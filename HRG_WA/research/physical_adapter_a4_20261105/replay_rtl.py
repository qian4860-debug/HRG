"""把A4闭环实际端口轨迹回放到未改字节的D0 RTL；不是RTL在线机械协同仿真。"""
from pathlib import Path
import csv
import hashlib
import json
import subprocess
import sys

HERE=Path(__file__).resolve().parent;D0=HERE.parent/'digital_drive_d0_20261104'
sys.path.insert(0,str(D0))
from run_d0 import pack,FIELDS,OUT_WIDTHS

def run():
    rows=[];lines=[];last=[0]*9;previous=None
    def emit(values,out):lines.append(f'{pack(values,[b for _,b in FIELDS]):099x} {pack(out,OUT_WIDTHS):034x}\n')
    emit([1]+[0]*15,last)
    with (HERE/'data/rtl_replay.csv').open(encoding='utf-8',newline='') as f:
        for row in csv.reader(f):
            v=[int(float(x)) for x in row];assert len(v)==32
            x=v[:23];out=v[23:];matrix=sum((c&0xfffff)<<(20*i) for i,c in enumerate(x[15:23]))
            values=x[:11]+[matrix]+x[11:15]
            key=tuple(x[2:11]+x[15:23]);changed=key!=previous
            idle=values.copy();idle[1]=int(changed);idle[12]=0
            held=last.copy();held[0]=0;emit(idle,held)
            sample=values.copy();sample[1]=0;sample[12]=1;emit(sample,out)
            last=out;previous=key;rows.append(v)
    good=HERE/'data/vectors.hex';good.write_text(''.join(lines),encoding='ascii',newline='\n')
    broken=lines.copy();a,b=broken[2].split();broken[2]=a+' '+f'{int(b,16)^(1<<100):034x}'+'\n'
    (HERE/'data/vectors_mutated.hex').write_text(''.join(broken),encoding='ascii',newline='\n')
    sim=HERE/'sim';sim.mkdir(exist_ok=True);vivado=Path('D:/vivado/2025.1/Vivado/bin')
    def execute(args,name):
        p=subprocess.run(args,cwd=sim,capture_output=True,text=True,errors='replace')
        (HERE/'evidence'/name).write_text(p.stdout+p.stderr,encoding='utf-8',newline='\n');return p
    for args,name in [([str(vivado/'xvlog.bat'),'--sv',str(D0/'rtl/hrg_wa_drive_d0.sv'),str(D0/'tb/tb_drive_d0.sv')],'rtl_compile.txt'),
                      ([str(vivado/'xelab.bat'),'tb_drive_d0','-s','d0_scoreboard'],'rtl_elaborate.txt')]:
        p=execute(args,name);assert p.returncode==0,p.stdout[-1200:]
    p=execute([str(vivado/'xsim.bat'),'d0_scoreboard','-runall'],'rtl_scoreboard.txt');assert 'D0_SCOREBOARD_PASS' in p.stdout and 'Fatal:' not in p.stdout,p.stdout[-1500:]
    p=execute([str(vivado/'xsim.bat'),'d0_scoreboard','-runall','-testplusarg','MUTATE'],'rtl_mutation.txt');assert 'D0_MISMATCH row=2' in p.stdout and 'D0_SCOREBOARD_PASS' not in p.stdout
    actual=(HERE/'evidence/rtl_actual.hex').read_text(encoding='ascii').splitlines();assert len(actual)==len(lines)
    assert all(int(a,16)==int(b.split()[1],16) for a,b in zip(actual,lines))
    result=dict(physical_samples=len(rows),core_cycles=len(lines),fields=9,actual_bit_identical=True,mutation_rejected=True,
                maximum_DAC_code_difference=0,
                schedule='每载波采样前留一个无sample_en的核心时钟槽；必要时原子加载命令，bootstrap先加载再发首采样',
                scope='对闭环实际端口记录的RTL回放，不是RTL实时闭环、综合或实际DAC建立时间验收',
                source_sha256={p.relative_to(HERE.parent.parent).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [D0/'rtl/hrg_wa_drive_d0.sv',D0/'tb/tb_drive_d0.sv']})
    (HERE/'evidence/rtl_results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':run()
