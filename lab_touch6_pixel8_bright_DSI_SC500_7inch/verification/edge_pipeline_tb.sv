`timescale 1ns/1ps
// Independent image-array oracle for the two-sample Sobel kernel, plus a
// byte-stream scoreboard for the real 96-to-128-bit DDR packer.
module edge_pipeline_test #(
    parameter W=32, H=8, FRAMES=8
);
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, ilast=0, iuser=0, ivalid=0;
    reg [95:0] idata=0;
    wire olast, ouser, ovalid, oready;
    wire [95:0] odata;
    wire [95:0] high_data;
    wire high_valid;
    wire puser, pvalid;
    wire [127:0] pdata;
    integer samples[0:H-1][0:W/2-1];
    integer pixels_checked=0, beats_checked=0, words_checked=0;
    integer white_checked=0;

    edge_detect_96 #(.IMG_WIDTH(W), .IMG_HEIGHT(H), .EDGE_TH(14'd80)) dut (
        .I_clk(clk), .I_rst_n(rst_n), .I_tlast(ilast), .I_tuser(iuser),
        .I_tdata(idata), .I_tvalid(ivalid), .I_tready(1'b1),
        .O_tlast(olast), .O_tuser(ouser), .O_tdata(odata),
        .O_tvalid(ovalid), .O_tready(oready)
    );
    edge_detect_96 #(.IMG_WIDTH(W), .IMG_HEIGHT(H), .EDGE_TH(14'd500)) high_dut (
        .I_clk(clk), .I_rst_n(rst_n), .I_tlast(ilast), .I_tuser(iuser),
        .I_tdata(idata), .I_tvalid(ivalid), .I_tready(1'b1),
        .O_tlast(), .O_tuser(), .O_tdata(high_data),
        .O_tvalid(high_valid), .O_tready()
    );
    data_96bit_to_128bit packer (
        .I_clk(clk), .I_rst_n(rst_n), .I_96b_frame_start(ouser),
        .I_96b_valid(ovalid), .I_96b_data(odata),
        .O_128b_frame_start(puser), .O_128b_valid(pvalid), .O_128b_data(pdata)
    );

    function integer luminance(input [23:0] p);
        luminance=(p[23:16]/4)+(p[15:8]/2)+(p[7:0]/4);
    endfunction
    function [23:0] pixel(input integer f, y, x);
        integer r,g,b;
        begin
            case(f % 8)
                0: begin r=0; g=0; b=0; end
                1: begin r=255; g=255; b=255; end
                2: begin r=(x<W/2)?0:255; g=r; b=r; end
                3: begin r=(y<H/2)?0:255; g=r; b=r; end
                4: begin r=((x/4+y/2)%2)*255; g=r; b=r; end
                5: begin r=(x*13+y*47)%256; g=(x*71+y*29)%256; b=(x*43+y*11)%256; end
                6: begin r=(x*255)/(W-1); g=r; b=r; end
                default: begin r=255*((x+y*3)%(W/2)<W/4); g=255*((x*3+y*7)%19<9); b=255-r; end
            endcase
            pixel={r[7:0],g[7:0],b[7:0]};
        end
    endfunction
    function integer magnitude(input integer y,c);
        integer gx,gy;
        begin
            gx=(samples[y-2][c]-samples[y-2][c-2])
              +2*(samples[y-1][c]-samples[y-1][c-2])
              +(samples[y][c]-samples[y][c-2]);
            gy=(samples[y-2][c-2]+2*samples[y-2][c-1]+samples[y-2][c])
              -(samples[y][c-2]+2*samples[y][c-1]+samples[y][c]);
            magnitude=((gx<0)?-gx:gx)+((gy<0)?-gy:gy);
        end
    endfunction

    reg [7:0] bytes_q[0:31];
    integer queued=0, k;
    reg [127:0] expected_word;
    reg expected_pvalid, expected_puser;
    // Sample pre-edge inputs to the packer; compare its registered result.
    always @(posedge clk) begin
        if (!rst_n) begin
            queued=0;
        end else begin
            expected_puser=ouser;
            expected_pvalid=0;
            if (ovalid) begin
                for(k=0;k<12;k=k+1) bytes_q[queued+k]=odata[95-k*8 -:8];
                queued=queued+12;
                if(queued>=16) begin
                    expected_pvalid=1;
                    for(k=0;k<16;k=k+1) expected_word[127-k*8 -:8]=bytes_q[k];
                    queued=queued-16;
                    for(k=0;k<queued;k=k+1) bytes_q[k]=bytes_q[k+16];
                end
            end else if(queued!=0) $fatal(1,"Line ended with partial DDR word");
            #2;
            if(pvalid !== expected_pvalid) $fatal(1,"Packer VALID mismatch");
            if(puser !== expected_puser) $fatal(1,"Packer SOF mismatch");
            if(expected_pvalid) begin
                if(pdata !== expected_word) $fatal(1,"Packer byte ordering mismatch");
                words_checked=words_checked+1;
            end
        end
    end

    task blank(input integer count, input integer marker);
        integer i;
        begin
            for(i=0;i<count;i=i+1) begin
                @(negedge clk); ivalid=0; iuser=(i==0 && marker); ilast=0; idata=0;
                @(posedge clk); #1;
                if(ovalid !== 0 || ouser !== iuser || odata !== 0)
                    $fatal(1,"Blanking/marker mismatch");
            end
        end
    endtask
    task beat(input integer f,y,g,marker);
        integer c,m0,m1;
        reg [23:0] p0,p1,p2,p3,a,b,ah,bh;
        reg [95:0] expected,expected_high;
        begin
            p0=pixel(f,y,g*4); p1=pixel(f,y,g*4+1);
            p2=pixel(f,y,g*4+2); p3=pixel(f,y,g*4+3);
            c=g*2;
            samples[y][c]=(luminance(p0)+luminance(p1))/2;
            samples[y][c+1]=(luminance(p2)+luminance(p3))/2;
            m0=0; m1=0;
            if(y>=2 && g!=0) begin m0=magnitude(y,c); m1=magnitude(y,c+1); end
            a=(m0>=80)?24'hffffff:0; b=(m1>=80)?24'hffffff:0;
            ah=(m0>=500)?24'hffffff:0; bh=(m1>=500)?24'hffffff:0;
            expected={a,a,b,b}; expected_high={ah,ah,bh,bh};
            @(negedge clk); ivalid=1; iuser=marker; ilast=(g==W/4-1); idata={p0,p1,p2,p3};
            @(posedge clk); #1;
            if(ovalid !== 1 || high_valid !== 1 || ouser !== iuser || olast !== ilast)
                $fatal(1,"Edge control mismatch f=%0d y=%0d g=%0d",f,y,g);
            if(odata !== expected || high_data !== expected_high)
                $fatal(1,"Sobel mismatch f=%0d y=%0d g=%0d got=%h expected=%h high=%h expected_high=%h",f,y,g,odata,expected,high_data,expected_high);
            if(oready !== 1) $fatal(1,"Ready connection mismatch");
            if(|odata) white_checked=white_checked+1;
            beats_checked=beats_checked+1; pixels_checked=pixels_checked+4;
        end
    endtask

    integer f,y,g;
    initial begin
        repeat(5) @(negedge clk);
        rst_n=1;
        blank(3,0);
        for(f=0;f<FRAMES;f=f+1) begin
            // Alternate a separate blanking SOF and an SOF on the first beat.
            blank(4, (f%2)==0);
            for(y=0;y<H;y=y+1) begin
                for(g=0;g<W/4;g=g+1) beat(f,y,g,(f%2)==1 && y==0 && g==0);
                blank(3+y%3,0);
            end
        end
        // Truncate after four groups of row one. A new marker must recover
        // x/y and line addressing, for either valid or blanking markers.
        for(f=0;f<2;f=f+1) begin
            blank(3,1);
            for(g=0;g<W/4;g=g+1) beat(5,0,g,0);
            blank(3,0);
            for(g=0;g<4;g=g+1) beat(5,1,g,0);
            blank(3,f==0);
            for(y=0;y<H;y=y+1) begin
                for(g=0;g<W/4;g=g+1) beat(7,y,g,f==1 && y==0 && g==0);
                blank(3,0);
            end
        end
        blank(6,0);
        if(white_checked==0) $fatal(1,"No edges exercised");
        $display("PASS EDGE_PIPELINE W=%0d H=%0d frames=%0d pixels=%0d beats=%0d DDR_words=%0d edge_beats=%0d thresholds=80,500",W,H,FRAMES,pixels_checked,beats_checked,words_checked,white_checked);
        $finish;
    end
    initial begin #200000000; $fatal(1,"Simulation timeout"); end
endmodule

module edge_small_tb;
    edge_pipeline_test #(.W(32),.H(8),.FRAMES(8)) test();
endmodule
module edge_720p_tb;
    edge_pipeline_test #(.W(1280),.H(720),.FRAMES(6)) test();
endmodule
