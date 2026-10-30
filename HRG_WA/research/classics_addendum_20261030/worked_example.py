"""Scalar calculation DAG with explicit operands, units and provenance."""
from pathlib import Path
import math
import json
import csv

HERE=Path(__file__).resolve().parent


def make():
    rows=[]; values={}
    def node(key,value,unit,expression,deps=(),source='本书合成算例'):
        values[key]=float(value)
        rows.append(dict(id=key,expression=expression,operands={k:values[k] for k in deps},value=float(value),unit=unit,source=source))
        return value
    pi=node('pi',math.pi,'1','pi'); rad=node('deg_to_rad',pi/180,'rad/deg','pi/180',('pi',))
    conv=node('rad_s_to_deg_h',180*3600/pi,'deg/h per rad/s','180*3600/pi',('pi',))
    f=node('f0',1000,'Hz','input'); m=node('mass',1e-4,'kg','input'); a=node('amplitude',1e-6,'m','input')
    Q=node('Q',1e4,'1','input'); B=node('B',.27699,'1','input'); df=node('full_split_Hz',.2,'Hz','input')
    theta=node('theta',50*rad,'rad','50*deg_to_rad',('deg_to_rad',)); tg=node('theta_G',20*rad,'rad','20*deg_to_rad',('deg_to_rad',))
    th=node('theta_H',-10*rad,'rad','-10*deg_to_rad',('deg_to_rad',)); O=node('input_rate',30*rad,'rad/s','30*deg_to_rad',('deg_to_rad',))
    d=node('damping_half_difference',1e-5,'1/s','input'); et=node('alignment_leak',1e-5,'1','input'); ep=node('phase_leak',2e-5,'rad','input')
    thetaD=node('drive_coupling',2e-5,'N/V','input'); thetaS=node('sense_coupling',1e-8,'C/m','input'); cf=node('Cf',1e-11,'F','input'); rf=node('Rf',1e9,'ohm','input')
    om=node('omega0',2*pi*f,'rad/s','2*pi*f0',('pi','f0')); alpha=node('alpha',2*B,'1','2*B',('B',))
    gamma=node('gamma',om/(2*Q),'1/s','omega0/(2*Q)',('omega0','Q')); tau=node('tau_amplitude',1/gamma,'s','1/gamma',('gamma',))
    h=node('split_half_rate',pi*df,'rad/s','pi*full_split_Hz',('pi','full_split_Hz'))
    angG=node('double_angle_G',2*(theta-tg),'rad','2*(theta-theta_G)',('theta','theta_G')); angH=node('double_angle_H',2*(theta-th),'rad','2*(theta-theta_H)',('theta','theta_H'))
    cg=node('cosG',math.cos(angG),'1','cos(double_angle_G)',('double_angle_G',)); sg=node('sinG',math.sin(angG),'1','sin(double_angle_G)',('double_angle_G',))
    ch=node('cosH',math.cos(angH),'1','cos(double_angle_H)',('double_angle_H',)); sh=node('sinH',math.sin(angH),'1','sin(double_angle_H)',('double_angle_H',))
    ca=node('Ca',gamma+d*cg,'1/s','gamma+damping_half_difference*cosG',('gamma','damping_half_difference','cosG'))
    cq=node('Cq',h*sh,'1/s','split_half_rate*sinH',('split_half_rate','sinH'))
    dw=node('natural_detuning',h*ch,'rad/s','split_half_rate*cosH',('split_half_rate','cosH'))
    bD=node('bias_damping',d*sg,'rad/s','damping_half_difference*sinG',('damping_half_difference','sinG'))
    bA=node('bias_amplitude_leak',et*ca,'rad/s','alignment_leak*Ca',('alignment_leak','Ca'))
    bQ=node('bias_quadrature_leak',ep*cq,'rad/s','phase_leak*Cq',('phase_leak','Cq'))
    bias=node('bias_electrical',bD+bA+bQ,'rad/s','bias_damping+bias_amplitude_leak+bias_quadrature_leak',('bias_damping','bias_amplitude_leak','bias_quadrature_leak'))
    biasphys=node('bias_body',-bias/alpha,'rad/s','-bias_electrical/alpha',('bias_electrical','alpha'))
    node('bias_body_deg_h',biasphys*conv,'deg/h','bias_body*rad_s_to_deg_h',('bias_body','rad_s_to_deg_h'))
    td=node('WA_theta_dot',-alpha*O+bias,'rad/s','-alpha*input_rate+bias_electrical',('alpha','input_rate','bias_electrical'))
    node('WA_estimated_body_rate',-td/alpha,'rad/s','-WA_theta_dot/alpha',('WA_theta_dot','alpha'))
    S=node('force_normalization',2*m*a*om,'N per 1/s','2*mass*amplitude*omega0',('mass','amplitude','omega0'))
    Fa=node('amplitude_force_peak',S*ca,'N','force_normalization*Ca',('force_normalization','Ca'))
    Fq=node('quadrature_force_peak',S*abs(cq),'N','force_normalization*abs(Cq)',('force_normalization','Cq'))
    node('amplitude_voltage_peak',Fa/thetaD,'V','amplitude_force_peak/drive_coupling',('amplitude_force_peak','drive_coupling'))
    node('quadrature_voltage_peak',Fq/thetaD,'V','quadrature_force_peak/drive_coupling',('quadrature_force_peak','drive_coupling'))
    qr=node('sense_charge_peak',thetaS*a,'C','sense_coupling*amplitude',('sense_coupling','amplitude'))
    vi=node('ideal_charge_output_peak',qr/cf,'V','sense_charge_peak/Cf',('sense_charge_peak','Cf'))
    wt=node('omega_Rf_Cf',om*rf*cf,'1','omega0*Rf*Cf',('omega0','Rf','Cf'))
    gain=node('charge_response_magnitude',wt/math.sqrt(1+wt*wt),'1','omega_Rf_Cf/sqrt(1+omega_Rf_Cf^2)',('omega_Rf_Cf',))
    node('actual_charge_output_peak',vi*gain,'V','ideal_charge_output_peak*charge_response_magnitude',('ideal_charge_output_peak','charge_response_magnitude'))
    node('charge_phase_offset',math.atan(1/wt),'rad','atan(1/omega_Rf_Cf)',('omega_Rf_Cf',))
    target=node('single_body_bias_budget',.01/conv,'rad/s','0.01/rad_s_to_deg_h',('rad_s_to_deg_h',))
    targete=node('single_electrical_bias_budget',alpha*target,'rad/s','alpha*single_body_bias_budget',('alpha','single_body_bias_budget'))
    node('max_single_alignment_leak',targete/abs(ca),'1','single_electrical_bias_budget/abs(Ca)',('single_electrical_bias_budget','Ca'))
    maxphase=node('max_single_phase_leak',targete/abs(cq),'rad','single_electrical_bias_budget/abs(Cq)',('single_electrical_bias_budget','Cq'))
    node('max_differential_timing_skew',maxphase/om,'s','max_single_phase_leak/omega0',('max_single_phase_leak','omega0'))
    # Reproduce source budgets without confusing their inputs with our head.
    x=node('J08_phase_ratio',1e4*1e3/(10*(1e3**2-1e4**2)),'1','10000*1000/[10*(1000^2-10000^2)]',source='Jeanroy PDF2–3 原式7–8')
    phase=node('J08_literal_phase',math.atan(x),'rad','atan(J08_phase_ratio)',('J08_phase_ratio',),'Jeanroy PDF2–3 原式7–8')
    invq=node('J08_literal_inverseQ',.001*phase/(2*pi),'1','0.001*J08_literal_phase/(2*pi)',('J08_literal_phase','pi'),'Jeanroy PDF3 原式8，负值反例')
    node('J08_loss_magnitude_inverseQ',abs(invq),'1','abs(J08_literal_inverseQ)',('J08_literal_inverseQ',),'本书解释性取绝对值，非原式')
    ig=node('J09_total_inverseQ_rounded',1e-7+1.6e-6,'1','1e-7+1.6e-6',source='Jeanroy 原文舍入输入')
    node('J09_Q_global',1/ig,'1','1/J09_total_inverseQ_rounded',('J09_total_inverseQ_rounded',))
    node('J09_exact_maintenance_deg_s',180*1e4*ig,'deg/s','180*10000*J09_total_inverseQ_rounded',('J09_total_inverseQ_rounded',))
    node('J09_approx_maintenance_deg_s',180*1e4*1.6e-6,'deg/s','180*10000*1.6e-6',source='忽略本征损耗时对应原文2.88')
    with (HERE/'worked_trace.csv').open('w',encoding='utf-8',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=['id','expression','operands','value','unit','source'],lineterminator='\n'); writer.writeheader()
        for row in rows:writer.writerow(dict(row,operands=json.dumps(row['operands'],ensure_ascii=False)))
    (HERE/'worked_example.json').write_text(json.dumps(dict(nodes=len(rows),values=values,boundary='Synthetic inputs, no identified hardware parameters'),ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    lines=['### 自动展开的标量计算痕迹','', '每一行先使用上方已定义的量；CSV另存每个依赖的当时数值，避免只留最终结果。下面的输入用于复算方法，不是制造商参数。','','| 节点 | 算式 | 数值 | 单位 |','|---|---|---:|---|']
    for row in rows:lines.append(f"| `{row['id']}` | `{row['expression']}` | {row['value']:.12g} | {row['unit']} |")
    (HERE/'worked_steps.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
    print('Generated',len(rows),'scalar trace nodes')


if __name__=='__main__':make()
