function verify_addendum_matlab()
% Independent MATLAB checks; no changes to accepted Simulink models.
here=fileparts(mfilename('fullpath'));
J=[0 -1;1 0]; t=0.73; v=[cos(t);sin(t)]; w=J*v;
H=[0.3 0.2;0.2 -0.3]; h=hypot(0.3,0.2); axis=atan2(0.2,0.3)/2;
checks.matrix_axes=abs(v'*H*v-h*cos(2*(t-axis)))<1e-12;
checks.quadrature_projection=abs(-w'*H*v-h*sin(2*(t-axis)))<1e-12;
checks.direction_sign=abs([1 0]*J*[0;-2]/2-1)<1e-12;
p=(0:65535)*pi/65536;
b=0.01*sin(2*(p-0.2))+(0.0001+0.0003*cos(2*(p+0.1))).*(0.3+0.01*cos(2*(p-0.2)))+(0.0002+0.0004*cos(2*(p-0.7))).*0.6.*sin(2*(p+0.3));
dc=0.0001*0.3+0.0003*0.01/2*cos(2*(0.2+0.1))+0.0004*0.6/2*sin(2*(0.7+0.3));
checks.product_DC=abs(mean(b)-dc)<1e-12;
s=0.02;r=2; ep=s*r-mean(b);em=-s*r-mean(b);
checks.reversal=abs((ep+em)/2+dc)<1e-12;
c=linspace(-0.1,0.1,51)';coeff=[ones(size(c)) c]\(0.7-c/(1+s));
checks.scale_inverse=abs(-1/coeff(2)-1-s)<1e-12;
x=1e4*1e3/(10*(1e3^2-1e4^2));
checks.negative_printed_Q=(0.001/(2*pi)*atan(x)<0);
checks.global_Q=abs(180*1e4*(1e-7+1.6e-6)-3.06)<1e-12;
phase=(0:65535)*2*pi/65536;
power=mean((-0.2*cos(2*phase+0.7)*1.4.*cos(phase)).* (-1.4*3*sin(phase)));
checks.parametric_power=abs(power+0.2*1.4^2*3*sin(0.7)/4)<1e-12;
disp(checks);
assert(all(structfun(@(x)x,checks)),'Classics addendum check failed');
report=struct('matlab',version,'checks',checks,'total',numel(fieldnames(checks)), ...
 'boundary','Synthetic mathematical checks, not Simulink or hardware performance');
text=jsonencode(report,PrettyPrint=true);
fid=fopen(fullfile(here,'matlab_checks.json'),'w','n','UTF-8');
cleaner=onCleanup(@()fclose(fid));
fwrite(fid,[text newline],'char');
fprintf('PASS %d MATLAB addendum checks\n',report.total);
end
