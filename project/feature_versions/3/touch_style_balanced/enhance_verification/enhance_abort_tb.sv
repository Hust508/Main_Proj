`timescale 1ns/1ps
module enhance_abort_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,v=0,u=0,l=0;reg [2:0] mode=1;reg [95:0] rgb=0;
 wire ov,ou,ol;wire [95:0] data;wire [2:0] om;
 enhance_frame_select #(.IMG_WIDTH(48),.IMG_HEIGHT(24)) D(.I_clk(clk),.I_rst_n(rst),.I_mode(mode),.I_data(rgb),.I_valid(v),.I_user(u),.I_last(l),.I_ready(1'b1),.O_data(data),.O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(),.O_frame_mode(om));
 integer frame=-1,count=0,total=0;reg [95:0] expected;
 always @(posedge clk)begin
  #1;
  if(rst)begin
   if(ou)begin
    if(frame>=0)begin
     if(frame==1||frame==3)begin if(count<=0||count>=288)$fatal(1,"Invalid aborted prefix size %0d",count);end
     else if(count!=288)$fatal(1,"Lost complete frame %0d: %0d",frame,count);
    end
    frame=frame+1;count=0;
   end
   if(ov)begin
    if(frame<0||frame>4)$fatal(1,"Unexpected frame after abort/reset");
    // Natural control: input 18,52,86 -> Y=52, Co=-68, Cg=0;
    // Y LUT=56, Co*9/8=-76, reconstructed RGB=18,56,94.
    expected=(frame==0||frame==3)?{4{24'hffffff}}:((frame==2)?{4{24'h12385e}}:96'd0);
    if(data!==expected||om!==((frame==2)?3'd0:3'd1)||ol!==(count%12==11))
     $fatal(1,"Stale row/pipeline after abort: frame=%0d beat=%0d data=%h expected=%h mode=%0d",frame,count,data,expected,om);
    count=count+1;total=total+4;
   end
  end
 end
 task send(input [2:0] m,input [23:0] color,input integer rows);
  integer y,x;
  begin
   @(negedge clk);u=1;v=0;l=0;mode=m;@(negedge clk);u=0;
   for(y=0;y<rows;y=y+1)begin
    for(x=0;x<12;x=x+1)begin v=1;l=(x==11);rgb={4{color}};@(negedge clk);end
    v=0;l=0;repeat(40)@(negedge clk);
   end
  end
 endtask
 initial begin
  repeat(5)@(negedge clk);rst=1;
  send(1,24'hffffff,24);repeat(200)@(negedge clk);
  send(1,24'h000000,6);send(0,24'h123456,24);repeat(200)@(negedge clk);
  send(1,24'hffffff,6);send(1,24'h000000,24);repeat(200)@(negedge clk);
  if(frame!=4||count!=288)$fatal(1,"Final fresh frame incomplete");
  // Cancel before a completed neighborhood, without resetting the row RAMs.
  @(negedge clk);u=1;mode=1;@(negedge clk);u=0;v=1;rgb={4{24'hffffff}};
  @(negedge clk);rst=0;v=0;repeat(5)@(negedge clk);rst=1;repeat(100)@(negedge clk);
  if(frame!=4||count!=288)$fatal(1,"Reset leaked stale frame");
  $display("PASS enhancement partial-frame abort to raw and to enhancement, no stale row/pipeline leakage, exact borders and reset cancellation; %0d checked pixels",total);$finish;
 end
 initial begin #1000000;$fatal(1,"Abort test timeout");end
endmodule
