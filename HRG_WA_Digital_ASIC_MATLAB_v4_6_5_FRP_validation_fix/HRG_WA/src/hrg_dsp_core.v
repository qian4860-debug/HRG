`timescale 1ns/1ps

// Fixed-point front end derived from HRG_WA_v46_simulate.m.
// ADC: Q2.16, NCO: Q1.17, mixer/CIC: Q6.24, demod: Q6.22,
// invariants: Q8.24.  CIC is three-stage, R=40, M=1.
module hrg_dsp_core #(
    parameter integer DECIMATION = 40,
    parameter integer CIC_GAIN   = 64000
) (
    input  wire                       clk,
    input  wire                       nrst,
    input  wire                       adc_valid_i,
    input  wire signed [17:0]          adc_x_i,
    input  wire signed [17:0]          adc_y_i,
    input  wire [31:0]                 nco_fcw_i,
    output reg                        ctrl_valid_o,
    output reg signed [27:0]           cx_o,
    output reg signed [27:0]           sx_o,
    output reg signed [27:0]           cy_o,
    output reg signed [27:0]           sy_o,
    output reg signed [31:0]           energy_o,
    output reg signed [31:0]           quad_o,
    output reg signed [31:0]           r_o,
    output reg signed [31:0]           s_o,
    output reg signed [31:0]           pll_l_o,
    output reg                        overflow_o,
    output wire [31:0]                nco_phase_o,
    output wire                       nco_wrap_o
);
    wire signed [17:0] nco_cos;
    wire signed [17:0] nco_sin;
    hrg_nco u_nco (
        .clk(clk), .nrst(nrst), .sample_en(adc_valid_i), .fcw(nco_fcw_i),
        .cos_o(nco_cos), .sin_o(nco_sin), .phase_o(nco_phase_o),
        .wrap_pulse_o(nco_wrap_o)
    );

    wire signed [35:0] p_xc = adc_x_i * nco_cos;
    wire signed [35:0] p_xs = adc_x_i * nco_sin;
    wire signed [35:0] p_yc = adc_y_i * nco_cos;
    wire signed [35:0] p_ys = adc_y_i * nco_sin;
    wire signed [36:0] p2_xc = {p_xc[35], p_xc} <<< 1;
    wire signed [36:0] p2_xs = {p_xs[35], p_xs} <<< 1;
    wire signed [36:0] p2_yc = {p_yc[35], p_yc} <<< 1;
    wire signed [36:0] p2_ys = {p_ys[35], p_ys} <<< 1;
    wire signed [36:0] mix_wide [0:3];
    assign mix_wide[0] = p2_xc >>> 9;
    assign mix_wide[1] = p2_xs >>> 9;
    assign mix_wide[2] = p2_yc >>> 9;
    assign mix_wide[3] = p2_ys >>> 9;

    reg signed [95:0] int0 [0:3];
    reg signed [95:0] int1 [0:3];
    reg signed [95:0] int2 [0:3];
    reg signed [95:0] comb_d0 [0:3];
    reg signed [95:0] comb_d1 [0:3];
    reg signed [95:0] comb_d2 [0:3];
    reg signed [31:0] fir_z1 [0:3];
    reg signed [31:0] fir_z2 [0:3];
    reg signed [31:0] fir_z3 [0:3];
    reg signed [31:0] fir_z4 [0:3];
    reg [5:0] dec_count;

    integer i;
    reg signed [95:0] c0, c1, c2;
    reg signed [95:0] normalized;
    reg signed [95:0] fir_sum;
    reg signed [31:0] fir_now [0:3];
    reg signed [63:0] aa, bb, cc, dd;
    reg signed [63:0] e_w, q_w, r_w, s_w, l_w;

    function signed [31:0] sat32;
        input signed [63:0] value;
        begin
            if (value > 64'sh000000007fffffff) sat32 = 32'sh7fffffff;
            else if (value < -64'sh0000000080000000) sat32 = -32'sh80000000;
            else sat32 = value[31:0];
        end
    endfunction

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            ctrl_valid_o <= 1'b0;
            dec_count <= 0;
            cx_o <= 0; sx_o <= 0; cy_o <= 0; sy_o <= 0;
            energy_o <= 0; quad_o <= 0; r_o <= 0; s_o <= 0; pll_l_o <= 0;
            overflow_o <= 1'b0;
            for (i=0; i<4; i=i+1) begin
                int0[i]<=0; int1[i]<=0; int2[i]<=0;
                comb_d0[i]<=0; comb_d1[i]<=0; comb_d2[i]<=0;
                fir_z1[i]<=0; fir_z2[i]<=0; fir_z3[i]<=0; fir_z4[i]<=0;
                fir_now[i]=0;
            end
        end else begin
            ctrl_valid_o <= 1'b0;
            if (adc_valid_i) begin
                for (i=0; i<4; i=i+1) begin
                    int0[i] <= int0[i] + {{66{mix_wide[i][29]}},mix_wide[i][29:0]};
                    int1[i] <= int1[i] + int0[i];
                    int2[i] <= int2[i] + int1[i];
                    if (mix_wide[i] > 37'sd536870911 || mix_wide[i] < -37'sd536870912)
                        overflow_o <= 1'b1;
                end
                if (dec_count == DECIMATION-1) begin
                    dec_count <= 0;
                    for (i=0; i<4; i=i+1) begin
                        c0 = int2[i] - comb_d0[i];
                        c1 = c0 - comb_d1[i];
                        c2 = c1 - comb_d2[i];
                        comb_d0[i] <= int2[i];
                        comb_d1[i] <= c0;
                        comb_d2[i] <= c1;
                        normalized = c2 / CIC_GAIN;
                        fir_now[i] = normalized[31:0];
                        fir_sum = normalized + (fir_z1[i] <<< 1) +
                                  fir_z2[i] + (fir_z2[i] <<< 1) +
                                  (fir_z3[i] <<< 1) + fir_z4[i];
                        fir_now[i] = (fir_sum / 9) >>> 2;
                        fir_z4[i] <= fir_z3[i];
                        fir_z3[i] <= fir_z2[i];
                        fir_z2[i] <= fir_z1[i];
                        fir_z1[i] <= normalized[31:0];
                    end

                    cx_o <= fir_now[0][27:0]; sx_o <= fir_now[1][27:0];
                    cy_o <= fir_now[2][27:0]; sy_o <= fir_now[3][27:0];

                    aa = $signed(fir_now[0]) * $signed(fir_now[0]);
                    bb = $signed(fir_now[1]) * $signed(fir_now[1]);
                    cc = $signed(fir_now[2]) * $signed(fir_now[2]);
                    dd = $signed(fir_now[3]) * $signed(fir_now[3]);
                    e_w = (aa + bb + cc + dd) >>> 20;
                    q_w = (($signed(fir_now[0]) * $signed(fir_now[3]) -
                            $signed(fir_now[2]) * $signed(fir_now[1])) <<< 1) >>> 20;
                    r_w = (aa + bb - cc - dd) >>> 20;
                    s_w = (($signed(fir_now[0]) * $signed(fir_now[2]) +
                            $signed(fir_now[1]) * $signed(fir_now[3])) <<< 1) >>> 20;
                    l_w = (($signed(fir_now[0]) * $signed(fir_now[1]) +
                            $signed(fir_now[2]) * $signed(fir_now[3])) <<< 1) >>> 20;
                    energy_o <= sat32(e_w); quad_o <= sat32(q_w);
                    r_o <= sat32(r_w); s_o <= sat32(s_w); pll_l_o <= sat32(l_w);
                    if (e_w != $signed(sat32(e_w)) || q_w != $signed(sat32(q_w)) ||
                        r_w != $signed(sat32(r_w)) || s_w != $signed(sat32(s_w)) ||
                        l_w != $signed(sat32(l_w))) overflow_o <= 1'b1;
                    ctrl_valid_o <= 1'b1;
                end else begin
                    dec_count <= dec_count + 1'b1;
                end
            end
        end
    end
endmodule
