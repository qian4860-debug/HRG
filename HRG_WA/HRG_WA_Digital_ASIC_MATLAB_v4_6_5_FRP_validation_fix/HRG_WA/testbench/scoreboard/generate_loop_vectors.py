from pathlib import Path
import random,json,math
from loop_reference import pi,float_pi,rnd,Controller,DPLL,Navigation

root=Path(__file__).resolve().parent
rng=random.Random(466)
def save(name,rows):
    (root/name).write_text(''.join(' '.join(map(str,r))+'\n' for r in rows))

rows=[];max_pi_error=0
for k in range(5000):
    err=rng.randrange(-(1<<31),1<<31)
    state=rng.randrange(-1610612736,1610612737)
    kp=rng.randrange(-500000,500001)
    ki=rng.choice([0,22938,91750,-22938,1<<16])
    limit=rng.choice([590558003,483183821]);bg=rng.choice([3,8,12])
    fixed=pi(err,state,kp,ki,1610612736,limit,bg)
    floating=float_pi(err/2**24,state/2**30,kp/2**16,ki/2**16,1.5,limit/2**30,bg)
    error=max(abs(fixed[0]/2**30-floating[0]),abs(fixed[1]/2**30-floating[1]))
    max_pi_error=max(max_pi_error,error)
    assert error<1e-7,(k,error)
    rows.append([err,state,kp,ki,1610612736,limit,bg,*fixed])
save('pi_vectors.txt',rows)

dpll=DPLL();rows=[]
for k in range(6000):
    reset=k in (0,3001);update=int(k%9!=5);enable=int(k%500<450);valid=int(k%100<85)
    e=rng.randrange(1342177,2<<24)
    l=rng.randrange(-(1<<30),1<<30) if k>1000 else int(.02*e*math.sin(k*.013))
    base=rng.choice([0x20000000,0x21000000,0x100]) if k>5000 else 0x20000000
    rows.append([int(not reset),update,enable,valid,e,l,base,*dpll.step(reset,update,enable,valid,e,l,base)])
save('pll_vectors.txt',rows)

nav=Navigation();rows=[];phase=0;fangle=frate=0.;anchor=False;prev=0
max_nav_angle=max_nav_rate=0.
for k in range(6000):
    reset=k in (0,3001);update=int(k%13!=5);valid=int(k%100<92);zero=int(k in (1234,4000))
    delta=rng.randrange(-40000,40001)
    if k%211==0: delta=7000000
    phase=(phase+delta+(1<<23))%(1<<24)-(1<<23)
    virt=rng.randrange(-1000000,1000001)
    bryan=0 if k%521==0 else 297426485
    alpha=rng.choice([264448425,1<<30,0])
    expected=nav.step(reset,update,valid,zero,phase,virt,bryan,alpha)[:]
    # Independent floating physical conversion and LPF, not the integer oracle.
    if reset: fangle=frate=0.;anchor=False;prev=0
    elif update:
        delta=(phase-prev+(1<<23))%(1<<24)-(1<<23)
        if zero: fangle=frate=0.;prev=phase;anchor=bool(valid)
        elif not valid or not bryan: anchor=False
        else:
            if anchor and abs(delta)<=6710886:
                increment=(-delta*90/2**24+(virt/2**22)*180/math.pi*.001)/(bryan/2**30)
                fangle+=increment
                frate+=(increment*1000-frate)*(alpha/2**30)
                frate=max(-32768.,min(32767.99998474121,frate))
            prev=phase;anchor=True
    max_nav_angle=max(max_nav_angle,abs(expected[1]/2**24-fangle))
    max_nav_rate=max(max_nav_rate,abs(expected[2]/2**16-frate))
    rows.append([int(not reset),update,valid,zero,phase,virt,bryan,alpha,*expected])
assert max_nav_angle<1e-5 and max_nav_rate<1e-4,(max_nav_angle,max_nav_rate)
save('nav_vectors.txt',rows)

controller=Controller();rows=[]
for k in range(3200):
    reset=k in (0,1601);update=int(k%11!=3)
    mode=[1,2,3,0,3][(k//100)%5];entry=int(k%100==0 and mode==3)
    ctrl=rng.choice([15,15,15,0,3,5,7,9])
    e=rng.randrange(0,2<<24);q=rng.randrange(-(1<<24),1<<24)
    gains=[157286,22938,458752,91750]
    virt=rng.randrange(-3000000,3000001);tracking=int(k%3==0)
    actual=[rng.randrange(-2500000,2500001) for _ in range(2)]
    delivered=[v+rng.randrange(-1000,1001) for v in actual]
    hold=[rng.randrange(-100000,100001) for _ in range(2)]
    expected=controller.step(reset,update,ctrl,e,q,gains,virt,mode,entry,tracking,actual,delivered,hold)
    rows.append([int(not reset),update,ctrl,e,q,*gains,virt,mode,entry,tracking,*actual,*delivered,*hold,*expected])
save('control_extended_vectors.txt',rows)
(root/'loop_manifest.json').write_text(json.dumps({'seed':466,'pi':5000,'pll':6000,'navigation':6000,'controller':3200,'pi_float_max_abs':max_pi_error,'navigation_float_max_angle_deg':max_nav_angle,'navigation_float_max_rate_dps':max_nav_rate},indent=2))
print((root/'loop_manifest.json').read_text())
