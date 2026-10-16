`timescale 1ns/1ps
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
        denominator=energy_i>1342177 ? energy_i:1342177;
        if(numerator<0) error_q24=-((-numerator+denominator/2)/denominator);
        else error_q24=(numerator+denominator/2)/denominator;
        numerator=$signed(correction_q30)*128'sd4294967296;
        denominator=128'sd1073741824*40000;
        correction_word=numerator<0 ? -((-numerator+denominator/2)/denominator):(numerator+denominator/2)/denominator;
        total=$signed({1'b0,base_fcw_i})+correction_word;
    end
    hrg_pi_aw pi(error_q24,integrator,32'sd524288,32'sd2293760,
        40'sd24542670263,64'sd1288490188800,16'd12,next_integrator,correction_q30,pi_limit);
    always @(posedge clk or negedge nrst) begin
        if(!nrst) begin integrator<=0;fcw_o<=32'h20000000;frozen_o<=1;limited_o<=0;locked_o<=0;end
        else if(update_i) begin
            frozen_o<=!measurement_valid_i;limited_o<=0;locked_o<=0;
            if(!enable_i) begin integrator<=0;fcw_o<=base_fcw_i;end
            else if(measurement_valid_i) begin
                integrator<=next_integrator;limited_o<=pi_limit;
                fcw_o<=total<0 ? 32'd0:(total>128'sd4294967295 ? 32'hffffffff:total[31:0]);
                locked_o<=error_q24<=419430 && error_q24>= -419430;
            end
        end
    end
endmodule
