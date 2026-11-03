"""A2因果核心：持久SOS/滑窗状态、预畸变、白噪声传播；无真值目录入口。"""
from pathlib import Path
import sys
import math
import itertools
import numpy as np

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'port_to_metric_20261103'))
from a0_common import read_json,write_json,write_csv,sha


def bilinear_sos(zeros,poles,gain,fs,fc):
    """全部实极点的根式Tustin；系数按z^-1递增，载波fc处预畸变。"""
    k=2*np.pi*fc/np.tan(np.pi*fc/fs)
    z=[(k+x)/(k-x) for x in zeros]+[-1.]*(len(poles)-len(zeros))
    p=[(k+x)/(k-x) for x in poles]
    g=float(gain*np.prod([k-x for x in zeros])/np.prod([k-x for x in poles]))
    result=[]
    for i in range(0,len(p),2):
        b=np.pad(np.poly(z[i:i+2]),(0,3-len(z[i:i+2])-1)).astype(float)
        a=np.pad(np.poly(p[i:i+2]),(0,3-len(p[i:i+2])-1)).astype(float)
        if i==0:b*=g
        result.append(dict(b=b.tolist(),a=a.tolist()))
    return result


def response(sos,f,fs):
    z=np.exp(-2j*np.pi*np.asarray(f)/fs);h=np.ones_like(z,dtype=complex)
    for sec in sos:
        b,a=sec['b'],sec['a'];h*= (b[0]+b[1]*z+b[2]*z*z)/(a[0]+a[1]*z+a[2]*z*z)
    return h


class SosFilter:
    def __init__(self,sos):
        self.sos=sos;self.state=[[0.,0.] for _ in sos]

    def process(self,values):
        values=np.asarray(values).tolist()
        for index,sec in enumerate(self.sos):
            b0,b1,b2=sec['b'];_,a1,a2=sec['a'];s1,s2=self.state[index];out=[]
            for x in values:
                y=b0*x+s1;s1=b1*x-a1*y+s2;s2=b2*x-a2*y;out.append(y)
            self.state[index]=[s1,s2];values=out
        return np.asarray(values)


class Boxcar:
    def __init__(self,n):self.n=n;self.buffer=[0j]*n;self.index=0;self.total=0j
    def process(self,values):
        out=[]
        for x in np.asarray(values).tolist():
            self.total+=x-self.buffer[self.index];self.buffer[self.index]=x
            self.index=(self.index+1)%self.n;out.append(self.total/self.n)
        return np.asarray(out)


def design(cal,cfg):
    fs=cfg['sample_rate_Hz'];fc=cfg['carrier_Hz'];wb=2*np.pi*cfg['regularizer_cutoff_Hz'];wh=2*np.pi*cfg['washout_Hz']
    a=1/(cal['Rf']*cal['Cf']);g=1/cal['Rs']+cal['G0'];qs=cfg['charge_scale_C']
    es=[];td=[]
    for bw,tau in zip(cal['afe_bw'],cal['driver_tau']):
        lam=2*np.pi*bw
        gain=-cal['Rs']*cal['Cf']*cal['Cs']/lam*wb**3/qs
        es.append(bilinear_sos([-lam,-a,-g/cal['Cs']],[-wh,-wb,-wb,-wb],gain,fs,fc))
        td.append(bilinear_sos([],[-1/tau],1/tau,fs,fc))
    common=bilinear_sos([0],[-wh,-wb,-wb,-wb],wb**3,fs,fc)
    return dict(inverse_sos=es,driver_sos=td,common_sos=common,
        feed_charge_matrix_normalized=(np.asarray(cal['feed_charge_matrix_C_per_V'])/qs).tolist())


