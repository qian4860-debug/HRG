"""Build a row-complete screening matrix without claiming unread full texts were read."""
from pathlib import Path
import collections, hashlib, json, re
from scholar_piezo_batch import OUT,WORK,SOURCE,norm

NOTES={
1:('正文相关章节审读','半球双壳；间接压电驱动；LDV检测；AGC/PLL与开环角速度实验，不是双压电WA证据','PDF1–5，重点3–4'),
2:('题录初筛','题名直接涉及压电半球动态响应；须核对是否压电检测、是否只做零角速度共振','无正文'),
4:('题录初筛','间接压电激励几何设计直接相关；须保留外壳到内壳的频率相关传递','无正文'),
6:('题录初筛','压电半球共振实验/数值对照；不能由共振试验证明WA','无正文'),
9:('摘要及相关段落审读','半球结构；压电振动台激励、光学测振及静电调谐；不是集成双压电WA闭环；高Q下不能仅用简单黏性阻尼解释约19%的频率差','PDF1–2、4–6'),
14:('摘要审读','半球虚拟主/正交通道幅度测量与轴方位重构；摘要没有证明压电端口或WA闭环','PDF1摘要'),
10:('题录初筛；错误候选已剔除','原记录为Matveev 2026论文；本地另一篇2013论文不能作为其全文','无目标正文'),
28:('题录初筛','题名明确WA及通道相延迟，控制相关性高；换能方式仍需原文确认','无正文'),
40:('题录初筛','与S84会议稿不同，是Sensors Letters稿；不能互相替代全文','无正文'),
43:('题录初筛','利用压电电极阻尼进行圆柱修调；可研究负载反作用，需重推半球投影','无正文'),
50:('题录初筛','贴片引起半球频率变化直接影响频裂预算；优先取得正文','无正文'),
65:('题录初筛','圆柱压电阻尼补偿可借鉴方法，不能直接复用半球系数','无正文'),
79:('撤稿标识隔离','原始题名标RETRACTED；保留历史题录，不作设计结论或性能证据','尚未核实出版社撤稿通知'),
84:('正文相关章节审读；公式视觉核对','半球双壳间接压电激励，LDV检测；PDF2式(2)印刷条件存在可复算矛盾','PDF1–4；PDF2视觉核对'),
101:('摘要及相关章节审读','圆环而非半球；静电驱动检测；正文明确本文集中于FTR，不能把模式选项当作WA实验结果','PDF1、3–4'),
132:('题录及全文身份确认','圆盘RIG参数激励；属于非线性/平均法方法对照，非半球压电实物证据','只核对封面题名'),
136:('题录及全文身份确认','题名明确FTR；数字实现可借，固定驻波方向的控制目标不直接用于WA','只核对封面题名'),
137:('相关章节审读；公式视觉核对','Loveday学位论文：压电圆柱机电模型与电弹簧/电阻尼；半球几何仍需独立重推','PDF2、28–33、44、70–73；PDF30/72视觉核对'),
160:('摘要及引言审读','钟形而非严格半球；壳体应变和压电接口可作邻近方法，运行目标为角速度','PDF1–2'),
168:('题录及全文身份确认','预印本且题名明确rate mode；数值87.64%不可直接搬作WA补偿效果','只核对封面题名'),
174:('全文候选身份否决','取得的是会议日程而非报告正文；不按目标论文全文入库','会议日程首页'),
180:('题录及全文身份确认','静电场/磁场传感综述，偏离半球压电全角主线','只核对封面题名'),
192:('资源类型复核','继续教育课程Understanding Sensors Part 1；不是期刊论文','封面'),
198:('题录及全文身份确认','圆柱光学/电学模态表征；可用于交叉标定，不能证明WA算法','只核对封面题名'),
}

