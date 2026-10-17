`timescale 1ns/1ps
// Real enhancement + packer + asynchronous capture FIFO + command FIFO +
// pAXI bridge, with display-row requests and bounded controller backpressure.
module enhance_display_tb;
 parameter REQUIRE_CLEAN=0,STALL_LEN=2300;
 // Actual continuous processing clock: 24 MHz, 320 valid + 80 blank beats/row.
 reg cam=0,ddr=0;always #20.833 cam=~cam;always #3.75 ddr=~ddr;
 reg rst=0,v=0,u=0,l=0;reg [95:0] rgb={4{24'hffffff}};
 wire ov,ou,ol,pv,pu;wire [95:0] out;wire [127:0] packed_word;wire [2:0] mode;
 enhance_frame_select #(.IMG_WIDTH(1280),.IMG_HEIGHT(16)) E(.I_clk(cam),.I_rst_n(rst),.I_mode(3'd1),.I_data(rgb),.I_valid(v),.I_user(u),.I_last(l),.I_ready(1'b1),.O_data(out),.O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(),.O_frame_mode(mode));
 cartoon_packer P(.I_clk(cam),.I_rst_n(rst),.I_96b_frame_start(ou),.I_96b_valid(ov),.I_96b_data(out),.O_128b_frame_start(pu),.O_128b_valid(pv),.O_128b_data(packed_word));
 wire wr,wb,ready,publish;wire [24:0] wa;wire [127:0] wd;wire [1:0] latest;wire [11:0] modes;
 integer cycle=0;wire rd,rb,ret,fault;wire [24:0] ra;wire [23:0] pixel;
 cartoon_video_in #(.FRAME_WORDS(3840)) W(.I_rst_n(rst),.I_ddr_rst_n(rst),.I_camera_clk(cam),.I_camera_frame_start(pu),.I_camera_mode(mode),.I_camera_valid(pv),.I_camera_data(packed_word),.I_mipi_rx_error(1'b0),.I_ddr_clk(ddr),.I_display_pause(1'b0),.I_video_out_rd_busy(rb),.I_read_slot(2'd0),.O_video_in_wr_busy(wb),.O_video_out_rp(latest),.O_slot_modes(modes),.O_frame_available(),.O_publish_toggle(publish),.O_ddr_user_wr_en(wr),.O_ddr_user_addr(wa),.O_ddr_user_wr_data(wd),.I_ddr_user_ready(ready));
 wire app_en,app_ready,app_wready;wire [24:0] app_addr;wire [2:0] app_cmd;wire [127:0] app_data;wire [31:0] mask;wire [8:0] queue_words;wire empty,afull;
 cartoon_command_queue Q(.I_clk(ddr),.I_rst_n(rst),.I_ddr_user_wr_en(wr),.I_ddr_user_rd_en(rd),.I_ddr_user_addr(wr?wa:ra),.I_ddr_user_wr_data(wd),.O_ddr_user_ready(ready),.O_ddr_user_rd_valid(),.O_ddr_user_rd_data(),.O_mc_app_en(app_en),.O_mc_app_addr(app_addr),.O_mc_app_cmd(app_cmd),.I_mc_app_rdy(app_ready),.O_mc_app_wdf_wren(),.O_mc_app_wdf_data(app_data),.O_mc_app_wdf_end(),.O_mc_app_wdf_mask(mask),.I_mc_app_wdf_rdy(app_wready),.I_mc_app_rd_data({128{1'b1}}),.I_mc_app_rd_data_end(ret),.I_mc_app_rd_data_valid(ret),.O_diag_words(queue_words),.O_diag_empty(empty),.O_diag_afull(afull));
 wire [24:0] awaddr,araddr;wire awvalid,wvalid,arvalid;wire [127:0] wdata;
 wire controller_ready=(cycle%10000>=STALL_LEN)&&(cycle%3!=0);
 cartoon_ddr_bridge B(.clk(ddr),.rst_n(rst),.app_en(app_en),.app_addr(app_addr),.app_cmd(app_cmd),.app_wdata(app_data),.app_wmask(mask[15:0]),.app_ready(app_ready),.app_wready(app_wready),.axi_awaddr(awaddr),.axi_awvalid(awvalid),.axi_awready(controller_ready),.axi_wdata(wdata),.axi_wstrb(),.axi_wvalid(wvalid),.axi_wlast(),.axi_wready(controller_ready),.axi_araddr(araddr),.axi_arvalid(arvalid),.axi_arready(controller_ready));
 integer overflow=0,published=0,max_capture=0,max_queue=0,writes=0,reads=0,outputs=0;
 reg previous_publish=0;
 always @(posedge cam)if(rst)begin
  if(pv&&W.full)overflow=overflow+1;
  if(ov)begin if(out!=={96{1'b1}})$fatal(1,"White enhancement corrupted");outputs=outputs+4;end
 end
 always @(posedge ddr)begin
  if(!rst)begin cycle<=0;end
  else begin
   cycle<=cycle+1;
   if(rd&&wr)$fatal(1,"Read/write request overlap");
   if(wvalid&&controller_ready)begin if(wdata!=={128{1'b1}})$fatal(1,"Write payload corrupted");writes=writes+1;end
   if(arvalid&&controller_ready)reads=reads+1;
   if(W.used>max_capture)max_capture=W.used;if(queue_words>max_queue)max_queue=queue_words;
   #1;
   if(publish!=previous_publish)begin
    published=published+1;if(modes[latest*3+:3]!==1)$fatal(1,"Enhancement mode tag lost");
   end
   previous_publish=publish;
  end
 end

 reg px=0;always #9.583 px=~px;
 reg vs=0,pull=0,check_pixel=0,display_done=0;
 reg [39:0] return_pipe=0;
 assign ret=return_pipe[39];
 always @(posedge ddr)begin
  if(!rst)return_pipe<=0;else return_pipe<={return_pipe[38:0],arvalid&&controller_ready};
 end
 cartoon_video_out R(.I_rst_n(rst),.I_pixel_rst_n(rst),.I_display_ready_n(rst),.I_frame_available(1'b1),
 .I_ddr_clk(ddr),.I_dsi_clk(px),.I_video_vsync(vs),.I_video_rd_en(pull),.I_video_in_wr_busy(wb),
 .I_video_out_rp(2'd0),.I_slot_modes(12'd0),.O_frame_mode(),.O_read_slot(),.O_recovery_req(fault),
 .O_video_out_rd_busy(rb),.O_ddr_user_rd_en(rd),.O_ddr_user_addr(ra),.I_ddr_user_ready(ready),
 .I_ddr_user_rd_valid(ret),.I_ddr_user_rd_data({128{1'b1}}),.O_vdieo_data(pixel),
 .I_diag_queue_words(queue_words),.I_diag_queue_empty(empty),.I_diag_queue_afull(afull),.I_diag_link(6'd0),.I_diag_axi_pending(16'd0));
 integer black_pixels=0,white_pixels=0,display_y,display_x;
 always @(posedge px)begin #1;if(rst&&check_pixel)begin
  if(pixel!==24'hffffff)black_pixels=black_pixels+1;else white_pixels=white_pixels+1;
 end end
 initial begin
  wait(rst);repeat(10)@(negedge px);vs=1;repeat(8)@(negedge px);vs=0;
  repeat(2500)@(negedge px);
  for(display_y=0;display_y<64;display_y=display_y+1)begin
   for(display_x=0;display_x<1024;display_x=display_x+1)begin pull=1;@(negedge px);check_pixel=1;end
   pull=0;@(negedge px);check_pixel=0;repeat(319)@(negedge px);
  end
  display_done=1;
 end

 integer f,y,x;
 initial begin
  repeat(20)@(negedge cam);rst=1;repeat(20)@(negedge cam);
  for(f=0;f<4;f=f+1)begin
   for(y=0;y<16;y=y+1)begin
    for(x=0;x<320;x=x+1)begin v=1;u=(y==0&&x==0);l=(x==319);@(negedge cam);end
    v=0;u=0;l=0;repeat(80)@(negedge cam);
   end
   repeat(6000)@(negedge cam);
  end
  repeat(6000)@(negedge cam);
  wait(display_done);repeat(100)@(negedge cam);
  if(REQUIRE_CLEAN&&(black_pixels!=0||fault))$fatal(1,"Display starved: black=%0d fault=%b",black_pixels,fault);
  if(outputs!=4*1280*16)$fatal(1,"Missing algorithm output pixels: %0d",outputs);
  if(REQUIRE_CLEAN&&(overflow!=0||published!=4||writes!=4*3840))$fatal(1,"Transport failure: drops=%0d published=%0d writes=%0d",overflow,published,writes);
  $display("PASS PRESSURE clean=%0d stall=%0d dropped_words=%0d published=%0d writes=%0d reads=%0d max_capture=%0d max_queue=%0d black_pixels=%0d white_pixels=%0d",REQUIRE_CLEAN,STALL_LEN,overflow,published,writes,reads,max_capture,max_queue,black_pixels,white_pixels);$finish;
 end
 initial begin #3000000;$fatal(1,"pressure timeout");end
endmodule
