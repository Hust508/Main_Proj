`timescale 1ns/1ps
module reader_underflow_tb;
 reg clk=0,px=0;always #3.75 clk=~clk;always #9.583 px=~px;
 reg rst=0,vs=0,pull=0,serve=0,ret=0;
 wire req,fault;wire [23:0] pixel;
 integer pending=0,cycles=0;
 cartoon_video_out dut(.I_rst_n(rst),.I_pixel_rst_n(rst),.I_display_ready_n(rst),
 .I_frame_available(1'b1),.O_read_slot(),.O_recovery_req(fault),
 .I_ddr_clk(clk),.I_video_in_wr_busy(1'b0),.I_video_out_rp(2'd0),.I_slot_modes(8'd0),
 .O_frame_mode(),.O_video_out_rd_busy(),.O_ddr_user_rd_en(req),.O_ddr_user_addr(),
 .I_ddr_user_ready(pending<400),.I_ddr_user_rd_valid(ret),
 .I_ddr_user_rd_data({16{8'h7f}}),.I_dsi_clk(px),.I_video_vsync(vs),
 .I_video_rd_en(pull),.O_vdieo_data(pixel));
 always @(posedge clk)begin
   if(!rst)begin pending=0;ret<=0;end
   else begin
     if(req)pending=pending+1;
     ret<=0;
     if(serve&&pending>0)begin pending=pending-1;ret<=1;end
   end
 end
 task frame;
 begin @(negedge px);vs=1;repeat(8)@(negedge px);vs=0;end endtask
 initial begin
   repeat(12)@(negedge px);rst=1;frame();
   repeat(600)@(negedge px);pull=1;
   repeat(40)@(negedge px);
   if(!dut.S_scanout_bad||pixel!==0)$fatal(1,"empty FIFO must blank damaged frame");
   serve=1;repeat(600)@(negedge px);
   if(!dut.S_scanout_bad||pixel!==0)$fatal(1,"late data must not resume with shifted pixel phase");
   pull=0;frame();repeat(1000)@(negedge px);pull=1;
   repeat(3)@(negedge px);
   repeat(32)begin
     @(negedge px);
     if(pixel!==24'h7f7f7f||dut.S_scanout_bad||fault)$fatal(1,"next clean frame failed to restart");
   end
   $display("PASS display underflow: damaged frame stays blank despite late data; next VS flushes and resumes aligned pixels");
   $finish;
 end
 initial begin #200000;$fatal(1,"underflow test timeout");end
endmodule
