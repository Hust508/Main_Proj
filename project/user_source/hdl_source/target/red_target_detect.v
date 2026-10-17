// Single red region, streaming statistics. Coordinates are inclusive.
// Short horizontal runs are rejected before extending the bounding box.
module red_target_detect #(
 parameter WIDTH=1024, HEIGHT=600, MIN_RUN=4,
 parameter MIN_PIXELS=200, MIN_WIDTH=12, MIN_HEIGHT=12,
 parameter CONFIRM_FRAMES=2
)(
 input wire I_clk,I_rst_n,I_frame_start,I_enable,I_valid,I_red,
 input wire [10:0] I_x,I_y,
 output reg O_found,
 output reg [10:0] O_left,O_right,O_top,O_bottom,O_cx,O_cy,
 output wire [1:0] O_shape,output wire O_shape_ready
);
 reg enabled,opened,bad;
 reg [31:0] pixels,hits;
 reg [10:0] run_length,left,right,top,bottom;
 reg [7:0] streak;
 wire [11:0] box_width={1'b0,right}-{1'b0,left}+12'd1;
 wire [11:0] box_height={1'b0,bottom}-{1'b0,top}+12'd1;
 wire good=opened&&enabled&&!bad&&pixels==WIDTH*HEIGHT&&hits>=MIN_PIXELS&&
           box_width>=MIN_WIDTH&&box_height>=MIN_HEIGHT;
 wire [10:0] before_run=(I_x==0)?11'd0:run_length;
 wire qualified=I_red&&(before_run>=MIN_RUN-1);
 wire [10:0] first_x=(before_run==MIN_RUN-1)?I_x-(MIN_RUN-1):I_x;
 wire [11:0] sum_x={1'b0,left}+{1'b0,right};
 wire [11:0] sum_y={1'b0,top}+{1'b0,bottom};
 // Store only one descriptor per displayed row, never a second video frame.
 reg [10:0] row_left,row_right,row_hits;
 reg row_has;
 reg [10:0] next_left,next_right,next_hits;reg next_has;
 always @(*)begin
  next_left=(I_frame_start||I_x==0)?11'd2047:row_left;
  next_right=(I_frame_start||I_x==0)?11'd0:row_right;
  next_hits=(I_frame_start||I_x==0)?11'd0:row_hits;
  next_has=(I_frame_start||I_x==0)?1'b0:row_has;
  if(I_valid&&enabled&&qualified)begin
   next_has=1;
   if(first_x<next_left)next_left=first_x;
   if(I_x>next_right)next_right=I_x;
   next_hits=next_hits+((before_run==MIN_RUN-1)?MIN_RUN:1);
  end
 end
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin row_left<=2047;row_right<=0;row_hits<=0;row_has<=0;end
 else if(I_frame_start||I_valid)begin row_left<=next_left;row_right<=next_right;row_hits<=next_hits;row_has<=next_has;end
 red_shape_classify #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) shape_classifier(
  .I_clk(I_clk),.I_rst_n(I_rst_n),.I_start(I_frame_start),.I_good(I_enable&&good),.I_abort(I_valid),
  .I_clipped(left==0||top==0||right==WIDTH-1||bottom==HEIGHT-1),
  .I_left(left),.I_right(right),.I_top(top),.I_bottom(bottom),
  .I_row_wr(I_valid&&I_x==WIDTH-1&&opened&&enabled),.I_row_y(I_y),
  .I_row_data({next_has,next_left,next_right,next_hits}),
  .O_shape(O_shape),.O_ready(O_shape_ready),.O_busy());
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  enabled<=0;opened<=0;bad<=0;pixels<=0;hits<=0;run_length<=0;
  left<=2047;right<=0;top<=2047;bottom<=0;streak<=0;
  O_found<=0;O_left<=0;O_right<=0;O_top<=0;O_bottom<=0;O_cx<=0;O_cy<=0;
 end else if(I_frame_start)begin
  // Publish only at a frame boundary; a missing target clears immediately.
  if(I_enable&&good)begin
   if(streak<CONFIRM_FRAMES)streak<=streak+1'b1;
   O_found<=streak>=CONFIRM_FRAMES-1;
   O_left<=left;O_right<=right;O_top<=top;O_bottom<=bottom;
   O_cx<=sum_x[11:1];O_cy<=sum_y[11:1];
  end else begin O_found<=0;streak<=0;end
  enabled<=I_enable;opened<=1;bad<=0;hits<=0;
  pixels<=I_valid?32'd1:32'd0;
  run_length<=(I_enable&&I_valid&&I_red)?11'd1:11'd0;
  left<=2047;right<=0;top<=2047;bottom<=0;
 end else if(opened&&I_valid)begin
  if(pixels<WIDTH*HEIGHT+1)pixels<=pixels+1'b1;
  if(I_x>=WIDTH||I_y>=HEIGHT)bad<=1;
  if(enabled)begin
   if(I_red)begin
    if(before_run<WIDTH)run_length<=before_run+1'b1;
    if(qualified)begin
     hits<=hits+((before_run==MIN_RUN-1)?MIN_RUN:1);
     if(first_x<left)left<=first_x;
     if(I_x>right)right<=I_x;
     if(I_y<top)top<=I_y;
     if(I_y>bottom)bottom<=I_y;
    end
   end else run_length<=0;
  end
 end
endmodule
