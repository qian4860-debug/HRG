function [m,frame]=a4_metrics(r,p,cfg)
d=r.d;ix=find(d(:,9)>0&[true;diff(d(:,9))~=0]);f=d(ix,:);time=f(:,12);
valid=logical(f(:,8))&~logical(f(:,18));assert(all(valid),'A4:FrameInvalid','最小基线不跨无效帧解包');
N=f(:,1).^2+f(:,3).^2-f(:,2).^2-f(:,4).^2;M=2*(f(:,1).*f(:,2)+f(:,3).*f(:,4));
alpha=unwrap(atan2(M,N))/2;
ref=find(valid&time>=cfg.score_origin_not_before_s,1);assert(~isempty(ref));
body=-(alpha-alpha(ref))/(2*p.B);truth=interp1(r.t,r.x(:,14),time);truth=truth-truth(ref);
% 原点尚未建立时不发布相对角；禁止把后来的原点回填成先前可用输出。
body(1:ref-1)=NaN;truth(1:ref-1)=NaN;
error=body-truth;hold=valid&time>=cfg.score_not_before_s;energy=f(:,6)/p.charge_target^2;
quad=2*(f(:,1).*f(:,4)-f(:,2).*f(:,3))./f(:,6);
pll=(f(:,1).*f(:,3)+f(:,2).*f(:,4))./f(:,6);
m=struct('relative_body_RMS_rad',sqrt(mean(error(hold).^2)),'energy_relative_mean',mean(energy(hold))-1,...
 'quadrature_RMS',sqrt(mean(quad(hold).^2)),'PLL_RMS',sqrt(mean(pll(hold).^2)),...
 'valid_fraction',mean(valid),'source_origin_s',time(ref),'DAC_margin_V',p.vmax-max(abs(r.u),[],'all'),...
 'DAC_clipped',r.d(end,14),'max_frame_age_s',max(f(:,17)));
frame=[time body truth error energy quad pll f(:,10:13)];
end
