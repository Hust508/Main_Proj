`timescale 1ns/1ps
module clock_bridge_tb;
 reg src=0,dst=0,src_on=1,dst_on=1;
 always #8.333 if(src_on)src=~src;always #20.833 if(dst_on)dst=~dst;
 reg rst=0,v=0,u=0,l=0;reg [95:0] rgb=0;reg [2:0] mode=0;
 wire [95:0] data;wire ov,ou,ol,overflow;wire [2:0] om;
 enhance_clock_bridge D(.I_src_clk(src),.I_src_rst_n(rst),.I_dst_clk(dst),.I_dst_rst_n(rst),
 .I_rgb(rgb),.I_valid(v),.I_sof(u),.I_last(l),.I_mode(mode),
 .O_rgb(data),.O_valid(ov),.O_sof(ou),.O_last(ol),.O_mode(om),.O_overflow(overflow));
 reg [101:0] expected[0:8191];integer wi=0,ri=0,checks=0;reg check=1;
 always @(posedge dst)if(rst&&check&&(ov||ou))begin
  if(ri>=wi||{om,ol,ou,ov,data}!==expected[ri])$fatal(1,"RGB/event mismatch at %0d: %h/%h",ri,{om,ol,ou,ov,data},expected[ri]);
  ri=ri+1;checks=checks+1;
 end
 task event_word(input integer frame_id,index,input bit sof,valid,last);
  begin
   rgb={32'h91230000+frame_id,32'h45670000+index,32'h89abcdef^index};
   v=valid;u=sof;l=last;
   expected[wi]={frame_id[0]?3'd1:3'd0,last,sof,valid,rgb};wi=wi+1;
   @(negedge src);
  end
 endtask
 integer f,x;
 initial begin
  repeat(20)@(negedge src);rst=1;repeat(20)@(negedge src);
  for(f=0;f<10;f=f+1)begin
   mode=f%2;
   if(f%2)begin
    event_word(f,0,1,0,0);u=0;v=0;repeat(60)@(negedge src);
   end
   for(x=0;x<128;x=x+1)begin
    event_word(f,x,(x==0&&f%2==0),1,(x%32==31));
    // Changing a request mid-frame must not change the mode in queued data.
    mode=(mode+1)%8;
    if(x%17==16)begin
     v=0;u=0;l=0;src_on=0;#3000;src_on=1;@(negedge src);
    end
   end
   v=0;u=0;l=0;src_on=0;#15000;
   if(ri!=wi||overflow)$fatal(1,"Final event stranded after source stopped: %0d/%0d",ri,wi);
   src_on=1;@(negedge src);
  end
  // Cancel a nonempty queue and restart cleanly in both domains.
  rst=0;wi=0;ri=0;repeat(10)@(negedge src);rst=1;repeat(20)@(negedge src);
  mode=1;event_word(1,0,1,1,1);v=0;u=0;l=0;src_on=0;#5000;
  if(ri!=wi)$fatal(1,"Single last-edge word did not cross");
  src_on=1;@(negedge src);check=0;
  // Stop the consumer, fill the queue, verify the explicit overflow report.
  @(negedge dst);dst_on=0;
  for(x=0;x<1100;x=x+1)begin v=1;@(negedge src);end
  v=0;dst_on=1;repeat(20)@(negedge dst);
  if(!overflow)$fatal(1,"Input overflow was not reported");
  rst=0;repeat(10)@(negedge dst);rst=1;repeat(20)@(negedge dst);
  if(overflow)$fatal(1,"Reset did not clear overflow history");
  $display("PASS clock bridge: %0d exact mixed-mode RGB/control events, isolated SOF, mid-frame requests, repeated source stops, final-edge publication, reset and overflow report",checks);$finish;
 end
 initial begin #1000000;$fatal(1,"Clock bridge timeout");end
endmodule
