// Lossless 96 -> 128 packing: hold phase through invalid bubbles.
// Four input beats produce three output words, MSB-first RGB byte order.
// A SOF discards any incomplete previous-frame residue; it may share beat 0.
module cartoon_packer(
    input wire I_clk,I_rst_n,
    input wire I_96b_frame_start,I_96b_valid,
    input wire [95:0] I_96b_data,
    output reg O_128b_frame_start,O_128b_valid,
    output reg [127:0] O_128b_data
);
    reg [1:0] phase;
    reg [95:0] pending;
    wire [1:0] current_phase=I_96b_frame_start?2'd0:phase;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            phase<=0;pending<=0;O_128b_frame_start<=0;
            O_128b_valid<=0;O_128b_data<=0;
        end else begin
            O_128b_frame_start<=I_96b_frame_start;
            O_128b_valid<=0;O_128b_data<=0;
            if(I_96b_frame_start) begin phase<=0;pending<=0;end
            if(I_96b_valid) begin
                phase<=current_phase+1'b1;pending<=I_96b_data;
                case(current_phase)
                    0: begin O_128b_valid<=0;end
                    1: begin O_128b_valid<=1;O_128b_data<={pending,I_96b_data[95:64]};end
                    2: begin O_128b_valid<=1;O_128b_data<={pending[63:0],I_96b_data[95:32]};end
                    3: begin O_128b_valid<=1;O_128b_data<={pending[31:0],I_96b_data};end
                endcase
            end
        end
    end
endmodule
