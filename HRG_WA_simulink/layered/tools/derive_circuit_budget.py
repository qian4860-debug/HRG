"""Reproduce the documented illustrative HRG circuit budget (not silicon signoff)."""
import argparse
import hashlib
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[1]
PROFILE = PROJECT / 'HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA/config/head_default.json'
OUTPUT = ROOT / 'evidence/circuit_derivation/budget.json'


def calculate():
    config = (ROOT / 'wl_config.m').read_text(encoding='utf-8-sig')
    head = json.loads(PROFILE.read_text(encoding='utf-8-sig'))['mechanical']

    def c(name):
        # Only literal default assignments; do not evaluate MATLAB expressions.
        found = re.search(r'c\.' + re.escape(name) + r'=([+-]?[0-9.]+(?:e[+-]?[0-9]+)?);', config)
        if not found:
            raise ValueError('Expected numeric default assignment: ' + name)
        return float(found.group(1))

    f, Q, B = head['f0_hz'], head['quality_factor'], head['bryan']
    w, gamma = 2 * math.pi * f, math.pi * f / Q
    m, A, kF, fs = c('massKg'), c('displacementM'), c('driveNPerV'), c('fsAdc')
    C0, Cf, Rf, gap, bias, gain = [c(s) for s in ['c0F', 'cfF', 'rfOhm', 'gapM', 'biasV', 'pgaGain']]
    Be, angle_goal, build_s, phase_tol = 100., 1e-6, .1, math.radians(.1)
    kv, vs = gain * bias * C0 / (gap * Cf), gain * bias * C0 * A / (gap * Cf)
    zf = Rf / math.hypot(1, w * Rf * Cf)
    kB, T = 1.380649e-23, c('temperatureK')
    ith = math.sqrt(4 * kB * T / Rf)
    # Same simplified noise reference plane as wl_setup, no parasitic capacitance.
    noise_gain = (C0 + Cf) / Cf
    ev = math.sqrt((gain * noise_gain * c('cvEnVrtHz')) ** 2
                   + (gain * zf) ** 2 * (c('cvInArtHz') ** 2 + ith ** 2)
                   + c('pgaNoiseVrtHz') ** 2)
    adc_step = 2 * c('adcFsV') / 2 ** int(c('adcBits'))
    dac_step = 2 * c('dacFsV') / 2 ** int(c('dacBits'))
    force_hold = m * w * w * A / Q
    force_ramp = 2 * m * w * (A / build_s + gamma * A)
    force_constant = 2 * m * w * gamma * A / (-math.expm1(-gamma * build_s))
    a = w * Rf * Cf
    gdet = a / math.hypot(1, a)
    for pole in ['cvBandwidthHz', 'pgaBandwidthHz', 'antiAliasHz']:
        gdet /= math.hypot(1, f / c(pole))
    r = round(fs / 1000)
    cic_delay = 3 * (r - 1) / (2 * fs)
    delay = cic_delay + .002 + .003 + .001 + 2 / fs + .5 / fs
    adc_sigma = adc_step / (2 * B * vs) * math.sqrt(Be / (3 * fs))
    required_bits = math.ceil(math.log2(2 * c('adcFsV') / (angle_goal * 2 * B * vs) * math.sqrt(Be / (3 * fs))))
    image = fs - f
    image_ratio = f / image
    image_driver = image_ratio * math.hypot(1, f / c('driverBandwidthHz')) / math.hypot(1, image / c('driverBandwidthHz'))
    x = math.pi * f / fs
    fsplant = c('fsPlant')

    def rk4_decay(sample_rate):
        z = 1j * w / sample_rate
        p = 1 + z + z*z/2 + z**3/6 + z**4/24
        return -sample_rate * math.log(abs(p))

    results = {
        'scenario': {'status': 'unmeasured illustrative design, not specification',
                     'angleGoalRad': angle_goal, 'demodENBHz': Be, 'linearRampBuildS': build_s,
                     'phaseToleranceRad': phase_tol, 'noiseReference': 'ideal 0.2V readout, independent equal channels',
                     'controlRateHz': 1000, 'pipelineControlSamples': 3,
                     'assumptions': 'small amplitude, slow envelope; white uncorrelated ADC error; no parasitic capacitance; no true-resonance or startup qualification'},
        'mechanics': {'omega0RadS': w, 'amplitudeDecayPerS': gamma,
                      'amplitudeTauS': 1/gamma, 'energyTauS': 1/(2*gamma),
                      'powerLinewidthHz': f/Q, 'modalStiffnessNPerM': m*w*w,
                      'mechanicalEnergyJ': .5*m*w*w*A*A,
                      'holdForcePeakN': force_hold, 'holdVoltagePeakV': force_hold/kF,
                      'rampBuildForcePeakN': force_ramp, 'rampBuildVoltagePeakV': force_ramp/kF,
                      'constantForceBuildVoltageV': force_constant/kF,
                      'modelDeadZoneDegPerH': abs(head['damping_anisotropy_per_s'])/(4*B)*180/math.pi*3600},
        'readout': {'effectiveHalfDifferentialCapPeakF': C0*A/gap,
                    'signalCurrentPeakA': w*bias*C0*A/gap, 'gainVPerM': kv,
                    'idealSignalPeakV': vs, 'nominalReadoutGain': gdet,
                    'nominalEnergyGain': gdet*gdet, 'physicalEnergyAtUnitIQ': 1/(gdet*gdet),
                    'feedbackImpedanceOhm': zf, 'feedbackThermalCurrentASD': ith,
                    'simplifiedOutputNoiseASD': ev,
                    'simplifiedNoiseAngleRmsRad': ev*math.sqrt(2*Be)/(2*B*vs),
                    'totalWhiteNoiseBudgetASD': angle_goal*2*B*vs/math.sqrt(2*Be),
                    'gainMismatchResidualBound': 4*B*angle_goal},
        'conversion': {'adcStepV': adc_step, 'adcOnlyAngleRmsRad': adc_sigma,
                       'adcIdealBitsForEntireGoal': required_bits,
                       'dacStepV': dac_step, 'holdPeakDacCodes': force_hold/kF/dac_step,
                       'rawJitterSNRdB': -20*math.log10(w*c('jitterRmsS')),
                       'fixedSkewForPhaseToleranceS': phase_tol/w,
                       'dacZohMagnitude': math.sin(x)/x, 'dacZohPhaseDeg': -x*180/math.pi,
                       'firstImageHz': image, 'firstImageBeforeDriverDBc': 20*math.log10(image_ratio),
                       'firstImageWithDriverDBc': 20*math.log10(image_driver)},
        'bandwidth': {'onePoleForOnePercentDroopHz': f/math.sqrt(.99**-2-1),
                      'onePoleForPhaseToleranceHz': f/math.tan(phase_tol),
                      'driverSlewForRampPeakVPerS': w*force_ramp/kF,
                      'aaAttenuationAtFirstImageDB': -20*math.log10(math.hypot(1, image/c('antiAliasHz'))),
                      'cicGroupDelayS': cic_delay, 'illustrativeLoopDelayS': delay,
                      'delayOnlyThirtyDegreeCrossoverHz': 1/(12*delay),
                      'temperatureFrequencySlopeHzPerK': f*(-18e-6),
                      'finePllTwoHzTemperatureRangeK': 2/abs(f*(-18e-6)),
                      'quadPhaseLeakWorstDegPerH': math.pi*abs(head['frequency_split_hz'])*phase_tol/(2*B)*180/math.pi*3600},
        'noiseAndNumerics': {'brownianForceASD': math.sqrt(4*kB*T*(2*gamma*m)),
                            'rk4LinearNumericalDecayPerS': rk4_decay(fsplant),
                            'rk4LinearDecayToPhysicalRatio': rk4_decay(fsplant)/gamma,
                            'rk4DoubleRateDecayToPhysicalRatio': rk4_decay(2*fsplant)/gamma},
    }
    # Independent physical identities and order-of-magnitude anchors catch mapping mistakes.
    assert math.isclose(force_hold * w * A / 2, 2*gamma*results['mechanics']['mechanicalEnergyJ'], rel_tol=1e-12)
    assert math.isclose(results['mechanics']['constantForceBuildVoltageV'] * kF / (2*m*w*gamma)
                        * (-math.expm1(-gamma*build_s)), A, rel_tol=1e-12)
    assert math.isclose(gdet, .9370023143072796, rel_tol=1e-10)
    assert 3.97e-6 < adc_sigma < 3.98e-6 and required_bits == 20
    assert math.isclose(delay, .007525, abs_tol=1e-12)
    assert 8 < force_hold/kF/dac_step < 8.1
    sources = [ROOT/'wl_config.m', PROJECT/'HRG_WA_simulink/wa_parameters.m', PROFILE,
               ROOT/'evidence/principle_acceptance/manifest.json', Path(__file__)]
    results['provenance'] = {p.relative_to(PROJECT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='write this new budget only; do not touch older receipts')
    args = parser.parse_args()
    result = calculate()
    if args.write:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    else:
        saved = json.loads(OUTPUT.read_text(encoding='utf-8'))
        assert saved == result, 'Inputs or calculation changed: review the budget before explicitly rewriting it'
    print('PASS circuit derivation: physical identities, ADC budget, readout reference, timing and source hashes')


if __name__ == '__main__':
    main()
