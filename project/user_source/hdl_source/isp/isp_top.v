// SC500 720P standalone white balance demonstration ISP.
// This reference pipeline is a continuous video stream; it has no stall buffer.
module isp_top #(
    parameter BRIGHTEN_ENABLE = 1'b1
)(
    input          axi4s_video_aclk,
    input          I_rst_n,
    input I_process_clk,output O_cdc_overflow,
    input [18:0]   I_wb_config,
    input [2:0]    I_image_mode,
    output [36:0] O_wb_telemetry,
    input I_previous_bad,
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
    output         I_tready
);
    wire [127:0] demosaic_data;
    wire [95:0] rgb_data;
    wire demosaic_last, demosaic_user, demosaic_valid, demosaic_ready;
    wire [95:0] awb_data;
    wire awb_last, awb_user, awb_valid, awb_ready;
    wire [95:0] filter_data;
    wire filter_last,filter_user,filter_valid;

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

    reg [18:0] frame_config;
    always @(posedge axi4s_video_aclk or negedge I_rst_n)
     if(!I_rst_n)frame_config<=19'd30;else if(demosaic_user)frame_config<=I_wb_config;
    wire [18:0] active_config=demosaic_user?I_wb_config:frame_config;
    wire [11:0] applied_r,applied_b;wire statistics_ok;
    assign O_wb_telemetry={statistics_ok,applied_r,12'd1024,applied_b};
    wb_balance_96 u_white_balance (
        .I_clk(axi4s_video_aclk),.I_rst_n(I_rst_n),
        .I_mode(active_config[8:7]),.I_kelvin_index(active_config[6:0]),
        .I_data(rgb_data),.I_valid(demosaic_valid),.I_user(demosaic_user),.I_last(demosaic_last),
        .I_previous_bad(I_previous_bad),.I_ready(O_tready),.O_ready(demosaic_ready),.O_data(awb_data),
        .O_valid(awb_valid),.O_user(awb_user),.O_last(awb_last),.O_gain_r(applied_r),.O_gain_b(applied_b),.O_statistics_ok(statistics_ok));
    wire [95:0] tint_data;wire tint_valid,tint_user,tint_last;
    wb_tint_96 u_tint(.I_clk(axi4s_video_aclk),.I_rst_n(I_rst_n),.I_enable(frame_config[8:7]==2),
      .I_ab(frame_config[18:14]),.I_gm(frame_config[13:9]),.I_data(awb_data),
      .I_valid(awb_valid),.I_user(awb_user),.I_last(awb_last),.O_data(tint_data),
      .O_valid(tint_valid),.O_user(tint_user),.O_last(tint_last));
    wire [95:0] bright_pixels;
    rgb_brighten_96 #(.ENABLE(BRIGHTEN_ENABLE)) u_brighten(.I_data(tint_data),.O_data(bright_pixels));
    wire [95:0] process_rgb;wire process_valid,process_user,process_last;
    wire [2:0] process_mode;
    filter_clock_bridge u_filter_clock_bridge(
      .src_clk(axi4s_video_aclk),.dst_clk(I_process_clk),.rst_n(I_rst_n),
      .rgb(bright_pixels),.valid(tint_valid),.sof(tint_user),.last(tint_last),.mode(I_image_mode),
      .out_rgb(process_rgb),.out_valid(process_valid),.out_sof(process_user),.out_last(process_last),
      .out_mode(process_mode),.overflow(O_cdc_overflow));
    image_filter_bank_96 u_filter_bank(
      .I_clk(I_process_clk),.I_rst_n(I_rst_n),.I_mode(process_mode),
      .I_data(process_rgb),.I_valid(process_valid),.I_user(process_user),.I_last(process_last),
      .I_ready(O_tready),.O_data(filter_data),.O_valid(filter_valid),
      .O_user(filter_user),.O_last(filter_last),.O_ready(),.O_frame_mode(O_frame_mode));

    data_96bit_to_128bit u_data_96bit_to_128bit (
        .I_clk(I_process_clk), .I_rst_n(I_rst_n),
        .I_96b_frame_start(filter_user), .I_96b_valid(filter_valid),
        .I_96b_data(filter_data),
        .O_128b_frame_start(O_tuser), .O_128b_valid(O_tvalid),
        .O_128b_data(O_tdata)
    );

    // Match the packer latency on the legacy end-of-line status port.
    reg packed_last;
    always @(posedge I_process_clk or negedge I_rst_n) begin
        if (!I_rst_n) packed_last <= 1'b0;
        else          packed_last <= filter_last;
    end
    assign O_tlast = packed_last;
endmodule
