`timescale 1ns/1ps
`include "hrg_head_config.vh"
module hrg_dpll (
    input wire clk,nrst,update_i,enable_i,measurement_valid_i,
    input wire signed [31:0] energy_i,l_i,
    input wire [31:0] base_fcw_i,
    output reg [31:0] fcw_o,
    output reg frozen_o,limited_o,locked_o
);
    reg signed [39:0] integrator;
    wire signed [39:0] next_integrator;
    reg signed [63:0] error_q24;
    wire signed [63:0] correction_q30;
    wire pi_limit;
    reg signed [127:0] numerator,denominator,correction_word,total;
    always @* begin
        numerator=-$signed({l_i[31],l_i});numerator=numerator<<<24;
        denominator=energy_i>`HRG_ENERGY_DENOM_Q24 ? energy_i:`HRG_ENERGY_DENOM_Q24;
        if(numerator<0) error_q24=-((-numerator+denominator/2)/denominator);
        else error_q24=(numerator+denominator/2)/denominator;
        numerator=$signed(correction_q30)*128'sd4294967296;
        denominator=128'sd1073741824*`HRG_ADC_HZ;
        correction_word=numerator<0 ? -((-numerator+denominator/2)/denominator):(numerator+denominator/2)/denominator;
        total=$signed({1'b0,base_fcw_i})+correction_word;
    end
    hrg_pi_aw pi(error_q24,integrator,`HRG_PLL_KP_Q16,`HRG_PLL_KI_Q16,
        `HRG_PLL_I_LIMIT_Q30,`HRG_PLL_OUT_LIMIT_Q30,`HRG_PLL_BACK_GAIN,next_integrator,correction_q30,pi_limit);
    always @(posedge clk or negedge nrst) begin
        if(!nrst) begin integrator<=0;fcw_o<=`HRG_DEFAULT_NCO_FCW;frozen_o<=1;limited_o<=0;locked_o<=0;end
        else if(update_i) begin
            frozen_o<=!measurement_valid_i;limited_o<=0;locked_o<=0;
            if(!enable_i) begin integrator<=0;fcw_o<=base_fcw_i;end
            else if(measurement_valid_i) begin
                integrator<=next_integrator;limited_o<=pi_limit;
                fcw_o<=total<0 ? 32'd0:(total>128'sd4294967295 ? 32'hffffffff:total[31:0]);
                locked_o<=error_q24<=`HRG_PLL_LOCK_Q24 && error_q24>= -`HRG_PLL_LOCK_Q24;
            end
        end
    end
endmodule
