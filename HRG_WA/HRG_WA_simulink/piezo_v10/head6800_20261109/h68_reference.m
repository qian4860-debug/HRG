function [t,trace,frames,adcMonitor]=h68_reference(c)
% Independent sample-by-sample MATLAB implementation; never called by SLX.
% Optional adcMonitor rows are taken at the physical sample clock during
% the connected sensing window, before the ADC pipeline. Columns:
% tick (zero based), valid, clean X/Y, ADC input X/Y, code voltage X/Y,
% clipped, and (when available) group C/V A/B/C/D. Codes are zero before valid.
N=round(c.duration/c.Ts)+1;
t=(0:c.logDecimation:N-1)'*c.Ts;
hasGroups=isfield(c,'groupVoltage');
width=22;
if hasGroups, width=width+size(c.groupVoltage,1); end
trace=zeros(numel(t),width);
frames=zeros(ceil(N/c.frame)+2,width+1); nf=0; nr=0;
collectADC=nargout>=4;
hasGroupCV=isfield(c,'portCV');
if collectADC
    monitorWidth=9;
    if hasGroupCV, monitorWidth=monitorWidth+size(c.portCV,1); end
    adcMonitor=zeros(ceil(N/c.frame)*(c.validEnd-c.senseStart),monitorWidth);
    na=0;
end
x=c.x0; cmd=c.startCommand; acc=zeros(4,1); iq=zeros(4,1);
seen=false; lost=false; clipped=false; published=false; lastAz=0; angle=0;
lat=c.adcLatency; fifo=zeros(3,max(1,lat));
noiseState=[c.p.noise_seed;c.p.noise_seed+1];
heldDAC=zeros(2,1);
for k=0:N-1
    time=k*c.Ts; slot=mod(k,c.frame);
    driveOn=slot<c.driveEnd;
    senseOn=slot>=c.senseStart && slot<c.validEnd;
    validSample=senseOn && slot>=c.validStart;
    carrier=[cos(c.w*time);sin(c.w*time)];
    useCmd=cmd;
    if c.p.seed_enabled && time<c.p.seed_seconds, useCmd=c.seedCommand; end
    raw=reshape(useCmd,2,2)*carrier;
    dacClip=driveOn && any(raw<c.dacMin | raw>c.dacMax);
    if mod(k,c.p.dac_divisor)==0, heldDAC=quantize(raw,c.dacStep,c.dacMin,c.dacMax); end
    u=heldDAC*driveOn;
    noise=sqrt(12)*c.p.adc_noise_rms*(noiseState/2^32-.5);
    noiseState=mod(1664525*noiseState+1013904223,2^32);
    cleanADC=c.pickoff*x;
    analog=cleanADC+noise;
    clipNow=validSample && any(analog<c.adcMin | analog>c.adcMax);
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
    published=false;
    source=k-lat;
    if source>=0
        sourceSlot=mod(source,c.frame);
        if sourceSlot==0, acc(:)=0; clipped=false; end
        sourceCarrier=[cos(c.w*source*c.Ts);sin(c.w*source*c.Ts)];
        acc=acc+[adc*sourceCarrier(1);adc*sourceCarrier(2)];
        clipped=clipped || overflow;
        if sourceSlot==c.validEnd-1
            estimate=c.detect*(2/c.n*acc);
            I=estimate(1:2); Q=estimate(3:4); energy=dot(I,I)+dot(Q,Q);
            modal=I.^2+Q.^2; sn=modal(1)-modal(2);
            sm=2*(I(1)*I(2)+Q(1)*Q(2)); az=atan2(sm,sn);
            usable=~clipped && energy>=c.minEnergy && hypot(sm,sn)>=c.minLinearity*energy;
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
end
function y=quantize(x,step,lo,hi)
y=min(hi,max(lo,step*round(x/step)));
end
