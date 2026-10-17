// One acknowledged touch press advances one mode. The GT911 front end
// supplies debounced press pulses, so holding/dragging cannot repeat.
module touch_mode_cycle (
    input wire I_clk, I_rst_n, I_press,
    output reg [2:0] O_mode
);
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) O_mode <= 3'd0;
        else if (I_press) O_mode <= (O_mode>=3'd5) ? 3'd0 : O_mode+3'd1;
    end
endmodule
