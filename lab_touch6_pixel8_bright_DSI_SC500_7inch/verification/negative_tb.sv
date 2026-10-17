`timescale 1ns/1ps
module negative_unit_tb;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,valid=0,user=0,last=0,ready=1;
    reg [95:0] rgb=0;
    wire [95:0] negative;
    wire ov,ou,ol,orr;
    wire [2:0] frame_mode;
    isp_frame_select_96 #(.IMG_WIDTH(32),.IMG_HEIGHT(8)) dut (
      .I_clk(clk),.I_rst_n(rst),.I_mode(3'd4),.I_data(rgb),
      .I_valid(valid),.I_user(user),.I_last(last),.I_ready(ready),
      .O_data(negative),.O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(orr),
      .O_frame_mode(frame_mode));
    integer checked=0,b,expected;
    always @(posedge clk)begin
        #1;
        if(!rst)begin
            if({ov,ou,ol,frame_mode}!==6'd0)$fatal(1,"Negative reset controls");
        end else begin
            if({ov,ou,ol,orr}!=={valid,user,last,ready})$fatal(1,"Negative control latency");
            if(valid)begin
                if(frame_mode!==3'd4)$fatal(1,"Negative mode bit lost");
                for(b=0;b<12;b=b+1)begin
                    expected=255-rgb[b*8 +:8];
                    if(negative[b*8 +:8]!==expected[7:0])
                        $fatal(1,"Negative channel mismatch byte %0d input=%h output=%h",b,rgb,negative);
                end
                checked=checked+4;
            end
        end
    end
    integer n,p;
    initial begin
        repeat(3)@(negedge clk);rst=1;
        valid=1;user=1;rgb={24'hff0000,24'h00ff00,24'h0000ff,24'h000000};
        @(negedge clk);user=0;
        if(negative!=={24'h00ffff,24'hff00ff,24'hffff00,24'hffffff})$fatal(1,"Primary color to complementary color vectors");
        rgb={24'hffffff,24'h00ffff,24'hff00ff,24'hffff00};
        @(negedge clk);
        if(negative!=={24'h000000,24'hff0000,24'h00ff00,24'h0000ff})$fatal(1,"White and secondary color vectors");
        for(n=0;n<256;n=n+1)begin
            for(p=0;p<4;p=p+1)begin
                rgb[p*24+16 +:8]=n+p*37;
                rgb[p*24+8 +:8]=3*n+p*41;
                rgb[p*24 +:8]=5*n+p*43;
            end
            last=(n%8==7);@(negedge clk);
        end
        for(n=0;n<20000;n=n+1)begin
            rgb={$random,$random,$random};valid=(n%11!=0);last=(n%79==0);ready=n%2;
            @(negedge clk);
        end
        rst=0;valid=0;last=0;repeat(3)@(negedge clk);
        if(checked<70000)$fatal(1,"Insufficient negative coverage");
        $display("PASS RGB negative primaries and complements, all 256 levels per channel/lane, random pixels, one-cycle sidebands and reset; %0d pixels",checked);
        $finish;
    end
endmodule
