`timescale 1ns/1ps
module transport_recovery_tb;
 reg sys=0,clk=0,cam=0,dsi=0;
 always #7 sys=~sys;always #5 clk=~clk;always #11 cam=~cam;always #9 dsi=~dsi;
 reg cold=0,display_ready=1,vs=0,ready=1;
 wire run,fault;wire [15:0] recoveries;wire [2:0] reason;
 reg rx=0,isp=0,rx_enable=1,isp_enable=1;
 integer hc=0,requests=0,base,k;
 reg [30:0] returns=0;reg ret=0,drop_one=0,dropped=0,stray=0;
 wire req;
 always @(posedge cam or negedge run)begin
   if(!run)begin hc<=0;rx<=0;isp<=0;end
   else if(hc==6)begin
     hc<=0;if(rx_enable)rx<=~rx;if(isp_enable)isp<=~isp;
   end else hc<=hc+1;
 end
 cartoon_recovery #(.RESET_CYCLES(16),.STARTUP_CYCLES(300),.FRAME_TIMEOUT(200)) supervisor(
 .clk(sys),.rst_n(cold),.ddr_fault(fault),.rx_toggle(rx),.isp_toggle(isp),
 .run_n(run),.recovery_count(recoveries),.last_reason(reason));
 cartoon_video_out #(.DDR_STALL_CYCLES(64)) dut(.I_pixel_rst_n(run),.I_frame_available(1'b1),.O_read_slot(),.I_rst_n(run),.I_display_ready_n(display_ready),
 .O_recovery_req(fault),.I_ddr_clk(clk),.O_video_out_rd_busy(),.I_video_in_wr_busy(1'b0),
 .I_video_out_rp(2'd0),.I_slot_modes(8'd0),.O_frame_mode(),
 .O_ddr_user_rd_en(req),.O_ddr_user_addr(),.I_ddr_user_ready(ready),
 .I_ddr_user_rd_valid(ret),.I_ddr_user_rd_data(128'd0),
 .I_dsi_clk(dsi),.I_video_vsync(vs),.I_video_rd_en(1'b0),.O_vdieo_data());
 always @(posedge clk or negedge run)begin
   if(!run)returns<=0;
   else begin returns<={returns[29:0],req};if(req)requests=requests+1;end
 end
 always @(negedge clk)begin
   ret=run&&(returns[30]||stray);
   if(ret&&drop_one&&!dropped)begin ret=0;dropped=1;end
 end
 task frame;
 begin @(negedge clk);vs=1;repeat(8)@(negedge clk);vs=0;end
 endtask
 task boot;
 begin
   @(negedge sys);cold=0;display_ready=1;vs=0;ready=1;
   rx_enable=1;isp_enable=1;drop_one=0;dropped=0;stray=0;
   repeat(6)@(negedge sys);cold=1;wait(run);repeat(8)@(negedge clk);
 end endtask
 task resumed;
 begin
   wait(!run);wait(run);repeat(8)@(negedge clk);
   base=requests;frame();repeat(150)@(negedge clk);
   if(requests<=base||recoveries!=1||fault)$fatal(1,"transport did not resume cleanly");
 end endtask
 initial begin
   boot();frame();wait(requests>=40);
   // Display-only reset must retain outstanding requests and drain returns.
   @(negedge clk);display_ready=0;repeat(3)@(negedge clk);display_ready=1;
   frame();repeat(180)@(negedge clk);
   if(fault||recoveries!=0||!dut.S_frame_ready)$fatal(1,"display-only reset did not recover");
   $display("PASS display-only reset with late DDR responses: no counter underflow or spurious global reset");

   boot();drop_one=1;frame();wait(dropped);frame();
   resumed();
   if(reason!=1)$fatal(1,"missing-return reason");
   $display("PASS lost DDR response: bounded timeout, coordinated reset, next frame reads resume");

   boot();ready=0;frame();wait(fault);ready=1;
   resumed();
   $display("PASS command queue backpressure stall: timeout and recovery");

   boot();stray=1;repeat(2)@(negedge clk);stray=0;wait(fault);
   if(dut.S_outstanding_reads!==0)$fatal(1,"unowned response wrapped counter");
   resumed();
   $display("PASS unowned response: no underflow, safe full transport recovery");

   boot();repeat(400)@(negedge sys);
   if(recoveries!=0)$fatal(1,"normal asynchronous camera frames triggered recovery");
   rx_enable=0;wait(!run);rx_enable=1;wait(run);
   if(recoveries!=1||reason!=2)$fatal(1,"RX frame watchdog failure");
   repeat(350)@(negedge sys);
   if(recoveries!=1)$fatal(1,"camera recovery repeated spuriously");
   isp_enable=0;wait(!run);isp_enable=1;wait(run);
   if(recoveries!=2||reason!=3)$fatal(1,"ISP frame watchdog failure");
   $display("PASS independent system-clock supervisor: stopped RX/ISP activity, startup grace, recovery reasons");
   $finish;
 end
 initial begin #1000000;$fatal(1,"recovery timeout");end
endmodule
