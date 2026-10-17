module wb_ui_control #(parameter CLK_HZ=25000000,LONG_MS=800,RELEASE_MS=30)(
 input wire I_clk,I_rst_n,I_online,I_report,
 input wire [3:0] I_contacts,input wire [9:0] I_x,I_y,
 input wire [1:0] I_buttons_n,
 output reg [2:0] O_page,output reg [1:0] O_mode,O_preset,
 output reg [6:0] O_index,O_gain
);
 // Pages: preview, settings, auto, presets, custom Kelvin, sensitivity.
 reg [31:0] tick;wire ms=tick==CLK_HZ/1000-1;
 reg held,blocked,consumed,drag;
 reg [9:0] start_x,start_y;
 reg [15:0] hold_ms;reg [7:0] released_ms,repeat_ms;
 reg [1:0] direction;
 reg inc_req,dec_req,reset_gain;reg [1:0] gain_preset;
 reg [6:0] custom_index;
 (* async_reg="true" *) reg [1:0] keys_meta,keys_sync;
 reg [4:0] key_db[0:1];reg [15:0] key_time[0:1];
 reg [7:0] key_repeat[0:1];reg [1:0] key_event;
 integer i;
 function [6:0] slider_index(input [9:0] x);
  begin slider_index=(x<=600)?0:(x>=975)?75:(x-600+2)/5;end
 endfunction
 wire moved=(I_x>start_x+24)||(start_x>I_x+24)||(I_y>start_y+24)||(start_y>I_y+24);
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin tick<=0;keys_meta<=3;keys_sync<=3;key_event<=0;
  for(i=0;i<2;i=i+1)begin key_db[i]<=0;key_time[i]<=0;key_repeat[i]<=0;end
 end else begin
  tick<=ms?0:tick+1'b1;keys_meta<=I_buttons_n;keys_sync<=keys_meta;key_event<=0;
  if(ms)for(i=0;i<2;i=i+1)begin
   if(keys_sync[i])begin key_db[i]<=0;key_time[i]<=0;key_repeat[i]<=0;end
   else if(key_db[i]<20)begin
    key_db[i]<=key_db[i]+1'b1;
    if(key_db[i]==19)key_event[i]<=1;
   end else if(key_time[i]<500)key_time[i]<=key_time[i]+1'b1;
   else if(key_repeat[i]==119)begin key_repeat[i]<=0;key_event[i]<=1;end
   else key_repeat[i]<=key_repeat[i]+1'b1;
  end
 end
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)O_gain<=80;
 else if(gain_preset!=0)O_gain<=(gain_preset==1)?7'd16:(gain_preset==2)?7'd48:7'd80;
 else if(reset_gain)O_gain<=80;
 else if((inc_req||key_event[1])&&!(dec_req||key_event[0]))begin if(O_gain<89)O_gain<=O_gain+1'b1;end
 else if((dec_req||key_event[0])&&!(inc_req||key_event[1]))begin if(O_gain>16)O_gain<=O_gain-1'b1;end
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  O_page<=0;O_mode<=0;O_preset<=1;O_index<=30;custom_index<=30;
  held<=0;blocked<=0;consumed<=0;drag<=0;direction<=0;
  start_x<=0;start_y<=0;hold_ms<=0;released_ms<=RELEASE_MS;repeat_ms<=0;
  inc_req<=0;dec_req<=0;reset_gain<=0;gain_preset<=0;
 end else begin
  inc_req<=0;dec_req<=0;reset_gain<=0;gain_preset<=0;
  if(ms)begin
   if(!held)begin if(released_ms<255)released_ms<=released_ms+1'b1;end
   else begin
    if(hold_ms<65535)hold_ms<=hold_ms+1'b1;
    if(O_page==0&&!consumed&&hold_ms>=LONG_MS-1)begin O_page<=1;consumed<=1;end
    if(direction!=0&&hold_ms>=500)begin
     if(repeat_ms==119)begin repeat_ms<=0;inc_req<=direction==2;dec_req<=direction==1;end
     else repeat_ms<=repeat_ms+1'b1;
    end
   end
  end
  if(!I_online)begin held<=0;blocked<=1;drag<=0;direction<=0;hold_ms<=0;end
  else if(I_report)begin
   if(I_contacts==0)begin
    if(held||blocked)released_ms<=0;
    held<=0;blocked<=0;drag<=0;direction<=0;hold_ms<=0;repeat_ms<=0;
   end else if(I_contacts!=1)begin held<=0;blocked<=1;drag<=0;direction<=0;consumed<=1;released_ms<=0;end
   else if(!blocked)begin
    if(!held&&released_ms>=RELEASE_MS)begin
     held<=1;start_x<=I_x;start_y<=I_y;hold_ms<=0;consumed<=0;drag<=0;direction<=0;repeat_ms<=0;
     if(O_page!=0)begin
      consumed<=1;
      if(I_x>=584&&I_x<688&&I_y>=24&&I_y<80)O_page<=(O_page==1)?0:1;
      else case(O_page)
       1:if(I_x>=584&&I_x<1000)begin
        if(I_y>=112&&I_y<176)begin O_page<=2;O_mode<=0;end
        else if(I_y>=192&&I_y<256)O_page<=3;
        else if(I_y>=272&&I_y<336)begin O_page<=4;O_mode<=2;O_index<=custom_index;end
        else if(I_y>=352&&I_y<416)O_page<=5;
       end
       3:if(I_x>=584&&I_x<1000)begin
        if(I_y>=112&&I_y<176)begin O_mode<=1;O_preset<=0;O_index<=5;end
        else if(I_y>=192&&I_y<256)begin O_mode<=1;O_preset<=1;O_index<=30;end
        else if(I_y>=272&&I_y<336)begin O_mode<=1;O_preset<=2;O_index<=40;end
        else if(I_y>=352&&I_y<416)begin O_mode<=1;O_preset<=3;O_index<=50;end
       end
       4:if(I_y>=252&&I_y<340&&I_x>=584&&I_x<1000)begin
        drag<=1;O_index<=slider_index(I_x);custom_index<=slider_index(I_x);
       end
       5:begin
        if(I_y>=112&&I_y<168)begin
         if(I_x>=584&&I_x<712)gain_preset<=1;
         else if(I_x>=728&&I_x<856)gain_preset<=2;
         else if(I_x>=872&&I_x<1000)gain_preset<=3;
        end else if(I_y>=300&&I_y<388)begin
         if(I_x>=608&&I_x<736)begin dec_req<=1;direction<=1;end
         else if(I_x>=856&&I_x<984)begin inc_req<=1;direction<=2;end
        end else if(I_y>=432&&I_y<488&&I_x>=584&&I_x<1000)reset_gain<=1;
       end
      endcase
     end
    end else if(!held)begin
     // A contact returning before a stable release is bounce, not a new
     // gesture. Keep resetting the release window while it remains down.
     released_ms<=0;blocked<=1;
    end else if(held)begin
     if(drag)begin O_index<=slider_index(I_x);custom_index<=slider_index(I_x);end
     if(O_page==0&&moved)consumed<=1;
     if(direction!=0&&!(I_y>=300&&I_y<388&&((direction==1&&I_x>=608&&I_x<736)||(direction==2&&I_x>=856&&I_x<984))))direction<=0;
    end
   end
  end
 end
endmodule
