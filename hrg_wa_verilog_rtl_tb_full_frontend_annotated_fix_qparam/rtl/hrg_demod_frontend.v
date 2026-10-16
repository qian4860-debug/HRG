
// ============================================================================
// 详细注释补充说明
// ----------------------------------------------------------------------------
// 本模块实现 HRG 检测链路的数字解调前端，输入为载波级 x/y 原始 ADC。
//
// 同步解调数学关系：
//   Cx = LPF(2*x*cos_ref)，Sx = LPF(2*x*sin_ref)
//   Cy = LPF(2*y*cos_ref)，Sy = LPF(2*y*sin_ref)
//   E  = Cx^2 + Sx^2 + Cy^2 + Sy^2
//   Q  = 2*(Cx*Sy - Cy*Sx)
//   R  = Cx^2 + Sx^2 - Cy^2 - Sy^2
//   S  = 2*(Cx*Cy + Sx*Sy)
//
// 结构说明：
//   1) NCO 产生与谐振载波同频的 sin/cos 参考；
//   2) IQ mixer 完成 x/y 与 sin/cos 的乘法混频；
//   3) CIC 完成大倍率抽取和第一级低通；
//   4) FIR5 进一步平滑解调后的基带慢变量；
//   5) sat_shl1 对 LPF 平均因子进行 2 倍幅值补偿；
//   6) hrg_eqsr_calc 输出后级控制所需 E/Q/S/R。
// ============================================================================

// ============================================================================
// hrg_demod_frontend.v
// ----------------------------------------------------------------------------
// HRG 原始 X/Y 采样到 E/Q/S/R 的完整数字解调前端。
//
// 链路：
//   原始 ADC x/y
//   -> NCO sin/cos 参考
//   -> IQ 混频 x*cos, x*sin, y*cos, y*sin
//   -> 三阶 CIC 低通抽取
//   -> 五抽头 FIR 低通
//   -> 乘 2 补偿同步解调的 1/2 平均因子
//   -> E/Q/S/R 计算
//
// 默认 raw_valid 采样率为 64 kHz，DECIM_R=64 后输出 1 kHz 慢变量。
// ============================================================================

