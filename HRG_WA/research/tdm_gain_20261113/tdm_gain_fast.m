function [frames,info,debug] = tdm_gain_fast(c,blocks)
% 向量化执行已验证的五电极分时闭环。每帧保留 800 个 DAC 驱动拍和
% 1600 个 ADC 观察拍，线性状态推进用脉冲响应矩阵，量化和环路逐帧保留。
% 返回 frames=[发布时刻, 角度, Ix, Iy, Qx, Qy]。本研究固定无额外噪声/抖动。
arguments
    c (1,1) struct
    blocks (1,1) struct = tdm_gain_blocks(c)
end
assert(c.reuse && c.p.dac_divisor==1 && ~c.p.seed_enabled && ...
    c.p.adc_noise_rms==0 && c.p.adc_dither_lsb_rms==0 && ~isfield(c,'carrierPhase_rad'), ...
    '向量化评估只支持名义分时采样、全速 DAC 和无噪声/抖动。');
publishPhase = c.validEnd+c.adcLatency;
nTicks = round(c.duration/c.Ts);
nComplete = max(0,floor((nTicks-publishPhase)/c.frame)+1);
frames = zeros(nComplete,6);
info = struct('expected_frames',nComplete,'published_frames',0,'tracking_lost',false, ...
    'adc_clip_ticks',0,'dac_clip_ticks',0,'adc_valid_peak_V',0,'adc_sense_peak_V',0, ...
    'cv_sense_peak_V',0);
saveDebug = nargout>=3;
if saveDebug
    debug.adc = zeros(c.validEnd-c.validStart,2,nComplete);
    debug.dac = zeros(c.driveEnd,2,nComplete);
end
x = c.x0;
command = c.startCommand;
angle = 0;
lastAz = 0;
seen = false;
lost = false;
validIndex = c.validStart-c.senseStart+1:c.validEnd-c.senseStart;
driveTicks = 0:c.driveEnd-1;
validTicks = c.validStart:c.validEnd-1;
for f = 0:nComplete-1
    % 驱动窗结束由量化后的 DAC 序列卷积得到；泄放和检测窗口逐段更新。
    clock = c.w*((f*c.frame+driveTicks)*c.Ts);
    raw = reshape(command,2,2)*[cos(clock);sin(clock)];
    dac = quantize(raw,c.dacStep,c.dacMin,c.dacMax);
    x = blocks.driveEnd*x+blocks.driveConvolution*dac(:);
    x = blocks.bleedEnd*x;
    analog = reshape(blocks.adcSense*x,2,[])';
    cv = blocks.cvSense*x;
    v = analog(validIndex,:);
    adc = quantize(v,c.adcStep,c.adcMin,c.adcMax);
    if saveDebug
        debug.adc(:,:,f+1) = adc;
        debug.dac(:,:,f+1) = dac';
    end

    % ADC 峰值统计使用量化前电压。实际门控只对有效窗口内样本产生 ADC 过载。
    adcClip = any(v<c.adcMin | v>c.adcMax,2);
    info.adc_clip_ticks = info.adc_clip_ticks+nnz(adcClip);
    info.dac_clip_ticks = info.dac_clip_ticks+nnz(any(raw<c.dacMin | raw>c.dacMax,1));
    info.adc_valid_peak_V = max(info.adc_valid_peak_V,max(abs(v),[],'all'));
    info.adc_sense_peak_V = max(info.adc_sense_peak_V,max(abs(analog),[],'all'));
    info.cv_sense_peak_V = max(info.cv_sense_peak_V,max(abs(cv),[],'all'));
    x = blocks.tailEnd*(blocks.senseEnd*x);

    % 与逐拍参考一致，复原校准 I/Q、振幅与正交控制，按四倍角增量发布。
    clock = c.w*((f*c.frame+validTicks)*c.Ts);
    estimate = c.detect*(2/c.n*reshape(([cos(clock);sin(clock)]*adc)',4,1));
    i = estimate(1:2);
    q = estimate(3:4);
    energy = dot(i,i)+dot(q,q);
    modal = i.^2+q.^2;
    sn = modal(1)-modal(2);
    sm = 2*(i(1)*i(2)+q(1)*q(2));
    usable = ~any(adcClip) && energy>=c.minEnergy && hypot(sm,sn)>=c.minLinearity*energy;
    if usable && ~lost
        phi = atan2(2*dot(i,q),dot(i,i)-dot(q,q))/2;
        rotation = [cos(phi),-sin(phi);sin(phi),cos(phi)];
        principal = [i q]*rotation;
        e = principal(:,1)/max(norm(principal(:,1)),1e-9);
        fSin = -(c.gamma+c.agc*(1-sqrt(energy)))*e;
        fCos = -c.quad*principal(:,2);
        components = c.forceScale*[fCos fSin]*rotation';
        command = c.drive*components(:);
        az = atan2(sm,sn);
        if seen
            delta = az-lastAz;
            angle = angle-atan2(sin(delta),cos(delta))/(4*c.B);
        end
        lastAz = az;
        seen = true;
        info.published_frames = info.published_frames+1;
        frames(info.published_frames,:) = [(f*c.frame+publishPhase)*c.Ts,angle,estimate'];
    else
        command = c.startCommand;
        lost = lost || seen;
    end
end
frames = frames(1:info.published_frames,:);
info.tracking_lost = lost;
end

function q = quantize(x,step,lo,hi)
% 电压码格、舍入和正负码轨均沿用逐拍参考。
q = min(hi,max(lo,step*round(x/step)));
end
