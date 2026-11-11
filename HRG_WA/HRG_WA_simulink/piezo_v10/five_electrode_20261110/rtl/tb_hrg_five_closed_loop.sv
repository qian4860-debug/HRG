`timescale 1ns/1ps
// 五电极 RTL 闭环记分板：数字核驱动实时机电模型，.vec 仅作角度与事件真值。
// 默认连续模式。TDM=1 可验证分时复用和分时不复用，后者使用 18 状态机电矩阵。
module tb_hrg_five_closed_loop #(
    parameter TDM=0,
    parameter DAC_DIVISOR=1,
    parameter integer PLANT_STATES=26
);
    localparam AB=TDM ? 10 : 16;
    localparam DB=TDM ? 14 : 16;
    localparam real Q24=16777216.0;
    reg clk=0, reset_n=0;
    reg signed [AB-1:0] adc_x=0, adc_y=0;
    reg adc_overrange=0;
    reg [1023:0] detect_matrix=0, drive_matrix=0;
    reg signed [63:0] coefficient [0:37];
    wire drive_on, sense_on, sample_valid;
    wire signed [DB-1:0] dac_x, dac_y;
    wire dac_clip, published, angle_valid, tracking_lost;
    wire signed [63:0] angle;
    hrg_five_digital #(.TDM(TDM),.DAC_DIVISOR(DAC_DIVISOR)) dut (
        .clk(clk), .reset_n(reset_n), .adc_x(adc_x), .adc_y(adc_y),
        .adc_overrange(adc_overrange), .detect_matrix(detect_matrix), .drive_matrix(drive_matrix),
        .minimum_energy(coefficient[32]), .minimum_linearity(coefficient[33]),
        .intrinsic_damping(coefficient[34]), .agc_gain(coefficient[35]),
        .quadrature_gain(coefficient[36]), .angle_scale(coefficient[37]),
        .seed_ticks(32'd0), .seed_command(256'd0), .drive_on(drive_on), .sense_on(sense_on),
        .sample_valid(sample_valid), .dac_x(dac_x), .dac_y(dac_y), .dac_clip(dac_clip),
        .published(published), .angle_valid(angle_valid), .tracking_lost(tracking_lost),
        .angle(angle), .ix(), .iy(), .qx(), .qy()
    );
    hrg_five_analog_plant #(.N(PLANT_STATES)) plant();

    string directory, scenario;
    integer config_file, vector_file, scanned, row, tick, frames, first_tick, failures;
    integer x, y, adc_clip_ticks, startup_dac_clip_ticks, steady_dac_clip_ticks;
    logic drive, sense, clip;
    longint signed reference [0:12];
    real measured, expected, delta, max_delta, first_angle, truth, square_error;

    function automatic real magnitude(input real value);
        magnitude = value < 0.0 ? -value : value;
    endfunction

    initial begin
        if (!$value$plusargs("dir=%s",directory)) directory=".";
        if (!$value$plusargs("case=%s",scenario))
            scenario=TDM ? (DAC_DIVISOR==25 ? "tdm_shared_div25" : "tdm_shared") : "continuous";
        plant.read_model({directory,"/",scenario,".plant"});
        config_file=$fopen({directory,"/",scenario,".cfg"},"r");
        vector_file=$fopen({directory,"/",scenario,".vec"},"r");
        if (!config_file || !vector_file) $fatal(1,"Missing config or vectors for %s",scenario);
        for (row=0; row<38; row=row+1)
            if ($fscanf(config_file,"%d",coefficient[row])!=1)
                $fatal(1,"Missing fixed-point coefficient %d",row);
        $fclose(config_file);
        for (row=0; row<16; row=row+1) begin
            detect_matrix[64*row+:64]=coefficient[row];
            drive_matrix[64*row+:64]=coefficient[16+row];
        end
        #1 clk=1; #1 clk=0; reset_n=1; #1;
        tick=0; frames=0; failures=0; max_delta=0.0; square_error=0.0;
        adc_clip_ticks=0; startup_dac_clip_ticks=0; steady_dac_clip_ticks=0;

        // 采样使用当前门控和旧状态。时钟沿后读取本拍 DAC 并推进表头。
        while (!$feof(vector_file)) begin
            scanned=$fscanf(vector_file,"%d %d %d %d %d %d %d %d %d %d %d %d %d",
                reference[0],reference[1],reference[2],reference[3],reference[4],reference[5],
                reference[6],reference[7],reference[8],reference[9],reference[10],reference[11],reference[12]);
            if (scanned==13) begin
                drive=drive_on;
                sense=sense_on;
                plant.acquire(sample_valid,x,y,clip);
                adc_x=x;
                adc_y=y;
                adc_overrange=clip;
                #1 clk=1;
                #1;
                if (clip) adc_clip_ticks=adc_clip_ticks+1;
                if (dac_clip) begin
                    if (tick*plant.sample_period < 0.002)
                        startup_dac_clip_ticks=startup_dac_clip_ticks+1;
                    else steady_dac_clip_ticks=steady_dac_clip_ticks+1;
                end
                if ({published,angle_valid,tracking_lost} !==
                        {reference[5][0],reference[6][0],reference[7][0]})
                    failures=failures+1;
                if (published) begin
                    measured=real'(angle)/Q24;
                    expected=real'(reference[8])/Q24;
                    delta=magnitude(measured-expected);
                    if (delta>max_delta) max_delta=delta;
                    if (frames==0) begin
                        first_tick=tick;
                        first_angle=measured;
                    end
                    truth=plant.rotation_rate*(tick-first_tick)*plant.sample_period;
                    square_error=square_error+(measured-first_angle-truth)**2.0;
                    frames=frames+1;
                end
                plant.advance(drive,sense,$signed(dac_x),$signed(dac_y));
                tick=tick+1;
                clk=0;
                #1;
            end else if (!$feof(vector_file) || scanned > 0)
                $fatal(1,"Malformed vector at tick %d",tick);
        end
        $fclose(vector_file);
        if (frames<5) $fatal(1,"Insufficient closed-loop coverage, %d frames",frames);
        $display("CLOSED_LOOP %s ticks=%0d frames=%0d event_mismatches=%0d max_vs_MATLAB_rad=%.9g truth_RMS_rad=%.9g ADC_clip=%0d DAC_start=%0d DAC_steady=%0d",
            scenario,tick,frames,failures,max_delta,$sqrt(square_error/frames),
            adc_clip_ticks,startup_dac_clip_ticks,steady_dac_clip_ticks);
        // 本项是功能筛查。1 mrad 是定点闭环与同工况 MATLAB 的暂定差异上限。
        if (failures || max_delta>0.001 || adc_clip_ticks || steady_dac_clip_ticks)
            $fatal(1,"Closed-loop scoreboard failed");
        $display("CLOSED_LOOP PASS %s",scenario);
        $finish;
    end
endmodule
