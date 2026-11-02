from pathlib import Path
import json,hashlib
HERE=Path(__file__).resolve().parent;OLD=HERE.parent/'revision_v10_2_cn'
names=['tick','state','reference','sfun']
sources={}
for n in names:
    p=OLD/f'pcn_{n}.m';s=p.read_text(encoding='utf-8')
    sources[p.name]=hashlib.sha256(p.read_bytes()).hexdigest()
    for k in names:s=s.replace('pcn_'+k,'comp_'+k)
    if n=='tick':
        s=s.replace('t>=p.virtual_start_min_s && abs(sqrt(s.energy)/p.charge_target-1)<p.virtual_settle_fraction','t>=p.heading_start_s')
        s=s.replace('if p.calibrate_drive,phasor=',"% 独立辨识张量前馈：Fc-jFs=(ΔK+jωΔD)(I-jQ)。\nif p.enable_tensor_ff && s.valid\n C=s.I-1i*s.Q;h=s.heading_rate*max(0,t-s.center);R=[cos(h) -sin(h);sin(h) cos(h)];\n F=F+(p.identified_dK+1i*s.freq*p.identified_dD)*(R*C);\nend\nif p.calibrate_drive,phasor=")
    if n=='state':s=s.replace('x(32)=1;','if p.zero_start_force,x(8:11)=0;end\n x(32)=1;')
    (HERE/f'comp_{n}.m').write_text(s,encoding='utf-8',newline='\n')
(HERE/'source_hashes.json').write_text(json.dumps(sources,indent=2)+'\n',encoding='utf-8',newline='\n')
s=(HERE.parent/'nonideal_validation/stress_report.m').read_text(encoding='utf-8').replace('stress_report','comp_report').replace('root=stress_setup','root=comp_setup')
(HERE/'comp_report.m').write_text(s,encoding='utf-8',newline='\n')
