// Exact 160x160, 25-bit {opaque, RGB888} logo from example 3.
// The synchronous ROM uses embedded memory instead of a large case decoder.
module osd_logo_rom #(
    parameter INIT_FILE = "../../../user_source/hdl_source/osd/anlogic_logo.hex"
)(
    input wire I_clk,
    input wire [14:0] I_addr,
    output reg [24:0] O_pixel
);
    reg [24:0] memory [0:25599]; // synthesis ram_style=bram
    initial $readmemh(INIT_FILE, memory);
    always @(posedge I_clk) O_pixel <= memory[I_addr];
endmodule
