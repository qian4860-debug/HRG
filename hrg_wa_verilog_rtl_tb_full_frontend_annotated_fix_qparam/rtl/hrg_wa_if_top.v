
// ============================================================================
// 详细注释补充说明
// ----------------------------------------------------------------------------
// 本模块是 HRG 全角模式数字控制核心，输入为已解调好的 E/Q/S/R。
//
// 控制回路：
//   e_err = E_set - E，用于能量 PI，输出 fa；
//   q_err = Q_set - Q，用于正交 PI，输出 fq。
//
// 角度链路：
//   CORDIC 计算 phi=atan2(S,R)，对二阶模态有 phi=4θ；
//   hrg_phase_angle_rate 完成 4θ 展相、RUN 清零、Bryan 因子补偿和速率估计。
//
// 状态机：
//   MODE_IDLE：关闭或复位；
//   MODE_LOCK：等待 E/Q 达到锁定条件并计数；
//   MODE_RUN ：输出有效角度/速率，并锁存运行期故障。
// ============================================================================

// ============================================================================
// hrg_wa_if_top.v
// ----------------------------------------------------------------------------
// 半球谐振陀螺 HRG 全角模式 ASIC/FPGA 数字控制接口顶层。
// 
// 该顶层面向“已完成同步解调后的 E/Q/S/R 数据”。
// 输入：
//   adc_e, adc_q, adc_s, adc_r  均为 signed Q2.30
// 输出：
//   dac_fa, dac_fq              能量环和正交环控制量，signed Q2.30
//   angle_out                   全角模式积分角，signed binary-turn 扩展格式
//   rate_out                    角速度，signed Q16.16 deg/s
//
// 主要功能：
//   1. 状态机：IDLE -> LOCK -> RUN
//   2. E 能量 PI 闭环
//   3. Q 正交 PI 闭环
//   4. CORDIC atan2(S,R)
//   5. 4theta 相位展开
//   6. RUN 状态输出清零与角度积分
//   7. 状态字与故障标志
//
// 状态字 status_word：
//   bit0  data_ready
//   bit1  locked/RUN
//   bit2  ADC saturation sticky
//   bit3  DAC saturation sticky
//   bit4  fixed-point saturation sticky
//   bit5  angle jump sticky
//   bit6  E fault sticky
//   bit7  Q fault sticky
// ============================================================================

