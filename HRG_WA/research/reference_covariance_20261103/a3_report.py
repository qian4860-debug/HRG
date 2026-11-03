"""图文与文本输出，不改变冻结的评分或门控；显示等待、拒绝和不同原点段。"""
import csv
import html
from a3_common import HERE,read_json


if __name__=='__main__':
    scores=read_json(HERE/'evidence/scores.json');sim=read_json(HERE/'evidence/simulink_scoreboard.json');rows=scores['cases']
    fields=['id','window_samples','noise_RMS_V','fault_kind','fresh_seed','reference_frame','joint_valid_fraction','cauchy_valid_fraction',
        'after_holdoff_valid_fraction','published_RMS_rad','all_observable_candidate_RMS_rad','source_delay_s','needs_external_reference','passed']
    with (HERE/'evidence/summary.csv').open('w',encoding='utf-8',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=fields,extrasaction='ignore');writer.writeheader();writer.writerows(rows)
    table=''
    for r in rows:
        values=[r['id'],r['window_samples'],r['fault_kind'],'%.4g'%r['noise_RMS_V'],
            '%.2f%%'%(100*r['cauchy_valid_fraction']),'%.2f%%'%(100*r['joint_valid_fraction']),
            '—' if r['after_holdoff_valid_fraction'] is None else '%.2f%%'%(100*r['after_holdoff_valid_fraction']),
            '—' if r['published_RMS_rad'] is None else '%.6g'%r['published_RMS_rad'],
            '需外部参考' if r['needs_external_reference'] else '未锁存分支丢失','匹配' if r['passed'] else '失败']
        table+='<tr>'+''.join('<td>'+html.escape(str(x))+'</td>' for x in values)+'</tr>'
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>A3共同原点协方差与参考管理</title>
<style>body{max-width:1450px;margin:28px auto;padding:0 24px;font:17px/1.7 "Microsoft YaHei",sans-serif;background:#f4f6fa;color:#203341}section{background:white;border-radius:12px;padding:24px;margin:18px 0}img{max-width:100%}table{border-collapse:collapse;font-size:14px;width:100%}th,td{padding:8px;border-bottom:1px solid #ddd;text-align:left}.scroll{overflow:auto}.limit{border-left:5px solid #c76d2d}</style>
<h1>A3｜共同原点协方差、正确重锚定与缺测恢复</h1>
<section><b>46/46“窗口×工况”检查符合预期，其中冻结算法/预算/评分后新增8项独立噪声种子对照。</b>
<p>500 μV正常白噪声的五个种子：240点/级在参考就绪后的帧全部满足本次0.003 rad调试预算；把固定20 ms参考等待也计入0.25 s预热后的分母，发布率98.86%。40点/级仍拒绝；1 mV两种窗口仍拒绝。</p>
<p>同一角度序列并未额外降噪；改进来自正确计算当前帧与原始参考的联合方差，减少标准差相加导致的过度拒绝。重锚定只改变局部数值参考，不清除原始参考误差。</p></section>
<section class="limit"><b>适用边界：</b>仍为A2合成静止表头、强制模态方向运动、冻结W与独立电路校准、采样白噪声。正常500 μV已发布RMS约0.423–1.130 mrad，不能换称真实表头精度。
<p>稳态数学源延迟保持1.0775/6.0775 ms，首次输出另等20 ms参考就绪。协方差计算和硬件执行耗时未测，6.08 ms仍占假定5 Hz/0.2 rad相位预算约95.5%，未证明可直接接入旧闭环。</p></section>
<section><h2>分项观察</h2><img src="a3_dashboard.png"></section>
<section><h2>缺测后的原点不能偷换</h2><p>10 ms检测数据失效及20 ms恢复观察后，声明速率界下可续接原全局角。120 ms失效后，恢复检查不能保证模π分支唯一，锁存全局无效；只提供带新段号的局部诊断角，全局输出NaN。初始参考未到达时保持等待；有色噪声探针和违反运动界也拒绝。</p>
<p>“原点保留”表示初始参考仍记在状态中，不表示缺测期间当前全局角可发布。外部参考重新同步接口尚未实现。</p></section>
<section><h2>独立MATLAB与Simulink</h2><img src="../models/a3_structure.png">
<p>4种参考状态场景×2000帧，9个输出/场景逐点核对；最大差SIMERR，无效NaN掩码相同。S函数实际推进DWork状态；协方差由Python处理器计算，另以MATLAB滤波/累加对白噪声做512次独立线性试验。</p>
<p>移位噪声核Gram矩阵对相关和公式的相对差约1.98×10⁻⁹；MATLAB相对角方差实测/预测约0.919–1.056。它们不构成真实硬件或非线性全程失效概率认证。</p></section>
<section><h2>所有工况，包括等待和拒绝</h2><div class="scroll"><table><tr><th>工况</th><th>每级窗口</th><th>类型</th><th>时域噪声RMS [V]</th><th>标准差和发布率</th><th>联合协方差发布率</th><th>参考等待后发布率</th><th>已发布RMS [rad]</th><th>分支状态</th><th>检查</th></tr>TABLE</table></div>
<p>两列发布率使用同一前端、同一首次原点、同一管理器及同一等待规则。长缺测例可在故障前发布，此后保持无效，不能把全段累计发布率当成恢复成功。</p></section>
<section><h2>复核入口</h2><a href="scores.json">逐项评分</a> · <a href="summary.csv">CSV</a> · <a href="independent_check.json">冻结/前缀/分块/隔离核验</a> · <a href="math_checks.json">误差守恒反例与Gram核对</a> · <a href="matlab_noise_scoreboard.json">MATLAB噪声试验</a> · <a href="simulink_scoreboard.json">原生状态机核对</a>
<p>From Workspace输入不能含NaN，因此输入中的未就绪quality明确编码为超预算哨兵，健康标志仍无效；原始CSV与输出NaN保留。首轮接口错误记录保留在trials。</p>
<p>不声称解决有色噪声、未知W漂移、量化、抖动、饱和、真实机体角速度、执行耗时或全闭环稳定性；工程改良也不是文献独创性证明。</p></section></html>'''
    page=page.replace('SIMERR','%.5g'%sim['maximum_absolute_difference']).replace('TABLE',table)
    (HERE/'evidence/index.html').write_text(page,encoding='utf-8',newline='\n')
    (HERE/'evidence/result_text.txt').write_text('A3：46/46行为/评分检查匹配，含8项冻结后新种子对照。\n正常白噪500uV五种子长窗：参考就绪后100%，含20ms等待发布率98.86%；短窗与1mV仍拒绝。\n延迟窗口未增加，角度序列未额外降噪；实时执行成本与闭环稳定性未验证。\n短缺测恢复全局；长缺测锁存全局NaN，局部角带新段号。\n',encoding='utf-8',newline='\n')
    print('A3 Chinese report, CSV and text written')
