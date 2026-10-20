`timescale 1ns/1ps
// Expected numbers are calculated from the physical equations for the fixture:
// fsADC=80 kHz, fsCtrl=2 kHz, pipeline=4, slew=3/s, PLL Kp=4 Ki=20.
module tb_custom_head;
    reg clk=0;always #5 clk=~clk;
    reg nrst=0,cu=0,pu=0,nu=0;
    reg signed [23:0] phase=0;reg signed [27:0] virtual_actual=0;
    wire signed [39:0] pi_state;wire signed [63:0] pi_command;wire pi_limit;
    hrg_pi_aw pi_dut(64'sd2097152,40'sd0,32'sd131072,32'sd65536,
        40'sd1610612736,64'sd1073741824,16'd3,pi_state,pi_command,pi_limit);
    wire signed [27:0] ec,qc,vc;wire cv,cl;
    hrg_controller ctl(clk,nrst,cu,5'd3,32'sd0,32'sd0,32'sd16777216,
        32'sd157286,32'sd22938,32'sd458752,32'sd91750,28'sd0,
        ec,qc,vc,cv,cl,2'd1,1'b0,1'b0,28'sd0,28'sd0,28'sd0,28'sd0,28'sd0,28'sd0);
    wire [31:0] fcw;wire frozen,limited,locked;
    hrg_dpll pll(clk,nrst,pu,1'b1,1'b1,32'sd16777216,-32'sd8388608,32'h20000000,fcw,frozen,limited,locked);
    wire nv,mv,uf;wire signed [47:0] angle;wire signed [31:0] rate;
    hrg_navigation nav(clk,nrst,nu,1'b1,1'b0,phase,virtual_actual,32'd1073741824,31'd1073741824,nv,angle,rate,mv,uf);
    integer i;
    initial begin
        #1;if(pi_state!==40'sd67109 || pi_command!==64'sd268502565) $fatal(1,"2kHz PI scaling failed");
        repeat(3) @(negedge clk);nrst=1;cu=1;
        for(i=1;i<=5;i=i+1) begin
            @(posedge clk);#1;
            if((i<5 && ec!==0) || (i==5 && ec!==28'sd6291)) $fatal(1,"4-update pipeline/slew failed i=%0d ec=%0d",i,ec);
            @(negedge clk);
        end
        cu=0;pu=1;
        @(posedge clk);#1;if(fcw!==32'd536978555) $fatal(1,"80kHz PLL conversion failed got=%0d",fcw);
        @(negedge clk);pu=0;nu=1;phase=0;
        @(posedge clk);#1;
        @(negedge clk);phase=1000;
        @(posedge clk);#1;if(angle!==-48'sd90000 || rate!==-32'sd703125 || !nv) $fatal(1,"2kHz navigation scale failed");
        @(negedge clk);virtual_actual=28'sd4194304;
        @(posedge clk);#1;if(angle!==48'sd390632 || rate!==32'sd3754936) $fatal(1,"2kHz virtual cancellation failed angle=%0d rate=%0d",angle,rate);
        $display("CUSTOM_HEAD_NUMERIC_SCOREBOARD_PASS");$finish;
    end
    initial begin #100000;$fatal(1,"Custom profile timeout");end
endmodule
