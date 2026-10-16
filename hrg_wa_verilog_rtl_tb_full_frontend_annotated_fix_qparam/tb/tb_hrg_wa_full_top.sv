
// ============================================================================
// 详细注释补充说明
// ----------------------------------------------------------------------------
// 本 testbench 验证完整链路：原始 x/y ADC -> 数字前端 -> 控制核心 -> plant。
//
// 验证内容：
//   1) NCO 参考频率是否与 plant 载波一致；
//   2) IQ/CIC/FIR 是否能恢复 Cx/Sx/Cy/Sy；
//   3) E/Q/S/R 是否稳定且满足全角角度关系 atan2(S,R)=4θ；
//   4) PI 控制输出是否闭环维持 E 和 Q；
//   5) angle_out/rate_out 是否跟随输入角速度积分；
//   6) status_word 是否无故障。
//
// 该文件使用 real 变量统计指标和导出 CSV，不参与综合。
// ============================================================================

// ============================================================================
// tb_hrg_wa_full_top.sv
// ----------------------------------------------------------------------------
// 原始采样级 HRG 全角模式完整链路 testbench。
//
// 覆盖链路：
//   raw x/y plant -> NCO -> IQ mixer -> CIC -> FIR -> decimation
//   -> E/Q/S/R calculation -> CORDIC angle -> PI control -> plant
// ============================================================================

