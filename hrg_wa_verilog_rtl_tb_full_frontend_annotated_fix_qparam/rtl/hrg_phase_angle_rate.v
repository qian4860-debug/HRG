
// ============================================================================
// 详细注释补充说明
// ----------------------------------------------------------------------------
// 本模块完成从 CORDIC phase=4θ 到全角输出角和角速度的转换。
//
// 功能流程：
//   1) phase_valid 有效时进行相位展开，消除 0/2π 回绕；
//   2) 由 4θ 得到 θ，即右移 2 位；
//   3) zero_angle 脉冲在进入 RUN 时记录参考角，实现输出清零；
//   4) 使用 cfg_cbyran_inv_q28 做 Bryan 因子反标度；
//   5) 差分得到速率，再用一阶 IIR 低通抑制角度量化噪声。
// ============================================================================

// ============================================================================
// hrg_phase_angle_rate.v
// ----------------------------------------------------------------------------
// 功能：
//   1. 对 CORDIC 输出的 phi=atan2(S,R) 进行相位展开。
//   2. 根据全角模式关系 phi = 4*theta，得到驻波角 theta。
//   3. 在进入 RUN 状态时建立 theta_ref，使输出角度清零。
//   4. 按 Bryan 因子反推输入转角。
//   5. 对角度差分得到速率，并进行一阶低通滤波。
// 
// 相位单位：
//   phase/angle 均采用 binary-turn，2^32 LSB = 1 turn = 360 deg。
//   angle_out 为 signed 64-bit，单位仍是 binary-turn 扩展格式。
//   rate_out 为 signed Q16.16，单位 deg/s。
// ============================================================================

`timescale 1ns/1ps

module hrg_phase_angle_rate #(
    parameter RATE_SCALE_Q32 = 64'd23592960000   // Fs=1000Hz 时，deg/s Q16 = dturn32 * RATE_SCALE_Q32 / 2^32
)(
    input                   clk,
    input                   rst_n,

    input                   phase_valid,
    input        [31:0]     phi_phase,

    input                   zero_angle,             // 进入 RUN 时拉高 1 拍
    input      signed [31:0] cfg_cbyran_inv_q28,    // 1/cB，Q4.28
    input             [15:0] cfg_rate_lpf_alpha_q16,// 速率低通 alpha，Q0.16

    output reg signed [63:0] phi_ext,
    output reg signed [63:0] theta_ext,
    output reg signed [63:0] angle_out,
    output reg signed [31:0] rate_out,
    output reg               angle_valid,
    output reg               angle_jump
);

    reg                 phase_init;
    reg        [31:0]   phi_prev;
    reg signed [63:0]  theta_ref;
    reg signed [63:0]  angle_prev;

    wire [31:0]         phi_diff_u = phi_phase - phi_prev;
    wire signed [31:0]  phi_diff_s = phi_diff_u;

    wire signed [63:0]  phi_ext_next   = phase_init ? (phi_ext + {{32{phi_diff_s[31]}}, phi_diff_s}) :
                                                      {{32{phi_phase[31]}}, phi_phase};
    wire signed [63:0]  theta_ext_next = phi_ext_next >>> 2;

    wire signed [63:0]  theta_delta = theta_ext_next - theta_ref;

    // 64-bit theta_delta 乘以 32-bit Q4.28 增益，结果为 96-bit。
    wire signed [31:0]  inv_cbyran_q28_s = cfg_cbyran_inv_q28;
    wire signed [95:0]  angle_mul = $signed(theta_delta) * $signed(inv_cbyran_q28_s);
    wire signed [63:0]  angle_calc = -(angle_mul >>> 28);

    wire signed [63:0]  angle_diff = angle_calc - angle_prev;
    wire signed [127:0] rate_mul   = angle_diff * $signed(RATE_SCALE_Q32);
    wire signed [63:0]  rate_raw64 = rate_mul >>> 32;

    wire signed [63:0]  rate_err64 = rate_raw64 - {{32{rate_out[31]}}, rate_out};
    wire signed [80:0]  rate_lpf_mul = rate_err64 * $signed({1'b0, cfg_rate_lpf_alpha_q16});
    wire signed [63:0]  rate_step64 = rate_lpf_mul >>> 16;
    wire signed [63:0]  rate_filt64 = {{32{rate_out[31]}}, rate_out} + rate_step64;

    function signed [31:0] sat32;
        input signed [63:0] v;
        begin
            if (v > 64'sh0000_0000_7fff_ffff)
                sat32 = 32'sh7fff_ffff;
            else if (v < 64'shffff_ffff_8000_0000)
                sat32 = 32'sh8000_0000;
            else
                sat32 = v[31:0];
        end
    endfunction

    // 用于粗略检测异常相位跳变。
    // 对 phi=4theta 而言，正常采样周期内不应接近半周跳变。
    wire large_phase_step = phase_init && (phi_diff_s > 32'sh3000_0000 || phi_diff_s < -32'sh3000_0000);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_init <= 1'b0;
            phi_prev   <= 32'd0;
            phi_ext    <= 64'sd0;
            theta_ext  <= 64'sd0;
            theta_ref  <= 64'sd0;
            angle_out  <= 64'sd0;
            angle_prev <= 64'sd0;
            rate_out   <= 32'sd0;
            angle_valid<= 1'b0;
            angle_jump <= 1'b0;
        end else begin
            angle_valid <= 1'b0;

            if (phase_valid) begin
                phase_init <= 1'b1;
                phi_prev   <= phi_phase;
                phi_ext    <= phi_ext_next;
                theta_ext  <= theta_ext_next;
                angle_valid<= 1'b1;

                if (zero_angle) begin
                    theta_ref  <= theta_ext_next;
                    angle_out  <= 64'sd0;
                    angle_prev <= 64'sd0;
                    rate_out   <= 32'sd0;
                end else begin
                    angle_out  <= angle_calc;
                    angle_prev <= angle_calc;
                    rate_out   <= sat32(rate_filt64);
                end

                if (large_phase_step) begin
                    angle_jump <= 1'b1;
                end
            end
        end
    end

endmodule
