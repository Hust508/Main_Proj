// Coalesce requests while the existing camera I2C writer is occupied.
// AG 16..89 is the original table's full range; AG80 matches startup 0x0f20.
module camera_gain_apply(
 input wire I_clk,I_rst_n,input wire [6:0] I_gain,
 input wire I_cam_done,I_ae_done,I_frame_toggle,
 output reg O_req,output wire [15:0] O_ae,output reg [15:0] O_ag
);
 reg initialized,wait_busy;
 (* async_reg="true" *) reg [1:0] fs_sync;
 reg fs_old;reg [1:0] cooldown;
 wire frame_tick=fs_sync[1]!=fs_old;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin fs_sync<=0;fs_old<=0;cooldown<=0;end
 else begin
  fs_sync<={fs_sync[0],I_frame_toggle};fs_old<=fs_sync[1];
  if(O_req)cooldown<=2;
  else if(frame_tick&&cooldown!=0)cooldown<=cooldown-1'b1;
 end
 wire [6:0] desired=(I_gain<16)?7'd16:(I_gain>89)?7'd89:I_gain;
 assign O_ae=16'd1990;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin O_req<=0;O_ag<=80;initialized<=0;wait_busy<=0;end
 else begin
  O_req<=0;
  if(!I_cam_done)begin initialized<=0;wait_busy<=0;end
  else if(wait_busy)begin if(!I_ae_done)wait_busy<=0;end
  else if(I_ae_done&&frame_tick&&cooldown==0&&(!initialized||O_ag!={9'd0,desired}))begin
   O_ag<={9'd0,desired};O_req<=1;initialized<=1;wait_busy<=1;
  end
 end
endmodule
