`timescale 1ns/1ps
module ui_control_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,online=1,report=0;reg [3:0] contacts=0;reg [9:0] x=0,y=0;reg [1:0] keys=3;
 wire [3:0] page;wire [1:0] mode,preset;wire [6:0] index,gain;wire detect,tag;wire [2:0] image_mode;
 wb_ui_control #(.CLK_HZ(1000)) dut(.I_clk(clk),.I_rst_n(rst),.I_online(online),.I_report(report),.I_contacts(contacts),.I_x(x),.I_y(y),.I_buttons_n(keys),
 .O_page(page),.O_mode(mode),.O_preset(preset),.O_index(index),.O_gain(gain),
 .O_detect_enable(detect),.O_tag_enable(tag),.O_image_mode(image_mode));
 task point(input integer c,px,py);
  begin @(negedge clk);contacts=c;x=px;y=py;report=1;@(negedge clk);report=0;repeat(2)@(negedge clk);end
 endtask
 task lift;begin point(0,0,0);repeat(40)@(negedge clk);end endtask
 task tap(input integer px,py);begin point(1,px,py);lift();end endtask
 task expect_page(input integer expected);begin if(page!=expected)$fatal(1,"UI page %0d expected %0d",page,expected);end endtask
 always @(posedge clk)if(rst&&(gain<16||gain>89||index>75))$fatal(1,"UI value bounds");
 integer i;
 initial begin
  repeat(4)@(negedge clk);rst=1;lift();
  tap(100,200);expect_page(0);
  point(1,100,200);point(0,0,0);repeat(5)@(negedge clk);
  for(i=0;i<200;i=i+1)begin point(1,100,200);repeat(2)@(negedge clk);end
  expect_page(0);repeat(100)@(negedge clk);point(1,100,200);repeat(900)@(negedge clk);
  expect_page(0);lift(); // stale reports during a returning contact also cannot rearm


  point(1,100,200);repeat(810)@(negedge clk);expect_page(1);
  repeat(1000)@(negedge clk);expect_page(1); // long press never clicks through
  lift();tap(700,300);expect_page(4);if(mode!=2||index!=30)$fatal(1,"Custom entry");
  point(1,600,290);if(index!=0)$fatal(1,"Slider lower endpoint");
  point(1,900,290);if(index!=60)$fatal(1,"Slider tracking");
  point(1,1023,550);if(index!=75)$fatal(1,"Captured slider upper clamp");
  lift();tap(620,50);expect_page(1);tap(700,220);expect_page(3);
  for(i=0;i<4;i=i+1)begin
   tap(700,140+i*80);
   if(mode!=1||preset!=i||index!=((i==0)?5:(i==1)?30:(i==2)?40:50))$fatal(1,"Preset %0d",i);
  end
  tap(620,50);expect_page(1);tap(700,140);expect_page(2);if(mode!=0)$fatal(1,"Automatic selection");
  tap(620,50);tap(700,300);expect_page(4);if(index!=75)$fatal(1,"Custom value not remembered");
  tap(620,50);tap(700,380);expect_page(5);
  tap(620,140);if(gain!=16)$fatal(1,"1x shortcut");
  tap(780,140);if(gain!=48)$fatal(1,"2x shortcut");
  tap(920,140);if(gain!=80)$fatal(1,"4x shortcut");
  tap(900,340);if(gain!=81)$fatal(1,"Touch gain plus");
  tap(650,340);if(gain!=80)$fatal(1,"Touch gain minus");
  point(1,900,340);repeat(2000)@(negedge clk);lift();if(gain!=89)$fatal(1,"Touch gain repeat upper limit");
  tap(800,460);if(gain!=80)$fatal(1,"Touch gain default");
  keys=2'b10;repeat(30)@(negedge clk);keys=3;repeat(30)@(negedge clk);if(gain!=79)$fatal(1,"Physical down synchronization");
  keys=2'b01;repeat(30)@(negedge clk);keys=3;repeat(30)@(negedge clk);if(gain!=80)$fatal(1,"Physical up synchronization");
  keys=2'b10;repeat(20000)@(negedge clk);keys=3;repeat(30)@(negedge clk);if(gain!=16)$fatal(1,"Physical lower clamp");
  tap(620,50);expect_page(1);tap(620,50);expect_page(0);
  point(2,100,200);point(1,100,200);repeat(900)@(negedge clk);expect_page(0);lift();
  point(1,100,200);point(1,200,250);repeat(900)@(negedge clk);expect_page(0);lift();
  point(1,100,200);repeat(200)@(negedge clk);online=0;repeat(900)@(negedge clk);online=1;expect_page(0);lift();
  point(1,100,200);repeat(810)@(negedge clk);expect_page(1);lift();
  tap(680,460);expect_page(7);tap(900,140);if(image_mode!=1)$fatal(1,"Gray filter");
  tap(680,220);if(image_mode!=2)$fatal(1,"Cartoon filter");tap(900,220);if(image_mode!=3)$fatal(1,"Negative filter");
  tap(680,300);if(image_mode!=4)$fatal(1,"Pixel filter");tap(900,300);if(image_mode!=5)$fatal(1,"Edge filter");
  tap(620,50);expect_page(1);tap(900,460);expect_page(8);tap(700,140);if(!tag)$fatal(1,"Tag toggle");
  tap(700,220);if(!detect)$fatal(1,"Tracking toggle");
  $display("PASS UI long press, WB pages, filter library, feature toggles, shared gain, repeat/clamps and fault cancellation");$finish;
 end
 initial begin #1000000;$fatal(1,"UI watchdog");end
endmodule

module wb_720p_tb;
 localparam N=1280*720*3;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,v=0,u=0,l=0;reg [95:0] rgb=0;reg [6:0] index=5;
 wire [95:0] data;wire ov,ou,ol,ready,pv,pu;wire [127:0] packed_data;
 wb_balance_96 dut(.I_clk(clk),.I_rst_n(rst),.I_mode(2'd1),.I_kelvin_index(index),.I_data(rgb),.I_valid(v),.I_user(u),.I_last(l),.I_ready(1'b1),.I_previous_bad(1'b0),
 .O_data(data),.O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(ready),.O_gain_r(),.O_gain_b());
 data_96bit_to_128bit packer(.I_clk(clk),.I_rst_n(rst),.I_96b_frame_start(ou),.I_96b_valid(ov),.I_96b_data(data),.O_128b_frame_start(pu),.O_128b_valid(pv),.O_128b_data(packed_data));
 integer put=0,take=0,words=0,frames=0,p,j,r,b;
 reg [7:0] expected[0:N-1];
 reg ddr=0;always #3.7 ddr=~ddr;
 wire wr;wire [24:0] address;wire [127:0] write_data;wire [31:0] good,dropped,overflow;
 integer write_bytes=0,write_count=0,ddr_cycle=0,z;
 reg [15:0] pending_writes=0;
 video_in store(.I_rst_n(rst),.I_camera_clk(clk),.I_camera_frame_start(pu),.I_camera_mode(3'd0),.O_slot_modes(),
 .I_camera_valid(pv),.I_camera_data(packed_data),.I_mipi_rx_error(1'b0),.I_ddr_clk(ddr),.I_display_pause(1'b0),
 .I_video_out_rd_busy(1'b0),.I_display_frame_release(1'b0),.I_ddr_writes_idle(pending_writes==0&&!wr),
 .O_video_in_wr_busy(),.O_video_out_rp(),.O_front_valid(),.O_ddr_user_wr_en(wr),.O_ddr_user_addr(address),
 .O_ddr_user_wr_data(write_data),.I_ddr_user_ready(ddr_cycle%13!=0),
 .O_dropped_frames(dropped),.O_good_frames(good),.O_fifo_overflows(overflow));
 always @(posedge ddr)begin
  ddr_cycle=ddr_cycle+1;
  if(!rst)pending_writes<=0;else pending_writes<={pending_writes[14:0],wr};
  if(wr)begin
   if(address!==write_count*8)$fatal(1,"720P DDR write address %d %d",address,write_count*8);
   for(z=0;z<16;z=z+1)begin
    if(write_bytes>=put||write_data[127-z*8-:8]!==expected[write_bytes])$fatal(1,"720P DDR byte %d",write_bytes);
    write_bytes=write_bytes+1;
   end
   write_count=write_count+1;
  end
 end
 reg pv0=0,pu0=0,pl0=0;
 always @(posedge clk)if(rst)begin
  if(v)for(p=3;p>=0;p=p-1)begin
   r=(rgb[p*24+16+:8]*717+512)/1024;b=(rgb[p*24+0+:8]*2048+512)/1024;
   expected[put]=(r>255)?255:r;put=put+1;expected[put]=rgb[p*24+8+:8];put=put+1;
   expected[put]=(b>255)?255:b;put=put+1;
  end
  #1;
  if({ov,ou,ol,ready}!=={pv0,pu0,pl0,1'b1})$fatal(1,"720p WB sidebands");
  pv0=v;pu0=u;pl0=l;
  if(pu)frames=frames+1;
  if(pv)begin
   for(j=0;j<16;j=j+1)begin
    if(take>=put||packed_data[127-j*8-:8]!==expected[take])$fatal(1,"WB 720p byte %0d",take);
    take=take+1;
   end
   words=words+1;
  end
 end
 integer yy,xx;
 initial begin
  repeat(4)@(negedge clk);rst=1;u=1;@(negedge clk);u=0;repeat(3)@(negedge clk);
  for(yy=0;yy<720;yy=yy+1)begin
   if(yy==300)index=75;
   for(xx=0;xx<320;xx=xx+1)begin v=1;l=xx==319;rgb={$random,$random,$random};@(negedge clk);end
   v=0;l=0;repeat(8)@(negedge clk);
  end
  repeat(8)@(negedge clk);
  if(put!=N||take!=N||words!=172800||frames!=1)$fatal(1,"WB 720p coverage");
  u=1;@(negedge clk);u=0;repeat(120)@(negedge clk);
  if(write_count!=172800||write_bytes!=N||good!=1||dropped!=0||overflow!=0)$fatal(1,"Full-frame commit %d %d %d %d %d",write_count,write_bytes,good,dropped,overflow);
  $display("PASS WB plus async frame store 1280x720 frame, 921600 pixels, 2764800 byte oracle, 172800 DDR words, no dropped beats, mid-frame K update deferred and exact controls");$finish;
 end
 initial begin #5000000;$fatal(1,"WB 720p watchdog");end
endmodule

module overlay_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,v=0,h=0,de=0;reg [23:0] rgb=0;reg [38:0] cfg=0;
 wire ov,oh,od;wire [23:0] data;
 wb_ui_overlay #(.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex")) dut(.I_telemetry({1'b1,12'd1536,12'd1024,12'd768}),.I_clk(clk),.I_rst_n(rst),.I_config(cfg),
 .I_vsync(v),.I_hsync(h),.I_de(de),.I_data(rgb),.O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(data));
 reg vv=0,hh=0,dd=0;reg [23:0] old_rgb=0;
 integer fd=0,count=0,total=0,page,yy,xx;reg [3:0] pg;reg [1:0] md;
 always @(posedge clk)if(rst)begin
  #1;
  if({ov,oh,od}!=={vv,hh,dd})$fatal(1,"UI overlay two-stage controls");
  if(od)begin
   if((^data)===1'bx)$fatal(1,"Unknown UI pixel");
   if(count%1024==590 && (count/1024==120||count/1024==200||count/1024==280||count/1024==360))begin
    if(page==1&&data!==((count/1024==120)?24'h087f83:24'h26394d))$fatal(1,"Settings button background y=%0d got=%h",count/1024,data);
    if(page==3&&data!==((count/1024==280)?24'h087f83:24'h26394d))$fatal(1,"Preset button background");
   end
   if(page==2)begin
    if(count/1024==160&&count%1024==790&&data!==24'hdd6464)$fatal(1,"R gain bar filled range");
    if(count/1024==160&&count%1024==792&&data!==24'h34495e)$fatal(1,"R gain bar boundary");
    if(count/1024==230&&count%1024==727&&data!==24'h50bd86)$fatal(1,"G gain bar");
    if(count/1024==300&&count%1024==695&&data!==24'h609cea)$fatal(1,"B gain bar");
   end
   if(page==6&&count%1024==730&&count/1024==216&&data!==24'hffffff)$fatal(1,"B5 G6 cursor position");
   if(page==6&&count==500000&&(dut.ab!=-5||dut.gm!=6))$fatal(1,"Axis config changed mid-frame");
   if(count%1024==100&&count/1024==100&&data!==old_rgb)$fatal(1,"Live preview altered");
   $fwrite(fd,"%c%c%c",data[23:16],data[15:8],data[7:0]);count=count+1;total=total+1;
  end
  vv=v;hh=h;dd=de;old_rgb=rgb;
 end
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(page=0;page<9;page=page+1)begin
   pg=page;md=(page==4||page==6)?2:(page==3)?1:0;
   cfg={1'b0,(page==6)?5'b11011:5'd0,(page==6)?5'd6:5'd0,1'b1,1'b1,pg,md,2'd2,7'd40,7'd80,3'd2,1'b1};
   fd=$fopen($sformatf("ui_page_%0d.ppm",page),"wb");$fwrite(fd,"P6\n1024 600\n255\n");count=0;
   v=1;repeat(3)@(negedge clk);v=0;repeat(3)@(negedge clk);
   for(yy=0;yy<600;yy=yy+1)begin
    for(xx=0;xx<1024;xx=xx+1)begin
     de=1;h=0;rgb={xx[9:2],yy[9:2],8'h90};@(negedge clk);
     // A state request mid-frame must not tear this rendered page.
     if(yy==300&&xx==500)cfg={1'b0,5'd0,5'd0,1'b0,1'b0,4'd0,2'd0,2'd1,7'd30,7'd80,3'd0,1'b1};
    end
    de=0;h=1;repeat(3)@(negedge clk);h=0;
   end
   repeat(5)@(negedge clk);$fclose(fd);
   if(count!=614400)$fatal(1,"UI frame count %0d",count);
  end
  $display("PASS nine Chinese UI pages, exact overlay control latency, frame-latched configuration and exported RTL screenshots");$finish;
 end
 initial begin #50000000;$fatal(1,"Overlay watchdog");end
endmodule
