"""Prevent saved MATLAB expectations being used with changed model or stimuli.
Call --record only immediately after a successful MATLAB reference export.
"""
from pathlib import Path
import hashlib,json,sys

root=Path(__file__).resolve().parent
model=root.parents[2]

def digest(text): return hashlib.sha256(text.encode('utf-8')).hexdigest()
def inputs(path,columns):
    return '\n'.join(' '.join(line.split()[:columns]) for line in path.read_text().splitlines())+'\n'

current={
    'model_source':digest((model/'HRG_WA_v46_simulate.m').read_text(encoding='utf-8-sig')),
    'model_parameters':digest((model/'HRG_WA_v46_params.m').read_text(encoding='utf-8-sig')),
    'reference_adapter':digest((root/'export_model_vectors.m').read_text(encoding='utf-8-sig')),
    'adc_inputs':digest(inputs(root/'dsp_vectors.txt',5)),
    'pi_inputs':digest(inputs(root/'pi_vectors.txt',7)),
    'adc_matlab_expected':digest(inputs(root/'model_vectors.txt',9)),
    'pi_matlab_expected':digest(inputs(root/'model_pi_vectors.txt',2)),
}
path=root/'golden_provenance.json'
if '--record' in sys.argv:
    path.write_text(json.dumps(current,indent=2))
    print('MATLAB_REFERENCE_PROVENANCE_RECORDED')
else:
    saved=json.loads(path.read_text())
    mismatches=[name for name,value in current.items() if saved.get(name)!=value]
    if mismatches:
        raise SystemExit('Saved MATLAB reference is stale ('+', '.join(mismatches)+'). Regenerate with MATLAB before running the scoreboard.')
    print('MATLAB_REFERENCE_PROVENANCE_PASS')
