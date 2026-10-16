`timescale 1ns/1ps
module tb_hrg_top_scoreboard;
    reg clk=0;always #5 clk=~clk;
    reg nrst=0,adc_valid=0;
    reg signed [17:0] ax=0,ay=0;
    reg sclk=0,csn=1,mosi=0;
    wire miso,nav_valid;
    wire signed [15:0] de,dq,dv;
    wire signed [47:0] angle;
    wire signed [31:0] rate;
    wire [31:0] status;
    hrg_sensor_if_top dut(clk,nrst,adc_valid,ax,ay,14'sd2500,sclk,csn,mosi,miso,de,dq,dv,nav_valid,angle,rate,status);
    integer fd,count,cycles=0,errors=0,nav_count=0,mode_bits=0;
    longint signed row[0:13];
    task automatic spi_byte(input [7:0] value);
        integer b;
        begin for(b=7;b>=0;b=b-1) begin mosi=value[b];#50;sclk=1;#50;sclk=0;end end
    endtask
    task automatic configure;
        begin
            @(negedge clk);nrst=1;adc_valid=0;
            repeat(8) @(negedge clk);
            csn=0;spi_byte(8'h00);spi_byte(8'h3f);#100;csn=1;#1000;
            if(dut.ctrl_byte!==8'h3f) $fatal(1,"SPI CTRL configuration failed");
        end
    endtask
    task automatic check(input string name,input longint signed got,expected);
        if(got!==expected) begin
            errors=errors+1;
            if(errors<=24) $display("TOP_MISMATCH cycle=%0d %s got=%0d expected=%0d",cycles,name,got,expected);
        end
    endtask
    initial begin
        fd=$fopen("top_vectors.txt","r");if(!fd) $fatal(1,"Missing top vectors");
        while(!$feof(fd)) begin
            count=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",row[0],row[1],row[2],row[3],row[4],row[5],row[6],row[7],row[8],row[9],row[10],row[11],row[12],row[13]);
            if(count!=14) $fatal(1,"Malformed top vector");
            @(negedge clk);nrst=row[0];adc_valid=row[1];ax=row[2];ay=row[3];
            @(posedge clk);#1;cycles=cycles+1;
            check("DAC energy",$signed(de),row[4]);check("DAC quad",$signed(dq),row[5]);check("DAC virtual",$signed(dv),row[6]);
            check("nav valid",nav_valid,row[7]);check("angle",$signed(angle),row[8]);check("rate",$signed(rate),row[9]);
            check("status",{32'd0,status},row[10]);check("FCW",{32'd0,dut.nco_fcw},row[11]);
            check("mode",dut.mode,row[12]);check("update count",{32'd0,dut.sample_count},row[13]);
            if(nav_valid) nav_count=nav_count+1;
            mode_bits=mode_bits|(1<<dut.mode);
            if(!row[0]) configure();
        end
        $fclose(fd);
        $display("TOP_SCOREBOARD_SUMMARY cycles=%0d updates=%0d nav=%0d modes=%0h errors=%0d final_rate=%0f",cycles,dut.sample_count,nav_count,mode_bits,errors,$itor($signed(rate))/65536.0);
        if(errors || dut.sample_count!=4000 || nav_count!=4000 || mode_bits!=14) $fatal(1,"Top scoreboard failed");
        $display("TOP_SCOREBOARD_PASS");$finish;
    end
    initial begin #10000000;$fatal(1,"Top scoreboard watchdog");end
endmodule
