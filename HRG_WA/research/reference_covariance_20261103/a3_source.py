"""重建公开压缩端口流；故障在采样检测端注入，有效性标志同拍可见。"""
import numpy as np
from a3_common import synthesize


def stream(data,cfg,with_noise=True):
    t,u,clean=synthesize(data,cfg,with_noise=False);y=clean.copy()
    if with_noise:
        rng=np.random.default_rng(data['stream_noise_seed']);sigma=data['stream_noise_RMS_V']
        if data.get('noise_model','white')=='white':noise=sigma*rng.standard_normal(y.shape)
        else:
            rho=data['noise_rho'];x=rng.standard_normal((len(t)+4096,2));state=np.zeros(2);allnoise=[]
            for v in x:
                state=rho*state+np.sqrt(1-rho*rho)*sigma*v;allnoise.append(state.copy())
            noise=np.asarray(allnoise[4096:])
        y+=noise
    acquired=np.ones(len(t),bool)
    for start,end in data.get('sensor_invalid_intervals_s',[]):
        bad=(t>=start)&(t<end);acquired[bad]=False;y[bad]=0.
    return t,u,y,acquired
