`timescale 1ns/1ps
module mode_tags_tb;
    reg cam_clk=0,ddr_clk=0,dsi_clk=0;
    always #7 cam_clk=~cam_clk;
    always #5 ddr_clk=~ddr_clk;
    always #9 dsi_clk=~dsi_clk;
    reg rst=0,sof=0,vs=0;
    reg [2:0] cam_mode=0;
    wire [11:0] tags;
    wire [1:0] rp;
    wire [2:0] display_mode;
    wire wrbusy;
    video_in writer(.I_rst_n(rst),.I_camera_clk(cam_clk),.I_camera_frame_start(sof),
      .I_camera_mode(cam_mode),.O_slot_modes(tags),.I_camera_valid(1'b0),.I_camera_data(128'd0),
      .I_mipi_rx_error(1'b0),.I_ddr_clk(ddr_clk),.I_display_pause(1'b0),
      .I_video_out_rd_busy(1'b0),.O_video_in_wr_busy(wrbusy),.O_video_out_rp(rp),
      .O_ddr_user_wr_en(),.O_ddr_user_addr(),.O_ddr_user_wr_data(),.I_ddr_user_ready(1'b0));
    video_out reader(.I_rst_n(rst),.I_ddr_clk(ddr_clk),.I_video_in_wr_busy(wrbusy),
      .I_video_out_rp(rp),.I_slot_modes(tags),.O_frame_mode(display_mode),
      .O_video_out_rd_busy(),.O_ddr_user_rd_en(),.O_ddr_user_addr(),
      .I_ddr_user_ready(1'b0),.I_ddr_user_rd_valid(1'b0),.I_ddr_user_rd_data(128'd0),
      .I_dsi_clk(dsi_clk),.I_video_vsync(vs),.I_video_rd_en(1'b0),.O_vdieo_data());
    reg [11:0] expected_tags=0;
    reg [2:0] expected_display=0;
    integer writes=0,reads=0,slot,negative_reads=0,pixel_reads=0;
    reg [3:0] negative_slots=0,pixel_slots=0;
    always @(posedge ddr_clk) if(rst) begin
        if(writer.S_frame_start) begin
            slot=writer.S_video_in_wp;
            expected_tags[slot*3 +: 3]=cam_mode;writes=writes+1;
            if(cam_mode==4)negative_slots=negative_slots|(1<<slot);
            if(cam_mode==5)pixel_slots=pixel_slots|(1<<slot);
        end
        if(reader.S_video_frame_start) begin
            expected_display=tags[rp*3 +: 3];reads=reads+1;
            if(expected_display==4)negative_reads=negative_reads+1;
            if(expected_display==5)pixel_reads=pixel_reads+1;
        end
        #1;
        if(tags!==expected_tags) $fatal(1,"DDR slot mode tag mismatch");
        if(display_mode!==expected_display) $fatal(1,"Read mode disagrees with selected DDR slot");
    end
    integer f;
    initial begin
        #60;rst=1;
        for(f=0;f<24;f=f+1)begin
            @(negedge cam_clk);cam_mode=f/4;
            @(negedge cam_clk);sof=1;
            @(negedge cam_clk);sof=0;
            repeat(30)@(negedge cam_clk);
            @(negedge dsi_clk);vs=1;
            repeat(5)@(negedge dsi_clk);vs=0;
            repeat(15)@(negedge cam_clk);
        end
        if(writes!=24||reads!=24||negative_slots!=15||negative_reads==0||pixel_slots!=15||pixel_reads==0) $fatal(1,"Insufficient mode tag coverage");
        $display("PASS DDR four-slot 3-bit tags, negative and pixel-art modes in every slot and read-slot selection across asynchronous clocks, %0d writes %0d display frames",writes,reads);$finish;
    end
endmodule
