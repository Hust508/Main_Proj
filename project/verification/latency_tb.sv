`timescale 1ns/1ps
module latency_tb;
 reg clk=0,rst=0,sample=0,valid=0;
 reg [15:0] capture_sequence=0,display_sequence=0;
 wire out_valid;wire [7:0] latency;
 always #5 clk=~clk;
 frame_latency_meter dut(.I_clk(clk),.I_rst_n(rst),.I_sample(sample),.I_valid(valid),
  .I_capture_sequence(capture_sequence),.I_display_sequence(display_sequence),
  .O_valid(out_valid),.O_frame_latency(latency));
 task measure(input [15:0] capture,display,input bit input_valid,input [7:0] expected);
  begin
   @(negedge clk);capture_sequence=capture;display_sequence=display;valid=input_valid;sample=1;
   @(negedge clk);sample=0;#1;
   if(out_valid!==input_valid||latency!==expected)
    $fatal(1,"Latency capture=%0d display=%0d valid=%0d got=%0d",capture,display,input_valid,latency);
  end
 endtask
 initial begin
  repeat(3)@(negedge clk);rst=1;
  measure(16'd42,16'd41,1,8'd1);
  measure(16'd108,16'd103,1,8'd5);
  measure(16'h0001,16'hfffe,1,8'd3);
  measure(16'd400,16'd100,1,8'hff);
  measure(16'd8,16'd7,0,8'd0);
  capture_sequence=99;display_sequence=12;valid=1;repeat(3)@(negedge clk);
  if(out_valid!==0||latency!==0)$fatal(1,"Output changed without display sample");
  $display("PASS capture-to-display frame latency: valid gate, frame age, sequence wrap, saturation and sample hold");$finish;
 end
 initial begin #10000;$fatal(1,"Latency watchdog");end
endmodule
