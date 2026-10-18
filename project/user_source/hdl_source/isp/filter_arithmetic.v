// One weighted-luma calculation feeds grayscale and retro together.
module rgb_luma_96(input wire [95:0] rgb,output wire [31:0] luma);
 genvar p;
 generate for(p=0;p<4;p=p+1)begin:P
  wire [15:0] r={8'd0,rgb[p*24+16+:8]},g={8'd0,rgb[p*24+8+:8]},b={8'd0,rgb[p*24+:8]};
  wire [15:0] s=(r<<6)+(r<<3)+(r<<2)+r+(g<<7)+(g<<4)+(g<<2)+(g<<1)+
      (b<<4)+(b<<3)+(b<<2)+b+16'd128;
  assign luma[p*8+:8]=s[15:8];
 end endgenerate
endmodule

// Retro uses a shift/add tree; enhancement uses an exact 9-bit low product
// plus the gain's bit 9. The shared shape multiplier frees DSPs for this path.
module unsigned_gain_product #(parameter GAIN_BITS=10)(
 input wire [7:0] pixel,input wire [GAIN_BITS-1:0] gain,
 output wire [GAIN_BITS+7:0] product
);
 generate if(GAIN_BITS==10)begin:DSP_LOW
  wire [16:0] low=pixel*gain[8:0];
  assign product={1'b0,low}+(gain[9]?{1'b0,pixel,9'd0}:18'd0);
 end else begin:SHIFT_ADD
 wire [GAIN_BITS+7:0] a[0:7],b[0:3],c[0:1];
 genvar k;
 for(k=0;k<8;k=k+1)begin:P
  assign a[k]=pixel[k]?({8'd0,gain}<<k):{(GAIN_BITS+8){1'b0}};
 end
 for(k=0;k<4;k=k+1)begin:B assign b[k]=a[k*2]+a[k*2+1];end
 for(k=0;k<2;k=k+1)begin:C assign c[k]=b[k*2]+b[k*2+1];end
 assign product=c[0]+c[1];
 end endgenerate
endmodule
