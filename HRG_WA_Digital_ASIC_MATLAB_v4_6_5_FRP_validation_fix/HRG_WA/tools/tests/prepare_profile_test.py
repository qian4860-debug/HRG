from pathlib import Path
import argparse,copy,shutil,sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import head_config as h

p=argparse.ArgumentParser();p.add_argument('config',type=Path);p.add_argument('--out',type=Path,required=True);p.add_argument('--make-variants',action='store_true');a=p.parse_args()
c=h.validate(h.load(a.config));h.generate(c,a.out)
w={v['name']:v for v in h.runtime_words(c)}
order=['ENERGY_KP','ENERGY_KI','QUAD_KP','QUAD_KI','ENERGY_REF','VIRTUAL_RATE','NCO_FCW','ENERGY_HOLD','QUAD_HOLD','BRYAN','RATE_ALPHA']
values=[w[n]['signed_code'] for n in order]
values += [(w['ENERGY_REF']['signed_code']*h.compile_values(c)['ENERGY_TOL_Q30'][0])>>30,c['runtime']['enable_mask']]
(a.out/'spi_expected.txt').write_text(' '.join(map(str,values))+'\n',encoding='utf-8')
if a.make_variants:
    variant=copy.deepcopy(c);variant['head_id']='runtime_fixture'
    variant['mechanical'].update(f0_hz=6200,quality_factor=3000000,bryan=.3,energy_target=1.2)
    variant['runtime'].update(energy_ki=0,energy_hold=0,quad_hold=-.02,virtual_rate_rad_s=.1)
    (a.out/'runtime_fixture.json').write_text(h.canonical(variant),encoding='utf-8')
    v=copy.deepcopy(c);v['head_id']='compile_fixture'
    v['build'].update(fs_adc_hz=80000,fs_ctrl_hz=2000,pipeline_delay_ctrl=4,
        energy_slew_per_s=3,quad_slew_per_s=6,startup_drive=.2,pll_kp_hz=4,pll_ki_hz_per_s=20)
    src=a.out/'custom_src';src.mkdir(exist_ok=True)
    for name in ['hrg_pi_aw.v','hrg_controller.v','hrg_dpll.v','hrg_navigation.v']:
        shutil.copyfile(h.ROOT/'src'/name,src/name)
    (src/'hrg_head_config.vh').write_text(h.header(h.validate(v)),encoding='utf-8')
    (a.out/'compile_fixture.json').write_text(h.canonical(v),encoding='utf-8')
print('PROFILE_TEST_FIXTURE_READY')
