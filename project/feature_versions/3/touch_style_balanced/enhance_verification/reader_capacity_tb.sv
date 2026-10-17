`timescale 1ns/1ps
module reader_capacity_tb;
 reg clk=0,px=0;always #3.75 clk=~clk;always #9.583 px=~px;
 reg rst=0,vs=0,pull=0,ret=0;
 wire req;wire [24:0] addr;wire [23:0] pixel;
 reg [127:0] retdata=0;
 integer queue[0:2047];integer wp=0,rp=0,n=0,cycle=0,overflow=0,max_reservation=0;
 reg [30:0] pending=0;reg [127:0] return_pipe[0:30];integer j;
 cartoon_video_out dut(.I_pixel_rst_n(rst),.I_frame_available(1'b1),.O_read_slot(),.I_rst_n(rst),.I_display_ready_n(rst),.O_recovery_req(),
 .I_ddr_clk(clk),.I_video_in_wr_busy(1'b0),.I_video_out_rp(2'd0),.I_slot_modes(12'd0),.O_frame_mode(),
 .O_video_out_rd_busy(),.O_ddr_user_rd_en(req),.O_ddr_user_addr(addr),
 .I_ddr_user_ready(n<450),.I_ddr_user_rd_valid(ret),.I_ddr_user_rd_data(retdata),
 .I_dsi_clk(px),.I_video_vsync(vs),.I_video_rd_en(pull),.O_vdieo_data(pixel));
 function [23:0] pattern(input integer y,x);
   pattern={x[7:0],y[7:0],x[11:8],y[11:8]};
 endfunction
 function [127:0] word_at(input integer a);
   integer b,p,c;reg [23:0] v;
   begin
     for(b=0;b<16;b=b+1)begin
       p=(a*2+b)/3;c=(a*2+b)%3;v=pattern(p/1280,p%1280);
       word_at[127-b*8-:8]=v[23-c*8-:8];
     end
   end
 endfunction
 always @(posedge clk)begin
   if(!rst)begin wp=0;rp=0;n=0;cycle=0;pending<=0;ret<=0;end
   else begin
     cycle=cycle+1;
     if(req)begin queue[wp]=addr;wp=(wp+1)%2048;n=n+1;end
     pending<={pending[29:0],1'b0};
     if(cycle%2==0&&n>0)begin
       pending[0]<=1;return_pipe[0]<=word_at(queue[rp]);rp=(rp+1)%2048;n=n-1;
     end
     for(j=1;j<31;j=j+1)return_pipe[j]<=return_pipe[j-1];
     ret<=pending[30];retdata<=return_pipe[30];
     if(dut.U_w128_d512_fifo.full_flag && dut.U_w128_d512_fifo.we)overflow=overflow+1;
     if(dut.S_fifo_wr_num+dut.S_outstanding_reads>max_reservation)
       max_reservation=dut.S_fifo_wr_num+dut.S_outstanding_reads;
   end
 end
 integer x,y,checked=0;
 reg check=0;reg [23:0] expected=0;
 always @(posedge px)begin
   #1;
   if(check && pixel!==expected)$fatal(1,"pixel mismatch y=%0d x=%0d expected=%h got=%h overflow=%0d",y,x,expected,pixel,overflow);
 end
 initial begin
   repeat(12)@(negedge clk);rst=1;
   repeat(5)@(negedge px);vs=1;repeat(8)@(negedge px);vs=0;
   // Vertical blanking prefetch with a realistic queued, half-rate controller.
   repeat(2500)@(negedge px);
   if(overflow)$fatal(1,"display FIFO dropped %0d words during prefetch; occupied+inflight reached %0d",overflow,max_reservation);
   for(y=0;y<600;y=y+1)begin
     for(x=0;x<1024;x=x+1)begin
       pull=1;
       @(negedge px);check=1;expected=pattern(y+60,x+128);checked=checked+1;
     end
     pull=0;
     @(negedge px);check=0;
     repeat(319)@(negedge px);
   end
   if(overflow)$fatal(1,"FIFO overflow during scanout");
   $display("PASS actual FIFO capacity and %0d cropped pixels, queued half-rate returns, max occupied+inflight=%0d",checked,max_reservation);
   $finish;
 end
 initial begin #30000000;$fatal(1,"scanout timeout");end
endmodule
