"""Rebuild only the generated archive; preserve the hand-edited main text."""
from pathlib import Path
import hashlib
import json
import re
from urllib.parse import unquote
from inventory import clean, ROOT, HERE

BOOK = ROOT/'全角HRG从零到当前_完整推导与验证总书.md'
MARKER = '<!-- GENERATED_ARCHIVE_START -->'

def reason(row):
    path = row['path']
    if path == 'AGENTS.md':
        return False, '仓库指令，不是理论材料；按当前用户授权执行，未作为正文指令导入'
    if path.startswith(('research/literature_acquisition_', 'research/lynch1995_citing_',
                        'research/zotero_import_', 'research/zotero_integration_')):
        return False, '书目、获取或导入台账；保留来源链接，不把题录变成理论全文'
    if '资料索引' in path or '/新增资料_20261021_WoS/' in path:
        return False, '资料/检索索引；正文阅读等级沿用原台账'
    if row['equations']:
        return True, '含显式理论公式，必须纳入'
    return True, '设计、实现、修复、验收或研究背景补充；按版本保留'

def slug(s):
    s = re.sub(r'[*`_]', '', s).strip().lower()
    s = ''.join(c for c in s if c.isalnum() or c in ' -')
    return s.replace(' ', '-')

def segments(body):
    """Keep fenced source code byte-for-byte during Markdown rewrites."""
    out=[]; buf=[]; fence=None
    for line in body.splitlines(keepends=True):
        m=re.match(r'^\s*(`{3,}|~{3,})',line)
        if fence is None and m:
            if buf:out.append((False,''.join(buf)))
            buf=[line];fence=m.group(1)
        elif fence is not None:
            buf.append(line)
            if m and m.group(1)[0]==fence[0] and len(m.group(1))>=len(fence):
                out.append((True,''.join(buf)));buf=[];fence=None
        else:buf.append(line)
    if buf:out.append((fence is not None,''.join(buf)))
    assert fence is None, 'Unclosed code fence in source'
    return out

