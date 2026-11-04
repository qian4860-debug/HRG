"""路线复核的事实清单；只读既有模型和验收证据，不重新生成旧结果。"""
from pathlib import Path
import hashlib
import json
import math
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args):
    return subprocess.check_output(
        ['git', '-c', 'safe.directory=' + str(ROOT), *args], cwd=ROOT)


def audit():
    paths = [
        'DSH_md/09_更新了什么_路线判断与备选_20261103.md',
        'DSH_md/08_现状盘点_下一步补什么_V5研判_20261102.md',
        'codex_md/03_读08后的下一步执行单_20261103.md',
        'codex_md/07_A3参考帧协方差守恒_重锚定与缺测恢复_20261103.md',
        '研究规划与论文路线_20261010/06_博士研究路线与阶段验收.md',
        '研究规划与论文路线_20261010/evidence/archive_邰涵翛-开题v0.5.txt',
        'HRG_WA_simulink/piezo_v10/revision_v10_2_cn/pcn_config.m',
        'HRG_WA_simulink/piezo_v10/revision_v10_2_cn/pcn_plant.m',
        'HRG_WA_simulink/piezo_v10/noise_research/sn_tick.m',
        'HRG_WA_simulink/piezo_v10/identification/measurement_contract.json',
        'HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA/README.md',
        'HRG_WA_Digital_ASIC_MATLAB_v4_6_5_FRP_validation_fix/HRG_WA/testbench/scoreboard/top_scoreboard_simulation.log',
        'research/causal_deembedding_20261103/config.json',
        'research/causal_deembedding_20261103/a2_dsp.py',
        'research/reference_covariance_20261103/evidence/scores.json',
        'research/reference_covariance_20261103/evidence/independent_check.json',
        'research/classics_addendum_20261030/sources.json',
    ]
    sources = [{'path': name, 'sha256': sha(ROOT/name)} for name in paths]
    seal_checks = []
    for name in ['port_to_metric', 'port_deembedding', 'causal_deembedding', 'reference_covariance']:
        base = ROOT/'research'/(name + '_20261103')
        manifest = json.loads((base/'manifest.json').read_text(encoding='utf-8'))
        for rel, expected in manifest['files'].items():
            assert sha(base/rel) == expected, str(base/rel)
        seal_checks.append(dict(package=name, files_checked=len(manifest['files']),
                                manifest_sha256=sha(base/'manifest.json')))
    tracked = git('ls-files', '-z').decode('utf-8').rstrip('\0').split('\0')
    csv = [p for p in tracked if p.startswith('research/') and p.endswith('.csv')]
    rtl = [p for p in tracked if p.endswith(('.v', '.sv'))]
    constraints = [p for p in tracked if p.endswith(('.sdc', '.xdc'))]
    synthesis = []
    for name in tracked:
        if name.endswith('.tcl'):
            text = (ROOT/name).read_text(encoding='utf-8', errors='replace')
            # 展开脚本中的注释提及综合，不等于实际执行综合命令。
            if re.search(r'^\s*(synth_design|synth|read_liberty)\b', text, re.M):
                synthesis.append(dict(path=name,
                    rtl_elaboration_only=bool(re.search(r'^\s*synth_design\s+-rtl\b', text, re.M))))
    cfg = json.loads((ROOT/'research/causal_deembedding_20261103/config.json').read_text(encoding='utf-8'))
    scores = json.loads((ROOT/'research/reference_covariance_20261103/evidence/scores.json').read_text(encoding='utf-8'))
    delay = next(r['source_delay_s'] for r in scores['cases'] if r['window_samples'] == 240)
    fs = cfg['sample_rate_Hz']; m = cfg['comparison_demod_window_samples']
    rows = []
    # 两级等长滑窗群延迟=(M-1)/fs；控制更新率不同不会改变这部分。
    for update in [1000, 2000]:
        hold = 1/(2*update)  # 仅为零阶保持小信号近似，尚未与完整返回比组合。
        phase = 2*math.pi*cfg['reference_loop_bandwidth_Hz']*(delay+hold)
        rows.append(dict(update_Hz=update,source_delay_ms=delay*1000,
                         approximate_hold_ms=hold*1000,
                         source_plus_hold_phase_rad=phase,
                         source_plus_hold_budget_fraction=phase/cfg['additional_phase_budget_rad'],
                         with_one_sample_publication_phase_rad=phase+2*math.pi*5/fs))
    assert scores['summary']['checks_matched'] == 46
    log = (ROOT/paths[11]).read_text(encoding='utf-8')
    assert 'TOP_SCOREBOARD_PASS' in log and 'updates=4000' in log and 'errors=0' in log
    return dict(
        date='2026-11-03',base_commit=git('rev-parse','HEAD').decode().strip(),sources=sources,
        sealed_files=seal_checks,
        repository_inventory=dict(tracked_rtl_files=len(rtl),rtl_files=rtl,
            timing_constraints=constraints,synthesis_command_scripts=synthesis,
            research_csv_count=len(csv),research_csv_bytes=sum((ROOT/p).stat().st_size for p in csv)),
        latency=dict(source_ms=delay*1000,two_stage_window_ms=(m-1)/fs*1000,
            extra_phase_at_5Hz_rad=2*math.pi*5*delay,
            declared_phase_budget_rad=cfg['additional_phase_budget_rad'],
            source_budget_fraction=2*math.pi*5*delay/cfg['additional_phase_budget_rad'],
            allowed_total_pure_delay_ms=cfg['additional_phase_budget_rad']/(2*math.pi*5)*1000,
            with_approximate_hold=rows),
        scope='事实与哈希复核；未重跑旧仿真、未测返回比/硬件、未做PPA或重新认证论文新颖性')


if __name__ == '__main__':
    result = audit()
    (HERE/'facts.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8', newline='\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ['sources','repository_inventory']}, ensure_ascii=False, indent=2))
    print(json.dumps({k:v for k,v in result['repository_inventory'].items() if k!='rtl_files'}, ensure_ascii=False, indent=2))
