function y=wl_input(t,c)
w=2*pi*c.inputFrequencyHz;
rate=c.inputRate+c.inputRateAmplitude*sin(w*t);
acc=c.inputRateAmplitude*w*cos(w*t);
virtual=c.virtualRate;
if c.frpSequence,[virtual,~,~,~]=wl_legacy('schedule',t,c.legacyP);virtual=-virtual/c.head.bryan;end
y=[rate;acc;c.temperatureC+c.temperatureRampCPerS*t;virtual];
end
