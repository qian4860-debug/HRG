function [t,trace,frames,adcMonitor,angleCandidates,numericProbe]=h68_reference(c,collectADCMonitor)
% 6800 Hz 逐拍 MATLAB 参考；原生 Simulink 不调用本函数，二者独立对拍。
% trace 1:22 为控制/转换器/角度列；26 状态五电极版在 23:26 追加组端电压。
% adcMonitor 为物理采样时刻、ADC 流水线之前的采样，列定义见下方英文说明。
% Independent sample-by-sample MATLAB implementation; never called by SLX.
% Optional adcMonitor rows are taken at the physical sample clock during
% the connected sensing window, before the ADC pipeline. Columns:
% tick (zero based), valid, clean X/Y, ADC input X/Y, code voltage X/Y,
% clipped, and (when available) group C/V A/B/C/D. Codes are zero before valid.
% angleCandidates 的 10 列依次为发布时间、机械/CV/量化的包裹四倍驻波角、
% 三路可用标志、发布脉冲、原闭环机体角和原闭环角有效标志。
% collectADCMonitor=false 只取逐帧角观测时可省去整段模拟采样分配。
arguments
    c (1,1) struct
    collectADCMonitor (1,1) logical = true
end
N=round(c.duration/c.Ts)+1;
% 可选第六输出仅用于定位浮点/量化分歧，不改变控制和状态更新。
% 列为 cos、sin、量化前 DAC 两路、量化前 ADC 两路、当前归一化物理状态。
numericProbe=[];
if nargout>=6, numericProbe=zeros(N,6+c.stateCount); end
t=(0:c.logDecimation:N-1)'*c.Ts;
hasGroups=isfield(c,'groupVoltage');
width=22;
if hasGroups, width=width+size(c.groupVoltage,1); end
trace=zeros(numel(t),width);
frames=zeros(ceil(N/c.frame)+2,width+1); nf=0; nr=0;
adcMonitor=[];
collectADC=nargout>=4 && collectADCMonitor;
hasGroupCV=isfield(c,'portCV');
if collectADC
    monitorWidth=9;
    if hasGroupCV, monitorWidth=monitorWidth+size(c.portCV,1); end
    adcMonitor=zeros(ceil(N/c.frame)*(c.validEnd-c.senseStart),monitorWidth);
    na=0;
end
observeAngles=nargout>=5;
if observeAngles
    angleCandidates=zeros(ceil(N/c.frame)+2,10);
    pending=false;
    mechanicalAcc=zeros(4,1);
    cleanAcc=zeros(4,1);
    nc=0;
    candidateBuffer=zeros(ceil(c.adcLatency/c.frame)+1,4);
end
x=c.x0; cmd=c.startCommand; acc=zeros(4,1); iq=zeros(4,1);
seen=false; lost=false; clipped=false; published=false; lastAz=0; angle=0;
lat=c.adcLatency; fifo=zeros(3,max(1,lat));
noiseState=[c.p.noise_seed;c.p.noise_seed+1];
% 历史配置可能没有抖动字段。关闭时保持原有逐拍算术与轨迹。
ditherScale = 0;
if isfield(c.p,'adc_dither_lsb_rms')
    ditherScale = sqrt(12)*(c.p.adc_dither_lsb_rms*c.adcStep);
    ditherState = c.p.adc_dither_seeds(:);
