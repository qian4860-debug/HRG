from pathlib import Path
import json
import sys
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / 'vendor'))
import pyslang
out = HERE.parent / 'evidence'
info = {'members': dir(pyslang)}
for name in ['syntax', 'ast', 'driver']:
    obj = getattr(pyslang, name, None)
    info[name] = dir(obj) if obj else []
(out / 'pyslang_api.json').write_text(json.dumps(info, indent=2), encoding='utf-8')
print('API inspected', flush=True)