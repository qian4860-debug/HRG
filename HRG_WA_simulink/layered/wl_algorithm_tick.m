function [st,y]=wl_algorithm_tick(t,iq,T,virtual,permit,commands,st,c,saturated)
% Only public ADC I/Q, temperature, known commands, and fixture permission.
% No mechanical truth or true external rate is an input to this adapter.
p=c.legacyP;Ts=c.head.Ts;
if nargin<9,saturated=false;end
raw=struct('Cx',iq(1),'Cy',iq(2),'Sx',iq(3),'Sy',iq(4));
if c.matrixApply && c.online
 a=st.calibCompensationAlpha;M=(1-a)*eye(2)+a*st.calibDetectionMatrixHat;
 if rcond(M)>1e-6,iq=[M\iq(1:2);M\iq(3:4)];end
end
iqc=wl_invariants(iq);
valid=~saturated && iqc(5)>c.head.energyThreshold && hypot(iqc(7),iqc(8))>c.head.angleThreshold && all(isfinite(iqc));
phi=atan2(iqc(8),iqc(7));thetaRate=0;
if valid
 if st.wlAnchor
  delta=atan2(sin(phi-st.wlPhi),cos(phi-st.wlPhi));
  if abs(delta)<.8*pi,st.thetaEstimate=st.thetaEstimate+delta/4;thetaRate=delta/(4*Ts);else,valid=false;end
 else
  st.thetaEstimate=phi/4;st.wlOrigin=st.thetaEstimate;st.kalmanState=[st.thetaEstimate;0];
 end
 st.wlPhi=phi;st.wlAnchor=double(valid);
else,st.wlAnchor=0;end
if c.kalman
 [st,~]=wl_legacy('kalman',st,st.thetaEstimate,valid,p,Ts);
 thetaRate=st.kalmanState(2);
end
rawRate=-thetaRate/c.head.bryan-virtual;
correction=0;
inv=struct('E',iqc(5),'Q',iqc(6),'R',iqc(7),'S',iqc(8),'L',iqc(9));
demod=struct('Cx',iq(1),'Cy',iq(2),'Sx',iq(3),'Sy',iq(4));
st.previousActuatorOutput=[commands(1:2);virtual];
flags=struct('rawDemod',raw);
if c.online
 % Old online block is preserved; its full identifiability is tested separately.
 [st,correction]=wl_online_tick(t,inv,raw,commands,st,c,valid);
end
if ~c.compensationApply,correction=0;end
[~,active,stable,direction]=wl_legacy('schedule',t,p);
frpCorrection=0;
if c.frp
 % Zero-rate condition is an external fixture permit, never plant truth.
 [st,frpCorrection]=wl_legacy('frp',st,p,st.thetaEstimate,T,thetaRate,rawRate, ...
  logical(permit)&&valid,valid,active,stable,direction);
 if c.compensationApply,correction=correction+frpCorrection;end
end
if c.temperatureCompensate
 dt=T-25;b=c.temperatureBiasCoefficients;correction=correction-(b(1)+b(2)*dt+b(3)*dt^2);
end
if valid
 if st.wlLastTime>=0
  st.wlVirtualAngle=st.wlVirtualAngle+virtual*Ts;
  st.wlAngle=st.wlAngle+(rawRate+correction)*Ts;
 end
 alpha=1-exp(-Ts/c.head.rateTau);st.wlRate=st.wlRate+alpha*(rawRate+correction-st.wlRate);
 st.wlValidCount=st.wlValidCount+1;
else,st.wlInvalidCount=st.wlInvalidCount+1;end
st.wlLastTime=t;
nav=[st.wlAngle;st.wlRate;double(valid);st.thetaEstimate];
diag=[rawRate;correction;st.kalmanUpdateCount;st.kalmanRejectCount;st.calibUpdateCount; ...
 st.frpUpdateCount;st.frpCoverageFraction;st.frpConfidence;st.frpCompensationAlpha; ...
 st.wlValidCount;st.wlInvalidCount;st.calibCompensationAlpha];
if ~valid,iqc(5)=0;iqc(7:8)=0;end % Same invalid status gates PI and PLL, not just navigation.
y=[iqc;nav;diag;st.frpThetaHat];
end