end
heldDAC=zeros(2,1);
% 可选整形系数以专用电极参考拟合，窗内指数在最后一拍取 1。
hasDriveShape = isfield(c,'dacShape');
if hasDriveShape
    ticks = (0:c.driveEnd-1)'-(c.driveEnd-1);
    edges = exp((ticks*c.Ts)./c.dacShape.taus_s(:)');
    coefficients = reshape(c.dacShape.coeffs,2,[]);
    shapeByTick = [ones(c.driveEnd,1),edges]*coefficients';
end
% 载波初相同时作用在 DAC 调制和相应采样拍的 ADC 解调。
carrierPhase = 0;
if isfield(c,'carrierPhase_rad'), carrierPhase = c.carrierPhase_rad; end
periodicCarrier=isfield(c,'periodicCarrier') && c.periodicCarrier;
for k=0:N-1
    time=k*c.Ts; slot=mod(k,c.frame);
    driveOn=slot<c.driveEnd;
    senseOn=slot>=c.senseStart && slot<c.validEnd;
    validSample=senseOn && slot>=c.validStart;
    carrierTime=time;
    if periodicCarrier, carrierTime=mod(k,c.n)*c.Ts; end
    carrier=[cos(c.w*carrierTime+carrierPhase);sin(c.w*carrierTime+carrierPhase)];
    useCmd=cmd;
    seeding=c.p.seed_enabled && time<c.p.seed_seconds;
    if seeding, useCmd=c.seedCommand; end
    raw=reshape(useCmd,2,2)*carrier;
    % 保留起振预设幅相；闭环共用电极的参考需乘二后应用冻结增量。
    if hasDriveShape && driveOn && ~seeding
        quadrature=reshape(useCmd,2,2)*[-carrier(2);carrier(1)];
        raw=raw+2*(shapeByTick(slot+1,1)*raw+shapeByTick(slot+1,2)*quadrature);
    end
    dacClip=driveOn && any(raw<c.dacMin | raw>c.dacMax);
    if mod(k,c.p.dac_divisor)==0, heldDAC=quantize(raw,c.dacStep,c.dacMin,c.dacMax); end
    u=heldDAC*driveOn;
    noise=sqrt(12)*c.p.adc_noise_rms*(noiseState/2^32-.5);
    noiseState=mod(1664525*noiseState+1013904223,2^32);
    cleanADC=c.pickoff*x;
    if observeAngles
        % 观测直取当前物理采样时刻，保持与 ADC 相同的有效积分窗。
        if slot==0, mechanicalAcc(:)=0; cleanAcc(:)=0; end
        if validSample
            mechanical=c.motion*x;
            mechanicalAcc=mechanicalAcc+[mechanical*carrier(1);mechanical*carrier(2)];
            cleanAcc=cleanAcc+[cleanADC*carrier(1);cleanADC*carrier(2)];
        end
        if slot==c.validEnd-1
            mechanicalFit=2/c.n*mechanicalAcc;
            cleanFit=c.detect*(2/c.n*cleanAcc);
            [mechanicalAz,mechanicalValid]=candidateAzimuth(mechanicalFit,c);
            [cleanAz,cleanValid]=candidateAzimuth(cleanFit,c);
            monitorProp=[mechanicalAz,cleanAz,mechanicalValid,cleanValid];
            if lat>0
                % 连续版的下一帧在上个窗延迟期间已经开始，保留该窗结果。
                candidateBuffer(mod(floor(k/c.frame),ceil(lat/c.frame)+1)+1,:)=monitorProp;
            end
        end
    end
    analog=cleanADC+noise;
    if ditherScale>0
        % 独立于原噪声的两路确定性发生器，每个物理采样拍先取值再更新。
        % 69069×32 位无符号状态在 double 精确整数范围内。
        dither = ditherScale*(ditherState/2^32-.5);
        ditherState = mod(69069*ditherState+1,2^32);
        analog = analog+dither;
    end
    clipNow=validSample && any(analog<c.adcMin | analog>c.adcMax);
    if nargout>=6, numericProbe(k+1,:)=[carrier',raw',analog',x']; end
    adcNow=zeros(2,1);
    if validSample, adcNow=quantize(analog,c.adcStep,c.adcMin,c.adcMax); end
    if collectADC && senseOn
        na=na+1;
        adcMonitor(na,1:9)=[k,validSample,cleanADC',analog',adcNow',clipNow];
        if hasGroupCV, adcMonitor(na,10:end)=(c.portCV*x)'; end
    end
    if lat>0
        ptr=mod(k,lat)+1; received=fifo(:,ptr); fifo(:,ptr)=[adcNow;clipNow];
    else
        received=[adcNow;clipNow];
    end
    adc=received(1:2); overflow=received(3)>0;
    row=[slot,driveOn,senseOn,validSample,adc',u',published,iq',angle, ...
        seen && ~lost,(c.motion*x)',(c.electrode*x)',overflow,lost,dacClip];
    if hasGroups, row=[row,(c.groupVoltage*x)']; end
    if mod(k,c.logDecimation)==0, nr=nr+1; trace(nr,:)=row; end
    if published, nf=nf+1; frames(nf,:)=[time,row]; end
    if observeAngles && pending
        nc=nc+1;
        angleCandidates(nc,:)=[time,observation,published,angle,seen && ~lost];
        pending=false;
    end
    published=false;
    source=k-lat;
    if source>=0
        sourceSlot=mod(source,c.frame);
        if sourceSlot==0, acc(:)=0; clipped=false; end
        if periodicCarrier
            % 载波相位只用周期内整数拍；解调严格复用来源采样拍，避免长时间角度增长。
            phaseSource=c.w*(mod(source,c.n)*c.Ts)+carrierPhase;
        else
            phaseSource=c.w*source*c.Ts+carrierPhase;
        end
        sourceCarrier=[cos(phaseSource);sin(phaseSource)];
        acc=acc+[adc*sourceCarrier(1);adc*sourceCarrier(2)];
        clipped=clipped || overflow;
        if sourceSlot==c.validEnd-1
            estimate=c.detect*(2/c.n*acc);
            I=estimate(1:2); Q=estimate(3:4); energy=dot(I,I)+dot(Q,Q);
            modal=I.^2+Q.^2; sn=modal(1)-modal(2);
            sm=2*(I(1)*I(2)+Q(1)*Q(2)); az=atan2(sm,sn);
            usable=~clipped && energy>=c.minEnergy && hypot(sm,sn)>=c.minLinearity*energy;
            if observeAngles
                if lat>0
                    monitorProp=candidateBuffer(mod(floor(source/c.frame),ceil(lat/c.frame)+1)+1,:);
                end
                observation=[monitorProp(1:2),az,monitorProp(3:4),usable];
                pending=true;
            end
            if usable && ~lost
                iq=estimate; phi=atan2(2*dot(I,Q),dot(I,I)-dot(Q,Q))/2;
                R=[cos(phi),-sin(phi);sin(phi),cos(phi)]; principal=[I Q]*R;
                e=principal(:,1)/max(norm(principal(:,1)),1e-9);
                fSin=-(c.gamma+c.agc*(1-sqrt(energy)))*e;
                fCos=-c.quad*principal(:,2);
                components=c.forceScale*[fCos fSin]*R'; cmd=c.drive*components(:);
                if seen
                    delta=az-lastAz; angle=angle-atan2(sin(delta),cos(delta))/(4*c.B);
                end
                lastAz=az; seen=true; published=true;
            else
                cmd=c.startCommand; lost=lost || seen;
            end
        end
    end
    if driveOn, x=c.Ad*x+c.Bd*u;
    elseif senseOn, x=c.As*x;
    else, x=c.Af*x;
    end
end
frames=frames(1:nf,:);
if collectADC, adcMonitor=adcMonitor(1:na,:); end
if observeAngles, angleCandidates=angleCandidates(1:nc,:); end
end

function [az,usable]=candidateAzimuth(iq,c)
% c.motion 状态以标称电荷归一化，cleanFit 由现有 I/Q 校准映射归一化。
% 四倍驻波角取 atan2，使用原导航的能量和线性驻波门限。
i=iq(1:2);
q=iq(3:4);
modal=i.^2+q.^2;
energy=dot(i,i)+dot(q,q);
sn=modal(1)-modal(2);
sm=2*(i(1)*i(2)+q(1)*q(2));
az=atan2(sm,sn);
usable=energy>=c.minEnergy && hypot(sm,sn)>=c.minLinearity*energy;
end
function y=quantize(x,step,lo,hi)
y=min(hi,max(lo,step*round(x/step)));
end
