`timescale 1ns/1ps
module writer_stream_tb;
 reg cam=0,ddr=0;always #8.333 cam=~cam;always #3.75 ddr=~ddr;
 reg rst=0,sof=0,valid=0,ready=1,busy=0,error=0,block=0;
 reg [127:0] data=0;reg [1:0] mode=0,read_slot=0;
 wire wr,available,publish,wrbusy;wire [24:0] addr;wire [127:0] outdata;
 wire [7:0] modes;wire [1:0] latest;
 integer cycle=0,published=0,words=0,last_f=-1,last_i=-1,last_slot=-1;
 reg last_publish=0;
 cartoon_video_in #(.FRAME_WORDS(960)) dut(.I_rst_n(rst),.I_ddr_rst_n(rst),
 .I_camera_clk(cam),.I_camera_frame_start(sof),.I_camera_mode(mode),
 .O_slot_modes(modes),.I_camera_valid(valid),.I_camera_data(data),
 .I_mipi_rx_error(error),.I_ddr_clk(ddr),.I_display_pause(1'b0),
 .I_video_out_rd_busy(busy),.I_read_slot(read_slot),.O_video_in_wr_busy(wrbusy),
 .O_video_out_rp(latest),.O_frame_available(available),.O_publish_toggle(publish),
 .O_ddr_user_wr_en(wr),.O_ddr_user_addr(addr),.O_ddr_user_wr_data(outdata),.I_ddr_user_ready(ready));
 always @(negedge ddr)begin
   cycle=cycle+1;ready=rst&&!block&&(cycle%11!=0)&&(cycle%7!=0);
   busy=(cycle%400<50);
 end
 integer f,i,slot;
 always @(posedge ddr)if(rst)begin
   if(wr)begin
     f=outdata[127:96];i=outdata[95:64];slot=addr/7000000;
     if(outdata[63:0]!=={32'hacdc0000+f,32'h579b0000+i})$fatal(1,"FIFO payload corrupt");
     if(slot==read_slot)$fatal(1,"writing currently displayed slot");
     if(i==0)begin last_f=f;last_i=-1;last_slot=slot;end
     if(f!=last_f||i!=last_i+1||slot!=last_slot||addr!=slot*7000000+i*8)
       $fatal(1,"lost or reordered capture word: frame=%0d word=%0d prior=%0d addr=%0d",f,i,last_i,addr);
     last_i=i;words=words+1;
   end
   #1;
   if(publish!=last_publish)begin
     if(last_i!=959||latest!=last_slot||modes[latest*2+:2]!=(last_f%4))
       $fatal(1,"published incomplete frame or wrong mode");
     published=published+1;
   end
   last_publish=publish;
 end
 task send_frame(input integer id,n);
   integer k;
   begin
     @(negedge cam);mode=id%4;
     for(k=0;k<n;k=k+1)begin
       sof=(k==0);valid=1;data={id[31:0],k[31:0],32'hacdc0000+id,32'h579b0000+k};
       @(negedge cam);
       // Three packed words in four camera cycles, with realistic line gaps.
       if(k%3==2)begin valid=0;sof=0;@(negedge cam);end
       if(k%240==239)begin valid=0;sof=0;repeat(25)@(negedge cam);end
     end
     valid=0;sof=0;repeat(100)@(negedge cam);
   end
 endtask
 integer n0,k;
 initial begin
   repeat(12)@(negedge cam);rst=1;repeat(12)@(negedge cam);
   // Garbage before a SOF is discarded, never made visible.
   valid=1;data=128'd0;repeat(8)@(negedge cam);valid=0;
   repeat(30)@(negedge cam);
   if(words||available)$fatal(1,"unframed startup data became visible");
   send_frame(0,960);wait(published==1);read_slot=latest;
   for(k=1;k<=8;k=k+1)send_frame(k,960);
   wait(published==9);
   n0=published;send_frame(9,256);
   if(published!=n0)$fatal(1,"truncated frame published");
   send_frame(10,960);wait(published==n0+1);
   n0=published;block=1;send_frame(11,960);block=0;
   repeat(1500)@(negedge cam);
   if(published!=n0)$fatal(1,"overflowed frame published");
   send_frame(12,960);wait(published==n0+1);
   n0=published;error=1;send_frame(13,960);error=0;
   if(published!=n0)$fatal(1,"errored frame published");
   send_frame(14,960);wait(published==n0+1);
   $display("PASS real asynchronous FIFO, %0d capture words, %0d complete frames, first-word SOF, stalls, four modes, protected read slot, truncated/overflow/error-frame rejection and next-frame recovery",words,published);
   $finish;
 end
 initial begin #2000000;$fatal(1,"writer timeout");end
endmodule
