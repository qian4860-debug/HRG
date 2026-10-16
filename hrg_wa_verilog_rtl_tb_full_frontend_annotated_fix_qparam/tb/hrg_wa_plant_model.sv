
// ============================================================================
// 详细注释补充说明
// ----------------------------------------------------------------------------
// 本文件是 testbench 使用的慢变量 HRG plant 模型，不参与综合。
//
// 作用：
//   直接根据 fa/fq 控制量推进 E、Q、θ 状态；
//   生成 E/Q/S/R 慢变量，供 hrg_wa_if_top 闭环验证。
//
// 与 full_frontend testbench 的区别：
//   本模型绕过 NCO/IQ/CIC/FIR，只验证控制核心；
//   hrg_wa_raw_plant_model.sv 则输出原始 x/y 载波采样，用于完整前端验证。
// ============================================================================

// ============================================================================
// hrg_wa_plant_model.sv
// ----------------------------------------------------------------------------
// 行为级 HRG 全角模式慢变量 plant。
// 该文件用于 testbench，不可综合。
// 
// 状态：
//   E      能量变量
//   Q      正交变量
//   theta  物理驻波角，rad
//
// 模型：
//   dE/dt     = -2*damp*E + fa
//   dQ/dt     = -2*damp*Q - 2*dOmega*E*sin(4*(theta-thetaOmega)) + fq
//   dtheta/dt = -cBryan*inputRate
//              + 0.5*dTau*sin(4*(theta-thetaTau))
//              + 0.5*dOmega*(Q/E)*cos(4*(theta-thetaOmega))
//
// 输出：
//   E_adc, Q_adc, S_adc, R_adc，均转成 Q2.30 给 RTL。
// ============================================================================

`timescale 1ns/1ps

module hrg_wa_plant_model;

    real E;
    real Q;
    real theta;

    real cBryan;
    real damp;
    real dOmega;
    real dTau;
    real thetaOmega;
    real thetaTau;

    initial begin
        E          = 1.0;
        Q          = 0.0;
        theta      = 0.0;

        cBryan     = 0.300;
        damp       = 0.015;
        dOmega     = 0.0020;
        dTau       = 0.0006;
        thetaOmega = 0.35;
        thetaTau   = 0.20;
    end

    task step;
        input real dt;
        input real input_rate_rad_s;
        input real fa;
        input real fq;
        real Edot;
        real Qdot;
        real Tdot;
        begin
            Edot = -2.0*damp*E + fa;
            Qdot = -2.0*damp*Q
                   - 2.0*dOmega*E*$sin(4.0*(theta-thetaOmega))
                   + fq;

            if (E < 0.05) begin
                Tdot = -cBryan*input_rate_rad_s;
            end else begin
                Tdot = -cBryan*input_rate_rad_s
                       + 0.5*dTau*$sin(4.0*(theta-thetaTau))
                       + 0.5*dOmega*(Q/E)*$cos(4.0*(theta-thetaOmega));
            end

            E     = E     + Edot*dt;
            Q     = Q     + Qdot*dt;
            theta = theta + Tdot*dt;

            if (E < 0.10) E = 0.10;
            if (E > 1.50) E = 1.50;
            if (Q >  0.30) Q =  0.30;
            if (Q < -0.30) Q = -0.30;
        end
    endtask

    task get_eqsr;
        output real Eout;
        output real Qout;
        output real Sout;
        output real Rout;
        real D;
        begin
            D = E*E - Q*Q;
            if (D < 0.0) D = 0.0;
            D = $sqrt(D);

            Eout = E;
            Qout = Q;
            Sout = D*$sin(4.0*theta);
            Rout = D*$cos(4.0*theta);
        end
    endtask

endmodule
