`timescale 1ns/1ps
module gray_unit_tb;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,valid=0,user=0,last=0,ready=1;
    reg [95:0] rgb=0;
    wire [95:0] gray;
    wire ov,ou,ol,orr;
    rgb_to_gray_96 dut(.I_clk(clk),.I_rst_n(rst),.I_data(rgb),
      .I_valid(valid),.I_user(user),.I_last(last),.I_ready(ready),
      .O_data(gray),.O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(orr));
    integer checked=0,p,r,g,b,y,nearest;
    real exact;
    always @(posedge clk) begin
        #1;
        if(!rst)begin
            if({gray,ov,ou,ol}!==99'd0)$fatal(1,"Gray reset outputs");
        end else begin
            if({ov,ou,ol,orr}!=={valid,user,last,ready})$fatal(1,"Gray sideband latency");
            for(p=0;p<4;p=p+1)begin
                r=rgb[p*24+16 +:8];g=rgb[p*24+8 +:8];b=rgb[p*24 +:8];
                y=(77*r+150*g+29*b+128)/256;
                if(valid)begin
                    if(gray[p*24 +:24]!=={3{y[7:0]}})$fatal(1,"Luma mismatch %h",rgb);
                    if(r==g && g==b && y!=r)$fatal(1,"Neutral gray not preserved");
                    exact=0.299*r+0.587*g+0.114*b;
                    nearest=$rtoi(exact+0.5);
                    if(y-nearest>1 || nearest-y>1)$fatal(1,"Luma approximation error > 1");
                    checked=checked+1;
                end else if(gray[p*24 +:24]!==24'd0)$fatal(1,"Invalid pixels not blanked");
            end
        end
    end
    integer n;
    initial begin
        repeat(3)@(negedge clk);rst=1;
        valid=1;rgb={24'hff0000,24'h00ff00,24'h0000ff,24'hffffff};
        @(negedge clk);
        if(gray!=={24'h4d4d4d,24'h959595,24'h1d1d1d,24'hffffff})$fatal(1,"Primary-color reference vectors");
        for(n=0;n<256;n=n+1)begin
            valid=1;rgb={12{n[7:0]}};user=(n==0);last=(n==255);
            @(negedge clk);
        end
        for(n=0;n<20000;n=n+1)begin
            rgb={$random,$random,$random};valid=(n%11!=0);
            user=(n%313==0);last=(n%79==0);ready=n%2;
            @(negedge clk);
        end
        valid=0;user=0;last=0;rst=0;
        repeat(3)@(negedge clk);
        if(checked<70000)$fatal(1,"Insufficient gray coverage");
        $display("PASS grayscale primaries, 256 neutral levels, random independent four-pixel lanes, <=1 luma error, one-cycle sidebands, reset; %0d pixels",checked);
        $finish;
    end
endmodule

module style_720p_test #(parameter MODE=3);
    localparam W=1280,H=720,NBYTES=W*H*3;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,valid=0,user=0,last=0;
    reg [95:0] rgb=0;
    wire [95:0] gray;
    wire ov,ou,ol,orr,pv,pu;
    wire [2:0] frame_mode;
    wire [127:0] packed_data;
    isp_frame_select_96 dut(.I_clk(clk),.I_rst_n(rst),.I_mode(MODE[2:0]),.I_data(rgb),
      .I_valid(valid),.I_user(user),.I_last(last),.I_ready(1'b1),
      .O_data(gray),.O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(orr),.O_frame_mode(frame_mode));
    data_96bit_to_128bit packer(.I_clk(clk),.I_rst_n(rst),
      .I_96b_frame_start(ou),.I_96b_valid(ov),.I_96b_data(gray),
      .O_128b_frame_start(pu),.O_128b_valid(pv),.O_128b_data(packed_data));
    reg [7:0] expected[0:NBYTES-1];
    integer put=0,take=0,words=0,p,j,r,g,b,y,sof_count=0;
    always @(posedge clk) if(rst)begin
        if(valid)begin
            for(p=3;p>=0;p=p-1)begin
                r=rgb[p*24+16 +:8];g=rgb[p*24+8 +:8];b=rgb[p*24 +:8];
                y=(77*r+150*g+29*b+128)/256;
                for(j=0;j<3;j=j+1)begin
                    expected[put]=(MODE==4)?(255-rgb[p*24+16-j*8 +:8]):y;
                    put=put+1;
                end
            end
        end
        #1;
        if({ov,ou,ol,orr}!=={valid,user,last,1'b1})$fatal(1,"720p frame/line controls");
        if(valid && frame_mode!==MODE[2:0])$fatal(1,"Gray frame tag lost");
        if(pu)sof_count=sof_count+1;
        if(pv)begin
            for(j=0;j<16;j=j+1)begin
                if(take>=put || packed_data[127-j*8 -:8]!==expected[take])
                    $fatal(1,"Gray DDR packer byte %0d, got %h expected %h",take,packed_data[127-j*8 -:8],expected[take]);
                take=take+1;
            end
            words=words+1;
        end
    end
    integer row,col;
    initial begin
        repeat(5)@(negedge clk);rst=1;
        // Frame marker during blanking, as in the supplied ISP.
        user=1;@(negedge clk);user=0;
        repeat(3)@(negedge clk);
        for(row=0;row<H;row=row+1)begin
            for(col=0;col<W/4;col=col+1)begin
                valid=1;last=(col==W/4-1);rgb={$random,$random,$random};
                @(negedge clk);
            end
            valid=0;last=0;repeat(8)@(negedge clk);
        end
        repeat(5)@(negedge clk);
        if(put!=NBYTES || take!=NBYTES || words!=172800 || sof_count!=1)
            $fatal(1,"Gray full-frame coverage put=%0d take=%0d words=%0d sof=%0d",put,take,words,sof_count);
        $display("PASS style mode=%0d 1280x720 frame, %0d pixels, %0d DDR words, all %0d bytes in order, exact frame and line timing",MODE,W*H,words,take);
        $finish;
    end
    initial begin #5000000;$fatal(1,"Gray 720p watchdog");end
endmodule

module gray_720p_tb;
    style_720p_test #(.MODE(3)) test();
endmodule
module negative_720p_tb;
    style_720p_test #(.MODE(4)) test();
endmodule