class CausalFrontend:
    def __init__(self,cal,cfg):
        self.coefficients=design(cal,cfg);self.cfg=cfg;self.count=0
        self.e=[SosFilter(s) for s in self.coefficients['inverse_sos']]
        self.td=[SosFilter(s) for s in self.coefficients['driver_sos']]
        self.common=[SosFilter(self.coefficients['common_sos']) for _ in range(2)]
        self.box=[[Boxcar(cfg['demod_window_samples']) for _ in range(2)] for _ in range(2)]
        self.feedbox=[[Boxcar(cfg['demod_window_samples']) for _ in range(2)] for _ in range(2)]

    def process(self,u,y):
        u=np.asarray(u);y=np.asarray(y);assert u.shape==y.shape and u.shape[1]==2
        vd=np.c_[self.td[0].process(u[:,0]),self.td[1].process(u[:,1])]
        feed=vd@np.asarray(self.coefficients['feed_charge_matrix_normalized']).T
        feed=np.c_[self.common[0].process(feed[:,0]),self.common[1].process(feed[:,1])]
        z=np.c_[self.e[0].process(y[:,0]),self.e[1].process(y[:,1])]+feed
        n=np.arange(self.count,self.count+len(y));osc=2*np.exp(-2j*np.pi*self.cfg['carrier_Hz']*n/self.cfg['sample_rate_Hz'])
        envelope=np.empty(z.shape,complex);feedenv=envelope.copy()
        for j in range(2):
            envelope[:,j]=self.box[j][1].process(self.box[j][0].process(z[:,j]*osc))
            feedenv[:,j]=self.feedbox[j][1].process(self.feedbox[j][0].process(feed[:,j]*osc))
        self.count+=len(y)
        return dict(z=z,envelope=envelope,feed_envelope=feedenv,vd=vd)


def synthesize(data,cfg,with_noise=True):
    n=int(round(cfg['duration_s']*cfg['sample_rate_Hz']));t=np.arange(n)/cfg['sample_rate_Hz']
    u=np.zeros((n,2));y=u.copy()
    for row in data['tones']:
        wave=np.exp(2j*np.pi*row['frequency_Hz']*t)[:,None]
        u+=np.real(wave*(np.asarray(row['u_re'])+1j*np.asarray(row['u_im'])))
        y+=np.real(wave*(np.asarray(row['y_re'])+1j*np.asarray(row['y_im'])))
    if with_noise:
        rng=np.random.default_rng(data['stream_noise_seed']);y+=data['stream_noise_RMS_V']*rng.standard_normal(y.shape)
    return t,u,y


def orientation(env,W):
    w=np.asarray(env)@np.linalg.cholesky(W)
    a=abs(w[:,0])**2-abs(w[:,1])**2;b=2*np.real(w[:,0]*np.conj(w[:,1]))
    angle=.5*np.unwrap(np.arctan2(b,a))
    energy=np.sum(abs(w)**2,axis=1);safe=np.maximum(energy,1e-100)
    quadrature=2*np.imag(w[:,0]*np.conj(w[:,1]))/safe
    linearity=np.sqrt(np.maximum(0,1-np.clip(quadrature,-1,1)**2))
    phase=.5*np.angle(w[:,0]**2+w[:,1]**2)
    return dict(w=w,absolute_coordinate_angle=angle,energy=energy,quadrature=quadrature,linearity=linearity,phase=phase)


def delay_seconds(cal,cfg,coeff):
    fc=cfg['carrier_Hz'];fs=cfg['sample_rate_Hz'];df=.01;delays=[]
    for j in range(2):
        f=np.array([fc-df,fc+df]);s=2j*np.pi*f
        q=-s/((cal['Cs']*s+1/cal['Rs']+cal['G0'])*cal['Rs']*cal['Cf']*(s+1/(cal['Rf']*cal['Cf'])))
        physical=q/(1+s/(2*np.pi*cal['afe_bw'][j]))
        h=response(coeff['inverse_sos'][j],f,fs)*physical
        delays.append(float(-np.angle(h[1]/h[0])/(4*np.pi*df)))
    fir=(cfg['demod_window_samples']-1)/fs
    return fir+float(np.mean(delays)),delays


