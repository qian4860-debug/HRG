"""Keep the authored R00--R39 text and append transparent reproduction artifacts."""
from pathlib import Path
import hashlib,json,re

HERE=Path(__file__).resolve().parents[1];ROOT=HERE.parents[1]
BOOK=ROOT/'全角HRG验证总书第二版_逐行推导与复算.md'
V1=ROOT/'全角HRG从零到当前_完整推导与验证总书.md'
START='<!-- APPENDIX_V2 -->';TOC='<!-- TOC_V2 -->';TOCEND='<!-- /TOC_V2 -->'
COVERAGE=[['R00','R38'],['R01'],['R04','R08'],['R02','R18'],['R04'],['R05'],['R06'],['R04','R09'],['R07'],['R08','R09'],['R09','R22'],['R10','R29'],['R11'],['R12','R14'],['R13'],['R13','R15'],['R15'],['R16','R17'],['R18'],['R19'],['R19','R20'],['R21'],['R20','R37'],['R22'],['R23'],['R24'],['R26'],['R23','R25'],['R27'],['R28'],['R29','R30'],['R30','R31'],['R32'],['R33'],['R37'],['R36','R37'],['R36'],['R34'],['R35'],['R27','R36','R38'],['R34','R38'],['R39'],['R38'],['R00','R39'],['R24','R30','R38','R39'],['R39']]

def main():
    text=BOOK.read_text(encoding='utf-8').split(START)[0]
    text=re.sub(re.escape(TOC)+r'[\s\S]*?'+re.escape(TOCEND),TOC,text)
    headings=re.findall(r'^## (R\d\d)　(.+)$',text,re.M)
    toc='\n'.join('- ['+key+' '+title+'](#'+key+')' for key,title in headings)
    text=text.replace(TOC,TOC+'\n\n'+toc+'\n\n'+TOCEND)
    result=json.loads((HERE/'evidence/python_results.json').read_text(encoding='utf-8'))
    matlab=json.loads((HERE/'evidence/matlab_results.json').read_text(encoding='utf-8'))
    chunks=[text.rstrip()+'\n\n'+START+'\n',
      '\n<a id="appendix-calculation"></a>\n## 附录A　本次实际复算的中间计算表\n\n',
      f"Python数值/代数/ODE交叉检查{len(result['checks'])}项，全部通过；保存{len(result['values'])}个数值节点。MATLAB实际执行{len(matlab['checks'])}项，全部通过；两种实现交叉比较{len(matlab['values'])}个共同节点及3001个ODE输出时刻的位移/速度。其他Python节点用于保留更细的算术，不冒称全部由MATLAB重算。\n\n",
      'ODE案例驱动力为标称维振力，外力频率5000.7Hz、固有频率5000Hz、零位移/零速度初值、记录3ms；不是整机建幅试验。下图为MATLAB对原二阶方程积分与闭式的比较，底图的量是位移差/Aref。\n\n',
      f"![原方程ODE与闭式核对](<{(HERE/'evidence/forced_response.png').as_posix()}>)\n\n",
      '|单元/节点|数值（未提前截断）|单位|这一行做的运算|\n|---|---:|---|---|\n']
    for key,r in sorted(result['values'].items()):
        formula=r['formula'].replace('|','\\|')
        chunks.append(f"|{key}|{r['value']:.16g}|{r['unit']}|{formula}|\n")
    chunks.append('\n## 附录B　如何自行检查参考式，而不跳过演算\n\n')
    chunks.append('参考式也应代回定义核对。博士论文PDF35式(2-8)视觉版面的衰减指数将2m与阻尼的位置写得与R02特征根不符；从r²+(c/m)r+k/m=0完成平方，实部只能是−c/(2m)。这条检查基于量纲和原微分方程，不推断作者程序采用了同一版面表达。开题V0.5第4.2锁相环段说起振时各极点实部均正，而其极点式和R21均保留一个负实极点，右移的是一对复极点。开题PDF22的局部三角展开应逐项复核：本书使用sin a cos b=.5[sin(a+b)+sin(a−b)]，低通系数必须连同参考幅度定义。上述只解释为什么不能把印刷结果当成不需复算的前提，不影响本版“把自己的运算讲全”的重点。\n\n')
    chunks.append('来源准确路径及原字节SHA见本版sources.json，实际阅读位置见reading.json。PDF页码从第一页计数；DOCX用章节与段号定位。完整提取文本和公式预览仅在本地忽略目录，未把这三份原件或全文复制到公共Git。\n')
    chunks.append('\n## 附录C　第一版46章在第二版中的覆盖\n\n')
    chunks.append(f'[第一版完整历史汇编](<{V1.as_posix()}>)保留原字节。第二版按计算依赖重新组织，以下逐项映射防止只细化机械而遗落现有算法、RTL和测试。\n\n|第一版章节|第二版推导单元|\n|---|---|\n')
    old=V1.read_text(encoding='utf-8').split('<!-- GENERATED_ARCHIVE_START -->')[0]
    oldheads=re.findall(r'^## 第(\d+)章　(.+)$',old,re.M)
    assert len(oldheads)==46 and len(COVERAGE)==46
    for (num,title),units in zip(oldheads,COVERAGE):
        chunks.append(f"|第{num}章 {title}|"+'、'.join(f'[{r}](#{r})' for r in units)+'|\n')
    chunks.append('\n## 附录D　可直接复制的MATLAB完整复算代码\n\n')
    chunks.append('对应文件run_reproduction.m；不调用Python生成答案，不修改原工程。\n\n```matlab\n'+(HERE/'run_reproduction.m').read_text(encoding='utf-8').rstrip()+'\n```\n')
    chunks.append('\n## 附录E　可直接复制的Python完整复算代码\n\n')
    chunks.append('对应tools/reproduce.py，依赖NumPy。代码在项目目录执行，或按R39目录保存；参数JSON列在下一附录。附录源码与独立脚本逐字核对，避免正文示例与实际脚本不同。\n\n```python\n'+(HERE/'tools/reproduce.py').read_text(encoding='utf-8').rstrip()+'\n```\n')
    chunks.append('\n## 附录F　全部数值输入与复现身份\n\n```json\n'+(HERE/'parameters.json').read_text(encoding='utf-8').rstrip()+'\n```\n')
    chunks.append('\n只有第一版共享节点与本版新假设算例使用同一单位时才比较。封存的V7/V8/WZ/V9完整性核对另见交付检查；本次新证据是逐步计算和标量ODE，不新增实物性能结论。\n')
    BOOK.write_text(''.join(chunks),encoding='utf-8',newline='\n')
    v1sha=hashlib.sha256(V1.read_bytes()).hexdigest()
    meta=dict(date='2026-10-27',units=len(headings),steps=text.count('**步骤'),numerical_checkpoints=len(result['values']),
              python_checks=len(result['checks']),matlab_checks=len(matlab['checks']),shared_checkpoints=len(matlab['values']),
              v1_sha256=v1sha,v1_mapping=COVERAGE,main_characters=len(text),book_bytes=BOOK.stat().st_size)
    (HERE/'book_structure.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps({k:v for k,v in meta.items() if k!='v1_mapping'},ensure_ascii=False))

if __name__=='__main__':main()
