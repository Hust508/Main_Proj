// Shared cartoon combiner. The color and Sobel buses must already have the
// same one-cycle latency. Four-level RGB blocks are outlined with dark ink.
module cartoon_stylize_96 (
 input wire [95:0] I_color,input wire [95:0] I_edge,
 output wire [95:0] O_data
);
 function [7:0] level4(input [7:0] channel);
  begin level4={4{channel[7:6]}};end
 endfunction
 genvar p;
 generate for(p=0;p<4;p=p+1)begin:g_pixel
  wire [23:0] color=I_color[p*24 +: 24];
  wire [23:0] edge_pixel=I_edge[p*24 +: 24];
  wire [23:0] poster={level4(color[23:16]),level4(color[15:8]),level4(color[7:0])};
  assign O_data[p*24 +: 24]=edge_pixel[23]?24'h101820:poster;
 end endgenerate
endmodule
