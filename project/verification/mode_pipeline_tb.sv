`timescale 1ns/1ps
module mode_pipeline_tb;
    reg clk=0,sys=0;always #7 clk=~clk;always #11 sys=~sys;
    reg rst=0;
    reg [1:0] request=0;
    wire [1:0] mode,frame_mode;
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
    reg old_user=0;
    function [7:0] q4(input [7:0] c);
        begin q4={4{c[7:6]}}; end
    endfunction
    function [95:0] cartoon(input [95:0] pixels,edges);
        integer i;
        reg [23:0] p;
        begin
            cartoon=0;
            for(i=0;i<4;i=i+1) begin
                p=pixels[i*24 +: 24];
                cartoon[i*24 +: 24]=edges[i*24+23] ? 24'h101820 :
                    {q4(p[23:16]),q4(p[15:8]),q4(p[7:0])};
            end
        end
    endfunction
    always @(posedge clk) if(rst) begin
        if(user&&!old_user)expected_mode=mode;
        old_user=user;
        #1;
        if(ov!==valid || ou!==user || ol!==last) $fatal(1,"Frame/sync latency mismatch");
        if(frame_mode!==expected_mode) $fatal(1,"Mode changed mid-frame");
        if(valid) begin
            if(data !== ((expected_mode==1)?ref_edge:
                          (expected_mode==3)?cartoon(rgb,ref_edge):rgb))
                $fatal(1,"Color/edge/cartoon mux mismatch mode=%0d",expected_mode);
            checked=checked+4;
        end
    end
    integer f,y,x;
    initial begin
        #50;rst=1;
        for(f=0;f<8;f=f+1)begin
            request=f%4;repeat(15)@(negedge clk);
            if(f%2)begin user=1;valid=0;@(negedge clk);user=0;end
            for(y=0;y<8;y=y+1)begin
                for(x=0;x<8;x=x+1)begin
                    valid=1;user=!(f%2)&&(y==0)&&(x==0);last=(x==7);rgb={$random,$random,$random};
                    if(y==2&&x==2)request=(f+1)%4;
                    @(negedge clk);
                end
                valid=0;last=0;repeat(3)@(negedge clk);
            end
        end
        $display("PASS frame-boundary four-mode selection, mailbox and pixels: %0d pixels",checked);
        $finish;
    end
endmodule
