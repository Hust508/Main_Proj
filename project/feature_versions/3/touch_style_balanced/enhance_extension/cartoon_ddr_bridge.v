// One transaction slot between the legacy app interface and PH1P pAXI.
// IPUG034 1.2, section 2.3.3.2: write data accompanies the address or
// follows it by at most two clocks. This is the controller's custom pAXI
// port, not a general AXI4 port that permits W to precede AW arbitrarily.
// Stage the complete write, accept AW, then offer its stable W one clock
// later. Keep W valid under backpressure and block later commands until
// it is accepted. AR still has its own independent ready/valid handshake.
module cartoon_ddr_bridge (
    input wire clk, rst_n,
    input wire app_en,
    input wire [24:0] app_addr,
    input wire [2:0] app_cmd,
    input wire [127:0] app_wdata,
    input wire [15:0] app_wmask,
    output wire app_ready,
    output wire app_wready,
    output wire [24:0] axi_awaddr,
    output wire axi_awvalid,
    input wire axi_awready,
    output wire [127:0] axi_wdata,
    output wire [15:0] axi_wstrb,
    output wire axi_wvalid, axi_wlast,
    input wire axi_wready,
    output wire [24:0] axi_araddr,
    output wire axi_arvalid,
    input wire axi_arready
);
    reg aw_pending, w_pending, ar_pending;
    reg [24:0] addr;
    reg [127:0] data;
    reg [15:0] mask;
    assign app_ready = rst_n && !(aw_pending || w_pending || ar_pending);
    assign app_wready = app_ready;
    assign axi_awaddr = addr;
    assign axi_araddr = addr;
    assign axi_awvalid = aw_pending;
    assign axi_wvalid = w_pending && !aw_pending;
    assign axi_wlast = 1'b1;
    assign axi_arvalid = ar_pending;
    assign axi_wdata = data;
    // The existing DDR integration uses all-zero mask for full-word writes.
    // Preserve its controller-specific mask convention here.
    assign axi_wstrb = mask;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_pending<=0; w_pending<=0; ar_pending<=0;
            addr<=0; data<=0; mask<=0;
        end else begin
            if (aw_pending && axi_awready) aw_pending<=0;
            if (axi_wvalid && axi_wready) w_pending<=0;
            if (ar_pending && axi_arready) ar_pending<=0;
            if (app_en && app_ready) begin
                addr<=app_addr; data<=app_wdata; mask<=app_wmask;
                ar_pending<=app_cmd[0];
                aw_pending<=!app_cmd[0]; w_pending<=!app_cmd[0];
            end
        end
    end
endmodule
