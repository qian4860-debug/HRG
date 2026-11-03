"""共同原点的联合角噪声协方差；不删除参考帧项，不读取运动真值。"""
import numpy as np
from a3_common import SosFilter


class KernelBank:
    def __init__(self,coeff,cfg):
        n=cfg['kernel_impulse_samples'];impulse=np.zeros(n);impulse[0]=1
        m=cfg['demod_window_samples'];g=np.convolve(np.ones(m)/m,np.ones(m)/m)
        g=g*np.exp(2j*np.pi*cfg['carrier_Hz']*np.arange(len(g))/cfg['sample_rate_Hz'])
        self.kernels=[np.convolve(SosFilter(s).process(impulse),g) for s in coeff['inverse_sos']]
        self.cache={};self.cfg=cfg

    def cross(self,lag):
        lag=int(lag);assert lag>=0
        if lag not in self.cache:
            result=[]
            for a in self.kernels:
                if lag>=len(a):result.append([0.]*4);continue
                later=a[lag:];earlier=a[:len(a)-lag]
                result.append([float(later.real@earlier.real),float(later.real@earlier.imag),
                               float(later.imag@earlier.real),float(later.imag@earlier.imag)])
            self.cache[lag]=np.asarray(result)
        return self.cache[lag]


def projection(metric,cal,t,cfg):
    phi=metric['phase'];w=metric['w'];v=np.real(w*np.exp(-1j*phi[:,None]))
    norm=np.maximum(np.linalg.norm(v,axis=1),1e-30)
    perp=np.c_[-v[:,1],v[:,0]]/norm[:,None]
    c=perp@np.linalg.cholesky(cal['W']).T/norm[:,None]
    psi=2*np.pi*cfg['carrier_Hz']*np.asarray(t)+phi
    return c,psi


def covariance(bank,c,psi,sample_indices,variance,left,right):
    if left<right:left,right=right,left
    lag=sample_indices[left]-sample_indices[right];moments=bank.cross(lag)
    co1,si1=np.cos(psi[left]),np.sin(psi[left]);co2,si2=np.cos(psi[right]),np.sin(psi[right])
    value=0.
    for j,(rr,ri,ir,ii) in enumerate(moments):
        value+=4*variance[j]*c[left,j]*c[right,j]*(co1*co2*rr+co1*si2*ri+si1*co2*ir+si1*si2*ii)
    return float(value)


def relative_variance(bank,c,psi,sample_indices,variance,reference):
    n=len(c);absolute=np.array([covariance(bank,c,psi,sample_indices,variance,i,i) for i in range(n)])
    absolute=np.maximum(absolute,0);relative=np.full(n,np.nan);cross=np.full(n,np.nan)
    if reference is not None:
        for i in range(reference,n):
            cross[i]=covariance(bank,c,psi,sample_indices,variance,i,reference)
            raw=absolute[i]+absolute[reference]-2*cross[i]
            assert raw>=-1e-10*max(absolute[i]+absolute[reference],1e-30)
            relative[i]=max(0.,raw)
    return absolute,relative,cross


def reanchored_variance(bank,c,psi,indices,variance,n,anchor,origin):
    cov=lambda a,b:covariance(bank,c,psi,indices,variance,a,b)
    offset=cov(anchor,anchor)+cov(origin,origin)-2*cov(anchor,origin)
    local=cov(n,n)+cov(anchor,anchor)-2*cov(n,anchor)
    joint=cov(anchor,n)-cov(anchor,anchor)-cov(origin,n)+cov(origin,anchor)
    return offset+local+2*joint
