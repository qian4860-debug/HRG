function y = wa_nav_step(u)
% u=[measurement(10); previous(phi4, angle, rate, anchored)(4); virtual; p]
E=u(5); R=u(7);S=u(8); old=u(11:14);virtual=u(15);p=u(16:end);
valid=E>p(40) && hypot(R,S)>p(41);
phase=atan2(S,R); state=old;
if valid
    if old(4)>0
        delta=atan2(sin(phase-old(1)),cos(phase-old(1)));
        deltaAngle=-delta/(4*p(7))-virtual*p(38);
        state(2)=old(2)+deltaAngle;
        a=1-exp(-p(38)/p(39));
        state(3)=old(3)+a*(deltaAngle/p(38)-old(3));
    end
    state(1)=phase;state(4)=1;
else
    state(4)=0; % Re-anchor after dropout; never bridge an unobserved interval.
end
y=[state;state(2);state(3);double(valid);phase/4];
end
