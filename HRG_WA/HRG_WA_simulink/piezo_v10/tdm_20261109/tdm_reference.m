function [t, trace] = tdm_reference(c)
% Independent MATLAB sample loop. No Simulink model calls this function.
t = (0:round(c.duration/c.Ts))'*c.Ts;
trace = zeros(numel(t),21);
x = c.x0;
cmd = c.startCommand;
acc = zeros(4,1);
iq = zeros(4,1);
seen = false;
lost = false;
clipped = false;
published = false;
lastAz = 0;
angle = 0;
for k = 1:numel(t)
    slot = mod(k-1,c.frame);
    driveOn = slot < c.driveEnd;
    senseOn = slot >= c.senseStart && slot < c.validEnd;
    validSample = senseOn && slot >= c.validStart;
    carrier = [cos(c.w*t(k)); sin(c.w*t(k))];
    u = command(cmd,carrier,c)*driveOn;
    analog = c.pickoff*x;
    adc = zeros(2,1);
    overflow = validSample && any(analog < c.adcMin | analog > c.adcMax);
    if validSample
        adc = quantize(analog,c.adcStep,c.adcMin,c.adcMax);
    end
    trace(k,:) = [slot, driveOn, senseOn, validSample, adc', u', published, ...
        iq', angle, seen && ~lost, (c.motion*x)', (c.electrode*x)', overflow, lost];
    published = false;
    if slot == 0
        acc(:) = 0;
        clipped = false;
    end
    acc = acc + [adc*carrier(1); adc*carrier(2)];
    clipped = clipped || overflow;
    if slot == c.validEnd-1
        estimate = c.detect*(2/c.n*acc);
        I = estimate(1:2);
        Q = estimate(3:4);
        energy = dot(I,I)+dot(Q,Q);
        modal = I.^2+Q.^2;
        N = modal(1)-modal(2);
        M = 2*(I(1)*I(2)+Q(1)*Q(2));
        az = atan2(M,N);
        usable = ~clipped && energy >= c.minEnergy && hypot(M,N) >= c.minLinearity*energy;
        if usable && ~lost
            iq = estimate;
            phi = atan2(2*dot(I,Q),dot(I,I)-dot(Q,Q))/2;
            R = [cos(phi), -sin(phi); sin(phi), cos(phi)];
            principal = [I Q]*R;
            e = principal(:,1)/max(norm(principal(:,1)),1e-9);
            fSin = -(c.gamma + c.agc*(1-sqrt(energy)))*e;
            fCos = -c.quad*principal(:,2);
            components = c.forceScale*[fCos fSin]*R';
            cmd = c.drive*components(:);
            if seen
                delta = az-lastAz;
                angle = angle-atan2(sin(delta),cos(delta))/(4*c.B);
            end
            lastAz = az;
            seen = true;
            published = true;
        else
            cmd = c.startCommand;
            lost = lost || seen;
        end
    end
    if driveOn
        x = c.Ad*x + c.Bd*u;
    elseif senseOn
        x = c.As*x;
    else
        x = c.Af*x;
    end
end
end

function y = command(u,carrier,c)
y = quantize(reshape(u,2,2)*carrier,c.dacStep,c.dacMin,c.dacMax);
end

function y = quantize(x,step,lo,hi)
y = min(hi,max(lo,step*round(x/step)));
end
