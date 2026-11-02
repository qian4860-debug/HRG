from pathlib import Path
import json,hashlib
HERE=Path(__file__).resolve().parent;OLD=HERE.parent/'compensation_research'
sources={}
for name in ['tick','state','reference','sfun']:
    src=OLD/f'comp_{name}.m';sources[src.name]=hashlib.sha256(src.read_bytes()).hexdigest();s=src.read_text(encoding='utf-8')
    for k in ['tick','state','reference','sfun']:s=s.replace('comp_'+k,'sn_'+k)
    if name=='tick':
        s=s.replace('s.frame_end;s.center;s.available;s.sat;s.frame_clip;s.cp;age;s.frame_dac_clip];','s.frame_end;s.center;s.available;s.sat;s.frame_clip;s.cp;age;s.frame_dac_clip;s.iq_history(:,1);s.raw_valid];')
        s=s.replace(' s.I=real(z);'," [s,z]=sn_smooth(s,z,p,condition,s.window_clip||s.window_dac_clip||~s.finite_window);\n s.I=real(z);")
        s=s.replace('s.window_clip||s.window_dac_clip||~s.finite_window,condition);','s.window_clip||s.window_dac_clip||~s.finite_window||~s.raw_valid,condition);')
    if name=='state':
        s=s.replace('控制状态的35维','控制状态的165维（原35维加128维IQ历史、填充数及原始有效标志），').replace('(35).','(前35维).')
        s=s.replace(' x(32)=1;',' x(32)=1;x=[x;zeros(130,1)];')
        s=s.replace("'heading_rate',v(35));","'heading_rate',v(35));\n x.iq_history=reshape(v(36:163),4,32);x.history_count=v(164);x.raw_valid=v(165);")
        s=s.replace('s.heading_rate];','s.heading_rate;s.iq_history(:);s.history_count;s.raw_valid];')
    if name=='sfun':s=s.replace('Dimensions=18','Dimensions=23').replace('Dimensions=35','Dimensions=165')
    if name=='reference':
        s=s.replace('zeros(N,18)','zeros(N,23)')
        s=s.replace("stream=RandStream", "r.clean=zeros(N,4);clean=zeros(4,1);acc=zeros(4,1);\nstream=RandStream")
        s=s.replace('for k=1:N','for k=1:N\n if isempty(s),phase=0;else,phase=s.phase;end\n r.clean(k,:)=clean\';acc=acc+2*[x(1:2)*cos(phase);x(1:2)*sin(phase)];')
        s=s.replace("r.adc(k,:)=adc';x=", "r.adc(k,:)=adc';if mod(k,round(p.Tc/p.Ts))==0,clean=acc/round(p.Tc/p.Ts);acc(:)=0;end;x=")
    (HERE/f'sn_{name}.m').write_text(s,encoding='utf-8',newline='\n')
s=(HERE.parent/'nonideal_validation/stress_report.m').read_text(encoding='utf-8').replace('stress_report','sn_report').replace('root=stress_setup','root=sn_setup')
(HERE/'sn_report.m').write_text(s,encoding='utf-8',newline='\n')
s=(HERE.parent/'quality_dashboard/quality_sfun.m').read_text(encoding='utf-8').replace('quality_sfun','sn_quality_sfun').replace('Dimensions=18','Dimensions=23')
(HERE/'sn_quality_sfun.m').write_text(s,encoding='utf-8',newline='\n')
(HERE/'source_hashes.json').write_text(json.dumps(sources,indent=2)+'\n',encoding='utf-8',newline='\n')
