


module cartoon_video_out #(parameter DDR_STALL_CYCLES=133333) (
    input wire [8:0] I_diag_queue_words,
    input wire I_diag_queue_empty,I_diag_queue_afull,
    input wire [5:0] I_diag_link,
    input wire [15:0] I_diag_axi_pending,
    output wire O_fault_event,
    output wire [95:0] O_fault_snapshot,
    input wire        I_rst_n, // Same transport reset as DDR queues and bridge.
    input wire        I_pixel_rst_n,
    input wire        I_frame_available,
    output reg [1:0] O_read_slot,
    input wire        I_display_ready_n, // May drop independently; keep DDR accounting.
    output reg        O_recovery_req,

    input wire        I_ddr_clk,
    output wire       O_video_out_rd_busy,  
    input wire        I_video_in_wr_busy,   
    input wire[1:0]   I_video_out_rp,
    input wire[11:0]  I_slot_modes,
    output reg[2:0]   O_frame_mode,
    output wire       O_ddr_user_rd_en,
    output reg[24:0]  O_ddr_user_addr,
    input wire        I_ddr_user_ready,
    input wire        I_ddr_user_rd_valid,
    input wire[127:0] I_ddr_user_rd_data,

    input wire        I_dsi_clk,
    input wire        I_video_vsync,
    input wire        I_video_rd_en,  
    output reg[23:0]  O_vdieo_data
);

    localparam CROP_OFFSET = 25'd115392; // ((60*1280+128)*3)/2
    localparam ROW_SKIP = 25'd384; // (1280-1024)*3/2, in 16-bit address units
    reg [7:0] S_crop_word;
    reg [9:0] S_crop_row;
    reg [9:0] S_outstanding_reads;
    wire        S_video_frame_start;
    reg S_have_frame;
    reg S_frame_pending;
    reg S_frame_ready;
    reg         S_fifo_rst;     
    wire S_flush_start = S_frame_pending && (S_outstanding_reads == 0)
                        && I_display_ready_n && !S_video_frame_start;
    reg[7:0]    S_fifo_rst_cnt;
    wire[8:0]   S_fifo_wr_num;       
    wire        S_fifo_rd_en;        
    wire[127:0] S_fifo_rd_data;      
    reg         S_video_vsync_1d;
    reg         S_video_vsync_2d;
    reg         S_video_vsync_3d;
   
    wire        S_ddr_rd_trig;       
    reg         S_ddr_rd_valid;      
    reg[9:0]    S_ddr_rd_cnt;        
    reg[3:0]    S_fifo_rd_cnt;       
    reg         S_video_rd_en_1d;
    reg[3:0]    S_fifo_rd_cnt_1d;     
    reg[127:0]  S_fifo_rd_data_1d;    
	wire        S_fifo_emtpy;     



    // Capture the selected slot's mode on the same edge as its read address.
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin O_frame_mode<=0;O_read_slot<=0;end
        else if(S_video_frame_start && I_frame_available)begin
            O_frame_mode<=I_slot_modes[I_video_out_rp*3 +: 3];O_read_slot<=I_video_out_rp;
        end
    end

    localparam IMAGE_BASE_ADDR_0 = 25'd0;
    localparam IMAGE_BASE_ADDR_1 = 25'd7000000;
    localparam IMAGE_BASE_ADDR_2 = 25'd14000000;
    localparam IMAGE_BASE_ADDR_3 = 25'd21000000;


    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            S_video_vsync_1d<=0; S_video_vsync_2d<=0; S_video_vsync_3d<=0;
        end else if(!I_display_ready_n) begin
            S_video_vsync_1d<=0; S_video_vsync_2d<=0; S_video_vsync_3d<=0;
        end else begin
            S_video_vsync_1d<=I_video_vsync;
            S_video_vsync_2d<=S_video_vsync_1d;
            S_video_vsync_3d<=S_video_vsync_2d;
        end
    end
    assign S_video_frame_start = ~S_video_vsync_3d & S_video_vsync_2d;

    // Count actual app transactions for their full lifetime, including a
    // display-only pause. A timeout requests a coordinated transport reset;
    // it NEVER clears the count while old requests may still return.
    localparam STALL_W=(DDR_STALL_CYCLES<2)?1:$clog2(DDR_STALL_CYCLES);
    reg [STALL_W-1:0] S_stall_count;
    wire S_owned_return=I_ddr_user_rd_valid &&
                       ((S_outstanding_reads!=0) || O_ddr_user_rd_en);
    wire fault_extra=I_ddr_user_rd_valid&&!O_ddr_user_rd_en&&(S_outstanding_reads==0);
    wire fault_overflow=O_ddr_user_rd_en&&!I_ddr_user_rd_valid&&(S_outstanding_reads==10'h3ff);
    wire stalled=!(S_owned_return || O_ddr_user_rd_en || ((S_outstanding_reads==0)&&!S_ddr_rd_valid));
    wire fault_timeout=stalled&&(S_stall_count==DDR_STALL_CYCLES-1);
    wire [3:0] fault_kind=fault_extra?4'd2:(fault_overflow?4'd3:((S_outstanding_reads!=0)?4'd1:4'd4));
    assign O_fault_event=I_rst_n&&!O_recovery_req&&(fault_extra||fault_overflow||fault_timeout);
    assign O_fault_snapshot={I_diag_axi_pending,
        I_diag_link,I_diag_queue_afull,I_diag_queue_empty,
        I_display_ready_n,S_frame_pending,S_frame_ready,S_ddr_rd_valid,
        I_video_in_wr_busy,O_ddr_user_rd_en,I_ddr_user_rd_valid,I_ddr_user_ready,
        2'b0,S_ddr_rd_cnt,2'b0,S_crop_row,3'b0,S_fifo_wr_num,
        3'b0,I_diag_queue_words,2'b0,S_outstanding_reads,fault_kind};
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_outstanding_reads<=0; S_stall_count<=0; O_recovery_req<=0;
        end else begin
            case({O_ddr_user_rd_en,I_ddr_user_rd_valid})
                2'b10: begin
                    if(S_outstanding_reads==10'h3ff) O_recovery_req<=1;
                    else S_outstanding_reads<=S_outstanding_reads+1'b1;
                end
                2'b01: begin
                    if(S_outstanding_reads==0) O_recovery_req<=1;
                    else S_outstanding_reads<=S_outstanding_reads-1'b1;
                end
                default: ;
            endcase
            if (S_owned_return || O_ddr_user_rd_en ||
                ((S_outstanding_reads==0) && !S_ddr_rd_valid)) S_stall_count<=0;
            else if(S_stall_count==DDR_STALL_CYCLES-1) O_recovery_req<=1;
            else S_stall_count<=S_stall_count+1'b1;
        end
    end

    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_frame_pending<=0; S_frame_ready<=0; S_have_frame<=0;
            S_fifo_rst<=1; S_fifo_rst_cnt<=0;
        end else if(!I_display_ready_n || O_recovery_req) begin
            S_frame_pending<=0; S_frame_ready<=0; S_have_frame<=0;
            S_fifo_rst<=1; S_fifo_rst_cnt<=0;
        end else if(S_video_frame_start) begin
            S_frame_pending<=I_frame_available; S_frame_ready<=0; S_have_frame<=I_frame_available;
        end else if(S_flush_start) begin
            S_fifo_rst<=1; S_fifo_rst_cnt<=0; S_frame_pending<=0;
        end else if(S_fifo_rst) begin
            if(S_fifo_rst_cnt==8'd10) begin
                S_fifo_rst<=0;
                S_frame_ready<=S_have_frame && !S_frame_pending;
            end else S_fifo_rst_cnt<=S_fifo_rst_cnt+1'b1;
        end
    end

    /*
        这里需要注意fifo的剩余空间一定要大于将要写入的长度，因为ddr读出的时候会有至少40个时钟周期的延时，
        例如每次从ddr读出240个长度的数据，那么fifo的剩余空间最少要设为280，否则会引起fifo写满丢失数据。
    */
    wire [10:0] S_reserved_words={2'b00,S_fifo_wr_num}+{1'b0,S_outstanding_reads};
    // Reserve every queued response before launching a complete 192-word row.
    assign S_ddr_rd_trig = (S_reserved_words<=11'd310) && (('d511 - S_fifo_wr_num) >= 'd300) && (!I_video_in_wr_busy) && (!S_ddr_rd_valid) && (!S_fifo_rst) && I_rst_n && I_display_ready_n && !O_recovery_req && S_frame_ready && !S_video_frame_start && (S_crop_row < 600) ? 1'b1 : 1'b0;

    /*
        fifo的深度是512，实际的深度是510，因此需要注意每次读出的长度避免为256，否则连续两次写入会引起fifo写满，丢失数据
    */
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            S_ddr_rd_valid <= 1'b0;
        else
			if(!I_display_ready_n || O_recovery_req || S_video_frame_start || S_frame_pending || (O_ddr_user_rd_en && S_ddr_rd_cnt == 'd191))
                S_ddr_rd_valid <= 1'b0;
            else if(S_ddr_rd_trig)
                S_ddr_rd_valid <= 1'b1;
            else
                S_ddr_rd_valid <= S_ddr_rd_valid;
    end

    assign O_ddr_user_rd_en = I_rst_n & I_display_ready_n & ~O_recovery_req &
                             S_ddr_rd_valid & I_ddr_user_ready & S_frame_ready & ~S_video_frame_start;

    always @(posedge I_ddr_clk) begin
        if(S_ddr_rd_valid && !S_video_frame_start)
            begin
                if(O_ddr_user_rd_en)
                    S_ddr_rd_cnt <= S_ddr_rd_cnt + 'd1;
                else
                    S_ddr_rd_cnt <= S_ddr_rd_cnt;
            end
        else    
            S_ddr_rd_cnt <= 'd0;
    end


    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            O_ddr_user_addr <= 'd0;
        else
            if(S_video_frame_start)
                begin
                    case(I_video_out_rp)
                        'd0: O_ddr_user_addr <= IMAGE_BASE_ADDR_0 + CROP_OFFSET;
                        'd1: O_ddr_user_addr <= IMAGE_BASE_ADDR_1 + CROP_OFFSET;
                        'd2: O_ddr_user_addr <= IMAGE_BASE_ADDR_2 + CROP_OFFSET;
                        'd3: O_ddr_user_addr <= IMAGE_BASE_ADDR_3 + CROP_OFFSET;
                    endcase
                end
            else if(O_ddr_user_rd_en)
                O_ddr_user_addr <= O_ddr_user_addr + 25'd8 +
                                   ((S_crop_word == 191) ? ROW_SKIP : 25'd0);
            else    
                O_ddr_user_addr <= O_ddr_user_addr;
    end

    
    always @(posedge I_ddr_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin S_crop_word <= 0; S_crop_row <= 0; end
        else if (S_video_frame_start) begin S_crop_word <= 0; S_crop_row <= 0; end
        else if (O_ddr_user_rd_en) begin
            if (S_crop_word == 191) begin
                S_crop_word <= 0;
                S_crop_row <= S_crop_row + 1'b1;
            end else S_crop_word <= S_crop_word + 1'b1;
        end
    end

    assign O_video_out_rd_busy = S_ddr_rd_trig | S_ddr_rd_valid;


    w128_d512_fifo U_w128_d512_fifo(
        .rst        ( S_fifo_rst          ),   

        .clkw       ( I_ddr_clk           ),     
        .we         ( S_owned_return && S_frame_ready && !S_frame_pending &&
                      !S_video_frame_start && !S_fifo_rst && I_display_ready_n && !O_recovery_req ),
        .di         ( I_ddr_user_rd_data  ),
        .wrusedw    ( S_fifo_wr_num       ),
        .afull      (),
        .full_flag  (),
 
        .clkr       ( I_dsi_clk           ),
        .re         ( S_fifo_rd_en        ), 
        .dout       ( S_fifo_rd_data      ),  
        .rdusedw    (), 
        .valid      (),  
        .empty_flag ( S_fifo_emtpy        ),
        .aempty     ()
    );


   always @(posedge I_dsi_clk) begin
       if(I_video_rd_en)
           S_fifo_rd_cnt <= S_fifo_rd_cnt + 'd1;
       else
           S_fifo_rd_cnt <= 'd0;
   end

   wire S_fifo_pop_slot = I_video_rd_en && (S_fifo_rd_cnt == 'd0)  ? 1'b1 :
                         I_video_rd_en && (S_fifo_rd_cnt == 'd5)  ? 1'b1 :
                         I_video_rd_en && (S_fifo_rd_cnt == 'd10) ? 1'b1 : 1'b0;

   reg S_scanout_bad;
   always @(posedge I_dsi_clk or negedge I_pixel_rst_n) begin
       if(!I_pixel_rst_n) S_scanout_bad<=1;
       else if(I_video_vsync) S_scanout_bad<=0;
       else if(S_fifo_pop_slot && S_fifo_emtpy) S_scanout_bad<=1;
   end
   assign S_fifo_rd_en=S_fifo_pop_slot && !S_fifo_emtpy && !S_scanout_bad;

   always @(posedge I_dsi_clk) begin
       S_video_rd_en_1d  <= I_video_rd_en;
       S_fifo_rd_cnt_1d  <= S_fifo_rd_cnt;
       S_fifo_rd_data_1d <= S_fifo_rd_data;
   end

   always @(posedge I_dsi_clk) begin
       if(S_video_rd_en_1d && !S_scanout_bad && I_pixel_rst_n)
           begin
               case(S_fifo_rd_cnt_1d)
                   'd0: O_vdieo_data  <= S_fifo_rd_data[127:104];
                   'd1: O_vdieo_data  <= S_fifo_rd_data[103:80];
                   'd2: O_vdieo_data  <= S_fifo_rd_data[79:56];
                   'd3: O_vdieo_data  <= S_fifo_rd_data[55:32];
                   'd4: O_vdieo_data  <= S_fifo_rd_data[31:8];
                   'd5: O_vdieo_data  <= {S_fifo_rd_data_1d[7:0],S_fifo_rd_data[127:112]};
                   'd6: O_vdieo_data  <= S_fifo_rd_data[111:88];
                   'd7: O_vdieo_data  <= S_fifo_rd_data[87:64];
                   'd8: O_vdieo_data  <= S_fifo_rd_data[63:40];
                   'd9: O_vdieo_data  <= S_fifo_rd_data[39:16];
                   'd10: O_vdieo_data <= {S_fifo_rd_data_1d[15:0],S_fifo_rd_data[127:120]};
                   'd11: O_vdieo_data <= S_fifo_rd_data[119:96];
                   'd12: O_vdieo_data <= S_fifo_rd_data[95:72];
                   'd13: O_vdieo_data <= S_fifo_rd_data[71:48];
                   'd14: O_vdieo_data <= S_fifo_rd_data[47:24];
                   'd15: O_vdieo_data <= S_fifo_rd_data[23:0];
               endcase
           end
       else
           O_vdieo_data <= 'd0;
   end

    
endmodule
