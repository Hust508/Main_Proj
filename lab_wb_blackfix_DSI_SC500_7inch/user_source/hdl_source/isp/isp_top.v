// SC500 720P standalone white balance demonstration ISP.
// This reference pipeline is a continuous video stream; it has no stall buffer.
module isp_top #(
    parameter BRIGHTEN_ENABLE = 1'b1
)(
    input          axi4s_video_aclk,
    input          I_rst_n,
    input [8:0]    I_wb_config,
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

    wb_balance_96 u_white_balance (
        .I_clk(axi4s_video_aclk),.I_rst_n(I_rst_n),
        .I_mode(I_wb_config[8:7]),.I_kelvin_index(I_wb_config[6:0]),
        .I_data(rgb_data),.I_valid(demosaic_valid),.I_user(demosaic_user),.I_last(demosaic_last),
        .I_previous_bad(I_previous_bad),.I_ready(O_tready),.O_ready(demosaic_ready),.O_data(awb_data),
        .O_valid(awb_valid),.O_user(awb_user),.O_last(awb_last),.O_gain_r(),.O_gain_b());
    wire [95:0] bright_pixels;
    rgb_brighten_96 #(.ENABLE(BRIGHTEN_ENABLE)) u_brighten(.I_data(awb_data),.O_data(bright_pixels));
    reg [95:0] bright_data;reg bright_valid,bright_user,bright_last;
    always @(posedge axi4s_video_aclk or negedge I_rst_n)
    if(!I_rst_n)begin bright_data<=0;bright_valid<=0;bright_user<=0;bright_last<=0;end
    else begin bright_data<=awb_valid?bright_pixels:96'd0;bright_valid<=awb_valid;bright_user<=awb_user;bright_last<=awb_last;end
    assign edge_data=bright_data;assign edge_valid=bright_valid;assign edge_user=bright_user;assign edge_last=bright_last;
    assign O_frame_mode=3'd0;

    data_96bit_to_128bit u_data_96bit_to_128bit (
        .I_clk(axi4s_video_aclk), .I_rst_n(I_rst_n),
        .I_96b_frame_start(edge_user), .I_96b_valid(edge_valid),
        .I_96b_data(edge_data),
        .O_128b_frame_start(O_tuser), .O_128b_valid(O_tvalid),
        .O_128b_data(O_tdata)
    );

    // Match the packer latency on the legacy end-of-line status port.
    reg packed_last;
    always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
        if (!I_rst_n) packed_last <= 1'b0;
        else          packed_last <= edge_last;
    end
    assign O_tlast = packed_last;
endmodule
