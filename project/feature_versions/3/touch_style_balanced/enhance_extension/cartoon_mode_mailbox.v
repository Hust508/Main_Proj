// Bundled-data CDC mailbox. Source payload is held until destination ACK;
// the request toggle is synchronized before the destination captures it.
module cartoon_mode_mailbox (
    input wire I_src_clk, I_dst_clk, I_rst_n,
    input wire I_dst_rst_n,
    input wire [2:0] I_mode,
    output reg [2:0] O_mode
);
    reg [2:0] payload;
    reg request, acknowledge;
    (* async_reg="true" *) reg [1:0] ack_sync, req_sync;
    reg req_delay;
    always @(posedge I_src_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin payload<=0; request<=0; ack_sync<=0; end
        else begin
            ack_sync<={ack_sync[0],acknowledge};
            if(request==ack_sync[1] && I_mode!=payload) begin
                payload<=I_mode; request<=!request;
            end
        end
    end
    always @(posedge I_dst_clk or negedge I_dst_rst_n) begin
        if(!I_dst_rst_n) begin req_sync<=0; req_delay<=0; acknowledge<=0; O_mode<=0; end
        else begin
            req_sync<={req_sync[0],request}; req_delay<=req_sync[1];
            if(req_delay!=acknowledge) begin O_mode<=payload; acknowledge<=req_delay; end
        end
    end
endmodule
