`timescale 1ns/1ps
module w128_d512_fifo(input rst, clkw, we, input [127:0] di,
 output [8:0] wrusedw, output afull, full_flag,
 input clkr, re, output [127:0] dout, output [8:0] rdusedw,
 output valid, empty_flag, aempty);
 // Address-generation test: storage capacity is deliberately unrestricted.
 assign wrusedw=0; assign rdusedw=0; assign dout=0;
 assign afull=0; assign full_flag=0; assign valid=0;
 assign empty_flag=0; assign aempty=0;
endmodule

module crop_tb;
 reg clk=0; always #5 clk=~clk;
 reg rst=0, vs=0;
 reg [1:0] rp=0;
 reg ready=0, busy=0;
 reg [30:0] returns=0;
 wire req;
 wire [24:0] addr;
 wire out_busy;
 wire [23:0] pixel;
 integer cycle=0, accepted=0, frames=0, expected=0;
 integer expected_base=0, next_row=0, next_word=0;
 integer drained=0;
 video_out dut(.I_rst_n(rst), .I_ddr_clk(clk),
 .O_video_out_rd_busy(out_busy), .I_video_in_wr_busy(busy),
 .I_video_out_rp(rp),.I_slot_modes(12'b100_011_010_001),.O_frame_mode(), .O_ddr_user_rd_en(req), .O_ddr_user_addr(addr),
 .I_ddr_user_ready(ready), .I_ddr_user_rd_valid(returns[30]),
 .I_ddr_user_rd_data(128'd0), .I_dsi_clk(clk),
 .I_video_vsync(vs), .I_video_rd_en(1'b0), .O_vdieo_data(pixel));
 always @(negedge clk) begin
   ready = rst && ((cycle % 7)!=0) && ((cycle % 11)!=0);
   busy = ((cycle % 19)<3);
 end
 always @(posedge clk) begin
   cycle=cycle+1;
   if (!rst) returns<=0;
   else returns<={returns[29:0],req};
   if (dut.S_video_frame_start && rst) begin
     accepted=0; expected_base=rp*7000000;
     frames=frames+1;
   end
   if (req) begin
     next_row=accepted/192; next_word=accepted%192;
     expected=expected_base+115392+next_row*1920+next_word*8;
     if (addr!==expected) $fatal(1,"crop address mismatch: %d != %d at word %d",addr,expected,accepted);
     if (accepted>=115200) $fatal(1,"read beyond 600 cropped rows");
     if (dut.S_frame_pending || dut.S_fifo_rst) $fatal(1,"read during old-frame drain/reset");
     accepted=accepted+1;
   end
   if (cycle>1500000) $fatal(1,"timeout");
 end
 task pulse_frame(input [1:0] buffer_index);
   begin
     @(negedge clk); rp=buffer_index; vs=1;
     repeat(8) @(negedge clk);
     vs=0;
   end
 endtask
 integer k;
 initial begin
   repeat(5) @(negedge clk); rst=1;
   repeat(5) @(negedge clk);
   // Interrupt a partially prefetched frame with outstanding DDR returns.
   pulse_frame(0);
   wait(accepted>=40);
   pulse_frame(1);
   wait(accepted==115200);
   wait(dut.S_outstanding_reads==0);
   repeat(100) @(negedge clk);
   if (accepted!=115200) $fatal(1,"overread after crop completion");
   for (k=0;k<4;k=k+1) begin
     pulse_frame(k[1:0]);
     wait(accepted==115200);
     wait(dut.S_outstanding_reads==0);
     repeat(100) @(negedge clk);
     if (accepted!=115200) $fatal(1,"overread");
   end
   $display("PASS: full crop address coverage for all four frame buffers, stalled requests, 31-cycle returns, partial-frame restart, and 600-row bounds.");
   $finish;
 end
endmodule
