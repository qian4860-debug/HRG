"""Read-only documentation, algebra-receipt and preserved-source verification."""
from pathlib import Path
import hashlib,json,re

HERE=Path(__file__).resolve().parents[1];ROOT=HERE.parents[1]
BOOK=ROOT/'全角HRG验证总书第二版_逐行推导与复算.md'
checks=[]
def ck(name,ok,detail=None):checks.append(dict(name=name,pass_=bool(ok),detail=detail))
def outside_fences(text):
    blocks=[];code=False;buf=[]
    for line in text.splitlines(keepends=True):
        if line.startswith('```'):
            if buf:blocks.append((code,''.join(buf)));buf=[]
            code=not code
        else:buf.append(line)
    if buf:blocks.append((code,''.join(buf)))
    ck('balanced_code_fences',not code)
    return blocks
def main():
    text=BOOK.read_text(encoding='utf-8');head=text.split('<!-- APPENDIX_V2 -->')[0]
    struct=json.loads((HERE/'book_structure.json').read_text(encoding='utf-8'))
    units=re.findall(r'^## (R\d\d)　',head,re.M)
    ck('all_40_ordered_units',units==[f'R{i:02}' for i in range(40)])
    for i,u in enumerate(units):
        start=head.index(f'<a id="{u}"></a>');stop=head.find('<a id="R',start+1)
        part=head[start:stop if stop>=0 else len(head)]
        ck(u+'_plain_explanation','**通俗解释。**' in part)
        if i<38:ck(u+'_explicit_derivation_steps',bool(re.search(r'\*\*步骤[0-9]',part)) or u=='R00')
    tags=re.findall(r'\\tag\{([^}]+)\}',head)
    ck('unique_equation_tags',len(tags)==len(set(tags)),len(tags))
    ck('balanced_display_math',head.count('\\[')==head.count('\\]'))
    prose=''.join(b for code,b in outside_fences(text) if not code)
    ids=re.findall(r'<a id="([^"]+)"></a>',prose)
    ck('unique_internal_anchors',len(ids)==len(set(ids)))
    missing=[]
    for link in re.finditer(r'!?\[[^\]\n]*\]\((<[^>\n]+>|[^)\n]+)\)',prose):
        target=link.group(1).strip('<>')
        if target.startswith('#'):
            if target[1:] not in ids:missing.append(target)
        elif not target.startswith(('https:','http:','mailto:')):
            if not Path(target).exists():missing.append(target)
    ck('all_links_resolve',not missing,missing)
    for name,lang in [('run_reproduction.m','matlab'),('tools/reproduce.py','python'),('parameters.json','json')]:
        source=(HERE/name).read_text(encoding='utf-8').rstrip()
        ck('embedded_code_matches_'+name,('```'+lang+'\n'+source+'\n```') in text)
    py=json.loads((HERE/'evidence/python_results.json').read_text(encoding='utf-8'))
    ma=json.loads((HERE/'evidence/matlab_results.json').read_text(encoding='utf-8'))
    ck('independent_python_pass',py['pass_'] and py['check_matlab'])
    ck('actual_MATLAB_pass',ma['pass'] and all(ma['checks'].values()))
    ck('all_numerical_nodes_printed',all('|'+key+'|' in text for key in py['values']))
    ck('all_46_V1_chapters_mapped',len(struct['v1_mapping'])==46)
    ck('no_omitted_numeric_inputs',all('"'+k+'"' in text for k in json.loads((HERE/'parameters.json').read_text())))
    refs=json.loads((HERE/'sources.json').read_text(encoding='utf-8'))['sources']
    for r in refs:ck(r['id']+'_source_original_bytes',hashlib.sha256(Path(r['path']).read_bytes()).hexdigest()==r['sha256'])
    v1=ROOT/'全角HRG从零到当前_完整推导与验证总书.md'
    oldseal=json.loads((ROOT/'research/complete_book_20261027/manifest.json').read_text(encoding='utf-8'))
    ck('V1_accepted_book_bytes_preserved',hashlib.sha256(v1.read_bytes()).hexdigest()==oldseal['sha256'][v1.name])
    for branch in ('literature_v7','literature_v8_research','literature_zotero_research','identifiability_v9'):
        seal=ROOT/'HRG_WA_simulink'/branch/'evidence/manifest.json';hashes=json.loads(seal.read_text())['sha256']
        bad=[path for path,digest in hashes.items() if hashlib.sha256((ROOT/path).read_bytes()).hexdigest()!=digest]
        ck(branch+'_sealed_bytes',not bad,dict(dependencies=len(hashes),changed=bad))
    report=dict(date='2026-10-27',pass_=all(c['pass_'] for c in checks),
                scope='Delivery structure, source identities and actual worksheet receipts; no full RF/RTL rerun',
                python_checks=len(py['checks']),matlab_checks=len(ma['checks']),numerical_checkpoints=len(py['values']),
                shared_checkpoints=len(ma['values']),steps=head.count('**步骤'),checks=checks)
    (HERE/'evidence/delivery.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps({k:v for k,v in report.items() if k!='checks'},ensure_ascii=False))
    for c in checks:
        if not c['pass_']:print(c)
    raise SystemExit(0 if report['pass_'] else 1)
if __name__=='__main__':main()
