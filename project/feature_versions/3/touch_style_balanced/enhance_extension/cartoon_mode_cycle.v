// Two modes: 0 original, 1 enhancement; invalid states return to original.
module cartoon_mode_cycle(input wire clk,rst_n,press_i,output reg [2:0] mode_o);
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)mode_o<=0;else if(press_i)mode_o<=(mode_o==0)?3'd1:3'd0;
end
endmodule
