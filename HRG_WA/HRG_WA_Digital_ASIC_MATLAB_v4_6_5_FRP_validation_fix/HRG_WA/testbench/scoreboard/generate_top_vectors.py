"""Cycle-accurate independent integrated oracle + a separate slow-variable plant.
Actual DUT outputs are never used to generate expectations or ADC stimulus.
CTRL=0x3f: all loops, DPLL and hardware STARTUP/ACQUIRE/RUN enabled.
"""
from pathlib import Path
import math,json
from generate_vectors import DSP
from loop_reference import Controller,DPLL,Navigation,rnd

root=Path(__file__).resolve().parent
def signed(v,bits): return (v+(1<<(bits-1)))%(1<<bits)-(1<<(bits-1))
ATAN=[67108864,39616676,20932363,10625595,5333416,2669308,1334980,667531,333770,166886,83443,41722,20861,10430,5215,2608,1304,652]
class Cordic:
    def __init__(self): self.x=self.y=self.z=self.it=self.busy=self.valid=self.angle=0
    def step(self,start,x,y):
        self.valid=0
        if start and not self.busy:
            self.it=0;self.busy=1
            if x<0: self.x=signed(-x,32);self.y=signed(-y,32);self.z=268435456 if y>=0 else -268435456
            else: self.x=x;self.y=y;self.z=0
        elif self.busy:
            x,y,z=self.x,self.y,self.z
            sign=1 if y>=0 else -1
            self.x=signed(x+sign*(y>>self.it),32)
            self.y=signed(y-sign*(x>>self.it),32)
            self.z=signed(z+sign*ATAN[self.it],30)
            if self.it==17: self.angle=signed(self.z>>5,24);self.valid=1;self.busy=0
            else: self.it+=1

class Top:
    def __init__(self):
        self.dsp=DSP();self.pll=DPLL();self.ctrl=Controller();self.nav=Navigation();self.cordic=Cordic()
        self.ds=[0]*13;self.cs=[0]*5;self.dacs=[0]*3;self.actual=[0]*3;self.delivered=[0]*2
        self.saturated=0;self.snapshot=[0,0,0];self.status=0;self.mode=1;self.ticks=0;self.count=0
    def step(self,reset,valid,x,y):
        if reset:
            self.__init__();return [0,0,0,0,0,0,0,0x20000000,1,0]
        ds=self.ds[:];cs=self.cs[:];pv,pzero,pvirt=self.snapshot[:]
        _,_,_,cx,sx,cy,sy,e,q,r,s,l,overflow=ds
        measurement=int(e>=1342178 and r*r+s*s>1801439850948 and not overflow)
        enter=int(self.mode==2 and self.ticks>=499 and 15435039<=e<=18119393 and abs(q)<=503316 and self.pll.flags[2])
        current_mode=3 if enter else self.mode
        phase_valid=self.cordic.valid;phase=self.cordic.angle
        if phase_valid: self.status=0x00c00001|(0x40 if pv else 0x40000)|(0x10 if overflow else 0)|(0x400 if cs[1] else 0)|(0x800 if self.pll.flags[0] else 0)
        nav=self.nav.step(False,phase_valid,pv,pzero,phase,pvirt,297426485,264448425)[:]
        if phase_valid: self.status=(self.status & 0xfffbffbf)|(0x40 if nav[3] else 0x40000)|(0x20 if nav[4] else 0)
        if ds[0]: self.snapshot=[measurement,enter,self.actual[2]]
        self.cordic.step(ds[0],r,s)
        old_actual=self.actual[:];old_delivered=self.delivered[:];old_sat=self.saturated
        if cs[0]:
            full=[2516582,2097152,2928177]
            codes=[rnd(v*32768,f) for v,f in zip(cs[2:],full)]
            self.dacs=[max(-32768,min(32767,v)) for v in codes]
            self.actual=[rnd(v*f,32768) for v,f in zip(self.dacs,full)]
            self.delivered=cs[2:4];self.saturated=int(any(v>32767 or v< -32768 for v in codes[:2]))
        self.cs=self.ctrl.step(False,ds[0],31,e,q,[157286,22938,458752,91750],0,current_mode,enter,old_sat,old_actual[:2],old_delivered,[65884,0])
        old_fcw=self.pll.fcw
        self.pll.step(False,ds[0],1,measurement,e,l,0x20000000)
        if ds[0]:
            self.count+=1;self.ticks=min(0xffffffff,self.ticks+1)
            if self.mode==1 and self.ticks>=250: self.mode=2;self.ticks=0
            if enter: self.mode=3;self.ticks=0
        self.ds=self.dsp.step(valid,x,y,old_fcw)
        return [*self.dacs,nav[0],nav[1],nav[2],self.status,self.pll.fcw,self.mode,self.count]

if __name__=='__main__':
    top=Top();energy=.25;quad=.015;theta=8*math.pi/180;carrier=0.;rate=0.
    mode_seen=set();freeze=0;nav_count=0;run_at=None;rows=0;run_reference_angle=0.
    with (root/'top_vectors.txt').open('w') as f:
        output=top.step(True,0,0,0);f.write(' '.join(map(str,[0,0,0,0,*output]))+'\n');rows+=1
        for n in range(160000):
            carrier=(carrier+2*math.pi*5001.5/40000)%(2*math.pi)
            a=math.sqrt(max(1e-10,(energy+math.sqrt(max(0,energy*energy-quad*quad)))/2))
            b=quad/(2*a)
            x=(a*math.cos(2*theta)*math.cos(carrier)-b*math.sin(2*theta)*math.sin(carrier))
            y=(a*math.sin(2*theta)*math.cos(carrier)+b*math.cos(2*theta)*math.sin(carrier))
            if 80000<=n<80400: x=y=0 # detection dropout, then reacquisition
            x=max(-131072,min(131071,rnd(round(x*2**40),1<<24)))
            y=max(-131072,min(131071,rnd(round(y*2**40),1<<24)))
            out=top.step(False,1,x,y)
            f.write(' '.join(map(str,[1,1,x,y,*out]))+'\n');rows+=1
            mode_seen.add(top.mode);freeze+=top.pll.flags[0];nav_count+=out[3]
            if top.mode==3 and run_at is None: run_at=n/40000
            if n%40==39:
                # Independent Euler mechanical model; virtual=0 in this scenario.
                energy=max(1e-8,energy+.001*(-2*math.pi*5000/2e6*energy+top.actual[0]/2**22))
                quad+=.001*(-2*math.pi*5000/2e6*quad+top.actual[1]/2**22)
                rate=80. if n>=60000 else 0.
                theta+=.001*(-.277*rate*math.pi/180)
            if n%7==0:
                out=top.step(False,0,1234,-5678)
                nav_count+=out[3]
                f.write(' '.join(map(str,[1,0,1234,-5678,*out]))+'\n');rows+=1
        for _ in range(30):
            out=top.step(False,0,0,0)
            nav_count+=out[3]
            f.write(' '.join(map(str,[1,0,0,0,*out]))+'\n');rows+=1
    result={'cycles':rows,'control_updates':top.count,'navigation_outputs':nav_count,'mode_seen':sorted(mode_seen),'run_entry_seconds':run_at,
        'final_plant_energy':energy,'final_plant_quad':quad,'final_expected_rate_dps':out[5]/2**16,
        'final_expected_fcw_hz':top.pll.fcw*40000/2**32,'dropout_samples':400}
    assert mode_seen=={1,2,3},result
    assert abs(energy-1)<.08 and abs(quad)<.03 and abs(out[5]/2**16-80)<1,result
    (root/'top_manifest.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
