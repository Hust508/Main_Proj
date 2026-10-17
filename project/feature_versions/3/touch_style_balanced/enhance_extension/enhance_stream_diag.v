// Cold-reset diagnostic counters; neither recovery nor display reset erases
// the first timeout snapshot. Both CDC hops use acknowledged held payloads.
module enhance_stream_diag(
 input wire cold_rst_n,cam_clk,sys_clk,pixel_clk,cam_run_n,recovery_run_n,
 input wire input_overflow_i,
 input wire av,asof,nv,nsof,ev,esof,pv,psof,drop_i,
 output reg [95:0] pixel_status
);
 reg [19:0] ac,nc,ec,pc;reg [15:0] drops;
 always @(posedge cam_clk or negedge cold_rst_n)begin
  if(!cold_rst_n)begin ac<=0;nc<=0;ec<=0;pc<=0;drops<=0;end
  else if(cam_run_n)begin
   if(asof)ac<=av?20'd1:20'd0;else if(av&&ac!=20'hfffff)ac<=ac+1'b1;
   if(nsof)nc<=nv?20'd1:20'd0;else if(nv&&nc!=20'hfffff)nc<=nc+1'b1;
   if(esof)ec<=ev?20'd1:20'd0;else if(ev&&ec!=20'hfffff)ec<=ec+1'b1;
   if(psof)pc<=pv?20'd1:20'd0;else if(pv&&pc!=20'hfffff)pc<=pc+1'b1;
   if(input_overflow_i)drops[15]<=1'b1;
   if(drop_i&&drops[14:0]!=15'h7fff)drops[14:0]<=drops[14:0]+1'b1;
  end
 end
 reg [95:0] source_payload;reg request,ack;
 (* async_reg="true" *) reg [1:0] ack_sync,req_sync;
 always @(posedge cam_clk or negedge cold_rst_n)begin
  if(!cold_rst_n)begin source_payload<=0;request<=0;ack_sync<=0;end
  else begin
   ack_sync<={ack_sync[0],ack};
   if(request==ack_sync[1])begin source_payload<={drops,pc,ec,nc,ac};request<=~request;end
  end
 end
 reg [95:0] system_live,frozen;
 reg was_running,freeze_started;reg [5:0] freeze_wait;
 always @(posedge sys_clk or negedge cold_rst_n)begin
  if(!cold_rst_n)begin req_sync<=0;ack<=0;system_live<=0;frozen<=0;was_running<=0;freeze_started<=0;freeze_wait<=0;end
  else begin
   req_sync<={req_sync[0],request};
   if(req_sync[1]!=ack)begin system_live<=source_payload;ack<=req_sync[1];end
   was_running<=recovery_run_n;
   if(!freeze_started&&was_running&&!recovery_run_n)begin freeze_started<=1;freeze_wait<=32;end
   else if(freeze_wait!=0)begin
    freeze_wait<=freeze_wait-1'b1;
    if(freeze_wait==1)frozen<=system_live;
   end
  end
 end
 reg [95:0] pixel_payload;reg preq,pack;
 (* async_reg="true" *) reg [1:0] preq_sync,pack_sync;
 always @(posedge sys_clk or negedge cold_rst_n)begin
  if(!cold_rst_n)begin pixel_payload<=0;preq<=0;pack_sync<=0;end
  else begin
   pack_sync<={pack_sync[0],pack};
   if(preq==pack_sync[1])begin
    pixel_payload<=(freeze_started&&freeze_wait==0)?frozen:system_live;preq<=~preq;
   end
  end
 end
 always @(posedge pixel_clk or negedge cold_rst_n)begin
  if(!cold_rst_n)begin preq_sync<=0;pack<=0;pixel_status<=0;end
  else begin
   preq_sync<={preq_sync[0],preq};
   if(preq_sync[1]!=pack)begin pixel_status<=pixel_payload;pack<=preq_sync[1];end
  end
 end
endmodule
