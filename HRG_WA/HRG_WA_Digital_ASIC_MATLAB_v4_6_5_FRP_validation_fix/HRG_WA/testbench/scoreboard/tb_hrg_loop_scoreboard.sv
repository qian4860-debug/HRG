`timescale 1ns/1ps
module tb_hrg_loop_scoreboard;
    reg clk=0;always #5 clk=~clk;
    longint signed row[0:23];
    integer fd,fm,count,cycles=0,errors=0,npi=0,npll=0,nnav=0,nctrl=0;
    longint signed matlab_state,matlab_command,diff,max_model_pi_error=0;
    reg signed [63:0] err=0,limit=0;
    reg signed [39:0] state=0,ilim=0;
    reg signed [31:0] kp=0,ki=0;
    reg [15:0] bg=0;
    wire signed [39:0] pi_state;
    wire signed [63:0] pi_command;
    wire pi_limited;
    hrg_pi_aw pi_dut(err,state,kp,ki,ilim,limit,bg,pi_state,pi_command,pi_limited);
    reg nrst=0,update=0,enable=0,mvalid=0;
    reg signed [31:0] energy=0,l=0;
    reg [31:0] base=0;
    wire [31:0] fcw;
    wire frozen,limited,locked;
    hrg_dpll pll_dut(clk,nrst,update,enable,mvalid,energy,l,base,fcw,frozen,limited,locked);
    reg nnrst=0,nupdate=0,nvalid=0,zero=0;
    reg signed [23:0] phase=0;
    reg signed [27:0] virt=0;
    reg [31:0] bryan=0;
    reg [30:0] alpha=0;
    wire nv,mv,uf;
    wire signed [47:0] angle;
    wire signed [31:0] rate;
    hrg_navigation nav_dut(clk,nnrst,nupdate,nvalid,zero,phase,virt,bryan,alpha,nv,angle,rate,mv,uf);
    reg crst=0,cu=0,entry=0,track=0;
    reg [4:0] ctrl=0;reg [1:0] mode=0;
    reg signed [31:0] ce=0,cq=0,ekp=0,eki=0,qkp=0,qki=0;
    reg signed [27:0] cv=0,ae=0,aq=0,de=0,dq=0,he=0,hq=0;
    wire signed [27:0] eo,qo,vo;wire valid_o,limit_o;
    hrg_controller ctl_dut(clk,crst,cu,ctrl,ce,cq,32'sd16777216,ekp,eki,qkp,qki,cv,
        eo,qo,vo,valid_o,limit_o,mode,entry,track,ae,aq,de,dq,he,hq);
    task automatic check(input string label,input longint signed actual,expected);
        if(actual!==expected) begin
            errors=errors+1;
            if(errors<=30) $display("LOOP_MISMATCH cycle=%0d %s got=%0d expected=%0d",cycles,label,actual,expected);
        end
    endtask
    initial begin
        fd=$fopen("pi_vectors.txt","r");if(!fd) $fatal(1,"Missing PI vectors");
        fm=$fopen("model_pi_vectors.txt","r");if(!fm) $fatal(1,"Run MATLAB export_model_vectors to generate original PI reference");
        while(!$feof(fd)) begin
            count=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d\n",row[0],row[1],row[2],row[3],row[4],row[5],row[6],row[7],row[8],row[9]);
            if(count!=10) $fatal(1,"PI row");
            err=row[0];state=row[1];kp=row[2];ki=row[3];ilim=row[4];limit=row[5];bg=row[6];
            #1;cycles=cycles+1;npi=npi+1;
            check("pi state",$signed(pi_state),row[7]);check("pi command",$signed(pi_command),row[8]);check("pi limit",pi_limited,row[9]);
            count=$fscanf(fm,"%d %d\n",matlab_state,matlab_command);
            if(count!=2) $fatal(1,"Missing MATLAB PI row");
            diff=$signed(pi_state)-matlab_state;if(diff<0) diff=-diff;
            if(diff>max_model_pi_error) max_model_pi_error=diff;
            if(diff>4) begin errors=errors+1;$display("MATLAB_PI_STATE_MISMATCH row=%0d delta=%0d",npi,diff);end
            diff=$signed(pi_command)-matlab_command;if(diff<0) diff=-diff;
            if(diff>max_model_pi_error) max_model_pi_error=diff;
            if(diff>4) begin errors=errors+1;$display("MATLAB_PI_COMMAND_MISMATCH row=%0d delta=%0d",npi,diff);end
        end
        $fclose(fd);$fclose(fm);fd=$fopen("pll_vectors.txt","r");if(!fd) $fatal(1,"Missing PLL vectors");
        while(!$feof(fd)) begin
            count=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %d\n",row[0],row[1],row[2],row[3],row[4],row[5],row[6],row[7],row[8],row[9],row[10]);
            if(count!=11) $fatal(1,"PLL row");
            @(negedge clk);nrst=row[0];update=row[1];enable=row[2];mvalid=row[3];energy=row[4];l=row[5];base=row[6];
            @(posedge clk);#1;cycles=cycles+1;npll=npll+1;
            check("pll fcw",{32'd0,fcw},row[7]);check("pll frozen",frozen,row[8]);check("pll limit",limited,row[9]);check("pll lock",locked,row[10]);
        end
        $fclose(fd);@(negedge clk);update=0;
        fd=$fopen("nav_vectors.txt","r");if(!fd) $fatal(1,"Missing navigation vectors");
        while(!$feof(fd)) begin
            count=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %d %d %d\n",row[0],row[1],row[2],row[3],row[4],row[5],row[6],row[7],row[8],row[9],row[10],row[11],row[12]);
            if(count!=13) $fatal(1,"NAV row");
            @(negedge clk);nnrst=row[0];nupdate=row[1];nvalid=row[2];zero=row[3];phase=row[4];virt=row[5];bryan=row[6];alpha=row[7];
            @(posedge clk);#1;cycles=cycles+1;nnav=nnav+1;
            check("nav valid",nv,row[8]);check("nav angle",$signed(angle),row[9]);check("nav rate",$signed(rate),row[10]);
            check("nav measurement valid",mv,row[11]);check("nav unwrap",uf,row[12]);
        end
        $fclose(fd);@(negedge clk);nupdate=0;
        fd=$fopen("control_extended_vectors.txt","r");if(!fd) $fatal(1,"Missing controller vectors");
        while(!$feof(fd)) begin
            count=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",row[0],row[1],row[2],row[3],row[4],row[5],row[6],row[7],row[8],row[9],row[10],row[11],row[12],row[13],row[14],row[15],row[16],row[17],row[18],row[19],row[20],row[21],row[22],row[23]);
            if(count!=24) $fatal(1,"CTRL row");
            @(negedge clk);crst=row[0];cu=row[1];ctrl=row[2];ce=row[3];cq=row[4];ekp=row[5];eki=row[6];qkp=row[7];qki=row[8];cv=row[9];
            mode=row[10];entry=row[11];track=row[12];ae=row[13];aq=row[14];de=row[15];dq=row[16];he=row[17];hq=row[18];
            @(posedge clk);#1;cycles=cycles+1;nctrl=nctrl+1;
            check("controller valid",valid_o,row[19]);check("controller limit",limit_o,row[20]);
            check("controller energy",$signed(eo),row[21]);check("controller quad",$signed(qo),row[22]);check("controller virtual",$signed(vo),row[23]);
        end
        $fclose(fd);
        $display("LOOP_SCOREBOARD_SUMMARY pi=%0d pll=%0d nav=%0d controller=%0d errors=%0d",npi,npll,nnav,nctrl,errors);
        $display("MATLAB_PI_MAX_ERROR_Q30_LSB=%0d",max_model_pi_error);
        if(errors || npi!=5000 || npll!=6000 || nnav!=6000 || nctrl!=3200) $fatal(1,"Loop scoreboard failed");
        $display("LOOP_SCOREBOARD_PASS");$finish;
    end
    initial begin #10000000;$fatal(1,"Loop scoreboard watchdog");end
endmodule
