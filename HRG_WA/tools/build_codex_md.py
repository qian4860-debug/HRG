"""Build/check a central Markdown archive without changing accepted source files.

Default is read-only verification. --build refreshes snapshots only in codex_md/.
DSH documents and active AGENTS instructions keep their own authoritative paths.
"""
import argparse
from datetime import date
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import posixpath
import re
import subprocess
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT/'codex_md'
GIT = ['git', '-c', f'safe.directory={ROOT.as_posix()}']
OWN_WORKING_SOURCES = {'全角陀螺/HRG_WA_codex.md'}
HISTORY = '全角陀螺/HRG_WA_codex.md'
LINK = re.compile(r'(!?\[[^\]\n]*\])\((<[^>\n]+>|[^\s)]+)([^)\n]*)\)')


def git(*args):
    return subprocess.check_output(GIT+list(args), cwd=ROOT)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write(name, data):
    path = (DEST/name).resolve()
    assert path.is_relative_to(DEST.resolve()), '归档目标越界'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data if isinstance(data, bytes) else data.encode('utf-8'))


def mdlink(label, target):
    target = str(target).replace('\\', '/')
    return f'[{label}](<{target}>)'


def redact(text):
    # Specific credential formats only; do not broadly erase technical numbers.
    text = re.sub(r'\b(?:github_pat_[A-Za-z0-9_]{25,}|gh[pousr]_[A-Za-z0-9]{30,}|sk-(?:proj-)?[A-Za-z0-9_-]{24,})', '[凭证已隐去]', text)
    text = re.sub(r'(设备码\s*)[A-Z0-9]{4}-[A-Z0-9]{4}', r'\1[已隐去]', text)
    return text


def clean_history(text):
    starts = list(re.finditer(r'^## (?:\d{4} \| |本轮追加 \| )([^\n]+)\n', text, re.M))
    accepted, omitted, seen = [], [], set()
    for i, match in enumerate(starts):
        block = text[match.end():starts[i+1].start() if i+1 < len(starts) else len(text)]
        lines = block.splitlines()
        message = '\n'.join(line[2:] if line.startswith('> ') else '' if line == '>' else line
                            for line in lines if line.startswith('>')).strip()
        session = re.search(r'Session: `([^`]+)`', block)
        sid = session.group(1) if session else '未记录'
        reason = None
        if not message:
            reason = '空消息或非引用正文'
        elif any(marker in message for marker in ['APPROVAL REQUEST START',
                'TRANSCRIPT DELTA START', 'The following is the Codex agent history',
                'PARENT TURN PERMISSION CONTEXT START']):
            reason = '自动审批/工具上下文，不作为用户提问'
        elif message.startswith(('# AGENTS.md', '<environment_context>', '<external_codex_apps_open_page>',
                                 '<turn_aborted>', '<permissions instructions>')):
            reason = '环境注入或回合标记'
        key = (sid, message)
        if key in seen:
            reason = '同会话同原文重复'
        if reason:
            omitted.append({'source_heading': match.group(0).strip(), 'reason': reason})
            continue
        seen.add(key)
        stamp = match.group(1)
        if '归档时间为当前记录时间，不推定原始消息发送时间' in block:
            stamp += '（归档时间，非原发送时间）'
        accepted.append((stamp, sid, redact(message)))
    assert accepted, '未发现可归档的真实提问，停止覆盖'
    output = '# Codex 用户提问记录（清理视图）\n\n'
    output += ('来源为已有本地提问档案。保留可见用户原文和交互回执，剔除自动审批、工具上下文和重复项；'
               '不声称包含不可访问的对话或全部助手回答。设备授权码等凭证作脱敏处理。'
               '原档案及其 Git 历史仍保留；本文件不是修改后的历史原稿。\n\n')
    for i, (stamp, sid, message) in enumerate(accepted, 1):
        output += f'## {i:04d} | {stamp}\n\n会话：`{sid}`\n\n'
        output += '\n'.join('> '+line for line in message.splitlines())+'\n\n'
    return output, accepted, omitted


