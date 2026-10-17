// Independent 25 MHz supervisor. It continues running when camera/DDR clocks
// stop. Reset the complete transport (not just its accounting) on a fault.
module cartoon_recovery #(
    parameter FRAME_WATCHDOG_ENABLE=1,
    parameter RESET_CYCLES=50000,       // 2 ms at 25 MHz
    parameter STARTUP_CYCLES=25000000,  // 1 s configuration grace
    parameter FRAME_TIMEOUT=25000000   // 1 s without RX or ISP frame starts
)(
    input wire clk, rst_n,
    input wire ddr_fault,
    input wire rx_toggle, isp_toggle,
    output reg run_n,
    output reg [15:0] recovery_count,
    output reg [2:0] last_reason
);
    localparam RW=(RESET_CYCLES<2)?1:$clog2(RESET_CYCLES);
    localparam GW=(STARTUP_CYCLES<2)?1:$clog2(STARTUP_CYCLES);
    localparam FW=(FRAME_TIMEOUT<2)?1:$clog2(FRAME_TIMEOUT);
    reg [RW-1:0] hold_count;
    reg [GW-1:0] grace_count;
    reg [FW-1:0] rx_age, isp_age;
    reg grace_done;
    (* async_reg="true" *) reg [1:0] fault_sync, rx_sync, isp_sync;
    reg rx_last, isp_last;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fault_sync<=0; rx_sync<=0; isp_sync<=0;
        end else begin
            fault_sync<={fault_sync[0],ddr_fault};
            rx_sync<={rx_sync[0],rx_toggle};
            isp_sync<={isp_sync[0],isp_toggle};
        end
    end
    wire rx_expired=(rx_age==FRAME_TIMEOUT-1);
    wire isp_expired=(isp_age==FRAME_TIMEOUT-1);
    wire fault_now=fault_sync[1] || (FRAME_WATCHDOG_ENABLE && grace_done &&
        ((rx_expired && rx_sync[1]==rx_last) || (isp_expired && isp_sync[1]==isp_last)));
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            run_n<=0; hold_count<=0; grace_count<=0; grace_done<=0;
            rx_age<=0; isp_age<=0; rx_last<=0; isp_last<=0;
            recovery_count<=0; last_reason<=0;
        end else if (!run_n) begin
            grace_count<=0; grace_done<=0; rx_age<=0; isp_age<=0;
            rx_last<=rx_sync[1]; isp_last<=isp_sync[1];
            if (hold_count==RESET_CYCLES-1) begin run_n<=1; hold_count<=0; end
            else hold_count<=hold_count+1'b1;
        end else if (fault_now) begin
            run_n<=0; hold_count<=0;
            if (recovery_count!=16'hffff) recovery_count<=recovery_count+1'b1;
            last_reason<=fault_sync[1]?3'd1:(rx_expired?3'd2:3'd3);
        end else begin
            if (!grace_done) begin
                if(grace_count==STARTUP_CYCLES-1) grace_done<=1;
                else grace_count<=grace_count+1'b1;
            end
            rx_last<=rx_sync[1]; isp_last<=isp_sync[1];
            if(rx_sync[1]!=rx_last) rx_age<=0;
            else if(!rx_expired) rx_age<=rx_age+1'b1;
            if(isp_sync[1]!=isp_last) isp_age<=0;
            else if(!isp_expired) isp_age<=isp_age+1'b1;
        end
    end
endmodule
