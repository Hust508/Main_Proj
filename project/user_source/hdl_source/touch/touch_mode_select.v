// Decode button hit regions inside the 150-pixel slide-up drawer.
module touch_mode_select #(
    parameter SWAP_XY=0,
    parameter FLIP_X=0,
    parameter FLIP_Y=0
)(
    input wire I_press,
    input wire [3:0] I_contacts,
    input wire [15:0] I_x, I_y,
    output reg O_valid,
    output reg [1:0] O_mode
);
    wire [15:0] raw_x = SWAP_XY ? I_y : I_x;
    wire [15:0] raw_y = SWAP_XY ? I_x : I_y;
    wire in_bounds = raw_x < 16'd1024 && raw_y < 16'd600;
    wire [15:0] x = FLIP_X ? 16'd1023-raw_x : raw_x;
    wire [15:0] y = FLIP_Y ? 16'd599-raw_y : raw_y;

    always @(*) begin
        O_valid=0;
        O_mode=0;
        if(I_press && I_contacts==1 && in_bounds && y>=16'd495 && y<16'd580) begin
            if(x>=16'd16 && x<16'd244) begin O_valid=1; O_mode=0; end
            else if(x>=16'd268 && x<16'd496) begin O_valid=1; O_mode=1; end
            else if(x>=16'd520 && x<16'd748) begin O_valid=1; O_mode=2; end
            else if(x>=16'd772 && x<16'd1000) begin O_valid=1; O_mode=3; end
        end
    end
endmodule
