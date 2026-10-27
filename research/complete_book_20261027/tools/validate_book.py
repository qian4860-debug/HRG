"""Check source coverage, equation/code retention, links, examples and evidence."""
from pathlib import Path
import hashlib
import json
import math
import re
from build_book import BOOK, MARKER, segments
from inventory import clean, ROOT, HERE

checks=[]
def check(name, passed, detail=None):
    checks.append(dict(name=name,passed=bool(passed),detail=detail))
def near(name,actual,expected,tol):
    check(name,abs(actual-expected)<=tol,dict(actual=actual,expected=expected,tolerance=tol))
def displays(text):
    return [m.group(0) for m in re.finditer(r'\\\[[\s\S]*?\\\]|\$\$[\s\S]*?\$\$',text)]

def main():
    coverage=json.loads((HERE/'coverage.json').read_text(encoding='utf-8'))
    text=BOOK.read_text(encoding='utf-8')
    head=text.split(MARKER)[0]
    check('one_generated_archive_boundary',text.count(MARKER)==1)
    tags=re.findall(r'\\tag\{([^}]+)\}',head)
    check('unique_main_equation_numbers',len(tags)==len(set(tags)))
    check('balanced_main_display_math',head.count('\\[')==head.count('\\]'))
    for i in range(46):
        start=head.find(f'<a id="ch{i:02}"></a>')
        end=head.find(f'<a id="ch{i+1:02}"></a>') if i<45 else len(head)
        part=head[start:end]
        check(f'chapter_{i:02}_paired_explanation',start>=0 and '### 学术版' in part and '### 通俗版' in part)
    # Process prose only: code comments are not Markdown headings or links.
    prose=''.join(s for code,s in segments(text) if not code)
    ids=re.findall(r'<a id="([^"]+)"></a>',prose)
    check('unique_explicit_anchors',len(ids)==len(set(ids)),len(ids))
    local_missing=[];anchor_missing=[]
    for match in re.finditer(r'!?\[[^\]\n]*\]\((<[^>\n]+>|[^)\n]+)\)',prose):
        dest=match.group(1).strip('<>')
        if dest.startswith(('https:','http:','mailto:','data:','app:','plugin:')):continue
        if dest.startswith('#'):
            if dest[1:] not in ids:anchor_missing.append(dest)
            continue
        path=dest.partition('#')[0]
        if not Path(path).exists():local_missing.append(dest)
    check('internal_links_resolve',not anchor_missing,anchor_missing)
    check('local_links_resolve',not local_missing,local_missing)
    old_unchanged=0;equation_files=0;seen=set();original_bytes=0
    for row in coverage['rows']:
        raw=(ROOT/row['path']).read_bytes()
        sha=hashlib.sha256(raw).hexdigest()
        original_bytes+=sha==row['sha256']
        ok=sha in (row['sha256'],row['git_sha256']) and hashlib.sha256(raw.replace(b'\r\n',b'\n')).hexdigest()==row['normalized_sha256']
        check(row['id']+'_source_bytes_preserved',ok)
        old_unchanged+=ok
        if row['equations']:
            equation_files+=1
            check(row['id']+'_theory_included',row['included'])
        if not row['included'] or row['archive_id'] in seen:continue
        seen.add(row['archive_id']);sid=row['archive_id']
        begin=text.index(f'<a id="src-{sid}"></a>')
        stop=text.find('\n<a id="src-MD',begin+1)
        archive=text[begin:stop if stop>=0 else len(text)]
        original=clean(raw.decode('utf-8-sig')).replace('\r\n','\n')
        check(sid+'_display_equations_retained',displays(original)==displays(archive))
        codes=[s.strip() for code,s in segments(original) if code]
        check(sid+'_code_fences_retained',all(s in archive for s in codes))

    # Independent worked-example calculations, not MATLAB execution claims.
    w=2*math.pi*5000;gamma=w/(2*2e6);m=1e-6;a=1e-7;g=5e-6;B=.277
    near('example_gamma',gamma,.007853981633974483,1e-15)
    near('example_stiffness',m*w*w,986.9604401089358,1e-9)
    hold=m*w*w*a/2e6
    near('example_hold_voltage',hold/1e-7,.0004934802200544679,1e-14)
    start=2*m*w*gamma*a/(-math.expm1(-gamma*.1))
    near('example_start_voltage',start/1e-7,.6285653031261904,1e-11)
    cap=1e-12*a/g;current=10*w*cap
    z=1e9/math.sqrt(1+(w*1e9*1e-12)**2)
    ha=math.prod(1/math.sqrt(1+(5000/fp)**2) for fp in (30000,30000,18000))
    v=current*z*ha
    near('example_ADC_peak',v,.18740046286145592,1e-12)
    allowance=2*B*v*1e-6/math.sqrt(200)
    near('example_noise_allowance_nV',allowance*1e9,7.341172450010561,1e-10)
    adc=(4/2**18)/(2*B*v)*math.sqrt(100/(3*40000))
    near('example_ADC_angle_urad',adc*1e6,4.242765438,1e-8)
    bits=math.ceil(math.log2(4/(2*B*v*1e-6)*math.sqrt(100/(3*40000))))
    check('example_ideal_ADC_lower_bound_21',bits==21)
    near('example_dead_zone_deg_h',.00025/(4*B)*180/math.pi*3600,46.53989311,1e-7)
    near('example_NCO_FCW',round(5000/40000*2**32),0x20000000,0)
    near('example_gain_error_deg',.01/(4*B)*180/math.pi,.5171099234032701,1e-14)
    near('example_false_damping',-2*.01*(-B*80*math.pi/180),.007735299245,1e-11)
    r1=math.sqrt(w*w-20*100)/(2*math.pi)
    r2=math.sqrt(w*w-12*100)/(2*math.pi)
    near('example_bias_fault_split_mHz',(r2-r1)*1000,2.02642534,1e-5)
    kp=.8*2*math.pi*.8;ki=(2*math.pi*.8)**2/2
    near('example_energy_Kp',kp,4.0212385965949355,1e-14)
    near('example_energy_Ki',ki,12.633093633394378,1e-14)
    # Historical statements are pinned to their actual receipts, not newly run.
    ev=ROOT/'HRG_WA_simulink/identifiability_v9/evidence'
    rf=json.loads((ev/'rf_study.json').read_text())
    vr=json.loads((ev/'verification.json').read_text())
    check('historical_V9_87_checks',vr['pass_'] and len(vr['checks'])==87)
    near('historical_V9_improvement_ratio',rf['angleImprovementRatio'],.003162689213533041,1e-14)
    check('historical_V9_instruments',rf['scopes']==21 and rf['spectra']==16 and rf['reopenedCompiled'])
    old_paths=[r['path'] for r in coverage['rows']]
    check('all_183_historical_paths_preserved',old_unchanged==183 and len(old_paths)==183)
    check('all_25_display_math_sources_included',equation_files==25)
    check('all_124_unique_sources_archived',len(seen)==124)
    for name in ('literature_v7','literature_v8_research','literature_zotero_research','identifiability_v9'):
        manifest=ROOT/'HRG_WA_simulink'/name/'evidence/manifest.json'
        hashes=json.loads(manifest.read_text())['sha256']
        changed=[p for p,digest in hashes.items() if hashlib.sha256((ROOT/p).read_bytes()).hexdigest()!=digest]
        check(name+'_sealed_bytes_preserved',not changed,dict(dependencies=len(hashes),changed=changed))
    report=dict(date='2026-10-27',pass_=all(c['passed'] for c in checks),checks=checks,
                statement='Documentation, retention, independent worked examples and receipt checks only; no new MATLAB/RTL runs',
                main_characters=len(head),book_bytes=BOOK.stat().st_size,
                historical_paths=len(old_paths),unique_archived_texts=len(seen),original_working_source_bytes_unchanged=original_bytes)
    (HERE/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps({**{k:v for k,v in report.items() if k!='checks'},'document_checks':len(checks),
                      'worked_examples':sum(c['name'].startswith('example_') for c in checks)},ensure_ascii=False))
    for c in checks:
        if not c['passed']:print(json.dumps(c,ensure_ascii=False))
    raise SystemExit(0 if report['pass_'] else 1)

if __name__=='__main__':main()
