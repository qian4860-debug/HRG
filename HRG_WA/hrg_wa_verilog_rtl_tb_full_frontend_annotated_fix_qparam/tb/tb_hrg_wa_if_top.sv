
// ============================================================================
// 详细注释补充说明
// ----------------------------------------------------------------------------
// 本 testbench 验证控制核心 hrg_wa_if_top，输入为 plant 直接生成的 E/Q/S/R。
//
// 目的：
//   在不引入前端解调误差的情况下，单独验证状态机、PI、CORDIC、角度展开和速率输出。
//   该测试可作为完整前端测试前的基础 golden check。
// ============================================================================

// ============================================================================
// tb_hrg_wa_if_top.sv
// ----------------------------------------------------------------------------
// HRG 全角模式 ASIC/FPGA 数字接口 testbench。
// 
// 验证内容：
//   1. 行为级 plant 产生 E/Q/S/R，RTL 闭环输出 fa/fq 反作用于 plant。
//   2. 输入速率：0 -> +20 deg/s -> -10 deg/s -> 0。
//   3. 检查角度输出、速率输出、状态字、能量和正交控制。
//   4. 生成 CSV，便于和 MATLAB golden model 对比。
// ============================================================================

`timescale 1ns/1ps

module tb_hrg_wa_if_top;

    localparam integer DATA_W      = 32;
    localparam integer FRAC        = 30;
    localparam integer CLK_PERIOD  = 20;       // 50 MHz 等效时钟周期，单位 ns
    localparam integer SAMPLE_DIV  = 50;       // 每 50 个 clk 给 1 个 adc_valid
    localparam real    FS_HZ       = 1000.0;   // ADC/控制采样率 1 kHz
    localparam real    DT          = 0.001;
    localparam integer TOTAL_SAMPLES = 60000;  // 60 s
    localparam real    PI          = 3.14159265358979323846;

    reg clk;
    reg rst_n;

    reg cfg_enable;
    reg cfg_clear_fault;

    reg adc_valid;
    reg signed [31:0] adc_e;
    reg signed [31:0] adc_q;
    reg signed [31:0] adc_s;
    reg signed [31:0] adc_r;

    wire dac_valid;
    wire signed [31:0] dac_fa;
    wire signed [31:0] dac_fq;
    wire signed [63:0] angle_out;
    wire signed [31:0] rate_out;
    wire data_ready;
    wire [1:0] mode;
    wire [31:0] status_word;

    // ---------------- 辅助函数要先声明，供配置常量使用 ----------------
    function signed [31:0] real_to_q30;
        input real v;
        real scaled;
        begin
            if (v > 1.999999999) begin
                real_to_q30 = 32'sh7fff_ffff;
            end else if (v < -2.0) begin
                real_to_q30 = 32'sh8000_0000;
            end else begin
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

    // ---------------- 配置参数：Q2.30 / Q4.28 ----------------
    wire signed [31:0] cfg_e_set       = real_to_q30(1.0);
    wire signed [31:0] cfg_q_set       = real_to_q30(0.0);

    wire signed [31:0] cfg_kp_e        = real_to_q30(0.080);
    wire signed [31:0] cfg_ki_e        = real_to_q30(0.00025);
    wire signed [31:0] cfg_kp_q        = real_to_q30(0.300);
    wire signed [31:0] cfg_ki_q        = real_to_q30(0.00008);

    wire signed [31:0] cfg_fa_limit    = real_to_q30(0.150);
    wire signed [31:0] cfg_fq_limit    = real_to_q30(0.250);
    wire signed [63:0] cfg_integ_limit = 64'sd128849019; // 0.15 in Q2.30

    wire signed [31:0] cfg_cbyran_inv_q28 = 32'sd894784853; // 1/0.3 * 2^28
    wire [15:0]        cfg_rate_lpf_alpha_q16 = 16'd328;    // 0.005*2^16

    wire signed [31:0] cfg_lock_e_tol    = real_to_q30(0.050);
    wire signed [31:0] cfg_lock_q_tol    = real_to_q30(0.050);
    wire signed [31:0] cfg_e_fault_low   = real_to_q30(0.500);
    wire signed [31:0] cfg_e_fault_high  = real_to_q30(1.300);
    wire signed [31:0] cfg_q_fault_abs   = real_to_q30(0.200);

    // ---------------- DUT ----------------
    hrg_wa_if_top #(
        .DATA_W(DATA_W),
        .FRAC(FRAC),
        .LOCK_SAMPLES(1000)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .cfg_enable(cfg_enable),
        .cfg_clear_fault(cfg_clear_fault),

        .adc_valid(adc_valid),
        .adc_e(adc_e),
        .adc_q(adc_q),
        .adc_s(adc_s),
        .adc_r(adc_r),

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
        .status_word(status_word)
    );

    // 行为级 plant 实例。该模块使用 real，不可综合。
    hrg_wa_plant_model plant();

    // ---------------- 仿真变量 ----------------
    integer n;
    integer fd;
    integer metric_count;

    real t_s;
    real input_rate_deg_s;
    real input_rate_rad_s;
    real input_angle_deg;

    real E_real;
    real Q_real;
    real S_real;
    real R_real;
    real fa_real;
    real fq_real;

    real dut_angle_deg;
    real dut_rate_deg_s;
    real angle_err;
    real rate_err;
    real sum_angle_err2;
    real sum_rate_err2;
    real max_abs_rate_err;
    real final_angle_err;
    real rms_angle_err;
    real rms_rate_err;

    // ---------------- 时钟 ----------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // ---------------- 主测试流程 ----------------
    initial begin
        rst_n           = 1'b0;
        cfg_enable      = 1'b0;
        cfg_clear_fault = 1'b0;
        adc_valid       = 1'b0;
        adc_e           = 32'sd0;
        adc_q           = 32'sd0;
        adc_s           = 32'sd0;
        adc_r           = 32'sd0;

        input_angle_deg = 0.0;
        sum_angle_err2  = 0.0;
        sum_rate_err2   = 0.0;
        max_abs_rate_err= 0.0;
        metric_count    = 0;

        fd = $fopen("tb_hrg_wa_if_output.csv", "w");
        $fwrite(fd, "t_s,input_angle_deg,dut_angle_deg,input_rate_deg_s,dut_rate_deg_s,E,Q,fa,fq,status,mode\n");

        repeat (20) @(posedge clk);
        rst_n      = 1'b1;
        cfg_enable = 1'b1;

        for (n = 0; n < TOTAL_SAMPLES; n = n + 1) begin
            t_s = n / FS_HZ;

            input_rate_deg_s = input_rate_profile_deg_s(t_s);
            input_rate_rad_s = input_rate_deg_s * PI / 180.0;
            input_angle_deg  = input_angle_deg + input_rate_deg_s * DT;

            fa_real = q30_to_real(dac_fa);
            fq_real = q30_to_real(dac_fq);

            // 先用上一拍控制量推进 plant，再采集新的 E/Q/S/R。
            plant.step(DT, input_rate_rad_s, fa_real, fq_real);
            plant.get_eqsr(E_real, Q_real, S_real, R_real);

            // 加入很小的确定性抖动，模拟 ADC/AFE 噪声。
            S_real = S_real + (($random % 1000) / 1000.0) * 2.0e-5;
            R_real = R_real + (($random % 1000) / 1000.0) * 2.0e-5;
            E_real = E_real + (($random % 1000) / 1000.0) * 1.0e-5;
            Q_real = Q_real + (($random % 1000) / 1000.0) * 1.0e-5;

            repeat (SAMPLE_DIV-1) @(posedge clk);
            adc_e     <= real_to_q30(E_real);
            adc_q     <= real_to_q30(Q_real);
            adc_s     <= real_to_q30(S_real);
            adc_r     <= real_to_q30(R_real);
            adc_valid <= 1'b1;
            @(posedge clk);
            adc_valid <= 1'b0;

            if (data_ready) begin
                dut_angle_deg  = angle_turn64_to_deg(angle_out);
                dut_rate_deg_s = rate_q16_to_deg_s(rate_out);
                angle_err      = dut_angle_deg - input_angle_deg;
                rate_err       = dut_rate_deg_s - input_rate_deg_s;

                $fwrite(fd, "%f,%f,%f,%f,%f,%f,%f,%f,%f,%0h,%0d\n",
                        t_s, input_angle_deg, dut_angle_deg,
                        input_rate_deg_s, dut_rate_deg_s,
                        E_real, Q_real, fa_real, fq_real,
                        status_word, mode);

                if (valid_metric_window(t_s) && mode == 2'd3) begin
                    sum_angle_err2 = sum_angle_err2 + angle_err*angle_err;
                    sum_rate_err2  = sum_rate_err2  + rate_err*rate_err;
                    if (rate_err < 0.0) begin
                        if (-rate_err > max_abs_rate_err) max_abs_rate_err = -rate_err;
                    end else begin
                        if (rate_err > max_abs_rate_err) max_abs_rate_err = rate_err;
                    end
                    metric_count = metric_count + 1;
                end

                final_angle_err = angle_err;
            end
        end

        repeat (200) @(posedge clk);
        $fclose(fd);

        if (metric_count > 0) begin
            rms_angle_err = $sqrt(sum_angle_err2 / metric_count);
            rms_rate_err  = $sqrt(sum_rate_err2  / metric_count);
        end else begin
            rms_angle_err = 999.0;
            rms_rate_err  = 999.0;
        end

        $display("============================================================");
        $display("HRG WA ASIC/FPGA RTL testbench finished");
        $display("Final input angle      = %f deg", input_angle_deg);
        $display("Final DUT angle        = %f deg", dut_angle_deg);
        $display("Final angle error      = %f deg", final_angle_err);
        $display("RMS angle error        = %f deg", rms_angle_err);
        $display("RMS rate error         = %f deg/s", rms_rate_err);
        $display("Max abs rate error     = %f deg/s", max_abs_rate_err);
        $display("Final status_word      = 0x%08h", status_word);
        $display("Final mode             = %0d", mode);
        $display("CSV output             = tb_hrg_wa_if_output.csv");
        $display("============================================================");

        if ((mode == 2'd3) &&
            (status_word[7:2] == 6'b0) &&
            (rms_angle_err < 2.0) &&
            (rms_rate_err  < 0.5)) begin
            $display("TEST PASS");
        end else begin
            $display("TEST FAIL");
        end

        $finish;
    end

endmodule
