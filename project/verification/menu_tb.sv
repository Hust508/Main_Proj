`timescale 1ns/1ps
module menu_tb;
    reg clk=0; always #5 clk=~clk;
    reg rst=0,vs=0,hs=0,de=0,visible=0;
    reg [1:0] mode=0;
    reg [23:0] rgb=24'h123456;
    wire ovs,ohs,ode;
    wire [23:0] out_rgb;
    dsi_menu_overlay dut(.I_clk(clk),.I_rst_n(rst),.I_visible(visible),
        .I_mode(mode),.I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(rgb),
        .O_vsync(ovs),.O_hsync(ohs),.O_de(ode),.O_data(out_rgb));

    function [23:0] half_blend(input [23:0] a,b);
        begin
            half_blend[23:16]=({1'b0,a[23:16]}+{1'b0,b[23:16]})>>1;
            half_blend[15:8]=({1'b0,a[15:8]}+{1'b0,b[15:8]})>>1;
            half_blend[7:0]=({1'b0,a[7:0]}+{1'b0,b[7:0]})>>1;
        end
    endfunction
    function [23:0] expected(input integer px,py,input bit show,input [1:0] selected_mode);
        integer button;
        reg [23:0] paint;
        reg active;
        begin
            expected=24'h123456;
            if(show && py>=450) begin
                button=3;
                if(px>=24 && px<312) button=0;
                else if(px>=364 && px<660) button=1;
                else if(px>=712 && px<1000) button=2;
                paint=24'h101b28;
                if(py<454) paint=24'h38b7c9;
                else if(py>=465 && py<470 && px>=462 && px<562)
                    paint=24'h9bdce4;
                else if(button!=3 && py>=495 && py<580) begin
                    active=(button==selected_mode);
                    paint=active ? 24'h176b80 : 24'h273748;
                    if(py<498 || py>=577 ||
                       (button==0 && (px<27 || px>=309)) ||
                       (button==1 && (px<367 || px>=657)) ||
                       (button==2 && (px<715 || px>=997)))
                        paint=active ? 24'h48dbec : 24'h526478;
                end
                expected=half_blend(24'h123456,paint);
            end
        end
    endfunction
    function is_sample(input integer px,py);
        begin
            // Chosen points exclude glyphs so the blend/borders are isolated.
            is_sample=(px==0 || px==24 || px==27 || px==100 || px==309 ||
                       px==312 || px==364 || px==367 || px==400 ||
                       px==512 || px==657 || px==660 || px==712 ||
                       px==715 || px==750 || px==997 || px==999 || px==1000) &&
                      (py==0 || py==449 || py==450 || py==453 || py==454 ||
                       py==465 || py==469 || py==470 || py==494 || py==495 ||
                       py==497 || py==498 || py==510 || py==576 || py==577 ||
                       py==579 || py==580 || py==599);
        end
    endfunction
    reg check1=0,check2=0;
    reg [23:0] exp1=0,exp2=0;
    integer px1=0,py1=0,px2=0,py2=0;
    integer xx,yy,frame,tests=0;
    always @(posedge clk) begin
        if(!rst) begin check1=0;check2=0; end
        else begin
            check2=check1;exp2=exp1;px2=px1;py2=py1;
            check1=de && is_sample(xx,yy);
            exp1=expected(xx,yy,visible,mode);px1=xx;py1=yy;
            #1;
            if(check2) begin
                if(!ode || out_rgb!==exp2)
                    $fatal(1,"Pixel (%0d,%0d) got %h expected %h",px2,py2,out_rgb,exp2);
                tests=tests+1;
            end
        end
    end
    initial begin
        #22;rst=1;
        for(frame=0;frame<4;frame=frame+1) begin
            visible=(frame!=0);mode=(frame==0)?0:frame-1;
            repeat(5) @(negedge clk);
            vs=1;repeat(3) @(negedge clk);vs=0;
            for(yy=0;yy<600;yy=yy+1) begin
                for(xx=0;xx<1024;xx=xx+1) begin
                    de=1;@(negedge clk);
                end
                de=0;repeat(3) @(negedge clk);
            end
        end
        repeat(4) @(negedge clk);
        if(tests<500) $fatal(1,"Insufficient sample coverage: %0d",tests);
        $display("PASS hidden passthrough, half-alpha drawer, all modes and frame edges: %0d samples",tests);
        $finish;
    end
    initial begin #30000000;$fatal(1,"Menu watchdog");end
endmodule
