"""Build the standalone piezo system book, preserving earlier books verbatim."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[1];V=ROOT/'HRG_WA_simulink/piezo_v10'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 work=ROOT/'HRG_WA_simulink/layered/_work/piezo_v10'
 raw=json.loads((work/'selected_sources.json').read_text(encoding='utf-8'))
 inv=json.loads((work/'zotero_inventory.json').read_text(encoding='utf-8'));by={i['key']:i['data'] for i in inv['items']}
 pages={'2F6FA5W9':[1,2,3],'33LLJK89':[1,14],'QCCBYZZ5':[1,6],
 'UYU9ZQYT':[1,4],'VGZ48WAL':[1],'3WWC87NP':[1]}
 src=[]
 for r in raw:
  d=by[r['parent']];src.append(dict(title=d['title'],doi=d.get('DOI'),path=r['path'],sha256=r['sha256'],
   text_pages_reviewed=pages[r['key']],visual_pages_reviewed=([14] if r['key']=='33LLJK89' else [6] if r['key']=='QCCBYZZ5' else []),
   boundary='Specified pages only, not whole-paper or complete-algorithm reproduction'))
 (V/'sources.json').write_text(json.dumps(src,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 results=json.loads((V/'evidence/results.json').read_text());ind=json.loads((V/'evidence/independent_checks.json').read_text())
 assert all(results['checks'].values()) and all(c['passed'] for c in ind['checks'].values())
 base=ROOT/'压电式半球全角陀螺_逐步推导与文献审读.md'
 book='# 压电半球全角陀螺验证总书第三版：逐步推导与V10模型\n\n2026-10-29。V10为独立压电研究版本，全部参数为合成夹具；原第二版、压电专题续篇及V7—V9保留原字节。\n\n'
 book+='阅读顺序：第一编从球壳几何、压电本构、旋转动能推到接口和控制；第二编逐行映射到本轮实际运行的MATLAB与Simulink；第三编列出结果、原文阅读边界和复现入口。第一编引用的历史模型边界以第二编V10完成清单补充，未实现算法不因为文献收录而算作已实现。\n\n'
 book+='## 第一编　从零开始的完整压电物理主线\n\n'+base.read_text(encoding='utf-8')
 book+='\n\n## 第二编　把方程逐项落成可运行V10\n\n'+(V/'docs/implementation.md').read_text(encoding='utf-8')
 book+='\n\n## 第三编　本轮真实验证结果\n\n'
 book+='| 工况 | 载体全角RMS [°] | 能量相对误差 | 建幅 [s] | 驱动裕量 [V] |\n| --- | --- | --- | --- | --- |\n'
 for name,c in results['cases'].items():book+=f"| {name} | {c['angle_rms_deg']:.8g} | {c['energy_relative_mean']:.8g} | {c['build_time_s']} | {c['drive_margin_V']:.8g} |\n"
 book+=f"\nMATLAB版本：{results['matlab']}。{len(results['checks'])}项MATLAB/Simulink检查通过；另有{len(ind['checks'])}项独立Python机电/电路检查通过。原压电推导19项复算继续保留。本轮未做实物、长期随机噪声、完整自校准或RTL压电闭环验收。\n\n"
 book+='### 本次新增原文的实际阅读范围\n\n'
 for r in src:book+=f"- **{r['title']}**；PDF页{r['text_pages_reviewed']}，视觉核对页{r['visual_pages_reviewed']}；文件：`{r['path']}`；DOI：{r.get('doi') or '见原文'}。\n"
 book+='\n### 可复现入口与文件关系\n\n```matlab\ncd(\'C:/Users/11725/Desktop/HRG_WA/HRG_WA_simulink/piezo_v10\')\naddpath(pwd)\np10_run\np10_finalize\nout=p10_demo;\n```\n\n然后在工程根目录运行：\n\n```powershell\npython HRG_WA_simulink/piezo_v10/verify_independent.py\npython research/scholar_piezo_20261029/reproduce_piezo.py\npython tools/build_piezo_v10_book.py\npython HRG_WA_simulink/piezo_v10/check_delivery.py\n```\n\n'
 book+='`p10_plant.m`构造物理电路矩阵；`p10_tick.m`实现数字控制；`p10_build.m`生成原生State-Space、ADC、控制器、Scope与Spectrum模型；`p10_reference.m`检查调度；`verify_independent.py`独立重建物理矩阵及能量账。数据、模型与这些源文件必须一起保存；单独传.slx不构成完整工程。\n'
 target=ROOT/'压电全角总书第三版_原理到V10实现.md';target.write_text(book,encoding='utf-8',newline='\n')
 deps=[p for p in V.rglob('*') if p.is_file() and p.suffix in ('.m','.json','.csv','.slx','.py','.md','.png') and p.name not in ('manifest.json',)]
 manifest=dict(scope='Synthetic V10 piezo research model; not measured-head acceptance',files={p.relative_to(ROOT).as_posix():sha(p) for p in deps},book_sha256=sha(target),
  previous_books={name:sha(ROOT/name) for name in ['全角HRG验证总书第二版_逐行推导与复算.md','压电式半球全角陀螺_逐步推导与文献审读.md']})
 (V/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print('Book built, dependencies sealed:',len(deps))
if __name__=='__main__':main()
