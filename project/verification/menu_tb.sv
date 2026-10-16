`timescale 1ns/1ps
module menu_tb;
    reg press=0;
    reg [3:0] contacts=1;
    reg [15:0] tx=0,ty=0;
    wire valid;
    wire [1:0] selected;
    touch_mode_select select_dut(.I_press(press),.I_contacts(contacts),
        .I_x(tx),.I_y(ty),.O_valid(valid),.O_mode(selected));
    wire flipped_valid;
    wire [1:0] flipped_mode;
    touch_mode_select #(.SWAP_XY(1),.FLIP_X(1),.FLIP_Y(1)) flip_dut(
        .I_press(press),.I_contacts(contacts),.I_x(tx),.I_y(ty),
        .O_valid(flipped_valid),.O_mode(flipped_mode));
    task automatic check_touch(input integer xx,yy,n,input bit hit,input [1:0] mode);
        begin
            tx=xx;ty=yy;contacts=n;press=1;#1;
            if(valid!==hit || (hit && selected!==mode))
                $fatal(1,"Hitbox (%0d,%0d) contacts=%0d got %b/%0d",xx,yy,n,valid,selected);
            press=0;#1;
            if(valid!==0) $fatal(1,"Hit must be one-shot");
        end
    endtask
    reg clk=0; always #5 clk=~clk;
    reg rst=0, vs=0,hs=0,de=0;
    reg [1:0] mode=0;
    reg [23:0] rgb=24'h123456;
    wire ovs,ohs,ode;
    wire [23:0] out_rgb;
    dsi_menu_overlay display_dut(.I_clk(clk),.I_rst_n(rst),.I_mode(mode),
        .I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(rgb),
        .O_vsync(ovs),.O_hsync(ohs),.O_de(ode),.O_data(out_rgb));
    integer tests=0;
    reg [23:0] exp1=0,exp2=0;
    reg check1=0,check2=0;
    reg [11:0] ox1=0,oy1=0,ox2=0,oy2=0;
    integer xx,yy,m;
    reg [15:0] font[0:4095];
    initial $readmemh("../reference_font.hex",font);
    function [23:0] expected_pixel(input integer px,py);
        integer local_x,code,row,col;
        reg [15:0] bits;
        begin
            expected_pixel=24'h123456;
            if(py>=504) begin
                expected_pixel=24'h111923;
                if(py<508) expected_pixel=24'h32b5c9;
                else if(py>=522 && py<586) begin
                    if(px>=24 && px<312) begin
                        expected_pixel=(mode==0)?24'h176b80:24'h273748;
                        if(py<525 || py>=583 || px<27 || px>=309)
                            expected_pixel=(mode==0)?24'h48dbec:24'h526478;
                        else if(px>=120 && px<216 && py>=538 && py<570) begin
                            local_x=px-120;
                            case(local_x/32)
                            0:code="R"; 1:code="A"; default:code="W";
                            endcase
                            row=(py-538)/2; col=(local_x/2)%16;
                            bits=font[code*16+row];
                            if(bits[15-col]) expected_pixel=(mode==0)?24'hffffff:24'hd5e0e8;
                        end
                    end else if(px>=364 && px<660) begin
                        expected_pixel=(mode==1)?24'h176b80:24'h273748;
                        if(py<525 || py>=583 || px<367 || px>=657)
                            expected_pixel=(mode==1)?24'h48dbec:24'h526478;
                        else if(px>=448 && px<576 && py>=538 && py<570) begin
                            local_x=px-448;
                            case(local_x/32)
                            0:code="E"; 1:code="D"; 2:code="G"; default:code="E";
                            endcase
                            row=(py-538)/2; col=(local_x/2)%16;
                            bits=font[code*16+row];
                            if(bits[15-col]) expected_pixel=(mode==1)?24'hffffff:24'hd5e0e8;
                        end
                    end else if(px>=712 && px<1000) begin
                        expected_pixel=(mode==2)?24'h176b80:24'h273748;
                        if(py<525 || py>=583 || px<715 || px>=997)
                            expected_pixel=(mode==2)?24'h48dbec:24'h526478;
                        else if(px>=808 && px<904 && py>=538 && py<570) begin
                            local_x=px-808;
                            case(local_x/32)
                            0:code="O"; 1:code="S"; default:code="D";
                            endcase
                            row=(py-538)/2; col=(local_x/2)%16;
                            bits=font[code*16+row];
                            if(bits[15-col]) expected_pixel=(mode==2)?24'hffffff:24'hd5e0e8;
                        end
                    end
                end
            end
        end
    endfunction
    function is_sample(input integer px,py);
        begin
            is_sample=(px==0 || px==24 || px==27 || px==30 || px==130 || px==309 ||
                       px==311 || px==312 || px==364 || px==367 || px==400 ||
                       px==460 || px==660 || px==712 || px==715 || px==750 ||
                       px==820 || px==999 || px==1000) &&
                      (py==0 || py==503 || py==504 || py==507 || py==508 ||
                       py==521 || py==522 || py==524 || py==525 || py==540 ||
                       py==545 || py==580 ||
                       py==583 || py==585 || py==586 || py==599);
        end
    endfunction
    always @(posedge clk) begin
        if(!rst) begin check1=0;check2=0; end
        else begin
            check2=check1;exp2=exp1;ox2=ox1;oy2=oy1;
            check1=de && is_sample(xx,yy);
            exp1=expected_pixel(xx,yy);ox1=xx;oy1=yy;
            #1;
            if(check2) begin
                if(!ode || out_rgb!==exp2)
                    $fatal(1,"Toolbar pixel (%0d,%0d): got %h expected %h",ox2,oy2,out_rgb,exp2);
                tests=tests+1;
            end
        end
    end
    initial begin
        check_touch(24,522,1,1,0);check_touch(311,585,1,1,0);
        check_touch(312,522,1,0,0);check_touch(364,522,1,1,1);
        check_touch(659,585,1,1,1);check_touch(660,522,1,0,0);
        check_touch(712,522,1,1,2);check_touch(999,585,1,1,2);
        check_touch(1000,585,1,0,0);check_touch(500,521,1,0,0);
        check_touch(500,586,1,0,0);check_touch(500,550,2,0,0);
        check_touch(500,550,0,0,0);check_touch(1024,550,1,0,0);
        check_touch(500,600,1,0,0);
        tx=16'd56;ty=16'd273;press=1;contacts=1;#1;
        if(!flipped_valid || flipped_mode!==2) $fatal(1,"Orientation transform");
        press=0;
        #2;rst=1;
        for(m=0;m<3;m=m+1) begin
            mode=m;
            vs=1;repeat(3) @(negedge clk);vs=0;
            for(yy=0;yy<600;yy=yy+1) begin
                for(xx=0;xx<1024;xx=xx+1) begin
                    de=1;@(negedge clk);
                end
                de=0;repeat(3) @(negedge clk);
            end
        end
        repeat(3) @(negedge clk);
        if(tests<100) $fatal(1,"Insufficient toolbar samples: %0d",tests);
        $display("PASS touch hitboxes, orientation and toolbar RGB/DE across %0d boundary samples",tests);
        $finish;
    end
    initial begin #25000000;$fatal(1,"Menu watchdog");end
endmodule
