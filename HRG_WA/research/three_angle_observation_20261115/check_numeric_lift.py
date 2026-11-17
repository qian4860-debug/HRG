"""第48号回执独立核查：边界异码、公共载波对拍、帧级模型适用范围。"""
from pathlib import Path
import json
import math


def main(folder):
    boundary=json.loads((folder/'boundary_probe.json').read_text(encoding='utf-8'))
    for row in boundary['cases']:
        p=row['first_code_details']
        assert p['converter']=='DAC'
        a,b=p['reference_scaled_code'],p['native_scaled_code']
        threshold=p['threshold_code']
        assert (a-threshold)*(b-threshold)<0
        rnd=lambda x: math.copysign(math.floor(abs(x)+.5),x)
        assert rnd(a)==p['reference_round'] and rnd(b)==p['native_round']
        assert abs(p['reference_round']-p['native_round'])==1
    r=json.loads((folder/'numeric_lift_verification.json').read_text(encoding='utf-8'))
    assert len(r['periodic_parity'])==3 and len(r['lift_short_checks'])==6 and len(r['lift_long_runs'])==2
    for p in r['periodic_parity']:
        assert p['events_equal'] and p['converter_mismatches']==0 and p['max_angle_delta_rad']<1e-7
    for p in r['lift_short_checks']:
        assert p['rail_free'] and p['max_candidate_angle_delta_rad']<1e-7
        if p['max_native_lift_trace_delta'] is not None:
            assert p['max_native_lift_trace_delta']<1e-7
    for p in r['lift_long_runs']:
        assert p['rail_free'] and p['duration_s']==20
        for mechanical,readout,total in p['slopes_mechanical_readout_total_mrad_s']:
            assert math.isclose(mechanical+readout,total,abs_tol=1e-7)
    long=json.loads((folder/'lift_long_native.json').read_text(encoding='utf-8'))
    assert len(long['long_native'])==2 and len(long['probe_regression'])==6
    assert all(x['frames']==34000 and x['max_trace_delta']<1e-7 and x['rail_free'] for x in long['long_native'])
    assert all(x['probe_read_is_exact_noop'] for x in long['probe_regression'])
    print('Boundary 2 / periodic parity 3 / lift short 6 / lift long 2: verified.')
    print('20s native parity 2 / read-only probe regression 6: verified.')


if __name__=='__main__':
    main(Path(__file__).resolve().parent)