def calibration_check(data,cfg):
    cal=data['calibration'];total=0.;dof=0;details=[]
    for row in data['independent_calibration_check']:
        s=2j*np.pi*row['frequency_Hz'];prediction=np.r_[1/(1+s/(2*np.pi*np.asarray(cal['afe_bw']))),cal['Cs']*s+1/cal['Rs']+cal['G0']]
        lower=[];upper=[]
        for sign in [-1,1]:
            fc=np.asarray(cal['afe_bw'])*(1+sign*cfg['calibration_AFE_relative_bound'])
            cs=cal['Cs']*(1+sign*cfg['calibration_Cs_relative_bound'])
            lower.append(np.r_[1/(1+s/(2*np.pi*fc)),cs*s+1/cal['Rs']+cal['G0']])
        extrema=np.asarray(lower);dr=np.max(abs(extrema.real-prediction.real),axis=0);di=np.max(abs(extrema.imag-prediction.imag),axis=0)
        observed=np.asarray(row['value_re'])+1j*np.asarray(row['value_im']);sigma=np.asarray(row['sigma'])
        residual=observed-prediction
        excess_r=np.maximum(0,abs(residual.real)-dr)/sigma;excess_i=np.maximum(0,abs(residual.imag)-di)/sigma
        stat=float(np.sum(excess_r**2+excess_i**2));total+=stat;dof+=6
        details.append(dict(frequency_Hz=row['frequency_Hz'],excess_statistic=stat))
    x=math.log(1/cfg['calibration_false_reject_alpha']);limit=dof+2*math.sqrt(dof*x)+2*x
    return dict(passed=bool(total<=limit),statistic=total,limit=limit,dof=dof,frequency_checks=details,
        scope='在独立高斯仪器误差、正确σ和所列校准参数界成立时的保守兼容性检查；非模型正确性证明')


def noise_upper(data,cfg):
    probe=np.asarray(data['noise_probe_V']);m=len(probe)-1;x=math.log(2/cfg['noise_upper_alpha'])
    factor=1-2*math.sqrt(x/m);assert factor>0
    return np.var(probe,axis=0,ddof=1)/factor


def noise_moments(coeff,cfg,length=16384):
    impulse=np.zeros(length);impulse[0]=1
    m=cfg['demod_window_samples'];g=np.convolve(np.ones(m)/m,np.ones(m)/m)
    g=g*np.exp(2j*np.pi*cfg['carrier_Hz']*np.arange(len(g))/cfg['sample_rate_Hz'])
    moments=[]
    for sos in coeff['inverse_sos']:
        h=SosFilter(sos).process(impulse);A=np.convolve(h,g)
        moments.append([float(A.real@A.real),float(A.imag@A.imag),float(A.real@A.imag)])
    return np.array(moments)


def angle_sigma(metrics,t,cal,cfg,coeff,variance):
    w=metrics['w'];phi=metrics['phase'];v=np.real(w*np.exp(-1j*phi[:,None]));norm=np.maximum(np.linalg.norm(v,axis=1),1e-30)
    perp=np.c_[-v[:,1],v[:,0]]/norm[:,None]
    sensitivity=perp@np.linalg.cholesky(cal['W']).T/norm[:,None]
    moments=noise_moments(coeff,cfg);phase=2*np.pi*cfg['carrier_Hz']*t+phi
    cr=np.cos(phase);si=np.sin(phase);vangle=np.zeros(len(t))
    for j,(aa,bb,ab) in enumerate(moments):
        projected=4*(aa*cr**2+bb*si**2+2*ab*cr*si)
        vangle+=variance[j]*sensitivity[:,j]**2*np.maximum(projected,0)
    return np.sqrt(vangle),moments


def corner_sensitivity(env,feedenv,cal,cfg,reference_index):
    base=orientation(env,cal['W'])['absolute_coordinate_angle'];base-=base[reference_index]
    coeff=design(cal,cfg);nom=np.array([response(s,cfg['carrier_Hz'],cfg['sample_rate_Hz']) for s in coeff['inverse_sos']])
    envelope=np.zeros(len(env))
    for signs in itertools.product([-1,1],repeat=3):
        perturbed=dict(cal);perturbed['Cs']=cal['Cs']*(1+signs[0]*cfg['calibration_Cs_relative_bound'])
        perturbed['afe_bw']=(np.asarray(cal['afe_bw'])*(1+np.asarray(signs[1:])*cfg['calibration_AFE_relative_bound'])).tolist()
        alternative=design(perturbed,cfg);ratio=np.array([response(s,cfg['carrier_Hz'],cfg['sample_rate_Hz']) for s in alternative['inverse_sos']])/nom
        adjusted=(env-feedenv)*ratio+feedenv
        angle=orientation(adjusted,cal['W'])['absolute_coordinate_angle'];angle-=angle[reference_index]
        difference=.5*np.angle(np.exp(2j*(angle-base)));envelope=np.maximum(envelope,abs(difference))
    return envelope
