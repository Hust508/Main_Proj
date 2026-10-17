// SC500 720P ISP with the lab-ex2 Sobel stage before DDR packing.
// This reference pipeline is a continuous video stream; it has no stall buffer.
module isp_top #(
    parameter EDGE_THRESHOLD = 14'd80
)(
    input          axi4s_video_aclk,
    input          I_rst_n,
    input [1:0]    I_mode,
    output [1:0]   O_frame_mode,
    input          I_tlast,
    input          I_tuser,
    input  [39:0]  I_tdata,
    input          I_tvalid,
    input  [9:0]   I_tdest,
    input          O_tready,
    output [127:0] O_tdata,
    output         O_tlast,
    output         O_tuser,
    output         O_tvalid,
    output         I_tready
);
    wire [127:0] demosaic_data;
    wire [95:0] rgb_data;
    wire demosaic_last, demosaic_user, demosaic_valid, demosaic_ready;
    wire [95:0] awb_data;
    wire awb_last, awb_user, awb_valid, awb_ready;
    wire [95:0] edge_data;
    wire edge_last, edge_user, edge_valid;

    demosaic #(
        .IMG_HEIGHT(720), .IMG_WIDTH(1280),
        .data_complete_delay(50), .BAYER_MODE("BGGR")
    ) u_demosaic (
        .I_clk(axi4s_video_aclk), .I_rst_n(I_rst_n),
        .axi4s_video_tdata(I_tdata), .axi4s_video_tdest(I_tdest),
        .axi4s_video_tlast(I_tlast), .axi4s_video_tuser(I_tuser),
        .axi4s_video_tvalid(I_tvalid), .axi4s_video_tready(I_tready),
        .O_tdata(demosaic_data), .O_tlast(demosaic_last),
        .O_tuser(demosaic_user), .O_tvalid(demosaic_valid),
        .O_tready(demosaic_ready)
    );

    data128_96 u_data128_96 (
        .I_tdata(demosaic_data), .O_tdata(rgb_data)
    );

    awb #(.IMG_HEIGHT(720), .IMG_WIDTH(1280)) u_awb (
        .I_clk(axi4s_video_aclk), .I_rst_n(I_rst_n),
        .I_tlast(demosaic_last), .I_tuser(demosaic_user),
        .I_tdata(rgb_data), .I_tvalid(demosaic_valid),
        .I_tready(demosaic_ready),
        .O_tlast(awb_last), .O_tuser(awb_user),
        .O_tdata(awb_data), .O_tvalid(awb_valid), .O_tready(awb_ready)
    );

    isp_frame_select_96 #(.EDGE_THRESHOLD(EDGE_THRESHOLD)) u_frame_select (
        .I_clk(axi4s_video_aclk),.I_rst_n(I_rst_n),.I_mode(I_mode),
        .I_data(awb_data),.I_valid(awb_valid),.I_user(awb_user),.I_last(awb_last),
        .I_ready(O_tready),.O_ready(awb_ready),.O_data(edge_data),
        .O_valid(edge_valid),.O_user(edge_user),.O_last(edge_last),
        .O_frame_mode(O_frame_mode));

    data_96bit_to_128bit u_data_96bit_to_128bit (
        .I_clk(axi4s_video_aclk), .I_rst_n(I_rst_n),
        .I_96b_frame_start(edge_user), .I_96b_valid(edge_valid),
        .I_96b_data(edge_data),
        .O_128b_frame_start(O_tuser), .O_128b_valid(O_tvalid),
        .O_128b_data(O_tdata)
    );

    // The DDR writer consumes frame_start/valid/data only. For the legacy
    // status port, delay the edge end-of-line pulse through the packer cycle.
    reg packed_last;
    always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
        if (!I_rst_n) packed_last <= 1'b0;
        else          packed_last <= edge_last;
    end
    assign O_tlast = packed_last;
endmodule
