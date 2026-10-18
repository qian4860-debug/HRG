"""Archive the executed checks without overwriting earlier delivery evidence."""
from pathlib import Path
import copy,json,re
import head_config as h

root=h.ROOT;tests=root/'tools/tests';sb=root/'testbench/scoreboard'
logs={
 'unit_tests.txt':(tests/'config_unit_tests.log',r'Ran 12 tests'),
 'spi_runtime.txt':(tests/'profile_simulation.log','HEAD_PROFILE_SCOREBOARD_PASS'),
 'custom_numeric.txt':(tests/'custom_simulation.log','CUSTOM_HEAD_NUMERIC_SCOREBOARD_PASS'),
 'matlab_profile.txt':(tests/'matlab_head_profile.log','GENERATED_MATLAB_HEAD_PROFILE_PASS'),
 'baseline_frontend.txt':(sb/'simulation.log','MATLAB_EQUIVALENCE_PASS'),
 'baseline_loops.txt':(sb/'loop_simulation.log','LOOP_SCOREBOARD_PASS'),
 'baseline_top.txt':(sb/'top_scoreboard_simulation.log','TOP_SCOREBOARD_PASS'),
 'rtl_elaboration.txt':(sb/'rtl_elaboration.log','HRG_RTL_ELABORATION_PASS'),
}
c=h.validate(h.load(h.DEFAULT));status=h.compatibility(c)
assert status['compatible'],status
out=root/'config/evidence_20261018';out.mkdir(exist_ok=True)
for name,(path,marker) in logs.items():
    text=path.read_text(encoding='utf-8-sig')
    assert marker in text,(path,marker)
    if name=='unit_tests.txt': assert '\nOK' in text and 'FAILED (' not in text
    else: assert 'Fatal:' not in text,path
    (out/name).write_text(text,encoding='utf-8',newline='\n')
runtime=copy.deepcopy(c);runtime['mechanical']['f0_hz']=6200
changed=copy.deepcopy(c);changed['build']['startup_seconds']=.3
rstatus=h.compatibility(runtime);bstatus=h.compatibility(changed)
assert rstatus['compatible'] and bstatus['recompile_required']
summary=dict(default_build_compatible=status,tests_passed=12,
    runtime_only_change=rstatus,compile_change=bstatus,
    baseline=h.load(sb/'results.json'),
    runtime_fixture_words=h.load(tests/'_work/runtime/spi_words.json'),
    nondefault_test_configuration=h.load(tests/'_work/base/compile_fixture.json')['build'],
    limitations=['RTL build identity only; hardware image not read back',
        'Nondefault profile tested at selected numeric points, not full per-head closed-loop performance'],
    rtl_sources=h.sources(),generator_sha256=h.sha((root/'tools/head_config.py').read_text(encoding='utf-8')))
(root/'config/validation_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('HEAD_CONFIGURATION_VALIDATION_PASS')
