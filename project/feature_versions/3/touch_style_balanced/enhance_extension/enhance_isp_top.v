// SC500 720P ISP, original/enhancement selection, shared lossless packing.
// This reference pipeline is a continuous video stream; it has no stall buffer.
module enhance_isp_top (
    input          axi4s_video_aclk,
    input          I_rst_n,
    input wire I_process_clk,I_process_rst_n,
    output wire O_cdc_overflow,
    input [2:0]    I_mode,
    output [2:0]   O_frame_mode,
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
    output wire [7:0] O_stage_events,
    output         I_tready
);
    wire nr_valid,nr_sof;
    assign O_stage_events={O_tuser,O_tvalid,edge_user,edge_valid,nr_sof,nr_valid,process_user,process_valid};
    wire [95:0] process_rgb;wire process_valid,process_user,process_last;wire [2:0] process_mode;
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
        .O_tdata(awb_data), .O_tvalid(awb_valid), .O_tready(1'b1)
    );

    // The D-PHY receive clock may stop during blanking. Buffer complete
    // RGB events before entering the continuously clocked enhancement path.
    enhance_clock_bridge u_clock_bridge(
        .I_src_clk(axi4s_video_aclk),.I_src_rst_n(I_rst_n),
        .I_dst_clk(I_process_clk),.I_dst_rst_n(I_process_rst_n),
        .I_rgb(awb_data),.I_valid(awb_valid),.I_sof(awb_user),.I_last(awb_last),.I_mode(I_mode),
        .O_rgb(process_rgb),.O_valid(process_valid),.O_sof(process_user),.O_last(process_last),
        .O_mode(process_mode),.O_overflow(O_cdc_overflow));

    enhance_frame_select u_frame_select (
        .I_clk(I_process_clk),.I_rst_n(I_process_rst_n),.I_mode(process_mode),
        .I_data(process_rgb),.I_valid(process_valid),.I_user(process_user),.I_last(process_last),
        .I_ready(O_tready),.O_ready(awb_ready),.O_data(edge_data),
        .O_valid(edge_valid),.O_user(edge_user),.O_last(edge_last),
        .O_frame_mode(O_frame_mode),.O_nr_valid(nr_valid),.O_nr_sof(nr_sof));

    cartoon_packer u_data_96bit_to_128bit (
        .I_clk(I_process_clk), .I_rst_n(I_process_rst_n),
        .I_96b_frame_start(edge_user), .I_96b_valid(edge_valid),
        .I_96b_data(edge_data),
        .O_128b_frame_start(O_tuser), .O_128b_valid(O_tvalid),
        .O_128b_data(O_tdata)
    );

    // The DDR writer consumes frame_start/valid/data only. For the legacy
    // status port, delay the edge end-of-line pulse through the packer cycle.
    reg packed_last;
    always @(posedge I_process_clk or negedge I_process_rst_n) begin
        if (!I_process_rst_n) packed_last <= 1'b0;
        else          packed_last <= edge_last;
    end
    assign O_tlast = packed_last;
endmodule
