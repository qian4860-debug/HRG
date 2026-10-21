function [st,correction]=wl_online_tick(t,inv,raw,commands,st,c,valid)
% Adapt V4.6.5 RLS/Joseph parameter-KF kernels to this complex-envelope plant.
% This is deliberately not a claim that old slow-variable observation units
% equal the new carrier model. Detection self-calibration remains experimental.
p=c.legacyP;Ts=c.head.Ts;E=inv.E;Q=inv.Q;theta=st.thetaEstimate;correction=0;
if ~valid || t<c.learnStartS
 st.calibPrevE=E;st.calibPrevQ=Q;st.calibPrevTheta=theta;return;
end
eDot=(E-st.calibPrevE)/Ts;qDot=(Q-st.calibPrevQ)/Ts;
delivered=[2*commands(1)*st.calibPrevE+2*commands(2)*st.calibPrevQ; ...
 2*commands(1)*st.calibPrevQ+2*commands(2)*st.calibPrevE];
angle=st.calibPrevTheta;H=[cos(4*angle) sin(4*angle) 0 0;0 0 sin(4*angle) -cos(4*angle)];
y=[-(eDot-delivered(1)+2*c.head.gamma*E)/max(E,eps); ...
 (qDot-delivered(2)+2*c.head.gamma*Q)/(2*pi*max(E,eps))];
if mod(round(t/Ts),max(1,p.calib.updateDecimation))==0
 vector=sqrt(max(E,eps))*[cos(2*theta);sin(2*theta)];
 phi=[vector(1) vector(2) 0 0;0 0 vector(1) vector(2)];
 [st.calibDetectionTheta,st.calibDetectionP]=wl_legacy('rls',st.calibDetectionTheta,st.calibDetectionP, ...
  phi,[raw.Cx;raw.Cy],p.calib.rlsLambda);
 candidate=reshape(st.calibDetectionTheta,2,2).';candidate=eye(2)+max(-.1,min(.1,candidate-eye(2)));
 st.calibDetectionMatrixHat=.99*st.calibDetectionMatrixHat+.01*candidate;
 [st.calibEkfState,st.calibEkfCovariance]=wl_legacy('parameter_kf', ...
  st.calibEkfState,st.calibEkfCovariance,H,y,p.calib.ekfProcessNoise,p.calib.ekfMeasurementNoise);
 st.calibUpdateCount=st.calibUpdateCount+1;
 st.wlInformation=st.wlInformation+H.'*H;
 st.calibDampingAnisotropyHat=min(norm(st.calibEkfState(1:2)),p.calib.maxDampingAnisotropy);
 st.calibDampingAxisHat=atan2(st.calibEkfState(2),st.calibEkfState(1))/4;
 st.calibFrequencySplitHatHz=min(norm(st.calibEkfState(3:4)),p.calib.maxFrequencySplitHz);
 st.calibStiffnessAxisHat=atan2(st.calibEkfState(4),st.calibEkfState(3))/4;
end
if st.calibUpdateCount>500 && rcond(st.wlInformation)>1e-3
 st.calibCompensationAlpha=min(.1,st.calibCompensationAlpha+.0001);
end
drift=st.calibDampingAnisotropyHat/4*sin(4*(theta-st.calibDampingAxisHat)) ...
 -pi*st.calibFrequencySplitHatHz/2*cos(4*(theta-st.calibStiffnessAxisHat))*Q/max(E,eps);
correction=st.calibCompensationAlpha*max(-2*pi/180,min(2*pi/180,drift/c.head.bryan));
st.calibPrevE=E;st.calibPrevQ=Q;st.calibPrevTheta=theta;
end
