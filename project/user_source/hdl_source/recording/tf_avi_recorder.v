// One-shot AVI recorder for a TF card prepared by tools/tf_prepare.py.
// The SPI block originates from Official/2_Example/18_sd_card_audio.
module tf_avi_recorder #(
    parameter HEADER_FILE = "../../../user_source/hdl_source/recording/avi_header.hex"
) (
    input wire I_clk, I_video_clk, I_rst_n,
    input wire I_card_detect_n, I_record_request,
    input wire I_vsync, I_de,
    input wire [23:0] I_rgb,
    output wire O_sd_cs_n, O_sd_clk, O_sd_mosi,
    input wire I_sd_miso,
    output wire [2:0] O_status,
    output reg [11:0] O_frames
);
    localparam [2:0] STAT_NO_CARD=0, STAT_READY=1, STAT_RECORDING=2,
                     STAT_SAVING=3, STAT_DONE=4, STAT_ERROR=5;
    localparam [31:0] FILE_LBA=32'd4067;
    localparam [11:0] MAX_FRAMES=12'd1800;
    localparam [14:0] BLOCK_BYTES=15'd29184;
    localparam [3:0] ST_INIT=0,ST_VERIFY_REQ=1,ST_VERIFY_WAIT=2,
                     ST_READY=3,ST_RECORD=4,ST_WRITE_REQ=5,
                     ST_WRITE_WAIT=6,ST_STOP_WAIT=7,
                     ST_HEADER_REQ=8,ST_HEADER_WAIT=9,ST_DONE=10,ST_ERROR=11;
    reg [3:0] rec_state;

    // The video input is the 1024x600 pre-UI camera image. Sample one
    // pixel in each 8x8 cell, producing 128x75 BGR24 without scaling logic.
    (* ram_style="block" *) reg [23:0] frame_ram [0:9599];
    reg [13:0] write_pixel;
    reg [10:0] vx,vy;
    reg [2:0] video_div;
    reg video_vs_d,video_de_d,capture_active,frame_toggle;
    (* async_reg="true" *) reg [1:0] arm_sync,free_sync;
    reg buffer_free;
    wire arm=(rec_state==ST_RECORD);
    always @(posedge I_video_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            arm_sync<=0;free_sync<=0;vx<=0;vy<=0;
            video_div<=0;video_vs_d<=0;video_de_d<=0;
            capture_active<=0;frame_toggle<=0;write_pixel<=0;
        end else begin
            arm_sync<={arm_sync[0],arm};
            free_sync<={free_sync[0],buffer_free};
            video_vs_d<=I_vsync;video_de_d<=I_de;
            if(I_vsync&&!video_vs_d) begin
                vx<=0;vy<=0;
                if(capture_active) frame_toggle<=!frame_toggle;
                capture_active<=arm_sync[1]&&free_sync[1]&&(video_div==0);
                write_pixel<=0;
                video_div<=(video_div==5)?0:video_div+1'b1;
            end else begin
                if(I_de) begin
                    vx<=vx+1'b1;
                    if(capture_active && vx[2:0]==0 && vy[2:0]==0 &&
                       vx<1024 && vy<600 && write_pixel<9600) begin
                        frame_ram[write_pixel]<=I_rgb;
                        write_pixel<=write_pixel+1'b1;
                    end
                end else vx<=0;
                if(video_de_d&&!I_de) vy<=vy+1'b1;
            end
        end
    end

    (* async_reg="true" *) reg [1:0] frame_sync,busy_sync;
    reg frame_seen;
    reg [9:0] verify_index;
    reg verify_ok;
    // Status is deliberately separate from the four-bit recorder state.
    reg [2:0] status;
    assign O_status=status;
    wire card_present=!I_card_detect_n;
    reg sd_read,sd_write;
    reg [31:0] sd_read_lba,sd_write_lba;
    wire sd_init,sd_read_valid,sd_read_end,sd_write_req,sd_write_end;
    wire [7:0] sd_read_data;
    wire [7:0] sd_write_data;
    sd_card_top #(.SPI_LOW_SPEED_DIV(30),.SPI_HIGH_SPEED_DIV(0)) card (
        .clk(I_clk),.rst(!I_rst_n),
        .SD_nCS(O_sd_cs_n),.SD_DCLK(O_sd_clk),.SD_MOSI(O_sd_mosi),.SD_MISO(I_sd_miso),
        .sd_init_done(sd_init),
        .sd_sec_read(sd_read),.sd_sec_read_addr(sd_read_lba),
        .sd_sec_read_data(sd_read_data),.sd_sec_read_data_valid(sd_read_valid),
        .sd_sec_read_end(sd_read_end),
        .sd_sec_write(sd_write),.sd_sec_write_addr(sd_write_lba),
        .sd_sec_write_data(sd_write_data),.sd_sec_write_data_req(sd_write_req),
        .sd_sec_write_end(sd_write_end)
    );

    reg [7:0] header_rom [0:511];
    initial $readmemh(HEADER_FILE,header_rom);
    reg [8:0] sector_byte;
    reg [14:0] frame_byte;
    reg [13:0] read_pixel;
    reg [1:0] component,tx_component;
    reg [23:0] pixel_word;
    reg tx_pixel;
    reg [7:0] tx_constant;
    reg final_header;
    reg [5:0] frame_sector;
    reg [31:0] next_lba,movi_bytes;
    reg [24:0] watchdog;
    reg [16:0] stop_wait;
    wire [31:0] riff_size=32'd504+movi_bytes;
    wire [31:0] movi_size=32'd4+movi_bytes;
    wire [7:0] pixel_byte=(tx_component==0)?pixel_word[7:0]:
                          (tx_component==1)?pixel_word[15:8]:pixel_word[23:16];
    wire [7:0] dynamic_header =
        (sector_byte>=4 && sector_byte<8)?(riff_size >> ((sector_byte-4)*8)):
        (sector_byte>=48 && sector_byte<52)?(O_frames >> ((sector_byte-48)*8)):
        (sector_byte>=140 && sector_byte<144)?(O_frames >> ((sector_byte-140)*8)):
        (sector_byte>=504 && sector_byte<508)?(movi_size >> ((sector_byte-504)*8)):
        (final_header && sector_byte>=220 && sector_byte<226)?
             ((sector_byte==222)?8'h44:(sector_byte==223)?8'h4f:
              (sector_byte==224)?8'h4e:(sector_byte==225)?8'h45:
              header_rom[sector_byte]):header_rom[sector_byte];
    assign sd_write_data=tx_pixel?pixel_byte:tx_constant;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            frame_sync<=0;busy_sync<=0;frame_seen<=0;buffer_free<=1;
            rec_state<=ST_INIT;status<=STAT_NO_CARD;O_frames<=0;
            sd_read<=0;sd_write<=0;sd_read_lba<=FILE_LBA;sd_write_lba<=FILE_LBA;
            verify_index<=0;verify_ok<=1;sector_byte<=0;frame_byte<=0;
            read_pixel<=0;component<=0;tx_component<=0;pixel_word<=0;
            tx_pixel<=0;tx_constant<=0;final_header<=0;
            frame_sector<=0;next_lba<=FILE_LBA+1; movi_bytes<=0;
            watchdog<=0;stop_wait<=0;
        end else begin
            frame_sync<={frame_sync[0],frame_toggle};
            busy_sync<={busy_sync[0],capture_active};
            sd_read<=0;sd_write<=0;
            if(!card_present) begin
                // Never issue writes after removal. Power cycle to re-arm.
                status<=STAT_NO_CARD;
                if(rec_state!=ST_INIT)rec_state<=ST_ERROR;
            end else case(rec_state)
                ST_INIT: begin
                    status<=STAT_NO_CARD;
                    if(sd_init)rec_state<=ST_VERIFY_REQ;
                end
                ST_VERIFY_REQ: begin
                    sd_read<=1;sd_read_lba<=FILE_LBA;
                    verify_index<=0;verify_ok<=1;watchdog<=0;
                    rec_state<=ST_VERIFY_WAIT;
                end
                ST_VERIFY_WAIT: begin
                    watchdog<=watchdog+1'b1;
                    if(sd_read_valid) begin
                        verify_index<=verify_index+1'b1;
                        case(verify_index)
                            10'd220:if(sd_read_data!=8'h54)verify_ok<=0; // T
                            10'd221:if(sd_read_data!=8'h46)verify_ok<=0; // F
                            10'd222:if(sd_read_data!=8'h52)verify_ok<=0; // R
                            10'd223:if(sd_read_data!=8'h45)verify_ok<=0; // E
                            10'd224:if(sd_read_data!=8'h43)verify_ok<=0; // C
                            10'd225:if(sd_read_data!=8'h31)verify_ok<=0; // 1
                            default:;
                        endcase
                    end
                    if(sd_read_end) begin
                        if(verify_ok && verify_index==10'd512) begin status<=STAT_READY;rec_state<=ST_READY;end
                        else begin status<=STAT_ERROR;rec_state<=ST_ERROR;end
                    end else if(watchdog==25'd24999999) begin
                        status<=STAT_ERROR;rec_state<=ST_ERROR;
                    end
                end
                ST_READY: if(I_record_request) begin
                    status<=STAT_RECORDING;rec_state<=ST_RECORD;
                end
                ST_RECORD: begin
                    if(frame_sync[1]!=frame_seen && O_frames<MAX_FRAMES) begin
                        frame_seen<=frame_sync[1];buffer_free<=0;
                        frame_sector<=0;frame_byte<=0;read_pixel<=0;component<=0;
                        rec_state<=ST_WRITE_REQ;
                    end else if(!I_record_request || O_frames==MAX_FRAMES) begin
                        status<=STAT_SAVING;stop_wait<=0;rec_state<=ST_STOP_WAIT;
                    end
                end
                ST_WRITE_REQ: begin
                    sd_write<=1;sd_write_lba<=next_lba;
                    sector_byte<=0;watchdog<=0;
                    rec_state<=ST_WRITE_WAIT;
                end
                ST_WRITE_WAIT: begin
                    watchdog<=watchdog+1'b1;
                    if(sd_write_req) begin
                        sector_byte<=sector_byte+1'b1;
                        frame_byte<=frame_byte+1'b1;
                        tx_pixel<=0;
                        if(frame_byte>=15'd8 && frame_byte<15'd28808) begin
                            tx_pixel<=1;
                            pixel_word<=frame_ram[read_pixel];
                            tx_component<=component;
                            if(component==2) begin component<=0;read_pixel<=read_pixel+1'b1;end
                            else component<=component+1'b1;
                        end else if(frame_byte<4) tx_constant<=
                            (frame_byte==2)?8'h64:(frame_byte==3)?8'h62:8'h30; // 00db
                        else if(frame_byte<8) tx_constant<=
                            (frame_byte==4)?8'h80:(frame_byte==5)?8'h70:8'h00; // 28800
                        else if(frame_byte>=28808 && frame_byte<28812) tx_constant<=
                            (frame_byte==28808)?8'h4a:(frame_byte==28809)?8'h55:
                            (frame_byte==28810)?8'h4e:8'h4b; // JUNK
                        else if(frame_byte>=28812 && frame_byte<28816) tx_constant<=
                            (frame_byte==28812)?8'h70:(frame_byte==28813)?8'h01:8'h00; // 368
                        else tx_constant<=0;
                    end
                    if(sd_write_end) begin
                        next_lba<=next_lba+1'b1;
                        if(frame_sector==56) begin
                            O_frames<=O_frames+1'b1;
                            movi_bytes<=movi_bytes+BLOCK_BYTES;
                            buffer_free<=1;
                            final_header<=!I_record_request || O_frames==MAX_FRAMES-1;
                            rec_state<=ST_HEADER_REQ;
                        end else begin
                            frame_sector<=frame_sector+1'b1;
                            rec_state<=ST_WRITE_REQ;
                        end
                    end else if(watchdog==25'd24999999) begin
                        status<=STAT_ERROR;rec_state<=ST_ERROR;
                    end
                end
                ST_STOP_WAIT: begin
                    stop_wait<=stop_wait+1'b1;
                    if(frame_sync[1]!=frame_seen && O_frames<MAX_FRAMES) begin
                        frame_seen<=frame_sync[1];buffer_free<=0;
                        frame_sector<=0;frame_byte<=0;read_pixel<=0;component<=0;
                        rec_state<=ST_WRITE_REQ;
                    end else if(stop_wait==17'd100000 && !busy_sync[1]) begin
                        final_header<=1;rec_state<=ST_HEADER_REQ;
                    end
                end
                ST_HEADER_REQ: begin
                    sd_write<=1;sd_write_lba<=FILE_LBA;
                    sector_byte<=0;watchdog<=0;
                    rec_state<=ST_HEADER_WAIT;
                end
                ST_HEADER_WAIT: begin
                    watchdog<=watchdog+1'b1;
                    if(sd_write_req) begin
                        tx_pixel<=0;tx_constant<=dynamic_header;
                        sector_byte<=sector_byte+1'b1;
                    end
                    if(sd_write_end) begin
                        if(final_header) begin status<=STAT_DONE;rec_state<=ST_DONE;end
                        else if(I_record_request) rec_state<=ST_RECORD;
                        else begin status<=STAT_SAVING;stop_wait<=0;rec_state<=ST_STOP_WAIT;end
                    end else if(watchdog==25'd24999999) begin
                        status<=STAT_ERROR;rec_state<=ST_ERROR;
                    end
                end
                ST_DONE: status<=STAT_DONE;
                default:begin status<=STAT_ERROR;rec_state<=ST_ERROR;end
            endcase
        end
    end
endmodule
