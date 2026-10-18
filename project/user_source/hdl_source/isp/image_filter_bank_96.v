// Eight frame-atomic filters, four RGB888 pixels per beat.
// Fast paths: four cycles. Spatial paths: two row-window stages + arithmetic.
// Requires a free-running clock and vertical blanking to drain two rows.
module image_filter_bank_96 #(
 parameter IMG_WIDTH=1280,IMG_HEIGHT=720,EDGE_THRESHOLD=14'd80
)(
 input wire I_clk,I_rst_n,input wire [2:0] I_mode,
 input wire [95:0] I_data,input wire I_valid,I_user,I_last,I_ready,
 output wire [95:0] O_data,output wire O_valid,O_user,O_last,O_ready,
 output wire [2:0] O_frame_mode
);
 reg [2:0] frame_mode;reg user_d;
 wire fs=I_user&&!user_d;
 wire [2:0] mode_now=fs?I_mode:frame_mode;
 wire spatial=(mode_now==2)||(mode_now==5)||(mode_now==7);
 wire [31:0] luma;
 rgb_luma_96 u_luma(.rgb(I_data),.luma(luma));
 wire [95:0] pixel_data,retro_data,spatial_data;
 wire sv,su,sl;
 pixel_art_96 #(.IMG_WIDTH(IMG_WIDTH),.IMG_HEIGHT(IMG_HEIGHT)) u_pixel(
  .I_clk(I_clk),.I_rst_n(I_rst_n),.I_data(I_data),.I_valid(I_valid),
  .I_user(I_user),.I_last(I_last),.I_ready(I_ready),.O_data(pixel_data),
  .O_valid(),.O_user(),.O_last(),.O_ready());
 sepia_core #(.W(IMG_WIDTH),.H(IMG_HEIGHT)) u_retro(
  .clk(I_clk),.rst_n(I_rst_n),.data_i(I_data),.valid_i(I_valid),
  .sof_i(I_user),.eol_i(I_last),.luma_i(luma),.data_o(retro_data),
  .valid_o(),.sof_o(),.eol_o());
 enhance_core #(.W(IMG_WIDTH),.H(IMG_HEIGHT)) u_spatial(
  .clk(I_clk),.rst_n(I_rst_n),.flush_i(fs),.data_i(I_data),
  .valid_i(I_valid&&spatial),.sof_i(I_user&&spatial),.mode_i(mode_now),
  .threshold_i(EDGE_THRESHOLD),.data_o(spatial_data),.valid_o(sv),
  .sof_o(su),.eol_o(sl),.nr_valid_o(),.nr_sof_o());
 reg [95:0] color[0:3],gray[0:3],pixel[0:2];
 reg [3:0] vp,up,lp;reg [2:0] mp[0:3];integer k,j;
 genvar p;
 generate for(p=0;p<4;p=p+1)begin:LUMA_REG
  always @(posedge I_clk)gray[0][p*24+:24]<={3{luma[p*8+:8]}};
 end endgenerate
 always @(posedge I_clk or negedge I_rst_n)begin
  if(!I_rst_n)begin frame_mode<=0;user_d<=0;vp<=0;up<=0;lp<=0;
   for(k=0;k<4;k=k+1)mp[k]<=0;
  end else begin
   user_d<=I_user;if(fs)frame_mode<=I_mode;
   vp<={vp[2:0],I_valid&&!spatial};
   up<={up[2:0],I_user&&!spatial};lp<={lp[2:0],I_last&&!spatial};
   mp[0]<=mode_now;for(k=1;k<4;k=k+1)mp[k]<=mp[k-1];
  end
 end
 always @(posedge I_clk)begin
  color[0]<=I_data;pixel[0]<=pixel_data;
  for(j=1;j<4;j=j+1)begin color[j]<=color[j-1];gray[j]<=gray[j-1];end
  for(j=1;j<3;j=j+1)pixel[j]<=pixel[j-1];
 end
 wire spatial_enable=spatial&&!fs;
 assign O_valid=vp[3]||(sv&&spatial_enable);
 assign O_user=up[3]||(su&&spatial_enable);
 assign O_last=lp[3]||(sl&&spatial_enable);
 assign O_frame_mode=(sv&&spatial_enable)?frame_mode:mp[3];
 assign O_data=vp[3]?((mp[3]==1)?gray[3]:(mp[3]==3)?~color[3]:
   (mp[3]==4)?pixel[2]:(mp[3]==6)?retro_data:color[3]):spatial_data;
 assign O_ready=I_ready;
endmodule
