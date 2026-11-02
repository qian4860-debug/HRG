function cases=stress_cases()
% 全部为事先声明的合成点；噪声为ADC输入每采样RMS，不是V/sqrt(Hz)。
stress_setup;p=pcn_config;c=pcn_calibration;cases=struct('id',{},'label',{},'p',{},'c',{});
add('baseline','基线',p,c);
for seed=[20261102 20261103 20261104]
 q=p;q.noise_rms_V=5e-6;q.noise_seed=seed;add(['noise5u_' num2str(seed)],'5μV噪声独立种子',q,c);
end
for noise=[50e-6 500e-6],q=p;q.noise_rms_V=noise;add(['noise_' num2str(noise*1e6) 'u'],[num2str(noise*1e6) 'μV噪声'],q,c);end
for rate=[0 .05 -.5 2],q=p;q.Omega=rate;add(['rate_' strrep(num2str(rate),'-','m')],[num2str(rate) 'rad/s输入'],q,c);end
for split=[.001 .01],q=p;q.split_hz=split;q.stiffness_axis=.61;add(['split_' num2str(split)],[num2str(split) 'Hz频裂'],q,c);end
for damp=[.0002 .002],q=p;q.damping_half_difference=damp;q.damping_axis=-.29;add(['damp_' num2str(damp)],[num2str(damp) '/s阻尼半差'],q,c);end
% 只污染控制器使用的标定矩阵，真实plant参数不变，避免真值抵消。
bad=c;bad.detect=diag([1.01*exp(1i*pi/360),.99*exp(-1i*pi/360)])*c.detect;
add('detect_mismatch','检测标定±1%/±0.5°失配',p,bad);
bad=c;bad.drive=diag([1.01*exp(1i*pi/360),.99*exp(-1i*pi/360)])*c.drive;
add('drive_mismatch','驱动标定±1%/±0.5°失配',p,bad);
for level=1:2
 q=p;q.noise_rms_V=5e-6*10^(level-1);q.split_hz=.001*10^(level-1);q.damping_half_difference=.0002*10^(level-1);q.stiffness_axis=.61;q.damping_axis=-.29;
 bad=c;g=.001*10^(level-1);phi=(.05*10^(level-1))*pi/180;bad.detect=diag([1+g,1-g])*diag(exp(1i*[phi,-phi]))*c.detect;
 add(['combined_' num2str(level)],['组合非理想等级' num2str(level)],q,bad);
end
 function add(id,label,q,cal),cases(end+1)=struct('id',id,'label',label,'p',q,'c',cal);end
end
