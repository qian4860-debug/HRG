"""中文可视化文字输出：只根据封存评分写报告，不改变门限/结果。"""
from a1_fit import HERE,read_json
import csv
import html


if __name__=='__main__':
    data=read_json(HERE/'evidence/scores.json');sim=read_json(HERE/'evidence/simulink_scoreboard.json')
    columns=['id','mode','kind','expected_eligible','eligible','heldout_max_relative','D_relative_error','K_relative_error','kappa_relative_error','candidate_angle_rms_rad','passed']
    with (HERE/'evidence/summary.csv').open('w',encoding='utf-8',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=columns,extrasaction='ignore');writer.writeheader();writer.writerows(data['cases'])
    rows=''
    for r in data['cases']:
        angle='—' if r['candidate_angle_rms_rad'] is None else '%.4g'%r['candidate_angle_rms_rad']
        rows+='<tr>'+''.join('<td>'+html.escape(str(v))+'</td>' for v in [r['id'],r['mode'],r['kind'],
            '允许更新' if r['eligible'] else '拒绝；公开角度NaN','%.4g'%r['heldout_max_relative'],angle,'匹配' if r['passed'] else '失败'])+'</tr>'
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>A1压电端口去嵌验证</title>
<style>body{max-width:1350px;margin:30px auto;padding:0 20px;background:#f5f7fa;color:#172b3a;font:17px/1.65 "Microsoft YaHei",sans-serif}section{background:white;padding:24px;margin:18px 0;border-radius:14px}table{border-collapse:collapse;font-size:14px;width:100%}td,th{padding:8px;border-bottom:1px solid #ddd;text-align:left}img{max-width:100%}.scroll{overflow:auto}</style>
<h1>A1｜完整压电端口 → 去嵌 → 共同加载辨识 → 适用性拒绝</h1>
<section><b>本轮结果：27/27对照检查匹配；主方法9例中4例允许更新、5例拒绝。</b>
<p>全部是静止、线性、SI合成参数。正例无噪；独立电路校准来自理想夹持夹具。拒绝不等于精度通过，不能据此宣称真实表头无参考自校准或强噪声通过。</p>
<p>case 003：AFE校准失配；004：共轴；005：各向同性；006：5 μV实/虚复相量噪声；009：Cs校准失配。007–009是预先列出的额外参数种子，未当成正式盲测认证。</p></section>
<section><h2>各指标分开观察</h2><img src="a1_dashboard.png"><p>角度为相对模态角，未换算Bryan机体角。对角度真值没有拟合偏置、时延或旋转常数。</p></section>
<section><h2>Simulink真实动态模块</h2><img src="../models/a1_structure.png"><img src="simulink_waveforms.png">
<p>驱动器、机械表头、传感端口、电荷放大器及AFE五个动态模块互连；Scope逐级观察，频谱支路先以40 kHz离散采样，不进入反馈。尚未接AGC/PLL导航控制闭环。</p><p>全部12状态对独立频域稳态解，归一化最大误差：SIMERR。</p></section>
<section><h2>逐工况及方法对照</h2><div class="scroll"><table><tr><th>工况</th><th>方法</th><th>类型</th><th>发布决定</th><th>最大留出相对误差</th><th>候选角度RMS [rad]</th><th>预期检查</th></tr>ROWS</table></div>
<p>候选角仅作诊断。模型兼容性使用独立频点；最终运动记录不参与拟合或决定门限。</p></section>
<section><h2>复查文件</h2><a href="scores.json">评分</a> · <a href="summary.csv">CSV</a> · <a href="simulink_scoreboard.json">Simulink scoreboard</a> · <a href="independent_check.json">隔离与独立方程核验</a>
<p>保存了首轮未做量纲平衡时的病态警告；最终频域求解与各Simulink状态均归一化，不靠屏蔽警告。</p></section></html>'''
    page=page.replace('SIMERR','%.5g'%sim['maximum_normalized_error']).replace('ROWS',rows)
    (HERE/'evidence/index.html').write_text(page,encoding='utf-8',newline='\n')
    print('A1 Chinese HTML and CSV written')
