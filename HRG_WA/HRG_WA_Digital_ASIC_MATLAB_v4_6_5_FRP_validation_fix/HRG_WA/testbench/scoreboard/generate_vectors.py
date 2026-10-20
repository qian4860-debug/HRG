"""Deterministic independent integer implementation oracle + original MATLAB adapter.
No RTL simulation output is used to construct expectations. Python stdlib only.
"""
from pathlib import Path
import hashlib
import json
import math
import random
import re

HERE = Path(__file__).resolve().parent
MODEL = HERE.parents[2]
RNG = random.Random(465)

def signed(v, bits):
    return (v + (1 << (bits-1))) % (1 << bits) - (1 << (bits-1))

def div(v, d):
    return (abs(v) // d) * (-1 if v < 0 else 1)

def nearest(v,d):
    return (abs(v)+d//2)//d * (-1 if v<0 else 1)

def clamp(v, lim):
    return max(-lim, min(lim, v))

def lut(phase):
    q, idx = (phase >> 30) & 3, (phase >> 24) & 63
    if q & 1:
        idx = 63 - idx
    v = int(math.floor(131071 * math.sin((idx + .5)*math.pi/128) + .5))
    return -v if q & 2 else v

class DSP:
    def __init__(self):
        self.phase, self.co, self.si, self.count = 0, 131071, 0, 0
        self.ints = [[0]*3 for _ in range(4)]
        self.combs = [[0]*3 for _ in range(4)]
        self.fir = [[0]*4 for _ in range(4)]
        self.out = [0]*9

    def step(self, valid, x, y, fcw):
        cv, wrap = 0, 0
        if valid:
            phase = (self.phase+fcw) & 0xffffffff
            self.co=int(math.floor(abs(math.cos(phase*2*math.pi/2**32))*131071+.5)) * (-1 if math.cos(phase*2*math.pi/2**32)<0 else 1)
            self.si=int(math.floor(abs(math.sin(phase*2*math.pi/2**32))*131071+.5)) * (-1 if math.sin(phase*2*math.pi/2**32)<0 else 1)
            mixed = [nearest(a*b*512,131071) for a,b in [(x,self.co),(x,self.si),(y,self.co),(y,self.si)]]
            dec = self.count == 39
            demod = []
            for ch, value in enumerate(mixed):
                old = self.ints[ch][:]
                n0=old[0]+value; n1=old[1]+n0; n2=old[2]+n1
                self.ints[ch] = [n0,n1,n2]
                if dec:
                    c = n2
                    for j in range(3):
                        c, self.combs[ch][j] = c-self.combs[ch][j], c
                    n = nearest(c*4,64000)
                    z = self.fir[ch]
                    demod.append(nearest(nearest(n+2*z[0]+3*z[1]+2*z[2]+z[3],9),16))
                    self.fir[ch] = [n] + z[:3]
            if dec:
                a,b,c,d = demod
                inv = [a*a+b*b+c*c+d*d, 2*(a*d-c*b), a*a+b*b-c*c-d*d, 2*(a*c+b*d),2*(a*b+c*d)]
                self.out = [signed(v,28) for v in demod] + [max(-(1<<31),min((1<<31)-1,nearest(v,1<<20))) for v in inv]
                cv = 1
            self.count = (self.count+1) % 40
            phase = (self.phase+fcw) & 0xffffffff
            wrap = int(phase < self.phase)
            self.phase = phase
        return [cv,self.phase,wrap,*self.out,0]

def generate_dsp():
    d = DSP()
    rows = []
    # Reset halfway through a decimation interval; test uninterrupted valid and gaps.
    for epoch in range(2):
        d = DSP()
        rows.append([0,0,0,0,0x20000000,*d.step(0,0,0,0)])
        count = 0
        for segment in range(7):
            for n in range(1600 if epoch == 0 else 400):
                fcw = 0x20000000 if segment < 5 else (0x13abcdef if segment == 5 else 0xf1234567)
                if segment == 0:
                    x,y = 0,0
                elif segment == 1:
                    x,y = (65536 if n == 0 else 0),(-32768 if n == 0 else 0)
                elif segment == 2:
                    x,y = 65535,-32768
                elif segment == 3:
                    x = round(60000*math.cos((count+1)*math.pi/4))
                    y = round(40000*math.sin((count+1)*math.pi/4+.4))
                elif segment == 4:
                    x,y = (131071 if n%2 else -131072), (-131072 if n%3 else 131071)
                else:
                    x,y = RNG.randrange(-131072,131072), RNG.randrange(-131072,131072)
                if n % 11 == 0:
                    rows.append([1,0,12345,-54321,fcw,*d.step(0,0,0,fcw)])
                rows.append([1,1,x,y,fcw,*d.step(1,x,y,fcw)])
                count += 1
        if epoch == 0:
            for _ in range(17):
                rows.append([1,1,123,-456,0x20000000,*d.step(1,123,-456,0x20000000)])
    for _ in range(30):
        rows.append([1,0,0,0,0x20000000,*d.step(0,0,0,0)])
    (HERE/'dsp_vectors.txt').write_text(''.join(' '.join(map(str,r))+'\n' for r in rows))
    return len(rows), sum(r[5] for r in rows)

def generate_ctrl():
    from loop_reference import Controller
    oracle=Controller()
    rows=[]
    for k in range(2400):
        reset=k in (0,1201)
        update=int(k%7 != 2)
        control=[15,3,5,9,0,1,7,15][(k//40)%8]
        e=RNG.randrange(0,2<<24);q=RNG.randrange(-(1<<23),1<<23)
        if k<320:
            e=(1<<24)+(1000 if k%80<40 else -1000)
            q=500 if k%80<40 else -500
        gains=[157286,22938,458752,91750]
        if k>1600: gains=[RNG.randrange(-500000,500001) for _ in range(4)]
        virt=RNG.randrange(-(1<<27),1<<27)
        outputs=oracle.step(reset,update,control,e,q,gains,virt)
        rows.append([int(not reset),update,control,e,q,*gains,virt,*outputs])
    (HERE/'ctrl_vectors.txt').write_text(''.join(' '.join(map(str,r))+'\n' for r in rows))
    return len(rows)

def matlab_adapter():
    source=(MODEL/'HRG_WA_v46_simulate.m').read_text(encoding='utf-8-sig')
    names=['local_integer_nco_step','local_cic_update','local_fir_update','local_invariants','local_fixed_vector','local_fixed','local_clip','local_pi_aw']
    chunks=[]
    for name in names:
        matches=list(re.finditer(r'^function .*\b'+name+r'\(',source,re.M))
        assert len(matches)==1,name
        start=matches[0].start()
        end=re.search(r'^function ',source[matches[0].end():],re.M)
        stop=matches[0].end()+end.start() if end else len(source)
        chunks.append(source[start:stop])
    header='''function export_model_vectors()
% Generated adapter: below helper functions are copied verbatim from current model.
addpath(fullfile(pwd,'..','..','..'));
p=HRG_WA_v46_params();
a=readmatrix('dsp_vectors.txt','FileType','text');
f=fopen('model_vectors.txt','w'); assert(f>=0); cleanup=onCleanup(@() fclose(f));
count=0; outputs=0;
for k=1:size(a,1)
 if a(k,1)==0
  st.ncoPhaseWord=0; st.bittrueNcoWrapCount=0;
  st.cicInt=zeros(4,p.asic.cicStages); st.cicCombDelay=zeros(4,p.asic.cicStages);
  st.firDelay=zeros(4,numel(p.asic.firCoefficients));
  st.bittrueCicValidCount=0; st.bittrueFirValidCount=0; count=0;
 elseif a(k,2)
  st.ncoFrequencyHz=a(k,5)*p.sim.fsAdc/2^32;
  [co,si,st]=local_integer_nco_step(st,p,1/p.sim.fsAdc);
  adc=a(k,3:4)/2^16;
  mix=[2*adc(1)*co;2*adc(1)*si;2*adc(2)*co;2*adc(2)*si];
  [mix,~]=local_fixed_vector(mix,p.asic.mixerWordLength,p.asic.mixerFractionLength);
  count=count+1;
  [c,valid,st,~]=local_cic_update(mix,st,p,mod(count,40)==0,40);
  if valid
   [d,~,st]=local_fir_update(c,st,p);
   [d,~]=local_fixed_vector(d,p.asic.demodWordLength,p.asic.demodFractionLength);
   demod=struct('Cx',d(1),'Sx',d(2),'Cy',d(3),'Sy',d(4));
   [inv,~]=local_invariants(demod,p);
   fprintf(f,'%.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f %.0f\\n',...
    d*2^22, [inv.E;inv.Q;inv.R;inv.S;inv.L]*2^24);
   outputs=outputs+1;
  end
 end
end
fprintf('MATLAB_GOLDEN_OUTPUTS=%d\\n',outputs);
if isfile('pi_vectors.txt')
 a=readmatrix('pi_vectors.txt','FileType','text');
 fp=fopen('model_pi_vectors.txt','w');assert(fp>=0);piCleanup=onCleanup(@() fclose(fp));
 for k=1:size(a,1)
  [command,integrator]=local_pi_aw(a(k,1)/2^24,a(k,2)/2^30,a(k,3)/2^16,a(k,4)/2^16,...
   a(k,5)/2^30,a(k,6)/2^30,a(k,7),true,.001);
  fprintf(fp,'%.0f %.0f\\n',round(integrator*2^30),round(command*2^30));
 end
 fprintf('MATLAB_PI_OUTPUTS=%d\\n',size(a,1));
end
end
'''
    (HERE/'export_model_vectors.m').write_text(header+'\n'+'\n'.join(chunks),encoding='utf-8')
    return hashlib.sha256(source.encode()).hexdigest()

if __name__=='__main__':
    cycles,transactions=generate_dsp()
    manifest={'seed':465,'dsp_cycles':cycles,'dsp_transactions':transactions,'controller_cycles':generate_ctrl(),'model_source_sha256_utf8':matlab_adapter()}
    (HERE/'manifest.json').write_text(json.dumps(manifest,indent=2))
    print(json.dumps(manifest))
