// Lossless RGB/event crossing from a possibly stopped D-PHY clock into a
// free-running processing clock. SOF, EOL, valid and frame mode share the FIFO.
// A SOF during blanking is a real event and must not wait for the first pixel.
module enhance_clock_bridge #(parameter FIFO_AW=10)(
 input wire I_src_clk,I_src_rst_n,I_dst_clk,I_dst_rst_n,
 input wire [95:0] I_rgb,input wire I_valid,I_sof,I_last,
 input wire [2:0] I_mode,
 output wire [95:0] O_rgb,output wire O_valid,O_sof,O_last,
 output wire [2:0] O_mode,output wire O_overflow
);
 reg user_d,overflow;reg [2:0] frame_mode;
 wire sof=I_sof&&!user_d;
 wire [2:0] requested=(I_mode==1)?3'd1:3'd0;
 wire [2:0] event_mode=sof?requested:frame_mode;
 wire event_valid=I_valid||sof;
 wire full,empty;wire [101:0] head;
 wire fifo_rst=!(I_src_rst_n&&I_dst_rst_n);
 always @(posedge I_src_clk or negedge I_src_rst_n)begin
  if(!I_src_rst_n)begin user_d<=0;frame_mode<=0;overflow<=0;end
  else begin
   user_d<=I_sof;if(sof)frame_mode<=requested;
   if(event_valid&&full)overflow<=1;
  end
 end
 soft_fifo_al_enhance_clock #(.DATA_WIDTH_W(102),.DATA_WIDTH_R(102),
 .ADDR_WIDTH_W(FIFO_AW),.ADDR_WIDTH_R(FIFO_AW),
 .AL_FULL_NUM((1<<FIFO_AW)-32),.AL_EMPTY_NUM(2),.SHOW_AHEAD_EN(1),.OUTREG_EN("NOREG")) u_rgb_fifo(
 .rst(fifo_rst),.clkw(I_src_clk),.clkr(I_dst_clk),
 .we(event_valid&&!full),.di({event_mode,I_last,sof,I_valid,I_rgb}),
 .re(I_dst_rst_n&&!empty),.dout(head),.full_flag(full),.empty_flag(empty),
 .valid(),.afull(),.aempty(),.wrusedw(),.rdusedw());
 assign O_rgb=head[95:0];assign O_valid=I_dst_rst_n&&!empty&&head[96];
 assign O_sof=I_dst_rst_n&&!empty&&head[97];
 assign O_last=I_dst_rst_n&&!empty&&head[98];assign O_mode=head[101:99];
 (* async_reg="true" *) reg [1:0] overflow_sync;
 always @(posedge I_dst_clk or negedge I_dst_rst_n)begin
  if(!I_dst_rst_n)overflow_sync<=0;else overflow_sync<={overflow_sync[0],overflow};
 end
 assign O_overflow=overflow_sync[1];
endmodule
