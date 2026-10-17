// Additive replacement: the supplied video_in.v remains unchanged.
// SOF/mode travel WITH the first data word; no per-frame FIFO reset can
// erase that first word. Only an exactly complete, non-overflowed frame
// becomes eligible for scanout. The current read slot is never overwritten.
module cartoon_video_in #(parameter FRAME_WORDS=172800)(
 input wire I_rst_n,I_ddr_rst_n,
 input wire I_camera_clk,I_camera_frame_start,
 input wire [1:0] I_camera_mode,
 output reg [7:0] O_slot_modes,
 input wire I_camera_valid,input wire [127:0] I_camera_data,
 input wire I_mipi_rx_error,I_ddr_clk,I_display_pause,I_video_out_rd_busy,
 input wire [1:0] I_read_slot,
 output wire O_video_in_wr_busy,
 output reg [1:0] O_video_out_rp,
 output reg O_frame_available,O_publish_toggle,
 output wire O_ddr_user_wr_en,output wire [24:0] O_ddr_user_addr,
 output wire [127:0] O_ddr_user_wr_data,
 input wire I_ddr_user_ready
);
 reg pending_sof,frame_bad,user_d;
 reg [1:0] pending_mode;
 wire sof=I_camera_frame_start&&!user_d;
 wire full,empty;
 wire [131:0] head;
 wire [8:0] used;
 // A capture grant covers only data already buffered. Holding a 240-word
 // grant while waiting for the camera can starve scanout across a line gap.
 localparam WRITE_BURST_WORDS=64;
 reg burst_active;
 reg [7:0] burst_count;
 reg writing,bad;
 reg [17:0] word_count;
 reg [1:0] write_slot,frame_mode;
 wire head_sof=head[131],head_bad=head[130];
 wire pop=I_ddr_rst_n && burst_active && !empty && I_ddr_user_ready;
 wire fifo_rst=!(I_rst_n&&I_ddr_rst_n);
 always @(posedge I_camera_clk or negedge I_rst_n)begin
   if(!I_rst_n)begin pending_sof<=0;pending_mode<=0;frame_bad<=0;user_d<=0;end
   else begin
     user_d<=I_camera_frame_start;
     if(sof)begin pending_sof<=1;pending_mode<=I_camera_mode;frame_bad<=0;end
     if(I_camera_valid&&full)frame_bad<=1;
     if(I_camera_valid&&!full)pending_sof<=0;
   end
 end
 soft_fifo_al_4057d6b76aa6 #(.DATA_WIDTH_W(132),.DATA_WIDTH_R(132),
 .ADDR_WIDTH_W(9),.ADDR_WIDTH_R(9),.AL_FULL_NUM(480),.AL_EMPTY_NUM(2),
 .SHOW_AHEAD_EN(1),.OUTREG_EN("NOREG")) u_capture_fifo(
 .rst(fifo_rst),.clkw(I_camera_clk),.clkr(I_ddr_clk),
 .we(I_camera_valid&&!full),
 .di({sof||pending_sof,sof?1'b0:frame_bad,sof?I_camera_mode:pending_mode,I_camera_data}),
 .re(pop),.dout(head),.valid(),.full_flag(full),.empty_flag(empty),
 .afull(),.aempty(),.wrusedw(),.rdusedw(used));

 function [24:0] slot_base(input [1:0] s);
   case(s)0:slot_base=0;1:slot_base=7000000;2:slot_base=14000000;3:slot_base=21000000;endcase
 endfunction
 function [1:0] free_slot(input [1:0] prior,reading,latest);
   integer k;reg found;reg [1:0] c;
   begin
     free_slot=prior;found=0;
     for(k=1;k<=4;k=k+1)begin
       c=prior+k;
       if(!found&&c!=reading&&c!=latest)begin free_slot=c;found=1;end
     end
   end
 endfunction
 wire [1:0] next_slot=free_slot(write_slot,I_read_slot,O_video_out_rp);
 wire last_word=!head_sof&&writing&&(word_count==FRAME_WORDS-1);
 wire tail_ready=writing && (word_count<FRAME_WORDS) &&
                 ((FRAME_WORDS-word_count)<WRITE_BURST_WORDS) &&
                 (used>=(FRAME_WORDS-word_count));
 wire burst_ready=(used>=WRITE_BURST_WORDS) || tail_ready;
 assign O_video_in_wr_busy=burst_active;
 assign O_ddr_user_wr_en=pop&&(head_sof||writing)&&!I_display_pause;
 assign O_ddr_user_wr_data=head[127:0];
 assign O_ddr_user_addr=head_sof?slot_base(next_slot):(slot_base(write_slot)+{4'd0,word_count,3'b0});

 always @(posedge I_ddr_clk or negedge I_ddr_rst_n)begin
   if(!I_ddr_rst_n)begin
     burst_active<=0;burst_count<=0;writing<=0;bad<=0;word_count<=0;
     write_slot<=0;frame_mode<=0;O_video_out_rp<=0;O_slot_modes<=0;
     O_frame_available<=0;O_publish_toggle<=0;
   end else begin
     if(!burst_active)begin
       burst_count<=0;
       if(burst_ready&&!empty&&!I_video_out_rd_busy&&!I_display_pause)burst_active<=1;
     end else if(empty||I_display_pause)begin
       burst_active<=0;burst_count<=0;
     end else if(pop)begin
       if(burst_count==WRITE_BURST_WORDS-1||last_word)begin burst_active<=0;burst_count<=0;end
       else burst_count<=burst_count+1'b1;
     end
     if(pop)begin
       if(head_sof)begin
         write_slot<=next_slot;frame_mode<=head[129:128];
         word_count<=1;writing<=1;bad<=head_bad||I_mipi_rx_error;
       end else if(writing)begin
         word_count<=word_count+1'b1;bad<=bad||head_bad||I_mipi_rx_error;
         if(last_word)begin
           writing<=0;
           if(!bad&&!head_bad&&!I_mipi_rx_error&&!I_display_pause)begin
             O_video_out_rp<=write_slot;
             O_slot_modes[write_slot*2+:2]<=frame_mode;
             O_frame_available<=1;O_publish_toggle<=~O_publish_toggle;
           end
         end
       end
     end
   end
 end
endmodule
