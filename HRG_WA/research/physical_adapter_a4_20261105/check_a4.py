"""只读核验A4交付；重算帧评分、RTL实际轨迹和依赖哈希。"""
from pathlib import Path
import argparse,csv,hashlib,json,math,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def inventory():
    return {p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file()
        and not set(p.relative_to(HERE).parts)&{'sim','__pycache__','slprj'} and p.name!='manifest.json'
        and p.suffix not in {'.slxc','.bak','.autosave'}}
def check():
    cfg=read(HERE/'config.json');results=read(HERE/'evidence/results.json');summary=read(HERE/'evidence/summary.json')
    assert len(results)==summary['cases']==6 and summary['all_passed']
    for name,r in results.items():
        assert r['passed'] and all(r['checks'].values())
        with (HERE/'evidence'/(name+'_frames.csv')).open(encoding='utf-8',newline='') as f:
            frames=[[float(x) for x in row] for row in csv.reader(f)]
        pending=[v for v in frames if v[0]<r['integer']['source_origin_s']]
        assert all(all(math.isnan(v[j]) for j in [1,2,3,11]) for v in pending),'原点未建立前不得输出相对角'
        hold=[v for v in frames if v[0]>=cfg['score_not_before_s']]
        rms=math.sqrt(sum(v[3]**2 for v in hold)/len(hold));delta=math.sqrt(sum((v[1]-v[11])**2 for v in hold)/len(hold))
        assert abs(rms-r['integer']['relative_body_RMS_rad'])<1e-12
        assert abs(delta-r['body_difference_RMS_rad'])<1e-12
        assert rms<=cfg['relative_body_angle_RMS_limit_rad'] and delta<=cfg['integer_vs_float_body_angle_RMS_limit_rad']
    unit=read(HERE/'evidence/adapter_checks.json');assert unit['passed'] and unit['metadata_and_singular_matrix_rejections']==3
    assert unit['maximum_unrounded_error_DAC_LSB']<=cfg['adapter_error_limit_DAC_LSB']
    sim=read(HERE/'evidence/simulink_scoreboard.json');assert sim['plant_relative_max']==sim['diagnostic_max']==0
    assert sim['ADC_bit_identical'] and sim['DAC_bit_identical'] and sim['diagnostics_NaN_masks']
    ode=read(HERE/'evidence/ODE_checks.json');assert ode['passed'] and ode['max_charge_error_over_target']<cfg['ODE_relative_charge_limit']
    rtl=read(HERE/'evidence/rtl_results.json');assert rtl['actual_bit_identical'] and rtl['mutation_rejected']
    for n,h in rtl['source_sha256'].items():assert sha(ROOT/n)==h,n
    vec=(HERE/'data/vectors.hex').read_text(encoding='ascii').splitlines();actual=(HERE/'evidence/rtl_actual.hex').read_text(encoding='ascii').splitlines()
    assert len(vec)==len(actual)==rtl['core_cycles']==64003
    assert all(int(v.split()[1],16)==int(a,16) for v,a in zip(vec,actual))
    # 重新从当前闭环记录编码输入，防止只核对旧向量与旧RTL日志而漏掉记录变化。
    sys.path.insert(0,str(HERE.parent/'digital_drive_d0_20261104'))
    from run_d0 import pack,FIELDS,OUT_WIDTHS
    last=[0]*9;previous=None;cursor=1
    with (HERE/'data/rtl_replay.csv').open(encoding='utf-8',newline='') as f:
        for row in csv.reader(f):
            v=[int(float(x)) for x in row];x=v[:23];out=v[23:]
            matrix=sum((c&0xfffff)<<(20*i) for i,c in enumerate(x[15:23]));values=x[:11]+[matrix]+x[11:15]
            key=tuple(x[2:11]+x[15:23]);idle=values.copy();idle[1]=int(key!=previous);idle[12]=0;held=last.copy();held[0]=0
            sample=values.copy();sample[1]=0;sample[12]=1
            for inp,expected in [(idle,held),(sample,out)]:
                stored=vec[cursor].split();assert int(stored[0],16)==pack(inp,[b for _,b in FIELDS]) and int(stored[1],16)==pack(expected,OUT_WIDTHS)
                cursor+=1
            last=out;previous=key
    assert cursor==len(vec)
    provenance=read(HERE/'source_provenance.json');source=ROOT/provenance['source'];assert sha(source)==provenance['sha256']
    expected=source.read_text(encoding='utf-8').replace('function [s,u,d]=sn_tick(s,adc,p,c)','function [s,u,d]=a4_control_tick(s,adc,p,c)',1).replace(
        'raw=real(phasor*exp(1i*s.phase));[u,~,dacclip]=pcn_quantize(raw,p.dac_span,p.dac_bits,p.vmax);','[u,dacclip]=a4_drive(s,p,c);',1)
    assert expected==(HERE/'a4_control_tick.m').read_text(encoding='utf-8')
    for name in ['a4_control_tick.m','a4_drive.m','a4_observe.m']:
        code=(HERE/name).read_text(encoding='utf-8')
        assert all(token not in code for token in ['p.Omega','p.theta0','z.omega','a4_metrics']),name
    return dict(cases=6,matched=6,adapter_max_error_DAC_LSB=unit['maximum_unrounded_error_DAC_LSB'],
        max_body_RMS_rad=max(r['integer']['relative_body_RMS_rad'] for r in results.values()),
        max_integer_vs_float_RMS_rad=max(r['body_difference_RMS_rad'] for r in results.values()),
        Simulink_ADC_DAC_bit_identical=True,Simulink_plant_difference=0,
        RTL_physical_samples=rtl['physical_samples'],RTL_core_cycles=len(vec),RTL_bit_identical=True,
        ODE_max_charge_error_over_target=ode['max_charge_error_over_target'],reference_before_origin_NaN=True,
        scope='合成固定标定、最小D0反馈链；非A2/A3全链、非硬件实时闭环、非稳定裕量证明')
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--seal',action='store_true');args=p.parse_args();result=check()
    if args.seal:
        names=['sn_tick.m','sn_state.m','sn_smooth.m','sn_setup.m']
        dependencies=['HRG_WA_simulink/piezo_v10/noise_research/'+n for n in names]
        dependencies += ['HRG_WA_simulink/piezo_v10/revision_v10_2_cn/'+n for n in ['pcn_plant.m','pcn_quantize.m','pcn_calibration.m','pcn_config.m','pcn_validity.m','pcn_json.m','p103_setup.m','evidence/calibration_profile.json']]
        dependencies += ['research/digital_drive_d0_20261104/'+n for n in ['rtl/hrg_wa_drive_d0.sv','tb/tb_drive_d0.sv','run_d0.py','manifest.json']]
        dependencies += ['HRG_WA_simulink/piezo_v10/compensation_research/'+n for n in ['comp_config.m','comp_setup.m']]
        dependencies += ['HRG_WA_simulink/piezo_v10/nonideal_validation/stress_setup.m','HRG_WA_simulink/piezo_v10/quality_dashboard/quality_setup.m']
        (HERE/'manifest.json').write_text(json.dumps(dict(date='2026-11-05',files=inventory(),dependencies={n:sha(ROOT/n) for n in dependencies}),ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    if (HERE/'manifest.json').exists():
        m=read(HERE/'manifest.json');assert m['files']==inventory(),'封存字节已改变，须审查后重封'
        for n,h in m['dependencies'].items():assert sha(ROOT/n)==h,n
    print(json.dumps(result,ensure_ascii=False,indent=2))
