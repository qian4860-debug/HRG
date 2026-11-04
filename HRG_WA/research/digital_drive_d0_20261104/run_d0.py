"""D0独立整数golden、浮点物理代数交叉检查、原生RTL scoreboard与负对照。"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import random
import subprocess

HERE=Path(__file__).resolve().parent
FIELDS=[('rst',1),('cmd_update',1),('cmd_enable',1),('calibration_valid',1),
 ('cmd_id',32),('cmd_source_sample',32),('force_energy',20),('force_quad',20),('force_virtual',20),
 ('direction_x',18),('direction_y',18),('inverse_drive_matrix',160),('sample_en',1),
 ('sample_id',32),('carrier_cos',18),('carrier_sin',18)]
OUT_WIDTHS=[1,1,18,18,1,1,32,32,32]
def rounding(x,bits):
    magnitude=(abs(x)+(1<<(bits-1)))//(1<<bits)
    return -magnitude if x<0 else magnitude
def q(x):return math.floor(x*65536+.5) if x>=0 else -math.floor(-x*65536+.5)
def pack(values,widths):
    result=0
    for x,b in zip(values,widths):result=(result<<b)|(int(x)&((1<<b)-1))
    return result
def write_json(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
def fresh():return dict(rst=0,cmd_update=0,cmd_enable=1,calibration_valid=1,cmd_id=0,cmd_source_sample=0,
 force_energy=0,force_quad=0,force_virtual=0,direction_x=65536,direction_y=0,
 inverse_drive_matrix=[65536,0,0,65536,0,0,0,0],sample_en=1,sample_id=0,carrier_cos=65536,carrier_sin=0)

def generate():
    rng=random.Random(20261104);rows=[]
    # 明确的复位、命令同拍/下一拍、两个满量程、正负半LSB与各象限向量。
    def add(**kw):
        x=fresh();x.update(kw);rows.append(x)
    add(rst=1,cmd_update=1,force_quad=-65536,direction_x=0,direction_y=65536)
    add(cmd_update=1,cmd_id=1,force_quad=-65536,direction_x=0,direction_y=65536)
    add(sample_id=1);add(cmd_update=1,cmd_id=2,cmd_source_sample=1,force_quad=65536,direction_x=0,direction_y=65536,sample_id=2)
    add(sample_id=3)
    for value in [32768,-32768]:
        add(cmd_update=1,cmd_id=3,force_quad=value,direction_x=1,sample_id=0)
        add(sample_id=1,carrier_cos=65536)
    for angle in [0,math.pi/2,math.pi,3*math.pi/2,.37]:
        add(cmd_update=1,cmd_source_sample=0,cmd_id=9,force_energy=q(.2),force_quad=q(-.1),force_virtual=q(.05),direction_x=q(math.cos(angle)),direction_y=q(math.sin(angle)),sample_id=1)
        for phase in [0,math.pi/2,math.pi,3*math.pi/2]:add(sample_id=2,carrier_cos=q(math.cos(phase)),carrier_sin=q(math.sin(phase)))
    for stamp,ids in [(100,[99,100,180,181]),(0xfffffff0,[0xfffffff1,0,64,65])]:
        add(cmd_update=1,cmd_id=11,cmd_source_sample=stamp,sample_id=stamp,force_energy=q(.3))
        for index in ids:add(sample_id=index)
    for cal,en in [(0,1),(1,0),(1,1)]:
        add(cmd_update=1,calibration_valid=cal,cmd_enable=en,cmd_id=20,force_quad=q(.4))
        add(sample_id=1);add(sample_en=0,sample_id=2)
    # 最小Q4.16/最大Q4.16、非物理方向范围作为纯算术压力测试，不能记作物理工况。
    add(cmd_update=1,force_energy=-524288,force_quad=524287,force_virtual=-524288,
        direction_x=-131072,direction_y=131071,inverse_drive_matrix=[524287,-524288]*4)
    add(sample_id=1,carrier_cos=-131072,carrier_sin=131071)
    for k in range(6000):
        angle=rng.uniform(-math.pi,math.pi);phase=2*math.pi*(k%40)/40
        m=[rng.randint(-100000,100000) for _ in range(8)]
        add(rst=int(k%701==0),cmd_update=int(k%40==0 or k%127==0),cmd_enable=int(k%211!=0),
            calibration_valid=int(k%173!=0),cmd_id=k//40+100,cmd_source_sample=max(0,k-rng.choice([0,1,20,81])),
            force_energy=rng.randint(-524288,524287),force_quad=rng.randint(-524288,524287),force_virtual=rng.randint(-524288,524287),
            direction_x=q(math.cos(angle)),direction_y=q(math.sin(angle)),inverse_drive_matrix=m,
            sample_en=int(k%17!=0),sample_id=k,carrier_cos=q(math.cos(phase)),carrier_sin=q(math.sin(phase)))
    state=None;out=[0]*9;expected=[];max_float_code_difference=0;active_count=0
    for row in rows:
        if row['rst']:state=None;out=[0]*9
        else:
            out=out.copy();out[0]=row['sample_en']
            if row['sample_en']:
                old=state or fresh();age=(row['sample_id']-old['cmd_source_sample'])&0xffffffff
                active=int(state is not None and old['cmd_enable'] and old['calibration_valid'] and age<=80)
                out=[1,active,0,0,0,0,old['cmd_id'],row['sample_id'],age]
                if active:
                    e,qq,v=[old[n] for n in ['force_energy','force_quad','force_virtual']];ex=old['direction_x'];ey=old['direction_y'];m=old['inverse_drive_matrix']
                    fc=[rounding(-qq*ey,16),rounding(qq*ex,16)]
                    fs=[rounding(-e*ex+v*ey,16),rounding(-e*ey-v*ex,16)]
                    vr=[];vi=[]
                    for j in [0,1]:
                        a=2*j
                        vr.append(rounding(sum(m[a+i]*fc[i]+m[4+a+i]*fs[i] for i in [0,1]),16))
                        vi.append(rounding(sum(m[4+a+i]*fc[i]-m[a+i]*fs[i] for i in [0,1]),16))
                    raw=[rounding(vr[j]*row['carrier_cos']-vi[j]*row['carrier_sin'],15) for j in [0,1]]
                    out[2:4]=[min(131071,max(-131072,x)) for x in raw];out[4:6]=[int(x< -131072 or x>131071) for x in raw]
                    # 独立复数浮点算法，不调用上面的分阶段整数公式。
                    n=complex(-ey/65536,ex/65536);direction=complex(ex/65536,ey/65536)
                    freal=qq/65536*n;fimag=e/65536*direction+v/65536*n
                    force=[complex(freal.real,fimag.real),complex(freal.imag,fimag.imag)]
                    oscillator=complex(row['carrier_cos']/65536,row['carrier_sin']/65536)
                    for j in [0,1]:
                        voltage=sum(complex(m[2*j+i],m[4+2*j+i])/65536*force[i] for i in [0,1])
                        ideal=max(-131072,min(131071,(voltage*oscillator).real*131072))
                        error=abs(out[2+j]-ideal);max_float_code_difference=max(max_float_code_difference,error)
                        gain=sum(abs(m[2*j+i])+abs(m[4+2*j+i]) for i in [0,1])/65536
                        wave=(abs(row['carrier_cos'])+abs(row['carrier_sin']))/65536
                        bound=(gain+1)*wave+0.5  # stage halfLSBs referred to Q17 DAC
                        assert error<=bound+1e-7,(error,bound)
                    active_count+=1
            if row['cmd_update']:state=row.copy()
        expected.append(out.copy())
    # 在identity标定下正满量程必须夹到+131071，负满量程-131072合法且不报clip。
    assert expected[2][2:6]==[131071,0,1,0]
    assert expected[4][2:6]==[-131072,0,0,0]
    assert expected[6][3]==2 and expected[8][3]==-2  # 负/正半LSB远离0
    data=HERE/'data';data.mkdir(exist_ok=True);evidence=HERE/'evidence';evidence.mkdir(exist_ok=True)
    lines=[]
    for row,out in zip(rows,expected):
        vals=[row[n] if n!='inverse_drive_matrix' else sum((c&0xfffff)<<(20*i) for i,c in enumerate(row[n])) for n,_ in FIELDS]
        lines.append(f'{pack(vals,[b for _,b in FIELDS]):099x} {pack(out,OUT_WIDTHS):034x}\n')
    (data/'vectors.hex').write_text(''.join(lines),encoding='ascii',newline='\n')
    bad=lines.copy();left,right=bad[2].split();bad[2]=left+' '+f'{int(right,16)^(1<<100):034x}'+'\n'
    (data/'vectors_mutated.hex').write_text(''.join(bad),encoding='ascii',newline='\n')
    columns=[n for n,_ in FIELDS if n!='inverse_drive_matrix']+[f'm{i}' for i in range(8)]
    write_json(data/'matlab_vectors.json',dict(columns=columns,inputs=[[row[n] for n in columns[:-8]]+row['inverse_drive_matrix'] for row in rows],expected=expected))
    write_json(evidence/'generation.json',dict(rows=len(rows),active_samples=active_count,max_floating_code_difference=max_float_code_difference,
        analytic_stage_error_bound_passed=True,positive_negative_fullscale_checked=True,positive_negative_half_LSB_checked=True,
        seed=20261104,scope='固定标定和外部相干NCO的数字接口算术/时序测试，非机械闭环'))
    return len(rows)

def rtl(vivado):
    sim=HERE/'sim';sim.mkdir(exist_ok=True)
    def run(args,name):
        p=subprocess.run(args,cwd=sim,capture_output=True,text=True,errors='replace')
        (HERE/'evidence'/name).write_text(p.stdout+p.stderr,encoding='utf-8',newline='\n')
        return p
    for cmd,log in [([str(vivado/'xvlog.bat'),'--sv',str(HERE/'rtl/hrg_wa_drive_d0.sv'),str(HERE/'tb/tb_drive_d0.sv')],'compile.txt'),
                    ([str(vivado/'xelab.bat'),'tb_drive_d0','-s','d0_scoreboard'],'elaborate.txt')]:
        p=run(cmd,log);assert p.returncode==0,(log,p.stdout[-2000:])
    good=run([str(vivado/'xsim.bat'),'d0_scoreboard','-runall'],'rtl_scoreboard.txt')
    assert 'D0_SCOREBOARD_PASS' in good.stdout and 'Fatal:' not in good.stdout
    bad=run([str(vivado/'xsim.bat'),'d0_scoreboard','-runall','-testplusarg','MUTATE'],'mutation_detected.txt')
    assert 'D0_MISMATCH' in bad.stdout and 'D0_SCOREBOARD_PASS' not in bad.stdout
    write_json(HERE/'evidence/rtl_results.json',dict(scoreboard_passed=True,mutated_expected_output_rejected=True,
        source_sha256={str(p.relative_to(HERE)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [HERE/'rtl/hrg_wa_drive_d0.sv',HERE/'tb/tb_drive_d0.sv',HERE/'data/vectors.hex']}))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--rtl',action='store_true');args=parser.parse_args()
    count=generate()
    if args.rtl:rtl(Path('D:/vivado/2025.1/Vivado/bin'))
    print('D0 generation/independent algebra checked:',count)
