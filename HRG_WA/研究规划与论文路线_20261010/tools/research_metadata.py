"""Publisher-deposited Crossref metadata; save successful records and failures."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import urllib.request
import urllib.parse
OUT = Path(__file__).resolve().parent.parent / 'evidence' / 'web'
OUT.mkdir(exist_ok=True)
DOIS = [
    '10.1109/TIM.2025.3650265', '10.1109/TIM.2025.3555670',
    '10.1109/TIM.2026.3674286', '10.1109/TIM.2026.3667313',
    '10.1109/TII.2026.3698512', '10.1016/j.ast.2025.111283',
    '10.1038/s41378-026-01321-1', '10.3390/mi17010143',
    '10.1016/j.sna.2025.116976', '10.1016/j.measurement.2024.115599',
    '10.3390/act14060275', '10.1016/j.ijmecsci.2026.111465',
    '10.1016/j.ymssp.2025.113228', '10.1007/s11071-026-12837-6',
    '10.1109/TIM.2026.3704236', '10.1109/TIM.2026.3682829',
    '10.1109/JSEN.2026.3728523', '10.1016/j.measurement.2026.121170',
    '10.1063/5.0268634',
]
QUERIES = [
    'hemispherical resonator gyroscope whole angle',
    'The Electrode Nonlinearity Error Suppression of Hemispherical Resonator Gyro Under Whole-Angle Mode',
    'Asymmetric Phase-Delay Modeling and Online Compensation for Whole-Angle Micro-Hemispherical Resonator Gyroscopes',
    'Modeling Characterization Compensation Detection Errors Differential Frequency Modulation Whole Angle',
]
def fetch(task):
    key, url = task
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'HRG-research-audit/1.0', 'Accept': 'application/json'})
        with urllib.request.urlopen(req, timeout=45) as r:
            obj = json.load(r)
        (OUT / (key + '.json')).write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding='utf-8')
        return {'key': key, 'url': url, 'status': 'ok'}
    except Exception as exc:
        return {'key': key, 'url': url, 'status': 'failed', 'error': str(exc)}
tasks = [(d.replace('/', '_'), 'https://api.crossref.org/works/' + urllib.parse.quote(d, safe='/')) for d in DOIS]
tasks += [('search_' + str(i), 'https://api.crossref.org/works?query.bibliographic=' + urllib.parse.quote(q)
           + '&filter=from-pub-date:2025-01-01,until-pub-date:2026-10-10&rows=12') for i, q in enumerate(QUERIES)]
with ThreadPoolExecutor(max_workers=4) as pool:
    status = list(pool.map(fetch, tasks))
(OUT / 'fetch_status.json').write_text(json.dumps(status, ensure_ascii=False, indent=2), encoding='utf-8')
summaries = []
for task in status:
    if task['status'] != 'ok':
        continue
    message = json.loads((OUT / (task['key'] + '.json')).read_text(encoding='utf-8'))['message']
    works = message.get('items', [message])
    for w in works:
        summaries.append({k: w.get(k) for k in ['DOI', 'title', 'container-title', 'published', 'published-online',
                                               'published-print', 'created', 'URL', 'abstract']})
(OUT / 'metadata_summary.json').write_text(json.dumps(summaries, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(status, ensure_ascii=False))