def rewrite_links(text, source, archive, mapping):
    rewrites = []
    in_fence = None
    output = []
    for line in text.splitlines(keepends=True):
        fence = re.match(r'^\s*(`{3,}|~{3,})', line)
        if fence:
            marker = fence.group(1)[0]
            if in_fence is None:
                in_fence = marker
            elif in_fence == marker:
                in_fence = None
            output.append(line)
            continue
        if in_fence:
            output.append(line)
            continue

        def replace(match):
            href = match.group(2).strip('<>')
            parsed = urlsplit(href)
            if parsed.scheme or parsed.netloc or not parsed.path or href.startswith(('#', '/', '\\')):
                return match.group(0)
            candidate = posixpath.normpath(posixpath.join(posixpath.dirname(source), unquote(parsed.path)))
            original = (ROOT/candidate).resolve()
            if not original.is_relative_to(ROOT) or not original.exists():
                return match.group(0)
            target = mapping.get(candidate, candidate)
            relative = posixpath.relpath(target, posixpath.dirname(archive))
            relative += ('?'+parsed.query if parsed.query else '')+('#'+parsed.fragment if parsed.fragment else '')
            rewrites.append({'source_href': href, 'resolved_target': target})
            return match.group(1)+'(<'+relative+'>'+match.group(3)+')'

        output.append(LINK.sub(replace, line))
    return ''.join(output), rewrites


def category(name):
    if '总书' in name or '教材' in name or '从零' in name:
        return '理论总书与教材'
    if name.startswith('HRG_WA_simulink/'):
        return 'MATLAB与Simulink建模'
    if name.startswith(('research/', '研究')) or '创新' in name or '博士' in name:
        return '研究、文献与选题'
    if name.startswith('全角陀螺/'):
        return '资料与文献管理'
    if 'HRG_WA' in name or 'rtl' in name.lower():
        return 'RTL、配置与历史版本'
    return '工程说明与需求'