`timescale 1ns/1ps

module hrg_wa_if_top #(
    parameter DATA_W = 32,
    parameter FRAC   = 30,
    parameter LOCK_SAMPLES = 1000,
    parameter signed [DATA_W-1:0] ADC_SAT_POS = 32'sh7fff_ffff,
    parameter signed [DATA_W-1:0] ADC_SAT_NEG = 32'sh8000_0000
)(
    input                         clk,
    input                         rst_n,

    input                         cfg_enable,
    input                         cfg_clear_fault,

    input                         adc_valid,
    input signed [DATA_W-1:0]     adc_e,
    input signed [DATA_W-1:0]     adc_q,
    input signed [DATA_W-1:0]     adc_s,
    input signed [DATA_W-1:0]     adc_r,

    input signed [DATA_W-1:0]     cfg_e_set,
    input signed [DATA_W-1:0]     cfg_q_set,

    input signed [DATA_W-1:0]     cfg_kp_e,
    input signed [DATA_W-1:0]     cfg_ki_e,
    input signed [DATA_W-1:0]     cfg_kp_q,
    input signed [DATA_W-1:0]     cfg_ki_q,

    input signed [DATA_W-1:0]     cfg_fa_limit,
    input signed [DATA_W-1:0]     cfg_fq_limit,
    input signed [63:0]           cfg_integ_limit,

    input signed [31:0]           cfg_cbyran_inv_q28,
    input        [15:0]           cfg_rate_lpf_alpha_q16,

    input signed [DATA_W-1:0]     cfg_lock_e_tol,
    input signed [DATA_W-1:0]     cfg_lock_q_tol,
    input signed [DATA_W-1:0]     cfg_e_fault_low,
    input signed [DATA_W-1:0]     cfg_e_fault_high,
    input signed [DATA_W-1:0]     cfg_q_fault_abs,

    output                        dac_valid,
    output signed [DATA_W-1:0]    dac_fa,
    output signed [DATA_W-1:0]    dac_fq,

    output signed [63:0]          angle_out,
    output signed [31:0]          rate_out,
    output                        data_ready,

    output reg [1:0]              mode,
    output reg [31:0]             status_word
);

    localparam MODE_IDLE = 2'd1;
    localparam MODE_LOCK = 2'd2;
    localparam MODE_RUN  = 2'd3;

    function signed [DATA_W-1:0] abs32;
        input signed [DATA_W-1:0] v;
        begin
            abs32 = v[DATA_W-1] ? -v : v;
        end
    endfunction

    wire signed [DATA_W-1:0] e_err = cfg_e_set - adc_e;
    wire signed [DATA_W-1:0] q_err = cfg_q_set - adc_q;

    wire e_good = (abs32(e_err) < cfg_lock_e_tol);
    wire q_good = (abs32(adc_q) < cfg_lock_q_tol);

    wire e_fault_now = (adc_e < cfg_e_fault_low) || (adc_e > cfg_e_fault_high);
    wire q_fault_now = (abs32(adc_q) > cfg_q_fault_abs);

    wire adc_sat_now = (adc_e == ADC_SAT_POS) || (adc_e == ADC_SAT_NEG) ||
                       (adc_q == ADC_SAT_POS) || (adc_q == ADC_SAT_NEG) ||
                       (adc_s == ADC_SAT_POS) || (adc_s == ADC_SAT_NEG) ||
                       (adc_r == ADC_SAT_POS) || (adc_r == ADC_SAT_NEG);

    reg [31:0] lock_cnt;
    reg        zero_angle_pulse;

    // ------------------------------------------------------------------------
    // PI 控制器
    // ------------------------------------------------------------------------
    wire signed [DATA_W-1:0] fa_pi;
    wire signed [DATA_W-1:0] fq_pi;
    wire signed [63:0]       integ_e;
    wire signed [63:0]       integ_q;
    wire                     fa_sat;
    wire                     fq_sat;

    // LOCK -> RUN 时会产生 zero_angle_pulse。该时刻同时清除 PI 积分器，
    // 避免 LOCK 阶段启动瞬态把正交环积分器推到限幅，导致进入 RUN 后 fq_sat 常高。
    wire                     pi_clear = (!cfg_enable) || zero_angle_pulse;

    hrg_pi_ctrl #(
        .DATA_W(DATA_W),
        .GAIN_W(DATA_W),
        .ACC_W(64),
        .FRAC(FRAC)
    ) u_pi_e (
        .clk(clk),
        .rst_n(rst_n),
        .en(adc_valid && cfg_enable),
        .clear(pi_clear),
        .err(e_err),
        .kp(cfg_kp_e),
        .ki(cfg_ki_e),
        .out_limit(cfg_fa_limit),
        .integ_limit(cfg_integ_limit),
        .out(fa_pi),
        .integ(integ_e),
        .sat(fa_sat)
    );

    hrg_pi_ctrl #(
        .DATA_W(DATA_W),
        .GAIN_W(DATA_W),
        .ACC_W(64),
        .FRAC(FRAC)
    ) u_pi_q (
        .clk(clk),
        .rst_n(rst_n),
        .en(adc_valid && cfg_enable),
        .clear(pi_clear),
        .err(q_err),
        .kp(cfg_kp_q),
        .ki(cfg_ki_q),
        .out_limit(cfg_fq_limit),
        .integ_limit(cfg_integ_limit),
        .out(fq_pi),
        .integ(integ_q),
        .sat(fq_sat)
    );

    assign dac_fa    = fa_pi;
    assign dac_fq    = fq_pi;
    assign dac_valid = adc_valid && (mode != MODE_IDLE);

    // ------------------------------------------------------------------------
    // CORDIC angle calculation
    // ------------------------------------------------------------------------
    wire cordic_busy;
    wire cordic_valid;
    wire [31:0] phi_phase;

    // S/R 向量有效性判断，避免 atan2(0,0) 引起随机角。
    wire vector_ok = (abs32(adc_s) > 32'sd1024) || (abs32(adc_r) > 32'sd1024);
    wire cordic_start = adc_valid && vector_ok && !cordic_busy && cfg_enable;

    hrg_cordic_atan2 u_cordic (
        .clk(clk),
        .rst_n(rst_n),
        .start(cordic_start),
        .x_in(adc_r),
        .y_in(adc_s),
        .busy(cordic_busy),
        .valid(cordic_valid),
        .phase(phi_phase)
    );

    wire signed [63:0] phi_ext_dbg;
    wire signed [63:0] theta_ext_dbg;
    wire angle_valid;
    wire angle_jump;

    hrg_phase_angle_rate u_phase (
        .clk(clk),
        .rst_n(rst_n),
        .phase_valid(cordic_valid),
        .phi_phase(phi_phase),
        .zero_angle(zero_angle_pulse),
        .cfg_cbyran_inv_q28(cfg_cbyran_inv_q28),
        .cfg_rate_lpf_alpha_q16(cfg_rate_lpf_alpha_q16),
        .phi_ext(phi_ext_dbg),
        .theta_ext(theta_ext_dbg),
        .angle_out(angle_out),
        .rate_out(rate_out),
        .angle_valid(angle_valid),
        .angle_jump(angle_jump)
    );

    assign data_ready = angle_valid;

    // ------------------------------------------------------------------------
    // 状态机与 sticky fault
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode             <= MODE_IDLE;
            lock_cnt         <= 32'd0;
            zero_angle_pulse <= 1'b0;
            status_word      <= 32'd0;
        end else begin
            zero_angle_pulse <= 1'b0;

            if (cfg_clear_fault) begin
                status_word[31:2] <= 30'd0;
            end

            if (!cfg_enable) begin
                mode      <= MODE_IDLE;
                lock_cnt  <= 32'd0;
                status_word[1:0] <= 2'b00;
            end else begin
                case (mode)
                    MODE_IDLE: begin
                        mode     <= MODE_LOCK;
                        lock_cnt <= 32'd0;
                    end

                    MODE_LOCK: begin
                        if (adc_valid) begin
                            if (e_good && q_good) begin
                                if (lock_cnt >= LOCK_SAMPLES-1) begin
                                    mode             <= MODE_RUN;
                                    zero_angle_pulse <= 1'b1;
                                    lock_cnt         <= 32'd0;
                                end else begin
                                    lock_cnt <= lock_cnt + 32'd1;
                                end
                            end else begin
                                lock_cnt <= 32'd0;
                            end
                        end
                    end

                    MODE_RUN: begin
                        mode <= MODE_RUN;
                    end

                    default: begin
                        mode <= MODE_IDLE;
                    end
                endcase

                status_word[0] <= angle_valid;
                status_word[1] <= (mode == MODE_RUN);

                // sticky fault 只在 RUN 状态下锁存，避免启动瞬态污染最终状态。
                if (mode == MODE_RUN) begin
                    if (adc_sat_now)          status_word[2] <= 1'b1;
                    if (fa_sat || fq_sat)     status_word[3] <= 1'b1;
                    if (angle_jump)           status_word[5] <= 1'b1;
                    if (e_fault_now)          status_word[6] <= 1'b1;
                    if (q_fault_now)          status_word[7] <= 1'b1;
                end
            end
        end
    end

endmodule