`timescale 1ns/1ps

module hrg_demod_frontend #(
    parameter ADC_W      = 16,
    parameter DATA_W     = 32,
    parameter FRAC       = 30,
    parameter DECIM_R    = 64,
    parameter CIC_SHIFT  = 18
)(
    input                         clk,
    input                         rst_n,
    input                         raw_valid,
    input signed [ADC_W-1:0]      adc_x,
    input signed [ADC_W-1:0]      adc_y,
    input        [31:0]           cfg_nco_phase_inc,
    input        [31:0]           cfg_nco_phase_offset,

    output                        eqsr_valid,
    output signed [DATA_W-1:0]    e_out,
    output signed [DATA_W-1:0]    q_out,
    output signed [DATA_W-1:0]    s_out,
    output signed [DATA_W-1:0]    r_out,

    output signed [DATA_W-1:0]    dbg_cx,
    output signed [DATA_W-1:0]    dbg_sx,
    output signed [DATA_W-1:0]    dbg_cy,
    output signed [DATA_W-1:0]    dbg_sy,
    output signed [15:0]          dbg_sin_ref,
    output signed [15:0]          dbg_cos_ref
);

    wire signed [15:0] sin_ref;
    wire signed [15:0] cos_ref;
    wire ref_valid;
    wire [31:0] phase_acc_unused;

    hrg_nco_sincos u_nco (
        .clk(clk),
        .rst_n(rst_n),
        .en(raw_valid),
        .phase_inc(cfg_nco_phase_inc),
        .phase_offset(cfg_nco_phase_offset),
        .sin_ref(sin_ref),
        .cos_ref(cos_ref),
        .ref_valid(ref_valid),
        .phase_acc(phase_acc_unused)
    );

    assign dbg_sin_ref = sin_ref;
    assign dbg_cos_ref = cos_ref;

    wire mix_valid;
    wire signed [DATA_W-1:0] mix_xi, mix_xq, mix_yi, mix_yq;

    hrg_iq_mixer #(
        .ADC_W(ADC_W),
        .REF_W(16),
        .OUT_W(DATA_W)
    ) u_mix (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(ref_valid),
        .adc_x(adc_x),
        .adc_y(adc_y),
        .sin_ref(sin_ref),
        .cos_ref(cos_ref),
        .out_valid(mix_valid),
        .x_i(mix_xi),
        .x_q(mix_xq),
        .y_i(mix_yi),
        .y_q(mix_yq)
    );

    wire cic_v_xi, cic_v_xq, cic_v_yi, cic_v_yq;
    wire signed [DATA_W-1:0] cic_xi, cic_xq, cic_yi, cic_yq;

    hrg_cic_decimator #(.IN_W(DATA_W), .ACC_W(64), .OUT_W(DATA_W), .DECIM_R(DECIM_R), .GAIN_SHIFT(CIC_SHIFT)) u_cic_xi (
        .clk(clk), .rst_n(rst_n), .in_valid(mix_valid), .din(mix_xi), .out_valid(cic_v_xi), .dout(cic_xi));
    hrg_cic_decimator #(.IN_W(DATA_W), .ACC_W(64), .OUT_W(DATA_W), .DECIM_R(DECIM_R), .GAIN_SHIFT(CIC_SHIFT)) u_cic_xq (
        .clk(clk), .rst_n(rst_n), .in_valid(mix_valid), .din(mix_xq), .out_valid(cic_v_xq), .dout(cic_xq));
    hrg_cic_decimator #(.IN_W(DATA_W), .ACC_W(64), .OUT_W(DATA_W), .DECIM_R(DECIM_R), .GAIN_SHIFT(CIC_SHIFT)) u_cic_yi (
        .clk(clk), .rst_n(rst_n), .in_valid(mix_valid), .din(mix_yi), .out_valid(cic_v_yi), .dout(cic_yi));
    hrg_cic_decimator #(.IN_W(DATA_W), .ACC_W(64), .OUT_W(DATA_W), .DECIM_R(DECIM_R), .GAIN_SHIFT(CIC_SHIFT)) u_cic_yq (
        .clk(clk), .rst_n(rst_n), .in_valid(mix_valid), .din(mix_yq), .out_valid(cic_v_yq), .dout(cic_yq));

    wire fir_v_xi, fir_v_xq, fir_v_yi, fir_v_yq;
    wire signed [DATA_W-1:0] fir_xi, fir_xq, fir_yi, fir_yq;

    hrg_fir5_lpf #(.DATA_W(DATA_W)) u_fir_xi (.clk(clk), .rst_n(rst_n), .in_valid(cic_v_xi), .din(cic_xi), .out_valid(fir_v_xi), .dout(fir_xi));
    hrg_fir5_lpf #(.DATA_W(DATA_W)) u_fir_xq (.clk(clk), .rst_n(rst_n), .in_valid(cic_v_xq), .din(cic_xq), .out_valid(fir_v_xq), .dout(fir_xq));
    hrg_fir5_lpf #(.DATA_W(DATA_W)) u_fir_yi (.clk(clk), .rst_n(rst_n), .in_valid(cic_v_yi), .din(cic_yi), .out_valid(fir_v_yi), .dout(fir_yi));
    hrg_fir5_lpf #(.DATA_W(DATA_W)) u_fir_yq (.clk(clk), .rst_n(rst_n), .in_valid(cic_v_yq), .din(cic_yq), .out_valid(fir_v_yq), .dout(fir_yq));

    function signed [DATA_W-1:0] sat_shl1;
        input signed [DATA_W-1:0] v;
        begin
            // 左移 1 位前先判断是否会超出 signed 32-bit 范围。
            if (v > 32'sh3fff_ffff)
                sat_shl1 = 32'sh7fff_ffff;
            else if (v < -32'sh4000_0000)
                sat_shl1 = 32'sh8000_0000;
            else
                sat_shl1 = v <<< 1;
        end
    endfunction

    wire signed [DATA_W-1:0] cx = sat_shl1(fir_xi);
    wire signed [DATA_W-1:0] sx = sat_shl1(fir_xq);
    wire signed [DATA_W-1:0] cy = sat_shl1(fir_yi);
    wire signed [DATA_W-1:0] sy = sat_shl1(fir_yq);

    assign dbg_cx = cx;
    assign dbg_sx = sx;
    assign dbg_cy = cy;
    assign dbg_sy = sy;

    hrg_eqsr_calc #(
        .DATA_W(DATA_W),
        .FRAC(FRAC)
    ) u_eqsr (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(fir_v_xi & fir_v_xq & fir_v_yi & fir_v_yq),
        .cx(cx),
        .sx(sx),
        .cy(cy),
        .sy(sy),
        .out_valid(eqsr_valid),
        .e_out(e_out),
        .q_out(q_out),
        .s_out(s_out),
        .r_out(r_out)
    );

endmodule
