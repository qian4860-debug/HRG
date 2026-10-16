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
strict=(root/'simulation.log').read_text()
impl=strict
negative=(root/'detection_simulation.log').read_text()
loop=(root/'loop_simulation.log').read_text()
top=(root/'top_scoreboard_simulation.log').read_text()
summary={
    'scope':'2026-10-16 front end, PI anti-windup, DPLL and direct navigation profile; online estimators excluded',
    'implementation_pass':'IMPLEMENTATION_SCOREBOARD_PASS' in impl,
    'implementation_summary':re.search(r'SCOREBOARD_SUMMARY[^\n]+',impl)[0],
    'matlab_bit_equivalence_pass': 'MATLAB_EQUIVALENCE_PASS' in strict,
    'strict_fatal_observed':'Fatal: RTL is not bit-equivalent' in strict,
    'negative_control_detected':'IMPLEMENTATION_MISMATCH cycle=1 Cx actual=0 expected=1' in negative,
    'top_smoke_pass':'HRG_SENSOR_IF_TB PASS' in (root/'top_simulation.log').read_text(),
    'loop_scoreboard_pass':'LOOP_SCOREBOARD_PASS' in loop and 'Fatal:' not in loop,
    'loop_summary':re.search(r'LOOP_SCOREBOARD_SUMMARY[^\n]+',loop)[0],
    'matlab_pi_max_error_q30_lsb':int(re.search(r'MATLAB_PI_MAX_ERROR_Q30_LSB=(\d+)',loop)[1]),
    'top_scoreboard_pass':'TOP_SCOREBOARD_PASS' in top and 'Fatal:' not in top,
    'top_summary':re.search(r'TOP_SCOREBOARD_SUMMARY[^\n]+',top)[0],
    'rtl_elaboration_pass':'HRG_RTL_ELABORATION_PASS' in (root/'rtl_elaboration.log').read_text(),
    'loop_numeric_checks':json.loads((root/'loop_manifest.json').read_text()),
    'top_scenario':json.loads((root/'top_manifest.json').read_text()),
    'transactions_compared':len(rows)//9,
    'transactions_with_difference':len(transactions),
    'field_mismatches':sum(v['mismatches'] for v in fields.values()),
    'first_mismatch':first,
    'fields':dict(fields),
}
files=list((root.parents[1]/'src').rglob('*.v'))
files += list(root.glob('*.py'))+list(root.glob('*.sv'))
files += list(root.glob('*.ps1'))+list(root.glob('*.tcl'))
files += list((root/'evidence_20261016').glob('*.txt'))
files += [root/f for f in ['export_model_vectors.m','dsp_vectors.txt','ctrl_vectors.txt','model_vectors.txt',
    'pi_vectors.txt','model_pi_vectors.txt','pll_vectors.txt','nav_vectors.txt','control_extended_vectors.txt']]
files += [root.parents[2]/f for f in ['HRG_WA_v46_simulate.m','HRG_WA_v46_params.m']]
summary['sha256']={str(f.relative_to(root.parents[2])):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
(root/'results.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in summary.items() if k!='sha256'},indent=2))
assert summary['implementation_pass'] and summary['matlab_bit_equivalence_pass']
assert summary['loop_scoreboard_pass'] and summary['top_scoreboard_pass'] and summary['top_smoke_pass']
assert summary['negative_control_detected'] and summary['rtl_elaboration_pass']
