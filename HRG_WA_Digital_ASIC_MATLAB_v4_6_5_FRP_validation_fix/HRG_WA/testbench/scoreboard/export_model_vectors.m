function export_model_vectors()
% Generated adapter: below helper functions are copied verbatim from current model.
addpath(fullfile(pwd,'..','..','..'));
p=HRG_WA_v46_params();
a=readmatrix('dsp_vectors.txt','FileType','text');
f=fopen('model_vectors.txt','w'); assert(f>=0); cleanup=onCleanup(@() fclose(f));
count=0; outputs=0;
for k=1:size(a,1)
 if a(k,1)==0
  st.ncoPhaseWord=0; st.bittrueNcoWrapCount=0;
  st.cicInt=zeros(4,p.asic.cicStages); st.cicCombDelay=zeros(4,p.asic.cicStages);
  st.firDelay=zeros(4,numel(p.asic.firCoefficients));
  st.bittrueCicValidCount=0; st.bittrueFirValidCount=0; count=0;
 elseif a(k,2)
  st.ncoFrequencyHz=a(k,5)*p.sim.fsAdc/2^32;
  [co,si,st]=local_integer_nco_step(st,p,1/p.sim.fsAdc);
  adc=a(k,3:4)/2^16;
  mix=[2*adc(1)*co;2*adc(1)*si;2*adc(2)*co;2*adc(2)*si];
  [mix,~]=local_fixed_vector(mix,p.asic.mixerWordLength,p.asic.mixerFractionLength);
  count=count+1;
  [c,valid,st,~]=local_cic_update(mix,st,p,mod(count,40)==0,40);
  if valid
   [d,~,st]=local_fir_update(c,st,p);
   [d,~]=local_fixed_vector(d,p.asic.demodWordLength,p.asic.demodFractionLength);
   demod=struct('Cx',d(1),'Sx',d(2),'Cy',d(3),'Sy',d(4));
   [inv,~]=local_invariants(demod,p);
   fprintf(f,'%.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f\n',...
    d*2^22, [inv.E;inv.Q;inv.R;inv.S;inv.L]*2^24);
   outputs=outputs+1;
  end
 end
end
fprintf('MATLAB_GOLDEN_OUTPUTS=%d\n',outputs);
end

function [ncoCos, ncoSin, st] = local_integer_nco_step(st, p, TsAdc) % 执行V4.4整数NCO相位累加和幅度量化。
phaseModulus = 2 ^ p.asic.ncoPhaseBits; % 计算整数相位累加器模数。
phaseIncrement = round(st.ncoFrequencyHz * TsAdc * phaseModulus); % 把NCO频率控制字转换为本ADC拍整数相位增量。
previousWord = st.ncoPhaseWord; % 保存更新前相位字用于回卷检测。
st.ncoPhaseWord = mod(st.ncoPhaseWord + phaseIncrement, phaseModulus); % 按模加法推进整数NCO相位累加器。
if st.ncoPhaseWord < previousWord % 判断本拍是否跨过相位累加器零点。
    st.bittrueNcoWrapCount = st.bittrueNcoWrapCount + 1; % 累加整数NCO回卷次数。
end % 结束NCO回卷计数。
st.ncoPhase = 2 * pi * st.ncoPhaseWord / phaseModulus; % 把整数相位字映射为诊断用弧度相位。
amplitudeScale = 2 ^ (p.asic.ncoAmplitudeBits - 1) - 1; % 计算NCO幅度量化满刻度。
ncoCos = round(cos(st.ncoPhase) * amplitudeScale) / amplitudeScale; % 量化余弦参考，等效硬件CORDIC/LUT幅度输出。
ncoSin = round(sin(st.ncoPhase) * amplitudeScale) / amplitudeScale; % 量化正弦参考，等效硬件CORDIC/LUT幅度输出。
end % 结束整数NCO函数。


function [out, valid, st, saturated] = local_cic_update(sample, st, p, decimateNow, decimationRatio) % 执行V4.4四路CIC积分器、抽取和梳状器更新。
saturated = false; % 初始化本样本CIC Q格式饱和标志。
valid = false; % 默认当前ADC样本未到抽取时刻。
out = zeros(4, 1); % 初始化CIC抽取输出。
for stage = 1:p.asic.cicStages % 遍历CIC积分器级联。
    if stage == 1 % 判断是否为第一级积分器。
        inputVector = sample; % 第一级直接接收混频乘积。
    else % 处理后续积分器。
        inputVector = st.cicInt(:, stage - 1); % 后续级接收前一级积分器输出。
    end % 结束积分器输入选择。
    st.cicInt(:, stage) = st.cicInt(:, stage) + inputVector; % 执行积分器累加。
    [st.cicInt(:, stage), satStage] = local_fixed_vector(st.cicInt(:, stage), p.asic.cicWordLength, p.asic.cicFractionLength); % 对积分器寄存器执行Q格式量化。
    saturated = saturated || satStage; % 合并积分器级饱和状态。
