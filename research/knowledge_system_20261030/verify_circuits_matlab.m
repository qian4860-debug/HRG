function verify_circuits_matlab()
% Cross-check synthetic circuit mathematics, without a PDK or Simulink claim.
here=fileparts(mfilename('fullpath'));
s=2i*pi*1000; ct=100e-12;cf=10e-12;rf=1e9;A=1e5/(1+s/(2*pi*100));
yf=1/rf+s*cf;zf=1/yf;ng=1+s*ct*zf;
response=[s*ct+yf -yf; A 1]\[1;0];
checks.charge_MNA=abs((response(2)+zf/(1+ng/A))/response(2))<1e-12;
g1=1e-5;g2=2e-5;gm1=.002;gm2=.01;c1=1e-12;c2=10e-12;cc=5e-12;
response=[g1+s*(c1+cc) -s*cc;gm2-s*cc g2+s*(c2+cc)]\[gm1;0];
den=g1*g2+s*(g1*(c2+cc)+g2*(c1+cc)+gm2*cc)+s^2*(c1*c2+cc*(c1+c2));
checks.miller_MNA=abs((response(2)+gm1*(gm2-s*cc)/den)/response(2))<1e-12;
k=1.380649e-23;T=300;R=1e4;C=1e-12;
u=logspace(-8,8,200000);noise=2*k*T/(pi*C)*trapz(u,1./(1+u.^2));
checks.thermal_integral=abs(noise/(k*T/C)-1)<1e-7;
bits=16;span=2;lsb=span/2^bits;tacq=2e-6;tau=tacq/((bits+1)*log(2));
checks.settling=abs(exp(-tacq/tau)-2^(-bits-1))<1e-12;
snr=10*log10((span^2/8)/(lsb^2/12));
checks.quantization=abs(snr-98.090511203)<1e-9;
checks.lecture_counterexample=abs(100/(1+100*.5)-100/(100+100*.5))>1;
rm=8;stages=3;imp=1;for n=1:stages,imp=conv(imp,ones(1,rm));end
checks.cic_delay=abs(sum((0:length(imp)-1).*imp)/sum(imp)-stages*(rm-1)/2)<1e-12;
rho=.7;N=20;cov=rho.^abs((0:N-1)'-(0:N-1));vec=ones(N,1)/N;
target=(1+2*sum((1-(1:N-1)/N).*rho.^(1:N-1)))/N;
checks.correlated_average=abs(vec'*cov*vec-target)<1e-12;
assert(all(structfun(@(v)v,checks)),'Circuit cross-check failed');
report=struct('matlab',version,'total',numel(fieldnames(checks)),'checks',checks, ...
 'boundary','Synthetic circuit mathematics, not transistor or hardware simulation');
fid=fopen(fullfile(here,'matlab_circuit_checks.json'),'w','n','UTF-8');cleaner=onCleanup(@()fclose(fid));
fwrite(fid,[jsonencode(report,PrettyPrint=true) newline],'char');
fprintf('PASS %d MATLAB circuit checks\n',report.total);
end
