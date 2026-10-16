function xnext = HRG_WA_rk4_step(f, t, x, h)
% HRG_WA_RK4_STEP  One fixed-step fourth-order Runge-Kutta integration step.
%
% 功能说明：
%   ASIC/FPGA 闭环验证通常使用固定采样周期。该函数用于在每个控制周期内对
%   连续时间谐振子慢变量模型进行确定性积分，便于与数字控制时序对齐。

k1 = f(t, x);
k2 = f(t + 0.5*h, x + 0.5*h*k1);
k3 = f(t + 0.5*h, x + 0.5*h*k2);
k4 = f(t + h, x + h*k3);
xnext = x + h*(k1 + 2*k2 + 2*k3 + k4)/6;
end