def build(snapshot_date=None):
    snapshot_date = snapshot_date or date.today().isoformat()
    date.fromisoformat(snapshot_date)
    base = git('rev-parse', 'HEAD').decode().strip()
    prior_path = DEST/'manifest.json'
    prior = json.loads(prior_path.read_text(encoding='utf-8')) if prior_path.exists() else {}
    prior_entries = {entry['source']: entry for entry in prior.get('entries', [])}
    current_docs = sorted(p for p in DEST.glob('[0-9][0-9]_*.md') if not p.name.startswith('00_'))
    tracked = git('ls-files', '-z', '--', '*.md').decode().rstrip('\0').split('\0')
    changed = set(git('diff', '--name-only', '-z', 'HEAD').decode().rstrip('\0').split('\0'))
    sources, excluded = [], []
    for name in sorted(tracked):
        if name.startswith('codex_md/'):
            continue
        if name == 'AGENTS.md' or name.startswith(('DSH_md/', 'Gyro/', 'hrg_wa_dsh/')):
            excluded.append({'path': name, 'reason': '活动规则、DSH独立文档或外部参考，保留原入口'})
            continue
        # Preserve a committed, accepted source snapshot when someone else's
        # unreviewed working changes are present. Only our raw question append is allowed.
        source_mode = 'working_question_append' if name in OWN_WORKING_SOURCES else 'committed_snapshot'
        data = (ROOT/name).read_bytes() if source_mode == 'working_question_append' else git('show', base+':'+name)
        try:
            text = data.decode('utf-8-sig')
            encoding = 'utf-8'
        except UnicodeDecodeError:
            try:
                text = data.decode('gb18030')
                encoding = 'gb18030'
            except UnicodeDecodeError:
                raise RuntimeError('无法无损解析 Markdown，请人工核对：'+name)
        if '本文件已迁移' in text[:150] or (len(text) < 800 and 'DSH_md/' in text and '迁移' in text):
            excluded.append({'path': name, 'reason': '已迁移至DSH的兼容指向，避免误列为Codex正文'})
            continue
        sources.append({'source': name, 'data': data, 'text': text, 'encoding': encoding,
                        'source_mode': source_mode, 'source_dirty': name in changed})
    mapping = {x['source']: ('codex_md/00_用户提问记录.md' if x['source'] == HISTORY
                            else 'codex_md/历史文档/'+x['source']) for x in sources}
    entries, history = [], None
    for item in sources:
        name, data, text = item['source'], item['data'], item['text']
        archive = mapping[name]
        links = []
        previous = prior_entries.get(name)
        if (name != HISTORY and previous and previous['source_sha256'] == digest(data)
                and previous['archive'] == archive
                and previous['source_dirty_at_archive'] == item['source_dirty']
                and (ROOT/archive).exists()
                and digest((ROOT/archive).read_bytes()) == previous['archive_sha256']):
            # Retain original snapshot provenance for unchanged historical documents.
            entries.append(previous)
            continue
        if name == HISTORY:
            rendered, accepted, omitted = clean_history(text)
            history = {'source_records': len(accepted)+len(omitted), 'kept': len(accepted),
                       'omitted': omitted, 'scope': '保留用户原文/回执；不含助手全文，原始档案保持原位'}
        else:
            # Copies gain explicit provenance and repaired local links. Source bytes stay untouched.
            rendered, links = rewrite_links(text, name, archive, mapping)
            origin = posixpath.relpath(name, posixpath.dirname(archive))
            header = (f'> Codex 文档归档副本｜原路径：{mdlink(name, origin)}\n> 来源提交：`{base[:12]}`；'
                      f'源 SHA256：`{digest(data)}`。历史结论须结合版本阅读。\n')
            if item['source_dirty']:
                header += '> 原位置存在未审工作区修改；本副本采用已提交版本，不纳入这些修改。\n'
            rendered = header+'\n'+rendered
            rendered = redact(rendered)
        payload = rendered.replace('\r\n', '\n').encode('utf-8')
        write(archive.removeprefix('codex_md/'), payload)
        entries.append({'source': name, 'archive': archive, 'category': category(name),
                        'source_commit': base, 'source_mode': item['source_mode'],
                        'source_encoding': item['encoding'], 'source_dirty_at_archive': item['source_dirty'],
                        'source_sha256': digest(data), 'archive_sha256': digest(payload),
                        'rewritten_local_links': links})
    assert history is not None
    write('history_filter_audit.json', json.dumps(history, ensure_ascii=False, indent=2)+'\n')

    index = ('# Codex 全部 Markdown 索引\n\n本次按已跟踪文件逐项盘点。历史正文已归档到 `历史文档/`，'
             '保留原目录层级以区分重复文件名和版本；正文中的可识别本地链接已调整。'
             '原工程位置保持兼容和原始验收字节。\n\n')
    index += f'共归档 **{len(entries)}** 份既有 Markdown；用户记录清理视图保留 **{history["kept"]}** 条。\n\n'
    index += '## 本目录新增修订\n\n'
    for document in reversed(current_docs):
        index += '- '+mdlink(document.stem, document.name)+'\n'
    index += '\n'
    for group in sorted(set(x['category'] for x in entries)):
        index += f'## {group}\n\n| 归档文件 | 原位置 | 来源状态 |\n|---|---|---|\n'
        for entry in entries:
            if entry['category'] != group:
                continue
            a = entry['archive'].removeprefix('codex_md/')
            state = '已提交快照；源工作区另有修改' if entry['source_dirty_at_archive'] and entry['source_mode'] != 'working_question_append' else '本轮原文追加' if entry['source_mode'] == 'working_question_append' else '已提交快照'
            index += '| '+mdlink(entry['source'], a)+' | '+mdlink('原文件', '../'+entry['source'])+' | '+state+' |\n'
        index += '\n'
    index += '## 独立维护的入口\n\n'
    index += '- '+mdlink('DSH 文档索引', '../DSH_md/README.md')+'\n'
    index += '- '+mdlink('活动项目规则 AGENTS', '../AGENTS.md')+'\n\n'
    index += '上述规则/DSH 文档和其兼容指向不重复伪装为 Codex 产出，详见 manifest.json 的 excluded。\n'
    write('00_文档索引.md', index)

    readme = '# codex_md · Codex 项目文档统一入口\n\n'
    readme += ('这里集中管理本项目历次 Codex 对话形成的 Markdown，采用**文件夹 + 索引 + 分版本正文**，'
               '不拼成一个巨型文件。新文档直接写入本目录；既有文档在 `历史文档/` 中保留原相对目录。\n\n')
    readme += '## 从这里开始\n\n'
    for document in reversed(current_docs):
        readme += '- '+mdlink(document.stem, document.name)+'\n'
    readme += '- [全部文档索引](00_文档索引.md)：总书、推导、文献、模型、RTL、配置和历史版本逐项列出。\n'
    readme += '- [用户提问记录](00_用户提问记录.md)：可见原文与交互回执的清理视图。\n'
    readme += '- [DSH 对 V2 的复核](../DSH_md/06_对V2修订意见的可行性复核_20261102.md)及 [DSH 全部文档](../DSH_md/README.md)。\n\n'
    readme += f'本次归档 {len(entries)} 份既有 Markdown；提问清理视图 {history["kept"]} 条。来源、字节哈希、链接修复与排除原因见 [manifest.json](manifest.json)。\n\n'
    readme += ('## 使用和版本边界\n\n'
               '历史归档副本添加了原位置/提交/哈希，修复可识别的本地 Markdown 链接，必要时脱敏；'
               '不据此升级原文结论。正文中的命令和参考说明作为资料阅读，不自动执行。'
               '外部磁盘绝对路径保持原样，离开本机可能不可访问。\n\n'
               '为保持已验收模型及报告的依赖哈希，原工程文件保留原位；这次集中的是管理和阅读入口。'
               '他人未审的工作区修改不混入归档，相关文档用已提交版本并在索引注明。'
               'DSH 文档继续在 DSH_md 独立维护；活动 AGENTS 仍留项目根目录。\n\n'
               '原提问档案曾混入自动审批/工具上下文，本目录只提供清理视图，过滤原因见 history_filter_audit.json；'
               '原始记录及 Git 历史保持可追溯。不声称恢复未保存的会话或全部助手回答。\n\n'
               '## 更新和核对\n\n'
               '在仓库根目录运行：\n\n```powershell\n'
               'python tools/build_codex_md.py --build\npython tools/build_codex_md.py --check\n```\n\n'
               '`--build` 根据当前已提交源文件刷新历史快照，只有本轮用户原文追加允许读取工作区；'
               '不会删改原工程文件。`--check` 默认只读，核对归档哈希、来源快照和重写链接目标。'
               '本次更新后按项目规则提交并同步 GitHub。\n')
    write('README.md', readme)
    manifest = {'schema': 1, 'date': snapshot_date, 'source_base_commit': base,
                'mode': 'central_archive_with_original_paths_preserved',
                'entries': entries, 'excluded': excluded,
                'history_counts': {'source_records': history['source_records'], 'kept': history['kept']},
                'generated_index_sha256': {name: digest((DEST/name).read_bytes()) for name in
                                          ['README.md', '00_文档索引.md', 'history_filter_audit.json']},
                'current_document_sha256': {p.name: digest(p.read_bytes()) for p in current_docs}}
    write('manifest.json', json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
    return manifest


def check():
    manifest = json.loads((DEST/'manifest.json').read_text(encoding='utf-8'))
    assert len({x['source'] for x in manifest['entries']}) == len(manifest['entries'])
    assert len({x['archive'] for x in manifest['entries']}) == len(manifest['entries'])
    committed_names = git('ls-tree', '-r', '--name-only', '-z', manifest['source_base_commit']).decode().rstrip('\0').split('\0')
    expected_sources = {x for x in committed_names if x.endswith('.md') and not x.startswith('codex_md/')}
    covered = {x['source'] for x in manifest['entries']} | {x['path'] for x in manifest['excluded']}
    assert covered == expected_sources, {'missing': sorted(expected_sources-covered), 'extra': sorted(covered-expected_sources)}
    target_count = 0
    dirty_sources = []
    for entry in manifest['entries']:
        name = entry['source']
        payload = (ROOT/entry['archive']).read_bytes()
        assert digest(payload) == entry['archive_sha256'], entry['archive']
        if entry['source_mode'] == 'committed_snapshot':
            source = git('show', entry['source_commit']+':'+name)
        else:
            source = (ROOT/name).read_bytes()
        assert digest(source) == entry['source_sha256'], name
        if entry['source_dirty_at_archive'] and entry['source_mode'] != 'working_question_append':
            dirty_sources.append(name)
        for link in entry['rewritten_local_links']:
            assert (ROOT/link['resolved_target']).exists(), link
            target_count += 1
    for name, expected in manifest['generated_index_sha256'].items():
        assert digest((DEST/name).read_bytes()) == expected, name
    for name, expected in manifest['current_document_sha256'].items():
        assert digest((DEST/name).read_bytes()) == expected, name
    question_view = (DEST/'00_用户提问记录.md').read_text(encoding='utf-8')
    assert 'APPROVAL REQUEST START' not in question_view
    assert 'TRANSCRIPT DELTA START' not in question_view
    assert '是把所有md放在新建的HRG_WA/codex_md文件夹中' in question_view
    return {'archived_existing_markdown': len(manifest['entries']),
            'source_markdown_inventory': len(expected_sources),
            'explicitly_excluded_metadata_DSH_and_compatibility_pointers': len(manifest['excluded']),
            'clean_history_records': manifest['history_counts']['kept'],
            'rewritten_local_link_targets_checked': target_count,
            'other_unreviewed_dirty_sources_use_committed_snapshot': dirty_sources,
            'status': 'passed'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', action='store_true')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--date', help='archive date YYYY-MM-DD; defaults to the local execution date')
    args = parser.parse_args()
    if args.build:
        build(args.date)
    print(json.dumps(check(), ensure_ascii=False, indent=2))
