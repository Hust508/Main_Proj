// Manual B/A and G/M trim, 19x19 positions. Positive AB=amber, GM=green.
// Each unit is 1/32 channel gain; axes are frame-atomic, four pixels per beat.
// Separate two-stage arithmetic preserves the previous WB pipeline timing.
module wb_tint_96(
 input wire I_clk,I_rst_n,I_enable,
 input wire signed [4:0] I_ab,I_gm,
 input wire [95:0] I_data,input wire I_valid,I_user,I_last,
 output reg [95:0] O_data,output reg O_valid,O_user,O_last
);
 function [11:0] factor(input signed [5:0] offset);
 integer n;begin n=offset;if(n>9)n=9;if(n< -9)n=-9;factor=1024+n*32;end
 endfunction
 function [7:0] clip(input [19:0] p);
 reg [20:0] q;begin q={1'b0,p}+21'd512;clip=q>261632?8'd255:q[17:10];end
 endfunction
 wire [11:0] want_r=I_enable?factor({I_ab[4],I_ab}):12'd1024;
 wire [11:0] want_b=I_enable?factor(-$signed({I_ab[4],I_ab})):12'd1024;
 wire [11:0] want_g=I_enable?factor({I_gm[4],I_gm}):12'd1024;
 reg [11:0] gr,gg,gb;
 wire [11:0] er=I_user?want_r:gr,eg=I_user?want_g:gg,eb=I_user?want_b:gb;
 reg [19:0] pr[0:3],pg[0:3],pb[0:3];reg v,u,l;integer p;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  gr<=1024;gg<=1024;gb<=1024;v<=0;u<=0;l<=0;O_data<=0;O_valid<=0;O_user<=0;O_last<=0;
  for(p=0;p<4;p=p+1)begin pr[p]<=0;pg[p]<=0;pb[p]<=0;end
 end else begin
  if(I_user)begin gr<=want_r;gg<=want_g;gb<=want_b;end
  v<=I_valid;u<=I_user;l<=I_last;O_valid<=v;O_user<=u;O_last<=l;
  for(p=0;p<4;p=p+1)begin
   pr[p]<=I_data[p*24+16+:8]*er;pg[p]<=I_data[p*24+8+:8]*eg;pb[p]<=I_data[p*24+:8]*eb;
   O_data[p*24+:24]<=v?{clip(pr[p]),clip(pg[p]),clip(pb[p])}:24'd0;
  end
 end
endmodule