end % 结束CIC积分器级联。
if decimateNow % 判断当前ADC样本是否到达控制域抽取边界。
    combVector = st.cicInt(:, end); % 读取末级积分器输出作为梳状器输入。
    for stage = 1:p.asic.cicStages % 遍历CIC梳状器级联。
        delayedVector = st.cicCombDelay(:, stage); % 读取当前梳状器延迟寄存器。
        differenceVector = combVector - delayedVector; % 执行一阶差分梳状运算。
        st.cicCombDelay(:, stage) = combVector; % 更新当前梳状器延迟寄存器。
        combVector = differenceVector; % 把差分结果送往下一级梳状器。
        [combVector, satStage] = local_fixed_vector(combVector, p.asic.cicWordLength, p.asic.cicFractionLength); % 对梳状器输出执行Q格式量化。
        saturated = saturated || satStage; % 合并梳状器级饱和状态。
    end % 结束CIC梳状器级联。
    cicGain = max((decimationRatio * p.asic.cicDifferentialDelay) ^ p.asic.cicStages, eps); % 计算CIC直流增益。
    out = combVector / cicGain; % 对CIC抽取结果执行直流增益归一化，保持与V4.3块平均解调量一致。
    [out, satNorm] = local_fixed_vector(out, p.asic.firWordLength, p.asic.firFractionLength); % 把CIC归一化输出送入FIR输入Q格式。
    saturated = saturated || satNorm; % 合并归一化输出饱和状态。
    valid = true; % 标记本控制拍CIC输出有效。
    st.bittrueCicValidCount = st.bittrueCicValidCount + 1; % 累加CIC有效输出计数。
end % 结束抽取边界处理。
end % 结束CIC更新函数。


function [out, saturated, st] = local_fir_update(cicVector, st, p) % 执行V4.4 CIC后FIR补偿滤波。
coefficients = p.asic.firCoefficients(:); % 读取FIR列向量系数。
st.firDelay = [cicVector, st.firDelay(:, 1:end - 1)]; % 推入四路FIR抽头延迟线。
out = st.firDelay * coefficients; % 对四路数据共享同一组FIR系数执行乘加。
[out, saturated] = local_fixed_vector(out, p.asic.firWordLength, p.asic.firFractionLength); % 按FIR输出Q格式量化。
st.bittrueFirValidCount = st.bittrueFirValidCount + 1; % 累加FIR有效输出计数。
end % 结束FIR更新函数。


function [inv, saturated] = local_invariants(demod, p) % 由Cx、Sx、Cy和Sy构造全角控制需要的五个不变量。
Cx = demod.Cx; % 读取X通道同相分量。
Sx = demod.Sx; % 读取X通道正交分量。
Cy = demod.Cy; % 读取Y通道同相分量。
Sy = demod.Sy; % 读取Y通道正交分量。
inv.E = Cx ^ 2 + Sx ^ 2 + Cy ^ 2 + Sy ^ 2; % 计算主驻波与正交波总能量不变量。
inv.Q = 2 * (Cx * Sy - Cy * Sx); % 计算主驻波与正交波耦合不变量。
inv.R = Cx ^ 2 + Sx ^ 2 - Cy ^ 2 - Sy ^ 2; % 计算包含cos(4theta)的驻波方位不变量。
inv.S = 2 * (Cx * Cy + Sx * Sy); % 计算包含sin(4theta)的驻波方位不变量。
inv.L = 2 * (Cx * Sx + Cy * Sy); % 计算谐振载波与NCO之间的频率相位误差信号。
saturated = false; % 初始化不变量定点饱和标志。
if p.asic.fixedEnable % 判断是否启用不变量数据路径的定点约束。
    [inv.E, sat1] = local_fixed(inv.E, p.asic.invariantWordLength, p.asic.invariantFractionLength); % 量化能量不变量。
    [inv.Q, sat2] = local_fixed(inv.Q, p.asic.invariantWordLength, p.asic.invariantFractionLength); % 量化正交不变量。
    [inv.R, sat3] = local_fixed(inv.R, p.asic.invariantWordLength, p.asic.invariantFractionLength); % 量化余弦方位不变量。
    [inv.S, sat4] = local_fixed(inv.S, p.asic.invariantWordLength, p.asic.invariantFractionLength); % 量化正弦方位不变量。
    [inv.L, sat5] = local_fixed(inv.L, p.asic.invariantWordLength, p.asic.invariantFractionLength); % 量化相位误差信号。
    saturated = sat1 || sat2 || sat3 || sat4 || sat5; % 合并五条数据路径的定点饱和标志。
end % 结束不变量定点量化判断。
end % 结束不变量计算函数。


function [y, saturated] = local_fixed_vector(x, wordLength, fractionLength) % 对向量逐元素执行有符号Q格式量化与饱和。
y = zeros(size(x)); % 预分配输出向量。
saturated = false; % 初始化向量饱和标志。
for idx = 1:numel(x) % 遍历向量所有元素。
    [y(idx), sat] = local_fixed(x(idx), wordLength, fractionLength); % 对当前元素执行定点量化。
    saturated = saturated || sat; % 汇总任一元素饱和状态。
end % 结束向量元素循环。
end % 结束向量Q格式量化函数。


function [y, saturated] = local_fixed(x, wordLength, fractionLength) % 执行有符号二进制定点舍入与饱和。
step = 2 ^ (-fractionLength); % 计算定点格式的最小量化步长。
minimum = -2 ^ (wordLength - fractionLength - 1); % 计算有符号定点数的最小可表示值。
maximum = 2 ^ (wordLength - fractionLength - 1) - step; % 计算有符号定点数的最大可表示值。
rounded = round(x / step) * step; % 将输入舍入到最近的定点量化格点。
[y, saturated] = local_clip(rounded, minimum, maximum); % 对舍入结果执行定点范围饱和。
end % 结束定点量化函数。


function [y, saturated] = local_clip(x, lower, upper) % 将标量或向量限制在给定上下界内。
y = min(max(x, lower), upper); % 执行逐元素上下界限制。
saturated = any(x(:) < lower(:)) || any(x(:) > upper(:)); % 判断任一元素是否发生限幅。
end % 结束通用限幅函数。

