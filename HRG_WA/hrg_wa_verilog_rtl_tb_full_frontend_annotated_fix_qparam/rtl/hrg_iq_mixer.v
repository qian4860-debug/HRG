
// ============================================================================
// 详细注释补充说明
// ----------------------------------------------------------------------------
// 本模块完成同步解调的乘法混频。
//
// 输入：
//   adc_x/adc_y：原始检测信号，signed Q1.15。
//   sin_ref/cos_ref：NCO 参考，signed Q1.15。
//
// 输出：
//   x_i = x*cos_ref，x_q = x*sin_ref
//   y_i = y*cos_ref，y_q = y*sin_ref
// 输出扩展到 DATA_W 位，保留足够动态范围，后续 CIC/FIR 负责低通抽取。
// ============================================================================

// ============================================================================
// hrg_iq_mixer.v
// ----------------------------------------------------------------------------
// 双通道同步 IQ 混频器。
//
// 输入：
//   adc_x, adc_y : signed Q1.15 原始检测采样
//   sin_ref/cos_ref : signed Q1.15 NCO 参考
//
// 输出：
//   x_i = x*cos, x_q = x*sin, y_i = y*cos, y_q = y*sin
//   格式为 signed Q2.30，后级 CIC/FIR 低通后乘 2 得到 Cx/Sx/Cy/Sy。
// ============================================================================

`timescale 1ns/1ps

module hrg_iq_mixer #(
    parameter ADC_W = 16,
    parameter REF_W = 16,
    parameter OUT_W = 32
)(
    input                         clk,
    input                         rst_n,
    input                         in_valid,
    input signed [ADC_W-1:0]      adc_x,
    input signed [ADC_W-1:0]      adc_y,
    input signed [REF_W-1:0]      sin_ref,
    input signed [REF_W-1:0]      cos_ref,
    output reg                    out_valid,
    output reg signed [OUT_W-1:0] x_i,
    output reg signed [OUT_W-1:0] x_q,
    output reg signed [OUT_W-1:0] y_i,
    output reg signed [OUT_W-1:0] y_q
);

    wire signed [ADC_W+REF_W-1:0] x_cos_mul = $signed(adc_x) * $signed(cos_ref);
    wire signed [ADC_W+REF_W-1:0] x_sin_mul = $signed(adc_x) * $signed(sin_ref);
    wire signed [ADC_W+REF_W-1:0] y_cos_mul = $signed(adc_y) * $signed(cos_ref);
    wire signed [ADC_W+REF_W-1:0] y_sin_mul = $signed(adc_y) * $signed(sin_ref);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            x_i <= {OUT_W{1'b0}};
            x_q <= {OUT_W{1'b0}};
            y_i <= {OUT_W{1'b0}};
            y_q <= {OUT_W{1'b0}};
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                x_i <= x_cos_mul[OUT_W-1:0];
                x_q <= x_sin_mul[OUT_W-1:0];
                y_i <= y_cos_mul[OUT_W-1:0];
                y_q <= y_sin_mul[OUT_W-1:0];
            end
        end
    end

endmodule
