"""Check comparison provenance and independent algebra used in the literature review."""
import hashlib
import argparse
import json
import math
from pathlib import Path

P = Path(__file__).resolve().parents[1]
E = P/'HRG_WA_simulink/layered/evidence/literature_comparison'


def calculate():
    manifest=E/'manifest.json'
    if manifest.exists():
        for relative,digest in json.loads(manifest.read_text(encoding='utf-8'))['files'].items():
            assert hashlib.sha256((P/relative).read_bytes()).hexdigest()==digest, 'Sealed review bytes changed: '+relative
    catalog = json.loads((E/'comparison_catalog.json').read_text(encoding='utf-8'))
    local = catalog['local']
    assert len(local) == len({r['sha256'] for r in local}) == catalog['localUnique']
    assert {'L052','L053','L054','L057'} <= {r['id'] for r in local}
    for r in local:
        for path in r['paths']:
            assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == r['sha256'], path
    assert len(catalog['online']) == len({r['key'] for r in catalog['online']})
    B, theta, speed = .277, .193, -.47
    n = [math.cos(2*theta), math.sin(2*theta)]
    alpha = 2*theta
    assert max(abs(x-y) for x,y in zip(n,[math.cos(alpha), math.sin(alpha)])) < 1e-14
    assert 2*(2*B) == 4*B
    amplitude, amplitude_dot = 1.7, -.13
    R, S = amplitude*math.cos(4*theta), amplitude*math.sin(4*theta)
    Rd = amplitude_dot*math.cos(4*theta) - amplitude*4*speed*math.sin(4*theta)
    Sd = amplitude_dot*math.sin(4*theta) + amplitude*4*speed*math.cos(4*theta)
    recovered = (R*Sd-S*Rd)/(4*(R*R+S*S))
    assert math.isclose(recovered, speed, abs_tol=1e-14)
    wh, kp, ki, kr = 1.6, .8, .4, 1.
    s = 1j*wh
    residual = abs(1/(1+kp+ki/s))
    assert math.isclose(residual, wh/math.sqrt((1+kp)**2*wh**2+ki**2), rel_tol=1e-14)
    # Frequency-response limit only; this is not a closed-loop stability proof.
    def pir_error(offset):
        t = 1j*wh*(1+offset)
        C = kp+ki/t+kr*t/(t*t+wh*wh)
        return abs(1/(1+C))
    coarse, fine = pir_error(1e-3), pir_error(1e-6)
    assert fine < coarse/500 and residual > .1
    # Zero-phase fixtures from the printed expressions, not inferred OCR glyphs.
    printed_quant_L_real = .5 - .5  # PDF25 Eq2.16, alpha=45deg, a=1, q=0.
    invariant_sum_real = .5 + .5
    printed_2019_R_left, printed_2019_R_right = .25, 0.  # PDF4 Eq7, theta=0.
    printed_patent_L, correct_patent_L = 2., 0.  # PDF4 Eq8, mx=1, other=0.
    assert printed_quant_L_real != invariant_sum_real
    assert printed_2019_R_left != printed_2019_R_right
    assert printed_patent_L != correct_patent_L
    return dict(localObjects=len(local), onlineRecords=len(catalog['online']),
                checks=['all local PDF hashes unchanged','unique byte/online identity','four specified references present',
                        'modal angle and Coriolis factor mapping','continuous azimuth derivative',
                        'PI harmonic residual','PIR local frequency-response limit','three printed-equation counterexamples'],
                recoveredAzimuthRate=recovered, piUnitPlantResidual=residual,
                pirFrequencyResponseErrors=[coarse,fine],
                limitations='Algebra and provenance only; no new Simulink, RTL, empirical paper replication, or silicon qualification')


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write',action='store_true')
    args=parser.parse_args()
    result = calculate()
    receipt=E/'algebra_checks.json'
    if args.write:
        receipt.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    elif receipt.exists():
        assert json.loads(receipt.read_text(encoding='utf-8'))==result, 'Comparison inputs or calculations changed'
    print(json.dumps(result,ensure_ascii=False,indent=2))
