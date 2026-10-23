function y=w8_control_tick(u,c)
warming=u(26)*c.head.Ts<c.v8.filterWarmupS;
if warming
 u(1:10)=0; % Hold startup/invalid handling until the observable filter is filled.
end
y=w7_control_tick(u,c);
if warming,y(18:21)=0;end % Do not torque an already vibrating head before valid sensing.
if c.v8.enabled
 h=c.v8.driveInverse*(y(18:19)+1i*y(20:21));
 y(18:21)=[real(h);imag(h)];
end
end
