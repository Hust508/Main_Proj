// ISP smoothing -> Sobel edges with retained color -> color quantization -> edge fusion.
// Four adjacent pixels per clock; two streaming 3x3 windows, no extra DDR pass.
module enhance_core #(parameter W=1280,H=720)(
 input wire clk,rst_n,flush_i,input wire [95:0] data_i,
 input wire valid_i,sof_i,input wire [2:0] mode_i,
 input wire [13:0] threshold_i,
 output wire [95:0] data_o,output wire valid_o,sof_o,eol_o,
 output wire nr_valid_o,nr_sof_o
);
 wire [103:0] yc;reg cv,cs;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin cv<=0;cs<=0;end
  else begin cv<=valid_i;cs<=sof_i;end
 end
 genvar p;
 generate for(p=0;p<4;p=p+1)begin:ENC
  enhance_rgb_to_yc C(.clk(clk),.rgb_i(data_i[(3-p)*24+:24]),.yc_o(yc[(3-p)*26+:26]));
 end endgenerate
 wire [935:0] nw,sw;wire nv,ns,nl,sv,ss,sl;
 enhance_window #(.W(W),.H(H)) NR(.clk(clk),.rst_n(rst_n),.flush_i(flush_i),.valid_i(cv),.sof_i(cs),.data_i(yc),.valid_o(nv),.sof_o(ns),.eol_o(nl),.win_o(nw));
 wire [103:0] smooth;reg [1:0] tv,ts;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin tv<=0;ts<=0;end
  else if(flush_i)begin tv<=0;ts<=0;end
  else begin tv<={tv[0],nv};ts<={ts[0],ns};end
 end
 generate for(p=0;p<4;p=p+1)begin:SMOOTH
  wire [25:0] sigma;reg [25:0] center0,center1;
  style_sigma S(.clk(clk),.win_i(nw[(3-p)*234+:234]),.data_o(sigma));
  always @(posedge clk)begin center0<=nw[(3-p)*234+4*26+:26];center1<=center0;end
  assign smooth[(3-p)*26+:26]=(mode_i==7)?sigma:center1;
 end endgenerate
 // Color accompanies the detected edge mask into the following quantization stage.
 enhance_window #(.W(W),.H(H)) ED(.clk(clk),.rst_n(rst_n),.flush_i(flush_i),.valid_i(tv[1]),.sof_i(ts[1]),.data_i(smooth),.valid_o(sv),.sof_o(ss),.eol_o(sl),.win_o(sw));
 reg [6:0] ov,os,ol;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin ov<=0;os<=0;ol<=0;end
  else if(flush_i)begin ov<=0;os<=0;ol<=0;end
  else begin ov<={ov[5:0],sv};os<={os[5:0],ss};ol<={ol[5:0],sl};end
 end
 generate for(p=0;p<4;p=p+1)begin:COLOR_AND_EDGE
  wire [25:0] edge_yc,toned,center_yc;wire [1:0] edge_level;wire [13:0] magnitude;wire [23:0] rgb;
  wire signed [12:0] co=$signed(center_yc[17:9]),cg=$signed(center_yc[8:0]);
  wire signed [12:0] tt=$signed({5'd0,center_yc[25:18]})-(cg>>>1);
  wire signed [12:0] bb=tt-(co>>>1),gg=cg+tt,rr=bb+co;
  wire [23:0] raw={rr[7:0],gg[7:0],bb[7:0]};
  wire [23:0] poster={{4{raw[23:22]}},{4{raw[15:14]}},{4{raw[7:6]}}};
  wire [23:0] simple=(mode_i==5)?((magnitude>=threshold_i)?24'hffffff:24'd0):
     ((magnitude>=threshold_i)?24'h101820:poster);
  reg [23:0] simple_pipe[0:4];integer k;
  always @(posedge clk)begin simple_pipe[0]<=simple;
   for(k=1;k<5;k=k+1)simple_pipe[k]<=simple_pipe[k-1];end
  wire [23:0] enhanced;
  assign data_o[(3-p)*24+:24]=(mode_i==7)?enhanced:simple_pipe[4];
  style_sobel E(.clk(clk),.win_i(sw[(3-p)*234+:234]),.yc_o(edge_yc),.level_o(edge_level),.center_o(center_yc),.magnitude_o(magnitude));
  enhance_lut T(.clk(clk),.y_i(edge_yc[25:18]),.y_o(toned[25:18]));
  reg [17:0] chroma;reg [1:0] tone_level,level_d0,level_d1;
  always @(posedge clk)begin
   chroma<=edge_yc[17:0];tone_level<=edge_level;level_d0<=tone_level;level_d1<=level_d0;
  end
  assign toned[17:0]=chroma;
  style_quantize_color C(.clk(clk),.yc_i(toned),.rgb_o(rgb));
  style_quantize_fuse Q(.clk(clk),.rgb_i(rgb),.level_i(level_d1),.rgb_o(enhanced));
 end endgenerate
 assign nr_valid_o=nv;assign nr_sof_o=ns;
 assign valid_o=ov[6];assign sof_o=os[6];assign eol_o=ol[6];
endmodule

module enhance_rgb_to_yc(input wire clk,input wire [23:0] rgb_i,output reg [25:0] yc_o);
 wire signed [10:0] r=$signed({3'd0,rgb_i[23:16]}),g=$signed({3'd0,rgb_i[15:8]}),b=$signed({3'd0,rgb_i[7:0]});
 wire signed [10:0] co=r-b,t=b+(co>>>1),cg=g-t,y=t+(cg>>>1);
 always @(posedge clk)yc_o<={y[7:0],co[8:0],cg[8:0]};
endmodule

// Fixed-normalization sigma filter; rejected neighbors become the center.
// Range gates protect both brightness and isoluminant color borders.
module style_sigma(input wire clk,input wire [233:0] win_i,output reg [25:0] data_o);
 wire [25:0] center=win_i[4*26+:26];
 reg signed [13:0] sy[0:8],sco[0:8],scg[0:8];
 genvar j;
 generate for(j=0;j<9;j=j+1)begin:GATE
  wire [25:0] n=win_i[(8-j)*26+:26];
  wire signed [9:0] dy=$signed({2'd0,n[25:18]})-$signed({2'd0,center[25:18]});
  wire signed [9:0] dc=$signed({n[17],n[17:9]})-$signed({center[17],center[17:9]});
  wire signed [9:0] dg=$signed({n[8],n[8:0]})-$signed({center[8],center[8:0]});
  wire keep=(dy>=-10'sd40)&&(dy<=10'sd40)&&(dc>=-10'sd64)&&(dc<=10'sd64)&&(dg>=-10'sd64)&&(dg<=10'sd64);
  wire [25:0] s=keep?n:center;
  always @(posedge clk)begin
   sy[j]<=$signed({6'd0,s[25:18]});sco[j]<=$signed(s[17:9]);scg[j]<=$signed(s[8:0]);
  end
 end endgenerate
 wire signed [13:0] ysum=sy[0]+(sy[1]<<<1)+sy[2]+(sy[3]<<<1)+(sy[4]<<<2)+(sy[5]<<<1)+sy[6]+(sy[7]<<<1)+sy[8]+14'sd8;
 wire signed [13:0] csum=sco[0]+(sco[1]<<<1)+sco[2]+(sco[3]<<<1)+(sco[4]<<<2)+(sco[5]<<<1)+sco[6]+(sco[7]<<<1)+sco[8]+14'sd8;
 wire signed [13:0] gsum=scg[0]+(scg[1]<<<1)+scg[2]+(scg[3]<<<1)+(scg[4]<<<2)+(scg[5]<<<1)+scg[6]+(scg[7]<<<1)+scg[8]+14'sd8;
 always @(posedge clk)data_o<={ysum[11:4],csum[12:4],gsum[12:4]};
endmodule

module style_sobel(input wire clk,input wire [233:0] win_i,output reg [25:0] yc_o,output reg [1:0] level_o,
 output reg [25:0] center_o,output reg [13:0] magnitude_o);
 wire [7:0] a[0:8];wire signed [13:0] cy[0:8],cc[0:8],cg[0:8];genvar j;
 generate for(j=0;j<9;j=j+1)begin:Y
  assign a[j]=win_i[(8-j)*26+18+:8];
  assign cy[j]=$signed({6'd0,a[j]});
  assign cc[j]=$signed(win_i[(8-j)*26+9+:9]);
  assign cg[j]=$signed(win_i[(8-j)*26+:9]);
 end endgenerate
 wire signed [11:0] gx=$signed({4'd0,a[2]})+($signed({4'd0,a[5]})<<<1)+$signed({4'd0,a[8]})-$signed({4'd0,a[0]})-($signed({4'd0,a[3]})<<<1)-$signed({4'd0,a[6]});
 wire signed [11:0] gy=$signed({4'd0,a[6]})+($signed({4'd0,a[7]})<<<1)+$signed({4'd0,a[8]})-$signed({4'd0,a[0]})-($signed({4'd0,a[1]})<<<1)-$signed({4'd0,a[2]});
 wire signed [13:0] ysum=cy[0]+(cy[1]<<<1)+cy[2]+(cy[3]<<<1)+(cy[4]<<<2)+(cy[5]<<<1)+cy[6]+(cy[7]<<<1)+cy[8]+14'sd8;
 wire signed [13:0] csum=cc[0]+(cc[1]<<<1)+cc[2]+(cc[3]<<<1)+(cc[4]<<<2)+(cc[5]<<<1)+cc[6]+(cc[7]<<<1)+cc[8]+14'sd8;
 wire signed [13:0] gsum=cg[0]+(cg[1]<<<1)+cg[2]+(cg[3]<<<1)+(cg[4]<<<2)+(cg[5]<<<1)+cg[6]+(cg[7]<<<1)+cg[8]+14'sd8;
 reg signed [11:0] xreg,yreg;reg [25:0] color;
 reg signed [13:0] by,bc,bg;
 wire [11:0] ax=xreg[11]?-xreg:xreg,ay=yreg[11]?-yreg:yreg;
 wire [12:0] mag={1'b0,ax}+{1'b0,ay};
 wire signed [13:0] center_y=$signed({6'd0,color[25:18]}),center_c=$signed(color[17:9]),center_g=$signed(color[8:0]);
 wire signed [13:0] mixy=(center_y+by+14'sd1)>>>1,mixc=(center_c+bc+14'sd1)>>>1,mixg=(center_g+bg+14'sd1)>>>1;
 wire signed [13:0] fy=(mag>=384)?center_y:((mag>=192)?mixy:by);
 wire signed [13:0] fc=(mag>=384)?center_c:((mag>=192)?mixc:bc);
 wire signed [13:0] fg=(mag>=384)?center_g:((mag>=192)?mixg:bg);
 always @(posedge clk)begin
  xreg<=gx;yreg<=gy;color<=win_i[4*26+:26];
  by<=ysum>>>4;bc<=csum>>>4;bg<=gsum>>>4;
  yc_o<={fy[7:0],fc[8:0],fg[8:0]};center_o<=color;magnitude_o<={1'b0,mag};
  level_o<=(mag>=256)?2'd3:((mag>=128)?2'd2:((mag>=64)?2'd1:2'd0));
 end
endmodule

module style_quantize_color(input wire clk,input wire [25:0] yc_i,output reg [23:0] rgb_o);
 wire signed [13:0] co=$signed(yc_i[17:9]),cg=$signed(yc_i[8:0]);
 // Fine chroma palette; bypass chroma quantization below Y=32.
 wire signed [13:0] cq=co+14'sd2,gq=cg+14'sd2;
 reg signed [12:0] sc,sg;reg [7:0] y;
 wire signed [12:0] t=$signed({5'd0,y})-(sg>>>1);
 wire signed [12:0] green=sg+t,blue=t-(sc>>>1),red=blue+sc;
 function [7:0] clip;
  input signed [12:0] v;
  begin if(v<0)clip=0;else if(v>255)clip=255;else clip=v[7:0];end
 endfunction
 // Keep all 32 shadow codes; quantize mid/high luminance in 8-code steps.
 // A nonzero shadow is never mapped to black by the palette.
 function [7:0] quantize_y;
  input [7:0] v;reg [8:0] rounded;
  begin rounded={1'b0,v}+9'd4;
   if(v<32)quantize_y=v;else if(rounded>=256)quantize_y=255;
   else quantize_y={rounded[7:3],3'b000};
  end
 endfunction
 always @(posedge clk)begin
  y<=quantize_y(yc_i[25:18]);
  sc<=(yc_i[25:18]<32)?co:((cq>>>2)<<<2);
  sg<=(yc_i[25:18]<32)?cg:((gq>>>2)<<<2);
  rgb_o<={clip(red),clip(green),clip(blue)};
 end
endmodule

// Shadow lift uses one common RGB gain, so it preserves channel ratios.
// There is no black-offset subtraction or threefold saturation.
// Pipeline remains two cycles: gain -> bounded saturation and gentle edge fusion.
module style_quantize_fuse(input wire clk,input wire [23:0] rgb_i,input wire [1:0] level_i,output reg [23:0] rgb_o);
 wire [7:0] r=rgb_i[23:16],g=rgb_i[15:8],b=rgb_i[7:0];
 wire [7:0] maxrg=(r>g)?r:g,maxrgb=(maxrg>b)?maxrg:b;
 wire [9:0] gain;
 style_tone_gain T(.max_i(maxrgb),.gain_o(gain));
 wire [17:0] rp,gp,bp;
 unsigned_gain_product #(.GAIN_BITS(10)) R(.pixel(r),.gain(gain),.product(rp));
 unsigned_gain_product #(.GAIN_BITS(10)) G(.pixel(g),.gain(gain),.product(gp));
 unsigned_gain_product #(.GAIN_BITS(10)) B(.pixel(b),.gain(gain),.product(bp));
 function [7:0] tone;
  input [17:0] product;reg [18:0] rounded;
  begin rounded={1'b0,product}+19'd128;
   tone=(rounded>=19'd65536)?8'd255:rounded[15:8];
  end
 endfunction
 reg [23:0] vibrant;reg [1:0] edge_level;
 wire [7:0] vr=vibrant[23:16],vg=vibrant[15:8],vb=vibrant[7:0];
 wire [7:0] mxrg=(vr>vg)?vr:vg,mx=(mxrg>vb)?mxrg:vb;
 function [7:0] fuse;
  input [7:0] v,m;input [1:0] level;
  reg signed [10:0] z;reg [7:0] c;
  reg [12:0] s31;reg [11:0] s15;reg [10:0] s7;
  begin
   z=$signed({3'd0,v})-($signed({3'd0,m})-$signed({3'd0,v})+11'sd2)/11'sd4;
   c=(z<0)?8'd0:z[7:0];
   s31=({5'd0,c}<<5)-{5'd0,c};s15=({4'd0,c}<<4)-{4'd0,c};s7=({3'd0,c}<<3)-{3'd0,c};
   case(level)2'd1:fuse=s31[12:5];2'd2:fuse=s15[11:4];2'd3:fuse=s7[10:3];default:fuse=c;endcase
  end
 endfunction
 always @(posedge clk)begin
  vibrant<={tone(rp),tone(gp),tone(bp)};edge_level<=level_i;
  rgb_o<={fuse(vr,mx,edge_level),fuse(vg,mx,edge_level),fuse(vb,mx,edge_level)};
 end
endmodule
