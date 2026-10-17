`timescale 1ns/1ps
module filter_bank_tb;
 reg clk=0,rst_n=0;
 reg [2:0] mode=0;
 reg [95:0] data={4{24'h804020}};
 reg valid=0,user=0,last=0;
 wire [95:0] out;
 wire out_valid,out_user,out_last,ready;
 wire [2:0] frame_mode;
 always #5 clk=~clk;
 image_filter_bank_96 #(.IMG_WIDTH(8),.IMG_HEIGHT(4)) dut(
  .I_clk(clk),.I_rst_n(rst_n),.I_mode(mode),.I_data(data),
  .I_valid(valid),.I_user(user),.I_last(last),.I_ready(1'b1),
  .O_data(out),.O_valid(out_valid),.O_user(out_user),.O_last(out_last),
  .O_ready(ready),.O_frame_mode(frame_mode));

 task automatic check_mode(input [2:0] selected,input [23:0] expected);
  begin
   rst_n=0;valid=0;user=0;mode=selected;repeat(3)@(posedge clk);
   rst_n=1;@(posedge clk);valid=1;user=1;last=1;
   @(posedge clk);#1;
   if(!out_valid||!out_user||!out_last||frame_mode!==selected)
    $fatal(1,"sideband/mode mismatch for mode %0d",selected);
   if(out!=={4{expected}})
    $fatal(1,"mode %0d expected %h got %h",selected,{4{expected}},out);
   valid=0;user=0;last=0;@(posedge clk);
  end
 endtask

 initial begin
  check_mode(3'd0,24'h804020);
  check_mode(3'd1,24'h505050);
  check_mode(3'd2,24'haa5500);
  check_mode(3'd3,24'h7fbfdf);
  check_mode(3'd4,24'h924900);
  check_mode(3'd5,24'h000000);
  $display("PASS filter_bank_tb");
  $finish;
 end
endmodule
