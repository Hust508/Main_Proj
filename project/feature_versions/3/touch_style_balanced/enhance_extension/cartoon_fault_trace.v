// Capture the first faulty DDR edge before recovery clears transaction state.
// Both banks use only the physical/cold reset; the transport reset cannot
// erase a snapshot. Faults are separated by the supervisor's >=2 ms reset.
// The source holds its payload until the next fault. A three-clock event
// crossing therefore gives the destination ample bundled-data settling time.
module cartoon_fault_trace(
 input wire cold_rst_n,ddr_clk,sys_clk,
 input wire event_i,input wire [95:0] snapshot_i,
 output reg [95:0] sys_trace
);
 reg [95:0] source_trace;
 reg source_toggle;
 always @(posedge ddr_clk or negedge cold_rst_n)begin
   if(!cold_rst_n)begin source_trace<=0;source_toggle<=0;end
   else if(event_i)begin source_trace<=snapshot_i;source_toggle<=~source_toggle;end
 end
 (* async_reg="true" *) reg seq_meta,seq_sync;
 reg seq_seen;
 always @(posedge sys_clk or negedge cold_rst_n)begin
   if(!cold_rst_n)begin seq_meta<=0;seq_sync<=0;seq_seen<=0;sys_trace<=0;end
   else begin
     seq_meta<=source_toggle;seq_sync<=seq_meta;
     if(seq_sync!=seq_seen)begin sys_trace<=source_trace;seq_seen<=seq_sync;end
   end
 end
endmodule
