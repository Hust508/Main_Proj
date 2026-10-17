// Diagnostic history lives on the independent 25 MHz clock. Only KEY1 clears
// it; transport, PLL lock and panel resets must not erase the evidence.
module cartoon_fault_monitor(
 input wire clk,rst_n,input wire [5:0] healthy,
 input wire [2:0] reason,input wire pixel_clk,
 input wire [95:0] trace_i,
 output reg [194:0] pixel_status
);
 (* async_reg="true" *) reg [5:0] meta,synced;
 reg [5:0] prior,seen;
 reg [95:0] counts;
 reg [2:0] last_reason;
 integer i;
 always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin meta<=0;synced<=0;prior<=0;seen<=0;counts<=0;last_reason<=0;end
   else begin
     meta<=healthy;synced<=meta;prior<=synced;seen<=seen|synced;
     for(i=0;i<6;i=i+1)begin
       if(seen[i]&&prior[i]&&!synced[i]&&counts[i*16+:16]!=16'hffff)
         counts[i*16+:16]<=counts[i*16+:16]+1'b1;
     end
     if(seen[3]&&prior[3]&&!synced[3])last_reason<=reason;
   end
 end
 // Bundled-data mailbox. Hold all counter bits until the destination has
 // captured the payload and its acknowledgement crosses back. The mailbox
 // survives a stopped/restarted DSI clock and display-only reset.
 reg [194:0] payload;
 reg req,ack;
 (* async_reg="true" *) reg [1:0] req_sync,ack_sync;
 always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin payload<=0;req<=0;ack_sync<=0;end
   else begin
     ack_sync<={ack_sync[0],ack};
     if(req==ack_sync[1])begin payload<={trace_i,last_reason,counts};req<=~req;end
   end
 end
 always @(posedge pixel_clk or negedge rst_n)begin
   if(!rst_n)begin req_sync<=0;ack<=0;pixel_status<=0;end
   else begin
     req_sync<={req_sync[0],req};
     if(req_sync[1]!=ack)begin pixel_status<=payload;ack<=req_sync[1];end
   end
 end
endmodule
