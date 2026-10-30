function r=p101_envelope_reference(p)
t=(0:round(p.envDuration/p.envTs))'*p.envTs;C=p.initial_fraction*[cos(p.theta0);sin(p.theta0)]+0i;
r.t=t;r.y=zeros(numel(t),6);
for k=1:numel(t)
 [next,voltage]=p101_envelope_step(C,p);r.y(k,:)=[real(C)' -imag(C)' p.virtual_rate voltage];C=next;
end
end
