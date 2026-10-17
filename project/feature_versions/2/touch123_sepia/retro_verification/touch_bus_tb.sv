`timescale 1ns/1ps
module touch_bus_tb;
    reg clk=0; always #500 clk=~clk; // 1 MHz, real millisecond intervals
    reg rst=0;
    tri1 scl,sda,int_pin;
    reg slave_low=0, nack=0, stretch=0, stuck=0;
    assign sda=(slave_low||stuck) ? 1'b0 : 1'bz;
    assign scl=stretch ? 1'b0 : 1'bz;
    wire reset_n,press,held,online;
    wire [15:0] errors;
    gt911_touch #(.CLK_HZ(1000000)) dut (
      .I_clk(clk),.I_rst_n(rst),.IO_scl(scl),.IO_sda(sda),.IO_int(int_pin),
      .O_reset_n(reset_n),.O_press(press),.O_held(held),.O_online(online),.O_error_count(errors));
    reg [7:0] status=0;
    integer presses=0,reads=0,clears=0;
    reg [1:0] mode=0;
    always @(posedge clk) if(press) begin
        presses=presses+1;
        mode=(mode==2)?0:mode+1;
    end
    task automatic start_condition;
        begin
            @(negedge sda);
            while(scl!==1'b1) @(negedge sda);
        end
    endtask
    task automatic recv_byte(output reg [7:0] value);
        integer i;
        begin
            for(i=7;i>=0;i=i-1) begin @(posedge scl); value[i]=sda; end
            @(negedge scl); slave_low=!nack;
            @(posedge scl);
            @(negedge scl); slave_low=0;
        end
    endtask
    task automatic send_byte(input reg [7:0] value);
        integer i;
        begin
            for(i=7;i>=0;i=i-1) begin
                slave_low=!value[i]; @(posedge scl); @(negedge scl);
            end
            slave_low=0; @(posedge scl);
            if(sda!==1'b1) $fatal(1,"Master did not NACK last read byte");
            @(negedge scl);
        end
    endtask
    reg [7:0] address,hi,lo,value;
    integer j;
    initial forever begin
        start_condition(); recv_byte(address);
        if(!nack) begin
            if(address!==8'hba && address!==8'hbb) $fatal(1,"Wrong GT911 address %h",address);
            if(address==8'hba) begin
                recv_byte(hi); recv_byte(lo);
                if({hi,lo}!==16'h814e) $fatal(1,"Wrong status register");
                // The only write payload is zero; a high first clock with
                // SDA high is the repeated-START setup, before its SDA fall.
                @(posedge scl);
                if(sda===1'b1) begin
                        start_condition(); recv_byte(address);
                        if(address!==8'hbb) $fatal(1,"Missing repeated START/read address");
                        value=status; send_byte(value); reads=reads+1;
                end else begin
                        value[7]=sda;
                        for(j=6;j>=0;j=j-1) begin @(posedge scl);value[j]=sda;end
                        @(negedge scl);slave_low=!nack;
                        @(posedge scl);@(negedge scl);slave_low=0;
                        if(value!==0) $fatal(1,"Status clear must write zero");
                        status=0; clears=clears+1;
                end
            end else $fatal(1,"Read address without register-pointer phase");
        end
    end
    task automatic report(input [7:0] val);
        integer old_c;
        begin
            old_c=clears;status=val;
            wait(clears>old_c);repeat(20) @(posedge clk);
        end
    endtask
    task automatic expect_count(input integer count);
        begin if(presses!=count) $fatal(1,"Press count %0d expected %0d",presses,count); end
    endtask
    initial begin
        #10000;rst=1;
        #19000000;if(reset_n!==0 || int_pin!==0) $fatal(1,"Reset/address sequence");
        @(posedge reset_n);#6000000;
        if(int_pin!==0) $fatal(1,"INT must stay low for synchronization");
        #56000000;if(int_pin!==1) $fatal(1,"INT must be released after reset");
        wait(online);
        report(8'h81);expect_count(1);
        repeat(4) report(8'h81);expect_count(1); // hold/drag
        report(8'h82);expect_count(1); // additional finger
        #50000000;expect_count(1); // ready=0 is not a release
        report(8'h80);#1000000;report(8'h81);expect_count(1); // short release bounce
        report(8'h80);#35000000;report(8'h81);expect_count(2);
        // Failed reads and clear writes never release a held contact.
        nack=1;#20000000;expect_count(2);nack=0;
        report(8'h81);expect_count(2);
        report(8'h80);#35000000;report(8'h85);expect_count(3);
        if(mode!=0) $fatal(1,"Mode must loop 0->1->2->0");
        report(8'h86);expect_count(3); // malformed contact count
        $display("PASS GT911 serial read/repeated-START/NACK/clear, reset, hold, drag, multi-touch, release debounce, NACK errors and 1-2-3 loop; reads=%0d clears=%0d errors=%0d",reads,clears,errors);
        $finish;
    end
    initial begin #1000000000;$fatal(1,"Touch bus watchdog"); end
endmodule
