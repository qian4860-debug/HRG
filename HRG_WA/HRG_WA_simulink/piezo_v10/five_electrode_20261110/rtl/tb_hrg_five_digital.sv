`timescale 1ns/1ps
// 使用独立 MATLAB 参考产生的 ADC 转换码和期望值，逐采样检查两个版本。
// 时序及故障标志要求完全一致，数据按 Q24 误差和 DAC 码误差独立统计。
module tb_hrg_five_digital #(
    parameter TDM = 0,
    parameter DAC_DIVISOR = 1
);
    localparam ADC_BITS = TDM ? 10 : 16;
    localparam DAC_BITS = TDM ? 14 : 16;
    localparam SAMPLES = TDM ? 800 : 160;
    localparam FRAME = TDM ? 3200 : 160;
    localparam VALID_END = TDM ? 2800 : 160;
    localparam DAC_TOLERANCE = 4;
    localparam ANGLE_TOLERANCE = 419; // 约 25 µrad
    localparam IQ_TOLERANCE = 336; // 约 20 ppm，归一化单位
    logic clk = 0;
    always #5 clk = ~clk;
    logic reset_n = 0;
    logic signed [ADC_BITS-1:0] adc_x, adc_y;
    logic adc_overrange;
    logic [1023:0] detect_matrix, drive_matrix;
    logic signed [63:0] minimum_energy, minimum_linearity, intrinsic_damping;
    logic signed [63:0] agc_gain, quadrature_gain, angle_scale;
    logic [31:0] seed_ticks = 0;
    logic [255:0] seed_command = 0;
    wire drive_on, sense_on, sample_valid;
    wire signed [DAC_BITS-1:0] dac_x, dac_y;
    wire dac_clip, published, angle_valid, tracking_lost;
    wire signed [63:0] angle, ix, iy, qx, qy;
    hrg_five_digital #(.TDM(TDM),.DAC_DIVISOR(DAC_DIVISOR)) dut (.*);

    string vector_dir, case_name, cfg_path, vec_path;
    integer cfg, vec, fields, tick, slot, i, frame_count, lost_count, dac_clip_count;
    integer rx_x, rx_y, rx_clip, ref_dac_x, ref_dac_y, ref_pub, ref_valid, ref_lost;
    longint signed coeff, ref_angle, ref_ix, ref_iy, ref_qx, ref_qy;
    longint signed max_dac_error, max_angle_error, max_iq_error;
    longint signed err;

    // 各类误差分别报告最大值，避免角度正确时掩盖 DAC 或 I/Q 误差。
    function automatic longint signed magnitude(input longint signed x);
        return x < 0 ? -x : x;
    endfunction

    task automatic check_iq(input longint signed actual, expected);
        longint signed error_value;
        error_value = magnitude(actual-expected);
        if (error_value > max_iq_error) max_iq_error = error_value;
    endtask

    initial begin
        if (!$value$plusargs("vectors=%s",vector_dir)) vector_dir = ".";
        if (!$value$plusargs("case=%s",case_name)) begin
            if (TDM) case_name = "tdm_shared";
            else case_name = "continuous";
        end
        cfg_path = {vector_dir,"/",case_name,".cfg"};
        vec_path = {vector_dir,"/",case_name,".vec"};
        cfg = $fopen(cfg_path,"r");
        vec = $fopen(vec_path,"r");
        if (!cfg || !vec) $fatal(1,"Cannot open %s or %s",cfg_path,vec_path);
        // 配置字和样本列在 MATLAB 导出器中定义，矩阵按行读取。
        for (i=0;i<38;i++) begin
            if ($fscanf(cfg,"%d",coeff) != 1) $fatal(1,"Missing coefficient %0d",i);
            if (i<16) detect_matrix[64*i+:64] = coeff;
            else if (i<32) drive_matrix[64*(i-16)+:64] = coeff;
            else case (i)
                32: minimum_energy = coeff;
                33: minimum_linearity = coeff;
                34: intrinsic_damping = coeff;
                35: agc_gain = coeff;
                36: quadrature_gain = coeff;
                37: angle_scale = coeff;
            endcase
        end
        if ($fscanf(cfg,"%d",coeff) == 1) begin
            seed_ticks = coeff[31:0];
            for (i=0;i<4;i++) begin
                if ($fscanf(cfg,"%d",coeff) != 1) $fatal(1,"Missing seed command %0d",i);
                seed_command[64*i+:64] = coeff;
            end
        end
        $fclose(cfg);
        if ($test$plusargs("vcd")) begin
            $dumpfile("five_digital.vcd");
            $dumpvars(1,tb_hrg_five_digital);
        end
        tick=0; frame_count=0; lost_count=0; dac_clip_count=0;
        max_dac_error=0; max_angle_error=0; max_iq_error=0;
        adc_x=0; adc_y=0; adc_overrange=0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset_n = 1;
        fields = $fscanf(vec,"%d %d %d %d %d %d %d %d %d %d %d %d %d",
            rx_x,rx_y,rx_clip,ref_dac_x,ref_dac_y,ref_pub,ref_valid,ref_lost,
            ref_angle,ref_ix,ref_iy,ref_qx,ref_qy);
        while (fields == 13) begin
            adc_x = rx_x; adc_y = rx_y; adc_overrange = rx_clip[0];
            slot = tick % FRAME;
            #1;
            if (drive_on !== (slot < SAMPLES) ||
                sense_on !== (slot >= (TDM ? 1200 : 0) && slot < VALID_END) ||
                sample_valid !== (slot >= (TDM ? 2000 : 0) && slot < VALID_END))
                $fatal(1,"Electrode switch/sample timing mismatch tick=%0d slot=%0d",tick,slot);
            @(posedge clk);
            #1;
            if (published !== ref_pub[0] || angle_valid !== ref_valid[0] || tracking_lost !== ref_lost[0])
                $fatal(1,"Navigation flags mismatch tick=%0d expected=%0d%0d%0d actual=%b%b%b",
                    tick,ref_pub,ref_valid,ref_lost,published,angle_valid,tracking_lost);
            if ((TDM && slot >= SAMPLES) && (dac_x !== 0 || dac_y !== 0 || dac_clip !== 0))
                $fatal(1,"DAC was active outside drive window at tick=%0d",tick);
            err = magnitude($signed(dac_x)-ref_dac_x);
            if (err > max_dac_error) max_dac_error = err;
            err = magnitude($signed(dac_y)-ref_dac_y);
            if (err > max_dac_error) max_dac_error = err;
            err = magnitude(angle-ref_angle);
            if (err > max_angle_error) max_angle_error = err;
            check_iq(ix,ref_ix); check_iq(iy,ref_iy);
            check_iq(qx,ref_qx); check_iq(qy,ref_qy);
            if (published) frame_count++;
            if (tracking_lost) lost_count++;
            if (dac_clip) dac_clip_count++;
            tick++;
            @(negedge clk);
            fields = $fscanf(vec,"%d %d %d %d %d %d %d %d %d %d %d %d %d",
                rx_x,rx_y,rx_clip,ref_dac_x,ref_dac_y,ref_pub,ref_valid,ref_lost,
                ref_angle,ref_ix,ref_iy,ref_qx,ref_qy);
        end
        if (!(fields == -1 || (fields == 0 && $feof(vec))) || tick < 2*FRAME)
            $fatal(1,"Incomplete vector at tick=%0d fields=%0d",tick,fields);
        $fclose(vec);
        $display("SCORE %s ticks=%0d frames=%0d lost_ticks=%0d dac_clip_ticks=%0d max_dac_codes=%0d max_angle_Q24=%0d max_iq_Q24=%0d",
            case_name,tick,frame_count,lost_count,dac_clip_count,max_dac_error,max_angle_error,max_iq_error);
        if (max_dac_error > DAC_TOLERANCE || max_angle_error > ANGLE_TOLERANCE || max_iq_error > IQ_TOLERANCE)
            $fatal(1,"Fixed-point error exceeds limit");
        $display("PASS %s",case_name);
        $finish;
    end
endmodule
