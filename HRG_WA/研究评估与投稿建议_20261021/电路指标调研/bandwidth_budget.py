"""Independent frequency-domain budget; not a replacement for the accepted plant/RTL.

Uses user-provided converter data and explicitly assumed scenario parameters.
It does not certify closed-loop stability, BI, silicon performance or anti-alias rejection.
"""
import cmath
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent


def db(value):
    return 20 * math.log10(max(abs(value), 1e-300))


def lowpass(f_hz, pole_hz):
    return 1 / (1 + 1j * f_hz / pole_hz)


def sampled_onepole(f_hz, fs_hz, pole_hz):
    alpha = 1 - math.exp(-2 * math.pi * pole_hz / fs_hz)
    return alpha / (1 - (1 - alpha) * cmath.exp(-2j * math.pi * f_hz / fs_hz))


def zoh(f_hz, fs_hz):
    x = math.pi * f_hz / fs_hz
    return (math.sin(x) / x if x else 1) * cmath.exp(-1j * x)


def cic(f_hz, fs_hz, ratio, order):
    w = 2 * math.pi * f_hz / fs_hz
    if abs(w) < 1e-14:
        return 1 + 0j
    return ((1 - cmath.exp(-1j * w * ratio)) /
            (ratio * (1 - cmath.exp(-1j * w)))) ** order


def fir(f_hz, fs_hz, taps):
    return sum(t * cmath.exp(-2j * math.pi * f_hz * k / fs_hz)
               for k, t in enumerate(taps)) / sum(taps)


def pll_reference(f_hz, natural_hz, damping):
    """Canonical type-II second-order reference-to-output model, not identified HRG loop."""
    s = 2j * math.pi * f_hz
    wn = 2 * math.pi * natural_hz
    return (2 * damping * wn * s + wn * wn) / (s*s + 2*damping*wn*s + wn*wn)


def pll_vco(f_hz, natural_hz, damping):
    return 1 - pll_reference(f_hz, natural_hz, damping)


def ad9215_check(fs_hz):
    if fs_hz < 5e6:
        raise ValueError('AD9215 physical sample clock must be at least 5 MSPS per Rev B')
    if fs_hz > 65e6:
        raise ValueError('Above conservative 65 MSPS limit; confirm actual speed suffix first')


def jitter_limit(f_input_hz, snr_db):
    return 10 ** (-snr_db / 20) / (2 * math.pi * f_input_hz)


def motion_terms(rate_dps, bryan):
    return {'rate_dps': rate_dps,
            'iq_orientation_hz': bryan * abs(rate_dps) / 180,
            'rs_orientation_hz': bryan * abs(rate_dps) / 90}


def modal_matrix(group_opposites):
    """Rows = cos(2a), sin(2a); grouped columns sum opposite electrodes."""
    a = [k * math.pi / 4 for k in range(8)]
    matrix = [[math.cos(2*x) for x in a], [math.sin(2*x) for x in a]]
    if group_opposites:
        matrix = [[r[k] + r[k+4] for k in range(4)] for r in matrix]
    return matrix


def rf_transfer(f_hz, adc_fs, adc_cycles, dac_fs, deskew_cycles,
                afe_poles, reconstruction_poles, analog_delay_s):
    """Analytic tone transfer. Not an aliasing or switched-electrode simulation."""
    h = zoh(f_hz, dac_fs)
    delay = adc_cycles / adc_fs + deskew_cycles / dac_fs + analog_delay_s
    h *= cmath.exp(-2j * math.pi * f_hz * delay)
    for pole in afe_poles + reconstruction_poles:
        h *= lowpass(f_hz, pole)
    return h


