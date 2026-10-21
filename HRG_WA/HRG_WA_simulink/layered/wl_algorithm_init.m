function st=wl_algorithm_init(c)
st=wl_legacy('init',c.legacyP);
st.wlAnchor=0;st.wlPhi=0;st.wlOrigin=0;st.wlAngle=0;st.wlRate=0;st.wlVirtualAngle=0;
st.wlLastTime=-1;st.wlValidCount=0;st.wlInvalidCount=0;
st.wlInformation=zeros(4);
st.thetaEstimate=0;st.thetaPrevious=0;st.kalmanState=[0;0];
st.previousActuatorOutput=zeros(3,1);
end
