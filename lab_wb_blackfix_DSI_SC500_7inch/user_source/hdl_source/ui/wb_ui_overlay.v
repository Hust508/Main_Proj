// Two-stage RGB overlay; UI config is captured once per display frame.
module wb_ui_overlay #(parameter FONT_FILE="../../../user_source/hdl_source/ui/wb_ui_font.hex")(
 input wire I_clk,I_rst_n,input wire [21:0] I_config,
 input wire I_vsync,I_hsync,I_de,input wire [23:0] I_data,
 output reg O_vsync,O_hsync,O_de,output reg [23:0] O_data
);
 reg [21:0] cfg;
 reg vs_d,de_d,pending;
 reg [10:0] x_count,y_count;
 wire frame_start=I_vsync&&!vs_d;
 wire [10:0] x=frame_start?11'd0:x_count,y=frame_start?11'd0:y_count;
 // Use the incoming stable mailbox value also on a coincident first pixel.
 wire [21:0] active=(pending||frame_start)?I_config:cfg;
 wire [2:0] page=active[21:19];wire [1:0] mode=active[18:17],preset=active[16:15];
 wire [6:0] index=active[14:8],gain=active[7:1];wire online=active[0];
 wire [7:0] k_units={1'b0,index}+8'd25;
 wire [6:0] gain_level=(gain<16)?7'd0:gain-7'd16;
 wire [15:0] gain_scaled=(gain<48)?((gain+16'd16)*16'd25+16'd4)>>3:
                            (gain<80)?((gain-16'd16)*16'd25+16'd2)>>2:
                                      ((gain-16'd48)*16'd25+16'd1)>>1;
 wire [9:0] gain100=gain_scaled[9:0];
 wire [10:0] thumb_x=11'd600+index*11'd5;
 wire [10:0] gain_x=11'd600+gain_level*11'd5;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin cfg<=22'd7840;vs_d<=0;de_d<=0;pending<=1;x_count<=0;y_count<=0;end
 else begin
  vs_d<=I_vsync;de_d<=I_de;
  if(frame_start)begin x_count<=I_de?11'd1:11'd0;y_count<=0;pending<=1;end
  else begin
   if(I_de)x_count<=x_count+1'b1;else x_count<=0;
   if(de_d&&!I_de)y_count<=y_count+1'b1;
  end
  if(I_de&&(pending||frame_start))begin cfg<=I_config;pending<=0;end
 end
     localparam DIGIT_0=7'd3;
    localparam DIGIT_1=7'd4;
    localparam DIGIT_7=7'd10;
    localparam DIGIT_3=7'd6;
    localparam LETTER_K=7'd13;
    localparam CHAR_ZENG=7'd30;
    localparam CHAR_YI=7'd69;
    localparam CHAR_SLASH=7'd2;
    localparam CHAR_DOT=7'd1;
    localparam CHAR_BEI=7'd16;
    function [6:0] digit_glyph(input [3:0] n);begin case(n)
        4'd0:digit_glyph=7'd3;
        4'd1:digit_glyph=7'd4;
        4'd2:digit_glyph=7'd5;
        4'd3:digit_glyph=7'd6;
        4'd4:digit_glyph=7'd7;
        4'd5:digit_glyph=7'd8;
        4'd6:digit_glyph=7'd9;
        4'd7:digit_glyph=7'd10;
        4'd8:digit_glyph=7'd11;
        4'd9:digit_glyph=7'd12;
        default:digit_glyph=7'd0;endcase end endfunction
    function [6:0] glyph(input [5:0] text_id,input [5:0] pos);
        begin
            glyph=7'd0;
            case(text_id)
            6'd0:case(pos)
                6'd0:glyph=7'd68;
                6'd1:glyph=7'd38;
                6'd2:glyph=7'd76;
                6'd3:glyph=7'd62;
                6'd4:glyph=7'd70;
                default:;endcase
            6'd1:case(pos)
                6'd0:glyph=7'd56;
                6'd1:glyph=7'd41;
                6'd2:glyph=7'd93;
                6'd3:glyph=7'd73;
                6'd4:glyph=7'd23;
                default:;endcase
            6'd2:case(pos)
                6'd0:glyph=7'd56;
                6'd1:glyph=7'd41;
                6'd2:glyph=7'd93;
                6'd3:glyph=7'd65;
                6'd4:glyph=7'd29;
                6'd5:glyph=7'd91;
                6'd6:glyph=7'd80;
                default:;endcase
            6'd3:case(pos)
                6'd0:glyph=7'd56;
                6'd1:glyph=7'd41;
                6'd2:glyph=7'd93;
                6'd3:glyph=7'd73;
                6'd4:glyph=7'd33;
                6'd5:glyph=7'd14;
                default:;endcase
            6'd4:case(pos)
                6'd0:glyph=7'd88;
                6'd1:glyph=7'd47;
                6'd2:glyph=7'd67;
                6'd3:glyph=7'd90;
                6'd4:glyph=7'd82;
                6'd5:glyph=7'd19;
                6'd6:glyph=7'd80;
                6'd7:glyph=7'd72;
                default:;endcase
            6'd5:case(pos)
                6'd0:glyph=7'd28;
                6'd1:glyph=7'd84;
                default:;endcase
            6'd6:case(pos)
                6'd0:glyph=7'd68;
                6'd1:glyph=7'd38;
                6'd2:glyph=7'd76;
                6'd3:glyph=7'd80;
                6'd4:glyph=7'd72;
                default:;endcase
            6'd7:case(pos)
                6'd0:glyph=7'd73;
                6'd1:glyph=7'd23;
                6'd2:glyph=7'd68;
                6'd3:glyph=7'd38;
                6'd4:glyph=7'd76;
                default:;endcase
            6'd8:case(pos)
                6'd0:glyph=7'd65;
                6'd1:glyph=7'd29;
                6'd2:glyph=7'd91;
                6'd3:glyph=7'd80;
                default:;endcase
            6'd9:case(pos)
                6'd0:glyph=7'd73;
                6'd1:glyph=7'd33;
                6'd2:glyph=7'd14;
                6'd3:glyph=7'd74;
                6'd4:glyph=7'd59;
                default:;endcase
            6'd10:case(pos)
                6'd0:glyph=7'd44;
                6'd1:glyph=7'd18;
                6'd2:glyph=7'd40;
                default:;endcase
            6'd11:case(pos)
                6'd0:glyph=7'd73;
                6'd1:glyph=7'd23;
                6'd2:glyph=7'd56;
                6'd3:glyph=7'd41;
                6'd4:glyph=7'd37;
                6'd5:glyph=7'd27;
                6'd6:glyph=7'd66;
                default:;endcase
            6'd12:case(pos)
                6'd0:glyph=7'd73;
                6'd1:glyph=7'd23;
                6'd2:glyph=7'd85;
                6'd3:glyph=7'd39;
                6'd4:glyph=7'd65;
                6'd5:glyph=7'd29;
                6'd6:glyph=7'd18;
                default:;endcase
            6'd13:case(pos)
                6'd0:glyph=7'd21;
                6'd1:glyph=7'd48;
                6'd2:glyph=7'd18;
                6'd3:glyph=7'd60;
                6'd4:glyph=7'd26;
                6'd5:glyph=7'd71;
                6'd6:glyph=7'd17;
                default:;endcase
            6'd14:case(pos)
                6'd0:glyph=7'd86;
                6'd1:glyph=7'd46;
                6'd2:glyph=7'd18;
                6'd3:glyph=7'd64;
                6'd4:glyph=7'd65;
                6'd5:glyph=7'd29;
                default:;endcase
            6'd15:case(pos)
                6'd0:glyph=7'd52;
                6'd1:glyph=7'd74;
                6'd2:glyph=7'd63;
                6'd3:glyph=7'd18;
                6'd4:glyph=7'd0;
                6'd5:glyph=7'd6;
                6'd6:glyph=7'd3;
                6'd7:glyph=7'd3;
                6'd8:glyph=7'd3;
                6'd9:glyph=7'd13;
                default:;endcase
            6'd16:case(pos)
                6'd0:glyph=7'd50;
                6'd1:glyph=7'd18;
                6'd2:glyph=7'd0;
                6'd3:glyph=7'd8;
                6'd4:glyph=7'd8;
                6'd5:glyph=7'd3;
                6'd6:glyph=7'd3;
                6'd7:glyph=7'd13;
                default:;endcase
            6'd17:case(pos)
                6'd0:glyph=7'd89;
                6'd1:glyph=7'd32;
                6'd2:glyph=7'd0;
                6'd3:glyph=7'd9;
                6'd4:glyph=7'd8;
                6'd5:glyph=7'd3;
                6'd6:glyph=7'd3;
                6'd7:glyph=7'd13;
                default:;endcase
            6'd18:case(pos)
                6'd0:glyph=7'd89;
                6'd1:glyph=7'd42;
                6'd2:glyph=7'd0;
                6'd3:glyph=7'd10;
                6'd4:glyph=7'd8;
                6'd5:glyph=7'd3;
                6'd6:glyph=7'd3;
                6'd7:glyph=7'd13;
                default:;endcase
            6'd19:case(pos)
                6'd0:glyph=7'd45;
                6'd1:glyph=7'd23;
                6'd2:glyph=7'd61;
                6'd3:glyph=7'd54;
                6'd4:glyph=7'd81;
                6'd5:glyph=7'd75;
                6'd6:glyph=7'd74;
                6'd7:glyph=7'd59;
                default:;endcase
            6'd20:case(pos)
                6'd0:glyph=7'd5;
                6'd1:glyph=7'd8;
                6'd2:glyph=7'd3;
                6'd3:glyph=7'd3;
                6'd4:glyph=7'd13;
                default:;endcase
            6'd21:case(pos)
                6'd0:glyph=7'd4;
                6'd1:glyph=7'd3;
                6'd2:glyph=7'd3;
                6'd3:glyph=7'd3;
                6'd4:glyph=7'd3;
                6'd5:glyph=7'd13;
                default:;endcase
            6'd22:case(pos)
                6'd0:glyph=7'd44;
                6'd1:glyph=7'd18;
                6'd2:glyph=7'd40;
                default:;endcase
            6'd23:case(pos)
                6'd0:glyph=7'd20;
                6'd1:glyph=7'd35;
                default:;endcase
            6'd24:case(pos)
                6'd0:glyph=7'd30;
                6'd1:glyph=7'd22;
                default:;endcase
            6'd25:case(pos)
                6'd0:glyph=7'd43;
                6'd1:glyph=7'd31;
                6'd2:glyph=7'd92;
                6'd3:glyph=7'd79;
                default:;endcase
            6'd26:case(pos)
                6'd0:glyph=7'd78;
                6'd1:glyph=7'd36;
                6'd2:glyph=7'd53;
                6'd3:glyph=7'd83;
                6'd4:glyph=7'd49;
                default:;endcase
            6'd27:case(pos)
                6'd0:glyph=7'd34;
                6'd1:glyph=7'd51;
                6'd2:glyph=7'd91;
                6'd3:glyph=7'd77;
                default:;endcase
            6'd30:case(pos)
                6'd0:glyph=7'd58;
                6'd1:glyph=7'd55;
                6'd2:glyph=7'd0;
                6'd3:glyph=7'd4;
                6'd4:glyph=7'd3;
                6'd5:glyph=7'd3;
                6'd6:glyph=7'd13;
                default:;endcase
            6'd31:case(pos)
                6'd0:glyph=7'd34;
                6'd1:glyph=7'd15;
                6'd2:glyph=7'd47;
                6'd3:glyph=7'd87;
                6'd4:glyph=7'd25;
                6'd5:glyph=7'd57;
                6'd6:glyph=7'd24;
                6'd7:glyph=7'd66;
                default:;endcase
            6'd32:case(pos)
                6'd0:glyph=7'd4;
                6'd1:glyph=7'd16;
                default:;endcase
            6'd33:case(pos)
                6'd0:glyph=7'd5;
                6'd1:glyph=7'd16;
                default:;endcase
            6'd34:case(pos)
                6'd0:glyph=7'd7;
                6'd1:glyph=7'd16;
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
 reg [6:0] char_glyph;
 reg [11:0] font_addr;
 task automatic label(input [5:0] id,input integer lx,ly,length);
  begin if(in_rect(x,y,lx,ly,lx+length*24,ly+24))begin text_on=1;text_id=id;origin_x=lx;origin_y=ly;end end
 endtask
 always @(*)begin
  background=I_data;foreground=24'hf3f6fa;text_on=0;text_id=0;origin_x=0;origin_y=0;
  if(page==0)begin
   if(y<64||y>=548)background={2'b0,I_data[23:18],2'b0,I_data[15:10],2'b0,I_data[7:2]};
   label(mode==0?1:mode==1?2:3,16,20,8);
   if(mode!=0)label(28,328,20,6);
   label(29,864,20,5);
   label(4,16,562,8);
   if(!online)label(26,736,562,5);
  end else begin
   if(x>=560)background=24'h111e2c;
   if(in_rect(x,y,584,24,688,80))background=24'h34495e;
   label(5,612,44,2);
   label(page==1?6:page==2?7:page==3?8:page==4?9:10,720,44,6);
   label(27,16,562,4);
   case(page)
    1:begin
     if(in_rect(x,y,584,112,1000,176))background=(mode==0)?24'h087f83:24'h26394d;
     if(in_rect(x,y,584,192,1000,256))background=(mode==1)?24'h087f83:24'h26394d;
     if(in_rect(x,y,584,272,1000,336))background=(mode==2)?24'h087f83:24'h26394d;
     if(in_rect(x,y,584,352,1000,416))background=24'h26394d;
     label(7,620,132,5);label(8,620,212,4);label(9,620,292,5);label(10,620,372,3);
    end
    2:begin
     label(11,600,144,7);label(12,600,208,7);label(13,600,272,7);
     if(in_rect(x,y,600,336,1000,344))background=24'h22b59a;
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
   endcase
  end
  dx=x-origin_x;dy=y-origin_y;char_pos=dx/24;char_col=dx%24;char_row=dy[4:0];
  char_glyph=glyph(text_id,char_pos);
  font_addr=text_on?{char_glyph,char_row}:12'd0;
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
