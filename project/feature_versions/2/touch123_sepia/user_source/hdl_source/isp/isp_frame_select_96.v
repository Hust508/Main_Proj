// Run the original edge engine continuously. Match its one-cycle latency
// on the color path, and select once per AWB frame, before the shared packer.
module isp_frame_select_96 #(
    parameter IMG_WIDTH=1280, IMG_HEIGHT=720, EDGE_THRESHOLD=14'd80
)(
    input wire I_clk,I_rst_n,
    input wire [1:0] I_mode,
    input wire [95:0] I_data,
    input wire I_valid,I_user,I_last,I_ready,
    output wire [95:0] O_data,
    output wire O_valid,O_user,O_last,O_ready,
    output reg [1:0] O_frame_mode
);
    reg [95:0] color_data;
    wire [95:0] edge_data;
    wire edge_valid, edge_user, edge_last;
    reg user_d;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin color_data<=0; O_frame_mode<=0; user_d<=0; end
        else begin
            color_data<=I_data; user_d<=I_user;
            if(I_user && !user_d) O_frame_mode <= (I_mode<=2) ? I_mode : 2'd0;
        end
    end
    edge_detect_96 #(.IMG_WIDTH(IMG_WIDTH),.IMG_HEIGHT(IMG_HEIGHT),
       .EDGE_TH(EDGE_THRESHOLD)) u_edge (
       .I_clk(I_clk),.I_rst_n(I_rst_n),.I_tdata(I_data),.I_tvalid(I_valid),
       .I_tuser(I_user),.I_tlast(I_last),.I_tready(I_ready),.O_tready(O_ready),
       .O_tdata(edge_data),.O_tvalid(edge_valid),.O_tuser(edge_user),.O_tlast(edge_last));
    assign O_data=(O_frame_mode==1) ? edge_data : color_data;
    assign O_valid=edge_valid;
    assign O_user=edge_user;
    assign O_last=edge_last;
endmodule
