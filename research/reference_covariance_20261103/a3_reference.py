"""因果参考管理器；重锚定保留全局原点，模π歧义保持锁存，不伪造恢复。"""
import math
import numpy as np


def wrap_pi(x):return .5*math.atan2(math.sin(2*x),math.cos(2*x))


def transition(state,frame,cfg,reanchor=True):
    # state: started,lost,last_angle,last_time,tracked,origin,anchor,offset,
    #        anchor_time,count,segment,local_origin,reference_time
    s=np.asarray(state,dtype=float).copy()
    t,angle,healthy,quality,latency=frame
    event=0.;global_angle=math.nan;local=math.nan
    if healthy and t>=cfg['warmup_s']:
        if s[0]==0:
            s[:]=[1,0,angle,t,angle,angle,angle,0,t,1,0,angle,t]
            event=1.
        else:
            dt=t-s[3];assert dt>=0
            radius=cfg['maximum_modal_direction_rate_rad_s']*dt+cfg['phase_uncertainty_margin_rad']
            delta=wrap_pi(angle-s[2])
            if radius>=math.pi/2 or abs(delta)>radius:
                s[1]=1;s[10]+=1;s[4]=angle;s[11]=angle
            else:s[4]+=delta
            s[2]=angle;s[3]=t
        local=s[4]-s[11]
        if not s[1]:
            global_angle=s[7]+s[4]-s[6]
            if reanchor and t-s[8]>=cfg['reanchor_period_s']-1e-12 and t-s[12]>=cfg['reference_holdoff_s']:
                s[7]=global_angle;s[6]=s[4];s[8]=t;s[9]+=1;event=1.
            global_angle=s[7]+s[4]-s[6]
    ready=s[0] and not s[1] and healthy and t-s[12]>=cfg['reference_holdoff_s']-1e-12
    valid=bool(ready and latency and np.isfinite(quality) and quality<=cfg['angle_budget_rad'])
    output=np.array([global_angle,global_angle if valid else math.nan,float(valid),s[9],s[1],s[10],local,event,float(s[0] and not s[1])])
    return s,output


class ReferenceManager:
    def __init__(self,cfg,reanchor=True):self.state=np.zeros(13);self.cfg=cfg;self.reanchor=reanchor
    def step(self,frame):
        self.state,out=transition(self.state,frame,self.cfg,self.reanchor);return out
