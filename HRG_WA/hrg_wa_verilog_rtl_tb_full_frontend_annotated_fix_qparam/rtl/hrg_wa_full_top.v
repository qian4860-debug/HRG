
// ============================================================================
// 详细注释补充说明
// ----------------------------------------------------------------------------
// 本模块是“原始 ADC -> 全角模式数字控制”的完整 RTL 顶层。
// 端口和模块名保持不变；本次只增加注释，不改动综合逻辑。
//
// 数据流：
//   raw_valid/adc_x/adc_y
//      -> u_frontend：NCO、IQ 混频、CIC、FIR、E/Q/S/R 计算
//      -> u_core：能量 PI、正交 PI、CORDIC、4θ 展相、角度/速率输出
//
// 时钟约定：
//   clk 为系统采样时钟；raw_valid 表示当前拍 adc_x/adc_y 有效。
//   eqsr_valid 是抽取后的慢变量有效脉冲，默认 64 kHz / 64 = 1 kHz。
//
// 定点格式：
//   adc_x/adc_y：signed Q1.15。
//   E/Q/S/R 与控制量：signed Q2.30。
//   angle_out：binary-turn 扩展格式，2^32 对应 360°。
//   rate_out：signed Q16.16，单位 deg/s。
// ============================================================================

// ============================================================================
// hrg_wa_full_top.v
// ----------------------------------------------------------------------------
// HRG 全角模式完整数字链路顶层。
//
// 与 hrg_wa_if_top 的区别：
//   hrg_wa_if_top 输入是已经解调好的 E/Q/S/R；
//   hrg_wa_full_top 输入是原始 X/Y ADC 采样，并在内部完成：
//     NCO -> sin/cos -> IQ 混频 -> CIC/FIR -> 抽取 -> E/Q/S/R -> 控制接口。
//
// 默认配置：raw ADC 采样率 64 kHz，DECIM_R=64，控制/EQSR 更新率 1 kHz。
// ============================================================================

`timescale 1ns/1ps

module hrg_wa_full_top #(
    parameter ADC_W      = 16,
    parameter DATA_W     = 32,
    parameter FRAC       = 30,
    parameter DECIM_R    = 64,
    parameter CIC_SHIFT  = 18,
    parameter LOCK_SAMPLES = 1000
)(
    input                         clk,
    input                         rst_n,

    input                         cfg_enable,
    input                         cfg_clear_fault,

    // 原始检测 ADC 输入，signed Q1.15。
    input                         raw_valid,
    input signed [ADC_W-1:0]      adc_x,
    input signed [ADC_W-1:0]      adc_y,

    // NCO 配置。64 kHz 采样、8 kHz 参考时 phase_inc = 2^32/8 = 0x2000_0000。
    input        [31:0]           cfg_nco_phase_inc,
    input        [31:0]           cfg_nco_phase_offset,

    // 控制参数，与 hrg_wa_if_top 保持一致。
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
    output [1:0]                  mode,
    output [31:0]                 status_word,

    // 调试观测量。
    output                        eqsr_valid,
    output signed [DATA_W-1:0]    eqsr_e,
    output signed [DATA_W-1:0]    eqsr_q,
    output signed [DATA_W-1:0]    eqsr_s,
    output signed [DATA_W-1:0]    eqsr_r,
    output signed [DATA_W-1:0]    dbg_cx,
    output signed [DATA_W-1:0]    dbg_sx,
    output signed [DATA_W-1:0]    dbg_cy,
    output signed [DATA_W-1:0]    dbg_sy,
    output signed [15:0]          dbg_sin_ref,
    output signed [15:0]          dbg_cos_ref
);

    hrg_demod_frontend #(
        .ADC_W(ADC_W),
        .DATA_W(DATA_W),
        .FRAC(FRAC),
        .DECIM_R(DECIM_R),
        .CIC_SHIFT(CIC_SHIFT)
    ) u_frontend (
        .clk(clk),
        .rst_n(rst_n),
        .raw_valid(raw_valid),
        .adc_x(adc_x),
        .adc_y(adc_y),
        .cfg_nco_phase_inc(cfg_nco_phase_inc),
        .cfg_nco_phase_offset(cfg_nco_phase_offset),
        .eqsr_valid(eqsr_valid),
        .e_out(eqsr_e),
        .q_out(eqsr_q),
        .s_out(eqsr_s),
        .r_out(eqsr_r),
        .dbg_cx(dbg_cx),
        .dbg_sx(dbg_sx),
        .dbg_cy(dbg_cy),
        .dbg_sy(dbg_sy),
        .dbg_sin_ref(dbg_sin_ref),
        .dbg_cos_ref(dbg_cos_ref)
    );

    hrg_wa_if_top #(
        .DATA_W(DATA_W),
        .FRAC(FRAC),
        .LOCK_SAMPLES(LOCK_SAMPLES)
    ) u_core (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_enable(cfg_enable),
        .cfg_clear_fault(cfg_clear_fault),
        .adc_valid(eqsr_valid),
        .adc_e(eqsr_e),
        .adc_q(eqsr_q),
        .adc_s(eqsr_s),
        .adc_r(eqsr_r),
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

endmodule
