from pathlib import Path
import hashlib,json,io,pdfplumber
from pypdf import PdfReader
HERE=Path(__file__).resolve().parent;WORK=HERE.parents[1]/'HRG_WA_simulink/_work/literature_20261102'
NAMES='''用三轴转台辨识陀螺仪误差模型系数时的速率试验设计
在反转平台离心机上标定陀螺仪的误差模型系数的方法
液浮陀螺仪在双轴离心机上的标定方法
基于线振动台的液浮陀螺仪二次项误差系数标定方法研究 (1)
磁强计和微机械陀螺_加速度计组合定姿的扩展卡尔曼滤波器设计
硅微陀螺温度漂移补偿研究
无陀螺惯性测量组合静动态解耦方法
利用磁强计及微机械加速度计和陀螺的姿态估计扩展卡尔曼滤波器
半球谐振陀螺仪谐振子振动特性的有限元分析
半球谐振陀螺控制及补偿技术
半球谐振陀螺仪随机误差分析
高精度液浮陀螺仪在双轴转台上的标定方法与误差分析
基于半球谐振陀螺的捷联惯性姿态系统的一种粒子滤波方法
基于线振动台的液浮陀螺仪二次项误差系数标定方法研究
基于自适应神经模糊推理系统的陀螺建模方法
加速度对半球谐振陀螺振动检测系统影响分析
全角模式半球谐振陀螺主要误差分析与补偿方法研究
速率积分半球谐振陀螺误差建模与抑制方法研究
基于半球谐振陀螺仪的姿态测量系统研究'''.splitlines()
def main():
    WORK.mkdir(parents=True,exist_ok=True);rows=[]
    for i,name in enumerate(NAMES,1):
        p=Path('C:/Users/11725/Downloads')/(name+'.pdf');raw=p.read_bytes();method='original'
        try:pdf=PdfReader(io.BytesIO(raw))
        except Exception:
            try:pdf=pdfplumber.open(io.BytesIO(raw));method='pdfplumber fallback; original bytes preserved'
            except Exception as e:
                rows.append(dict(id=f'N{i:02d}',title=name,path=str(p),sha256=hashlib.sha256(raw).hexdigest(),error=str(e),read_scope='unreadable; not reviewed'));continue
        pages=[]
        for page in pdf.pages:
            try:pages.append(page.extract_text() or '')
            except Exception as e:pages.append('[EXTRACTION ERROR]'+str(e))
        h=hashlib.sha256(p.read_bytes()).hexdigest();ident=f'N{i:02d}'
        (WORK/(ident+'.txt')).write_text('\n'.join(f'\n=== PDF PAGE {j+1} ===\n{t}' for j,t in enumerate(pages)),encoding='utf-8')
        (WORK/(ident+'.json')).write_text(json.dumps(pages,ensure_ascii=False),encoding='utf-8')
        row=dict(id=ident,title=name,path=str(p),sha256=h,pages=len(pages),chars=sum(map(len,pages)),extraction=method,metadata=str(pdf.metadata),read_scope='text extracted; review pages recorded separately')
        rows.append(row);print(ident,len(pages),row['chars'],name);print((' '.join(pages[:3]))[:1600])
    (HERE/'sources.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
if __name__=='__main__':main()
