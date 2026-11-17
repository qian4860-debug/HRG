function out=three_angle_lift_run(c,L)
% 无量化帧级闭环。机械/CV驻波角沿用逐拍定义；三路角中发布通路等于干净CV。
N=floor(c.duration/L.T+1e-9); x=c.x0; cmd=c.startCommand;
trace=zeros(N,c.stateCount+12); candidates=zeros(N,10);
angle=0; last=0; seen=false; lost=false;
for k=1:N
    cv=L.Hc*x+L.Jc*cmd; mech=L.Hm*x+L.Jm*cmd;
    [az,usable,energy]=azimuth(cv,c); [maz,mok]=azimuth(mech,c);
    accepted=usable && ~lost;
    if accepted
        if seen, delta=az-last; angle=angle-atan2(sin(delta),cos(delta))/(4*c.B); end
        last=az; seen=true;
    else
        lost=lost || seen;
    end
    trace(k,:)=[x',cmd',cv',mech'];
    candidates(k,:)=[(k-1)*L.T+L.candidateOffset_s,maz,az,az,mok,usable,usable,accepted,angle,seen && ~lost];
    x=L.F*x+L.G*cmd;
    if accepted
        % 复用既有 AGC/正交控制方程；命令在本次驱动结束后生成，下一帧生效。
        I=cv(1:2);Q=cv(3:4);phi=atan2(2*dot(I,Q),dot(I,I)-dot(Q,Q))/2;
        R=[cos(phi) -sin(phi);sin(phi) cos(phi)];principal=[I Q]*R;
        e=principal(:,1)/max(norm(principal(:,1)),1e-9);
        fs=-(c.gamma+c.agc*(1-sqrt(energy)))*e;
        fc=-c.quad*principal(:,2);
        a=c.forceScale*[fc fs]*R';cmd=c.drive*a(:);
    else
        cmd=c.startCommand;
    end
end
% 严格的三角不等式上界，可能很保守；上界超限不能反过来证明真实波形削顶。
bound=max(abs(trace(:,1:c.stateCount+4)),[],1)';
cvBound=max(abs(L.cvMap)*bound);
v=trace(:,c.stateCount+(1:4));
dacBound=max(hypot(v(:,1:2),v(:,3:4)),[],'all');
cvPeak=NaN;
if cvBound>=min(c.adcMax,-c.adcMin)
    % 上界过保守时，分批重建所有接通窗的采样点；不分配整段高采样率波形。
    cvPeak=0;
    for first=1:1000:N
        last=min(first+999,N);
        volts=L.cvMap*trace(first:last,1:c.stateCount+4)';
        cvPeak=max(cvPeak,max(abs(volts),[],'all'));
    end
end
peakForGate=cvBound; if isfinite(cvPeak),peakForGate=cvPeak;end
out=struct('trace',trace,'angleCandidates',candidates, ...
    'adc_conservative_peak_bound_V',cvBound,'dac_peak_bound_V',dacBound, ...
    'adc_reconstructed_peak_V',cvPeak, ...
    'rail_free',peakForGate<min(c.adcMax,-c.adcMin) && dacBound<min(c.dacMax,-c.dacMin));
end

function [az,valid,energy]=azimuth(v,c)
I=v(1:2);Q=v(3:4);energy=dot(I,I)+dot(Q,Q);
a=I.^2+Q.^2; sn=a(1)-a(2); sm=2*(I(1)*I(2)+Q(1)*Q(2));
az=atan2(sm,sn);valid=energy>=c.minEnergy && hypot(sm,sn)>=c.minLinearity*energy;
end
