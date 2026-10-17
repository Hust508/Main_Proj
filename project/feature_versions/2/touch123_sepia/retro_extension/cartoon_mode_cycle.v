// Add mode 3 to the original 0 -> 1 -> 2 cycle; reset still returns to 0.
module cartoon_mode_cycle(input wire clk,rst_n,press_i,output reg [1:0] mode_o);
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)mode_o<=0;else if(press_i)mode_o<=mode_o+2'd1;
    end
endmodule
