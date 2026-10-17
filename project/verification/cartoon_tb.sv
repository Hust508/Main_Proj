`timescale 1ns/1ps
module cartoon_tb;
    reg [95:0] color,edges;
    wire [95:0] art;
    cartoon_stylize_96 dut(.I_color(color),.I_edge(edges),.O_data(art));
    initial begin
        color={24'h00_40_80,24'h3f_7f_bf,24'h80_c0_ff,24'hff_00_55};
        edges=96'd0;
        #1;
        if(art!=={24'h00_55_aa,24'h00_55_aa,24'haa_ff_ff,24'hff_00_55})
            $fatal(1,"Four-level RGB quantization failed: %h",art);
        edges={24'hff_ffff,24'h00_0000,24'hff_ffff,24'h00_0000};
        #1;
        if(art!=={24'h10_18_20,24'h00_55_aa,24'h10_18_20,24'hff_00_55})
            $fatal(1,"Edge ink placement failed: %h",art);
        $display("PASS cartoon quantization and aligned outline pixels");
        $finish;
    end
endmodule
