"""Independent numerical worksheet keyed to R00--R39 in the V2 book."""
from pathlib import Path
import argparse,csv,json,math
from fractions import Fraction as F
import numpy as np

HERE=Path(__file__).resolve().parents[1]
EV=HERE/'evidence'
records={};checks=[]
def value(name,x,unit,formula):
    records[name]=dict(value=float(x),unit=unit,formula=formula)
    return x
def test(name,error,limit=1e-12):
    error=float(np.max(np.abs(error)))
    checks.append(dict(name=name,error=error,limit=limit,pass_=bool(np.isfinite(error) and error<=limit)))
def oscillator(p,t):
    w0=2*np.pi*p['f0_hz'];w=2*np.pi*p['forced_frequency_hz'];g=w0/(2*p['quality_factor'])
    force=p['mass_kg']*w0*w0*p['amplitude_m']/p['quality_factor']
    f=force/p['mass_kg'];D=w0*w0-w*w;b=2*g*w;wd=np.sqrt(w0*w0-g*g)
    u=f*D/(D*D+b*b);v=-f*b/(D*D+b*b);C=-v;S=(-u*w+g*C)/wd
    P=-g*C+wd*S;T=-g*S-wd*C
    co=np.cos(wd*t);si=np.sin(wd*t);e=np.exp(-g*t)
    x=u*np.sin(w*t)+v*np.cos(w*t)+e*(C*co+S*si)
    vel=u*w*np.cos(w*t)-v*w*np.sin(w*t)+e*(P*co+T*si)
    acc=-w*w*(u*np.sin(w*t)+v*np.cos(w*t))+e*((-g*P+wd*T)*co+(-g*T-wd*P)*si)
    return x,vel,acc,dict(u=u,v=v,C=C,S=S,D=D,b=b,wd=wd,force=force)

