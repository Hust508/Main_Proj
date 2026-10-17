`timescale 1ns/1ps
module sepia_portrait_tb;
    parameter W=48,H=24,GRAIN=1,VIGNETTE=1;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,v=0,u=0,l=0,ready=1;
    reg [1:0] mode=0;
    reg [95:0] rgb=0;
    wire ov,ou,ol,ordy,pv,pu;
    wire [95:0] data;
    wire [127:0] packed_data;
    wire [1:0] om;
    retro_frame_select #(.IMG_WIDTH(W),.IMG_HEIGHT(H),.RETRO_GRAIN(GRAIN),.RETRO_VIGNETTE(VIGNETTE)) dut(
        .I_clk(clk),.I_rst_n(rst),.I_mode(mode),.I_data(rgb),.I_valid(v),.I_user(u),.I_last(l),.I_ready(ready),
        .O_data(data),.O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(ordy),.O_frame_mode(om));
    cartoon_packer packer(.I_clk(clk),.I_rst_n(rst),.I_96b_frame_start(ou),.I_96b_valid(ov),.I_96b_data(data),
        .O_128b_frame_start(pu),.O_128b_valid(pv),.O_128b_data(packed_data));
    integer capture_fd;reg [4095:0] capture_name;
    integer fd,rc,n=0,pixels=0,frames=0,words=0,j,count=0;
    reg ev,eu,el,prev_v=0,prev_u=0,expected_pv;
    reg [1:0] em;
    reg [95:0] ed,prev_data=0;
    reg [127:0] expected_word;
    reg [7:0] byte_queue[0:31];
    reg [4095:0] filename;
    initial begin
        if(!$value$plusargs("VECTORS=%s",filename))$fatal(1,"Missing vector file");
        if(!$value$plusargs("CAPTURE=%s",capture_name))$fatal(1,"Missing capture");
        capture_fd=$fopen(capture_name,"w");
        fd=$fopen(filename,"r");if(!fd)$fatal(1,"Cannot open vectors");
        repeat(3)@(negedge clk);
        while(!$feof(fd))begin
            rc=$fscanf(fd,"%h %h %h %h %h %h %h %h %h %h %h %h\n",rst,v,u,l,mode,ready,rgb,ev,eu,el,em,ed);
            if(rc!=12)$fatal(1,"Bad record %0d",n);
            @(posedge clk);
            expected_pv=0;expected_word=0;
            if(!rst)begin count=0;prev_u=0;prev_v=0;end
            else begin
                if(prev_u)count=0;
                if(prev_v)begin
                    for(j=0;j<12;j=j+1)byte_queue[count+j]=prev_data[(11-j)*8 +:8];
                    count=count+12;
                    if(count>=16)begin
                        expected_pv=1;
                        for(j=0;j<16;j=j+1)expected_word[(15-j)*8 +:8]=byte_queue[j];
                        for(j=16;j<count;j=j+1)byte_queue[j-16]=byte_queue[j];
                        count=count-16;
                    end
                end
            end
            #1;
            if({ov,ou,ol,om,ordy}!=={ev,eu,el,em,ready})
                $fatal(1,"Control cycle=%0d got=%b%b%b/%0d/%b expected=%b%b%b/%0d/%b",n,ov,ou,ol,om,ordy,ev,eu,el,em,ready);
            if(data!==ed)$fatal(1,"Pixels cycle=%0d mode=%0d got=%h expected=%h",n,om,data,ed);
            if(pv!==expected_pv || pu!==(rst?prev_u:1'b0))$fatal(1,"Packed controls at %0d",n);
            if(pv && packed_data!==expected_word)$fatal(1,"Packed byte order at %0d",n);
            if(ov&&om==3)$fdisplay(capture_fd,"%024h",data);
            if(ov)pixels=pixels+4;if(ou)frames=frames+1;if(pv)words=words+1;
            prev_v=ev;prev_u=eu;prev_data=ed;
            n=n+1;@(negedge clk);
        end
        $fclose(capture_fd);
        $display("PASS SEPIA_PORTRAIT W=%0d H=%0d cycles=%0d pixels=%0d SOFs=%0d packed_words=%0d",W,H,n,pixels,frames,words);
        $finish;
    end
    initial begin #4000000000;$fatal(1,"Timeout");end
endmodule
