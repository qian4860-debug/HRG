"""Render actual results and boundaries without hiding failed controls."""
from pathlib import Path
import json
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
E=ROOT/'evidence'

def load(name):return json.loads((E/name).read_text(encoding='utf-8-sig'))

def main():
    core=load('core_study.json');rf=load('rf_study.json');verified=load('verification.json')
    expected=core['trueDampingCoefficients'];rows=[
      '# V9实际结果：因果对照与独立证据','',
      '本轮题目、原始材料、专家方法及预注册范围见[protocol.md](protocol.md)，从零推导的学术/通俗配对见[from_zero.md](from_zero.md)。全部为合成研究，不是实物表头测量。','',
      '## H1：检测误差与机械阻尼的混淆','',
      '独立方向/幅度参考经过量化后标定检测矩阵；估计器只接收参考和测量数据。矩阵误差Frobenius范数为'
      f"{core['checks'][0]['error']:.8g}，随后冻结。验证轨迹为20s、−40/80/160°/s；不通过验证轨迹重新拟合检测矩阵。",
      '',f'真实[γ, dc, ds]为{expected}，单位1/s。下表采用5ms包络步长：','',
      '|转速(°/s)|原始IQ估计ds(1/s)|校准IQ估计ds(1/s)|原始拟合残差RMS|校准拟合残差RMS|校准后阻尼相对误差|',
      '|---|---:|---:|---:|---:|---:|']
    for c in core['envelopeCases']:
        if c['stepS']!=.005:continue
        x=c['corrected'];err=np.linalg.norm(np.array([x['gamma'],x['dc'],x['ds']])-expected)/np.linalg.norm(expected[1:])
        rows.append(f"|{c['rateDegS']}|{c['raw']['ds']:.9g}|{x['ds']:.9g}|{c['raw']['residualRms']:.6g}|{x['residualRms']:.6g}|{err:.6%}|")
    rows+=['',
      '**两种拟合的残差几乎同样小，但原始IQ给出的阻尼方向项随转速大变。**所以低残差本身不能证明物理参数正确。在160°/s时，原始拟合还会给出γ−sqrt(dc²+ds²)<0，与此被动模型矛盾；若拿它更新真实机械补偿，必须额外拒绝。当前只是离线诊断，没有把这组错误参数应用到控制器。','',
      '方向欠激励的检测标定与固定方位的阻尼回归均按计划拒绝。冻结标定后再引入±0.1%通道漂移，残差可检测；此反例是独立夹具数据试验，不宣称做了额外RF漂移试验。','',
      '## H1留出RF：校准先于全部控制不变量','',
      '保留精确电容、ADC/DAC、模拟链、滤波、控制器和直接角度支路；两组仅改变冻结检测标定是否启用。原始物理角.231rad，输入80°/s，1s，噪声关闭，预充能。首个有效历元.012s，评估窗.5–1s；只扣首有效样本的相对零点，没有拟合去漂移。','',
      '|量|校准关|冻结标定开|','|---|---:|---:|']
    a,b=rf['cases'];am=a['metrics'];bm=b['metrics']
    metrics=[('直接角度RMS(°)',a['directAngle']['rmsDeg'],b['directAngle']['rmsDeg']),
      ('直接角度峰值(°)',a['directAngle']['peakDeg'],b['directAngle']['peakDeg']),
      ('测得能量相对RMS',am['energy']['relativeRms'],bm['energy']['relativeRms']),
      ('机械能量相对RMS',am['energy']['mechanicalRelativeRms'],bm['energy']['mechanicalRelativeRms']),
      ('Q/E RMS',am['quadrature']['invariantRatioRms'],bm['quadrature']['invariantRatioRms']),
      ('观测锁相RMS(rad)',am['lock']['phaseRmsRad'],bm['lock']['phaseRmsRad']),
      ('原导航速率均值误差(°/s)',am['rate']['meanErrorDegS'],bm['rate']['meanErrorDegS']),
      ('原导航速率残差标准差(°/s)',am['rate']['residualStdDegS'],bm['rate']['residualStdDegS']),
      ('最小饱和裕量',am['saturation']['minimumHeadroomFraction'],bm['saturation']['minimumHeadroomFraction'])]
    for label,x,y in metrics:rows.append(f'|{label}|{x:.10g}|{y:.10g}|')
    rows+=['',f"直接角度RMS比值{rf['angleImprovementRatio']:.9g}，约降低{(1-rf['angleImprovementRatio'])*100:.4f}%；校准关的原功能验收失败项为"+
      ', '.join(k for k,v in am['checks'].items() if not v)+'；校准开所有已评估的原功能门限通过。', '',
      '**没有所有指标都改善。**正交残差略增但仍在原门限内；不把它写成“所有指标全面提升”。原速率标准差门限会漏掉较大的常值速率误差，因此同时列出均值误差和角度误差。这个观察应引出后续先定义的均值误差规格，而不是事后重写本次门限。', '',
      f"校准后角度RMS约{b['directAngle']['rmsDeg']*np.pi/180*1e6:.6g}μrad。这是短时无噪声跟踪误差，不能宣称满足1μrad/100Hz随机噪声目标。", '',
      '本轮RF未做零初值建幅和零输入，建幅时间、零偏不在本次评估范围；ARW、长期Allan、全温与PVT均未评估。H1回归出的阻尼参数未继续嵌入RF补偿。', '',
      '![检测辨识及RF结果](../evidence/identification_and_rf.png)', '',
      '## H2：参考偏置与故障反例','',
      '原生Simulink机械载波在Vref=10V及留出12V测试未偏置机械刚度+完整静电反馈、参考偏置刚度+剩余静电反馈，以及故意双计的错误版本。正确两种表述的状态差小于预设1e−8；错误版本在参考电压处的假频裂为'
      f"{verified['false_split_hz']*1e3:.9g}mHz，超过预先定义的1mHz故障检测界。", '',
      '把1.25μs步长减半，正确模型的公共频率数值误差约从99.06μHz降至6.193μHz，符合四阶收敛尺度；双计假频裂没有随之消失。频率由全部零交叉原始括号样本拟合，并由独立Python重新插值/拟合；未用0.2s FFT的5Hz栅格声称mHz分辨率。', '',
      '![参考偏置及数值收敛](../evidence/bias_and_convergence.png)', '',
      '## 独立核对与可复现边界','',
      f"MATLAB核心预注册检查{len(core['checks'])}项通过；独立Python {len(verified['checks'])}项通过。它使用二维矩阵的闭式传播器、解析阻尼振子和RK4稳定多项式预测，不调用MATLAB估计器来生成自己的答案。V7的217、V8的84、WZ的28项封存依赖保持原字节。", '',
      f"完整RF模型保存并重开编译通过，{rf['scopes']}个Scope、{rf['spectra']}个Spectrum Analyzer，频谱实际输入采样率与设置逐路一致，最大乘积误差{rf['spectrumRateError']}。两个原生核心模型也重新打开编译。", '',
      '验收输入包括夹具数据、全部包络轨迹、全部频率事件括号、按固定规则抽取的2049个载波状态探针、RF导航/IQ与尾段波形及原指标。完整机械载波原始CSV/MAT在本机`layered/_work/v9_raw`保留；它们可重生成，不作为公共验收脚本的隐藏依赖。', '',
      '“独立程序”是实现和数值路径独立，不等于已有第三方实验认证。真实CAD/FEM、位移/电压/时钟计量、转台不确定度、温度记录及外部复核仍缺失；这正是本轮不能证明真实表头精度的原因。']
    (ROOT/'docs/results.md').write_text('\n'.join(rows)+'\n',encoding='utf-8',newline='\n')
    print('Wrote actual results; independent checks:',len(verified['checks']))

if __name__=='__main__':main()
