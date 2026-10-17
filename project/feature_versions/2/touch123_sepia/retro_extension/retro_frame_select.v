// Modes: 0 raw, 1 original edge, 2 raw for downstream original OSD, 3 sepia.
// All branches and the frame mode are aligned to four register stages.
module retro_frame_select #(
    parameter IMG_WIDTH=1280,IMG_HEIGHT=720,EDGE_THRESHOLD=80,
    parameter RETRO_GRAIN=1,RETRO_VIGNETTE=1
)(input wire I_clk,I_rst_n,input wire [1:0] I_mode,
  input wire [95:0] I_data,input wire I_valid,I_user,I_last,I_ready,
  output wire [95:0] O_data,output wire O_valid,O_user,O_last,O_ready,
  output wire [1:0] O_frame_mode);
    wire [95:0] sepia,edge_data;
    sepia_core #(.W(IMG_WIDTH),.H(IMG_HEIGHT),.GRAIN(RETRO_GRAIN),.VIGNETTE(RETRO_VIGNETTE)) u_sepia(
        .clk(I_clk),.rst_n(I_rst_n),.data_i(I_data),.valid_i(I_valid),.sof_i(I_user),.eol_i(I_last),
        .data_o(sepia),.valid_o(O_valid),.sof_o(O_user),.eol_o(O_last));
    edge_detect_96 #(.IMG_WIDTH(IMG_WIDTH),.IMG_HEIGHT(IMG_HEIGHT),.EDGE_TH(EDGE_THRESHOLD)) u_edge(
        .I_clk(I_clk),.I_rst_n(I_rst_n),.I_tdata(I_data),.I_tvalid(I_valid),.I_tuser(I_user),.I_tlast(I_last),.I_tready(I_ready),
        .O_tdata(edge_data),.O_tvalid(),.O_tuser(),.O_tlast(),.O_tready(O_ready));
    reg [95:0] raw_pipe[0:3],edge_pipe[0:2];
    reg [1:0] mode_pipe[0:3],active_mode;
    reg user_d;integer k;
    always @(posedge I_clk or negedge I_rst_n)begin
        if(!I_rst_n)begin
            for(k=0;k<4;k=k+1)begin raw_pipe[k]<=0;mode_pipe[k]<=0;end
            for(k=0;k<3;k=k+1)edge_pipe[k]<=0;
            active_mode<=0;user_d<=0;
        end else begin
            raw_pipe[0]<=I_data;edge_pipe[0]<=edge_data;user_d<=I_user;
            mode_pipe[0]<=(I_user&&!user_d)?I_mode:active_mode;
            if(I_user&&!user_d)active_mode<=I_mode;
            for(k=1;k<4;k=k+1)begin raw_pipe[k]<=raw_pipe[k-1];mode_pipe[k]<=mode_pipe[k-1];end
            for(k=1;k<3;k=k+1)edge_pipe[k]<=edge_pipe[k-1];
        end
    end
    assign O_frame_mode=mode_pipe[3];
    assign O_data=!O_valid?96'd0:((O_frame_mode==3)?sepia:((O_frame_mode==1)?edge_pipe[2]:raw_pipe[3]));
endmodule
