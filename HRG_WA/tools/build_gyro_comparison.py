"""Build a complete, evidence-labelled comparison register from the named corpus.

Unacquired papers receive an explicit pending comparison, never invented equations.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import urlsplit, urlunsplit

PROJECT = Path(__file__).resolve().parents[1]
BASE = PROJECT/'HRG_WA_simulink/layered'
OUT = BASE/'evidence/literature_comparison'
DOCS = BASE/'docs'
HISTORY = [PROJECT/'研究规划与论文路线_20261010/08_参考文献与检索记录.md',
           PROJECT/'02_最新技术进展与文献对照_20261010.md',
           Path('D:/学习资料/资料/全角陀螺/00_索引与白皮书/半球谐振陀螺资料索引_20260825.md'),
           BASE/'docs/principle_cross_review_papers_patents.md',
           BASE/'docs/whole_angle_circuit_parameter_derivation.md']
DOI = re.compile(r'10\.\d{4,9}/[-._;()/:A-Z0-9]+', re.I)
LINK = re.compile(r'\[([^\]]+)\]\((https?://[^\s)]+)\)')
LOCAL_DOIS = {
 '10.1109/tim.2025.3650265':'L039', '10.1016/j.sna.2025.116402':'L002',
 '10.1016/j.ifacol.2025.11.223':'L003', '10.3390/mi16030273':'L038',
 '10.1038/s41378-026-01321-1':'L065', '10.1109/ecie61885.2024.10627746':'L006',
 '10.13695/j.cnki.12-1222/o3.2023.04.011':'L059',
 '10.11977/j.issn.1004-2474.2023.04.002':'L061', '10.1186/s13638-021-01913-7':'L064',
 '10.1038/s41598-020-80885-y':'L063', '10.1016/j.sna.2012.01.029':'L072',
 '10.1016/j.measurement.2023.113331':'L073'}


def web_register():
    found = {}
    local_urls = {
      'https://bpb-us-e2.wpmucdn.com/faculty.sites.uci.edu/dist/e/700/files/2022/09/dgon22_nonlinear_rig_sub.pdf':'L071',
      'https://engineering.purdue.edu/oxidemems/conferences/transducers2011/pdfs/papers/07-085.pdf':'L070'}

    def add(title, url, source, scope='既往检索记录；正文推导未在本轮核验'):
        title = re.sub(r'^\[R\d+\]\*{0,2}\s*', '', title)
        if url.endswith('MT-007.pdf'):
            title = 'ADI MT-007：孔径时间、固定延迟与随机抖动'
        elif url.endswith('MT-229.pdf'):
            title = 'ADI MT-229：理想ADC量化噪声推导'
        url = url.rstrip('。；，.,')
        match = DOI.search(url)
        if match:
            key = 'doi:' + match.group().rstrip(').').lower()
            url = 'https://doi.org/' + key[4:]
        else:
            parsed = urlsplit(url)
            url = urlunsplit((parsed.scheme, parsed.netloc, parsed.path.rstrip('/'), '', ''))
            key = url.lower()
            if '/10964523' in key:
                key, url = 'doi:10.1109/tim.2025.3555670', 'https://doi.org/10.1109/TIM.2025.3555670'
        if key in found:
            found[key]['discoveryRecords'].append(source)
            return
        found[key] = dict(key=key, title=title, url=url, discoveryRecords=[source],
                          originalReadingClaim=scope, level='pending_fulltext',
                          same='题录已覆盖；尚不能判定具体推导与项目等价',
                          different='未核验正文的公式、系数、实验条件，不根据题目补写方法')

    for path in HISTORY:
        for number, line in enumerate(path.read_text(encoding='utf-8-sig').splitlines(), 1):
            source = f'{path.as_posix()}:{number}'
            if line.startswith('| R'):
                parts = [x.strip() for x in line.split('|')]
                match = DOI.search(parts[3])
                if match:
                    add(parts[2], 'https://doi.org/'+match.group(), source, parts[4])
            else:
                for label, url in LINK.findall(line):
                    # Publication, patent, primary hardware/tutorial and official product sources.
                    if not any(s in url for s in ['doi.org/', 'patents.google.com/patent/', 'ieeexplore.ieee.org/',
                                                 'sciencedirect.com/', 'nature.com/articles/', 'pmc.ncbi.nlm.nih.gov/',
                                                 'analog.com/', 'ntrs.nasa.gov/', 'safran-group.com/', 'univelt.com/']):
                        continue
                    title = re.sub(r'\[[^\]]+\]\([^)]*\)', '', line).strip('- *|')
                    title = title.split('核验范围')[0].split('实际核对位置')[0].strip('；。| ')
                    add(title or label, url, source)
    wos_path = PROJECT/'全角陀螺/新增资料_20261021_WoS/catalog.json'
    for row in json.loads(wos_path.read_text(encoding='utf-8')):
        add(row['title'], 'https://doi.org/'+row['doi'] if row.get('doi') else row['source'],
            wos_path.as_posix()+'#'+row['id'], row['status'])
    for title, doi in [('Micromachined RIG asymmetry model', '10.3390/sym12050801'),
                       ('MEMS interface ASIC with on-chip temperature compensation', '10.1016/j.measurement.2023.113331')]:
        add(title, 'https://doi.org/'+doi, '2026-10-23 primary search / whole-library screening')
    # Merge DOI records with alternate primary URLs where identity is established.
    aliases = {
      'https://www.nature.com/articles/s41598-025-86288-1':'doi:10.1038/s41598-025-86288-1',
      'https://www.nature.com/articles/s41378-026-01321-1':'doi:10.1038/s41378-026-01321-1',
      'https://www.nature.com/articles/s41378-024-00818-x':'doi:10.1038/s41378-024-00818-x',
      'https://www.nature.com/articles/s41598-020-80885-y':'doi:10.1038/s41598-020-80885-y',
      'https://pmc.ncbi.nlm.nih.gov/articles/pmc11535526':'doi:10.1038/s41378-024-00818-x',
      'https://www.sciencedirect.com/science/article/pii/s0924424725002080':'doi:10.1016/j.sna.2025.116402'}
    for alias, key in aliases.items():
        if alias in found:
            item = found.pop(alias)
            if key in found:
                found[key]['discoveryRecords'] += item['discoveryRecords']
            else:
                item.update(key=key, url='https://doi.org/'+key.removeprefix('doi:'))
                found[key] = item
    for key, row in found.items():
        doi = key.removeprefix('doi:')
        if doi in LOCAL_DOIS or key in local_urls:
            row.update(level='local_sections', localId=LOCAL_DOIS.get(doi,local_urls.get(key)),
                       same='见对应本地条目的具体推导比较', different='本地原文已读范围见localId；不继承旧记录的全文阅读声称')
        elif doi == '10.1038/s41598-025-86288-1':
            row.update(level='primary_sections', same='电子相位→正交力泄漏→角速率偏差，与本项目链一致',
                       different='原文式(1)-(13)/图4含在线正交扰动校相；本工程仅标称相位冻结及接口注入')
        elif doi == '10.3390/mi17010143':
            row.update(level='primary_sections', same='从通道量化误差经解调/参数函数传播，与Jacobian方法一致',
                       different='原文§3/§5特别研究方位调制与相干量化；此前独立白噪声位数预算仅是条件近似')
        elif doi == '10.3390/sym12050801':
            row.update(level='primary_sections', same='理想/非理想二模态，分离刚度/阻尼误差逐项仿真',
                       different='平面MEMS结构与λ定义不同；与分层扫参方法相近，但不提供HRG电极SI预算')
        elif doi == '10.1038/s41378-025-00872-z':
            row.update(level='primary_sections', same='Lynch慢变量→正交控制力随方位变化→频裂及主轴估计，与本项目频裂/控制力机制相通',
                       different='核对原文式(5)-(7)、相位误差与修调流程；原文增加自进动探针、实测标度和机械修调，当前仅有参数注入')
        elif doi == '10.1007/s11071-026-12837-6':
            row.update(level='primary_abstract', same='出版社摘要以等价变换及叠加分析周期转动下的非对称动力学漂移',
                       different='订阅预览未提供全文；本工程共同Duffing项不能视为该ORE解析模型，未核对吸引域方程')
        elif doi == '10.7527/s1000-6893.2025.32079':
            row.update(level='primary_abstract_figures', same='官方摘要建立装配倾斜/偏心→通道耦合→动态谐波的链条，与接口闭环思想一致',
                       different='原文采用差分调频、TDM和非线性联合辨识；RichHTML未提供正文公式，不能据摘要套用当前AM预算')
        elif doi in ['10.1038/s41378-024-00818-x', '10.3390/s20123549']:
            row.update(level='primary_abstract', same='已核验摘要说明非线性执行或参数激励属于相关路线',
                       different='未核验全文系数；位移相关驱动增益/2f0刚度调制不能等同当前线性f0驱动')
        elif '/patent/' in key:
            row.update(level='patent_record', same='公开专利条目按控制、校准或结构路线登记',
                       different='未读权利要求/说明书的条目不判定公式等价、创新性或已实现；详读条目见本地表')
        elif any(t in key for t in ['safran-group', 'ntrs.nasa', 'univelt', 'analog.com']):
            row.update(level='background_or_tutorial', same='产品/原理/转换器基础参考',
                       different='不是独立完整WA推导；不能用作本项目性能证据')
    rows = sorted(found.values(), key=lambda x: x['key'])
    for i, row in enumerate(rows, 1):
        row['id'] = f'W{i:03}'
    return rows


def build():
    inventory = json.loads((OUT/'local_inventory.json').read_text(encoding='utf-8'))
    with (OUT/'method_notes.tsv').open(encoding='utf-8', newline='') as stream:
        notes = {r['id']: r for r in csv.DictReader(stream, delimiter='\t')}
    assert set(notes) == {r['id'] for r in inventory['items']}, 'Every inventoried item needs a scoped comparison'
    local = []
    for row in inventory['items']:
        note = notes[row['id']]
        pages = []
        for group in note['read_pages'].split(',') if note['read_pages'] else []:
            endpoints = [int(x) for x in group.split('-')]
            pages.extend(range(endpoints[0], endpoints[-1]+1))
        if pages:
            assert row['pages'] and min(pages) >= 1 and max(pages) <= row['pages']
        local.append(dict(row, **{k:v for k,v in note.items() if k not in ['id','read_pages']}, readPdfPages=sorted(set(pages)),
                          evidenceLevel=note['level']))
    web = web_register()
    access_path=OUT/'network_access_checks.json'
    accesses=json.loads(access_path.read_text(encoding='utf-8'))['checks']
    for row in web:
        row['accessChecks20261023']=[a for a in accesses if a['url'].lower()==row['url'].lower()]
    result = dict(date='2026-10-23', scope='Named local HRG corpus, full D:/学习资料 screening, and recovered prior online records; bounded coverage, not universal fulltext equivalence',
                  localFiles=inventory['files'], localUnique=len(local), onlineRecords=len(web), local=local, online=web,
                  sources={p.as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in HISTORY})
    result['sources']['local_inventory.json'] = hashlib.sha256((OUT/'local_inventory.json').read_bytes()).hexdigest()
    result['sources']['method_notes.tsv'] = hashlib.sha256((OUT/'method_notes.tsv').read_bytes()).hexdigest()
    result['sources']['network_access_checks.json'] = hashlib.sha256(access_path.read_bytes()).hexdigest()
    rows = ['# 全角文献逐项方法对照清单', '', '日期：2026-10-23。完整比较说明见同目录 `literature_derivation_comparison.md`。', '',
            f'本地{len(local)}个不同字节对象（{inventory["files"]}处路径）全部登记；既往网络来源合并为{len(web)}条记录。仅题录/摘要/扫描失败条目不能声称已逐式比较。', '',
            '## 本地原文与邻近资料', '', '| ID | 资料 | 已核对PDF页/层级 | 推导方法 | 与工程相同 | 差别/边界 |', '|---|---|---|---|---|---|']
    def safe(value):
        return str(value).replace('|','／').replace('\n',' ')
    for r in local:
        rows.append('| '+' | '.join(safe(x) for x in [r['id'],r['title'],str(r['readPdfPages'])+' / '+r['level'],r['method'],r['same'],r['different']])+' |')
    rows += ['', '绝对路径、SHA-256、重复位置见 `../evidence/literature_comparison/comparison_catalog.json`。', '',
             '## 既往网络资源逐条覆盖', '', '| ID | 原始来源/题录 | 证据层级 | 相同点 | 差别/待核验 |', '|---|---|---|---|---|']
    for r in web:
        rows.append('| '+' | '.join([r['id'],f'[{safe(r["title"])}]({r["url"]})',r['level']+((' / '+r['localId']) if 'localId' in r else ''),safe(r['same']),safe(r['different'])])+' |')
    md = '\n'.join(rows)+'\n'
    all_rows = [dict(id=r['id'],title=r['title'],level=r['level'],method=r['method'],same=r['same'],different=r['different'],url=r['paths'][0],pages=str(r['readPdfPages'])) for r in local]
    all_rows += [dict(id=r['id'],title=r['title'],level=r['level'],method='网络条目；详见证据层级',same=r['same'],different=r['different'],url=r['url'],pages=r.get('localId','')) for r in web]
    payload = json.dumps(all_rows, ensure_ascii=False).replace('<','\\u003c')
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>全角文献方法对照</title>
<style>body{font:15px/1.6 system-ui;margin:28px;color:#172b3a;background:#f5f7fa}h1{font-size:26px}input,select{padding:10px;margin:5px;border:1px solid #9aaaba;border-radius:5px}input{width:55%}table{border-collapse:collapse;width:100%;background:white}th,td{padding:11px;border-bottom:1px solid #dae1e7;text-align:left;vertical-align:top}th{background:#203c54;color:white;position:sticky;top:0}td:first-child{white-space:nowrap}a{color:#075da8}.note{padding:14px;background:#e4edf4;margin-bottom:18px}#count{margin:10px}</style>
<h1>全角陀螺文献推导方法对照</h1><div class="note">2026-10-23。检索覆盖≠全文阅读；仅题录、摘要、不可读文件均明确标注。当前工程采用统一物理圆周角、复包络、接口SI预算和八类验收量，不能据此宣称与全部论文逐式等价。</div>
<input id="q" aria-label="按题名、方法、差异检索" placeholder="检索 PIR、量化、调频、阻尼、PLL、TDM…"><select id="level" aria-label="证据层级"><option value="">全部证据层级</option></select><div id="count"></div><table><thead><tr><th>ID / 阅读</th><th>来源</th><th>方法</th><th>相同点</th><th>不同点与适用边界</th></tr></thead><tbody id="body"></tbody></table>
<script>const rows=PAYLOAD;const q=document.getElementById('q'),sel=document.getElementById('level');[...new Set(rows.map(r=>r.level))].sort().forEach(v=>{let o=document.createElement('option');o.value=o.textContent=v;sel.append(o)});function render(){let list=rows.filter(r=>(!sel.value||r.level===sel.value)&&JSON.stringify(r).toLowerCase().includes(q.value.toLowerCase()));document.getElementById('count').textContent=`显示 ${list.length} / ${rows.length} 条`;const body=document.getElementById('body');body.replaceChildren();for(const r of list){let tr=document.createElement('tr');for(const key of ['id','title','method','same','different']){let td=document.createElement('td');if(key==='title'&&r.url.startsWith('https://')){let a=document.createElement('a');a.href=r.url;a.textContent=r.title;td.append(a)}else td.textContent=key==='id'?`${r.id}\n${r.level}\n${r.pages}`:r[key];tr.append(td)}body.append(tr)}}q.oninput=sel.onchange=render;render();</script></html>'''.replace('PAYLOAD',payload)
    outputs={OUT/'comparison_catalog.json':json.dumps(result,ensure_ascii=False,indent=2)+'\n',
             DOCS/'literature_method_matrix.md':md, DOCS/'literature_method_matrix.html':page}
    return outputs, result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write',action='store_true')
    args=parser.parse_args()
    outputs,result=build()
    for path,content in outputs.items():
        if args.write:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_text(content,encoding='utf-8',newline='\n')
        else:
            assert path.read_text(encoding='utf-8')==content, f'Stale comparison: {path}'
    print(f'PASS scoped comparison: {result["localUnique"]} local objects; {result["onlineRecords"]} recovered online records; every local object accounted for')


if __name__=='__main__':
    main()
