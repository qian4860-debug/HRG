"""SI calculation trace and independent numerical oracles for the V7 studies."""
from pathlib import Path
import hashlib
import json
import math
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
E = ROOT / 'evidence'


def calculate():
    profile = json.loads((ROOT.parent / 'literature_v7/profile.json').read_text(encoding='utf-8'))
    head = json.loads((REPO / profile['mechanicalProfile']).read_text(encoding='utf-8'))['mechanical']
    c = profile['circuit']; readout = profile['charge']
    w=2*math.pi*head['f0_hz'];m=c['massKg'];A=c['displacementM'];g=c['gapM'];B=head['bryan']
    gamma=w/(2*head['quality_factor']);k=m*w*w;kt=1.380649e-23*c['temperatureK']
    trace=[]
    def value(name,formula,substitution,result,unit):
        trace.append(dict(name=name,formula=formula,substitution=substitution,value=float(result),unit=unit))
        return result
    value('omega','2*pi*f0','2*pi*5000',w,'rad/s')
    value('gamma','omega/(2*Q)','31415.9265/(2*2000000)',gamma,'1/s')
    value('modal_stiffness','m*omega^2','1e-6*(31415.9265)^2',k,'N/m')
    value('mechanical_energy','m*omega^2*A^2/2','1e-6*31415.9265^2*(1e-7)^2/2',k*A*A/2,'J')
    Fhold=value('hold_force','m*omega^2*A/Q','986.96044*1e-7/2000000',k*A/head['quality_factor'],'N')
    value('hold_voltage','Fhold/kF',f'{Fhold}/1e-7',Fhold/c['driveNPerV'],'V')
    tb=profile['budget']['startupTimeS']
    Fstart=2*m*w*gamma*A/(-math.expm1(-gamma*tb))
    value('ideal_resonant_start_force','2*m*omega*gamma*A/(1-exp(-gamma*tb))',f'2*1e-6*{w}*{gamma}*1e-7/(1-exp(-{gamma}*{tb}))',Fstart,'N')
    value('ideal_start_voltage','Fstart/kF',f'{Fstart}/1e-7',Fstart/c['driveNPerV'],'V')
    Cpk=c['c0F']*A/g;Ipk=c['biasV']*w*Cpk
    value('capacitance_half_difference','C0*A/g','1e-12*1e-7/5e-6',Cpk,'F')
    value('sense_current','Vb*omega*Cpk',f'10*{w}*{Cpk}',Ipk,'A')
    Z=readout['rfOhm']/(1+1j*w*readout['rfOhm']*readout['cfF'])
    H=1
    for f in ['cvBandwidthHz','pgaBandwidthHz','antiAliasHz']:H/=1+1j*w/(2*math.pi*c[f])
    Vpk=Ipk*abs(Z)*readout['pgaGain']*abs(H)
    value('ADC_peak_voltage','Ipk*abs(Zf)*G*abs(Hafe)',f'{Ipk}*{abs(Z)}*1*{abs(H)}',Vpk,'V peak')
    spsi=profile['budget']['angleRmsRad'];Be=profile['budget']['noiseBandwidthHz']
    emax=2*B*Vpk*spsi/math.sqrt(2*Be)
    value('total_input_noise_allowance','2*B*Vpk*sigma_psi/sqrt(2*Be)',f'2*{B}*{Vpk}*1e-6/sqrt(200)',emax,'V/sqrt(Hz)')
    noisegain=abs(1+1j*w*(c['c0F']+readout['cfF'])*readout['rfOhm'])/abs(1+1j*w*readout['rfOhm']*readout['cfF'])
    eamp=math.hypot(noisegain*c['cvEnVrtHz'],abs(Z)*math.sqrt(c['cvInArtHz']**2+4*kt/readout['rfOhm']))
    eadc=(2*c['adcFsV']/2**c['adcBits'])/math.sqrt(6*c['fsAdc'])
    value('AFE_noise_at_ADC','sqrt((NG*en)^2+|Z|^2*(in^2+4*kT/Rf))*G*|Hafe|',f'{eamp}*{abs(H)}',eamp*abs(H),'V/sqrt(Hz)')
    value('ADC_quantizer_ASD','(2*VFS/2^N)/sqrt(6*fs)',f'(4/2^18)/sqrt(6*40000)',eadc,'V/sqrt(Hz)')
    value('ADC_white_angle_RMS','Delta/(2*B*Vpk)*sqrt(Be/(3*fs))',f'(4/2^18)/(2*{B}*{Vpk})*sqrt(100/120000)',eadc*math.sqrt(2*Be)/(2*B*Vpk),'rad')
    N=math.ceil(math.log2(2*c['adcFsV']/(2*B*Vpk*spsi)*math.sqrt(Be/(3*c['fsAdc']))))
    value('ideal_ADC_bits_for_full_noise_allowance','ceil(log2(2*VFS/(2*B*Vpk*sigma)*sqrt(Be/(3*fs))))',f'ceil(log2(4/(2*{B}*{Vpk}*1e-6)*sqrt(100/120000)))',N,'ideal bits')
    value('peak_differential_gain_residual','4*B*psi_peak','4*.277*1e-6',4*B*spsi,'relative')
    value('damping_lock_threshold','abs(dgamma)/(4*B)','0.00025/(4*.277)*180/pi*3600',head['damping_anisotropy_per_s']/(4*B)*180/math.pi*3600,'deg/h')
    Ts=profile['headSimulation']['Ts'];R=c['fsAdc']*Ts
    delay=c['cicStages']*(R-1)/(2*c['fsAdc'])+(len(c['fir'])-1)*Ts/2+(c['pipelineCtrl']+1)*Ts+(c['adcDelay']+c['dacDelay']+.5)/c['fsAdc']
    impulse=np.array([1.])
    for _ in range(c['cicStages']):impulse=np.convolve(impulse,np.ones(int(R))/R)
    upfir=np.zeros((len(c['fir'])-1)*int(R)+1);upfir[::int(R)]=c['fir']
    impulse=np.convolve(impulse,upfir)
    value('digital_chain_ENBW','fsADC/2 * sum(h_equivalent^2)',f'40000/2 * {np.sum(impulse**2)}',c['fsAdc']/2*np.sum(impulse**2),'Hz; full-window white demodulated input')
    value('chain_group_delay','CIC+FIR+registers+converters',f'0.0014625+0.002+0.004+0.0000625',delay,'s')
    value('delay_30deg_crossover_bound','1/(12*tau)',f'1/(12*{delay})',1/(12*delay),'Hz')
    wn=2*math.pi*profile['loopNaturalHz'][0];zeta=profile['dampingRatio'];E0=head['energy_target']
    kp=zeta*wn/E0;ki=wn**2/(2*E0)
    aa=2*E0*kp;bb=2*E0*ki;wc=math.sqrt((aa**2+math.sqrt(aa**4+4*bb**2))/2)
    pm=math.pi/2-math.atan(ki/(kp*wc))-wc*delay
    value('energy_Kp','zeta*wn/E0',f'.8*(2*pi*.8)/1',kp,'1/s')
    value('energy_Ki','wn^2/(2*E0)',f'(2*pi*.8)^2/2',ki,'1/s^2')
    value('energy_crossover','sqrt((a^2+sqrt(a^4+4*b^2))/2)',f'a={aa},b={bb}',wc/(2*math.pi),'Hz')
    value('energy_PI_delay_phase_margin','90deg-atan(Ki/(Kp*wc))-wc*tau',f'90-atan({ki}/({kp}*{wc}))*180/pi-{wc}*{delay}*180/pi',pm*180/math.pi,'deg; low-frequency approximation')
    rho=A/g;H3=1
    for f in ['cvBandwidthHz','pgaBandwidthHz','antiAliasHz']:H3/=1+3j*w/(2*math.pi*c[f])
    Z3=readout['rfOhm']/(1+3j*w*readout['rfOhm']*readout['cfF'])
    ratio3=rho*rho/4*3*abs(Z3)/abs(Z)*abs(H3/H)
    value('third_harmonic_at_ADC','rho^2/4 * |3Z(3w)H(3w)/(Z(w)H(w))|',f'.02^2/4*{3*abs(Z3)/abs(Z)*abs(H3/H)}',ratio3,'relative peak, cubic approximation')
    value('third_harmonic_voltage','V1*ratio3',f'{Vpk}*{ratio3}',Vpk*ratio3,'V peak')
    value('DAC_hold_peak_codes','Vhold/(2*VFS/2^N)',f'{Fhold/c["driveNPerV"]}/(4/2^16)',Fhold/c['driveNPerV']/(2*c['dacFsV']/2**c['dacBits']),'codes')
    value('AFE_equivalent_angle_RMS','eAFE*sqrt(2*Be)/(2*B*Vpk)',f'{eamp*abs(H)}*sqrt(200)/(2*{B}*{Vpk})',eamp*abs(H)*math.sqrt(2*Be)/(2*B*Vpk),'rad; approximate white narrowband')
    value('input_current_full_allowance','e_allow/(|Z|*G*|Hafe|)',f'{emax}/({abs(Z)}*{abs(H)})',emax/(abs(Z)*abs(H)),'A/sqrt(Hz); all noise assigned to current alone')
    value('Rf_thermal_lower_bound','4*kT/i_allow^2',f'4*{kt}/({emax/(abs(Z)*abs(H))})^2',4*kt/(emax/(abs(Z)*abs(H)))**2,'ohm; noise bound only, not practical R selection')
    xi=1j*w/profile['fsPlant'];P=1+xi+xi**2/2+xi**3/6+xi**4/24
    gn=-profile['fsPlant']*math.log(abs(P))
    value('RK4_numerical_damping_fraction','-fs*ln(abs(P4(j*w/fs)))/gamma',f'-800000*ln(abs(P4(j*{w}/800000)))/{gamma}',gn/gamma,'relative; ideal undamped carrier')
    # Educational ring, explicitly not a hemispherical-shell prediction.
    radius=.01;thick=1e-4;width=1e-3;young=72e9;density=2200;n=2
    area=width*thick;inertia=width*thick**3/12
    mr=density*area*math.pi*radius*(1+1/n**2);kr=math.pi*young*inertia*(n*n-1)**2/radius**3
    ring=dict(radiusM=radius,thicknessM=thick,widthM=width,youngPa=young,densityKgM3=density,
              modalMassKg=mr,modalStiffnessNPerM=kr,frequencyHz=math.sqrt(kr/mr)/(2*math.pi),
              modalAngularGain=2*n/(n*n+1),physicalBryan=2/(n*n+1),
              boundary='Inextensible slender free ring for calculation teaching; not the project HRG head')
    return dict(date='2026-10-24',status='Unmeasured design examples, not silicon requirements',
                inputProfile='../literature_v7/profile.json',trace=trace,ring=ring)


