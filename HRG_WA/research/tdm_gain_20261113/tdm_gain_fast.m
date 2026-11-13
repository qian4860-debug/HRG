function [frames,info,debug] = tdm_gain_fast(c,blocks)
% 向量化执行五电极三种驱检闭环。用脉冲响应推进物理状态，
% 保留每一物理拍的量化以及控制指令更新时序。
% 返回 frames=[发布时刻, 角度, Ix, Iy, Qx, Qy]。本研究固定无额外噪声/抖动。
% 峰值和限幅时间覆盖能在仿真时限内发布的完整检测帧。
arguments
    c (1,1) struct
    blocks (1,1) struct = tdm_gain_blocks(c)
end
assert(c.p.dac_divisor==1 && ~c.p.seed_enabled && ...
    c.p.adc_noise_rms==0 && c.p.adc_dither_lsb_rms==0 && ~isfield(c,'carrierPhase_rad'), ...
    '向量化评估只支持名义载波、全速 DAC 和无噪声/抖动。');
assert(c.continuous || c.validEnd+c.adcLatency<=c.frame, ...
    '分时快速评估要求 ADC 流水在下一帧首个 DAC 拍前结束。');
publishPhase = c.validEnd+c.adcLatency;
nTicks = round(c.duration/c.Ts);
nComplete = max(0,floor((nTicks-publishPhase)/c.frame)+1);
frames = zeros(nComplete,6);
info = struct('expected_frames',nComplete,'published_frames',0,'tracking_lost',false, ...
    'adc_clip_ticks',0,'dac_clip_ticks',0,'adc_valid_peak_V',0,'adc_sense_peak_V',0, ...
    'cv_sense_peak_V',0,'last_adc_clip_s',NaN,'last_dac_clip_s',NaN);
saveDebug = nargout>=3;
if saveDebug
    debug.adc = zeros(c.validEnd-c.validStart,2,nComplete);
    debug.dac = zeros(c.driveEnd,2,nComplete);
end
x = c.x0;
command = c.startCommand;
previous = command;
angle = 0;
lastAz = 0;
seen = false;
lost = false;
validIndex = c.validStart-c.senseStart+1:c.validEnd-c.senseStart;
driveTicks = 0:c.driveEnd-1;
validTicks = c.validStart:c.validEnd-1;
for f = 0:nComplete-1
    % 连续版帧首 ADC 流水未完成时，DAC 仍输出上一帧命令。
    basis = carrierAt(c,f*c.frame+driveTicks);
    if c.continuous
        lat = c.adcLatency;
        raw = [reshape(previous,2,2)*basis(:,1:lat), ...
            reshape(command,2,2)*basis(:,lat+1:end)];
        dac = quantize(raw,c.dacStep,c.dacMin,c.dacMax);
        [x,early] = advance(blocks.early,x,dac(:,1:lat));
        [x,later] = advance(blocks.later,x,dac(:,lat+1:end));
        output = [early;later];
        analog = output(:,1:2);
        cv = output(:,3:end);
    else
        raw = reshape(command,2,2)*basis;
        dac = quantize(raw,c.dacStep,c.dacMin,c.dacMax);
        % 驱动卷积、泄放、检测及尾窗按实际拓扑推进。
        x = blocks.bleedEnd*(blocks.driveEnd*x+blocks.driveConvolution*dac(:));
        analog = reshape(blocks.adcSense*x,2,[])';
        cv = blocks.cvSense*x;
        x = blocks.tailEnd*(blocks.senseEnd*x);
    end
    v = analog(validIndex,:);
    adc = quantize(v,c.adcStep,c.adcMin,c.adcMax);
    if saveDebug
        debug.adc(:,:,f+1) = adc;
        debug.dac(:,:,f+1) = dac';
    end

    % ADC 峰值统计使用量化前电压。实际门控只对有效窗口内样本产生 ADC 过载。
    adcClip = any(v<c.adcMin | v>c.adcMax,2);
    dacClip = any(raw<c.dacMin | raw>c.dacMax,1);
    info.adc_clip_ticks = info.adc_clip_ticks+nnz(adcClip);
    info.dac_clip_ticks = info.dac_clip_ticks+nnz(dacClip);
    if any(adcClip)
        info.last_adc_clip_s = (f*c.frame+validTicks(find(adcClip,1,'last')))*c.Ts;
    end
    if any(dacClip)
        info.last_dac_clip_s = (f*c.frame+driveTicks(find(dacClip,1,'last')))*c.Ts;
    end
    info.adc_valid_peak_V = max(info.adc_valid_peak_V,max(abs(v),[],'all'));
    info.adc_sense_peak_V = max(info.adc_sense_peak_V,max(abs(analog),[],'all'));
    info.cv_sense_peak_V = max(info.cv_sense_peak_V,max(abs(cv),[],'all'));
    % 与逐拍参考一致，复原校准 I/Q、振幅与正交控制，按四倍角增量发布。
    estimate = c.detect*(2/c.n*reshape((carrierAt(c,f*c.frame+validTicks)*adc)',4,1));
    i = estimate(1:2);
    q = estimate(3:4);
    energy = dot(i,i)+dot(q,q);
    modal = i.^2+q.^2;
    sn = modal(1)-modal(2);
    sm = 2*(i(1)*i(2)+q(1)*q(2));
    usable = ~any(adcClip) && energy>=c.minEnergy && hypot(sm,sn)>=c.minLinearity*energy;
    previous = command;
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

function basis = carrierAt(c,ticks)
% 乘法顺序与逐拍物理采样参考一致。
phase = c.w*(ticks*c.Ts);
basis = [cos(phase);sin(phase)];
end

function [x,y] = advance(s,x,dac)
% FFT 只对线性 DAC 到读出电压的卷积加速，边界状态仍按离散矩阵推进。
if s.count==0
    y = zeros(0,s.observed);
    return
end
driveFFT = reshape(fft(dac',s.lengthFFT,1),s.lengthFFT,1,2);
forced = ifft(sum(s.impulseFFT.*driveFFT,3),[],1,'symmetric');
y = reshape(s.stateMap*x,s.observed,s.count)'+forced(1:s.count,:);
x = s.state*x+s.drive*dac(:);
end

function q = quantize(x,step,lo,hi)
% 电压码格、舍入和正负码轨均沿用逐拍参考。
q = min(hi,max(lo,step*round(x/step)));
end
