// Unified filter library for four RGB888 pixels per beat.
// All effects run in parallel and share one frame-synchronous selector:
// 0 original, 1 grayscale, 2 cartoon, 3 negative, 4 pixel art, 5 Sobel.
module image_filter_bank_96 #(
 parameter IMG_WIDTH=1280,IMG_HEIGHT=720,EDGE_THRESHOLD=14'd80
)(
 input wire I_clk,I_rst_n,input wire [2:0] I_mode,
 input wire [95:0] I_data,input wire I_valid,I_user,I_last,I_ready,
 output wire [95:0] O_data,output wire O_valid,O_user,O_last,O_ready,
 output reg [2:0] O_frame_mode
);
 localparam MODE_ORIGINAL=3'd0,MODE_GRAY=3'd1,MODE_CARTOON=3'd2,
  MODE_NEGATIVE=3'd3,MODE_PIXEL=3'd4,MODE_EDGE=3'd5;
 reg [95:0] color_data;reg user_d;
 wire [95:0] edge_data,gray_data,pixel_data,cartoon_data;
 wire edge_valid,edge_user,edge_last;
 always @(posedge I_clk or negedge I_rst_n)
  if(!I_rst_n)begin color_data<=0;user_d<=0;O_frame_mode<=0;end
  else begin
   color_data<=I_valid?I_data:96'd0;user_d<=I_user;
   if(I_user&&!user_d)O_frame_mode<=(I_mode<=MODE_EDGE)?I_mode:MODE_ORIGINAL;
  end
 edge_detect_96 #(.IMG_WIDTH(IMG_WIDTH),.IMG_HEIGHT(IMG_HEIGHT),.EDGE_TH(EDGE_THRESHOLD)) u_edge(
  .I_clk(I_clk),.I_rst_n(I_rst_n),.I_tdata(I_data),.I_tvalid(I_valid),
  .I_tuser(I_user),.I_tlast(I_last),.I_tready(I_ready),.O_tready(O_ready),
  .O_tdata(edge_data),.O_tvalid(edge_valid),.O_tuser(edge_user),.O_tlast(edge_last));
 rgb_to_gray_96 u_gray(
  .I_clk(I_clk),.I_rst_n(I_rst_n),.I_data(I_data),.I_valid(I_valid),
  .I_user(I_user),.I_last(I_last),.I_ready(I_ready),.O_data(gray_data),
  .O_valid(),.O_user(),.O_last(),.O_ready());
 pixel_art_96 #(.IMG_WIDTH(IMG_WIDTH),.IMG_HEIGHT(IMG_HEIGHT)) u_pixel(
  .I_clk(I_clk),.I_rst_n(I_rst_n),.I_data(I_data),.I_valid(I_valid),
  .I_user(I_user),.I_last(I_last),.I_ready(I_ready),.O_data(pixel_data),
  .O_valid(),.O_user(),.O_last(),.O_ready());
 cartoon_stylize_96 u_cartoon(.I_color(color_data),.I_edge(edge_data),.O_data(cartoon_data));
 assign O_data=(O_frame_mode==MODE_GRAY)?gray_data:
  (O_frame_mode==MODE_CARTOON)?cartoon_data:
  (O_frame_mode==MODE_NEGATIVE)?~color_data:
  (O_frame_mode==MODE_PIXEL)?pixel_data:
  (O_frame_mode==MODE_EDGE)?edge_data:color_data;
 assign O_valid=edge_valid;assign O_user=edge_user;assign O_last=edge_last;
endmodule
