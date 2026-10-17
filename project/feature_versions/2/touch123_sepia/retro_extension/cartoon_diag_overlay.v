// Two-stage diagnostic strip after the original OSD. All sync/data signals
// receive the same delay. A frame snapshot prevents torn hexadecimal counts.
module cartoon_diag_overlay #(parameter X=8,Y=552)(
 input wire clk,rst_n,input wire [194:0] status,
 input wire vs,hs,de,input wire [23:0] rgb,
 output reg ovs,ohs,ode,output reg [23:0] data
);
 reg vd,dd;reg [11:0] x,y;reg [194:0] snapshot;
 always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin vd<=0;dd<=0;x<=0;y<=0;snapshot<=0;end
   else begin
     vd<=vs;dd<=de;
     if(vs&&!vd)begin x<=0;y<=0;snapshot<=status;end
     else begin
       if(de)x<=x+1'b1;else x<=0;
       if(dd&&!de)y<=y+1'b1;
     end
   end
 end
 wire detail=(y>=Y+24)&&(y<Y+40);
 wire region=de&&x>=X&&x<X+752&&((y>=Y&&y<Y+16)||detail);
 wire [11:0] tx=x-X,ty=detail?(y-Y-24):(y-Y);
 wire [5:0] index=tx[9:4];
 reg [7:0] ch;reg [3:0] nibble;
 always @(*)begin
   ch=8'h20;nibble=0;
   if(!detail)case(index)
     0:ch="P"; 7:ch="D"; 14:ch="M"; 21:ch="R"; 28:ch="S"; 35:ch="B"; 42:ch="F";
     1,8,15,22,29,36,43:ch=":";
     2:begin nibble=snapshot[12+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     3:begin nibble=snapshot[8+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     4:begin nibble=snapshot[4+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     5:begin nibble=snapshot[0+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     9:begin nibble=snapshot[28+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     10:begin nibble=snapshot[24+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     11:begin nibble=snapshot[20+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     12:begin nibble=snapshot[16+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     16:begin nibble=snapshot[44+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     17:begin nibble=snapshot[40+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     18:begin nibble=snapshot[36+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     19:begin nibble=snapshot[32+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     23:begin nibble=snapshot[60+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     24:begin nibble=snapshot[56+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     25:begin nibble=snapshot[52+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     26:begin nibble=snapshot[48+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     30:begin nibble=snapshot[76+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     31:begin nibble=snapshot[72+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     32:begin nibble=snapshot[68+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     33:begin nibble=snapshot[64+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     37:begin nibble=snapshot[92+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     38:begin nibble=snapshot[88+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     39:begin nibble=snapshot[84+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     40:begin nibble=snapshot[80+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     44:ch="0"+{1'b0,snapshot[98:96]};
     default:;
   endcase else case(index)
     0:ch="K";
     1:ch=":";
     2:begin nibble=snapshot[99+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     4:ch="N";
     5:ch=":";
     6:begin nibble=snapshot[111+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     7:begin nibble=snapshot[107+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     8:begin nibble=snapshot[103+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     10:ch="Q";
     11:ch=":";
     12:begin nibble=snapshot[123+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     13:begin nibble=snapshot[119+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     14:begin nibble=snapshot[115+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     16:ch="V";
     17:ch=":";
     18:begin nibble=snapshot[135+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     19:begin nibble=snapshot[131+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     20:begin nibble=snapshot[127+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     22:ch="C";
     23:ch=":";
     24:begin nibble=snapshot[147+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     25:begin nibble=snapshot[143+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     26:begin nibble=snapshot[139+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     28:ch="I";
     29:ch=":";
     30:begin nibble=snapshot[159+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     31:begin nibble=snapshot[155+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     32:begin nibble=snapshot[151+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     34:ch="H";
     35:ch=":";
     36:begin nibble=snapshot[175+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     37:begin nibble=snapshot[171+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     38:begin nibble=snapshot[167+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     39:begin nibble=snapshot[163+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     41:ch="T";
     42:ch=":";
     43:begin nibble=snapshot[191+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     44:begin nibble=snapshot[187+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     45:begin nibble=snapshot[183+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     46:begin nibble=snapshot[179+:4];ch=(nibble<10)?"0"+nibble:"A"+(nibble-10);end
     default:;
   endcase
 end
 wire [15:0] bits;
 osd_char_lib font(.I_char(ch),.I_row(ty[3:0]),.O_row_bits(bits));
 reg v1,h1,d1,box1,ink1;reg [23:0] rgb1;
 always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin v1<=0;h1<=0;d1<=0;box1<=0;ink1<=0;rgb1<=0;ovs<=0;ohs<=0;ode<=0;data<=0;end
   else begin
     v1<=vs;h1<=hs;d1<=de;rgb1<=rgb;box1<=region;ink1<=bits[15-tx[3:0]];
     ovs<=v1;ohs<=h1;ode<=d1;
     data<=box1?(ink1?24'hffff00:24'h101010):rgb1;
   end
 end
endmodule
