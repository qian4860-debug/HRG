"""只读检查D0接口、逐拍实际输出和封存字节；--seal仅在审查后使用。"""
from pathlib import Path
import argparse
import hashlib
import json

HERE=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def inventory():
    return {p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file()
        and 'sim' not in p.relative_to(HERE).parts and '__pycache__' not in p.parts and p.name!='manifest.json'}
def check():
    g=read(HERE/'evidence/generation.json');m=read(HERE/'evidence/matlab_scoreboard.json');r=read(HERE/'evidence/rtl_results.json')
    assert g['rows']==m['rows']==6055 and m['fields']==9 and m['passed'] and m['maximum_absolute_difference']==0
    assert g['analytic_stage_error_bound_passed'] and g['positive_negative_fullscale_checked'] and g['positive_negative_half_LSB_checked']
    assert r['scoreboard_passed'] and r['mutated_expected_output_rejected']
    for n,h in r['source_sha256'].items():assert sha(HERE/n)==h,n
    vectors=(HERE/'data/vectors.hex').read_text(encoding='ascii').splitlines()
    actual=(HERE/'evidence/rtl_actual.hex').read_text(encoding='ascii').splitlines()
    assert len(vectors)==len(actual)==6055
    assert all(int(v.split()[1],16)==int(a,16) for v,a in zip(vectors,actual))
    assert 'D0_MISMATCH row=2' in (HERE/'evidence/mutation_detected.txt').read_text(encoding='utf-8')
    return dict(rows=6055,fields=9,RTL_actual_trace_bit_identical=True,MATLAB_maximum_difference=0,
        floating_unrounded_maximum_difference_DAC_LSB=g['max_floating_code_difference'],
        analytic_stage_bound_passed=True,mutation_rejected=True,
        scope='离线数字驱动接口验证；未接NCO/控制器/机械闭环，未综合或硬件测量')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--seal',action='store_true');args=parser.parse_args()
    result=check()
    if args.seal:
        dependencies=['HRG_WA_simulink/piezo_v10/noise_research/sn_tick.m',
            'HRG_WA_simulink/piezo_v10/revision_v10_2_cn/pcn_calibration.m']
        (HERE/'manifest.json').write_text(json.dumps(dict(date='2026-11-04',files=inventory(),
            dependencies={n:sha(HERE.parents[1]/n) for n in dependencies}),ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    if (HERE/'manifest.json').exists():
        seal=read(HERE/'manifest.json');assert seal['files']==inventory(),'封存后文件变化，必须先审查'
        for n,h in seal['dependencies'].items():assert sha(HERE.parents[1]/n)==h,n
    print(json.dumps(result,ensure_ascii=False,indent=2))
