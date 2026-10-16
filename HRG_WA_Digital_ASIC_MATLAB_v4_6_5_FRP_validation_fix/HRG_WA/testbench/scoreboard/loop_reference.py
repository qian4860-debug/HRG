"""Executable fixed-point contract; floating reference independently checks PI math.
All division rounds to nearest with ties away from zero. No RTL is parsed.
"""
import math

def rnd(n,d):
    if not d: return 0
    return (-1 if (n<0)!=(d<0) else 1)*((abs(n)+abs(d)//2)//abs(d))

def clip(v,limit): return max(-limit,min(limit,v))

def pi(err,state,kp,ki,ilimit,limit,bg):
    candidate=state+rnd(err*64,1000)
    limited=int(abs(candidate)>ilimit)
    candidate=clip(candidate,ilimit)
    p=rnd(err*kp,1024)
    u=p+rnd(candidate*ki,65536)
    if (u>limit and err>0) or (u< -limit and err<0):
        candidate=state
        u=p+rnd(candidate*ki,65536)
    sat=clip(u,limit)
    limited|=int(u!=sat)
    delta=rnd(bg*(sat-u)*65536,ki*1000) if ki and sat!=u else 0
    final=candidate+delta
    limited|=int(abs(final)>ilimit)
    final=clip(final,ilimit)
    return final,clip(p+rnd(final*ki,65536),limit),limited

def float_pi(err,state,kp,ki,ilimit,limit,bg):
    candidate=clip(state+err*.001,ilimit)
    u=kp*err+ki*candidate
    if (u>limit and err>0) or (u< -limit and err<0):
        candidate=state
        u=kp*err+ki*candidate
    sat=clip(u,limit)
    if ki and sat!=u: candidate+=bg*(sat-u)/ki*.001
    state=clip(candidate,ilimit)
    return state,clip(kp*err+ki*state,limit)

class Controller:
    def __init__(self):
        self.ints=[0,0];self.previous=[0,0]
        self.pipe=[[0]*3 for _ in range(3)];self.outputs=[0]*3

    def step(self,reset,update,ctrl,e,q,gains,virt,mode=3,entry=0,tracking=0,actual=(0,0),delivered=(0,0),hold=(0,0)):
        if reset:
            self.__init__();return [0,0,*self.outputs]
        if not update: return [0,0,*self.outputs]
        commands=[];states=[];limit=0
        for i,(err,kp,ki,lim,slew,bg,enabled) in enumerate([
            ((1<<24)-e,*gains[:2],590558003,8389,3,ctrl&3==3),
            (-q,*gains[2:],483183821,16777,8,ctrl&5==5)]):
            initial=self.ints[i]
            def track(state,a,b): return clip(state+rnd((a-b)*655360,ki*1000),1610612736)
            if tracking: initial=track(initial,actual[i]*256,delivered[i]*256)
            if entry: initial=clip(rnd(hold[i]*16777216,ki),1610612736)
            nxt,target,flag=pi(err,initial,kp,ki,1610612736,lim,bg)
            active=True
            if mode==1: target=375809638 if i==0 else 0;active=False
            if mode==2 and i==0 and abs(err)>1342177: target=lim if err>0 else -lim;active=False
            if not enabled or mode==0: target=0;active=False
            raw=rnd(target,256)
            if entry: raw=rnd(clip(rnd(err*kp,1024)+rnd(initial*ki,65536),lim),256)
            limited=self.previous[i]+clip(raw-self.previous[i],slew)
            if entry: limited=raw
            if not enabled or mode==0: limited=0
            final=nxt if active else initial
            if active and limited!=raw: final=track(final,limited*256,raw*256)
            if not enabled or mode==0: final=0
            commands.append(limited);states.append(final)
            limit|=int((active and flag) or limited!=raw)
        commands.append(virt if ctrl&9==9 and mode!=0 else 0)
        self.outputs=[p[-1] for p in self.pipe]
        self.pipe=[[v,*p[:2]] for v,p in zip(commands,self.pipe)]
        if entry:
            self.pipe[0]=[commands[0]]*3;self.pipe[1]=[commands[1]]*3
            self.outputs[:2]=commands[:2]
        if not ctrl&1 or mode==0:
            self.pipe=[[0]*3 for _ in range(3)];self.outputs=[0]*3
        self.ints=states;self.previous=commands[:2]
        return [1,limit,*self.outputs]

class DPLL:
    def __init__(self): self.state=0;self.fcw=0x20000000;self.flags=[1,0,0]
    def step(self,reset,update,enable,valid,e,l,base):
        if reset: self.__init__()
        elif update:
            self.flags=[int(not valid),0,0]
            if not enable: self.state=0;self.fcw=base
            elif valid:
                err=rnd(-l*(1<<24),max(e,1342177))
                self.state,correction,limited=pi(err,self.state,8<<16,35<<16,24542670263,1200<<30,12)
                self.fcw=max(0,min(0xffffffff,base+rnd(correction*(1<<32),(1<<30)*40000)))
                self.flags=[0,limited,int(abs(err)<=419430)]
        return [self.fcw,*self.flags]

class Navigation:
    def __init__(self):
        self.anchor=False;self.previous=0;self.angle=0;self.rate=0;self.outputs=[0,0,0,0,0]
    def step(self,reset,update,valid,zero,phase,virtual,bryan,alpha):
        if reset: self.__init__();return self.outputs
        if not update:
            self.outputs[0]=0;return self.outputs
        mv=int(valid and bryan!=0);fault=0
        delta=(phase-self.previous+(1<<23))%(1<<24)-(1<<23)
        if zero:
            self.angle=self.rate=0;self.outputs[1:3]=[0,0]
            self.previous=phase;self.anchor=bool(valid)
        elif not mv: self.anchor=False
        else:
            if self.anchor:
                if abs(delta)>6710886: mv=0;fault=1
                else:
                    vstep=rnd(virtual*62997375797124,4194304000)
                    step=rnd((vstep-delta*5898240)*(1<<30),bryan)
                    self.angle+=step
                    raw=rnd(step*1000,256)
                    self.rate+=rnd((raw-self.rate)*alpha,1<<30)
                    self.rate=max(-140737488355328,min(140737488289792,self.rate))
                    self.outputs[1:3]=[rnd(self.angle,65536),rnd(self.rate,65536)]
            self.anchor=True;self.previous=phase
        self.outputs=[1,*self.outputs[1:3],mv,fault]
        return self.outputs