`timescale 1ns/1ps

module tb_hrg_wa_full_top;

    localparam integer DATA_W = 32;
    localparam integer FRAC   = 30;
    localparam integer DECIM_R = 64;
    localparam integer CLK_PERIOD = 10;
    localparam integer TOTAL_CTRL_SAMPLES = 60000;
    localparam integer TOTAL_RAW_SAMPLES  = TOTAL_CTRL_SAMPLES * DECIM_R;
    localparam real    RAW_FS_HZ = 64000.0;
    localparam real    CTRL_DT = 0.001;
    localparam real    PI = 3.14159265358979323846;

    reg clk;
    reg rst_n;
    reg cfg_enable;
    reg cfg_clear_fault;
    reg raw_valid;

    wire signed [15:0] adc_x;
    wire signed [15:0] adc_y;
    wire dac_valid;
    wire signed [31:0] dac_fa;
    wire signed [31:0] dac_fq;
    wire signed [63:0] angle_out;
    wire signed [31:0] rate_out;
    wire data_ready;
    wire [1:0] mode;
    wire [31:0] status_word;
    wire eqsr_valid;
    wire signed [31:0] eqsr_e, eqsr_q, eqsr_s, eqsr_r;
    wire signed [31:0] dbg_cx, dbg_sx, dbg_cy, dbg_sy;
    wire signed [15:0] dbg_sin_ref, dbg_cos_ref;

    real sim_t;
    real rate_in_deg_s;
    real input_angle_deg;
    real out_angle_deg;
    real out_rate_deg_s;
    real angle_err;
    real rate_err;
    real angle_err_sum2;
    real rate_err_sum2;
    real max_rate_err;
    integer metric_count;
    integer raw_count;
    integer ctrl_count;
    integer csv_fd;
    real true_E, true_Q, true_theta;

    function signed [31:0] real_to_q30;
        input real v;
        real scaled;
        begin
            if (v > 1.999999999)
                real_to_q30 = 32'sh7fff_ffff;
            else if (v < -2.0)
                real_to_q30 = 32'sh8000_0000;
            else begin
                scaled = v * 1073741824.0;
                real_to_q30 = $rtoi(scaled);
            end
        end
    endfunction

    function real q30_to_real;
        input signed [31:0] v;
        begin
            q30_to_real = $itor(v) / 1073741824.0;
        end
    endfunction

    function real angle_turn64_to_deg;
        input signed [63:0] v;
        begin
            angle_turn64_to_deg = $itor(v) * 360.0 / 4294967296.0;
        end
    endfunction

    function real rate_q16_to_deg_s;
        input signed [31:0] v;
        begin
            rate_q16_to_deg_s = $itor(v) / 65536.0;
        end
    endfunction

    function real input_rate_profile_deg_s;
        input real t;
        begin
            if (t < 5.0)
                input_rate_profile_deg_s = 0.0;
            else if (t < 35.0)
                input_rate_profile_deg_s = 20.0;
            else if (t < 50.0)
                input_rate_profile_deg_s = -10.0;
            else
                input_rate_profile_deg_s = 0.0;
        end
    endfunction

    function bit valid_metric_window;
        input real t;
        begin
            valid_metric_window = (t > 2.0) &&
                                  ((t < 4.90) || (t > 5.20)) &&
                                  ((t < 34.90) || (t > 35.30)) &&
                                  ((t < 49.90) || (t > 50.30));
        end
    endfunction

    // ---------------- 配置参数 ----------------
    wire signed [31:0] cfg_e_set       = real_to_q30(1.0);
    wire signed [31:0] cfg_q_set       = real_to_q30(0.0);
    wire signed [31:0] cfg_kp_e        = real_to_q30(0.080);
    wire signed [31:0] cfg_ki_e        = real_to_q30(0.00025);
    wire signed [31:0] cfg_kp_q        = real_to_q30(0.300);
    wire signed [31:0] cfg_ki_q        = real_to_q30(0.00008);
    wire signed [31:0] cfg_fa_limit    = real_to_q30(0.150);
    wire signed [31:0] cfg_fq_limit    = real_to_q30(0.250);
    wire signed [63:0] cfg_integ_limit = 64'sd128849019;
    wire signed [31:0] cfg_cbyran_inv_q28 = 32'sd894784853;
    wire [15:0]        cfg_rate_lpf_alpha_q16 = 16'd328;
    wire signed [31:0] cfg_lock_e_tol    = real_to_q30(0.150);
    wire signed [31:0] cfg_lock_q_tol    = real_to_q30(0.150);
    wire signed [31:0] cfg_e_fault_low   = real_to_q30(0.300);
    wire signed [31:0] cfg_e_fault_high  = real_to_q30(1.500);
    wire signed [31:0] cfg_q_fault_abs   = real_to_q30(0.300);

    // 64kHz / 8 = 8kHz 参考频率，和 plant 载波一致。
    wire [31:0] cfg_nco_phase_inc    = 32'h2000_0000;
    wire [31:0] cfg_nco_phase_offset = 32'h0000_0000;

    hrg_wa_full_top #(
        .ADC_W(16),
        .DATA_W(DATA_W),
        .FRAC(FRAC),
        .DECIM_R(DECIM_R),
        .CIC_SHIFT(18),
        .LOCK_SAMPLES(1000)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_enable(cfg_enable),
        .cfg_clear_fault(cfg_clear_fault),
        .raw_valid(raw_valid),
        .adc_x(adc_x),
        .adc_y(adc_y),
        .cfg_nco_phase_inc(cfg_nco_phase_inc),
        .cfg_nco_phase_offset(cfg_nco_phase_offset),
        .cfg_e_set(cfg_e_set),
        .cfg_q_set(cfg_q_set),
        .cfg_kp_e(cfg_kp_e),
        .cfg_ki_e(cfg_ki_e),
        .cfg_kp_q(cfg_kp_q),
        .cfg_ki_q(cfg_ki_q),
        .cfg_fa_limit(cfg_fa_limit),
        .cfg_fq_limit(cfg_fq_limit),
        .cfg_integ_limit(cfg_integ_limit),
        .cfg_cbyran_inv_q28(cfg_cbyran_inv_q28),
        .cfg_rate_lpf_alpha_q16(cfg_rate_lpf_alpha_q16),
        .cfg_lock_e_tol(cfg_lock_e_tol),
        .cfg_lock_q_tol(cfg_lock_q_tol),
        .cfg_e_fault_low(cfg_e_fault_low),
        .cfg_e_fault_high(cfg_e_fault_high),
        .cfg_q_fault_abs(cfg_q_fault_abs),
        .dac_valid(dac_valid),
        .dac_fa(dac_fa),
        .dac_fq(dac_fq),
        .angle_out(angle_out),
        .rate_out(rate_out),
        .data_ready(data_ready),
        .mode(mode),
        .status_word(status_word),
        .eqsr_valid(eqsr_valid),
        .eqsr_e(eqsr_e),
        .eqsr_q(eqsr_q),
        .eqsr_s(eqsr_s),
        .eqsr_r(eqsr_r),
        .dbg_cx(dbg_cx),
        .dbg_sx(dbg_sx),
        .dbg_cy(dbg_cy),
        .dbg_sy(dbg_sy),
        .dbg_sin_ref(dbg_sin_ref),
        .dbg_cos_ref(dbg_cos_ref)
    );

    hrg_wa_raw_plant_model #(
        .RAW_FS_HZ(RAW_FS_HZ),
        .CTRL_DT(CTRL_DT),
        .CBRYAN(0.300),
        .DAMP(0.030),
        .DTAU(0.002),
        .DOMEGA(0.015),
        .THETA_TAU(0.200),
        .THETA_OMEGA(-0.150),
        .CARRIER_DIV(8.0)
    ) plant (
        .clk(clk),
        .rst_n(rst_n),
        .raw_valid(raw_valid),
        .ctrl_valid(dac_valid),
        .fa_cmd(dac_fa),
        .fq_cmd(dac_fq),
        .input_rate_deg_s(rate_in_deg_s),
        .adc_x(adc_x),
        .adc_y(adc_y),
        .true_E(true_E),
        .true_Q(true_Q),
        .true_theta_rad(true_theta)
    );

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    always @(posedge clk) begin
        raw_valid <= rst_n;
    end

    initial begin
        rst_n = 1'b0;
        cfg_enable = 1'b0;
        cfg_clear_fault = 1'b0;
        raw_valid = 1'b0;
        raw_count = 0;
        ctrl_count = 0;
        sim_t = 0.0;
        rate_in_deg_s = 0.0;
        input_angle_deg = 0.0;
        angle_err_sum2 = 0.0;
        rate_err_sum2 = 0.0;
        max_rate_err = 0.0;
        metric_count = 0;

        csv_fd = $fopen("tb_hrg_wa_full_output.csv", "w");
        $fwrite(csv_fd, "t,rate_in,input_angle,angle_out,rate_out,angle_err,rate_err,E,Q,S,R,Cx,Sx,Cy,Sy,mode,status,fa,fq\n");

        repeat (20) @(posedge clk);
        rst_n = 1'b1;
        cfg_enable = 1'b1;

        for (raw_count = 0; raw_count < TOTAL_RAW_SAMPLES; raw_count = raw_count + 1) begin
            sim_t = $itor(raw_count) / RAW_FS_HZ;
            rate_in_deg_s = input_rate_profile_deg_s(sim_t);
            @(posedge clk);
        end

        repeat (200) @(posedge clk);

        $display("================ HRG WA FULL RAW-FRONTEND RTL TB ================");
        $display("Final input angle      : %10.3f deg", input_angle_deg);
        $display("Final output angle     : %10.3f deg", out_angle_deg);
        $display("Final angle error      : %10.5f deg", angle_err);
        if (metric_count > 0) begin
            $display("RMS angle error        : %10.5f deg", $sqrt(angle_err_sum2/metric_count));
            $display("RMS rate error         : %10.5f deg/s", $sqrt(rate_err_sum2/metric_count));
        end
        $display("Max rate error window  : %10.5f deg/s", max_rate_err);
        $display("Final E/Q measured     : %10.6f / %10.6f", q30_to_real(eqsr_e), q30_to_real(eqsr_q));
        $display("Final status word      : 0x%08h", status_word);
        $display("Final mode             : %0d", mode);
        $display("===============================================================");
        $fclose(csv_fd);
        $finish;
    end

    always @(posedge clk) begin
        if (eqsr_valid) begin
            ctrl_count <= ctrl_count + 1;
            // 以抽取输出为 1 kHz 控制节拍，积分理想输入角。
            input_angle_deg <= input_angle_deg + rate_in_deg_s * CTRL_DT;
        end

        if (data_ready) begin
            out_angle_deg = angle_turn64_to_deg(angle_out);
            out_rate_deg_s = rate_q16_to_deg_s(rate_out);
            angle_err = out_angle_deg - input_angle_deg;
            rate_err = out_rate_deg_s - rate_in_deg_s;

            if (valid_metric_window(sim_t)) begin
                angle_err_sum2 = angle_err_sum2 + angle_err*angle_err;
                rate_err_sum2 = rate_err_sum2 + rate_err*rate_err;
                metric_count = metric_count + 1;
                if ((rate_err < 0 ? -rate_err : rate_err) > max_rate_err)
                    max_rate_err = (rate_err < 0 ? -rate_err : rate_err);
            end

            $fwrite(csv_fd, "%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%0d,%08h,%f,%f\n",
                    sim_t,
                    rate_in_deg_s,
                    input_angle_deg,
                    out_angle_deg,
                    out_rate_deg_s,
                    angle_err,
                    rate_err,
                    q30_to_real(eqsr_e),
                    q30_to_real(eqsr_q),
                    q30_to_real(eqsr_s),
                    q30_to_real(eqsr_r),
                    q30_to_real(dbg_cx),
                    q30_to_real(dbg_sx),
                    q30_to_real(dbg_cy),
                    q30_to_real(dbg_sy),
                    mode,
                    status_word,
                    q30_to_real(dac_fa),
                    q30_to_real(dac_fq));
        end
    end

endmodule
