`timescale 1ns/1ps

// Fixed-point front end derived from HRG_WA_v46_simulate.m.
// ADC: Q2.16, NCO: signed code/131071, mixer/CIC: Q6.24, demod: Q6.22,
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
        .cos_o(), .sin_o(), .phase_o(nco_phase_o),
        .cos_sample_o(nco_cos), .sin_sample_o(nco_sin),
        .wrap_pulse_o(nco_wrap_o)
    );

    wire signed [35:0] p_xc = adc_x_i * nco_cos;
    wire signed [35:0] p_xs = adc_x_i * nco_sin;
    wire signed [35:0] p_yc = adc_y_i * nco_cos;
    wire signed [35:0] p_ys = adc_y_i * nco_sin;
    wire signed [36:0] mix_wide [0:3];
    // round(2*ADC/2^16 * NCO/131071 * 2^24), ties away from zero.
    function signed [36:0] mix_round;
        input signed [35:0] product;
        reg signed [63:0] numerator;
        begin
            numerator=product;
            numerator=numerator<<<9;
            if(numerator<0) mix_round=-((-numerator+65535)/131071);
            else mix_round=(numerator+65535)/131071;
        end
    endfunction
    assign mix_wide[0] = mix_round(p_xc);
    assign mix_wide[1] = mix_round(p_xs);
    assign mix_wide[2] = mix_round(p_yc);
    assign mix_wide[3] = mix_round(p_ys);

    reg signed [95:0] int0 [0:3];
    reg signed [95:0] int1 [0:3];
    reg signed [95:0] int2 [0:3];
    reg signed [95:0] comb_d0 [0:3];
    reg signed [95:0] comb_d1 [0:3];
    reg signed [95:0] comb_d2 [0:3];
    reg signed [33:0] fir_z1 [0:3];
    reg signed [33:0] fir_z2 [0:3];
    reg signed [33:0] fir_z3 [0:3];
    reg signed [33:0] fir_z4 [0:3];
    integer dec_count;

    integer i;
    reg signed [95:0] c0, c1, c2;
    reg signed [95:0] normalized;
    reg signed [95:0] fir_sum;
    reg signed [95:0] n0,n1,n2;
    reg signed [31:0] fir_now [0:3];
    reg signed [63:0] aa, bb, cc, dd;
    reg signed [63:0] e_w, q_w, r_w, s_w, l_w;

    function signed [95:0] round_div;
        input signed [95:0] value;
        input integer divisor;
        begin
            if(value<0) round_div=-((-value+divisor/2)/divisor);
            else round_div=(value+divisor/2)/divisor;
        end
    endfunction
    function signed [63:0] round_inv;
        input signed [63:0] value;
        begin
            if(value<0) round_inv=-((-value+64'sd524288)>>>20);
            else round_inv=(value+64'sd524288)>>>20;
        end
    endfunction

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
                    n0=int0[i]+mix_wide[i];
                    n1=int1[i]+n0;
                    n2=int2[i]+n1;
                    int0[i] <= n0;
                    int1[i] <= n1;
                    int2[i] <= n2;
                    // Save the new last integrator for the same-sample comb.
                    if(dec_count==DECIMATION-1) begin
                        c0=n2-comb_d0[i]; c1=c0-comb_d1[i]; c2=c1-comb_d2[i];
                        comb_d0[i]<=n2;comb_d1[i]<=c0;comb_d2[i]<=c1;
                        normalized=round_div(c2<<<2,CIC_GAIN); // Q26
                        fir_sum=normalized+2*fir_z1[i]+3*fir_z2[i]+2*fir_z3[i]+fir_z4[i];
                        fir_now[i]=round_div(round_div(fir_sum,9),16); // Q26 -> Q22
                        fir_z4[i]<=fir_z3[i];fir_z3[i]<=fir_z2[i];
                        fir_z2[i]<=fir_z1[i];fir_z1[i]<=normalized;
                    end
                    if (mix_wide[i] > 37'sd536870911 || mix_wide[i] < -37'sd536870912)
                        overflow_o <= 1'b1;
                end
                if (dec_count == DECIMATION-1) begin
                    dec_count <= 0;

                    cx_o <= fir_now[0][27:0]; sx_o <= fir_now[1][27:0];
                    cy_o <= fir_now[2][27:0]; sy_o <= fir_now[3][27:0];

                    aa = $signed(fir_now[0]) * $signed(fir_now[0]);
                    bb = $signed(fir_now[1]) * $signed(fir_now[1]);
                    cc = $signed(fir_now[2]) * $signed(fir_now[2]);
                    dd = $signed(fir_now[3]) * $signed(fir_now[3]);
                    e_w = round_inv(aa + bb + cc + dd);
                    q_w = (($signed(fir_now[0]) * $signed(fir_now[3]) -
                            $signed(fir_now[2]) * $signed(fir_now[1])) <<< 1);
                    q_w=round_inv(q_w);
                    r_w = round_inv(aa + bb - cc - dd);
                    s_w = (($signed(fir_now[0]) * $signed(fir_now[2]) +
                            $signed(fir_now[1]) * $signed(fir_now[3])) <<< 1);
                    s_w=round_inv(s_w);
                    l_w = (($signed(fir_now[0]) * $signed(fir_now[1]) +
                            $signed(fir_now[2]) * $signed(fir_now[3])) <<< 1);
                    l_w=round_inv(l_w);
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
