`timescale 1ns/1ps
module mode_pipeline_tb;
    reg clk=0,sys=0;always #7 clk=~clk;always #11 sys=~sys;
    reg rst=0;
    reg [2:0] request=0;
    wire [2:0] mode,frame_mode;
    mode_mailbox mailbox(.I_src_clk(sys),.I_dst_clk(clk),.I_rst_n(rst),.I_mode(request),.O_mode(mode));
    reg [95:0] rgb=0;
    reg valid=0,user=0,last=0;
    wire [95:0] data,ref_edge;
    wire ov,ou,ol,ready;
    isp_frame_select_96 #(.IMG_WIDTH(32),.IMG_HEIGHT(8)) dut (
      .I_clk(clk),.I_rst_n(rst),.I_mode(mode),.I_data(rgb),
      .I_valid(valid),.I_user(user),.I_last(last),.I_ready(1'b1),
      .O_data(data),.O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(ready),.O_frame_mode(frame_mode));
    edge_detect_96 #(.IMG_WIDTH(32),.IMG_HEIGHT(8)) reference (
      .I_clk(clk),.I_rst_n(rst),.I_tdata(rgb),.I_tvalid(valid),.I_tuser(user),
      .I_tlast(last),.I_tready(1'b1),.O_tdata(ref_edge),.O_tvalid(),.O_tuser(),.O_tlast(),.O_tready());
    integer expected_mode=0,checked=0;
    function [95:0] gray_reference(input [95:0] value);
        integer p,r,g,b,y;
        begin
            for(p=0;p<4;p=p+1)begin
                r=value[p*24+16 +:8];g=value[p*24+8 +:8];b=value[p*24 +:8];
                y=(77*r+150*g+29*b+128)/256;
                gray_reference[p*24 +:24]={3{y[7:0]}};
            end
        end
    endfunction
    function [95:0] negative_reference(input [95:0] value);
        integer b;
        begin
            for(b=0;b<12;b=b+1)negative_reference[b*8 +:8]=255-value[b*8 +:8];
        end
    endfunction
    function integer lift_reference(input integer value);
        integer a,b,c;
        begin
            a=value*3/2;b=value+32;c=(value+255)/2;
            lift_reference=(a<b)?a:b;
            if(c<lift_reference)lift_reference=c;
        end
    endfunction
    function [95:0] bright_reference(input [95:0] value);
        integer i;
        begin for(i=0;i<12;i=i+1)bright_reference[i*8+:8]=lift_reference(value[i*8+:8]);end
    endfunction
    function [23:0] palette_reference(input [23:0] color);
        integer r,g,b;
        begin
            r=(color[23:16]/32*255+3)/7;
            g=(color[15:8]/32*255+3)/7;
            b=(color[7:0]/64)*85;
            palette_reference={r[7:0],g[7:0],b[7:0]};
        end
    endfunction
    reg [23:0] reference_row[0:3];
    reg [95:0] lifted,pixel_expected,expected;
    integer px=0,py=0;
    reg old_user=0;
    always @(posedge clk) if(rst) begin
        if(user&&!old_user)begin expected_mode=(mode<=5)?mode:0;px=0;py=0;end
        if(valid)begin
            lifted=bright_reference(rgb);
            if(py%8==0 && px%8==0)reference_row[px/8]=palette_reference(lifted[95:72]);
            pixel_expected={4{reference_row[px/8]}};
            px=px+4;if(px==32)begin px=0;py=(py+1)%8;end
        end
        old_user=user;
        #1;
        if(ov!==valid || ou!==user || ol!==last) $fatal(1,"Frame/sync latency mismatch");
        if(frame_mode!==expected_mode) $fatal(1,"Mode changed mid-frame");
        if(valid) begin
            if(data !== ((expected_mode==1)?ref_edge:
                         (expected_mode==3)?gray_reference(rgb):
                         (expected_mode==4)?negative_reference(rgb):
                         (expected_mode==5)?pixel_expected:bright_reference(rgb)))
                $fatal(1,"Color/edge/grayscale/negative mux mismatch, mode %0d",expected_mode);
            checked=checked+4;
        end
    end
    integer f,y,x;
    initial begin
        #50;rst=1;
        for(f=0;f<14;f=f+1)begin
            request=(f<12)?f%6:f-6;repeat(15)@(negedge clk);
            if((f/6)%2)begin user=1;valid=0;@(negedge clk);user=0;end
            for(y=0;y<8;y=y+1)begin
                for(x=0;x<8;x=x+1)begin
                    valid=1;user=!((f/6)%2)&&(y==0)&&(x==0);last=(x==7);rgb={$random,$random,$random};
                    if(y==2&&x==2)request=(f+1)%6;
                    @(negedge clk);
                end
                valid=0;last=0;repeat(3)@(negedge clk);
            end
        end
        $display("PASS six frame-boundary modes and 3-bit asynchronous mailbox, lifted color/edge/grayscale/negative/pixel-art independent oracle, invalid-mode fallback, no mid-frame mode change, %0d pixels",checked);
        $finish;
    end
endmodule
