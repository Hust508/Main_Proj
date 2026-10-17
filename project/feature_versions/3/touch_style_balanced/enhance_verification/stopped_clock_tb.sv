`timescale 1ns/1ps
module stopped_clock_tb;
 parameter W=1280,H=720,NEW_CLOCK=1,TAIL_CLOCKS=38;
 localparam G=W/4,WORDS=W*H*3/16;
 reg cam=0,run_cam=1,proc=0,ddr=0;
 always #8.333 if(run_cam)cam=~cam;
 always #20.833 proc=~proc;always #3.75 ddr=~ddr;
 wire clk=NEW_CLOCK?proc:cam;
 reg rst=0,v=0,u=0,l=0;reg [2:0] mode=1;
 reg [95:0] rgb={4{24'hffffff}};
 wire [95:0] in_rgb,out;wire iv,iu,il,ov,ou,ol,nv,nu,pv,pu,overflow;
 wire [2:0] in_mode,out_mode;wire [127:0] packed_word;
 generate if(NEW_CLOCK)begin:CROSSING
  enhance_clock_bridge C(.I_src_clk(cam),.I_src_rst_n(rst),.I_dst_clk(proc),.I_dst_rst_n(rst),
  .I_rgb(rgb),.I_valid(v),.I_sof(u),.I_last(l),.I_mode(mode),
  .O_rgb(in_rgb),.O_valid(iv),.O_sof(iu),.O_last(il),.O_mode(in_mode),.O_overflow(overflow));
 end else begin:ORIGINAL_CLOCK
  assign in_rgb=rgb;assign iv=v;assign iu=u;assign il=l;assign in_mode=mode;assign overflow=0;
 end endgenerate
 enhance_frame_select #(.IMG_WIDTH(W),.IMG_HEIGHT(H)) E(.I_clk(clk),.I_rst_n(rst),.I_mode(in_mode),
 .I_data(in_rgb),.I_valid(iv),.I_user(iu),.I_last(il),.I_ready(1'b1),
 .O_data(out),.O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(),.O_frame_mode(out_mode),.O_nr_valid(nv),.O_nr_sof(nu));
 cartoon_packer P(.I_clk(clk),.I_rst_n(rst),.I_96b_frame_start(ou),.I_96b_valid(ov),.I_96b_data(out),
 .O_128b_frame_start(pu),.O_128b_valid(pv),.O_128b_data(packed_word));
 wire publish,wr,drop;wire [127:0] wd;wire [24:0] wa;wire [1:0] latest;wire [11:0] modes;
 cartoon_video_in #(.FRAME_WORDS(WORDS)) CAP(.I_rst_n(rst),.I_ddr_rst_n(rst),
 .I_camera_clk(clk),.I_camera_frame_start(pu),.I_camera_mode(out_mode),.I_camera_valid(pv),.I_camera_data(packed_word),
 .I_mipi_rx_error(1'b0),.I_ddr_clk(ddr),.I_display_pause(1'b0),.I_video_out_rd_busy(1'b0),.I_read_slot(2'd0),
 .O_video_in_wr_busy(),.O_video_out_rp(latest),.O_slot_modes(modes),.O_frame_available(),.O_publish_toggle(publish),
 .O_ddr_user_wr_en(wr),.O_ddr_user_addr(wa),.O_ddr_user_wr_data(wd),.I_ddr_user_ready(1'b1),.O_capture_drop(drop));
 integer ac=0,nc=0,ec=0,pc=0,frames=0,writes=0,max_fifo=0;reg prior=0;
 always @(posedge clk)if(rst)begin
  if(iu)ac=0;if(iv)ac=ac+1;
  if(nu)nc=0;if(nv)nc=nc+1;
  if(ou)ec=0;if(ov)begin ec=ec+1;if(out!=={96{1'b1}})$fatal(1,"Incorrect white enhanced pixel");end
  if(pu)pc=0;if(pv)pc=pc+1;
  if(drop||overflow)$fatal(1,"Buffer overflow");
 end
 always @(posedge ddr)if(rst)begin
  if(wr)begin writes=writes+1;if(wd!=={128{1'b1}})$fatal(1,"Corrupt DDR write payload");end
  #1;if(prior!=publish)begin frames=frames+1;if(modes[latest*3+:3]!=1)$fatal(1,"Wrong frame mode");end
  prior=publish;
 end
 generate if(NEW_CLOCK)begin
  always @(posedge cam)if(rst&&CROSSING.C.u_rgb_fifo.wrusedw>max_fifo)max_fifo=CROSSING.C.u_rgb_fifo.wrusedw;
 end endgenerate
 integer f,y,x;
 initial begin
  repeat(20)@(negedge cam);rst=1;repeat(20)@(negedge cam);
  for(f=0;f<2;f=f+1)begin
   run_cam=1;@(negedge cam);u=1;v=0;@(negedge cam);u=0;repeat(58)@(negedge cam);
   for(y=0;y<H;y=y+1)begin
    for(x=0;x<G;x=x+1)begin v=1;l=(x==G-1);@(negedge cam);end
    v=0;l=0;if(y!=H-1)repeat(680)@(negedge cam);
   end
   repeat(TAIL_CLOCKS)@(negedge cam);run_cam=0;
   // No D-PHY edges during vertical blanking. The new 24 MHz clock continues.
   #100000;
   $display("FRAME clockfix=%0d index=%0d A=%05h N=%05h E=%05h P=%05h published=%0d",NEW_CLOCK,f,ac,nc,ec,pc,frames);
   if(NEW_CLOCK)begin
    if(ac!=W*H/4||nc!=W*H/4||ec!=W*H/4||pc!=WORDS||frames!=f+1)$fatal(1,"Clock-independent frame drain incomplete");
   end else if(pc>=WORDS||frames!=0)$fatal(1,"Stopped-clock baseline did not reproduce incomplete frame");
  end
  if(NEW_CLOCK&&writes!=2*WORDS)$fatal(1,"Missing DDR writes: %0d",writes);
  $display("PASS stopped-DPHY clockfix=%0d W=%0d H=%0d tail=%0d A=%05h N=%05h E=%05h P=%05h published=%0d writes=%0d max_rgb_fifo=%0d",NEW_CLOCK,W,H,TAIL_CLOCKS,ac,nc,ec,pc,frames,writes,max_fifo);$finish;
 end
 initial begin #100000000;$fatal(1,"Stopped-clock test timeout");end
endmodule