def main():
    rows = json.loads((HERE/'inventory.json').read_text(encoding='utf-8'))
    groups = {}
    mapping = {}
    for row in rows:
        p = ROOT/row['path']
        raw=p.read_bytes()
        assert hashlib.sha256(raw).hexdigest() in (row['sha256'],row['git_sha256']), row['path']
        assert hashlib.sha256(raw.replace(b'\r\n',b'\n')).hexdigest()==row['normalized_sha256'],row['path']
        included, why = reason(row)
        row['included'] = included
        row['reason'] = why
        if not included:
            continue
        body = clean(p.read_text(encoding='utf-8-sig')).replace('\r\n','\n')
        key = hashlib.sha256(body.encode()).hexdigest()
        if key not in groups:
            groups[key] = dict(id=row['id'], paths=[], body=body)
        group = groups[key]
        group['paths'].append(row['path'])
        row['archive_id'] = group['id']
        mapping[row['path']] = group['id']

    # Record every transformation; source hashes refer to untouched original bytes.
    rewrites = []
    chunks = ['\n<a id="source-archive"></a>\n# 附录　项目来源、历史推导与验收全文去重汇编\n',
              '\n这部分保存各版本自己的上下文，不把旧文的“当前/已完成/下一步”升级为今天的状态。主线第42—43章的状态与纠错优先。公式仍按原来源编号；同号不表示同一公式。完全相同的规范化正文只保留一次，其余路径列为别名。内嵌base64图像改为原文件入口，避免数兆编码淹没文本；图片原字节保留在原MD中。正文措辞、公式与失败记录不作静默修正，纠错见主线。文内相对代码/证据链接转成本机绝对路径，已汇编MD链接指向本书内的来源章节；正文的双空格硬换行改用显式br，代码块保留。\n',
              '\n## A　全量来源覆盖表\n\n|编号|原文路径|纳入位置/范围|\n|---|---|---|\n']
    for row in rows:
        path = row['path']
        label = path.replace('|','\\|')
        loc = f"[历史全文](#src-{row['archive_id']})" if row['included'] else row['reason']
        chunks.append(f"|{row['id']}|[{label}](<{(ROOT/path).as_posix()}>)|{loc}|\n")
    chunks.append('\n## B　历史文本的阅读规则\n\n1. 先核对来源版本，再采用公式；同名参数可能有不同单位。\n2. 旧静态报告、旧失败、修复后日志各自保留，不互相覆盖。\n3. 旧产品/文献进展信息只代表原文日期，本书未重新作市场或期刊检索。\n4. 资料中操作步骤是待分析历史内容，运行时遵从当前工程路径、权限及源文的适用条件。\n5. 不得把原PDF下载/索引数量写成逐篇公式核验数量。\n')
    chunks.append('\n源SHA默认指本次读取的原工作区字节；少数旧文CRLF与Git规范LF不同，coverage.json同时保存Git字节SHA和仅行尾规范化SHA。检出复核只接受这两种已知身份且规范化正文相同，不放宽任何封存模型的字节哈希，也不重写旧源。\n')

    for group in groups.values():
        sid = group['id']
        primary = group['paths'][0]
        chunks.append(f'\n<a id="src-{sid}"></a>\n## C-{sid}　{primary}\n\n')
        chunks.append('**历史来源，非当前新增实验。** 当前含义请先读第42—43章。\n\n')
        for p in group['paths']:
            sha = next(r['sha256'] for r in rows if r['path']==p)
            chunks.append(f'- 原路径：[{p}](<{(ROOT/p).as_posix()}>)；SHA256：`{sha}`。\n')
        chunks.append('\n')
        body = group['body']
        # Source front matter is metadata, not another top-level document header.
        if body.startswith('---\n'):
            end = body.find('\n---',4)
            if end>=0:
                body='```yaml\n'+body[4:end]+'\n```\n'+body[end+4:]
        parts=segments(body)
        prose=''.join(s for iscode,s in parts if not iscode)
        heading_ids = {}
        for k, match in enumerate(re.finditer(r'^#{1,6} (.+)$',prose,re.M),1):
            heading_ids.setdefault(slug(match.group(1)),f'{sid}-h{k:03}')
        linkpat = re.compile(r'(!?\[[^\]\n]*\])\((<[^>\n]+>|[^)\n]+)\)')
        def link(match):
            lead, target = match.groups()
            target = target.strip('<>')
            if target.startswith(('http:', 'https:', 'data:', 'mailto:', 'plugin:', 'app:')):
                return match.group(0)
            if target.startswith('#'):
                new = '#'+heading_ids.get(unquote(target[1:]), f'src-{sid}')
            else:
                filepart, _, frag = target.partition('#')
                # Preserve image syntax only for actual images, never for MD pages.
                p = Path(unquote(filepart))
                if not p.is_absolute(): p=(ROOT/primary).parent/p
                p=p.resolve()
                try: rel=p.relative_to(ROOT).as_posix()
                except ValueError: rel=None
                if rel in mapping and not lead.startswith('!'):
                    new='#src-'+mapping[rel]
                else:
                    new=p.as_posix()+(('#'+frag) if frag else '')
            rewrites.append(dict(source=sid, old=target, new=new))
            return lead+'('+('<'+new+'>' if ' ' in new else new)+')'
        counter=[0]
        def heading(match):
            counter[0]+=1
            return f'<a id="{sid}-h{counter[0]:03}"></a>\n'+('#'*min(6,len(match.group(1))+2))+' '+match.group(2)
        body=''.join(s if iscode else re.sub(r'^(#{1,6}) (.+)$',heading,
                     re.sub(r'[ \t]+(?=\n)',lambda m:'<br>' if len(m.group(0))>=2 else '',linkpat.sub(link,s)),flags=re.M)
                     for iscode,s in parts)
        chunks.append(body.rstrip()+'\n')

    head=BOOK.read_text(encoding='utf-8').split(MARKER)[0].rstrip()
    result=head+'\n\n'+MARKER+'\n'+''.join(chunks)
    BOOK.write_text(result,encoding='utf-8',newline='\n')
    coverage=dict(date='2026-10-27', baseline='097ab0e', book=BOOK.name,
                  inventoried=len(rows),included_paths=sum(r['included'] for r in rows),
                  unique_archived_texts=len(groups),
                  original_display_equation_sources=sum(bool(r['equations']) for r in rows),
                  rows=rows, rewrites=rewrites)
    (HERE/'coverage.json').write_text(json.dumps(coverage,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps({k:v for k,v in coverage.items() if k not in ('rows','rewrites')},ensure_ascii=False))
    print(json.dumps(dict(book_bytes=len(result.encode()), main_characters=len(head), total_characters=len(result))))

if __name__=='__main__':main()
