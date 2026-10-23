"""Screen PDF front matter in the full local library for HRG/whole-angle leads.

Automated screening is not human reading and cannot classify unreadable scans.
"""
from concurrent.futures import ThreadPoolExecutor, as_completed
import gzip
import json
import logging
from pathlib import Path
import re
import sys

logging.getLogger('pypdf').setLevel(logging.ERROR)
PROJECT = Path(__file__).resolve().parents[1]
WORK = PROJECT/'HRG_WA_simulink/layered/_work/literature_comparison'
MATCH = re.compile(r'whole[\s-]*angle|rate[\s-]*integrat|全角|半球.{0,4}谐振|hemispherical\s+resonat', re.I)


def inspect(path):
    from pypdf import PdfReader
    try:
        reader = PdfReader(path, strict=False)
        text = str(reader.metadata or '')
        for page in list(reader.pages[:2]):
            text += '\n' + (page.extract_text() or '')
        matched = bool(MATCH.search(path.name + '\n' + text))
        result = dict(path=path.as_posix(), status='screened_front_2_pages', matched=matched,
                      textCharacters=len(text), error='')
        if matched:
            result['snippet'] = re.sub(r'\s+', ' ', text)[:1200]
        return result
    except Exception as error:
        return dict(path=path.as_posix(), status='screen_failed', matched=bool(MATCH.search(path.name)), error=str(error)[:250])


def main():
    with gzip.open(WORK/'skill_index/catalog_full.jsonl.gz', 'rt', encoding='utf-8') as stream:
        paths = [Path('D:/学习资料')/r['relative'] for line in stream if (r := json.loads(line))['type'] == 'file' and r['relative'].lower().endswith('.pdf')]
    results = []
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(inspect, path) for path in paths]
        for future in as_completed(futures):
            results.append(future.result())
            if len(results) % 100 == 0:
                print('PDF front-matter screening', len(results), '/', len(paths), flush=True)
    results.sort(key=lambda r: r['path'])
    full = WORK/'library_pdf_screening.json'
    full.write_text(json.dumps(results, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    report = dict(scope='automated first-two-page screening, not fulltext reading; scan/font failures retained',
                  pdfFiles=len(paths), screened=sum(r['status'] != 'screen_failed' for r in results),
                  failures=[dict(path=r['path'], error=r['error']) for r in results if r['status']=='screen_failed'],
                  matches=[r for r in results if r['matched']])
    (WORK/'library_pdf_screening_summary.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('DONE', report['pdfFiles'], 'PDFs;',len(report['matches']), 'matches;',len(report['failures']), 'failures')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main()
