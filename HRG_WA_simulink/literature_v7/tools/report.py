"""Render results only from actual MATLAB receipts. Standard library only."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
E = ROOT / 'evidence'


def read(name):
    return json.loads((E / name).read_text(encoding='utf-8-sig'))


def main():
    v = read('validation.json')
    b = read('budget_charge.json')
    mech = read('mechanics_scoreboard.json')
    noise = read('noise_scoreboard.json')
    saved = read('saved_models.json')
    sweeps = read('interface_sweep.json')
    instruments = read('instrument_scoreboard.json')
    lines = [
        '# V7实际验证结果', '',
        '2026-10-23。所有数值由本目录实际MATLAB/Simulink记录生成；没有继承论文样机性能。'
        '预算和验收阈值仍为假设研究分配。', '',
        f"独立代数/状态/时序记分板：{len(read('unit_scoreboards.json')['checks'])}项通过。"
        f"保存后重开编译：{len(saved['carrierModels'])}个载波模型与1个包络模型。"
        f"仪器{len(instruments['checks'])}项检查通过，核对18个分时模型频谱仪的实际采样率、单位及观察支路无扰动。", '',
        '## 载波闭环与同一组验收量', '',
        '| 场景 | 时长/s | IQ能量RMS/% | 机械能量RMS/% | Q/E RMS | 观测相位RMS/rad | 最小量程裕量/% | 示例全部门限 |',
        '|---|---:|---:|---:|---:|---:|---:|---|',
    ]
    for case in v['cases']:
        m = case['metrics']
        lines.append(f"| {case['name']} | {m['recordDurationS']:.3g} | "
                     f"{100*m['energy']['relativeRms']:.5g} | "
                     f"{100*m['energy']['mechanicalRelativeRms']:.5g} | "
                     f"{m['quadrature']['invariantRatioRms']:.6g} | "
                     f"{m['lock']['phaseRmsRad']:.6g} | "
                     f"{100*m['saturation']['minimumHeadroomFraction']:.5g} | {'通过' if m['pass'] else '未全部通过'} |")
    cold = next(x['metrics'] for x in v['cases'] if x['name'] == 'zero_state_startup')
    build = cold['build']
    build_time = '未进入验收带' if build['timeS'] is None else f"{build['timeS']:.6g} s"
    with (E / 'zero_state_startup_mechanical_energy.csv').open(newline='') as stream:
        energy_rows = [[float(x) for x in row] for row in csv.reader(stream)]
    outside = [i for i, row in enumerate(energy_rows) if abs(row[1]-1) > build['relativeBand']]
    permanent_index = outside[-1]+1 if outside else 0
    permanent = '未在记录结束前持续稳定'
    if permanent_index < len(energy_rows):
        permanent = f"{energy_rows[permanent_index][0]:.6g} s（1 ms导出分辨率）"
    peak = max(row[1] for row in energy_rows)
    lines += ['', f"零状态启动：`{build['status']}`，入带时间{build_time}；"
              f"定义为机械能量进入±{100*build['relativeBand']:.3g}%并连续保持{build['holdS']:.3g} s。"
              '该激励已知标称频率，不能证明未知频率自动搜索。', '',
              f"首次持续入带不等于后续一直稳定：该记录机械能量峰值约{peak:.6g}，"
              f"最后一次出带后、保持至记录结束的时间为{permanent}。", '',
              '统一旧scoreboard对零状态启动成功状态的前缀识别有遗漏；V7在独立包装器中修正，'
              '不修改原验收脚本。建幅与IQ滤波填充、预置振动捕获分开。', '',
              '静电力场景包含真实负刚度引起的谐振变化；缩短观察时间可能尚未捕获。'
              '即使观测相位通过，也未对所有控制力完成独立物理谐振判据签核。', '',
              '## PI/PIR同工况对照', '',
              '40 s平均包络模型，20—40 s统计，检测/驱动矩阵设为单位，Δγ=.004/s、Δf=.08 Hz，'
              '关闭噪声和格式量化以隔离控制器周期残差；两组使用同一被控对象、PI增益和因果输入。', '',
              '| 控制器 | 能量相对RMS | Q/E RMS |', '|---|---:|---:|']
    for mode in ['PI', 'PIR']:
        p = v['PI_PIR'][mode]
        lines.append(f"| {mode} | {p['energyRms']:.8g} | {p['quadratureRms']:.8g} |")
    lines += ['', f"此工况PIR使正交残差下降{100*(1-v['PI_PIR']['quadratureRatio']):.3f}%，"
              f"能量残差下降{100*(1-v['PI_PIR']['energyRatio']):.3f}%。"
              '它是单一研究工况的实际改善，不代表任意转速/动态下稳定，不是载波量化与TDM验收。', '',
              '![PI/PIR实际对照](../evidence/pi_pir.png)', '',
              '![零状态启动](../evidence/startup.png)', '',
              '![分时载波原采样率尾段](../evidence/tdm.png)', '',
              '## 数值步长与噪声', '',
              '| 机械求解频率/Hz | 实际终点位移误差 | 实际终点速度/ω0误差 | 线性RK4等效耗散/物理耗散 |',
              '|---|---:|---:|---:|']
    for x in mech['cases']:
        lines.append(f"| {x['fsPlant']} | {x['qError']:.8g} | {x['vOverOmegaError']:.8g} | {x['numericalDampingFraction']:.8g} |")
    lines += ['', f"实际步长减半的位移误差比={mech['halfStepErrorRatio']:.8g}。"
              '独立参考为含科里奥利项的完整4×4矩阵指数，仅证明线性自由振动收敛。', '',
              f"CV噪声开/关配对记录{noise['recordS']} s，"
              f"0.1 s之后角速度增量std={noise['rateIncrementStdRadS']:.8g} rad/s。"
              f"PSD有效窗长{noise['psd']['windowDurationS']:.6g} s，"
              f"频点间隔{noise['psd']['binSpacingHz']:.6g} Hz。"
              '该短记录包含噪声经非线性/量化器改变的闭环响应，不是固有噪声、ARW或Allan零偏不稳定性。', '',
              '![短记录配对噪声](../evidence/noise_increment.png)', '',
              '## 当前电路预算暴露的问题', '',
              f"实际标称有限带宽信号峰值约{b['readoutPeakV']:.8g} V；"
              f"假设1 μrad/100 Hz场景的总白噪声分配约{b['totalWhiteNoiseAllowanceVrtHz']*1e9:.6g} nV/√Hz，"
              f"简化读出自身约{b['readoutNoiseVrtHz']*1e9:.6g} nV/√Hz，尚不满足该场景。", '',
              f"18位理想ADC的白量化估算约{b['adcWhiteAngleRmsRad']*1e6:.6g} μrad；"
              f"在此实际信号幅度下，若单独把1 μrad全部给ADC，理想位数下限为{b['adcIdealBitsCeiling']}位。"
              '该数字不是采购或流片规格，相干量化、ENOB及其他噪声还需另验。', '',
              'D-r-S-r示例占空比20%，0.1 s理想启动的峰值请求约为连续方案5倍，可能超过现有量程；'
              '短时预置振动场景通过不代表分时快速冷启动通过。连续标称驱动校准也不完全抵消开关执行映射。', '',
              '## 接口单因素筛查', '',
              '每项80 ms，保持标称校准；包含短时捕获，不能解释为稳态误差或联合PVT。', '',
              '| 工况 | 能量RMS/% | Q/E RMS | 相位RMS/rad | 全角峰值误差/deg | 示例全部门限 |',
              '|---|---:|---:|---:|---:|---|']
    for row in sweeps['cases']:
        m = row['metrics']
        lines.append(f"| {row['name']} | {100*m['energy']['relativeRms']:.6g} | "
                     f"{m['quadrature']['invariantRatioRms']:.6g} | {m['lock']['phaseRmsRad']:.6g} | "
                     f"{m['angle']['peakDeg']:.6g} | {'通过' if m['pass'] else '未全部通过'} |")
    lines += ['', '完整单通道复用、在线电调、全部文献算法、长期低速/零偏、温度联合角落和晶体管PVT仍需后续实测条件。'
              '本轮功能运行通过不替代上述性能验收。', '',
              '## 复现与证据', '',
              '执行顺序：`w7_run_validation` → `w7_validate_mechanics` → `w7_validate_noise` → '
              '`w7_sweep_interfaces` → `w7_build_delivery` → `w7_validate_instrumentation` → `w7_plot_results` → `python tools/report.py` → `python tools/verify.py --seal`。'
              '清单同时包含原模型依赖与新代码，CSV保留规定节点的原生采样尾段或完整低速记录。', '']
    (ROOT / 'docs' / 'results.md').write_text('\n'.join(lines), encoding='utf-8', newline='\n')


if __name__ == '__main__':
    main()
