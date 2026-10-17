`timescale 1ns/1ps
module stream_diag_tb;
 reg cam=0,sys=0,px=0,enable_cam=1;
 always #8.333 if(enable_cam)cam=~cam;
 always #20 sys=~sys;always #9.583 px=~px;
 reg rst=0,run=0,crun=0,av=0,asof=0,nv=0,nsof=0,ev=0,esof=0,pv=0,psof=0,drop=0,input_overflow=0;
 wire [95:0] status;
 enhance_stream_diag D(.cold_rst_n(rst),.cam_clk(cam),.sys_clk(sys),.pixel_clk(px),
 .cam_run_n(crun),.input_overflow_i(input_overflow),.recovery_run_n(run),.av(av),.asof(asof),.nv(nv),.nsof(nsof),
 .ev(ev),.esof(esof),.pv(pv),.psof(psof),.drop_i(drop),.pixel_status(status));
 integer i;
 initial begin
  repeat(5)@(negedge cam);rst=1;run=1;crun=1;
  for(i=0;i<100;i=i+1)begin
   asof=(i==0);nsof=(i==0);esof=(i==0);psof=(i==0);
   av=1;nv=(i<80);ev=(i<60);pv=(i<45);drop=(i<3);@(negedge cam);
  end
  av=0;nv=0;ev=0;pv=0;asof=0;nsof=0;esof=0;psof=0;drop=0;
  input_overflow=1;repeat(5)@(negedge cam);input_overflow=0;
  repeat(100)@(negedge sys);
  if(status!=={16'h8003,20'd45,20'd60,20'd80,20'd100})$fatal(1,"Live diagnostic mismatch: %h",status);
  run=0;crun=0;repeat(50)@(negedge sys);
  enable_cam=0;repeat(100)@(negedge sys);
  if(status!=={16'h8003,20'd45,20'd60,20'd80,20'd100})$fatal(1,"Stopped camera lost timeout snapshot");
  enable_cam=1;run=1;crun=1;
  @(negedge cam);av=1;asof=1;nv=1;nsof=1;ev=1;esof=1;pv=1;psof=1;
  @(negedge cam);asof=0;nsof=0;esof=0;psof=0;
  repeat(9)@(negedge cam);av=0;nv=0;ev=0;pv=0;
  repeat(100)@(negedge sys);
  if(status!=={16'h8003,20'd45,20'd60,20'd80,20'd100})$fatal(1,"Recovery overwrote first fault snapshot");
  rst=0;repeat(5)@(negedge sys);rst=1;repeat(100)@(negedge sys);
  if(status!==0)$fatal(1,"Cold reset did not clear history");
  $display("PASS A/N/E/P/drop counts, sticky input overflow, acknowledged CDC, first-fault freeze, stopped camera, recovery retention and cold reset");$finish;
 end
 initial begin #100000;$fatal(1,"diagnostic timeout");end
endmodule
