"""Bounded coverage of all acquired article files, without inventing method reviews."""
from pathlib import Path
import hashlib
import json
from pypdf import PdfReader

ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parents[1]


def main():
    all_files=json.loads((REPO/'research/literature_acquisition_20261023/fulltext_manifest.json').read_text(encoding='utf-8'))['records']
    selected=json.loads((ROOT/'evidence/source_reading.json').read_text(encoding='utf-8'))['selected_sources']
    selected_by_sha={x['sha256']:x for x in selected}
    seen=set();rows=[]
    for rec in all_files:
        if rec['status']!='downloaded_verified' or rec['sha256'] in seen:continue
        seen.add(rec['sha256']);p=Path(rec['path'])
        assert hashlib.sha256(p.read_bytes()).hexdigest()==rec['sha256']
        try:
            pages=PdfReader(p).pages
            front='\n'.join(x.extract_text() or '' for x in pages[:2])
            screening=dict(status='front_pages_extracted_only',pages=list(range(1,min(len(pages),2)+1)),characters=len(front))
        except Exception as ex:screening=dict(status='front_screen_failed',error=str(ex)[:180])
        title=rec['title'].casefold()
        if any(x in title for x in ['whole-angle','whole angle','rate integrating','rate-integrating']):category='direct_WA_or_RIG_candidate'
        elif any(x in title for x in ['shell','ring','gyroscop','resonator','resonance']):category='resonator_or_gyro_background_candidate'
        elif any(x in title for x in ['control','circuit','noise','kalman','identification','calibration']):category='control_or_circuit_background_candidate'
        else:category='other_or_unclassified_background'
        read=selected_by_sha.get(rec['sha256'])
        rows.append(dict(record=rec['record'],title=rec['title'],doi=rec.get('doi'),path=rec['path'],sha256=rec['sha256'],
                         title_only_triage=category,screening=screening,
                         method_review='selected_equations_checked' if read else 'not_scientifically_reviewed',
                         checked_source_record=read['record'] if read else None,
                         model_action='See mechanics_to_algorithms.md with explicit equations and conditions' if read else 'No formula imported; read relevant primary sections before changing the model'))
    assert len(rows)==109
    record=dict(date='2026-10-24',files=len(rows),selected_sections_checked=sum(bool(x['checked_source_record']) for x in rows),
                boundary='Title-only topic triage and front-page extraction are not method comparison or scientific verification',records=rows)
    (ROOT/'evidence/new_source_coverage.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    lines=['# 全部新增文章文件的核对层级','','109是新增文章文件的去重哈希数，不是新证明的数量。题名自动分组只用于阅读排序，前两页机器提取不等于算法或公式核验。6篇采用的正文详见源阅读收据，其余不据题名导入公式。','',
           '|记录|题名|DOI|题名初筛|方法核对层级|采用动作|','|---|---|---|---|---|---|']
    for x in rows:
        lines.append('| '+' | '.join(str(x.get(k) or '').replace('|',r'\|').replace('\n',' ') for k in ['record','title','doi','title_only_triage','method_review','model_action'])+' |')
    (ROOT/'docs/new_source_coverage.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(dict(files=len(rows),selected=record['selected_sections_checked'],front_screen_failures=sum(x['screening']['status']=='front_screen_failed' for x in rows))))


if __name__=='__main__':main()
