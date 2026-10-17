// Detection uses the displayed, white-balanced RGB BEFORE any UI/annotations.
// No framebuffer or detector CDC is needed. Results describe the prior frame.
module red_target_video #(
 parameter WIDTH=1024,HEIGHT=600,R_MIN=80,RG_MARGIN=32,RB_MARGIN=24,
 parameter MIN_RUN=4,MIN_PIXELS=200,MIN_WIDTH=12,MIN_HEIGHT=12,CONFIRM_FRAMES=2,
 parameter BOX_THICKNESS=3
)(
 input wire I_clk,I_rst_n,I_enable,
 input wire [2:0] I_page,
 input wire I_vsync,I_hsync,I_de,input wire [23:0] I_data,
 output reg O_vsync,O_hsync,O_de,output reg [23:0] O_data
);
 reg vs_d,de_d,enabled;
 reg [2:0] page;
 reg [10:0] xc,yc;
 wire fs=I_vsync&&!vs_d;
 wire en=fs?I_enable:enabled;
 wire [2:0] pg=fs?I_page:page;
 wire [10:0] x=fs?11'd0:xc,y=fs?11'd0:yc;
 wire [9:0] r={2'd0,I_data[23:16]},g={2'd0,I_data[15:8]},b={2'd0,I_data[7:0]};
 wire is_red=r>=R_MIN&&r>=g+RG_MARGIN&&r>=b+RB_MARGIN&&
             (r<<1)>=g+(g<<1)&&(r<<1)>=b+(b<<1)&&g<=b+10'd48;
 reg v1,h1,d1,fs1,en1,red1;reg [2:0] pg1;reg [10:0] x1,y1;reg [23:0] rgb1;
 reg v2,h2,d2,en2;reg [2:0] pg2;reg [10:0] x2,y2;reg [23:0] rgb2;
 wire found;wire [10:0] left,right,top,bottom,cx,cy;
 wire [1:0] raw_shape;wire shape_ready;
 reg [1:0] render_shape;reg shape_pending;
 red_target_detect #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MIN_RUN(MIN_RUN),
  .MIN_PIXELS(MIN_PIXELS),.MIN_WIDTH(MIN_WIDTH),.MIN_HEIGHT(MIN_HEIGHT),.CONFIRM_FRAMES(CONFIRM_FRAMES)) detector(
  .I_clk(I_clk),.I_rst_n(I_rst_n),.I_frame_start(fs1),.I_enable(en1),.I_valid(d1),.I_red(red1),.I_x(x1),.I_y(y1),
  .O_found(found),.O_left(left),.O_right(right),.O_top(top),.O_bottom(bottom),.O_cx(cx),.O_cy(cy),
  .O_shape(raw_shape),.O_shape_ready(shape_ready));
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin render_shape<=0;shape_pending<=1;end
 else begin
  if(fs1)begin render_shape<=0;shape_pending<=1;end
  if(d1&&(shape_pending||fs1))begin render_shape<=(!fs1&&shape_ready)?raw_shape:2'd0;shape_pending<=0;end
 end
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  vs_d<=0;de_d<=0;enabled<=0;page<=0;xc<=0;yc<=0;
  v1<=0;h1<=0;d1<=0;fs1<=0;en1<=0;red1<=0;pg1<=0;x1<=0;y1<=0;rgb1<=0;
  v2<=0;h2<=0;d2<=0;en2<=0;pg2<=0;x2<=0;y2<=0;rgb2<=0;
 end else begin
  vs_d<=I_vsync;de_d<=I_de;
  if(fs)begin enabled<=I_enable;page<=I_page;xc<=I_de?11'd1:11'd0;yc<=0;end
  else begin
   if(I_de)xc<=xc+1'b1;else xc<=0;
   if(de_d&&!I_de)yc<=yc+1'b1;
  end
  v1<=I_vsync;h1<=I_hsync;d1<=I_de;fs1<=fs;en1<=en;pg1<=pg;red1<=is_red;x1<=x;y1<=y;rgb1<=I_data;
  v2<=v1;h2<=h1;d2<=d1;en2<=en1;pg2<=pg1;x2<=x1;y2<=y1;rgb2<=rgb1;
 end
 // Decimal conversion is registered once per frame. No pixel-rate division.
 function [15:0] to_bcd(input [10:0] number);
  reg [15:0] value;integer i;
  begin value=0;
   for(i=10;i>=0;i=i-1)begin
    if(value[3:0]>=5)value[3:0]=value[3:0]+3;
    if(value[7:4]>=5)value[7:4]=value[7:4]+3;
    if(value[11:8]>=5)value[11:8]=value[11:8]+3;
    if(value[15:12]>=5)value[15:12]=value[15:12]+3;
    value={value[14:0],number[i]};
   end to_bcd=value;
  end
 endfunction
 reg fs2;reg [15:0] bcd_x,bcd_y;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin fs2<=0;bcd_x<=0;bcd_y<=0;end
 else begin fs2<=fs1;if(fs2)begin bcd_x<=to_bcd(cx);bcd_y<=to_bcd(cy);end end
 wire [10:0] dist_x=(x2>=cx)?x2-cx:cx-x2,dist_y=(y2>=cy)?y2-cy:cy-y2;
 wire box=found&&x2>=left&&x2<=right&&y2>=top&&y2<=bottom&&
  ((x2-left<BOX_THICKNESS)||(right-x2<BOX_THICKNESS)||(y2-top<BOX_THICKNESS)||(bottom-y2<BOX_THICKNESS));
 wire crosshair=found&&((dist_x<=10&&dist_y<=1)||(dist_y<=10&&dist_x<=1));
 // Follow the target: one-line colored class/coordinate tag above the box.
 // Near the top, use the space below; clamp away from the settings panel.
 localparam LABEL_W=252,LABEL_H=24;
 wire [10:0] viewport=(pg2==0)?WIDTH:560;
 wire [10:0] label_x=found?((left+LABEL_W<=viewport)?left:viewport-LABEL_W):(viewport-LABEL_W)/2;
 wire [10:0] label_y=found?((top>=92)?top-11'd28:((bottom+28<=548)?bottom+11'd4:11'd64)):11'd516;
 wire label_area=x2>=label_x&&x2<label_x+LABEL_W&&y2>=label_y&&y2<label_y+LABEL_H;
 wire [10:0] tx=x2-label_x-11'd6,ty=y2-label_y-11'd5;
 wire [5:0] char_pos=tx/12;
 wire [3:0] col=tx%12;
 wire [2:0] row=ty[3:1];
 reg [7:0] char_code;
 always @(*)begin
  char_code=" ";
  if(!found)begin
   case(char_pos)
    0:char_code="N";1:char_code="O";3:char_code="T";4:char_code="A";5:char_code="R";6:char_code="G";7:char_code="E";8:char_code="T";
    default:;
   endcase
  end else begin
   if(render_shape==0)case(char_pos)
    0:char_code="U";1:char_code="N";2:char_code="K";3:char_code="N";4:char_code="O";5:char_code="W";6:char_code="N";default:;
   endcase
   else case(char_pos)
    0:char_code="R";1:char_code="E";2:char_code="D";
    4:char_code=(render_shape==1)?"B":"C";
    5:char_code=(render_shape==1)?"A":"U";
    6:char_code=(render_shape==1)?"L":"B";
    7:char_code=(render_shape==1)?"L":"E";default:;
   endcase
   case(char_pos)
    9:char_code="(";
    10:char_code=bcd_x[15:12]?8'd48+bcd_x[15:12]:" ";
    11:char_code=(bcd_x[15:8]!=0)?8'd48+bcd_x[11:8]:" ";
    12:char_code=(bcd_x[15:4]!=0)?8'd48+bcd_x[7:4]:" ";
    13:char_code=8'd48+bcd_x[3:0];14:char_code=",";
    15:char_code=bcd_y[15:12]?8'd48+bcd_y[15:12]:" ";
    16:char_code=(bcd_y[15:8]!=0)?8'd48+bcd_y[11:8]:" ";
    17:char_code=(bcd_y[15:4]!=0)?8'd48+bcd_y[7:4]:" ";
    18:char_code=8'd48+bcd_y[3:0];19:char_code=")";default:;
   endcase
  end
 end
 wire [4:0] font_bits;
 target_ascii_font font(.I_char(char_code),.I_row(row),.O_bits(font_bits));
 wire ink=label_area&&x2>=label_x+6&&col<10&&ty<14&&font_bits[4-(col>>1)];
 // Keep annotations out of the settings panel and the existing status bars.
 wire visible=en2&&(pg2==0||x2<560);
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin O_vsync<=0;O_hsync<=0;O_de<=0;O_data<=0;end
 else begin
  O_vsync<=v2;O_hsync<=h2;O_de<=d2;
  if(!d2)O_data<=0;
  else if(visible&&label_area)O_data<=ink?24'hffffff:(found?24'hb02024:24'h15202b);
  else if(visible&&(box||crosshair))O_data<=24'h000000;
  else O_data<=rgb2;
 end
endmodule
