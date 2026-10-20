`timescale 1ns/1ps
module tb_hrg_profile_spi;
    reg clk=0;always #5 clk=~clk;
    reg nrst=0,valid=0,sclk=0,csn=1,mosi=0;
    wire miso,nav;
    wire signed [15:0] de,dq,dv;wire signed [47:0] angle;wire signed [31:0] rate;wire [31:0] status;
    hrg_sensor_if_top dut(clk,nrst,valid,18'sd0,18'sd0,14'sd2500,sclk,csn,mosi,miso,de,dq,dv,nav,angle,rate,status);
    string plan_path,expected_path;
    integer fd,n,op,addr,value,i,errors=0,commands=0;
    longint signed e[0:12];
    task automatic byte_out(input [7:0] data);
        integer bitno;
        begin for(bitno=7;bitno>=0;bitno=bitno-1) begin mosi=data[bitno];#50;sclk=1;#50;sclk=0;end end
    endtask
    task automatic check(input string name,input longint signed actual,expected);
        if(actual!==expected) begin errors=errors+1;$display("HEAD_PROFILE_MISMATCH %s got=%0d expected=%0d",name,actual,expected);end
    endtask
    initial begin
        if(!$value$plusargs("PLAN_%s",plan_path) || !$value$plusargs("EXPECTED_%s",expected_path)) $fatal(1,"Missing profile paths");
        repeat(8) @(negedge clk);nrst=1;
        fd=$fopen(plan_path,"r");if(!fd) $fatal(1,"Missing generated SPI plan");
        while(!$feof(fd)) begin
            n=$fscanf(fd,"%d %d %d\n",op,addr,value);if(n!=3) $fatal(1,"Bad SPI command");
            if(op==1) begin csn=0;byte_out(addr);byte_out(value);#100;csn=1;#1000;end
            else if(op==2) begin
                for(i=0;i<value;i=i+1) begin @(negedge clk);valid=1;@(negedge clk);valid=0;end
                repeat(4) @(negedge clk);
            end else $fatal(1,"Unknown SPI plan op");
            commands=commands+1;
        end
        $fclose(fd);fd=$fopen(expected_path,"r");if(!fd) $fatal(1,"Missing expected values");
        n=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %d %d %d",e[0],e[1],e[2],e[3],e[4],e[5],e[6],e[7],e[8],e[9],e[10],e[11],e[12]);
        if(n!=13) $fatal(1,"Bad expected values");$fclose(fd);
        check("explicit zero mode",dut.explicit_profile,1);
        check("energy kp",$signed(dut.energy_kp),e[0]);check("energy ki",$signed(dut.energy_ki),e[1]);
        check("quad kp",$signed(dut.quad_kp),e[2]);check("quad ki",$signed(dut.quad_ki),e[3]);
        check("energy ref",$signed(dut.energy_ref),e[4]);check("virtual",$signed(dut.cfg_virtual),e[5]);
        check("base FCW",{32'd0,dut.base_fcw},e[6]);check("energy hold",$signed(dut.energy_hold),e[7]);
        check("quad hold",$signed(dut.quad_hold),e[8]);check("Bryan",{32'd0,dut.bryan_q30},e[9]);
        check("alpha",{33'd0,dut.rate_alpha},e[10]);check("relative lock window",$signed(dut.energy_window),e[11]);
        check("CTRL",dut.ctrl_byte,e[12]);
        if(e[12]&16) check("warm loaded PLL FCW",{32'd0,dut.nco_fcw},e[6]);
        if(errors || commands!=52) $fatal(1,"Profile SPI scoreboard failed errors=%0d commands=%0d",errors,commands);
        $display("HEAD_PROFILE_SCOREBOARD_PASS commands=%0d",commands);$finish;
    end
    initial begin #10000000;$fatal(1,"Profile SPI timeout");end
endmodule
