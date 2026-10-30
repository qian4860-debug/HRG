"""Reproducible scalar circuit budgets, explicit dependency trace and units."""
from pathlib import Path
import math,csv,json

HERE=Path(__file__).resolve().parent


def main():
    nodes=[];v={}
    def n(key,value,unit,formula,deps=()):
        nodes.append(dict(id=key,value=float(value),unit=unit,formula=formula,operands={d:v[d] for d in deps}));v[key]=float(value);return value
    pi=n('pi',math.pi,'1','pi');k=n('kB',1.380649e-23,'J/K','SI exact');T=n('T',300,'K','assumed input')
    f=n('carrier_Hz',1000,'Hz','assumed input');om=n('omega',2*pi*f,'rad/s','2*pi*carrier_Hz',('pi','carrier_Hz'))
    Ct=n('Ct',100e-12,'F','assumed input');Cf=n('Cf',10e-12,'F','assumed input')
    ng=n('noise_gain',1+Ct/Cf,'1','1+Ct/Cf',('Ct','Cf'));gbw=n('GBW',1e7,'Hz','assumed single-pole input')
    n('closed_bandwidth',gbw/ng,'Hz','GBW/noise_gain',('GBW','noise_gain'))
    en=n('input_noise_target',10e-9,'V/sqrt(Hz)','assumed input');gam=n('MOS_noise_gamma',2/3,'1','long-channel teaching assumption');kap=n('noise_topology_factor',2,'1','teaching assumption')
    gm=n('gm_min',4*k*T*gam*kap/en**2,'S','4*kB*T*MOS_noise_gamma*noise_topology_factor/input_noise_target^2',('kB','T','MOS_noise_gamma','noise_topology_factor','input_noise_target'))
    eff=n('gm_ID',15,'1/V','teaching assumption');n('input_device_ID',gm/eff,'A','gm_min/gm_ID',('gm_min','gm_ID'))
    bits=n('ADC_bits',16,'bit','teaching assumption');fs=n('ADC_span',2,'V','teaching assumption')
    delta=n('ADC_LSB',fs/2**bits,'V','ADC_span/2^ADC_bits',('ADC_span','ADC_bits'))
    nq=n('quantization_RMS',delta/math.sqrt(12),'V','ADC_LSB/sqrt(12)',('ADC_LSB',))
    cs=n('sample_C_min',k*T/nq**2,'F','kB*T/quantization_RMS^2',('kB','T','quantization_RMS'))
    ta=n('acquisition_time',2e-6,'s','teaching assumption');factor=n('settling_constants',(bits+1)*math.log(2),'1','(ADC_bits+1)*ln(2)',('ADC_bits',))
    tau=n('acquisition_tau_max',ta/factor,'s','acquisition_time/settling_constants',('acquisition_time','settling_constants'))
    n('effective_R_max',tau/cs,'ohm','acquisition_tau_max/sample_C_min',('acquisition_tau_max','sample_C_min'))
    snr=n('ideal_fullscale_SNR',10*math.log10((fs*fs/8)/(delta*delta/12)),'dB','10*log10[(ADC_span^2/8)/(ADC_LSB^2/12)]',('ADC_span','ADC_LSB'))
    sig=n('ADC_signal_peak',.001,'V','teaching assumption');r=n('signal_fraction',sig/(fs/2),'1','ADC_signal_peak/(ADC_span/2)',('ADC_signal_peak','ADC_span'))
    n('SNR_without_PGA',snr+20*math.log10(r),'dB','ideal_fullscale_SNR+20*log10(signal_fraction)',('ideal_fullscale_SNR','signal_fraction'))
    gain=n('PGA',100,'1','teaching assumption');n('SNR_with_PGA',snr+20*math.log10(r*gain),'dB','ideal_fullscale_SNR+20*log10(signal_fraction*PGA)',('ideal_fullscale_SNR','signal_fraction','PGA'))
    fd=n('DAC_rate',40000,'sample/s','teaching assumption');ts=n('DAC_Ts',1/fd,'s','1/DAC_rate',('DAC_rate',))
    x=n('hold_argument',pi*f*ts,'rad','pi*carrier_Hz*DAC_Ts',('pi','carrier_Hz','DAC_Ts'))
    n('hold_magnitude',math.sin(x)/x,'1','sin(hold_argument)/hold_argument',('hold_argument',))
    n('hold_phase_deg',-x*180/pi,'deg','-hold_argument*180/pi',('hold_argument','pi'))
    cp=n('drive_Cp',10e-9,'F','teaching assumption');vp=n('drive_Vpeak',1,'V','teaching assumption')
    n('sinusoidal_drive_Ipeak',om*cp*vp,'A','omega*drive_Cp*drive_Vpeak',('omega','drive_Cp','drive_Vpeak'))
    n('sinusoidal_min_slew',om*vp,'V/s','omega*drive_Vpeak',('omega','drive_Vpeak'))
    step=n('startup_step',5,'V','teaching assumption');rise=n('startup_rise',1e-6,'s','teaching assumption')
    n('startup_capacitive_current',cp*step/rise,'A','drive_Cp*startup_step/startup_rise',('drive_Cp','startup_step','startup_rise'))
    cds=n('feedthrough_Cds',.1e-12,'F','teaching assumption');n('feedthrough_Ipeak',om*cds*vp,'A','omega*feedthrough_Cds*drive_Vpeak',('omega','feedthrough_Cds','drive_Vpeak'))
    qe=n('motion_charge_peak',10e-15,'C','teaching assumption');n('motion_Ipeak',om*qe,'A','omega*motion_charge_peak',('omega','motion_charge_peak'))
    fp=n('noise_filter_pole',100,'Hz','teaching assumption');bn=n('filter_ENBW',pi*fp/2,'Hz','pi*noise_filter_pole/2',('pi','noise_filter_pole'))
    n('filtered_voltage_RMS',en*math.sqrt(bn),'V','input_noise_target*sqrt(filter_ENBW)',('input_noise_target','filter_ENBW'))
    qref=n('reference_charge_step',1e-12,'C','teaching assumption');cdec=n('reference_decoupling',10e-9,'F','teaching assumption')
    n('reference_instantaneous_step',qref/cdec,'V','reference_charge_step/reference_decoupling',('reference_charge_step','reference_decoupling'))
    with (HERE/'circuit_trace.csv').open('w',encoding='utf-8',newline='') as file:
        writer=csv.DictWriter(file,fieldnames=['id','formula','operands','value','unit'],lineterminator='\n');writer.writeheader()
        for row in nodes:writer.writerow(dict(row,operands=json.dumps(row['operands'],ensure_ascii=False)))
    (HERE/'circuit_example.json').write_text(json.dumps(dict(nodes=len(nodes),values=v,boundary='Teaching assumptions; no measured head or PDK'),ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    lines=['## 电路贯通算例：逐节点计算表','','本表每个依赖均在上文定义；CSV另存其当时操作数。全部为演示值。','','| 节点 | 算式 | 数值 | 单位 |','|---|---|---:|---|']
    for row in nodes:lines.append(f"| `{row['id']}` | `{row['formula']}` | {row['value']:.12g} | {row['unit']} |")
    (HERE/'circuit_steps.md').write_text('\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
    print('Generated',len(nodes),'circuit trace nodes')


if __name__=='__main__':main()
