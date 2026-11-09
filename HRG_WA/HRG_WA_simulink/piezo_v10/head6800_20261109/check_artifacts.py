"""Check the delivered native model files, source dependency hashes and receipts."""
from pathlib import Path
import hashlib,json,zipfile,xml.etree.ElementTree as ET
root=Path(__file__).resolve().parent
sources=json.loads((root/'sources.json').read_text(encoding='utf-8'))
for item in sources['legacy_dependencies']:
 assert hashlib.sha256((root/item['path']).read_bytes()).hexdigest()==item['sha256'],item
receipt=json.loads((root/'verification.json').read_text(encoding='utf-8'))
assert receipt['status']=='passed'
assert len(receipt['nominal'])==9 and len(receipt['sensitivity'])==8 and len(receipt['faults'])==9
assert json.loads((root/'rate_sweep.json').read_text())['status']=='passed'
assert json.loads((root/'physics_checks.json').read_text())['passed']
parameters=json.loads((root/'parameter_summary.json').read_text())
assert parameters[0]['head']==parameters[1]['head']==parameters[2]['head']
for row in parameters:
 assert row['gain_check']['drive_pre_V_per_V']==row['gain_check']['sense_pre_V_per_V']
for model in sorted((root/'models').glob('*.slx')):
 types=[]
 with zipfile.ZipFile(model) as z:
  assert not any('stateflow' in n and n.endswith('.xml') for n in z.namelist())
  for name in z.namelist():
   if name.startswith('simulink/systems/') and name.endswith('.xml'):
    tree=ET.fromstring(z.read(name));types.extend(b.get('BlockType') for b in tree.findall('.//Block'))
 assert not set(types)&{'S-Function','MATLABFcn','MATLABSystem','FromWorkspace'},model
 print(model.name,len(types),'native blocks')
assert len(list((root/'models').glob('*.slx')))==3
for file in root.glob('*.m'):
 data=file.read_bytes();assert not data.startswith(b'\xef\xbb\xbf');data.decode('utf-8')
 print(file.name,hashlib.sha256(data).hexdigest()[:16])
print('Artifact checks passed')
