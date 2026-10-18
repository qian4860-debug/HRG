from pathlib import Path
import copy,json,subprocess,sys,tempfile,unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import head_config as h

class HeadConfigTests(unittest.TestCase):
    def setUp(self):
        self.c=h.load(h.DEFAULT)
        self.tmp=tempfile.TemporaryDirectory(prefix='hrg_config_')
        self.addCleanup(self.tmp.cleanup);self.dir=Path(self.tmp.name)
        self.built=self.dir/'built.json'
        self.receipt={'build_sha256':h.build_id(self.c),'header_sha256':h.sha(h.header(self.c)),
            'head_id':'unit_test_fixture','compile_configuration':{'build':self.c['build'],'architecture':self.c['architecture']},
            'rtl_sources':h.sources()}
        self.built.write_text(json.dumps(self.receipt))
    def test_default_words(self):
        h.validate(self.c)
        words={v['name']:v for v in h.runtime_words(self.c)}
        expected={'NCO_FCW':0x20000000,'BRYAN':297426485,'ENERGY_REF':16777216,'ENERGY_KP':157286,
            'ENERGY_KI':22938,'QUAD_KP':458752,'QUAD_KI':91750,'ENERGY_HOLD':65884,'RATE_ALPHA':264448425}
        for key,value in expected.items(): self.assertEqual(words[key]['word'],value,key)
    def test_runtime_change_does_not_recompile(self):
        candidate=copy.deepcopy(self.c);candidate['head_id']='head_B'
        candidate['mechanical'].update(f0_hz=6200,bryan=.3,quality_factor=3000000,energy_target=1.2)
        candidate['runtime'].update(energy_ki=0,energy_hold=0,quad_hold=-.02)
        self.assertEqual(h.header(candidate),h.header(self.c))
        result=h.generate(candidate,self.dir/'out',self.built)
        self.assertTrue(result['compatible'])
        words={v['name']:v for v in h.load(self.dir/'out/spi_words.json')}
        self.assertEqual(words['ENERGY_KI']['word'],0)
        self.assertEqual(words['ENERGY_HOLD']['word'],0)
        self.assertLess(words['QUAD_HOLD']['signed_code'],0)
        self.assertEqual(words['QUAD_HOLD']['bytes_le'][3],255)
        # Numerically equivalent JSON spellings must not trigger recompilation.
        candidate['build']['fs_adc_hz']=40000.0
        candidate['build']['pll_kp_hz']=8
        self.assertTrue(h.compatibility(candidate,self.built)['compatible'])
    def test_model_only_change(self):
        c=copy.deepcopy(self.c);c['mechanical']['frequency_split_hz']=.02
        c['detection']['cross_matrix'][0][1]=.01
        self.assertTrue(h.compatibility(c,self.built)['compatible'])
        self.assertEqual(h.runtime_words(c),h.runtime_words(self.c))
        self.assertIn('u.res.frequencySplitHz = 0.02',h.matlab(c,h.runtime_words(c)))
    def test_every_compile_field_is_fingerprinted(self):
        for key,value in self.c['build'].items():
            if isinstance(value,dict):
                for child in value:
                    c=copy.deepcopy(self.c);c['build'][key][child]+=1
                    self.assertFalse(h.compatibility(c,self.built)['compatible'],child)
            else:
                c=copy.deepcopy(self.c);c['build'][key]=value+1
                status=h.compatibility(c,self.built)
                self.assertFalse(status['compatible'],key)
                self.assertEqual(status['changes'][0]['parameter'],'build.'+key)
    def test_sources_and_header_staleness(self):
        self.receipt['rtl_sources']={};self.built.write_text(json.dumps(self.receipt))
        self.assertTrue(h.compatibility(self.c,self.built)['recompile_required'])
        self.assertTrue(h.compatibility(self.c,self.dir/'missing.json')['recompile_required'])
    def test_reject_invalid_values(self):
        variants=[('mechanical','quality_factor',0),('mechanical','bryan',-0.277),('mechanical','f0_hz',19500),
            ('runtime','enable_mask',True),('runtime','rate_lpf_hz',0),('runtime','energy_kp',40000),
            ('runtime','virtual_rate_rad_s',1),('runtime','energy_hold',1),('build','fs_ctrl_hz',999),
            ('build','pipeline_delay_ctrl',0),('build','pll_ki_hz_per_s',0),('build','startup_seconds',0),
            ('build','energy_back_gain_per_s',3.5),('build','energy_limit',.7),('build','energy_slew_per_s',1e-12)]
        for section,key,value in variants:
            c=copy.deepcopy(self.c);c[section][key]=value
            with self.subTest(parameter=key),self.assertRaises(h.ConfigError):
                h.validate(c);h.compile_values(c);h.runtime_words(c)
    def test_unknown_keys_and_architecture(self):
        c=copy.deepcopy(self.c);c['runtime']['energy_Kp']=2
        with self.assertRaises(h.ConfigError): h.validate(c)
        c=copy.deepcopy(self.c);c['architecture']['adc_bits']=16
        with self.assertRaises(h.ConfigError): h.validate(c)
        c=copy.deepcopy(self.c);c['architecture']['fir_coefficients'][0]=True
        with self.assertRaises(h.ConfigError): h.validate(c)
    def test_non_finite_and_duplicate_json(self):
        for text in ['{"schema_version": NaN}','{"schema_version":1,"schema_version":2}']:
            p=self.dir/'bad.json';p.write_text(text)
            with self.assertRaises(h.ConfigError): h.load(p)
    def test_constant_virtual_command_model_mapping(self):
        c=copy.deepcopy(self.c);c['runtime']['virtual_rate_rad_s']=.1
        text=h.matlab(c,h.runtime_words(c))
        self.assertIn('u.virtual.enable = true;',text)
        self.assertIn('u.virtual.frequencyHz = 0;',text)
        c['runtime']['enable_mask']=7
        self.assertIn('u.virtual.enable = false;',h.matlab(c,h.runtime_words(c)))
    def test_deterministic_generation_and_spi_order(self):
        out=self.dir/'out';h.generate(self.c,out,self.built)
        before={p.name:p.read_bytes() for p in out.iterdir()}
        h.generate(self.c,out,self.built)
        self.assertEqual(before,{p.name:p.read_bytes() for p in out.iterdir()})
        steps=h.load(out/'spi_plan.json')['steps']
        self.assertEqual(steps[:2],[{'op':'write8','address':112,'value':0},{'op':'write8','address':0,'value':0}])
        self.assertEqual(steps[2]['value'],h.MAGIC)
        self.assertEqual(steps[-2],{'op':'wait_adc_samples','count':42})
        self.assertEqual(steps[-1],{'op':'write8','address':0,'value':63})
    def test_build_receipt_requires_fresh_passed_evidence(self):
        pending={**self.receipt,'started_ns':0}
        pp=self.dir/'pending.json';pp.write_text(json.dumps(pending))
        sim=self.dir/'sim.log';elab=self.dir/'elab.log'
        sim.write_text('TOP_SCOREBOARD_PASS\n');elab.write_text('HRG_RTL_ELABORATION_PASS\n')
        args=['finish-build','--pending',str(pp),'--simulation-log',str(sim),'--elaboration-log',str(elab),'--out',str(self.dir/'done.json')]
        self.assertEqual(h.main(args),0)
        sim.write_text('TOP_SCOREBOARD_PASS\nFatal: injected\n')
        self.assertEqual(h.main(args),3)
        pending['started_ns']=10**30;pp.write_text(json.dumps(pending));sim.write_text('TOP_SCOREBOARD_PASS\n')
        self.assertEqual(h.main(args),3)
    def test_cli_check_exit_codes(self):
        cfg=self.dir/'profile.json';cfg.write_text(json.dumps(self.c))
        self.assertEqual(h.main(['check',str(cfg),'--built',str(self.built)]),0)
        c=copy.deepcopy(self.c);c['build']['startup_seconds']=.3;cfg.write_text(json.dumps(c))
        self.assertEqual(h.main(['check',str(cfg),'--built',str(self.built)]),2)

if __name__=='__main__': unittest.main()
