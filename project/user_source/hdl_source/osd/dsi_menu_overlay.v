// Frame-synchronous, translucent 1024x600 slide-up drawer.
// Exactly two registered stages keep RGB and VS/HS/DE aligned.
module dsi_menu_overlay (
    input wire I_clk, I_rst_n,
    input wire I_visible,
    input wire [1:0] I_mode,
    input wire I_vsync, I_hsync, I_de,
    input wire [23:0] I_data,
    output reg O_vsync, O_hsync, O_de,
    output reg [23:0] O_data
);
    reg vs_d, de_d;
    (* async_reg="true" *) reg visible_meta,visible_sync;
    reg visible_frame;
    reg [11:0] x, y;
    wire frame_start = I_vsync && !vs_d;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            vs_d<=0;de_d<=0;x<=0;y<=0;
            visible_meta<=0;visible_sync<=0;visible_frame<=0;
        end
        else begin
            visible_meta<=I_visible;visible_sync<=visible_meta;
            vs_d<=I_vsync; de_d<=I_de;
            if(frame_start) begin x<=0; y<=0; visible_frame<=visible_sync; end
            else begin
                if(I_de) x<=x+1'b1; else x<=0;
                if(de_d && !I_de) y<=y+1'b1;
            end
        end
    end

    reg [1:0] button;
    reg [9:0] label_x;
    reg [7:0] label_width;
    reg [7:0] char_code;
    reg [3:0] char_col, char_row;
    reg label_region;
    wire [15:0] char_bits;
    wire selected = button==I_mode;
    osd_char_lib u_font(.I_char(char_code),.I_row(char_row),.O_row_bits(char_bits));

    // Three independent hit regions leave generous gaps to avoid wrong taps.
    always @(*) begin
        button=3; label_x=0; label_width=0; char_code=0;
        char_col=0; char_row=0; label_region=0;
        if(x>=24 && x<312) begin button=0; label_x=120; label_width=96; end
        else if(x>=364 && x<660) begin button=1; label_x=448; label_width=128; end
        else if(x>=712 && x<1000) begin button=2; label_x=808; label_width=96; end
        if(button!=3 && x>=label_x && x<label_x+label_width && y>=520 && y<552) begin
            label_region=1;
            char_col=(x-label_x)>>1;
            char_row=(y-520)>>1;
            case(button)
            0: case((x-label_x)>>5)
                0: char_code="R"; 1: char_code="A"; 2: char_code="W";
                default: char_code=0;
               endcase
            1: case((x-label_x)>>5)
                0: char_code="E"; 1: char_code="D";
                2: char_code="G"; 3: char_code="E";
                default: char_code=0;
               endcase
            2: case((x-label_x)>>5)
                0: char_code="O"; 1: char_code="S"; 2: char_code="D";
                default: char_code=0;
               endcase
            endcase
        end
    end

    reg [23:0] menu_rgb,paint_rgb;
    reg text_pixel;
    always @(*) begin
        paint_rgb=24'h101b28;
        text_pixel=0;
        menu_rgb=I_data;
        if(I_de && visible_frame && y>=450 && y<600) begin
            if(y<454) paint_rgb=24'h38b7c9;
            else if(y>=465 && y<470 && x>=462 && x<562)
                paint_rgb=24'h9bdce4;
            else if(button!=3 && y>=495 && y<580) begin
                paint_rgb=selected ? 24'h176b80 : 24'h273748;
                if(y<498 || y>=577 ||
                   (button==0 && (x<27 || x>=309)) ||
                   (button==1 && (x<367 || x>=657)) ||
                   (button==2 && (x<715 || x>=997)))
                    paint_rgb=selected ? 24'h48dbec : 24'h526478;
                else if(label_region && char_bits[15-char_col])
                    text_pixel=1;
            end
            // Constant half-alpha uses only three 9-bit adders and no DSP.
            menu_rgb[23:16]=({1'b0,I_data[23:16]}+{1'b0,paint_rgb[23:16]})>>1;
            menu_rgb[15:8]=({1'b0,I_data[15:8]}+{1'b0,paint_rgb[15:8]})>>1;
            menu_rgb[7:0]=({1'b0,I_data[7:0]}+{1'b0,paint_rgb[7:0]})>>1;
            if(text_pixel) menu_rgb=selected ? 24'hffffff : 24'hd5e0e8;
        end
    end

    reg s1_vs,s1_hs,s1_de;
    reg [23:0] s1_rgb;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            s1_vs<=0; s1_hs<=0; s1_de<=0; s1_rgb<=0;
            O_vsync<=0; O_hsync<=0; O_de<=0; O_data<=0;
        end else begin
            s1_vs<=I_vsync; s1_hs<=I_hsync; s1_de<=I_de;
            s1_rgb<=I_de ? menu_rgb : 24'd0;
            O_vsync<=s1_vs; O_hsync<=s1_hs; O_de<=s1_de;
            O_data<=s1_de ? s1_rgb : 24'd0;
        end
    end
endmodule