def retain_intermediates(p):
    """Publish the primitive arithmetic, not only the final engineering numbers."""
    pi=np.pi;w=2*pi*p['f0_hz'];gam=w/(2*p['quality_factor']);m=p['mass_kg'];A=p['amplitude_m'];B=p['bryan']
    _,_,_,q=oscillator(p,np.array([0.]))
    extra={
      'R02_drive_omega':(2*pi*p['forced_frequency_hz'],'rad/s','2*pi*forced_frequency_hz'),
      'R02_force':(q['force'],'N','m*omega0^2*Aref/Qm'),
      'R02_force_acceleration':(q['force']/m,'m/s^2','force/m'),
      'R02_D':(q['D'],'1/s^2','omega0^2-drive_omega^2'),
      'R02_b':(q['b'],'1/s^2','2*gamma*drive_omega'),
      'R02_denominator':(q['D']**2+q['b']**2,'1/s^4','D^2+b^2'),
      'R02_damped_omega':(q['wd'],'rad/s','sqrt(omega0^2-gamma^2)'),
      'R02_homogeneous_P':(-gam*q['C']+q['wd']*q['S'],'m/s','-gamma*C+wd*S'),
      'R02_homogeneous_T':(-gam*q['S']-q['wd']*q['C'],'m/s','-gamma*S-wd*C')}
    zf=p['rf_ohm']/(1+1j*w*p['rf_ohm']*p['cf_f']);ng=1+1j*w*p['cin_f']*zf
    ha=math.prod(1/math.sqrt(1+(p['f0_hz']/f)**2) for f in p['analog_poles_hz'])
    extra['R11_omega_Rf_Cf']=(w*p['rf_ohm']*p['cf_f'],'1','omega0*Rf*Cf')
    extra['R11_noise_gain']=(abs(ng),'1','abs(1+j*omega0*Ci*Zf)')
    extra['R11_pre_filter_voltage']=(records['R11_current_peak']['value']*abs(zf),'V','Ipeak*abs(Zf)')
    for i,fp in enumerate(p['analog_poles_hz'],1):
        extra['R11_pole_'+str(i)+'_magnitude']=(1/math.sqrt(1+(p['f0_hz']/fp)**2),'1','1/sqrt(1+(f0/fpole)^2)')
        extra['R11_pole_'+str(i)+'_phase_deg']=(-math.atan(p['f0_hz']/fp)*180/pi,'deg','-atan(f0/fpole)')
    delta=records['R13_ADC_step']['value'];allow=records['R13_allowed_ASD']['value'];qe=1.602176634e-19
    extra.update({
      'R13_ADC_variance':(delta**2/12,'V^2','Delta^2/12'),
      'R13_ADC_ASD':(delta/math.sqrt(6*p['adc_rate_hz']),'V/sqrt(Hz)','Delta/sqrt(6*fs)'),
      'R12_one_electron_current_ASD':(qe*w,'A/sqrt(Hz)','qe*omega0'),
      'R13_charge_allowance':(allow/(ha*w*abs(zf)),'C/sqrt(Hz)','eADC/(Ha*omega0*abs(Zf))'),
      'R13_charge_allowance_electrons':(allow/(ha*w*abs(zf)*qe),'electron/sqrt(Hz)','charge_allowance/qe'),
      'R15_phase_step':(2*pi/2**32,'rad','2*pi/2^32'),
      'R15_sample_phase_deg':(360*5000/40000,'deg','360*f0/fs'),
      'R17_impulse_squared_sum':(records['R17_ENBW']['value']*2/40000,'1','sum(h^2)'),
      'R17_CIC_delay':(3*39/(2*40000),'s','N*(R-1)/(2*fs)'),
      'R17_FIR_delay':(2/1000,'s','(L-1)/(2*fctrl)'),
      'R17_support_time':(3*39/40000+4/1000+4/1000+1/40000,'s','CICsupport+FIRsupport+pipeline+ADC'),
      'R17_delay_crossover_bound':(1/(12*records['R17_delay']['value']),'Hz','1/(12*tau)')})
    hold=m*w*w*A/p['quality_factor'];start=2*m*w*gam*A/(-math.expm1(-gam*.1))
    wn=2*pi*.8;kp=records['R19_Kp']['value'];ki=records['R19_Ki']['value'];wc=records['R20_crossover_hz']['value']*2*pi
    extra.update({
      'R18_mechanical_energy':(m*w*w*A*A/2,'J','m*w0^2*A^2/2'),
      'R18_loss_power':(m*gam*w*w*A*A,'W','2*gamma*mechanical_energy'),
      'R18_hold_force':(hold,'N','m*w0^2*A/Qm'),
      'R18_start_force':(start,'N','2*m*w0*gamma*A/(1-exp(-gamma*tb))'),
      'R18_DAC_step':(4/2**16,'V','4/2^16'),
      'R18_start_over_hold':(start/hold,'1','Fstart/Fhold'),
      'R18_start_20percent_v':(start/p['drive_n_per_v']/.2,'V','Vstart/duty'),
      'R19_natural_omega':(wn,'rad/s','2*pi*fn'),
      'R20_a':(2*kp,'1/s','2*E0*Kp'),'R20_b':(2*ki,'1/s^2','2*E0*Ki'),
      'R20_crossover_omega':(wc,'rad/s','positive root of gain=1 equation'),
      'R20_PI_phase_loss_deg':(math.atan(ki/(kp*wc))*180/pi,'deg','atan(Ki/(Kp*wc))'),
      'R20_delay_phase_loss_deg':(wc*records['R17_delay']['value']*180/pi,'deg','wc*tau*180/pi'),
      'R23_predicted_P11':(1+4*.001**2,'rad^2','1+4*Ts^2'),
      'R23_predicted_P12':(4*.001,'rad^2/s','4*Ts'),
      'R23_innovation_variance':(1+4*.001**2+.01,'rad^2','P11+R'),
      'R24_Gram_determinant':(2*2-1*1,'1','2*2-1*1'),
      'R25_scalar_gain':(200/401,'1','200/(1+2*100*2)'),
      'R25_scalar_beta':(1200/401,'1','K*y'),
      'R25_scalar_covariance':(100/401,'1','1/(.01+2^2)'),
      'R26_theta_rate':(-B*80*pi/180,'rad/s','-B*Omega'),
      'R26_false_over_true':(records['R26_false_damping']['value']/records['R26_true_ds']['value'],'1','false_ds/true_ds'),
      'R29_fault_frequency_x':(math.sqrt(w*w-2000)/(2*pi),'Hz','sqrt(omega0^2-20*100)/(2*pi)'),
      'R29_fault_frequency_y':(math.sqrt(w*w-1200)/(2*pi),'Hz','sqrt(omega0^2-12*100)/(2*pi)'),
      'R30_omega_RC':(w*2e5*.025e-12,'1','omega0*R*C0'),
      'R30_electrical_damping':(100*(5e-9)**2*2e5/(1+(w*2e5*.025e-12)**2),'kg/s','Vb^2*p^2*R/(1+(omega*R*C0)^2)'),
      'R31_Gram_min_eigenvalue':(1-1/math.sqrt(2),'1','1-1/sqrt(2)'),
      'R31_Gram_max_eigenvalue':(1+1/math.sqrt(2),'1','1+1/sqrt(2)'),
      'R33_decoded_frequency':(records['R33_FCW_6200']['value']*40000/2**32,'Hz','FCW*fs/2^32'),
      'R33_decoded_frequency_error':(records['R33_FCW_6200']['value']*40000/2**32-6200,'Hz','decoded-requested')})
    ar=1.
    for k in range(1,4):
        ar-=(ar+.05*ar**3-1)/(1+.15*ar*ar)
        extra['R28_Newton_step_'+str(k)]=(ar,'1','a_next=a-f(a)/fprime(a); beta=.05,r=1')
    for name,(x,unit,formula) in extra.items():value(name,x,unit,formula)
    # The new full-ellipse and nonlinear-measurement derivations are tested directly.
    J=np.array([[0.,-1.],[1.,0.]]);aa=1.2;bb=.23;theta=.18;phi=.31;om=.8
    nn=np.array([np.cos(2*theta),np.sin(2*theta)]);tt=J@nn
    Gam=np.array([[.07,.012],[.012,.04]]);HH=np.array([[.2,-.03],[-.03,-.1]]);hh=np.array([.01+.02j,-.04+.01j])
    zz=np.exp(1j*phi)*(aa*nn+1j*bb*tt);zd=-Gam@zz+1j*HH@zz-2*B*om*J@zz+hh
    wn=nn@(np.exp(-1j*phi)*zd);wt=tt@(np.exp(-1j*phi)*zd);sep=aa*aa-bb*bb
    Gnn=nn@Gam@nn;Gtt=tt@Gam@tt;Gnt=nn@Gam@tt;Hnn=nn@HH@nn;Htt=tt@HH@tt;Hnt=nn@HH@tt
    hn=nn@(np.exp(-1j*phi)*hh);ht=tt@(np.exp(-1j*phi)*hh)
    expanded=np.array([-aa*Gnn-bb*Hnt+hn.real,-bb*Gtt+aa*Hnt+ht.imag,
       (aa*aa*Hnn-bb*bb*Htt-2*aa*bb*Gnt+aa*hn.imag+bb*ht.real)/sep,
       -B*om+(-(aa*aa+bb*bb)*Gnt+aa*bb*(Hnn-Htt)+bb*hn.imag+aa*ht.real)/(2*sep)])
    projected=np.array([wn.real,wt.imag,(aa*wn.imag+bb*wt.real)/sep,(bb*wn.imag+aa*wt.real)/(2*sep)])
    test('R09_full_expanded_dynamics',expanded-projected)
    st=np.array([.6,-.4,.1,.2]);rx,ry,ix,iy=st
    Hm=np.array([[2*rx,2*ry,2*ix,2*iy],[2*iy,-2*ix,-2*ry,2*rx],[2*rx,-2*ry,2*ix,-2*iy],[2*ry,2*rx,2*iy,2*ix]])
    def meas(st):
        rx,ry,ix,iy=st;return np.array([rx*rx+ry*ry+ix*ix+iy*iy,2*(rx*iy-ix*ry),rx*rx+ix*ix-ry*ry-iy*iy,2*(rx*ry+ix*iy)])
    Hfd=np.column_stack([(meas(st+ep)-meas(st-ep))/(2e-6) for ep in np.eye(4)*1e-6])
    test('R23_nonlinear_measurement_jacobian',Hm-Hfd,1e-10)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check-matlab',action='store_true');args=parser.parse_args()
    p=json.loads((HERE/'parameters.json').read_text())
    pi=np.pi;w=2*pi*p['f0_hz'];g=w/(2*p['quality_factor']);m=p['mass_kg'];A=p['amplitude_m'];B=p['bryan']
    value('R01_omega0',w,'rad/s','2*pi*f0')
    value('R02_gamma',g,'1/s','omega0/(2*Qm)')
    value('R02_stiffness',m*w*w,'N/m','mass*omega0^2')
    t=np.linspace(0,p['oscillator_duration_s'],3001)
    x,v,a,c=oscillator(p,t)
    for k in ('u','v','C','S'):value('R02_'+k,c[k],'m','forced sin/cos and homogeneous coefficients')
    test('R02_initial_position',x[0]/A,1e-12);test('R02_initial_velocity',v[0]/(A*w),1e-12)
    rhs=c['force']/m*np.sin(2*pi*p['forced_frequency_hz']*t)
    test('R02_differential_residual',(a+2*g*v+w*w*x-rhs)/(c['force']/m),1e-11)
    # Exact rational algebra of the coefficient solve, independent of floating rounding.
    for D in (F(-3),F(0),F(2,3)):
        b=F(5,2);f=F(7,3);u=f*D/(D*D+b*b);vv=-f*b/(D*D+b*b)
        test('R02_fraction_sin_'+str(D),float(D*u-b*vv-f),0)
        test('R02_fraction_cos_'+str(D),float(b*u+D*vv),0)
    Dy=3.2;by=.8;fc=-.27;q1=fc*Dy/(Dy*Dy+by*by);q2=fc*by/(Dy*Dy+by*by)
    test('R03_cos_coefficient',Dy*q1+by*q2-fc);test('R03_sin_coefficient',-by*q1+Dy*q2)
    J=np.array([[0.,-1.],[1.,0.]])
    beta=.17;R=np.array([[np.cos(beta),-np.sin(beta)],[np.sin(beta),np.cos(beta)]])
    K=R@np.diag([2.,3.])@R.T
    test('R04_rotation_xx',K[0,0]-(2*np.cos(beta)**2+3*np.sin(beta)**2))
    test('R04_rotation_xy',K[0,1]-(2-3)*np.cos(beta)*np.sin(beta))
    r=np.array([.34,-.8]);test('R05_coriolis_power',r@J@r)
    n=2;rho=2200;Ac=.001*.0001;I=.001*.0001**3/12;radius=.01;young=72e9
    ringm=rho*Ac*pi*radius*(1+1/n**2);ringk=pi*young*I*(n*n-1)**2/radius**3
    value('R06_ring_mass',ringm,'kg','rho*Ac*pi*radius*(1+1/n^2)')
    value('R06_ring_stiffness',ringk,'N/m','pi*E*I*(n^2-1)^2/radius^3')
    value('R06_ring_frequency',np.sqrt(ringk/ringm)/(2*pi),'Hz','sqrt(k/m)/(2*pi)')
    value('R06_ring_B',2/(n*n+1),'1','2/(n^2+1)')
    for theta in np.linspace(-1,1,9):
        for aa,bb,phi in ((1,.1,.3),(.7,-.2,-.4)):
            nn=np.array([np.cos(2*theta),np.sin(2*theta)]);z=np.exp(1j*phi)*(aa*nn+1j*bb*J@nn)
            E=np.vdot(z,z).real;Q=2*(np.conj(z[0])*z[1]).imag
            RR=abs(z[0])**2-abs(z[1])**2;SS=2*(np.conj(z[0])*z[1]).real
            test('R08_invariants_'+str(theta)+'_'+str(bb),[E-aa*aa-bb*bb,Q-2*aa*bb,RR-(aa*aa-bb*bb)*np.cos(4*theta),SS-(aa*aa-bb*bb)*np.sin(4*theta)])
            test('R08_energy_identity_'+str(theta)+'_'+str(bb),E*E-Q*Q-RR*RR-SS*SS)
    # Full chain rule: synthesize derivative from arbitrary a_dot,b_dot,phi_dot,theta_dot.
    aa=1.2;bb=.23;theta=.18;phi=.31;ad=.04;bd=-.03;pd=.2;td=-.4
    nn=np.array([np.cos(2*theta),np.sin(2*theta)]);tt=J@nn
    dz=np.exp(1j*phi)*((ad+1j*aa*pd-2j*bb*td)*nn+(2*aa*td-bb*pd+1j*bd)*tt)
    wn=nn@(np.exp(-1j*phi)*dz);wt=tt@(np.exp(-1j*phi)*dz)
    test('R09_full_ellipse_chain_rule',[(aa*wn.imag+bb*wt.real)/(aa*aa-bb*bb)-pd,(bb*wn.imag+aa*wt.real)/(2*(aa*aa-bb*bb))-td])
    value('R09_dead_zone_deg_h',p['damping_difference_s']/(4*B)*180/pi*3600,'deg/h','dgamma/(4*B)')
    cap=p['capacitance_f']*A/p['gap_m'];current=p['bias_v']*w*cap
    value('R10_capacitance_peak',cap,'F','C0*A/gap');value('R11_current_peak',current,'A','Vb*omega0*Cpeak')
    s=1j*w;zf=p['rf_ohm']/(1+s*p['rf_ohm']*p['cf_f']);ng=1+s*p['cin_f']*zf
    ha=math.prod(1/math.sqrt(1+(p['f0_hz']/fp)**2) for fp in p['analog_poles_hz'])
    vp=current*abs(zf)*ha
    value('R11_Zf_magnitude',abs(zf),'ohm','Rf/sqrt(1+(omega*Rf*Cf)^2)')
    value('R11_analog_magnitude',ha,'1','product of three analog pole magnitudes')
    value('R11_ADC_peak',vp,'V','Ipeak*abs(Zf)*abs(Hanalog)')
    gain=120+35j;transfer=-zf/(1+ng/gain);iin=.07+1j*.02;vo=transfer*iin;vn=-vo/gain
    test('R11_finite_A_KCL',abs((s*p['cin_f']*vn+(vn-vo)/zf-iin)/iin),1e-13)
    kt=1.380649e-23*p['temperature_k'];ir=math.sqrt(4*kt/p['rf_ohm'])
    eno=abs(ng)*p['en_v_rtHz'];ino=abs(zf)*p['in_a_rtHz'];rno=abs(zf)*ir
    afe=math.sqrt(eno**2+ino**2+rno**2)
    for key,val,unit in [('R12_Rf_current_ASD',ir,'A/sqrt(Hz)'),('R12_voltage_noise',eno,'V/sqrt(Hz)'),('R12_current_noise',ino,'V/sqrt(Hz)'),('R12_resistor_noise',rno,'V/sqrt(Hz)'),('R12_AFE_ASD',afe,'V/sqrt(Hz)')]:value(key,val,unit,'R12 node transfer and independent PSD sum')
    allowed=2*B*vp*p['angle_budget_rad']/math.sqrt(2*p['noise_bandwidth_hz'])
    delta=2*p['adc_half_range_v']/2**p['adc_bits'];adcangle=delta/(2*B*vp)*math.sqrt(p['noise_bandwidth_hz']/(3*p['adc_rate_hz']))
    value('R13_allowed_ASD',allowed,'V/sqrt(Hz)','2*B*Vpk*angle/sqrt(2*Be)')
    value('R13_ADC_step',delta,'V','2*VFS/2^N');value('R13_ADC_angle',adcangle,'rad','Delta/(2*B*Vpk)*sqrt(Be/(3*fs))')
    value('R13_ideal_bits',math.ceil(math.log2(delta*2**p['adc_bits']/(2*B*vp*p['angle_budget_rad'])*math.sqrt(p['noise_bandwidth_hz']/(3*p['adc_rate_hz'])))),'bits','R13.3')
    value('R13_gain_error_deg',p['gain_error']/(4*B)*180/pi,'deg','epsilon/(4*B)')
    # Derivative checked by independent finite differences of the actual angle function.
    zz=np.array([.71,.13,-.46,.19]);xx,uu,yy,vv=zz;RR=xx*xx+uu*uu-yy*yy-vv*vv;SS=2*(xx*yy+uu*vv)
    jac=-np.array([RR*yy-SS*xx,RR*vv-SS*uu,RR*xx+SS*yy,RR*uu+SS*vv])/(2*B*(RR*RR+SS*SS))
    def angle(z):
        xx,uu,yy,vv=z;return -np.arctan2(2*(xx*yy+uu*vv),xx*xx+uu*uu-yy*yy-vv*vv)/(4*B)
    fd=[]
    for j in range(4):
        ep=np.eye(4)[j]*1e-6;fd.append((angle(zz+ep)-angle(zz-ep))/(2e-6))
    test('R13_angle_jacobian_finite_difference',jac-fd,2e-10)
    P=.3-.2j;AA=2+.1j;C=1.1+.4j;FF=.7-.3j;fd=.4;nF=.2;nA=.1;nV=.07
    L=P*AA*C*FF;Scl=1/(1+L);y=P*Scl*(fd+nF+nA)-P*FF*C*Scl*nV;vout=AA*y+nV;u=-C*vout
    test('R14_closed_loop_node_equation',y-P*(fd+FF*u+nF+nA))
    value('R15_NCO_FCW',round(5000/40000*2**32),'code','round(f/fs*2^32)')
    value('R15_NCO_step_hz',40000/2**32,'Hz','fs/2^32')
    value('R15_skew_limit',1e-4/w,'s','Q/E budget / omega0')
    I1=I2=I3=0;old=np.zeros(3,dtype=int);out=[]
    for k in range(12):
        I1+=1;I2+=I1;I3+=I2
        if k%2:
            val=I3
            for j in range(3):new=val-old[j];old[j]=val;val=new
            out.append(val)
    test('R16_CIC_small_hand_trace',np.array(out)-[4,8,8,8,8,8],0)
    box=np.ones(40)/40;hc=np.convolve(np.convolve(box,box),box);hf=np.zeros(161);hf[::40]=np.array([1,2,3,2,1])/9
    h=np.convolve(hc,hf);enbw=40000/2*np.sum(h*h)
    value('R17_ENBW',enbw,'Hz','fs/2*sum(h^2)');value('R17_delay',.0014625+.002+.004+.0000625,'s','CIC+FIR+pipeline+converters')
    hold=m*w*w*A/p['quality_factor'];start=2*m*w*g*A/(-math.expm1(-g*.1))
    value('R18_hold_voltage',hold/p['drive_n_per_v'],'V','m*w0^2*A/(Q*kF)')
    value('R18_start_voltage',start/p['drive_n_per_v'],'V','2*m*w0*gamma*A/((1-exp(-gamma*tb))*kF)')
    value('R18_start_denominator',-math.expm1(-g*.1),'1','1-exp(-gamma*.1)')
    value('R18_DAC_hold_codes',hold/p['drive_n_per_v']/(4/2**16),'code','Vhold/DACstep')
    kp=.8*2*pi*.8;ki=(2*pi*.8)**2/2;aa=2*kp;bb=2*ki;wc=math.sqrt((aa*aa+math.sqrt(aa**4+4*bb*bb))/2)
    value('R19_Kp',kp,'1/s','zeta*wn/E0');value('R19_Ki',ki,'1/s^2','wn^2/(2*E0)')
    value('R20_crossover_hz',wc/(2*pi),'Hz','R20 gain=1 equation')
    value('R20_phase_margin_deg',90-math.atan(ki/(kp*wc))*180/pi-wc*records['R17_delay']['value']*180/pi,'deg','90-atan(Ki/(Kp*wc))-wc*tau')
    alpha=.2;Om=.01;Hz=alpha/(np.exp(1j*Om)-1);Happrox=alpha/(1j*Om)
    test('R21_SC_low_frequency_limit',abs(Hz/Happrox-1),.006)
    poles=np.roots([1,3,3,1+3**3]);expected=np.array([-4,.5+1j*3*math.sqrt(3)/2,.5-1j*3*math.sqrt(3)/2])
    test('R21_ring_poles',np.sort_complex(poles)-np.sort_complex(expected),1e-13)
    def wrap(x):return np.arctan2(np.sin(x),np.cos(x))
    test('R22_wrap_crossing',wrap(-3.1-3.1)-(.08318530717958605),1e-14)
    Ts=.001;Fk=np.array([[1,Ts],[0,1]]);Pm=Fk@np.diag([1.,4.])@Fk.T;Kk=Pm[:,0]/(Pm[0,0]+.01)
    value('R23_gain_angle',Kk[0],'1','P11/(P11+R)');value('R23_gain_rate',Kk[1],'1/s','P21/(P11+R)')
    X=np.array([[1.,0,1],[0,1,1]]);DD=np.array([[1,.02],[-.01,1.01]]);Y=DD@X
    fit=np.linalg.lstsq(X.T,Y.T,rcond=None)[0].T;test('R24_external_reference_fit',fit-DD)
    PP=np.eye(2)*100;beta0=np.zeros(2);beta=beta0.copy();Sinfo=np.linalg.inv(PP);binfo=Sinfo@beta0;lam=.997
    for i in range(1,101):
        ph=np.array([1.,np.sin(i*.31)]);yy=ph@np.array([.3,-.7]);gain=PP@ph/(lam+ph@PP@ph)
        beta=beta+gain*(yy-ph@beta);PP=(PP-np.outer(gain,ph)@PP)/lam
        Sinfo=lam*Sinfo+np.outer(ph,ph);binfo=lam*binfo+ph*yy
    test('R25_RLS_vs_weighted_batch',beta-np.linalg.solve(Sinfo,binfo),1e-12)
    test('R25_information_inverse',PP@Sinfo-np.eye(2),1e-12)
    value('R26_false_damping',2*p['gain_error']*B*80*pi/180,'1/s','-2*epsilon*theta_dot')
    value('R26_true_ds',p['damping_difference_s']/2*math.sin(4*p['damping_axis_rad']),'1/s','d*sin(4*beta)')
    # Cubic inverse: compare residual, and explicitly test one-step subtraction error.
    for tr in (.001,.01,.05):
        rr=1.;bet=tr;ar=rr
        for k in range(3):ar-= (ar+bet*ar**3-rr)/(1+3*bet*ar*ar)
        test('R28_Newton_residual_'+str(tr),ar+bet*ar**3-rr,4e-16)
    ar=.8;bet=.1;rr=ar+bet*ar**3;tt=bet*ar*ar
    test('R28_one_step_error_identity',(rr-bet*rr**3)/ar-(1-3*tt*tt-3*tt**3-tt**4))
    value('R29_false_split_mHz',(math.sqrt(w*w-1200)-math.sqrt(w*w-2000))/(2*pi)*1000,'mHz','exact effective stiffness eigenfrequencies')
    for V in (10.,12.):test('R29_reference_equivalence_'+str(V),(w*w+20*100-20*V*V)-(w*w-20*(V*V-100)),0)
    pp=5e-9;RR=2e5;C0=.025e-12;ce=100*pp*pp*RR/(1+(w*RR*C0)**2)
    Ipk=w*10*pp*A/math.sqrt(1+(w*RR*C0)**2)
    test('R30_passive_power_balance',(Ipk*Ipk*RR/2-ce*w*w*A*A/2)/(ce*w*w*A*A/2),1e-14)
    gram=np.array([[1.5,-.5],[-.5,.5]]);value('R31_Gram_condition',np.linalg.cond(gram),'1','(1+1/sqrt(2))/(1-1/sqrt(2))')
    value('R31_pump_threshold_v',m*w*w*p['gap_m']**2/(4*p['quality_factor']*p['capacitance_f']*10),'V','m*w0^2*g^2/(4*Q*C0*V0)')
    def qround(n,r):return (1 if n>=0 else -1)*((abs(n)+(1<<(r-1)))>>r)
    test('R32_ties_away_positive',qround(3,1)-2,0);test('R32_ties_away_negative',qround(-3,1)+2,0)
    value('R32_IQ_bound',math.sqrt(2)*2**-22/(4*B),'rad','sqrt(2)*DeltaIQ/(4*B*sqrt(E))')
    code=round(6200/40000*2**32);value('R33_FCW_6200',code,'code','round(6200/40000*2^32)')
    test('R33_little_endian',int.from_bytes(bytes([0x7b,0x14,0xae,0x27]),'little')-code,0)
    value('R33_Bryan_03_code',round(.3*2**30),'code','round(.3*2^30)')
    value('R33_Eref_12_code',round(1.2*2**24),'code','round(1.2*2^24)')
    dg=.00025;d=dg/2;beta=.17;Ab=np.array([[np.cos(4*beta),np.sin(4*beta)],[np.sin(4*beta),-np.cos(4*beta)]])
    omega=2*B*80*pi/180;Cmat=-d*Ab-omega*J
    test('R35_traceless_matrix_square',Cmat@Cmat-(d*d-omega*omega)*np.eye(2))
    for fs in (400000,800000):
        rr=w/fs;poly=1+1j*rr-rr*rr/2-1j*rr**3/6+rr**4/24
        test('R35_RK4_magnitude_identity_'+str(fs),abs(poly)**2-(1-rr**6/72+rr**8/576),3e-16)
        value('R35_num_damping_ratio_'+str(fs),-fs*.5*math.log1p(-rr**6/72+rr**8/576)/g,'1','-fs/2*log1p(-r^6/72+r^8/576)/gamma')
    e=np.array([.1,.7,-.4,.2]);test('R36_RMS_decomposition',np.mean(e*e)-np.mean(e)**2-np.var(e))
    arr=np.array([1.,2.,3.,4.]);test('R36_Allan_hand',.5*np.mean(np.diff(arr)**2)-.5,0)
    retain_intermediates(p)
    if args.check_matlab:
        other=json.loads((EV/'matlab_results.json').read_text())
        for key,val in other['values'].items():
            target=records[key]['value'];scale=max(abs(target),1e-20)
            test('MATLAB_checkpoint_'+key,(val-target)/scale,2e-10)
        dat=np.loadtxt(EV/'matlab_oscillator.csv',delimiter=',',skiprows=1);xp,vp,_,_=oscillator(p,dat[:,0])
        test('MATLAB_ODE_position_vs_independent_closed_form',(dat[:,1]-xp)/A,2e-8)
        test('MATLAB_ODE_velocity_vs_independent_closed_form',(dat[:,2]-vp)/(A*w),2e-8)
        for name,result in other['checks'].items():test('MATLAB_executed_'+name,0 if result else 1,0)
    EV.mkdir(exist_ok=True)
    report=dict(date='2026-10-27',pass_=all(c['pass_'] for c in checks),check_matlab=args.check_matlab,
                statement='New derivation/ODE worksheet only; no new full RF or RTL runs',values=records,checks=checks)
    (EV/'python_results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    with (EV/'trace.csv').open('w',encoding='utf-8',newline='') as f:
        wr=csv.writer(f,lineterminator='\n');wr.writerow(['checkpoint','value','unit','formula'])
        for key,r in records.items():wr.writerow([key,format(r['value'],'.16g'),r['unit'],r['formula']])
    print(json.dumps(dict(pass_=report['pass_'],checks=len(checks),checkpoints=len(records),matlab_compared=args.check_matlab)))
    for c in checks:
        if not c['pass_']:print(c)
    raise SystemExit(0 if report['pass_'] else 1)

if __name__=='__main__':main()
