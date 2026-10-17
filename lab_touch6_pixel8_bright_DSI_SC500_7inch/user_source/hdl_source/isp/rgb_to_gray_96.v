// Four RGB888 pixels per beat, preserving their 96-bit input order.
// Full-range luma: round((77*R + 150*G + 29*B)/256).
// Coefficients sum to 256, so black/white and neutral grays are exact.
// One register stage matches the existing color and edge paths.
// This is the reference continuous-video interface, without stall storage.
module rgb_to_gray_96 (
    input wire I_clk, I_rst_n,
    input wire [95:0] I_data,
    input wire I_valid, I_user, I_last, I_ready,
    output reg [95:0] O_data,
    output reg O_valid, O_user, O_last,
    output wire O_ready
);
    wire [95:0] gray_pixels;
    assign O_ready = I_ready;
    genvar p;
    generate for (p=0; p<4; p=p+1) begin: g_pixel
        // Explicitly widen BEFORE shifts and additions. The rounded maximum
        // is 65408, within 16 bits. Shift/add avoids general multipliers.
        wire [15:0] r = {8'd0, I_data[p*24+16 +: 8]};
        wire [15:0] g = {8'd0, I_data[p*24+8 +: 8]};
        wire [15:0] b = {8'd0, I_data[p*24 +: 8]};
        wire [15:0] r77  = (r<<6) + (r<<3) + (r<<2) + r;
        wire [15:0] g150 = (g<<7) + (g<<4) + (g<<2) + (g<<1);
        wire [15:0] b29  = (b<<4) + (b<<3) + (b<<2) + b;
        wire [15:0] weighted = r77 + g150 + b29 + 16'd128;
        wire [7:0] y = weighted[15:8];
        assign gray_pixels[p*24 +: 24] = {y,y,y};
    end endgenerate
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_data<=96'd0; O_valid<=0; O_user<=0; O_last<=0;
        end else begin
            O_data <= I_valid ? gray_pixels : 96'd0;
            O_valid <= I_valid; O_user <= I_user; O_last <= I_last;
        end
    end
endmodule
