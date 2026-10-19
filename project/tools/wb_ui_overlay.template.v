// Two-stage RGB overlay; UI config is captured once per display frame.
module wb_ui_overlay #(parameter FONT_FILE="../../../user_source/hdl_source/ui/wb_ui_font.hex")(
 input wire I_clk,I_rst_n,input wire [38:0] I_config,
 input wire [36:0] I_telemetry,
 input wire [8:0] I_latency,
 input wire [23:0] I_diagnostics,input wire [7:0] I_underflow,
 input wire I_vsync,I_hsync,I_de,input wire [23:0] I_data,
 output reg O_vsync,O_hsync,O_de,output reg [23:0] O_data
);
 localparam [38:0] CONFIG_RESET={1'b0,5'd0,5'd0,1'b0,1'b0,4'd0,
                                  2'd0,2'd1,7'd30,7'd80,3'd0,1'b0};
 reg [38:0] cfg;
 reg vs_d,de_d,pending;
 reg [10:0] x_count,y_count;
 wire frame_start=I_vsync&&!vs_d;
 wire [10:0] x=frame_start?11'd0:x_count,y=frame_start?11'd0:y_count;
 // Use the incoming stable mailbox value also on a coincident first pixel.
 wire [38:0] active=(pending||frame_start)?I_config:cfg;
 reg [36:0] telemetry_cfg;
 wire [36:0] telemetry=(pending||frame_start)?I_telemetry:telemetry_cfg;
 reg [8:0] latency_cfg;
 wire [8:0] latency=(pending||frame_start)?I_latency:latency_cfg;
 reg [23:0] diagnostics_cfg;reg [7:0] underflow_cfg;
 wire [23:0] diagnostics=(pending||frame_start)?I_diagnostics:diagnostics_cfg;
 wire [7:0] underflow=(pending||frame_start)?I_underflow:underflow_cfg;
 wire latency_valid=latency[8];
 wire [7:0] latency_frames=latency[7:0];
 // Eight shift/add-3 steps turn an 8-bit counter into three BCD digits.
 function [11:0] bcd8(input [7:0] value);
  integer bit_index;reg [11:0] digits;
  begin
   digits=0;
   for(bit_index=7;bit_index>=0;bit_index=bit_index-1)begin
    if(digits[3:0]>4)digits[3:0]=digits[3:0]+4'd3;
    if(digits[7:4]>4)digits[7:4]=digits[7:4]+4'd3;
    if(digits[11:8]>4)digits[11:8]=digits[11:8]+4'd3;
    digits={digits[10:0],value[bit_index]};
   end
   bcd8=digits;
  end
 endfunction
 wire [11:0] latency_bcd=bcd8(latency_frames);
 wire [11:0] peak_bcd=bcd8(diagnostics[23:16]);
 wire [11:0] drop_bcd=bcd8(diagnostics[15:8]);
 wire [11:0] overflow_bcd=bcd8(diagnostics[7:0]);
 wire [11:0] underflow_bcd=bcd8(underflow);
 wire signed [4:0] ab=active[37:33],gm=active[32:28];
 wire signed [10:0] point_x=11'sd800+$signed(ab)*11'sd14;
 wire signed [10:0] point_y=11'sd300-$signed(gm)*11'sd14;
 wire [21:0] rr=telemetry[35:24]*22'd100+22'd512;
 wire [21:0] rg=telemetry[23:12]*22'd100+22'd512;
 wire [21:0] rb=telemetry[11:0]*22'd100+22'd512;
 wire [9:0] tr100=rr[19:10],tg100=rg[19:10],tb100=rb[19:10];
 wire [3:0] page=active[25:22];wire [1:0] mode=active[21:20],preset=active[19:18];
 wire [6:0] index=active[17:11],gain=active[10:4];wire [2:0] image_mode=active[3:1];
 wire online=active[0],tag_enable=active[26],detect_enable=active[27];
 wire [7:0] k_units={1'b0,index}+8'd25;
 wire [6:0] gain_level=(gain<16)?7'd0:gain-7'd16;
 wire [15:0] gain_scaled=(gain<48)?((gain+16'd16)*16'd25+16'd4)>>3:
                            (gain<80)?((gain-16'd16)*16'd25+16'd2)>>2:
                                      ((gain-16'd48)*16'd25+16'd1)>>1;
 wire [9:0] gain100=gain_scaled[9:0];
 wire [10:0] thumb_x=11'd600+index*11'd5;
 wire [10:0] gain_x=11'd600+gain_level*11'd5;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin latency_cfg<=0;diagnostics_cfg<=0;underflow_cfg<=0;telemetry_cfg<={1'b0,12'd1024,12'd1024,12'd1024};cfg<=CONFIG_RESET;vs_d<=0;de_d<=0;pending<=1;x_count<=0;y_count<=0;end
 else begin
  vs_d<=I_vsync;de_d<=I_de;
  if(frame_start)begin x_count<=I_de?11'd1:11'd0;y_count<=0;pending<=1;end
  else begin
   if(I_de)x_count<=x_count+1'b1;else x_count<=0;
   if(de_d&&!I_de)y_count<=y_count+1'b1;
  end
  if(I_de&&(pending||frame_start))begin cfg<=I_config;telemetry_cfg<=I_telemetry;latency_cfg<=I_latency;diagnostics_cfg<=I_diagnostics;underflow_cfg<=I_underflow;pending<=0;end
 end
 // GENERATED_GLYPHS
 function automatic in_rect(input [10:0] px,py,input integer left,top,right,bottom);
  begin in_rect=px>=left&&px<right&&py>=top&&py<bottom;end
 endfunction
 reg [23:0] background,foreground;
 reg text_on;
 reg [6:0] text_id;
 reg [10:0] origin_x,origin_y;
 reg [10:0] dx,dy;
 reg [5:0] char_pos;
 reg [4:0] char_col,char_row;
 reg [7:0] char_glyph;
 reg [12:0] font_addr;
 task automatic label(input [6:0] id,input integer lx,ly,length);
  begin if(in_rect(x,y,lx,ly,lx+length*24,ly+24))begin text_on=1;text_id=id;origin_x=lx;origin_y=ly;end end
 endtask
 always @(*)begin
  background=I_data;foreground=24'hf3f6fa;text_on=0;text_id=0;origin_x=0;origin_y=0;
  if(page==0)begin
   if(y<64||y>=548)background={2'b0,I_data[23:18],2'b0,I_data[15:10],2'b0,I_data[7:2]};
   label(mode==0?1:mode==1?2:3,176,20,8);
   if(mode!=0)label(28,400,20,6);
   label(image_mode==0?55:image_mode==1?56:image_mode==2?57:image_mode==3?58:image_mode==4?59:image_mode==5?60:image_mode==6?63:38,600,20,4);

   label(29,864,20,5);
   label(4,16,562,8);
   label(64,520,562,8);
   if(in_rect(x,y,520,562,712,586))
    foreground=!latency_valid?24'h8a96a5:(latency_frames<=2)?24'h16b8ad:(latency_frames<=4)?24'hffaa55:24'hdd6464;
   if(!online)label(26,736,562,5);
  end else begin
   if(x>=560)background=24'h111e2c;
   if(in_rect(x,y,584,24,688,80))background=24'h34495e;
   label(5,612,44,2);
   label(page==1?6:page==2?7:page==3?8:page==4?9:page==6?39:page==7?53:page==8?54:page==9?65:10,720,44,6);
   label(27,16,562,4);
   case(page)
    1:begin
     if(in_rect(x,y,584,112,1000,176))background=(mode==0)?24'h087f83:24'h26394d;
     if(in_rect(x,y,584,192,1000,256))background=(mode==1)?24'h087f83:24'h26394d;
     if(in_rect(x,y,584,272,1000,336))background=(mode==2)?24'h087f83:24'h26394d;
     if(in_rect(x,y,584,352,1000,416))background=24'h26394d;
     if(in_rect(x,y,584,432,784,496)||in_rect(x,y,800,432,1000,496))background=24'h26394d;
     label(7,620,132,5);label(8,620,212,4);label(9,620,292,5);label(10,620,372,3);
     label(53,648,452,3);label(54,864,452,3);
     if(in_rect(x,y,584,504,1000,556))background=24'h26394d;
     label(65,732,518,4);
    end
    2:begin
     label(47,600,120,7);label(48,600,190,7);label(49,600,260,7);
     if(x>=600&&x<984&&y>=154&&y<166)background=x<(600+(telemetry[35:24]>>3))?24'hdd6464:24'h34495e;
     if(x>=600&&x<984&&y>=224&&y<236)background=x<(600+(telemetry[23:12]>>3))?24'h50bd86:24'h34495e;
     if(x>=600&&x<984&&y>=294&&y<306)background=x<(600+(telemetry[11:0]>>3))?24'h609cea:24'h34495e;
     label(telemetry[36]?41:42,600,332,5);
     if(in_rect(x,y,600,400,1000,472))background=detect_enable?24'h087f83:24'h26394d;
     label(35,620,424,4);label(detect_enable?36:37,916,424,2);

    end
    3:begin
     if(in_rect(x,y,584,112,1000,176))background=(mode==1&&preset==0)?24'h087f83:24'h26394d;
     if(in_rect(x,y,584,192,1000,256))background=(mode==1&&preset==1)?24'h087f83:24'h26394d;
     if(in_rect(x,y,584,272,1000,336))background=(mode==1&&preset==2)?24'h087f83:24'h26394d;
     if(in_rect(x,y,584,352,1000,416))background=(mode==1&&preset==3)?24'h087f83:24'h26394d;
     label(15,620,132,12);label(16,620,212,8);label(17,620,292,8);label(18,620,372,8);
     label(14,600,464,6);
    end
    4:begin
     label(19,600,116,9);label(28,720,184,6);
     if(in_rect(x,y,600,284,976,300))background=x<=thumb_x?24'h16b8ad:24'h3e5369;
     if(x+8>=thumb_x&&x<thumb_x+8&&y>=272&&y<312)background=24'hf4f7fa;
     label(20,600,344,5);label(21,856,344,6);label(30,600,424,7);
     if(x>=584&&x<1000&&y>=472&&y<536)background=24'h087f83;
     label(39,744,492,4);
    end
    6:begin
     if(x>=674&&x<=926&&y>=174&&y<=426)begin
      background=24'h0a1018;
      if(((x-674)%14)==0||((y-174)%14)==0)background=24'h34495e;
      if(x==800||y==300)background=24'h8a96a5;
     end
     if(x>=671&&x<674&&y>=171&&y<430)background=24'h3d68df;
     if(x>=927&&x<930&&y>=171&&y<430)background=24'hffaa55;
     if(x>=671&&x<930&&y>=171&&y<174)background=24'h16b86a;
     if(x>=671&&x<930&&y>=427&&y<430)background=24'hd45abb;
     if(x+5>=point_x&&x<point_x+6&&y+5>=point_y&&y<point_y+6)background=24'h000000;
     if(x+3>=point_x&&x<point_x+4&&y+3>=point_y&&y<point_y+4)background=24'hffffff;
     if(x>=584&&x<656&&y>=268&&y<332)background=24'h26394d;
     if(x>=944&&x<1016&&y>=268&&y<332)background=24'h26394d;
     if(x>=768&&x<832&&y>=104&&y<164)background=24'h26394d;
     if(x>=768&&x<832&&y>=436&&y<496)background=24'h26394d;
     label(43,608,288,1);label(44,968,288,1);label(45,788,122,1);label(46,788,454,1);
     label(50,592,116,2);label(51,920,116,2);
     if(x>=588&&x<644&&y>=144&&y<148&&!active[38])background=24'h16b8ad;
     if(x>=916&&x<972&&y>=144&&y<148&&active[38])background=24'h16b8ad;
     label(52,584,490,5);
     if(x>=584&&x<1000&&y>=520&&y<576)background=24'h087f83;
     label(40,768,540,2);
    end
    5:begin
     if(x>=584&&x<712&&y>=112&&y<168)background=(gain==16)?24'h087f83:24'h26394d;
     if(x>=728&&x<856&&y>=112&&y<168)background=(gain==48)?24'h087f83:24'h26394d;
     if(x>=872&&x<1000&&y>=112&&y<168)background=(gain==80)?24'h087f83:24'h26394d;
     label(32,624,128,2);label(33,768,128,2);label(34,912,128,2);
     label(29,732,196,5);
     if(in_rect(x,y,600,250,966,266))background=x<=gain_x?24'h16b8ad:24'h3e5369;
     if(in_rect(x,y,608,300,736,388)||in_rect(x,y,856,300,984,388))background=24'h087f83;
     label(23,648,332,2);label(24,888,332,2);
     if(in_rect(x,y,584,432,1000,488))background=24'h26394d;
     label(25,744,448,4);label(31,600,524,8);
    end
    7:begin
     if(in_rect(x,y,584,112,784,176))background=(image_mode==0)?24'h087f83:24'h26394d;
     if(in_rect(x,y,800,112,1000,176))background=(image_mode==1)?24'h087f83:24'h26394d;
     if(in_rect(x,y,584,192,784,256))background=(image_mode==2)?24'h087f83:24'h26394d;
     if(in_rect(x,y,800,192,1000,256))background=(image_mode==3)?24'h087f83:24'h26394d;
     if(in_rect(x,y,584,272,784,336))background=(image_mode==4)?24'h087f83:24'h26394d;
     if(in_rect(x,y,800,272,1000,336))background=(image_mode==5)?24'h087f83:24'h26394d;
     label(55,648,132,2);label(56,864,132,2);
     label(57,648,212,2);label(58,864,212,2);
     label(59,636,292,3);label(60,864,292,2);
     if(in_rect(x,y,584,352,784,416))background=(image_mode==6)?24'h087f83:24'h26394d;
     if(in_rect(x,y,800,352,1000,416))background=(image_mode==7)?24'h087f83:24'h26394d;
     label(63,648,372,2);label(38,852,372,4);
    end
    8:begin
     if(in_rect(x,y,584,112,1000,176))background=tag_enable?24'h087f83:24'h26394d;
     if(in_rect(x,y,584,192,1000,256))background=detect_enable?24'h087f83:24'h26394d;
     label(61,620,132,6);label(tag_enable?36:37,916,132,2);
     label(62,620,212,4);label(detect_enable?36:37,916,212,2);

    end
    9:begin
     if(in_rect(x,y,584,112,1000,496))background=24'h1b2b3b;
     label(66,600,132,4);label(72,880,132,3);
     label(67,600,212,4);label(73,880,212,3);
     label(68,600,292,4);label(74,880,292,3);
     label(69,600,372,4);label(75,880,372,3);
     label(70,600,452,4);label(76,880,452,3);
     if(in_rect(x,y,880,132,952,156))foreground=!latency_valid?24'h8a96a5:(latency_frames<=2)?24'h16b8ad:(latency_frames<=4)?24'hffaa55:24'hdd6464;
     label(71,600,520,8);
    end
   endcase
  end
  dx=x-origin_x;dy=y-origin_y;char_pos=dx/24;char_col=dx%24;char_row=dy[4:0];
  char_glyph=glyph(text_id,char_pos);
  font_addr=text_on?{char_glyph,char_row}:13'd0;
 end
 wire [23:0] font_bits;
 wb_ui_font #(.FONT_FILE(FONT_FILE)) rom(.I_clk(I_clk),.I_addr(font_addr),.O_bits(font_bits));
 reg [23:0] bg_d,fg_d;reg [4:0] col_d;reg text_d,v_d,h_d,d_d;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  bg_d<=0;fg_d<=0;col_d<=0;text_d<=0;v_d<=0;h_d<=0;d_d<=0;
  O_vsync<=0;O_hsync<=0;O_de<=0;O_data<=0;
 end else begin
  bg_d<=background;fg_d<=foreground;col_d<=char_col;text_d<=text_on;
  v_d<=I_vsync;h_d<=I_hsync;d_d<=I_de;
  O_vsync<=v_d;O_hsync<=h_d;O_de<=d_d;
  O_data<=d_d?((text_d&&font_bits[23-col_d])?fg_d:bg_d):24'd0;
 end
endmodule
