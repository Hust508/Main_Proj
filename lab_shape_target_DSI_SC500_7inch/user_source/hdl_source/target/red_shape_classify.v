// Classify a single convex red silhouette during vertical blanking.
// BALL: near-circular row profile AND a curved boundary requiring >4 lines.
// CUBE: convex 4..6-vertex projection with straight boundary chains.
// This is appearance classification, not a reconstruction of 3-D geometry.
module red_shape_classify #(
 parameter WIDTH=1024,HEIGHT=600,MIN_SHAPE_SIZE=48,ROUND_ERROR_Q8=16,
 parameter EDGE_TOL_DIV=40,MAX_SIDE_PIECES=4
)(
 input wire I_clk,I_rst_n,I_start,I_good,I_abort,I_clipped,
 input wire [10:0] I_left,I_right,I_top,I_bottom,
 input wire I_row_wr,input wire [10:0] I_row_y,
 input wire [33:0] I_row_data,
 output reg [1:0] O_shape,output reg O_ready,output wire O_busy
);
 // {valid, left[10:0], right[10:0], red_pixel_count[10:0]}.
 (* ram_style="block" *) reg [33:0] rows[0:HEIGHT-1];
 reg [10:0] rd_addr;reg [33:0] rd_data;
 always @(posedge I_clk)begin
  if(I_row_wr&&I_row_y<HEIGHT)rows[I_row_y]<=I_row_data;
  rd_data<=rows[rd_addr];
 end
 localparam IDLE=0,ST_REQ=1,ST_WAIT=2,ST_USE=3,ST_DONE=4,
  POP=5,SEG_INIT=6,EDGE_REQ=7,EDGE_WAIT=8,EDGE_USE=9,EDGE_DONE=10;
 reg [3:0] state;
 assign O_busy=state!=IDLE;
 reg [10:0] left,right,top,bottom,scan_y,bw,bh,tolerance;
 reg [21:0] box_area;
 reg [31:0] spans,reds,upper_area,lower_area,round_error;
 reg [39:0] x_moment;
 reg missing,clipped,concave,round_ok;
 reg [3:0] band;reg [1:0] caps;
 reg [10:0] first_l,first_r,last_l,last_r;
 wire row_valid=rd_data[33];
 wire [10:0] row_l=rd_data[32:22],row_r=rd_data[21:11],row_reds=rd_data[10:0];
 wire [11:0] row_span={1'b0,row_r}-{1'b0,row_l}+12'd1;
 wire [10:0] dy=scan_y-top;
 wire [15:0] next_band_end=bh*({1'b0,band}+5'd1);
 wire [3:0] current_band=({dy,4'd0}>=next_band_end&&band<15)?band+1'b1:band;
 function [7:0] circle_width(input [3:0] n);
  begin case(n)
   0,15:circle_width=89;1,14:circle_width=149;2,13:circle_width=186;
   3,12:circle_width=212;4,11:circle_width=230;5,10:circle_width=243;
   6,9:circle_width=252;default:circle_width=255;
  endcase end
 endfunction
 wire [19:0] expected_span=bw*circle_width(current_band);
 wire [19:0] actual_span={row_span,8'd0};
 wire [19:0] row_error=(actual_span>=expected_span)?actual_span-expected_span:expected_span-actual_span;
 wire [23:0] row_moment=({1'b0,row_l}+{1'b0,row_r})*row_span;
 wire [39:0] central_moment=({1'b0,left}+{1'b0,right})*spans;
 wire [39:0] center_error=(x_moment>=central_moment)?x_moment-central_moment:central_moment-x_moment;
 wire [39:0] width_area=bw*spans;
 wire solid=!missing&&reds*64'd100>=spans*64'd65;
 wire balanced=upper_area*64'd5>=lower_area*64'd3&&lower_area*64'd5>=upper_area*64'd3&&center_error*64'd5<=width_area;
 wire base_ok=solid&&balanced&&!clipped&&bw>=MIN_SHAPE_SIZE&&bh>=MIN_SHAPE_SIZE&&
  bw*5>=bh*3&&bh*5>=bw*3&&spans*64'd100>=box_area*64'd40;
 wire circle_ok=base_ok&&bw*4>=bh*3&&bh*4>=bw*3&&
  spans*64'd100>=box_area*64'd68&&spans*64'd100<=box_area*64'd88&&
  round_error<=box_area*ROUND_ERROR_Q8;
 // Small stack implementing line simplification independently on left/right.
 reg [10:0] sy0[0:7],sy1[0:7],sx0[0:7],sx1[0:7];
 reg [3:0] sp;reg side;
 reg [3:0] pieces,left_pieces;
 reg [10:0] y0,y1,x0,x1,split_y,split_x,seg_dy;
 reg signed [11:0] seg_dx;
 reg [23:0] max_error;
 wire [10:0] edge_x=side?row_r:row_l;
 wire signed [11:0] edge_dx=$signed({1'b0,edge_x})-$signed({1'b0,x0});
 wire signed [11:0] edge_dy=$signed({1'b0,scan_y})-$signed({1'b0,y0});
 wire signed [23:0] product_a=edge_dx*$signed({1'b0,seg_dy});
 wire signed [23:0] product_b=seg_dx*edge_dy;
 wire signed [24:0] cross_value=$signed(product_a)-$signed(product_b);
 wire [23:0] deviation=cross_value[24]?-cross_value:cross_value;
 wire [23:0] limit=tolerance*seg_dy;
 wire wrong_turn=side?(cross_value< -$signed({1'b0,limit})):(cross_value>$signed({1'b0,limit}));
 wire [4:0] vertex_count={1'b0,left_pieces}+{1'b0,pieces}+caps;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  state<=IDLE;O_shape<=0;O_ready<=0;rd_addr<=0;
  left<=0;right<=0;top<=0;bottom<=0;scan_y<=0;bw<=0;bh<=0;tolerance<=2;box_area<=0;
  spans<=0;reds<=0;upper_area<=0;lower_area<=0;round_error<=0;x_moment<=0;
  missing<=0;clipped<=0;concave<=0;round_ok<=0;band<=0;caps<=0;
  first_l<=0;first_r<=0;last_l<=0;last_r<=0;sp<=0;side<=0;pieces<=0;left_pieces<=0;
  y0<=0;y1<=0;x0<=0;x1<=0;split_y<=0;split_x<=0;seg_dy<=0;seg_dx<=0;max_error<=0;
 end else if(I_start)begin
  O_shape<=0;O_ready<=!I_good;state<=I_good?ST_REQ:IDLE;
  left<=I_left;right<=I_right;top<=I_top;bottom<=I_bottom;scan_y<=I_top;
  bw<=I_right-I_left+1'b1;bh<=I_bottom-I_top+1'b1;
  box_area<=({1'b0,I_right}-{1'b0,I_left}+12'd1)*({1'b0,I_bottom}-{1'b0,I_top}+12'd1);
  tolerance<=((I_right-I_left+1)/EDGE_TOL_DIV<2)?11'd2:(I_right-I_left+1)/EDGE_TOL_DIV;
  clipped<=I_clipped;spans<=0;reds<=0;upper_area<=0;lower_area<=0;round_error<=0;x_moment<=0;
  missing<=0;concave<=0;round_ok<=0;band<=0;caps<=0;
  sp<=0;side<=0;pieces<=0;left_pieces<=0;
 end else if(I_abort&&state!=IDLE)begin
  // An unexpectedly short blanking interval cannot change a label mid-frame.
  state<=IDLE;O_shape<=0;O_ready<=1;
 end else case(state)
  ST_REQ:begin rd_addr<=scan_y;state<=ST_WAIT;end
  ST_WAIT:state<=ST_USE;
  ST_USE:begin
   if(!row_valid||row_l>row_r)missing<=1;
   else begin
    spans<=spans+row_span;reds<=reds+row_reds;round_error<=round_error+row_error;
    x_moment<=x_moment+row_moment;
    if({dy,1'b0}<bh)upper_area<=upper_area+row_span;else lower_area<=lower_area+row_span;
    // Ignore two raster rows at each extreme when fitting edges. A nearly
    // horizontal projected face can otherwise create a one-row false corner.
    if(scan_y==top+2)begin first_l<=row_l;first_r<=row_r;end
    if(scan_y==bottom-2)begin last_l<=row_l;last_r<=row_r;end
    if(scan_y==top||scan_y==bottom)if(row_span*5>=bw)caps<=caps+1'b1;
   end
   band<=current_band;
   if(scan_y==bottom)state<=ST_DONE;else begin scan_y<=scan_y+1'b1;state<=ST_REQ;end
  end
  ST_DONE:begin
   round_ok<=circle_ok;
   if(!base_ok)begin state<=IDLE;O_ready<=1;end
   else begin
    sy0[0]<=top+2;sy1[0]<=bottom-2;sx0[0]<=first_l;sx1[0]<=last_l;sp<=1;state<=POP;
   end
  end
  POP:begin
   if(sp!=0)begin
    y0<=sy0[sp-1'b1];y1<=sy1[sp-1'b1];x0<=sx0[sp-1'b1];x1<=sx1[sp-1'b1];
    sp<=sp-1'b1;state<=SEG_INIT;
   end else if(!side)begin
    left_pieces<=pieces;pieces<=0;side<=1;
    sy0[0]<=top+2;sy1[0]<=bottom-2;sx0[0]<=first_r;sx1[0]<=last_r;sp<=1;
   end else begin
    O_shape<=(!concave&&vertex_count>=4&&vertex_count<=6)?2'd2:2'd0;
    O_ready<=1;state<=IDLE;
   end
  end
  SEG_INIT:begin
   seg_dy<=y1-y0;seg_dx<=$signed({1'b0,x1})-$signed({1'b0,x0});
   max_error<=0;split_y<=y0;split_x<=x0;scan_y<=y0+1'b1;
   if(y1<=y0+1'b1)begin pieces<=pieces+1'b1;state<=POP;end else state<=EDGE_REQ;
  end
  EDGE_REQ:begin rd_addr<=scan_y;state<=EDGE_WAIT;end
  EDGE_WAIT:state<=EDGE_USE;
  EDGE_USE:begin
   if(wrong_turn)concave<=1;
   if(deviation>max_error)begin max_error<=deviation;split_y<=scan_y;split_x<=edge_x;end
   if(scan_y>=y1-1'b1)state<=EDGE_DONE;else begin scan_y<=scan_y+1'b1;state<=EDGE_REQ;end
  end
  EDGE_DONE:begin
   if(max_error<=limit)begin pieces<=pieces+1'b1;state<=POP;end
   else if(pieces+sp+2>MAX_SIDE_PIECES)begin
    // Several smooth bends are required for BALL; few straight edges are not.
    O_shape<=(round_ok&&!concave)?2'd1:2'd0;O_ready<=1;state<=IDLE;
   end else begin
    sy0[sp]<=y0;sy1[sp]<=split_y;sx0[sp]<=x0;sx1[sp]<=split_x;
    sy0[sp+1'b1]<=split_y;sy1[sp+1'b1]<=y1;sx0[sp+1'b1]<=split_x;sx1[sp+1'b1]<=x1;
    sp<=sp+2;state<=POP;
   end
  end
  default:state<=IDLE;
 endcase
endmodule
