"""Read selected acquired primary sources without modifying their bytes."""
from pathlib import Path
import hashlib
import json
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'HRG_WA_simulink/literature_v8_research'
WORK = ROOT / 'HRG_WA_simulink/layered/_work/optimization_sources'
SELECTED = ['R0005', 'R0037', 'R0039', 'R0125', 'R0152', 'R0252']


def main():
    register = json.loads((ROOT / 'research/literature_acquisition_20261023/fulltext_manifest.json').read_text(encoding='utf-8'))
    WORK.mkdir(parents=True, exist_ok=True)
    evidence = []
    for ident in SELECTED:
        rec = next(x for x in register['records'] if x['record'] == ident)
        source = Path(rec['path'])
        assert hashlib.sha256(source.read_bytes()).hexdigest() == rec['sha256']
        pages = PdfReader(source).pages
        text = '\n\n'.join(f'=== PDF PAGE {i+1} ===\n{p.extract_text() or ""}' for i, p in enumerate(pages))
        (WORK / (ident+'.txt')).write_text(text, encoding='utf-8')
        evidence.append(dict(record=ident, title=rec['title'], doi=rec['doi'], path=rec['path'],
                             sha256=rec['sha256'], pages=len(pages), extracted_pages=list(range(1,len(pages)+1)),
                             boundary='Text extraction only; formula reading and visual checks logged separately'))
    (DEST / 'evidence').mkdir(parents=True, exist_ok=True)
    (DEST / 'evidence/source_extraction.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


if __name__ == '__main__':
    main()
