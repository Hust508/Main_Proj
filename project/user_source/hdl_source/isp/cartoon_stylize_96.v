// Four RGB888 pixels per beat. Color and edge inputs have the same latency.
// Each channel is reduced to four levels; Sobel edges become dark ink.
module cartoon_stylize_96 (
    input wire [95:0] I_color,
    input wire [95:0] I_edge,
    output wire [95:0] O_data
);
    function [7:0] level4;
        input [7:0] channel;
        begin level4 = {4{channel[7:6]}}; end
    endfunction

    genvar pixel;
    generate for(pixel=0;pixel<4;pixel=pixel+1) begin: g_pixel
        wire [23:0] color = I_color[pixel*24 +: 24];
        wire [23:0] edge_pixel = I_edge[pixel*24 +: 24];
        wire [23:0] poster = {level4(color[23:16]),
                              level4(color[15:8]),level4(color[7:0])};
        assign O_data[pixel*24 +: 24] = edge_pixel[23] ? 24'h101820 : poster;
    end endgenerate
endmodule
