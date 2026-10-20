`timescale 1ns/1ps
// File-backed transaction scoreboard: expected values never read DUT internals.
// Strict default: any MATLAB mismatch fails. +IMPLEMENTATION_ONLY permits only
// model differences, while retaining strict cycle/bit checks against integer spec.
module tb_hrg_scoreboard;
  reg clk=0;
  always #5 clk=~clk;
  reg nrst=0, adc_valid=0;
  reg signed [17:0] ax=0, ay=0;
  reg [31:0] fcw=0;
  wire dv, overflow, wrap;
  wire [31:0] phase;
  wire signed [27:0] cx,sx,cy,sy;
  wire signed [31:0] energy,quad,r,s,l;
  hrg_dsp_core dsp(clk,nrst,adc_valid,ax,ay,fcw,dv,cx,sx,cy,sy,
                   energy,quad,r,s,l,overflow,phase,wrap);
  reg crst=0, update=0;
  reg [4:0] ctrl=0;
  reg signed [31:0] ce=0,cq=0,kp=0,ki=0,qkp=0,qki=0;
  reg signed [27:0] virt=0;
  wire signed [27:0] ecmd,qcmd,vcmd;
  wire command_valid,limit_event;
  hrg_controller controller(clk,crst,update,ctrl,ce,cq,32'sd16777216,
       kp,ki,qkp,qki,virt,ecmd,qcmd,vcmd,command_valid,limit_event,
       2'd3,1'b0,1'b0,28'sd0,28'sd0,28'sd0,28'sd0,28'sd0,28'sd0);
  reg arst=0,start=0;
  reg signed [31:0] vx=0,vy=0;
  wire busy,av;
  wire signed [23:0] angle;
  hrg_cordic cordic(clk,arst,start,vx,vy,busy,av,angle);

  integer errors=0, model_errors=0, model_transactions=0;
  integer dsp_transactions=0, ctrl_transactions=0, cordic_transactions=0;
  integer cycles=0, fd, fm, fo, count, j;
  longint signed row[0:17], model[0:8], actual[0:8];
  longint signed max_model_error[0:8];
  string labels[0:8]='{"Cx","Sx","Cy","Sy","E","Q","R","S","L"};
  function automatic longint signed abs_code(input longint signed value);
    return value < 0 ? -value : value;
  endfunction
  task automatic check(input string name, input longint signed got, expected);
    if (got !== expected) begin
      errors=errors+1;
      if(errors<=20) $display("IMPLEMENTATION_MISMATCH cycle=%0d %s actual=%0d expected=%0d",cycles,name,got,expected);
    end
  endtask
  task automatic cordic_case(input integer x,y);
    real ideal,delta;
    longint signed reference_code, distance;
    integer tick;
    begin
      @(negedge clk); start=1; vx=x;vy=y;
      @(posedge clk); #1; check("cordic busy accepted",busy,1);check("cordic early valid",av,0);
      @(negedge clk); start=0;
      for(tick=1;tick<=18;tick=tick+1) begin
        // Inputs while busy must not replace accepted transaction.
        if(tick==4) begin start=1; vx=123;vy=-456;end
        if(tick==5) start=0;
        @(posedge clk); #1;
        check("cordic latency",av,tick==18);
        check("cordic busy",busy,tick!=18);
        @(negedge clk);
      end
      ideal=$atan2(real'(y),real'(x))*16777216.0/(2.0*3.141592653589793);
      reference_code=$rtoi(ideal);
      distance=$signed(angle)-reference_code;
      if(distance>8388608) distance=distance-16777216;
      if(distance< -8388608) distance=distance+16777216;
      // 18 vectoring iterations: theoretical residual plus integer truncation.
      if(distance>64 || distance< -64) begin
        errors=errors+1;
        $display("CORDIC_MISMATCH x=%0d y=%0d got=%0d ideal=%0d",x,y,angle,reference_code);
      end
      cordic_transactions=cordic_transactions+1;
      @(posedge clk); #1; check("cordic valid pulse",av,0);
    end
  endtask
  initial begin
    for(j=0;j<9;j=j+1) max_model_error[j]=0;
    fd=$fopen("dsp_vectors.txt","r"); fm=$fopen("model_vectors.txt","r");
    fo=$fopen("dsp_comparison.csv","w");
    if(!fd || !fm || !fo) $fatal(1,"Missing vectors: run generate_vectors.py and export_model_vectors first");
    $fdisplay(fo,"transaction,field,rtl_code,matlab_code,difference_lsb");
    while(!$feof(fd)) begin
      count=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",
        row[0],row[1],row[2],row[3],row[4],row[5],row[6],row[7],row[8],row[9],row[10],row[11],row[12],row[13],row[14],row[15],row[16],row[17]);
      if(count!=18) $fatal(1,"Malformed DSP row %0d fields=%0d",cycles,count);
      @(negedge clk); nrst=row[0];adc_valid=row[1];ax=row[2];ay=row[3];fcw=row[4];
      @(posedge clk); #1; cycles=cycles+1;
      check("dsp valid",dv,row[5]);check("nco phase",{32'b0,phase},row[6]);
      check("nco wrap",wrap,row[7]);check("overflow",overflow,row[17]);
      actual[0]=$signed(cx);actual[1]=$signed(sx);actual[2]=$signed(cy);actual[3]=$signed(sy);
      actual[4]=$signed(energy);actual[5]=$signed(quad);actual[6]=$signed(r);actual[7]=$signed(s);actual[8]=$signed(l);
      for(j=0;j<9;j=j+1) check(labels[j],actual[j],row[j+8]);
      // Consume expected transactions by scheduled valid, even if DUT drops one.
      if(row[5]) begin
        count=$fscanf(fm,"%d %d %d %d %d %d %d %d %d\n",model[0],model[1],model[2],model[3],model[4],model[5],model[6],model[7],model[8]);
        if(count!=9) $fatal(1,"Missing model transaction %0d",dsp_transactions);
        dsp_transactions=dsp_transactions+1;
        for(j=0;j<9;j=j+1) begin
          $fdisplay(fo,"%0d,%s,%0d,%0d,%0d",dsp_transactions,labels[j],actual[j],model[j],actual[j]-model[j]);
          if(actual[j] !== model[j]) begin
            model_errors=model_errors+1;
            if(model_errors<=9) $display("MODEL_MISMATCH transaction=%0d %s rtl=%0d matlab=%0d",dsp_transactions,labels[j],actual[j],model[j]);
            if(abs_code(actual[j]-model[j])>max_model_error[j]) max_model_error[j]=abs_code(actual[j]-model[j]);
          end
        end
      end
    end
    count=$fscanf(fm,"%d",model[0]);
    if(count==1) $fatal(1,"Unconsumed MATLAB transactions");
    $fclose(fd);$fclose(fm);$fclose(fo);
    @(negedge clk); adc_valid=0;
    fd=$fopen("ctrl_vectors.txt","r"); if(!fd) $fatal(1,"Missing controller vectors");
    while(!$feof(fd)) begin
      count=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",
        row[0],row[1],row[2],row[3],row[4],row[5],row[6],row[7],row[8],row[9],row[10],row[11],row[12],row[13],row[14]);
      if(count!=15) $fatal(1,"Malformed controller vector");
      @(negedge clk);crst=row[0];update=row[1];ctrl=row[2];ce=row[3];cq=row[4];
      kp=row[5];ki=row[6];qkp=row[7];qki=row[8];virt=row[9];
      @(posedge clk);#1;cycles=cycles+1;
      check("controller valid",command_valid,row[10]);check("controller limit",limit_event,row[11]);
      check("energy command",$signed(ecmd),row[12]);check("quad command",$signed(qcmd),row[13]);check("virtual command",$signed(vcmd),row[14]);
      if(row[10]) ctrl_transactions=ctrl_transactions+1;
    end
    $fclose(fd);
    @(negedge clk);update=0;arst=1;
    cordic_case(16777216,0);cordic_case(0,16777216);
    cordic_case(-16777216,0);cordic_case(0,-16777216);
    for(j=0;j<128;j=j+1)
      cordic_case($rtoi(100000000*$cos(j*0.071)), $rtoi(100000000*$sin(j*0.071)));
    // Reset aborts a CORDIC transaction; no stale valid may escape.
    @(negedge clk);start=1;vx=12345678;vy=34567890;
    repeat(5) @(negedge clk);
    arst=0;start=0;@(posedge clk);#1;check("reset abort busy",busy,0);check("reset abort valid",av,0);
    @(negedge clk);arst=1;
    repeat(20) begin @(posedge clk);#1;check("no stale cordic valid",av,0);end
    if(dsp_transactions!=350 || ctrl_transactions<1000 || cordic_transactions!=132) $fatal(1,"Coverage incomplete");
    for(j=0;j<9;j=j+1) $display("MODEL_MAX_ERROR field=%s lsb=%0d",labels[j],max_model_error[j]);
    $display("SCOREBOARD_SUMMARY dsp=%0d controller=%0d cordic=%0d implementation_errors=%0d model_field_mismatches=%0d",dsp_transactions,ctrl_transactions,cordic_transactions,errors,model_errors);
    if(errors) $fatal(1,"Implementation scoreboard FAILED");
    $display("IMPLEMENTATION_SCOREBOARD_PASS");
    if(model_errors) begin
      $display("MATLAB_EQUIVALENCE_FAIL");
      if(!$test$plusargs("IMPLEMENTATION_ONLY")) $fatal(1,"RTL is not bit-equivalent to MATLAB model");
    end else $display("MATLAB_EQUIVALENCE_PASS");
    $finish;
  end
  initial begin #10000000; $fatal(1,"Scoreboard watchdog timeout");end
endmodule
