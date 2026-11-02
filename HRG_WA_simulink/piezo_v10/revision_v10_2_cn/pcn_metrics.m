function [m,frame]=pcn_metrics(r,p)
% 按每个完整窗口的源中心时刻评分，每帧只计一次。
% 断效区间之间不跨段unwrap，不根据真值选择偏置、延迟或分支。
% 扣除实际施加的Cp历史积分，而不是扣除请求值。
% 稳态评分取后40%时段；body角误差由驻波角误差除B得到。
% 短确定性记录不用于声称ARW或真实零偏稳定性；未知B时不输出机体角精度。
% Score each completed frame once, at SOURCE WINDOW CENTER, never use the
% ideal truth to choose an angle branch or optimize a delay/offset.
% 【中文步骤】按帧号取首次发布样本，消除保持40拍造成的伪重复评分。
d=r.d;ix=find(d(:,9)>0 & [true;diff(d(:,9))~=0]);f=d(ix,:);times=f(:,12);
valid=logical(f(:,8))&~logical(f(:,18));N=f(:,1).^2+f(:,3).^2-f(:,2).^2-f(:,4).^2;
M=2*(f(:,1).*f(:,2)+f(:,3).*f(:,4));beta=NaN(size(times));
% Restart unwrapping after every invalid interval; do not bridge lost cycles.
% 【中文步骤】每个有效片段单独解包驻波角。
segments=cumsum([true;~valid(1:end-1)|~valid(2:end)]);
for id=unique(segments(valid))'
 j=find(segments==id&valid);beta(j)=unwrap(atan2(M(j),N(j)))/4;
end
% 【中文步骤】按实际Cp逐拍积分，并插值到源窗口中心。
cp=d(:,16);virtualPhase=[0;cumsum(cp(1:end-1)*p.Ts)];vp=interp1(r.t,virtualPhase,times,'linear');
if isempty(p.B),assert(p.Omega==0);truth=ones(size(times))*p.theta0/2;
else,truth=(p.theta0-2*p.B*p.Omega*times)/2;end
betaCorrected=beta-vp/2;err=betaCorrected-truth;
% 【中文步骤】只对有效稳态帧计算误差，完整记录仍保留启动过程。
hold=valid & times>.6*p.duration;
m=struct('total_frames',numel(times),'valid_frames',sum(valid),'valid_fraction',mean(valid),...
 'angle_status','unavailable','angle_rms_deg',NaN,'pattern_rms_deg',NaN,...
 'energy_relative_mean',NaN,'quadrature_rms',NaN,'pll_phase_rms',NaN,...
 'bias_deg_s',NaN,'rate_noise_status','not_estimated_from_deterministic_short_run',...
 'dac_margin_V',p.vmax-max(abs(r.u),[],'all'),'dac_clip_samples',d(end,14),...
 'build_time_s',NaN,'timestamp_max_age_s',max(f(:,17)));
if nnz(hold)>=3
 m.angle_status='valid_center_timestamped_frames';m.pattern_rms_deg=sqrt(mean(err(hold).^2))*180/pi;
 if ~isempty(p.B),m.angle_rms_deg=m.pattern_rms_deg/abs(p.B);end
 E=f(:,6);m.energy_relative_mean=mean(E(hold))/p.charge_target^2-1;
 L=f(:,1).*f(:,4)-f(:,2).*f(:,3);m.quadrature_rms=sqrt(mean((2*L(hold)./E(hold)).^2));
 m.pll_phase_rms=sqrt(mean(((f(hold,1).*f(hold,3)+f(hold,2).*f(hold,4))./E(hold)).^2));
 if ~isempty(p.B)
  j=find(hold);good=diff(j)==1;dt=diff(times(j));de=diff(err(j));
  if any(good),m.bias_deg_s=-mean(de(good)./dt(good))/p.B*180/pi;end
 end
 target=valid&abs(sqrt(E)/p.charge_target-1)<.05;
 for k=find(times>.05,1):numel(times)
  if all(target(k:end)),m.build_time_s=times(k);break;end
 end
end
frame=table(times,valid,beta,betaCorrected,truth,err,f(:,10),f(:,11),f(:,13),...
 'VariableNames',{'source_center_s','angle_valid','beta_rad','beta_corrected_rad','ideal_beta_rad','error_rad','window_start_s','window_end_s','available_s'});
end
