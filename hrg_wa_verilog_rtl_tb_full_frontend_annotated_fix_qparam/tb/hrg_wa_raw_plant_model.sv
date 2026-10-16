
// ============================================================================
// 详细注释补充说明
// ----------------------------------------------------------------------------
// 本文件是原始载波级 HRG plant 行为模型，不参与综合。
//
// 输出关系：
//   x = a*cos(2θ)*cos(ψ) - q*sin(2θ)*sin(ψ)
//   y = a*sin(2θ)*cos(ψ) + q*cos(2θ)*sin(ψ)
//
// 其中 ψ 为谐振载波相位，θ 为物理驻波角。
// 该模型用于验证 RTL 内部 NCO、IQ 混频、低通抽取和 E/Q/S/R 计算是否正确。
// ============================================================================

// ============================================================================
// hrg_wa_raw_plant_model.sv
// ----------------------------------------------------------------------------
// 不可综合的 HRG 全角模式原始载波级 plant 模型。
// 该模型输出原始 x/y 检测 ADC 采样，供 RTL 前端完成 NCO/IQ/CIC/FIR/EQSR。
// ============================================================================

`timescale 1ns/1ps

module hrg_wa_raw_plant_model #(
    parameter real RAW_FS_HZ       = 64000.0,
    parameter real CTRL_DT         = 0.001,
    parameter real CBRYAN          = 0.300,
    parameter real DAMP            = 0.030,
    parameter real DTAU            = 0.002,
    parameter real DOMEGA          = 0.015,
    parameter real THETA_TAU       = 0.200,
    parameter real THETA_OMEGA     = -0.150,
    parameter real CARRIER_DIV     = 8.0
)(
    input                         clk,
    input                         rst_n,
    input                         raw_valid,
    input                         ctrl_valid,
    input signed [31:0]           fa_cmd,
    input signed [31:0]           fq_cmd,
    input real                    input_rate_deg_s,
    output reg signed [15:0]      adc_x,
    output reg signed [15:0]      adc_y,
    output real                   true_E,
    output real                   true_Q,
    output real                   true_theta_rad
);

    real E;
    real Q;
    real theta;
    real psi;
    real fa;
    real fq;
    real omega_in;
    real dE;
    real dQ;
    real dtheta;
    real a;
    real q;
    real x_real;
    real y_real;
    real noise_x;
    real noise_y;
    reg [31:0] lfsr;

    assign true_E = E;
    assign true_Q = Q;
    assign true_theta_rad = theta;

    function real q30_to_real;
        input signed [31:0] v;
        begin
            q30_to_real = $itor(v) / 1073741824.0;
        end
    endfunction

    function signed [15:0] real_to_q15;
        input real v;
        real scaled;
        begin
            if (v > 0.999969)
                real_to_q15 = 16'sh7fff;
            else if (v < -1.0)
                real_to_q15 = 16'sh8000;
            else begin
                scaled = v * 32768.0;
                real_to_q15 = $rtoi(scaled);
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            E <= 1.0;
            Q <= 0.0;
            theta <= 0.0;
            psi <= 0.0;
            adc_x <= 16'sd0;
            adc_y <= 16'sd0;
            lfsr <= 32'h1357_2468;
        end else begin
            if (ctrl_valid) begin
                fa = q30_to_real(fa_cmd);
                fq = q30_to_real(fq_cmd);
                omega_in = input_rate_deg_s * 3.14159265358979323846 / 180.0;

                dE = -2.0*DAMP*E + fa;
                dQ = -2.0*DAMP*Q - 2.0*DOMEGA*E*$sin(4.0*(theta-THETA_OMEGA)) + fq;
                dtheta = -CBRYAN*omega_in
                       + 0.5*DTAU*$sin(4.0*(theta-THETA_TAU))
                       + 0.5*DOMEGA*(Q/(E+1.0e-9))*$cos(4.0*(theta-THETA_OMEGA));

                E <= E + dE*CTRL_DT;
                Q <= Q + dQ*CTRL_DT;
                theta <= theta + dtheta*CTRL_DT;
            end

            if (raw_valid) begin
                if (E < 1.0e-6) begin
                    a = 0.001;
                    q = 0.0;
                end else begin
                    a = $sqrt(E);
                    q = Q/(2.0*a + 1.0e-12);
                end

                // 二阶模态检测：x/y 包含 cos(2theta)、sin(2theta)。
                x_real = a*$cos(2.0*theta)*$cos(psi) - q*$sin(2.0*theta)*$sin(psi);
                y_real = a*$sin(2.0*theta)*$cos(psi) + q*$cos(2.0*theta)*$sin(psi);

                // 微小确定性伪噪声，避免过于理想；幅值足够小，不影响功能判断。
                lfsr = {lfsr[30:0], lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};
                noise_x = ((lfsr & 16'h00ff) - 128.0) / 32768.0 * 0.002;
                noise_y = (((lfsr >> 8) & 16'h00ff) - 128.0) / 32768.0 * 0.002;

                adc_x <= real_to_q15(x_real + noise_x);
                adc_y <= real_to_q15(y_real + noise_y);

                psi = psi + 2.0*3.14159265358979323846/CARRIER_DIV;
                if (psi >= 2.0*3.14159265358979323846)
                    psi = psi - 2.0*3.14159265358979323846;
            end
        end
    end

endmodule
