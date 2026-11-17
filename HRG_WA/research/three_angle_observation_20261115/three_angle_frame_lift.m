function L=three_angle_frame_lift(c)
% 对一个分时帧提升精确离散机电矩阵，并保留有效窗机械/CV的 I/Q 积分。
% 仅适用于驱动窗内命令不变、ADC延迟在下一驱动窗前结束、无量化/噪声/限幅的研究模型。
assert(~c.continuous && c.validEnd+c.adcLatency<c.frame);
assert(c.p.dac_divisor==1 && ~c.p.seed_enabled && ~isfield(c,'dacShape'));
assert(c.p.adc_noise_rms==0 && c.p.adc_dither_lsb_rms==0);
n=c.stateCount; P=eye(n); U=zeros(n,4);
Hm=zeros(4,n); Jm=zeros(4,4); Hc=zeros(4,n); Jc=zeros(4,4);
phase=0; if isfield(c,'carrierPhase_rad'), phase=c.carrierPhase_rad; end
% 保留整段接通窗的电压映射，长轨迹用状态/命令幅值上界核对量程适用性。
cvMap=zeros(2*(c.validEnd-c.senseStart),n+4); row=0;
for k=0:c.frame-1
    a=c.w*(mod(k,c.n)*c.Ts)+phase; z=[cos(a) sin(a)];
    if k>=c.senseStart && k<c.validEnd
        cvMap(row+(1:2),:)=c.pickoff*[P U]; row=row+2;
    end
    if k>=c.validStart && k<c.validEnd
        W=[z(1)*eye(2);z(2)*eye(2)]*(2/c.n);
        Hm=Hm+W*c.motion*P; Jm=Jm+W*c.motion*U;
        Hc=Hc+W*c.pickoff*P; Jc=Jc+W*c.pickoff*U;
    end
    if k<c.driveEnd
        A=c.Ad; B=c.Bd*[z(1)*eye(2),z(2)*eye(2)];
    elseif k>=c.senseStart && k<c.validEnd
        A=c.As; B=zeros(n,4);
    else
        A=c.Af; B=zeros(n,4);
    end
    P=A*P; U=A*U+B;
end
L=struct('F',P,'G',U,'Hm',Hm,'Jm',Jm,'Hc',c.detect*Hc, ...
    'Jc',c.detect*Jc,'T',c.frame*c.Ts,'cvMap',cvMap, ...
    'candidateOffset_s',(c.validEnd+c.adcLatency)*c.Ts);
end
