"""Explicitly seal reviewed evidence; never called by run_all.py."""
import argparse,json
from check_delivery import HERE,ROOT,COUNTS,files,sha,evidence

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--seal',action='store_true',required=True)
    parser.parse_args();evidence()
    # Canonical LF evidence must match Git blobs without post-seal conversion.
    for p in HERE.rglob('*'):
        if p.is_file() and p.suffix in {'.m','.py','.json','.csv','.md'} and p.name!='manifest.json':
            raw=p.read_bytes(); normalized=raw.replace(b'\r\n',b'\n')
            if raw!=normalized:p.write_bytes(normalized)
    paths=['HRG_WA_simulink/piezo_v10/manifest.json',
           'HRG_WA_simulink/piezo_v10/identification/manifest.json',
           'HRG_WA_simulink/piezo_v10/electrical/manifest.json',
           'research/classics_20261030/manifest.json',
           'research/classics_addendum_20261030/manifest.json',
           'research/knowledge_system_20261030/manifest.json']
    paths.extend(p.relative_to(ROOT).as_posix() for p in ROOT.glob('*总书*.md'))
    manifest=dict(release='V10.1 synthetic piezo closed-loop revision',date='2026-10-30',
                  checks_total=sum(COUNTS.values()),files=files(),
                  preserved_legacy={n:sha(ROOT/n) for n in sorted(paths)},
                  boundary='Synthetic fixtures only; no physical head ratings, measured ARW or unrestricted virtual-rate claim')
    (HERE/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('Sealed reviewed V10.1 delivery')

if __name__=='__main__':main()
