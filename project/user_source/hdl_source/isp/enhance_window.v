// Centered replicate-border 3x3 windows, four adjacent pixels per valid beat.
// Three rotating row banks. Normal output follows the arriving bottom row;
// only the replicated last row is read autonomously, at the end of the frame.
// There is no line-period timer or completed-row scheduler in this design.
module enhance_window #(parameter W=1280,H=720,B=26)(
 input wire clk,rst_n,flush_i,valid_i,sof_i,
 input wire [4*B-1:0] data_i,
 output reg valid_o,sof_o,eol_o,output reg [4*9*B-1:0] win_o
);
 localparam G=W/4,AW=(G<2)?1:$clog2(G);
 (* ram_style="bram" *) reg [4*B-1:0] row0[0:G-1],row1[0:G-1],row2[0:G-1];
 reg [AW-1:0] ix,dx,qx;
 reg [10:0] iy,qy,tail_y;
 reg [1:0] bank,last_bank,qmid,qtop;
 reg sof_d,draining,rv,qdrain,tail;
 wire fs=flush_i||(sof_i&&!sof_d);
 wire [AW-1:0] wx=fs?{AW{1'b0}}:ix;
 wire [10:0] wy=fs?11'd0:iy;
 wire [1:0] wb=fs?2'd0:bank;
 function [1:0] prev_bank(input [1:0] b);
  begin prev_bank=(b==0)?2'd2:b-1'b1;end
 endfunction
 function [1:0] next_bank(input [1:0] b);
  begin next_bank=(b==2)?2'd0:b+1'b1;end
 endfunction
 wire normal_read=rst_n&&!fs&&valid_i&&(wy>0)&&(wy<H);
 wire drain_read=rst_n&&!fs&&draining;
 wire read_en=normal_read||drain_read;
 wire [AW-1:0] ra=drain_read?dx:wx;
 reg [4*B-1:0] q0,q1,q2,bottom;
 function [4*B-1:0] pick;
  input [1:0] b;input [4*B-1:0] a,c,d;
  begin case(b)0:pick=a;1:pick=c;default:pick=d;endcase end
 endfunction
 wire [4*B-1:0] qt=pick(qtop,q0,q1,q2),qm=pick(qmid,q0,q1,q2);
 wire [4*B-1:0] qb=qdrain?qm:bottom;
 reg [4*B-1:0] ct,cm,cb;
 reg [B-1:0] lt,lm,lb;
 wire [B-1:0] rt=tail?ct[B-1:0]:qt[4*B-1-:B];
 wire [B-1:0] rm=tail?cm[B-1:0]:qm[4*B-1-:B];
 wire [B-1:0] rb=tail?cb[B-1:0]:qb[4*B-1-:B];
 wire [6*B-1:0] tr={lt,ct,rt},mr={lm,cm,rm},br={lb,cb,rb};
 wire emit=(rv&&(qx!=0))||tail;
 // Input bank is distinct from the normal top/middle read banks. The
 // potentially colliding read of the write bank is never selected.
 always @(posedge clk)begin
  if(rst_n&&valid_i&&(wy<H))case(wb)
   0:row0[wx]<=data_i;1:row1[wx]<=data_i;2:row2[wx]<=data_i;
  endcase
  if(read_en)begin q0<=row0[ra];q1<=row1[ra];q2<=row2[ra];bottom<=data_i;end
 end
 // Datapath registers need no reset: valid/row guards qualify every use.
 // This also removes thousands of asynchronous-reset loads from the camera.
 integer p,c;
 always @(posedge clk)begin
  if(!fs)begin
   if(rv)begin
    ct<=qt;cm<=qm;cb<=qb;
    if(qx==0)begin lt<=qt[4*B-1-:B];lm<=qm[4*B-1-:B];lb<=qb[4*B-1-:B];end
    else begin lt<=ct[B-1:0];lm<=cm[B-1:0];lb<=cb[B-1:0];end
   end
   if(emit)for(p=0;p<4;p=p+1)for(c=0;c<3;c=c+1)begin
    win_o[(3-p)*9*B+(8-c)*B+:B]<=tr[(5-p-c)*B+:B];
    win_o[(3-p)*9*B+(5-c)*B+:B]<=mr[(5-p-c)*B+:B];
    win_o[(3-p)*9*B+(2-c)*B+:B]<=br[(5-p-c)*B+:B];
   end
  end
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   ix<=0;iy<=0;bank<=0;last_bank<=0;dx<=0;draining<=0;
   qx<=0;qy<=0;qmid<=0;qtop<=0;qdrain<=0;rv<=0;tail<=0;tail_y<=0;sof_d<=0;
   valid_o<=0;sof_o<=0;eol_o<=0;
  end else begin
   sof_d<=sof_i;valid_o<=0;sof_o<=0;eol_o<=0;
   if(fs)begin
    ix<=0;iy<=0;bank<=0;last_bank<=0;dx<=0;draining<=0;
    rv<=0;tail<=0;
   end else begin
    rv<=read_en;tail<=0;
    if(read_en)begin
     qx<=ra;qdrain<=drain_read;
     if(drain_read)begin
      qy<=H-1;qmid<=last_bank;qtop<=(H==1)?last_bank:prev_bank(last_bank);
      if(dx==G-1)begin draining<=0;dx<=0;end else dx<=dx+1'b1;
     end else begin
      qy<=wy-1'b1;qmid<=prev_bank(wb);
      qtop<=(wy==1)?prev_bank(wb):next_bank(wb);
     end
    end
    if(rv&&(qx==G-1))begin tail<=1;tail_y<=qy;end
    if(emit)begin
     valid_o<=1;eol_o<=tail;
     sof_o<=tail?((G==1)&&(tail_y==0)):((qy==0)&&(qx==1));
    end
   end
   if(valid_i&&(wy<H))begin
    if(wx==G-1)begin
     ix<=0;iy<=wy+1'b1;bank<=next_bank(wb);
     if(wy==H-1)begin draining<=1;last_bank<=wb;dx<=0;end
    end else begin ix<=wx+1'b1;iy<=wy;bank<=wb;end
   end
  end
 end
endmodule
