
// ============================================================================
// 详细注释补充说明
// ----------------------------------------------------------------------------
// 本模块是三阶 CIC 低通抽取器，适合在同步混频后从高采样率降到控制率。
//
// 结构：
//   integrator1/2/3 在输入速率上累加；
//   每 DECIM_R 个输入样本取一次积分器输出；
//   comb1/2/3 在抽取后速率上做差分，形成 CIC 响应。
//
// GAIN_SHIFT 用于补偿 CIC 增益，三阶 CIC 增益约为 DECIM_R^3。
// 默认 DECIM_R=64 时增益为 64^3=2^18，因此 GAIN_SHIFT=18。
// ============================================================================

// ============================================================================
// hrg_cic_decimator.v
// ----------------------------------------------------------------------------
// 三阶 CIC 抽取低通滤波器，默认 R=64，M=1，N=3。
//
// 输入格式一般为 Q2.30。CIC 未归一化增益为 R^N。
// 当 DECIM_R=64 且 STAGES=3 时，R^N=2^18，因此 GAIN_SHIFT=18 可以完成归一化。
// ============================================================================

`timescale 1ns/1ps

module hrg_cic_decimator #(
    parameter IN_W       = 32,
    parameter ACC_W      = 64,
    parameter OUT_W      = 32,
    parameter DECIM_R    = 64,
    parameter GAIN_SHIFT = 18
)(
    input                         clk,
    input                         rst_n,
    input                         in_valid,
    input signed [IN_W-1:0]       din,
    output reg                    out_valid,
    output reg signed [OUT_W-1:0] dout
);

    reg [31:0] decim_cnt;

    reg signed [ACC_W-1:0] int0, int1, int2;
    reg signed [ACC_W-1:0] comb_d0, comb_d1, comb_d2;

    reg signed [ACC_W-1:0] n0, n1, n2;
    reg signed [ACC_W-1:0] c0, c1, c2;
    reg signed [ACC_W-1:0] norm;

    function signed [OUT_W-1:0] sat_out;
        input signed [ACC_W-1:0] v;
        begin
            // 当前工程使用 OUT_W=32。保留参数名，比较阈值按 32-bit signed 饱和。
            if (v > 64'sh0000_0000_7fff_ffff)
                sat_out = 32'sh7fff_ffff;
            else if (v < 64'shffff_ffff_8000_0000)
                sat_out = 32'sh8000_0000;
            else
                sat_out = v[OUT_W-1:0];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            decim_cnt <= 32'd0;
            int0 <= {ACC_W{1'b0}};
            int1 <= {ACC_W{1'b0}};
            int2 <= {ACC_W{1'b0}};
            comb_d0 <= {ACC_W{1'b0}};
            comb_d1 <= {ACC_W{1'b0}};
            comb_d2 <= {ACC_W{1'b0}};
            dout <= {OUT_W{1'b0}};
            out_valid <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            if (in_valid) begin
                // 三级积分器。使用 blocking 临时量保证本拍级联关系清晰。
                n0 = int0 + {{(ACC_W-IN_W){din[IN_W-1]}}, din};
                n1 = int1 + n0;
                n2 = int2 + n1;

                int0 <= n0;
                int1 <= n1;
                int2 <= n2;

                if (decim_cnt == DECIM_R-1) begin
                    decim_cnt <= 32'd0;

                    c0 = n2 - comb_d0;
                    c1 = c0 - comb_d1;
                    c2 = c1 - comb_d2;

                    comb_d0 <= n2;
                    comb_d1 <= c0;
                    comb_d2 <= c1;

                    norm = c2 >>> GAIN_SHIFT;
                    dout <= sat_out(norm);
                    out_valid <= 1'b1;
                end else begin
                    decim_cnt <= decim_cnt + 32'd1;
                end
            end
        end
    end

endmodule