def run():
    spec = json.loads((HERE / 'provisional_spec.json').read_text(encoding='utf-8'))
    physical = spec['external_converter_assumed_profile']
    ad9215_check(physical['adc_fs_hz'])
    profiles = spec['digital_profiles']
    result = {'status': 'analytical budget under assumptions; not measured',
              'unknowns': spec['unknowns'], 'motion_terms': [], 'digital_profiles': {},
              'converter': {}, 'rf_examples': [], 'pll_examples': []}
    for speed in [100, 1000, 10000]:
        result['motion_terms'].append(motion_terms(speed, spec['bryan_assumed']))
    for name, p in profiles.items():
        fs, rate, order = p['input_fs_hz'], p['decimation'], p['cic_order']
        out_fs = fs / rate
        assert out_fs == p['control_fs_hz']
        delay = order * (rate-1) / (2*fs) + (len(p['fir'])-1) / (2*out_fs)
        command_delay = p['command_cycles'] / out_fs
        entries = []
        for freq in [1, 5, 10, 30, 45, 100, 200]:
            if freq >= out_fs / 2:
                continue
            h = cic(freq, fs, rate, order) * fir(freq, out_fs, p['fir'])
            h *= cmath.exp(-2j * math.pi * freq * command_delay)
            nav = sampled_onepole(freq, out_fs, p['navigation_lpf_hz'])
            entries.append({'frequency_hz': freq, 'detection_and_command_db': db(h),
                            'linear_group_delay_phase_deg': -360 * freq * (delay+command_delay),
                            'navigation_lpf_only_db': db(nav),
                            'navigation_lpf_only_phase_deg': math.degrees(cmath.phase(nav))})
        result['digital_profiles'][name] = {
            'filter_group_delay_s': delay, 'command_delay_s': command_delay,
            'partial_total_delay_s': delay+command_delay,
            'crossover_ceiling_for_30deg_delay_allocation_hz': 30/(360*(delay+command_delay)),
            'warning': 'Delay allocation only; NOT a phase margin or complete loop transfer',
            'responses': entries}
    adc_fs = physical['adc_fs_hz']
    result['converter'] = {
        'adc_pipeline_delay_s': 5/adc_fs,
        'adc_bits_physical': 10, 'dac_bits_physical': 14,
        'dac_settling_spec': '11 ns typical to 0.1%, NOT a 14-bit half-LSB guarantee',
        'noise_process_gain_100hz_db': 10*math.log10(adc_fs/(2*100)),
        'noise_process_gain_warning': 'White uncorrelated noise only; no INL/spur/flicker improvement guarantee',
        'jitter_80db_at_5khz_s': jitter_limit(5000, 80),
        'jitter_80db_at_1mhz_s': jitter_limit(1e6, 80),
        'skew_for_0p01deg_at_1mhz_s': .01/(360*1e6),
        'raw_minimum_clock_40ksps_compatible': False}
    for tone in [5000, 10000, 500000, 1000000]:
        h = rf_transfer(tone, adc_fs, 5, physical['dac_fs_hz'],
                        physical['dac_deskew_cycles'], physical['afe_poles_hz_assumed'],
                        physical['reconstruction_poles_hz_assumed'], 4e-9)
        result['rf_examples'].append({'tone_hz': tone, 'amplitude_db': db(h),
                                      'wrapped_phase_deg': math.degrees(cmath.phase(h)),
                                      'warning': 'Assumed poles, uncompensated tone phase; not measured AFE'})
    for natural in [1, 5, 20]:
        result['pll_examples'].append({
            'natural_frequency_hz': natural, 'damping': .707,
            'reference_gain_at_10hz_db': db(pll_reference(10,natural,.707)),
            'vco_gain_at_10hz_db': db(pll_vco(10,natural,.707)),
            'warning': 'Natural frequency is NOT the -3dB bandwidth; actual HRG loop requires plant/controller'})
    result['electrode_modal_matrices'] = {
        'eight_independent': modal_matrix(False), 'four_opposite_pairs': modal_matrix(True),
        'warning': 'Ideal n=2 mechanical coupling only; not electrical noise/feedthrough equivalence'}
    (HERE / 'budget_results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'legacy_partial_delay_ms': result['digital_profiles']['legacy']['partial_total_delay_s']*1000,
                      'proposed_partial_delay_ms': result['digital_profiles']['candidate_5khz']['partial_total_delay_s']*1000,
                      'motion_terms': result['motion_terms'], 'converter': result['converter']},indent=2))


if __name__ == '__main__':
    run()
