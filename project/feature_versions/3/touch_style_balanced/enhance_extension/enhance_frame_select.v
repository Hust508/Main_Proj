// Frame-boundary selection: natural calibrated color / vivid slide style.
module enhance_frame_select #(parameter IMG_WIDTH=1280,IMG_HEIGHT=720)(
 input wire I_clk,I_rst_n,input wire [2:0] I_mode,
 input wire [95:0] I_data,input wire I_valid,I_user,I_last,I_ready,
 output wire [95:0] O_data,output wire O_valid,O_user,O_last,O_ready,
 output wire [2:0] O_frame_mode,output wire O_nr_valid,O_nr_sof
);
 reg [2:0] active_mode;reg user_d;
 wire fs=I_user&&!user_d;
 wire [2:0] requested=(I_mode==1)?3'd1:3'd0;
 wire [2:0] mode_now=fs?requested:active_mode;
 wire [95:0] enhanced;wire ev,eu,el;
 enhance_core #(.W(IMG_WIDTH),.H(IMG_HEIGHT)) u_enhance(
  .clk(I_clk),.rst_n(I_rst_n),.flush_i(fs),.data_i(I_data),
  .valid_i(I_valid&&(mode_now==1)),.sof_i(I_user&&(mode_now==1)),
  .data_o(enhanced),.valid_o(ev),.sof_o(eu),.eol_o(el),.nr_valid_o(O_nr_valid),.nr_sof_o(O_nr_sof));
 wire [95:0] natural_rgb;
 genvar p;
 generate for(p=0;p<4;p=p+1)begin:NATURAL
  style_natural_pixel C(.clk(I_clk),.rgb_i(I_data[(3-p)*24+:24]),.rgb_o(natural_rgb[(3-p)*24+:24]));
 end endgenerate
 reg [2:0] mode_pipe[0:3];
 reg [3:0] vp,up,lp;integer k;
 always @(posedge I_clk or negedge I_rst_n)begin
  if(!I_rst_n)begin
   active_mode<=0;user_d<=0;vp<=0;up<=0;lp<=0;
   for(k=0;k<4;k=k+1)begin mode_pipe[k]<=0;end
  end else begin
   user_d<=I_user;if(fs)active_mode<=requested;
   vp<={vp[2:0],I_valid&&(mode_now==0)};
   up<={up[2:0],I_user&&(mode_now==0)};
   lp<={lp[2:0],I_last&&(mode_now==0)};
   mode_pipe[0]<=mode_now;
   for(k=1;k<4;k=k+1)begin mode_pipe[k]<=mode_pipe[k-1];end
  end
 end
 wire enable_enhance=(mode_now==1)&&!fs;
 assign O_valid=vp[3]||(ev&&enable_enhance);
 assign O_user=up[3]||(eu&&enable_enhance);
 assign O_last=lp[3]||(el&&enable_enhance);
 assign O_data=vp[3]?natural_rgb:enhanced;
 assign O_frame_mode=(ev&&enable_enhance)?3'd1:mode_pipe[3];
 assign O_ready=I_ready;
endmodule
