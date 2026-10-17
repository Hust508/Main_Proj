`timescale 1ns/1ps
module scanout_arbitration_tb;
 reg clk=0,cam=0,px=0;
 always #3.75 clk=~clk;
 always #8.333 cam=~cam;
 always #9.583 px=~px;
 reg rst=0,vs=0,pull=0,valid=0,sof=0;
 wire wr,rd,wb,rb;wire [24:0] wa,ra;wire [127:0] wd;
 reg ret=0;reg [127:0] retdata=0;wire [23:0] pixel;wire fault;
 wire [1:0] read_slot;
 cartoon_video_in writer(.I_rst_n(rst),.I_ddr_rst_n(rst),
 .I_camera_clk(cam),.I_camera_frame_start(sof),.I_camera_mode(2'd0),
 .O_slot_modes(),.I_camera_valid(valid),.I_camera_data(128'h1234),
 .I_mipi_rx_error(1'b0),.I_ddr_clk(clk),.I_display_pause(1'b0),
 .I_video_out_rd_busy(rb),.I_read_slot(read_slot),.O_video_in_wr_busy(wb),
 .O_video_out_rp(),.O_frame_available(),.O_publish_toggle(),
 .O_ddr_user_wr_en(wr),.O_ddr_user_addr(wa),.O_ddr_user_wr_data(wd),
 .I_ddr_user_ready(1'b1));
 cartoon_video_out reader(.I_pixel_rst_n(rst),.I_frame_available(1'b1),
 .O_read_slot(read_slot),.I_rst_n(rst),.I_display_ready_n(rst),.O_recovery_req(fault),
 .I_ddr_clk(clk),.I_video_in_wr_busy(wb),.I_video_out_rp(2'd0),.I_slot_modes(8'd0),
 .O_frame_mode(),.O_video_out_rd_busy(rb),.O_ddr_user_rd_en(rd),.O_ddr_user_addr(ra),
 .I_ddr_user_ready(1'b1),.I_ddr_user_rd_valid(ret),.I_ddr_user_rd_data(retdata),
 .I_dsi_clk(px),.I_video_vsync(vs),.I_video_rd_en(pull),.O_vdieo_data(pixel));
 function [23:0] pattern(input integer y,x);
   pattern={x[7:0],y[7:0],x[11:8],y[11:8]};
 endfunction
 function [127:0] word_at(input integer a);
   integer b,p,c;reg [23:0] v;
   begin for(b=0;b<16;b=b+1)begin
     p=(a*2+b)/3;c=(a*2+b)%3;v=pattern(p/1280,p%1280);
     word_at[127-b*8-:8]=v[23-c*8-:8];
   end end
 endfunction
 reg [39:0] pending=0;reg [127:0] pipe[0:39];integer j,reads=0,writes=0;
 integer idle_owner=0,max_idle_owner=0;
 always @(posedge clk)begin
   if(!rst)begin pending<=0;ret<=0;end
   else begin
     if(rd&&wr)$fatal(1,"simultaneous capture/display commands corrupt shared address bus");
     pending<={pending[38:0],rd};pipe[0]<=word_at(ra);
     for(j=1;j<40;j=j+1)pipe[j]<=pipe[j-1];
     ret<=pending[39];retdata<=pipe[39];
     if(rd)reads=reads+1;if(wr)writes=writes+1;
     if(wb&&writer.empty)idle_owner=idle_owner+1;else idle_owner=0;
     if(idle_owner>max_idle_owner)max_idle_owner=idle_owner;
   end
 end
 integer x,y,checked=0;reg check=0;reg [23:0] expected=0;
 always @(posedge px)begin
   #1;
   if(check&&pixel!==expected)$fatal(1,"scanout starved at y=%0d x=%0d expected=%h got=%h, writer busy=%b empty=%b idle ownership=%0d DDR clocks",y,x,expected,pixel,wb,writer.empty,max_idle_owner);
 end
 initial begin
   repeat(12)@(negedge clk);rst=1;
   repeat(5)@(negedge px);vs=1;repeat(8)@(negedge px);vs=0;
   repeat(2500)@(negedge px);
   // A partial camera line, followed by an exposure/packet gap. The already
   // published display frame must keep refreshing throughout the capture gap.
   @(negedge cam);sof=1;valid=1;
   @(negedge cam);sof=0;valid=0;
   for(y=0;y<12;y=y+1)begin
     for(x=0;x<1024;x=x+1)begin
       pull=1;@(negedge px);check=1;expected=pattern(y+60,x+128);checked=checked+1;
     end
     pull=0;@(negedge px);check=0;repeat(319)@(negedge px);
   end
   if(fault)$fatal(1,"healthy display refresh triggered transport recovery");
   if(max_idle_owner>2)$fatal(1,"capture retained DDR grant without data");
   $display("PASS capture/display arbitration: %0d exact pixels during partial camera line and gap, max empty capture ownership=%0d DDR clocks, %0d reads",checked,max_idle_owner,reads);
   $finish;
 end
 initial begin #1000000;$fatal(1,"arbitration test timeout");end
endmodule
