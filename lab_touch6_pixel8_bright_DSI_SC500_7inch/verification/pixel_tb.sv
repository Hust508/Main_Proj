`timescale 1ns/1ps
module tone_unit_tb;
    reg [95:0] rgb=0;
    wire [95:0] lifted,bypass;
    rgb_brighten_96 dut(.I_data(rgb),.O_data(lifted));
    rgb_brighten_96 #(.ENABLE(0)) off(.I_data(rgb),.O_data(bypass));
    function integer ref_lift(input integer value);
        integer a,b,c;
        begin
            a=value*3/2;b=value+32;c=(value+255)/2;
            ref_lift=(a<b)?a:b;if(c<ref_lift)ref_lift=c;
        end
    endfunction
    integer n,i,last_value=-1,value,checked=0;
    task check;
        begin
            #1;
            if(bypass!==rgb)$fatal(1,"Tone bypass modified RGB");
            for(i=0;i<12;i=i+1)begin
                value=rgb[i*8+:8];
                if(lifted[i*8+:8]!==ref_lift(value))$fatal(1,"Tone channel %0d input %0d",i,value);
                if(lifted[i*8+:8]<value || lifted[i*8+:8]>value+32)$fatal(1,"Tone lift bound");
                checked=checked+1;
            end
        end
    endtask
    initial begin
        for(n=0;n<256;n=n+1)begin
            rgb={12{n[7:0]}};check();
            if(n>0 && lifted[7:0]<last_value)$fatal(1,"Tone is nonmonotonic");
            last_value=lifted[7:0];
            if((n==0||n==255)&&lifted!==rgb)$fatal(1,"Black/white changed");
        end
        for(n=0;n<20000;n=n+1)begin rgb={$random,$random,$random};check();end
        $display("PASS tone lift independent arithmetic oracle, all 256 levels, monotonicity, neutral gray, black/white endpoints, <=32 lift, four independent RGB lanes and bypass; %0d channels",checked);
        $finish;
    end
endmodule

module pixel_unit_tb;
    localparam W=32,H=24;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,valid=0,user=0,last=0,ready=1;
    reg [95:0] rgb=0;
    wire [95:0] data;
    wire ov,ou,ol,orr;
    pixel_art_96 #(.IMG_WIDTH(W),.IMG_HEIGHT(H)) dut(
        .I_clk(clk),.I_rst_n(rst),.I_data(rgb),.I_valid(valid),.I_user(user),.I_last(last),.I_ready(ready),
        .O_data(data),.O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(orr));
    function [23:0] palette(input [23:0] color);
        integer r,g,b;
        begin
            r=(color[23:16]/32*255+3)/7;g=(color[15:8]/32*255+3)/7;b=(color[7:0]/64)*85;
            palette={r[7:0],g[7:0],b[7:0]};
        end
    endfunction
    reg [23:0] row_reference[0:W/8-1];
    reg [95:0] expected;
    integer x=0,y=0,checked=0,frames=0;
    reg prev_user=0;
    always @(posedge clk)begin
        if(!rst)begin x=0;y=0;prev_user=0;end
        else begin
            if(user&&!prev_user)begin x=0;y=0;frames=frames+1;end
            prev_user=user;
            if(valid)begin
                if(x%8==0 && y%8==0)row_reference[x/8]=palette(rgb[95:72]);
                expected={4{row_reference[x/8]}};
                x=x+4;if(x==W)begin x=0;y=(y+1)%H;end
            end
        end
        #1;
        if(!rst)begin
            if({data,ov,ou,ol}!==99'd0)$fatal(1,"Pixel reset");
        end else begin
            if({ov,ou,ol,orr}!=={valid,user,last,ready})$fatal(1,"Pixel one-cycle sidebands");
            if(valid)begin
                if(data!==expected)$fatal(1,"Pixel block x=%0d y=%0d actual=%h expected=%h",x,y,data,expected);
                checked=checked+4;
            end else if(data!==0)$fatal(1,"Pixel blanking data");
        end
    end
    integer f,yy,xx,lane;
    initial begin
        repeat(3)@(negedge clk);rst=1;
        for(f=0;f<6;f=f+1)begin
            if(f==4)begin rst=0;valid=0;repeat(3)@(negedge clk);rst=1;end
            if(f%2==0)begin user=1;valid=0;repeat(2)@(negedge clk);user=0;end
            for(yy=0;yy<((f==2)?5:H);yy=yy+1)begin
                for(xx=0;xx<W;xx=xx+4)begin
                    rgb={$random,$random,$random};valid=1;last=(xx==W-4);
                    user=(f%2!=0 && yy==0 && xx==0);ready=(xx%12!=0);
                    // Distinct lanes ensure sampling uses the first spatial
                    // pixel [95:72], not the low-order RGB lane.
                    if(yy==0&&xx==0)rgb={24'hff0000,24'h00ff00,24'h0000ff,24'hffffff};
                    @(negedge clk);
                    user=0;
                    if(xx%12==0)begin valid=0;last=0;repeat(2)@(negedge clk);end
                end
                valid=0;last=0;repeat(3)@(negedge clk);
            end
            valid=0;user=0;repeat(3)@(negedge clk);
        end
        if(checked!=4000||frames!=6)$fatal(1,"Pixel coverage checked=%0d frames=%0d",checked,frames);
        $display("PASS 8x8 RGB332 spatial oracle, first-lane sample, all block rows/columns, valid gaps, extended blanking SOF, coincident SOF, truncated-frame restart, reset and one-cycle controls; %0d pixels",checked);
        $finish;
    end
endmodule

module new_style_720p_test #(parameter MODE=5);
    localparam W=1280,H=720,N=W*H*3;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,valid=0,user=0,last=0;
    reg [95:0] rgb=0;
    wire [95:0] styled;
    wire ov,ou,ol,orr,pv,pu;
    wire [2:0] frame_mode;
    wire [127:0] packed_data;
    isp_frame_select_96 dut(.I_clk(clk),.I_rst_n(rst),.I_mode(MODE[2:0]),.I_data(rgb),
        .I_valid(valid),.I_user(user),.I_last(last),.I_ready(1'b1),
        .O_data(styled),.O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(orr),.O_frame_mode(frame_mode));
    data_96bit_to_128bit packer(.I_clk(clk),.I_rst_n(rst),.I_96b_frame_start(ou),.I_96b_valid(ov),.I_96b_data(styled),
        .O_128b_frame_start(pu),.O_128b_valid(pv),.O_128b_data(packed_data));
    function integer lift(input integer value);
        integer a,b,c;
        begin a=value*3/2;b=value+32;c=(value+255)/2;lift=(a<b)?a:b;if(c<lift)lift=c;end
    endfunction
    function [23:0] palette(input [23:0] color);
        integer r,g,b;
        begin
            r=(color[23:16]/32*255+3)/7;g=(color[15:8]/32*255+3)/7;b=(color[7:0]/64)*85;
            palette={r[7:0],g[7:0],b[7:0]};
        end
    endfunction
    reg [7:0] expected[0:N-1];
    reg [23:0] row_colors[0:159],sample;
    reg [95:0] lifted,oracle;
    integer put=0,take=0,words=0,sof_count=0,p,j,x=0,y=0;
    always @(posedge clk)if(rst)begin
        if(valid)begin
            for(j=0;j<12;j=j+1)lifted[j*8+:8]=lift(rgb[j*8+:8]);
            if(y%8==0&&x%8==0)row_colors[x/8]=palette(lifted[95:72]);
            oracle=(MODE==5)?{4{row_colors[x/8]}}:lifted;
            for(p=3;p>=0;p=p-1)for(j=0;j<3;j=j+1)begin
                expected[put]=oracle[p*24+16-j*8+:8];put=put+1;
            end
            x=x+4;if(x==W)begin x=0;y=y+1;end
        end
        #1;
        if({ov,ou,ol,orr}!=={valid,user,last,1'b1})$fatal(1,"New style 720p controls");
        if(valid&&(frame_mode!==MODE[2:0]||styled!==oracle))$fatal(1,"New style pixel/frame oracle");
        if(pu)sof_count=sof_count+1;
        if(pv)begin
            for(j=0;j<16;j=j+1)begin
                if(take>=put||packed_data[127-j*8-:8]!==expected[take])$fatal(1,"New style packed byte %0d",take);
                take=take+1;
            end
            words=words+1;
        end
    end
    integer yy,xx;
    initial begin
        repeat(4)@(negedge clk);rst=1;user=1;@(negedge clk);user=0;
        repeat(3)@(negedge clk);
        for(yy=0;yy<H;yy=yy+1)begin
            for(xx=0;xx<W/4;xx=xx+1)begin
                valid=1;last=(xx==W/4-1);rgb={$random,$random,$random};@(negedge clk);
            end
            valid=0;last=0;repeat(8)@(negedge clk);
        end
        repeat(6)@(negedge clk);
        if(put!=N||take!=N||words!=172800||sof_count!=1||y!=H)$fatal(1,"New style full-frame coverage");
        $display("PASS new style mode=%0d 1280x720 independent pixel oracle, 921600 pixels, 2764800 ordered bytes, 172800 DDR words, no dropped beats, exact frame/line timing",MODE);$finish;
    end
    initial begin #5000000;$fatal(1,"New style 720p watchdog");end
endmodule
module bright_720p_tb;new_style_720p_test #(.MODE(0)) test();endmodule
module pixel_720p_tb;new_style_720p_test #(.MODE(5)) test();endmodule
