`timescale 1ns/1ps
// Real enhancement + packer + asynchronous capture FIFO + command FIFO +
// pAXI bridge, with display-row requests and bounded controller backpressure.
module enhance_pressure_tb;
 parameter REQUIRE_CLEAN=0,STALL_LEN=2300;
 reg cam=0,ddr=0;always #8.333 cam=~cam;always #3.75 ddr=~ddr;
 reg rst=0,v=0,u=0,l=0;reg [95:0] rgb={4{24'hffffff}};
 wire ov,ou,ol,pv,pu;wire [95:0] out;wire [127:0] packed_word;wire [2:0] mode;
 enhance_frame_select #(.IMG_WIDTH(1280),.IMG_HEIGHT(16)) E(.I_clk(cam),.I_rst_n(rst),.I_mode(3'd1),.I_data(rgb),.I_valid(v),.I_user(u),.I_last(l),.I_ready(1'b1),.O_data(out),.O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(),.O_frame_mode(mode));
 cartoon_packer P(.I_clk(cam),.I_rst_n(rst),.I_96b_frame_start(ou),.I_96b_valid(ov),.I_96b_data(out),.O_128b_frame_start(pu),.O_128b_valid(pv),.O_128b_data(packed_word));
 wire wr,wb,ready,publish;wire [24:0] wa;wire [127:0] wd;wire [1:0] latest;wire [11:0] modes;
 integer cycle=0,left=0,read_index=0;wire rd=(left>0)&&!wb&&ready;
 cartoon_video_in #(.FRAME_WORDS(3840)) W(.I_rst_n(rst),.I_ddr_rst_n(rst),.I_camera_clk(cam),.I_camera_frame_start(pu),.I_camera_mode(mode),.I_camera_valid(pv),.I_camera_data(packed_word),.I_mipi_rx_error(1'b0),.I_ddr_clk(ddr),.I_display_pause(1'b0),.I_video_out_rd_busy(left>0),.I_read_slot(2'd0),.O_video_in_wr_busy(wb),.O_video_out_rp(latest),.O_slot_modes(modes),.O_frame_available(),.O_publish_toggle(publish),.O_ddr_user_wr_en(wr),.O_ddr_user_addr(wa),.O_ddr_user_wr_data(wd),.I_ddr_user_ready(ready));
 wire app_en,app_ready,app_wready;wire [24:0] app_addr;wire [2:0] app_cmd;wire [127:0] app_data;wire [31:0] mask;wire [8:0] queue_words;wire empty,afull;
 cartoon_command_queue Q(.I_clk(ddr),.I_rst_n(rst),.I_ddr_user_wr_en(wr),.I_ddr_user_rd_en(rd),.I_ddr_user_addr(wr?wa:(read_index*8)),.I_ddr_user_wr_data(wd),.O_ddr_user_ready(ready),.O_ddr_user_rd_valid(),.O_ddr_user_rd_data(),.O_mc_app_en(app_en),.O_mc_app_addr(app_addr),.O_mc_app_cmd(app_cmd),.I_mc_app_rdy(app_ready),.O_mc_app_wdf_wren(),.O_mc_app_wdf_data(app_data),.O_mc_app_wdf_end(),.O_mc_app_wdf_mask(mask),.I_mc_app_wdf_rdy(app_wready),.I_mc_app_rd_data(128'd0),.I_mc_app_rd_data_end(1'b0),.I_mc_app_rd_data_valid(1'b0),.O_diag_words(queue_words),.O_diag_empty(empty),.O_diag_afull(afull));
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
  if(!rst)begin cycle<=0;left<=0;read_index<=0;end
  else begin
   cycle<=cycle+1;
   if(cycle%3434==300&&left==0)left<=192;
   else if(rd)begin left<=left-1;read_index<=(read_index==191)?0:read_index+1;end
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
 integer f,y,x;
 initial begin
  repeat(20)@(negedge cam);rst=1;repeat(20)@(negedge cam);
  for(f=0;f<4;f=f+1)begin
   for(y=0;y<16;y=y+1)begin
    for(x=0;x<320;x=x+1)begin v=1;u=(y==0&&x==0);l=(x==319);@(negedge cam);end
    v=0;u=0;l=0;repeat(680)@(negedge cam);
   end
   repeat(6000)@(negedge cam);
  end
  repeat(6000)@(negedge cam);
  if(outputs!=4*1280*16)$fatal(1,"Missing algorithm output pixels: %0d",outputs);
  if(REQUIRE_CLEAN&&(overflow!=0||published!=4||writes!=4*3840))$fatal(1,"Transport failure: drops=%0d published=%0d writes=%0d",overflow,published,writes);
  $display("PASS PRESSURE clean=%0d stall=%0d dropped_words=%0d published=%0d writes=%0d reads=%0d max_capture=%0d max_queue=%0d",REQUIRE_CLEAN,STALL_LEN,overflow,published,writes,reads,max_capture,max_queue);$finish;
 end
 initial begin #3000000;$fatal(1,"pressure timeout");end
endmodule
