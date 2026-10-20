from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import urllib.request
import json
OUT = Path(__file__).resolve().parent.parent / 'evidence' / 'web'
SOURCES = {
    'TCAS_I_official': 'https://ieee-cas.org/publication/TCAS-I',
    'TCAS_II_official': 'https://ieee-cas.org/publication/TCAS-II',
    'Measurement_scope': 'https://www.sciencedirect.com/journal/measurement/about/aims-and-scope',
    'WMEC_publisher': 'https://www.sciencedirect.com/science/article/pii/S0263224126008791',
    'Quantization_publisher': 'https://www.mdpi.com/2072-666X/17/1/143',
    'Patterned_coating_publisher': 'https://www.nature.com/articles/s41378-026-01321-1',
    'Partition_platform': 'https://www.fenqubiao.com/',
}
def get(item):
    key, url = item
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=30) as response:
            data = response.read()
            final = response.url
        (OUT / (key + '.html')).write_bytes(data)
        return {'key': key, 'url': url, 'final_url': final, 'bytes': len(data), 'status': 'fetched_not_necessarily_fulltext'}
    except Exception as exc:
        return {'key': key, 'url': url, 'status': 'failed', 'error': str(exc)}
with ThreadPoolExecutor(max_workers=3) as executor:
    result = list(executor.map(get, SOURCES.items()))
(OUT / 'publisher_fetch_status.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(result, ensure_ascii=False))