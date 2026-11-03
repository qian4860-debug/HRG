"""中文图文与文字输出：同时列全帧误差、发布率、已发布误差和拒绝原因。"""
import csv
import html
from a2_dsp import HERE,read_json


if __name__=='__main__':
    scores=read_json(HERE/'evidence/scores.json');sim=read_json(HERE/'evidence/simulink_scoreboard.json')
    rows=scores['cases'];fields=['id','window_samples','kind','noise_RMS_V','valid_fraction','source_delay_s',
        'correct_timestamp_RMS_rad','available_timestamp_RMS_rad','published_RMS_rad','noise_observed_to_predicted_RMS_ratio','passed']
    with (HERE/'evidence/summary.csv').open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields,extrasaction='ignore');w.writeheader();w.writerows(rows)
    table=''
    for r in rows:
        values=[r['id'],r['window_samples'],r['kind'],'%.4g'%r['noise_RMS_V'],
            '%.2f%%'%(100*r['valid_fraction']),'%.4f'%(1000*r['source_delay_s']),
            '%.5g'%r['correct_timestamp_RMS_rad'],'—' if r['published_RMS_rad'] is None else '%.5g'%r['published_RMS_rad'],
            '匹配' if r['passed'] else '失败']
        table+='<tr>'+''.join('<td>'+html.escape(str(v))+'</td>' for v in values)+'</tr>'
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>A2因果去嵌验证</title>
<style>body{max-width:1450px;margin:28px auto;padding:0 24px;font:17px/1.7 "Microsoft YaHei",sans-serif;background:#f4f6fa;color:#1d3140}section{background:white;padding:24px;margin:18px 0;border-radius:12px}img{max-width:100%}table{border-collapse:collapse;font-size:14px;width:100%}th,td{padding:8px;border-bottom:1px solid #ddd;text-align:left}.scroll{overflow:auto}.limit{border-left:5px solid #d16b28}</style>
<h1>A2｜因果限带去嵌、独立电路检查、噪声与时间戳</h1>
<section><b>30/30“窗口×工况”预期检查匹配，含正确拒绝，不能称为30个精度通过。</b>
<p>15种合成流，两种窗口；白噪声为AFE采样电压每通道时域RMS。主结果：5 μV可发布，500 μV短窗拒绝、长窗约37%–48%稳态帧满足保守预算；1 mV仍拒绝。长窗不是全帧通过。</p>
<p>三种校准失配/额外极点、低幅工况均拒绝。噪声探针与流噪声独立，处理器不读取运动真值。W沿用A1无噪标定，串扰矩阵依赖独立夹持夹具。</p></section>
<section class="limit"><b>长窗口有明确代价：</b>包括一拍发布的源延迟约6.0775 ms，在假定5 Hz、0.2 rad预算下使用约95.5%。未计入原控制链其他环节，未测实际开环相位裕量，不能直接接回旧AGC/PLL宣称稳定。
<p>旧代码max_frame_age检查“当前时刻−发布时间”，不代表信号源延迟；本次分别列FIR起点/中心、源中心、样本末点和下一拍发布时间。源中心为窄带群延迟估计，IIR没有有限硬起点。</p></section>
<section><h2>六项指标分开展示</h2><img src="a2_dashboard.png"></section>
<section><h2>Simulink实际离散算法</h2><img src="../models/a2_structure.png"><img src="../models/a2_frontend_detail.png">
<p>原生Discrete Filter、乘法器、两级滑窗和Unit Delay执行实际算法；From Workspace只输入u/y，不输入期望输出。两种窗口8192样本、12输出逐点最大差SIMERR。角度和质量门控在Python处理器执行，尚未进入控制反馈。</p></section>
<section><h2>全帧与选择性发布同时报告</h2><div class="scroll"><table><tr><th>工况</th><th>每级窗口</th><th>类型</th><th>时域噪声RMS [V]</th><th>稳态发布率</th><th>源延迟 [ms]</th><th>全部稳态帧角误差RMS [rad]</th><th>已发布帧RMS [rad]</th><th>预期检查</th></tr>TABLE</table></div>
<p>评分从预先声明的0.25 s预热后开始。相对角以首个参考帧定义增量；不拟合真值偏置或延迟。参考帧到达前，相对角和相对噪声预算为NaN。拒绝帧不发布角，但仍列全部稳态候选误差，避免只展示好帧。</p></section>
<section><h2>独立检查与复现</h2><ul><li><a href="scores.json">逐项评分</a> / <a href="summary.csv">汇总CSV</a></li><li><a href="independent_check.json">分块、未来扰动、前缀、噪声核和无真值目录重放</a></li><li><a href="simulink_scoreboard.json">原生Simulink scoreboard</a></li><li><a href="window_40/estimates.json">短窗系数、校准统计量及输入哈希</a> / <a href="window_240/estimates.json">长窗</a></li></ul>
<p>角点敏感度为窄带探索，非严格区间保证；3σ门控含首参考帧噪声的保守上界，非全程失效概率认证。高斯仪器残差检查的概率含义仅在独立噪声、正确σ及参数界成立时有效。</p>
<p>原机械模型静止、运动由外部强制模态方向轨迹产生；所列0/0.7/5 rad/s不是已验证的机体角速度。未验证ADC/DAC量化、抖动、饱和、有色噪声、未知W漂移、硬件定点及全闭环稳定性。</p>
<p>trials保留首轮短窗结果快照和输入源配置失败记录；首轮结果缺少当时完整源码快照，不作为独立重放证明。正式交付的源码、数据、模型和结果由manifest封存。</p></section></html>'''
    page=page.replace('SIMERR','%.5g'%sim['maximum_absolute_difference']).replace('TABLE',table)
    (HERE/'evidence/index.html').write_text(page,encoding='utf-8',newline='\n')
    (HERE/'evidence/result_text.txt').write_text('A2：30/30行为及评分检查匹配。\n5uV通过；500uV短窗拒绝，240点/级约37%-48%稳态帧发布；1mV拒绝。\n长窗含一拍延迟6.0775ms，使用假定5Hz/0.2rad相位预算约95.5%，未证明旧闭环可直接接入。\n',encoding='utf-8',newline='\n')
    print('A2 Chinese HTML, CSV and text written')
