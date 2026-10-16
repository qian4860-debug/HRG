"""Summarize observed MATLAB/RTL differences and fingerprint verification inputs."""
from pathlib import Path
import collections
import csv
import hashlib
import json
import re

root=Path(__file__).resolve().parent
rows=list(csv.DictReader((root/'dsp_comparison.csv').open()))
fields=collections.defaultdict(lambda: {'mismatches':0,'max_abs_lsb':0})
transactions=set()
first=None
for row in rows:
    diff=int(row['difference_lsb'])
    if diff:
        f=fields[row['field']]
        f['mismatches']+=1
        f['max_abs_lsb']=max(f['max_abs_lsb'],abs(diff))
        transactions.add(int(row['transaction']))
        if first is None: first=row
impl=(root/'implementation_simulation.log').read_text()
strict=(root/'simulation.log').read_text()
negative=(root/'detection_simulation.log').read_text()
summary={
    'scope':'V4.6.5 sensor interface DSP/PI/CORDIC; top smoke separately',
    'implementation_pass':'IMPLEMENTATION_SCOREBOARD_PASS' in impl,
    'implementation_summary':re.search(r'SCOREBOARD_SUMMARY[^\n]+',impl)[0],
    'matlab_bit_equivalence_pass': 'MATLAB_EQUIVALENCE_PASS' in strict,
    'strict_fatal_observed':'Fatal: RTL is not bit-equivalent' in strict,
    'negative_control_detected':'IMPLEMENTATION_MISMATCH cycle=1 Cx actual=0 expected=1' in negative,
    'top_smoke_pass':'HRG_SENSOR_IF_TB PASS' in (root/'top_simulation.log').read_text(),
    'transactions_compared':len(rows)//9,
    'transactions_with_difference':len(transactions),
    'field_mismatches':sum(v['mismatches'] for v in fields.values()),
    'first_mismatch':first,
    'fields':dict(fields),
}
files=list((root.parents[1]/'src').rglob('*.v'))
files += [root/f for f in ['generate_vectors.py','export_model_vectors.m','tb_hrg_scoreboard.sv',
    'dsp_vectors.txt','ctrl_vectors.txt','model_vectors.txt']]
files += [root.parents[2]/f for f in ['HRG_WA_v46_simulate.m','HRG_WA_v46_params.m']]
summary['sha256']={str(f.relative_to(root.parents[2])):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
(root/'results.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in summary.items() if k!='sha256'},indent=2))
