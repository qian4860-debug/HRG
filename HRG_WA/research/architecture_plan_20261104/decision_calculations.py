"""DSH10/11路线规划中的说明性计算；不构成器件规格或闭环验收。"""
from pathlib import Path
import hashlib
import json
import math

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def calculate():
    names = [
        'DSH_md/10_A0-A3质量评估与后面做什么_20261103.md',
        'DSH_md/11_对09号技术路线比较的评判_20261103.md',
        'HRG_WA_simulink/piezo_v10/electrical/p10e_build.m',
        'HRG_WA_simulink/piezo_v10/electrical/p10e_tick.m',
        'HRG_WA_simulink/piezo_v10/noise_research/sn_tick.m',
        'HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA/src/hrg_sensor_if_top.v',
    ]
    fc, stop, target = 12000, 39000, 40
    order = math.ceil(math.log10(10**(target/10)-1)/(2*math.log10(stop/fc)))
    loss = lambda q: 1-math.exp(-math.pi*1000*.0005/q)
    # 允许单个停驱段损失不同，Q门槛就不同；并非普适Q>=1000。
    limits = {str(e): math.pi*1000*.0005/-math.log1p(-e) for e in [.01,.001,.0001]}
    result = dict(date='2026-11-04',
        sources=[dict(path=n,sha256=hashlib.sha256((ROOT/n).read_bytes()).hexdigest()) for n in names],
        butterworth_example=dict(cutoff_Hz=fc,stop_Hz=stop,target_dB=target,
            first_order_attenuation_dB=10*math.log10(1+(stop/fc)**2),minimum_order=order,
            scope='仅单阻带频点和指定Butterworth截止频率；不是本工程AAF规格'),
        sampling_example=dict(two_carrier_channels_samples_per_s=2*40000,
            four_baseband_channels_samples_per_s=4*5000,aggregate_rate_ratio=4,
            scope='不代表功耗比；ΔΣ输出率不等于调制器频率'),
        tdm_example=dict(f0_Hz=1000,off_time_s=.0005,
            per_slot_amplitude_loss={str(q):loss(q) for q in [10000,1000,100]},
            minimum_Q_by_allowed_loss=limits,
            scope='单个无补能停驱段；未含补能功率、载波相位、电气建立和角度误差'),
        primary_sources=[
            'https://www.analog.com/en/resources/technical-articles/sigmadelta-adcs-tutorial.html',
            'https://www.analog.com/en/resources/technical-articles/guide-to-antialiasing-filter-basics.html'])
    assert order == 4 and limits['0.001'] > 1000
    return result


if __name__ == '__main__':
    result=calculate()
    (HERE/'decision_calculations.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps({k:v for k,v in result.items() if k!='sources'},ensure_ascii=False,indent=2))
