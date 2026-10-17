// Two-stage RGB overlay; UI config is captured once per display frame.
module wb_ui_overlay #(parameter FONT_FILE="../../../user_source/hdl_source/ui/wb_ui_font.hex")(
 input wire I_clk,I_rst_n,input wire [38:0] I_config,
 input wire [36:0] I_telemetry,
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
 if(!I_rst_n)begin telemetry_cfg<={1'b0,12'd1024,12'd1024,12'd1024};cfg<=CONFIG_RESET;vs_d<=0;de_d<=0;pending<=1;x_count<=0;y_count<=0;end
 else begin
  vs_d<=I_vsync;de_d<=I_de;
  if(frame_start)begin x_count<=I_de?11'd1:11'd0;y_count<=0;pending<=1;end
  else begin
   if(I_de)x_count<=x_count+1'b1;else x_count<=0;
   if(de_d&&!I_de)y_count<=y_count+1'b1;
  end
  if(I_de&&(pending||frame_start))begin cfg<=I_config;telemetry_cfg<=I_telemetry;pending<=0;end
 end
     localparam [7:0] DIGIT_0=8'd3;
    localparam [7:0] DIGIT_1=8'd4;
    localparam [7:0] DIGIT_7=8'd10;
    localparam [7:0] DIGIT_3=8'd6;
    localparam [7:0] LETTER_K=8'd18;
    localparam [7:0] CHAR_ZENG=8'd52;
    localparam [7:0] CHAR_YI=8'd108;
    localparam [7:0] CHAR_SLASH=8'd2;
    localparam [7:0] CHAR_DOT=8'd1;
    localparam [7:0] CHAR_BEI=8'd29;
    localparam [7:0] CHAR_R=8'd23;
    localparam [7:0] CHAR_G=8'd16;
    localparam [7:0] CHAR_B=8'd14;
    localparam [7:0] CHAR_A=8'd13;
    localparam [7:0] CHAR_M=8'd19;
    localparam [7:0] CHAR_AN=8'd77;
    localparam [7:0] CHAR_JIAN=8'd140;
    function [7:0] digit_glyph(input [3:0] n);begin case(n)
        4'd0:digit_glyph=8'd3;
        4'd1:digit_glyph=8'd4;
        4'd2:digit_glyph=8'd5;
        4'd3:digit_glyph=8'd6;
        4'd4:digit_glyph=8'd7;
        4'd5:digit_glyph=8'd8;
        4'd6:digit_glyph=8'd9;
        4'd7:digit_glyph=8'd10;
        4'd8:digit_glyph=8'd11;
        4'd9:digit_glyph=8'd12;
        default:digit_glyph=8'd0;endcase end endfunction
    function [7:0] glyph(input [5:0] text_id,input [5:0] pos);
        begin
            glyph=8'd0;
            case(text_id)
            6'd0:case(pos)
                6'd0:glyph=8'd107;
                6'd1:glyph=8'd61;
                6'd2:glyph=8'd123;
                6'd3:glyph=8'd98;
                6'd4:glyph=8'd110;
                default:;endcase
            6'd1:case(pos)
                6'd0:glyph=8'd90;
                6'd1:glyph=8'd66;
                6'd2:glyph=8'd150;
                6'd3:glyph=8'd120;
                6'd4:glyph=8'd41;
                default:;endcase
            6'd2:case(pos)
                6'd0:glyph=8'd90;
                6'd1:glyph=8'd66;
                6'd2:glyph=8'd150;
                6'd3:glyph=8'd103;
                6'd4:glyph=8'd51;
                6'd5:glyph=8'd147;
                6'd6:glyph=8'd128;
                default:;endcase
            6'd3:case(pos)
                6'd0:glyph=8'd90;
                6'd1:glyph=8'd66;
                6'd2:glyph=8'd150;
                6'd3:glyph=8'd120;
                6'd4:glyph=8'd55;
                6'd5:glyph=8'd27;
                default:;endcase
            6'd4:case(pos)
                6'd0:glyph=8'd142;
                6'd1:glyph=8'd77;
                6'd2:glyph=8'd106;
                6'd3:glyph=8'd146;
                6'd4:glyph=8'd135;
                6'd5:glyph=8'd34;
                6'd6:glyph=8'd128;
                6'd7:glyph=8'd118;
                default:;endcase
            6'd5:case(pos)
                6'd0:glyph=8'd48;
                6'd1:glyph=8'd137;
                default:;endcase
            6'd6:case(pos)
                6'd0:glyph=8'd107;
                6'd1:glyph=8'd61;
                6'd2:glyph=8'd123;
                6'd3:glyph=8'd128;
                6'd4:glyph=8'd118;
                default:;endcase
            6'd7:case(pos)
                6'd0:glyph=8'd120;
                6'd1:glyph=8'd41;
                6'd2:glyph=8'd107;
                6'd3:glyph=8'd61;
                6'd4:glyph=8'd123;
                default:;endcase
            6'd8:case(pos)
                6'd0:glyph=8'd103;
                6'd1:glyph=8'd51;
                6'd2:glyph=8'd147;
                6'd3:glyph=8'd128;
                default:;endcase
            6'd9:case(pos)
                6'd0:glyph=8'd74;
                6'd1:glyph=8'd41;
                6'd2:glyph=8'd107;
                6'd3:glyph=8'd61;
                6'd4:glyph=8'd123;
                default:;endcase
            6'd10:case(pos)
                6'd0:glyph=8'd72;
                6'd1:glyph=8'd33;
                6'd2:glyph=8'd64;
                default:;endcase
            6'd11:case(pos)
                6'd0:glyph=8'd120;
                6'd1:glyph=8'd41;
                6'd2:glyph=8'd90;
                6'd3:glyph=8'd66;
                6'd4:glyph=8'd59;
                6'd5:glyph=8'd47;
                6'd6:glyph=8'd105;
                default:;endcase
            6'd12:case(pos)
                6'd0:glyph=8'd120;
                6'd1:glyph=8'd41;
                6'd2:glyph=8'd138;
                6'd3:glyph=8'd63;
                6'd4:glyph=8'd103;
                6'd5:glyph=8'd51;
                6'd6:glyph=8'd33;
                default:;endcase
            6'd13:case(pos)
                6'd0:glyph=8'd37;
                6'd1:glyph=8'd78;
                6'd2:glyph=8'd33;
                6'd3:glyph=8'd95;
                6'd4:glyph=8'd46;
                6'd5:glyph=8'd112;
                6'd6:glyph=8'd30;
                default:;endcase
            6'd14:case(pos)
                6'd0:glyph=8'd139;
                6'd1:glyph=8'd76;
                6'd2:glyph=8'd33;
                6'd3:glyph=8'd101;
                6'd4:glyph=8'd103;
                6'd5:glyph=8'd51;
                default:;endcase
            6'd15:case(pos)
                6'd0:glyph=8'd84;
                6'd1:glyph=8'd121;
                6'd2:glyph=8'd100;
                6'd3:glyph=8'd33;
                6'd4:glyph=8'd0;
                6'd5:glyph=8'd6;
                6'd6:glyph=8'd3;
                6'd7:glyph=8'd3;
                6'd8:glyph=8'd3;
                6'd9:glyph=8'd18;
                default:;endcase
            6'd16:case(pos)
                6'd0:glyph=8'd82;
                6'd1:glyph=8'd33;
                6'd2:glyph=8'd0;
                6'd3:glyph=8'd8;
                6'd4:glyph=8'd8;
                6'd5:glyph=8'd3;
                6'd6:glyph=8'd3;
                6'd7:glyph=8'd18;
                default:;endcase
            6'd17:case(pos)
                6'd0:glyph=8'd144;
                6'd1:glyph=8'd54;
                6'd2:glyph=8'd0;
                6'd3:glyph=8'd9;
                6'd4:glyph=8'd8;
                6'd5:glyph=8'd3;
                6'd6:glyph=8'd3;
                6'd7:glyph=8'd18;
                default:;endcase
            6'd18:case(pos)
                6'd0:glyph=8'd144;
                6'd1:glyph=8'd69;
                6'd2:glyph=8'd0;
                6'd3:glyph=8'd10;
                6'd4:glyph=8'd8;
                6'd5:glyph=8'd3;
                6'd6:glyph=8'd3;
                6'd7:glyph=8'd18;
                default:;endcase
            6'd19:case(pos)
                6'd0:glyph=8'd75;
                6'd1:glyph=8'd41;
                6'd2:glyph=8'd96;
                6'd3:glyph=8'd87;
                6'd4:glyph=8'd130;
                6'd5:glyph=8'd122;
                6'd6:glyph=8'd121;
                6'd7:glyph=8'd94;
                default:;endcase
            6'd20:case(pos)
                6'd0:glyph=8'd5;
                6'd1:glyph=8'd8;
                6'd2:glyph=8'd3;
                6'd3:glyph=8'd3;
                6'd4:glyph=8'd18;
                default:;endcase
            6'd21:case(pos)
                6'd0:glyph=8'd4;
                6'd1:glyph=8'd3;
                6'd2:glyph=8'd3;
                6'd3:glyph=8'd3;
                6'd4:glyph=8'd3;
                6'd5:glyph=8'd18;
                default:;endcase
            6'd22:case(pos)
                6'd0:glyph=8'd72;
                6'd1:glyph=8'd33;
                6'd2:glyph=8'd64;
                default:;endcase
            6'd23:case(pos)
                6'd0:glyph=8'd36;
                6'd1:glyph=8'd57;
                default:;endcase
            6'd24:case(pos)
                6'd0:glyph=8'd52;
                6'd1:glyph=8'd40;
                default:;endcase
            6'd25:case(pos)
                6'd0:glyph=8'd71;
                6'd1:glyph=8'd53;
                6'd2:glyph=8'd149;
                6'd3:glyph=8'd127;
                default:;endcase
            6'd26:case(pos)
                6'd0:glyph=8'd125;
                6'd1:glyph=8'd58;
                6'd2:glyph=8'd86;
                6'd3:glyph=8'd136;
                6'd4:glyph=8'd79;
                default:;endcase
            6'd27:case(pos)
                6'd0:glyph=8'd56;
                6'd1:glyph=8'd83;
                6'd2:glyph=8'd147;
                6'd3:glyph=8'd124;
                default:;endcase
            6'd30:case(pos)
                6'd0:glyph=8'd92;
                6'd1:glyph=8'd89;
                6'd2:glyph=8'd0;
                6'd3:glyph=8'd4;
                6'd4:glyph=8'd3;
                6'd5:glyph=8'd3;
                6'd6:glyph=8'd18;
                default:;endcase
            6'd31:case(pos)
                6'd0:glyph=8'd56;
                6'd1:glyph=8'd28;
                6'd2:glyph=8'd77;
                6'd3:glyph=8'd140;
                6'd4:glyph=8'd45;
                6'd5:glyph=8'd91;
                6'd6:glyph=8'd44;
                6'd7:glyph=8'd105;
                default:;endcase
            6'd32:case(pos)
                6'd0:glyph=8'd4;
                6'd1:glyph=8'd29;
                default:;endcase
            6'd33:case(pos)
                6'd0:glyph=8'd5;
                6'd1:glyph=8'd29;
                default:;endcase
            6'd34:case(pos)
                6'd0:glyph=8'd7;
                6'd1:glyph=8'd29;
                default:;endcase
            6'd35:case(pos)
                6'd0:glyph=8'd109;
                6'd1:glyph=8'd88;
                6'd2:glyph=8'd129;
                6'd3:glyph=8'd38;
                default:;endcase
            6'd36:case(pos)
                6'd0:glyph=8'd65;
                6'd1:glyph=8'd47;
                default:;endcase
            6'd37:case(pos)
                6'd0:glyph=8'd35;
                6'd1:glyph=8'd143;
                default:;endcase
            6'd38:case(pos)
                6'd0:glyph=8'd104;
                6'd1:glyph=8'd28;
                6'd2:glyph=8'd73;
                6'd3:glyph=8'd81;
                6'd4:glyph=8'd50;
                default:;endcase
            6'd39:case(pos)
                6'd0:glyph=8'd121;
                6'd1:glyph=8'd68;
                6'd2:glyph=8'd31;
                6'd3:glyph=8'd111;
                default:;endcase
            6'd40:case(pos)
                6'd0:glyph=8'd67;
                6'd1:glyph=8'd145;
                default:;endcase
            6'd41:case(pos)
                6'd0:glyph=8'd116;
                6'd1:glyph=8'd126;
                6'd2:glyph=8'd85;
                6'd3:glyph=8'd80;
                default:;endcase
            6'd42:case(pos)
                6'd0:glyph=8'd114;
                6'd1:glyph=8'd70;
                6'd2:glyph=8'd113;
                6'd3:glyph=8'd55;
                6'd4:glyph=8'd60;
                default:;endcase
            6'd43:case(pos)
                6'd0:glyph=8'd14;
                default:;endcase
            6'd44:case(pos)
                6'd0:glyph=8'd13;
                default:;endcase
            6'd45:case(pos)
                6'd0:glyph=8'd16;
                default:;endcase
            6'd46:case(pos)
                6'd0:glyph=8'd19;
                default:;endcase
            6'd53:case(pos)
                6'd0:glyph=8'd97;
                6'd1:glyph=8'd141;
                6'd2:glyph=8'd62;
                default:;endcase
            6'd54:case(pos)
                6'd0:glyph=8'd39;
                6'd1:glyph=8'd119;
                6'd2:glyph=8'd62;
                default:;endcase
            6'd55:case(pos)
                6'd0:glyph=8'd43;
                6'd1:glyph=8'd49;
                default:;endcase
            6'd56:case(pos)
                6'd0:glyph=8'd148;
                6'd1:glyph=8'd107;
                default:;endcase
            6'd57:case(pos)
                6'd0:glyph=8'd41;
                6'd1:glyph=8'd99;
                default:;endcase
            6'd58:case(pos)
                6'd0:glyph=8'd131;
                6'd1:glyph=8'd102;
                default:;endcase
            6'd59:case(pos)
                6'd0:glyph=8'd32;
                6'd1:glyph=8'd115;
                6'd2:glyph=8'd106;
                default:;endcase
            6'd60:case(pos)
                6'd0:glyph=8'd134;
                6'd1:glyph=8'd117;
                default:;endcase
            6'd61:case(pos)
                6'd0:glyph=8'd93;
                6'd1:glyph=8'd42;
                6'd2:glyph=8'd0;
                6'd3:glyph=8'd25;
                6'd4:glyph=8'd13;
                6'd5:glyph=8'd16;
                default:;endcase
            6'd62:case(pos)
                6'd0:glyph=8'd109;
                6'd1:glyph=8'd88;
                6'd2:glyph=8'd132;
                6'd3:glyph=8'd133;
                default:;endcase
            6'd63:case(pos)
                6'd0:glyph=8'd15;
                6'd1:glyph=8'd22;
                6'd2:glyph=8'd16;
                6'd3:glyph=8'd13;
                6'd4:glyph=8'd0;
                6'd5:glyph=8'd26;
                6'd6:glyph=8'd17;
                6'd7:glyph=8'd24;
                6'd8:glyph=8'd17;
                6'd9:glyph=8'd21;
                6'd10:glyph=8'd20;
                default:;endcase
            6'd28:case(pos)
                0:if(k_units>=100)glyph=DIGIT_1;
                1:glyph=digit_glyph((k_units/10)%10);
                2:glyph=digit_glyph(k_units%10);
                3,4:glyph=DIGIT_0;
                5:glyph=LETTER_K;
                default:;endcase
            6'd29:case(pos)
                0:glyph=digit_glyph(gain100/100);
                1:glyph=CHAR_DOT;
                2:glyph=digit_glyph((gain100/10)%10);
                3:glyph=digit_glyph(gain100%10);
                4:glyph=CHAR_BEI;
                default:;endcase
            6'd47,6'd48,6'd49:case(pos)
                0:glyph=(text_id==47)?CHAR_R:(text_id==48)?CHAR_G:CHAR_B;
                2:glyph=digit_glyph(((text_id==47)?tr100:(text_id==48)?tg100:tb100)/100);
                3:glyph=CHAR_DOT;
                4:glyph=digit_glyph((((text_id==47)?tr100:(text_id==48)?tg100:tb100)/10)%10);
                5:glyph=digit_glyph(((text_id==47)?tr100:(text_id==48)?tg100:tb100)%10);
                6:glyph=CHAR_BEI;
                default:;endcase
            6'd52:case(pos)
                0:glyph=CHAR_AN;1:glyph=CHAR_JIAN;
                3:glyph=active[38]?CHAR_G:CHAR_B;
                4:glyph=active[38]?CHAR_M:CHAR_A;
                default:;endcase
            6'd50:case(pos)
                0:glyph=ab<0?CHAR_B:CHAR_A;
                1:glyph=digit_glyph(ab<0?-ab:ab);
                default:;endcase
            6'd51:case(pos)
                0:glyph=gm<0?CHAR_M:CHAR_G;
                1:glyph=digit_glyph(gm<0?-gm:gm);
                default:;endcase
            default:;
            endcase
        end
    endfunction

 function automatic in_rect(input [10:0] px,py,input integer left,top,right,bottom);
  begin in_rect=px>=left&&px<right&&py>=top&&py<bottom;end
 endfunction
 reg [23:0] background,foreground;
 reg text_on;
 reg [5:0] text_id;
 reg [10:0] origin_x,origin_y;
 reg [10:0] dx,dy;
 reg [5:0] char_pos;
 reg [4:0] char_col,char_row;
 reg [7:0] char_glyph;
 reg [12:0] font_addr;
 task automatic label(input [5:0] id,input integer lx,ly,length);
  begin if(in_rect(x,y,lx,ly,lx+length*24,ly+24))begin text_on=1;text_id=id;origin_x=lx;origin_y=ly;end end
 endtask
 always @(*)begin
  background=I_data;foreground=24'hf3f6fa;text_on=0;text_id=0;origin_x=0;origin_y=0;
  if(page==0)begin
   if(y<64||y>=548)background={2'b0,I_data[23:18],2'b0,I_data[15:10],2'b0,I_data[7:2]};
   label(mode==0?1:mode==1?2:3,16,20,8);
   if(mode!=0)label(28,240,20,6);
   label(image_mode==0?55:image_mode==1?56:image_mode==2?57:image_mode==3?58:image_mode==4?59:60,400,20,4);
   if(tag_enable)label(63,600,20,11);
   label(29,864,20,5);
   label(4,16,562,8);
   if(!online)label(26,736,562,5);
  end else begin
   if(x>=560)background=24'h111e2c;
   if(in_rect(x,y,584,24,688,80))background=24'h34495e;
   label(5,612,44,2);
   label(page==1?6:page==2?7:page==3?8:page==4?9:page==6?39:page==7?53:page==8?54:10,720,44,6);
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
    end
    2:begin
     label(47,600,120,7);label(48,600,190,7);label(49,600,260,7);
     if(x>=600&&x<984&&y>=154&&y<166)background=x<(600+(telemetry[35:24]>>3))?24'hdd6464:24'h34495e;
     if(x>=600&&x<984&&y>=224&&y<236)background=x<(600+(telemetry[23:12]>>3))?24'h50bd86:24'h34495e;
     if(x>=600&&x<984&&y>=294&&y<306)background=x<(600+(telemetry[11:0]>>3))?24'h609cea:24'h34495e;
     label(telemetry[36]?41:42,600,332,5);
     if(in_rect(x,y,600,400,1000,472))background=detect_enable?24'h087f83:24'h26394d;
     label(35,620,424,4);label(detect_enable?36:37,916,424,2);
     label(38,600,504,5);
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
    end
    8:begin
     if(in_rect(x,y,584,112,1000,176))background=tag_enable?24'h087f83:24'h26394d;
     if(in_rect(x,y,584,192,1000,256))background=detect_enable?24'h087f83:24'h26394d;
     label(61,620,132,6);label(tag_enable?36:37,916,132,2);
     label(62,620,212,4);label(detect_enable?36:37,916,212,2);
     label(38,600,292,5);
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
