// 8x8 top-left sampling + RGB332 quantization + nearest-neighbor replication.
// Four pixels/valid beat; the first spatial pixel is I_data[95:72].
// One register stage, same throughput and sideband latency as color/gray.
// Continuous video interface: ready is forwarded, there is no stall buffer.
module pixel_art_96 #(
    parameter IMG_WIDTH=1280, IMG_HEIGHT=720
)(
    input wire I_clk,I_rst_n,
    input wire [95:0] I_data,
    input wire I_valid,I_user,I_last,I_ready,
    output reg [95:0] O_data,
    output reg O_valid,O_user,O_last,
    output wire O_ready
);
    localparam GROUPS=IMG_WIDTH/4;
    localparam BLOCKS=IMG_WIDTH/8;
    localparam X_BITS=(GROUPS>1)?$clog2(GROUPS):1;
    localparam Y_BITS=(IMG_HEIGHT>1)?$clog2(IMG_HEIGHT):1;
    // No reset loop: every entry is replaced on the first row of each band
    // before rows 1..7 can read it, including the first band after reset/SOF.
    (* ram_style="block" *) reg [7:0] block_row[0:BLOCKS-1];
    reg [X_BITS-1:0] x_group;
    reg [Y_BITS-1:0] y_pos;
    reg [7:0] held_color;
    reg user_d;
    wire sof=I_user && !user_d;
    wire [X_BITS-1:0] x=sof ? {X_BITS{1'b0}} : x_group;
    wire [Y_BITS-1:0] y=sof ? {Y_BITS{1'b0}} : y_pos;
    wire [7:0] sample_color={I_data[95:93],I_data[87:85],I_data[79:78]};
    function [23:0] expand332;
        input [7:0] color;
        begin
            expand332={{color[7:5],color[7:5],color[7:6]},
                       {color[4:2],color[4:2],color[4:3]},
                       {color[1:0],color[1:0],color[1:0],color[1:0]}};
        end
    endfunction
    assign O_ready=I_ready;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            x_group<=0; y_pos<=0; held_color<=0; user_d<=0;
            O_data<=0; O_valid<=0; O_user<=0; O_last<=0;
        end else begin
            user_d<=I_user;
            O_valid<=I_valid; O_user<=I_user; O_last<=I_last;
            O_data<=0;
            if(sof) begin x_group<=0; y_pos<=0; held_color<=0; end
            if(I_valid) begin
                if(y[2:0]==0) begin
                    if(!x[0]) begin
                        block_row[x>>1]<=sample_color;
                        held_color<=sample_color;
                        O_data<={4{expand332(sample_color)}};
                    end else O_data<={4{expand332(held_color)}};
                end else O_data<={4{expand332(block_row[x>>1])}};
                if(x==GROUPS-1) begin
                    x_group<=0;
                    y_pos<=(y==IMG_HEIGHT-1) ? 0 : y+1'b1;
                end else begin x_group<=x+1'b1; y_pos<=y; end
            end
        end
    end
endmodule
