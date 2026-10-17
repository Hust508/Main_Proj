`timescale 1ns/1ps
module enhance_portrait_tb;
 parameter W=48,H=24;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,v=0,u=0,l=0,ready=1;reg [2:0] mode=0;reg [95:0] rgb=0;
 wire ov,ou,ol,ordy,pv,pu;wire [95:0] data;wire [127:0] packed_data;wire [2:0] om;
 enhance_frame_select #(.IMG_WIDTH(W),.IMG_HEIGHT(H)) dut(
 .I_clk(clk),.I_rst_n(rst),.I_mode(mode),.I_data(rgb),.I_valid(v),.I_user(u),.I_last(l),.I_ready(ready),
 .O_data(data),.O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(ordy),.O_frame_mode(om));
 cartoon_packer packer(.I_clk(clk),.I_rst_n(rst),.I_96b_frame_start(ou),.I_96b_valid(ov),.I_96b_data(data),.O_128b_frame_start(pu),.O_128b_valid(pv),.O_128b_data(packed_data));
 integer fd,ef,rc,erc,n=0,pixels=0,frames=0,words=0,j,count=0,group=0;
 reg [2:0] em;reg el;reg [95:0] ed;
 reg prev_v=0,prev_u=0,epv;reg [95:0] prev_data=0;reg [127:0] epd;
 reg [7:0] bytes_q[0:31];reg [4095:0] filename,expected,capture_name;
 integer capture_fd=0,raw_capture_fd=0;
 initial begin
  if(!$value$plusargs("VECTORS=%s",filename)||!$value$plusargs("EXPECTED=%s",expected))$fatal(1,"Missing vectors");
  fd=$fopen(filename,"r");ef=$fopen(expected,"r");if(!fd||!ef)$fatal(1,"Cannot open vectors");
  if($value$plusargs("CAPTURE=%s",capture_name))capture_fd=$fopen(capture_name,"w");
  if($value$plusargs("RAW_CAPTURE=%s",capture_name))raw_capture_fd=$fopen(capture_name,"w");
  repeat(3)@(negedge clk);
  while(!$feof(fd))begin
   rc=$fscanf(fd,"%h %h %h %h %h %h %h\n",rst,v,u,l,mode,ready,rgb);
   if(rc!=7)$fatal(1,"Malformed event %0d",n);
   @(posedge clk);epv=0;epd=0;
   if(!rst)begin count=0;prev_u=0;prev_v=0;end
   else begin
    if(prev_u)count=0;
    if(prev_v)begin
     for(j=0;j<12;j=j+1)bytes_q[count+j]=prev_data[(11-j)*8+:8];
     count=count+12;
     if(count>=16)begin
      epv=1;for(j=0;j<16;j=j+1)epd[(15-j)*8+:8]=bytes_q[j];
      for(j=16;j<count;j=j+1)bytes_q[j-16]=bytes_q[j];count=count-16;
     end
    end
   end
   #1;
   if(ordy!==ready)$fatal(1,"Ready passthrough");
   if(ov)begin
    erc=$fscanf(ef,"%h %h %h\n",em,el,ed);
    if(erc!=3)$fatal(1,"Unexpected output at cycle %0d",n);
    if(om!==em||ol!==el||data!==ed)$fatal(1,"Pixel mismatch cycle=%0d group=%0d mode=%0d expected_mode=%0d last=%b/%b got=%h expected=%h",n,group,om,em,ol,el,data,ed);
    if(group==0&&!(ou||frames>0))$fatal(1,"No output SOF");
    group=(group+1)%(W*H/4);pixels=pixels+4;
    if(capture_fd&&om==1)$fdisplay(capture_fd,"%024h",data);
    if(raw_capture_fd&&om==0)$fdisplay(raw_capture_fd,"%024h",data);
   end
   if(ou)begin frames=frames+1;if(group!=0&&group!=1)$fatal(1,"SOF inside frame");end
   if(dut.vp[3]&&dut.ev&&dut.enable_enhance)$fatal(1,"Overlapping legacy/enhance output");
   if(pv!==epv||pu!==(rst?prev_u:1'b0)||(pv&&packed_data!==epd))$fatal(1,"Packed byte/control mismatch cycle=%0d",n);
   if(pv)words=words+1;
   prev_v=ov;prev_u=ou;prev_data=data;
   n=n+1;@(negedge clk);
  end
  erc=$fscanf(ef,"%h %h %h\n",em,el,ed);if(erc==3)$fatal(1,"Missing output pixels");
  if(group!=0)$fatal(1,"Incomplete final output");
  if(capture_fd)$fclose(capture_fd);if(raw_capture_fd)$fclose(raw_capture_fd);
  $display("PASS TWO_MODES W=%0d H=%0d cycles=%0d pixels=%0d frames=%0d packed_words=%0d",W,H,n,pixels,frames,words);$finish;
 end
 initial begin #4000000000;$fatal(1,"Timeout");end
endmodule
