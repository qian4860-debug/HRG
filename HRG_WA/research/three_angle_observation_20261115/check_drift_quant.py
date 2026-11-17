"""第47号独立回执与无控制双模态解析对照；只依赖标准库，不读取角度真值来调参。"""
import json
import math
from pathlib import Path


def free_body_angle(t, beta_deg, split_hz, axis_rad=.37, bryan=.27699096196168066):
    # 窄带包络：theta=2beta-axis，四倍驻波角为 atan2(sin(2theta)*cos(2πΔft),cos(2theta))。
    theta = 2 * math.radians(beta_deg) - axis_rad
    az0 = math.atan2(math.sin(2*theta), math.cos(2*theta))
    az = math.atan2(math.sin(2*theta)*math.cos(2*math.pi*split_hz*t), math.cos(2*theta))
    delta = math.atan2(math.sin(az-az0), math.cos(az-az0))
    return -delta / (4*bryan)


def slope(x, y):
    xm, ym = sum(x)/len(x), sum(y)/len(y)
    return sum((a-xm)*(b-ym) for a,b in zip(x,y))/sum((a-xm)**2 for a in x)


def main(folder):
    r=json.loads((folder/'drift_quant_verification.json').read_text(encoding='utf-8'))
    assert len(r['cases'])==26 and len(r['native_parity'])==8
    assert math.isclose(r['true_mirror_beta_deg']+22.5, math.degrees(r['stiffness_axis_modal_rad']), abs_tol=1e-12)
    for row in r['cases']:
        assert len(row['windows'])==2
        for w in row['windows']:
            parts=sum(w[k] for k in ('mechanical_mrad_s','readout_mrad_s','publication_mrad_s'))
            assert math.isclose(parts,w['total_mrad_s'],abs_tol=1e-7)
            assert w['frames']>=10
        passed=(row['full_publication'] and row['no_clipping'] and row['peak_fraction_half_span']<.8
                and all(w['all_frames_usable'] and abs(w['total_mrad_s'])<=.25 for w in row['windows']))
        assert row['offline_absolute_screen_pass']==passed
    for p in r['native_parity']:
        assert p['event_flags_equal']
        assert p['angle_gate_pass']==(p['max_angle_delta_rad']<p['angle_gate_rad'])
        if p['label'].startswith('short_'):
            assert p['converter_mismatches']==0 and p['angle_gate_pass']
    # 独立解析近似只说明符号与时间趋势；不拟合或替代机电/控制闭环。
    analytic=[]
    for beta in (22.5,r['true_mirror_beta_deg'],r['physical_axis_beta_deg']):
        for split in (0,.05,-.05):
            rates=[]
            for start,end in ((.02,.06),(.08,.12)):
                t=[start+(end-start)*k/1000 for k in range(1001)]
                y=[free_body_angle(a,beta,split) for a in t]
                rates.append(1000*slope(t,y))
            analytic.append(dict(beta_deg=beta,split_Hz=split,window_slopes_mrad_s=rates))
    assert abs(analytic[1]['window_slopes_mrad_s'][1]+analytic[4]['window_slopes_mrad_s'][1])<1e-10
    assert analytic[1]['window_slopes_mrad_s']==analytic[2]['window_slopes_mrad_s']
    regression=json.loads((folder/'zero_dither_regression.json').read_text(encoding='utf-8'))
    assert regression['status']=='passed' and len(regression['cases'])==2
    assert all(x['whole_trace_exact'] and x['whole_frames_exact'] and x['whole_candidates_exact']
               for x in regression['cases'])
    out=dict(status='receipt_checks_passed',zero_dither_regression=regression,
             native_angle_gate_failures=[p for p in r['native_parity'] if not p['angle_gate_pass']],
             assumptions='Unforced narrowband modal envelopes, isotropic damping, no electrical back-action or control.',
             analytic_free_envelope=analytic)
    (folder/'drift_quant_audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('26 cases / 52 score windows / 8 native comparisons verified.')
    print('Native angle gate failures:',len(out['native_angle_gate_failures']))


if __name__=='__main__':
    main(Path(__file__).resolve().parent)
