`timescale 1ns/1ps
`include "hrg_head_config.vh"
// Combinational fixed-point port of local_pi_aw. I is unweighted Q30,
// error Q24, gains Q16, command Q30. Nearest rounding, ties away from zero.
module hrg_pi_aw (
    input wire signed [63:0] error_i,
    input wire signed [39:0] integrator_i,
    input wire signed [31:0] kp_i,ki_i,
    input wire signed [39:0] integrator_limit_i,
    input wire signed [63:0] output_limit_i,
    input wire [15:0] back_gain_i,
    output reg signed [39:0] integrator_o,
    output reg signed [63:0] command_o,
    output reg limited_o
);
    reg signed [127:0] candidate,p,u,sat,delta,final_i;
    function signed [127:0] nearest;
        input signed [127:0] n,d;
        reg signed [127:0] a,b;
        begin
            a=n<0 ? -n:n;b=d<0 ? -d:d;
            if(d==0) nearest=0;
            else nearest=((n<0) != (d<0)) ? -((a+b/2)/b):(a+b/2)/b;
        end
    endfunction
    function signed [127:0] clip;
        input signed [127:0] n,lim;
        begin clip=n>lim ? lim:(n< -lim ? -lim:n);end
    endfunction
    always @* begin
        limited_o=0;
        candidate=$signed(integrator_i)+nearest($signed(error_i)*64,`HRG_CTRL_HZ);
        if(candidate>integrator_limit_i || candidate< -integrator_limit_i) limited_o=1;
        candidate=clip(candidate,integrator_limit_i);
        p=nearest($signed(error_i)*$signed(kp_i),1024);
        u=p+nearest(candidate*$signed(ki_i),65536);
        if((u>output_limit_i && error_i>0) || (u< -output_limit_i && error_i<0)) begin
            candidate=integrator_i;
            u=p+nearest(candidate*$signed(ki_i),65536);
        end
        sat=clip(u,output_limit_i);
        if(u!=sat) limited_o=1;
        delta=0;
        if(ki_i!=0 && sat!=u)
            delta=nearest($signed({1'b0,back_gain_i})*(sat-u)*65536,$signed(ki_i)*`HRG_CTRL_HZ);
        final_i=candidate+delta;
        if(final_i>integrator_limit_i || final_i< -integrator_limit_i) limited_o=1;
        final_i=clip(final_i,integrator_limit_i);
        integrator_o=final_i;
        command_o=clip(p+nearest(final_i*$signed(ki_i),65536),output_limit_i);
    end
endmodule
