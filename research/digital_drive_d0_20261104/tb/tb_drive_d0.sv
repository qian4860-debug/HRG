`timescale 1ns/1ps
module tb_drive_d0;
 reg clk=0;always #5 clk=~clk;
 reg [392:0] stimulus;reg [135:0] expected;
 wire rst,cmd_update,cmd_enable,calibration_valid,sample_en;
 wire [31:0] cmd_id,cmd_source_sample,sample_id;
 wire signed [19:0] force_energy,force_quad,force_virtual;
 wire signed [17:0] direction_x,direction_y,carrier_cos,carrier_sin;
 wire [159:0] inverse_drive_matrix;
 assign {rst,cmd_update,cmd_enable,calibration_valid,cmd_id,cmd_source_sample,
 force_energy,force_quad,force_virtual,direction_x,direction_y,inverse_drive_matrix,
 sample_en,sample_id,carrier_cos,carrier_sin}=stimulus;
 wire dac_valid,drive_active,clip_x,clip_y;
 wire signed [17:0] dac_x,dac_y;
 wire [31:0] applied_cmd_id,applied_sample_id,command_age;
 wire [135:0] actual={dac_valid,drive_active,dac_x,dac_y,clip_x,clip_y,applied_cmd_id,applied_sample_id,command_age};
 hrg_wa_drive_d0 dut(.*);
 integer file,trace,rc,rows=0;string vectors;
 initial begin
  stimulus=0;
  vectors="../data/vectors.hex";
  if($test$plusargs("MUTATE"))vectors="../data/vectors_mutated.hex";
  trace=0;
  if(!$test$plusargs("MUTATE"))begin
   trace=$fopen("../evidence/rtl_actual.hex","w");if(trace==0)$fatal(1,"Cannot save actual trace");
  end
  file=$fopen(vectors,"r");if(file==0)$fatal(1,"Cannot open vectors");
  while(!$feof(file))begin
   @(negedge clk);rc=$fscanf(file,"%h %h\n",stimulus,expected);
   if(rc==2)begin
    @(posedge clk);#1;
    if(trace!=0)$fwrite(trace,"%034h\n",actual);
    if(actual!==expected)begin
     $display("D0_MISMATCH row=%0d actual=%h expected=%h",rows,actual,expected);$fatal(1,"scoreboard mismatch");
    end
    rows=rows+1;
   end else if(!$feof(file))$fatal(1,"Malformed vectors");
  end
  $fclose(file);if(trace!=0)$fclose(trace);$display("D0_SCOREBOARD_PASS rows=%0d",rows);$finish;
 end
endmodule
