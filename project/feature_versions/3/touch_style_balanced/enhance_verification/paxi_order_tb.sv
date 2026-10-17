`timescale 1ns/1ps
module paxi_order_tb;
 reg clk=0,rst=0,en=0;
 always #5 clk=~clk;
 reg [24:0] addr=0;
 reg [2:0] cmd=0;
 reg [127:0] data=0;
 wire ready,wrdy,awvalid,wvalid,wlast,arvalid;
 wire [24:0] awaddr,araddr;
 wire [127:0] wdata;
 wire [15:0] mask;
 reg awready=0,wready=0,arready=0;
 cartoon_ddr_bridge dut(.clk(clk),.rst_n(rst),.app_en(en),
 .app_addr(addr),.app_cmd(cmd),.app_wdata(data),.app_wmask(16'd0),
 .app_ready(ready),.app_wready(wrdy),.axi_awaddr(awaddr),
 .axi_awvalid(awvalid),.axi_awready(awready),.axi_wdata(wdata),
 .axi_wstrb(mask),.axi_wvalid(wvalid),.axi_wlast(wlast),.axi_wready(wready),
 .axi_araddr(araddr),.axi_arvalid(arvalid),.axi_arready(arready));
 integer awcount=0,wcount=0,rcount=0,wn=0,rn=0,i,cycle=0;
 integer wa[0:1023],ra[0:1023];
 reg [127:0] wd[0:1023];
 reg address_owned=0;
 integer offer_deadline=-1;
 reg held_aw=0,held_w=0,held_ar=0;
 reg [24:0] prev_aw,prev_ar;
 reg [127:0] prev_w;
 always @(posedge clk)begin
   if(!rst)begin
     address_owned=0;offer_deadline=-1;
     held_aw=0;held_w=0;held_ar=0;
   end else begin
     if(held_aw && (!awvalid || awaddr!==prev_aw))$fatal(1,"AW payload changed while stalled");
     if(held_w && (!wvalid || wdata!==prev_w))$fatal(1,"W payload changed while stalled");
     if(held_ar && (!arvalid || araddr!==prev_ar))$fatal(1,"AR payload changed while stalled");
     held_aw=awvalid&&!awready;prev_aw=awaddr;
     held_w=wvalid&&!wready;prev_w=wdata;
     held_ar=arvalid&&!arready;prev_ar=araddr;
     if(awvalid&&arvalid)$fatal(1,"bridge mixed read and write commands");
     // PH1P IPUG034 1.2 section 2.3.3.2, Figures 2-14 through 2-16:
     // permit W in the same accepted-address cycle or within two clocks.
     // A WVALID transfer ahead of any address is outside that schedule.
     if(awvalid&&awready)begin
       if(address_owned)$fatal(1,"a second write address was submitted before data completion");
       if(awcount>=wn || awaddr!==wa[awcount])$fatal(1,"lost/duplicated/reordered write address");
       awcount=awcount+1;address_owned=1;offer_deadline=2;
     end
     if(wvalid)begin
       if(!address_owned)$fatal(1,"PAXI_W_BEFORE_AW: write data offered before address acceptance");
       offer_deadline=-1;
     end else if(offer_deadline>=0)begin
       if(offer_deadline==0)$fatal(1,"pAXI write data not offered within two clocks of AW acceptance");
       offer_deadline=offer_deadline-1;
     end
     if(wvalid&&wready)begin
       if(wcount>=wn || wdata!==wd[wcount] || mask!==0 || !wlast)$fatal(1,"write payload mismatch");
       wcount=wcount+1;address_owned=0;
     end
     if(arvalid&&arready)begin
       if(rcount>=rn || araddr!==ra[rcount])$fatal(1,"lost/duplicated/reordered read address");
       rcount=rcount+1;
     end
   end
 end
 task send(input integer is_read,input integer a);
 begin
   @(negedge clk);while(!ready)@(negedge clk);
   addr=a;cmd=is_read?1:0;data={4{32'haf020000+a}};en=1;
   if(is_read)begin ra[rn]=a;rn=rn+1;end
   else begin wa[wn]=a;wd[wn]=data;wn=wn+1;end
   @(negedge clk);en=0;
   // Make the app payload change immediately after acceptance; the
   // pending controller payload must come from the transaction slot.
   addr=25'h1ffffff;data=0;cmd=7;
 end endtask
 initial begin
   repeat(5)@(negedge clk);rst=1;
   // Reproduce the old bridge's W-before-AW behavior explicitly.
   awready=0;wready=1;arready=1;
   send(0,32);repeat(16)@(negedge clk);
   if(awcount!=0 || wcount!=0 || wvalid || !awvalid || ready)$fatal(1,"write was not retained while AW stalled");
   awready=1;wait(wcount==1);
   // AW accepts now, W ready stays low. W must be offered promptly,
   // retained stably, and no following app command may enter the slot.
   @(negedge clk);wready=0;
   send(0,48);repeat(16)@(negedge clk);
   if(awcount!=2 || wcount!=1 || !wvalid || awvalid || ready)$fatal(1,"AW-first data backpressure failed");
   wready=1;wait(wcount==2);
   // Read acceptance must depend on ARREADY alone.
   @(negedge clk);arready=0;
   send(1,64);repeat(16)@(negedge clk);
   if(rcount!=0 || !arvalid || ready)$fatal(1,"ARREADY backpressure was ignored");
   arready=1;wait(rcount==1);
   fork
     begin for(i=0;i<900;i=i+1)send(i%3==0,128+i*8);end
     begin repeat(20000)begin
       @(negedge clk);cycle=cycle+1;
       awready=(cycle%11<5);wready=(cycle%7<3);arready=(cycle%13<4);
     end end
   join
   @(negedge clk);awready=1;wready=1;arready=1;
   wait(wcount==wn && rcount==rn);repeat(6)@(negedge clk);
   if(awcount!=wn || !ready || arvalid || awvalid || wvalid)$fatal(1,"leftover transaction");
   // Reset each partially completed channel state. Do not count the
   // abandoned transaction as a normal completion after cold restart.
   @(negedge clk);awready=0;
   send(0,9000);repeat(4)@(negedge clk);
   @(negedge clk);rst=0;repeat(4)@(negedge clk);rst=1;
   repeat(3)@(negedge clk);
   if(arvalid || awvalid || wvalid || !ready)$fatal(1,"pending AW survived transport reset");
   wn=awcount;
   @(negedge clk);awready=1;wready=0;
   send(0,9016);wait(wvalid);@(negedge clk);rst=0;
   repeat(4)@(negedge clk);rst=1;
   repeat(3)@(negedge clk);
   if(arvalid || awvalid || wvalid || !ready)$fatal(1,"pending W survived transport reset");
   $display("PASS PH1P pAXI write-order contract: 900 mixed commands, AW-before-W, W offered within two clocks, independent ready stalls, stable payloads, AR isolation, reset cancellation");
   $finish;
 end
 initial begin #1000000;$fatal(1,"pAXI order test timeout");end
endmodule
