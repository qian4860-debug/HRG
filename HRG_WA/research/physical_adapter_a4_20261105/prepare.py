"""从已验收sn_tick生成隔离控制分支，仅替换DAC接口，不改旧源字节。"""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
p=ROOT/'HRG_WA_simulink/piezo_v10/noise_research/sn_tick.m'
s=p.read_text(encoding='utf-8');old='raw=real(phasor*exp(1i*s.phase));[u,~,dacclip]=pcn_quantize(raw,p.dac_span,p.dac_bits,p.vmax);'
assert s.count(old)==1
s=s.replace('function [s,u,d]=sn_tick(s,adc,p,c)','function [s,u,d]=a4_control_tick(s,adc,p,c)',1).replace(old,'[u,dacclip]=a4_drive(s,p,c);',1)
(HERE/'a4_control_tick.m').write_text(s,encoding='utf-8',newline='\n')
(HERE/'source_provenance.json').write_text(json.dumps(dict(source=p.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),
    substitutions=['function name','one DAC synthesis line replaced by a4_drive; actual clip feeds original control state']),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('isolated controller generated; old source untouched')
