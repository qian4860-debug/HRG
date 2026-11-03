"""生成中文A0报告与汇总CSV；只读取已完成的离线评分。"""
from pathlib import Path
import csv
import html
from a0_common import read_json

HERE=Path(__file__).resolve().parent


def build():
    scores=read_json(HERE/'evidence/scores.json');replay=read_json(HERE/'evidence/matlab_replay.json')
    rows=scores['cases'];summary=scores['summary']
    with (HERE/'evidence/summary.csv').open('w',encoding='utf-8',newline='') as stream:
        writer=csv.writer(stream,lineterminator='\n');writer.writerow(['id','kind','cohort','eligible','checks_matched','D_relative_error','K_relative_error','raw_modal_RMS_rad','candidate_modal_RMS_rad','gap','epsilon_C'])
        for r in rows:
            writer.writerow([r['id'],r['kind'],r['cohort'],int(r['eligible']),int(r['passed']),r['IV_relative_errors']['D'],r['IV_relative_errors']['K'],r['raw_modal_increment_RMS_rad'],r['candidate_modal_increment_RMS_rad'],r['constraint_gap'],r['empirical_C_margin']])
    number=lambda x:'—' if x is None else f'{x:.5g}'
    table=''
    names={'A_clean':'充分信息/无噪声','A_noisy':'充分信息/有噪声','B_coaxial':'共轴','C_isotropic':'完全各向同性','D_weak_noisy':'弱信息/有噪声'}
    for r in rows:
        status='允许更新' if r['eligible'] else '拒绝更新；未发布校正角'
        table+=f'<tr><td>{html.escape(r["id"])}</td><td>{names[r["kind"]]}</td><td>{"独立" if r["cohort"]=="independent" else "开发"}</td><td>{status}</td>'
        table+=f'<td>{number(r["IV_relative_errors"]["D"])}</td><td>{number(r["IV_relative_errors"]["K"])}</td><td>{number(r["raw_modal_increment_RMS_rad"])}</td><td>{number(r["candidate_modal_increment_RMS_rad"])}</td><td>{"匹配" if r["passed"] else "失败"}</td></tr>'
    text=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>A0 输入输出到导航度量</title>
<style>body{{font:16px/1.65 system-ui,"Microsoft YaHei",sans-serif;color:#173044;background:#f2f6fa;margin:0}}main{{max-width:1400px;margin:auto;padding:30px}}h1{{font-size:30px}}.cards{{display:flex;gap:15px;flex-wrap:wrap}}.card,section{{background:white;border:1px solid #dce5ee;border-radius:12px;padding:20px;margin:15px 0}}.card b{{font-size:30px;display:block}}.note{{border-left:5px solid #d99b20;padding:12px 18px;background:#fff7e4}}img{{max-width:100%;height:auto}}table{{border-collapse:collapse;width:100%;font-size:14px}}th,td{{padding:8px;border-bottom:1px solid #dce5ee;text-align:left}}th{{background:#eaf1f8}}code{{background:#edf2f6;padding:3px}}a{{color:#126293}}</style>
<main><h1>A0：输入输出记录 → 动力学辨识 → 导航度量 → 留出验证</h1><p>2026-11-03 · 归一化二阶条件模型 · Python辨识 + MATLAB跨语言回放</p>
<div class="cards"><div class="card"><b>{summary['checks_matched']}/{summary['cases']}</b>适用性与评分检查匹配</div><div class="card"><b>{summary['accepted']}</b>允许更新校准</div><div class="card"><b>{summary['rejected']}</b>拒绝更新</div><div class="card"><b>{summary['independent_checks_matched']}/{summary['independent_cases']}</b>冻结后的独立工况匹配</div></div>
<p class="note">拒绝不等于精度通过。这里的角度是相对模态角，时间和I/O幅值为归一化单位；不是实际表头、完整12状态电路、机体角、ARW或RTL性能认证。误差裕量为经验估计，不是严格置信区间。</p>
<section><h2>验证图</h2><img src="a0_dashboard.png" alt="无噪声角度、独立种子、信息门槛与参数误差四联图"></section>
<section><h2>数据边界</h2><p>生成器独立生成周期稳态训练和不同频点/运动的留出记录。估计器只读取 observations 内的 t/u/y 和公开协议；真实 H/G/D/K 和角度单独放在 private_score，仅离线评分读取。</p><p>先保留了多项式输入工具变量法的失败：13个开发工况中5个充分信息有噪声例被过度拒绝。随后改为留一重复试验的交叉拟合IV，冻结方法和门槛，再生成5个正例与5个弱信息负例。原失败记录保留在 trials/。</p></section>
<section><h2>23个工况</h2><div style="overflow:auto"><table><thead><tr><th>编号</th><th>类型</th><th>批次</th><th>输出行为</th><th>D误差</th><th>K误差</th><th>原始角RMS/rad</th><th>候选校正RMS/rad</th><th>预期检查</th></tr></thead><tbody>{table}</tbody></table></div><p>拒绝工况的候选误差仅作诊断；公开校正输出为NaN。所有工况保留原始幅值有效标志。</p></section>
<section><h2>MATLAB回放</h2><p>23个算子/门控回放全部匹配；算子最大绝对差 {replay['max_model_absolute_difference']:.3g}，允许更新工况的角度最大差 {replay['max_angle_absolute_difference_accepted']:.3g} rad。</p><p>这是同方法的跨语言实现核对，不是另一个独立物理辨识证明。运行 a0_demo 可打开并保留图窗。</p></section>
<section><h2>复查入口</h2><ul><li><a href="scores.json">完整离线评分</a> / <a href="summary.csv">汇总CSV</a></li><li><a href="estimates.json">估计器结果与输入哈希</a></li><li><a href="independent_check.json">无真值目录的隔离重放检查</a></li><li><a href="matlab_replay.json">MATLAB scoreboard</a></li><li><a href="../method_freeze.json">方法与独立种子冻结记录</a></li></ul></section></main></html>'''
    (HERE/'evidence/index.html').write_bytes(text.encode('utf-8'))


if __name__=='__main__':build()