def numerical_oracles():
    checks=[]
    def check(name,error,limit):
        checks.append(dict(name=name,error=float(error),limit=limit,pass_=bool(error<=limit)))
    t=np.arange(262144)*2*np.pi/262144
    rows=[]
    for rho in [.002,.02,.08,.15]:
        y=rho*np.cos(t)/(1-rho*rho*np.cos(t)**2)
        f1=2*np.mean(y*np.cos(t));f3=2*np.mean(y*np.cos(3*t))
        s=math.sqrt(1-rho*rho);exact=rho*2/(s*(1+s))
        check(f'exact_capacitor_fundamental_{rho}',abs(f1-exact),1e-13)
        corrected=f1-3*f3
        rows.append(dict(rho=rho,fundamental=f1,third=f3,linear=rho,
                         uncorrectedRelative=f1/rho-1,correctedRelative=corrected/rho-1))
    # Force phase matters: cos^3 -> 3/4, but cos^2*sin -> 1/4.
    check('detect_cubic_factor_3_over_4',abs(2*np.mean(np.cos(t)**4)-.75),1e-14)
    check('velocity_drive_cubic_factor_1_over_4',abs(2*np.mean(np.cos(t)**2*np.sin(t)**2)-.25),1e-14)
    # Full nonlinear charge equation, exact held-C steps, small x, many periods.
    # Dimensionless q=x/g, C/C0=1/(1+q), V/Vb=charge/C.
    # Predicted ce/(C0^2*Vb^2*R/g^2) = 1/(1+(wRC0)^2), NOT 3.
    rc=[]
    for omegaRC in [.2,1.0]:
        N=32768;dt=2*math.pi/N;rho=1e-5;Q=1.;power=0.;qpower=0.
        for step in range(12*N):
            tt=(step+.5)*dt;q=rho*math.cos(tt);Cp=1/(1+q)
            Qmid=Cp+(Q-Cp)*math.exp(-dt/(2*omegaRC*Cp))
            Q=Cp+(Q-Cp)*math.exp(-dt/(omegaRC*Cp))
            voltage=Qmid/Cp;current=(1-voltage)/omegaRC
            if step>=11*N:
                power+=current**2*omegaRC;qpower+=(rho*math.sin(tt))**2
        ce=power/qpower;theory=omegaRC/(1+omegaRC**2)
        check(f'nonlinear_RC_dissipation_{omegaRC}',abs(ce/theory-1),4e-4)
        rc.append(dict(omegaRC=omegaRC,normalizedDampingNumerical=ce,normalizedDampingTheory=theory,
                       paperLowFrequencyMultiplier=3,
                       boundary='Single capacitor, ideal resistor and voltage source, local small-signal at bias equilibrium; no unspecified electrode multiplicity'))
    # Jacobian of physical angle from four IQ values, independent finite differences.
    v=np.array([.7,.3,.11,-.09]);a,b,c,d=v
    R=a*a+c*c-b*b-d*d;S=2*(a*b+c*d)
    dR=np.array([2*a,-2*b,2*c,-2*d]);dS=np.array([2*b,2*a,2*d,2*c])
    J=(R*dS-S*dR)/(4*(R*R+S*S));h=1e-6
    def angle(x):
        a,b,c,d=x;return math.atan2(2*(a*b+c*d),a*a+c*c-b*b-d*d)/4
    fd=np.array([(angle(v+np.eye(4)[i]*h)-angle(v-np.eye(4)[i]*h))/(2*h) for i in range(4)])
    check('full_IQ_angle_Jacobian',np.max(np.abs(J-fd)),1e-9)
    # Ring gyro integral, using vector mode shapes in the local radial/tangent basis.
    n=2;px=np.stack([np.cos(n*t),-np.sin(n*t)/n],1);py=np.stack([np.sin(n*t),np.cos(n*t)/n],1)
    cross_py=np.stack([-py[:,1],py[:,0]],1)
    cross=-np.mean(np.sum(px*cross_py,1));mass=np.mean(np.sum(px*px,1))
    check('ring_Bryan_modal_integral',abs(cross/mass/n-.4),1e-14)
    return dict(checks=checks,pass_=all(x['pass_'] for x in checks),
                harmonicRows=rows,resistorChargeODE=rc)


def main():
    E.mkdir(parents=True,exist_ok=True)
    budget=calculate();oracle=numerical_oracles()
    (E/'calculation_trace.json').write_text(json.dumps(budget,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (E/'derivation_scoreboard.json').write_text(json.dumps(oracle,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    lines=['# 可复算数值代入表','','这些是假设算例。完整条件、推导和单位见主文；不得直接作为实测或流片指标。','',
           '|量|公式|代入|计算值|单位|','|---|---|---|---|---|']
    for row in budget['trace']:
        lines.append('|'+ '|'.join(x.replace('|',r'\|') for x in [row['name'],row['formula'],row['substitution'],f"{row['value']:.10g}",row['unit']])+'|')
    (ROOT/'docs').mkdir(exist_ok=True)
    (ROOT/'docs/calculation_trace.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps(dict(checks=len(oracle['checks']),passed=oracle['pass_'],ring=budget['ring']),ensure_ascii=False))
    assert oracle['pass_'], 'Independent derivation oracle failed'


if __name__=='__main__':main()
