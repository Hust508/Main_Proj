`timescale 1ns/1ps
module touch_two_cycle_tb;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,report=0;reg [3:0] contacts=0;
    wire press,held;wire [2:0] mode;
    touch_press_once #(.CLK_HZ(1000),.RELEASE_MS(3)) P(.I_clk(clk),.I_rst_n(rst),.I_report_valid(report),.I_contacts(contacts),.O_press(press),.O_held(held));
    cartoon_mode_cycle C(.clk(clk),.rst_n(rst),.press_i(press),.mode_o(mode));
    task sample(input [3:0] c,input bit valid);
        begin @(negedge clk);contacts=c;report=valid;@(negedge clk);report=0;repeat(5)@(negedge clk);end
    endtask
    task check(input [2:0] expected);
        begin if(mode!==expected)$fatal(1,"Mode got=%0d expected=%0d",mode,expected);end
    endtask
    initial begin
        repeat(3)@(negedge clk);rst=1;check(0);
        sample(1,1);check(1);
        sample(1,1);sample(2,1);check(1); // Hold, drag or added finger.
        sample(0,0);sample(1,1);check(1); // Unready report is not release.
        sample(0,1);sample(1,1);check(0);
        sample(0,1);sample(1,1);check(1);
        sample(0,1);sample(1,1);check(0);
        sample(0,1);sample(1,1);check(1);
        sample(0,1);sample(1,1);check(0);
        rst=0;@(negedge clk);check(0);
        $display("PASS two-mode 0->1->0 repeated, long press/multitouch protection and reset-to-original");$finish;
    end
endmodule