def screen(title):
    t=title.lower()
    if title=='标题不可用':return '待补题名','未知','未知','未知','缺少标题，不能作可靠相关性判断'
    if 'retracted' in t:return '隔离','题名含半球','未知','未知','撤稿条目只保留检索线索'
    hemi=any(s in t for s in ['hemispher','hemi-spher','micro-hrg','dual-shell','hrg'])
    piezo=any(s in t for s in ['piezo','pzt','aln','lithium niobate'])
    wa=any(s in t for s in ['whole-angle','whole angle','rate-integrat','rate integrat','integrating gyroscope'])
    shape='半球/HRG题名线索' if hemi else ('其他谐振结构题名线索' if any(s in t for s in ['cylind','ring','disk','bell','resonat']) else '题名不足以限定结构')
    trans='压电题名线索；驱检待分辨' if piezo else '题名未限定压电'
    mode='全角/RIG题名线索' if wa else ('FTR/角速度题名线索' if any(s in t for s in ['rebalance','rate mode','angular rate']) else '题名未证明WA')
    if hemi and piezo:return 'A 优先核对',shape,trans,mode,'直接围绕压电半球结构或换能；全文决定是否覆盖WA'
    if hemi and wa:return 'A 优先核对',shape,trans,mode,'直接涉及半球WA控制；需确认换能方式和实验范围'
    if hemi:return 'B 机械/误差基础',shape,trans,mode,'可用于半球模态、损耗、频裂或误差；不可据题名认定双压电WA'
    if piezo or wa:return 'C 邻近方法',shape,trans,mode,'可借换能或RIG方法；形状、归一化及控制目标须重新映射'
    if any(s in t for s in ['resonat','vibrat','mode','gyro']):return 'C 邻近方法',shape,trans,mode,'谐振/陀螺通用方法；目前未建立到目标表头的直接证据'
    return 'D 背景资料',shape,trans,mode,'导航、传感器或其他应用背景；不作为机电耦合系数来源'

def main():
    m=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
    rows=json.loads(SOURCE.read_text(encoding='utf-8-sig'))
    assert len(rows)==len(m['records'])==203
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==m['source_sha256']
    lines=['# 两组压电半球关键词：203条逐条相关性与阅读状态','',
        '本表是完整的**检索记录初筛清单**，不是203篇全文通读报告。A/B/C/D为阅读优先级，不是器件性能或论文质量分数。题名线索与原文证据分列；文本提取不自动升级为审读。',
        '', '同名异文、综述、学位论文、会议稿与期刊稿分别保留；来源ID与原JSON逐条对应。未取得全文的条目只能保留待核实结论。', '',
        '| 序号/来源ID | 题名与入口 | 相关性初筛 | 结构 / 换能 / 模式线索 | 阅读证据与理由 | 全文状态 |',
        '| --- | --- | --- | --- | --- | --- |']
    review=[]
    for src,r in zip(rows,m['records']):
        assert src['id']==r['source_id']
        level,shape,trans,mode,reason=screen(r['title'])
        state='题录初筛；未科学审读';pages='无已审读正文'
        if r.get('path'):state='已取得并提取全文；未科学审读';pages='仅文件身份核验'
        if r['row'] in NOTES:state,reason,pages=NOTES[r['row']]
        if r['row'] in (1,84):
            level='A 优先核对';shape='正文：半球双壳';trans='正文：间接压电驱动；LDV检测'
            mode='正文：AGC/PLL及开环角速度响应' if r['row']==1 else '正文：激励与共振表征；未证明WA闭环'
        if r['row']==9:
            shape='正文：3D打印半球壳';trans='正文：压电振动台/光学测振；另有静电实验';mode='已读部分：共振/电学表征'
        if r['row']==137:shape='正文：圆柱';trans='正文：压电驱动与检测';mode='已读部分：机电耦合及反馈修正'
        rec=dict(row=r['row'],source_id=r['source_id'],title=r['title'],screening_priority=level,
            structure=shape,transduction=trans,operating_mode=mode,judgment_basis='title_screening',
            reading_status=state,reviewed_pages=pages,reason=reason,fulltext_status=r['status'])
        if r['row'] in NOTES and '审读' in state:rec['judgment_basis']='specified_original_pages_only'
        if r.get('path'):rec.update(path=r['path'],sha256=r['sha256'])
        review.append(rec)
        url=r['url'];title=r['title'].replace('|','/');name=f'[{title}]({url})' if url.startswith('http') else title
        status={'existing_fulltext':'已有全文','downloaded_fulltext':'新取得全文','not_obtained':'未取得目标全文'}[r['status']]
        if r.get('path'):status+=f" [本地]({r['path'].replace(' ','%20')})"
        lines.append(f"| S{r['row']:03d} / {r['source_id']} | {name} | {level} | {shape}；{trans}；{mode} | **{state}**；{pages}。{reason} | {status} |")
    (OUT/'逐条相关性.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    save=dict(source_records=203,counts=m['counts'],reading_boundary='No claim that all acquired full texts have been read',records=review)
    (OUT/'relevance_review.json').write_text(json.dumps(save,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(dict(collections.Counter(r['screening_priority'] for r in review)))

if __name__=='__main__':main()
