"""Preserve the accepted report formulas/thresholds; change output location only."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent;src=HERE.parent/'quality_dashboard/quality_report.m'
s=src.read_text(encoding='utf-8').replace('function report=quality_report(out,p,visible)','function report=stress_report(out,p,visible,caseid)')
s=s.replace('root=quality_setup;if nargin<3,visible=true;end',"root=stress_setup;if nargin<3,visible=true;end;if nargin<4,caseid='manual';end")
s=s.replace("folder=fullfile(root,'evidence');","folder=fullfile(root,'evidence',caseid);")
(HERE/'stress_report.m').write_text(s,encoding='utf-8',newline='\n')
(HERE/'report_source.json').write_text(json.dumps({'source':'quality_dashboard/quality_report.m','sha256':hashlib.sha256(src.read_bytes()).hexdigest()},indent=2)+'\n',encoding='utf-8',newline='\n')
