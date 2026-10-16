`timescale 1ns/1ps
module touch_ui_tb;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,report_valid=0;
    reg [3:0] contacts=0;
    reg [15:0] x=0,y=0;
    wire visible,select_valid;
    wire [1:0] selected;
    touch_ui_controller #(.CLK_HZ(1000)) dut (
        .I_clk(clk),.I_rst_n(rst),.I_report_valid(report_valid),
        .I_contacts(contacts),.I_x(x),.I_y(y),
        .O_menu_visible(visible),.O_select_valid(select_valid),
        .O_select_mode(selected));
    integer selections=0;
    reg [1:0] last_mode=0;
    always @(posedge clk) if(select_valid) begin
        selections=selections+1;last_mode=selected;
    end
    task automatic sample(input [3:0] n,input [15:0] xx,yy);
        begin
            @(negedge clk);contacts=n;x=xx;y=yy;report_valid=1;
            @(negedge clk);report_valid=0;
        end
    endtask
    task automatic settle;
        begin repeat(35) @(posedge clk);#1;end
    endtask
    task automatic open_drawer;
        begin
            sample(1,500,550);sample(1,500,430);sample(0,0,0);
            settle();
            if(visible!==1) $fatal(1,"Up swipe did not open drawer");
        end
    endtask
    initial begin
        #22;rst=1;#1;
        if(visible!==0) $fatal(1,"Drawer must reset hidden");
        // A tap while hidden has no effect.
        sample(1,500,530);sample(0,0,0);settle();
        if(visible || selections) $fatal(1,"Hidden button selected");
        // Horizontal movement and a multi-touch report cancel gestures.
        sample(1,500,550);sample(1,600,400);sample(0,0,0);settle();
        if(visible) $fatal(1,"Diagonal gesture opened drawer");
        sample(2,500,550);sample(1,500,430);sample(0,0,0);settle();
        if(visible) $fatal(1,"Multi-touch opened drawer");
        open_drawer();
        if(selections) $fatal(1,"Opening swipe selected a mode");
        sample(1,500,535);sample(0,0,0);settle();
        if(selections!=1 || last_mode!=1 || !visible)
            $fatal(1,"EDGE tap failed");
        // A short release bounce followed by a 25-pixel move is a drag.
        sample(1,500,535);sample(0,0,0);
        repeat(5) @(posedge clk);
        sample(1,500,560);sample(0,0,0);settle();
        if(selections!=1) $fatal(1,"Release bounce selected a mode");
        // Drag across buttons must not select another mode.
        sample(1,140,535);sample(1,800,535);sample(0,0,0);settle();
        if(selections!=1) $fatal(1,"Drag selected a mode");
        sample(1,500,470);sample(1,500,570);sample(0,0,0);settle();
        if(visible) $fatal(1,"Down swipe did not close drawer");
        open_drawer();
        sample(1,300,100);sample(0,0,0);settle();
        if(visible) $fatal(1,"Outside tap did not close drawer");
        open_drawer();
        repeat(3010) @(posedge clk);#1;
        if(visible) $fatal(1,"Drawer did not auto-hide");
        if(selections!=1) $fatal(1,"Unexpected selection");
        $display("PASS swipe open/close, hidden passthrough, tap, drag, multi-touch and auto-hide");
        $finish;
    end
    initial begin #100000;$fatal(1,"Gesture watchdog");end
endmodule
