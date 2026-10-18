"""Single-source head profiles, deterministic artifacts and RTL build receipts.
Python standard library only. Never communicates with hardware.
"""
from pathlib import Path
from decimal import Decimal,ROUND_HALF_UP,ROUND_FLOOR,ROUND_CEILING
import argparse,copy,hashlib,json,math,re,sys,time

ROOT=Path(__file__).resolve().parents[1]
MODEL=ROOT.parent
DEFAULT=ROOT/'config/head_default.json'
RECEIPT=ROOT/'config/compiled_rtl.json'
MAGIC=0x48524731
ARCH={'adc_bits':18,'adc_full_scale':2.0,'dac_bits':16,'nco_phase_bits':32,
      'nco_amplitude_bits':18,'cic_stages':3,'fir_coefficients':[1,2,3,2,1],'fir_divisor':9}
MECHANICAL=dict(zip('f0_hz quality_factor bryan energy_target initial_energy initial_quadrature initial_theta_deg damping_anisotropy_per_s damping_axis_deg frequency_split_hz stiffness_axis_deg duffing_hz_per_energy'.split(),
    'f0 Q bryan energyTarget energyInitial quadInitial thetaInitialDeg dampingAnisotropy dampingAxisDeg frequencySplitHz stiffnessAxisDeg duffingHzPerEnergy'.split()))
BUILD_KEYS='fs_adc_hz fs_ctrl_hz pipeline_delay_ctrl energy_limit quad_limit integrator_limit energy_slew_per_s quad_slew_per_s energy_back_gain_per_s quad_back_gain_per_s actuator_tracking_gain_per_s slew_tracking_gain_per_s startup_drive startup_seconds acquire_seconds energy_lock_relative quad_lock_absolute energy_valid_threshold phase_valid_threshold unwrap_limit_pi pll_kp_hz pll_ki_hz_per_s pll_integral_limit_hz pll_frequency_limit_hz pll_back_gain_per_s pll_lock_phase_error dac_full_scale_energy dac_full_scale_quad dac_full_scale_virtual_dps legacy_defaults'.split()
LEGACY_KEYS='nco_fcw energy_kp_q16 energy_ki_q16 quad_kp_q16 quad_ki_q16 energy_ref_q24 energy_hold_q22 bryan_q30 rate_alpha_q30'.split()
RUNTIME_KEYS='energy_kp energy_ki quad_kp quad_ki virtual_rate_rad_s energy_hold quad_hold rate_lpf_hz enable_mask'.split()

class ConfigError(ValueError): pass
def canonical(value): return json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=False)
def sha(value): return hashlib.sha256(value.encode('utf-8')).hexdigest()
def load(path):
    def invalid(value): raise ConfigError('Non-finite JSON value: '+value)
    def pairs(items):
        out={}
        for k,v in items:
            if k in out: raise ConfigError('Duplicate JSON key: '+k)
            out[k]=v
        return out
    return json.loads(Path(path).read_text(encoding='utf-8-sig'),parse_constant=invalid,object_pairs_hook=pairs)
def keys(value,expected,where):
    if not isinstance(value,dict): raise ConfigError(where+' must be an object')
    missing=set(expected)-set(value);unknown=set(value)-set(expected)
    if missing or unknown: raise ConfigError(f'{where}: missing={sorted(missing)}, unknown={sorted(unknown)}')
def num(x,where,lo=None,hi=None,integer=False):
    if isinstance(x,bool) or not isinstance(x,(int,float)) or not math.isfinite(x): raise ConfigError(where+' must be finite numeric')
    if integer and int(x)!=x: raise ConfigError(where+' must be an integer')
    if (lo is not None and x<lo) or (hi is not None and x>hi): raise ConfigError(f'{where} outside [{lo},{hi}]')
    return x
def q(x,frac,bits,signed=True):
    value=int((Decimal(str(x))*(1<<frac)).to_integral_value(rounding=ROUND_HALF_UP))
    lo=-(1<<(bits-1)) if signed else 0;hi=(1<<(bits-int(signed)))-1
    if not lo<=value<=hi: raise ConfigError(f'{x} cannot be encoded in {bits}-bit Q{frac}')
    return value
def ceil(x): return int(Decimal(str(x)).to_integral_value(rounding=ROUND_CEILING))
def floor(x): return int(Decimal(str(x)).to_integral_value(rounding=ROUND_FLOOR))

def validate(c):
    keys(c,['schema_version','head_id','measurement_status','notes','mechanical','detection','drive','runtime','build','architecture'],'profile')
    if type(c['schema_version']) is not int or c['schema_version']!=1: raise ConfigError('Unsupported schema_version')
    if not isinstance(c['head_id'],str) or not re.fullmatch(r'[A-Za-z][A-Za-z0-9_-]{0,63}',c['head_id']): raise ConfigError('head_id must be a short ASCII identifier')
    if c['measurement_status'] not in ('assumed','measured','mixed'): raise ConfigError('measurement_status must be assumed/measured/mixed')
    if not isinstance(c['notes'],str): raise ConfigError('notes must be text')
    keys(c['mechanical'],MECHANICAL,'mechanical');keys(c['runtime'],RUNTIME_KEYS,'runtime')
    keys(c['build'],BUILD_KEYS,'build');keys(c['build']['legacy_defaults'],LEGACY_KEYS,'legacy_defaults')
    keys(c['detection'],['cross_matrix','offset','phase_delay_deg'],'detection')
    keys(c['drive'],['cross_matrix','dac_gain','dac_offset'],'drive')
    if c['architecture']!=ARCH or 'true' in canonical(c['architecture']) or 'false' in canonical(c['architecture']): raise ConfigError('Architecture/word formats are fixed in this RTL. Changing ADC scaling/width or filter topology requires a source redesign, not just recompilation.')
    for name,value in c['mechanical'].items(): num(value,'mechanical.'+name)
    m,b,r=c['mechanical'],c['build'],c['runtime']
    for name in ('f0_hz','quality_factor','bryan','energy_target','initial_energy'): num(m[name],name,1e-12)
    num(m['bryan'],'bryan',1e-6,1.0);q(m['energy_target'],24,32)
    if abs(m['initial_quadrature'])>m['initial_energy']: raise ConfigError('Initial |Q| cannot exceed initial energy')
    for name,value in b.items():
        if name!='legacy_defaults': num(value,'build.'+name,0)
    num(b['fs_adc_hz'],'fs_adc_hz',1,1000000,True);num(b['fs_ctrl_hz'],'fs_ctrl_hz',1,20000,True)
    ratio=b['fs_adc_hz']/b['fs_ctrl_hz']
    if ratio!=int(ratio) or not 24<=ratio<=1024: raise ConfigError('ADC/control ratio must be integer 24..1024 (CORDIC throughput and CIC integer gain limits)')
    num(b['pipeline_delay_ctrl'],'pipeline_delay_ctrl',1,16,True)
    for name in ('energy_back_gain_per_s','quad_back_gain_per_s','actuator_tracking_gain_per_s','slew_tracking_gain_per_s','pll_back_gain_per_s'): num(b[name],name,0,65535,True)
    num(b['energy_lock_relative'],'energy_lock_relative',1e-9,.99)
    num(b['unwrap_limit_pi'],'unwrap_limit_pi',1e-6,.999999)
    num(b['pll_ki_hz_per_s'],'pll_ki_hz_per_s',1e-9)
    if m['f0_hz']-b['pll_frequency_limit_hz']<=0 or m['f0_hz']+b['pll_frequency_limit_hz']>=b['fs_adc_hz']/2:
        raise ConfigError('f0 +/- PLL correction range must stay between DC and ADC Nyquist frequency')
    for name in ('energy_valid_threshold','phase_valid_threshold','energy_limit','quad_limit','integrator_limit','dac_full_scale_energy','dac_full_scale_quad','dac_full_scale_virtual_dps'):
        num(b[name],name,1e-12)
    if max(b['energy_valid_threshold'],b['phase_valid_threshold'])>=m['energy_target']: raise ConfigError('energy_target must exceed energy/phase validity thresholds')
    if b['energy_limit']>b['dac_full_scale_energy'] or b['quad_limit']>b['dac_full_scale_quad']: raise ConfigError('Control limits exceed DAC full scale')
    if b['startup_drive']>b['energy_limit']: raise ConfigError('startup_drive exceeds energy_limit')
    for name in ('startup_seconds','acquire_seconds'):
        if not 1<=ceil(Decimal(str(b[name]))*Decimal(str(b['fs_ctrl_hz'])))<=0xffffffff: raise ConfigError(name+' must encode 1..2^32-1 updates')
    for name in ('energy_slew_per_s','quad_slew_per_s'):
        if q(b[name]/b['fs_ctrl_hz'],22,28)<=0: raise ConfigError(name+' is below one command LSB per update')
    for name,value in r.items():
        if name=='energy_hold' and value is None: continue
        num(value,'runtime.'+name)
    num(r['enable_mask'],'enable_mask',0,63,True)
    if r['enable_mask']&32 and not r['enable_mask']&16: raise ConfigError('Hardware sequencer requires DPLL enable')
    num(r['rate_lpf_hz'],'rate_lpf_hz',1e-9,b['fs_ctrl_hz']/2)
    if r['rate_lpf_hz']>=b['fs_ctrl_hz']/2: raise ConfigError('rate_lpf_hz must stay below control Nyquist')
    if abs(r['virtual_rate_rad_s'])>b['dac_full_scale_virtual_dps']*math.pi/180: raise ConfigError('virtual command exceeds DAC full scale')
    for section,sizes in [('detection',{'offset':2,'phase_delay_deg':2}),('drive',{'dac_gain':3,'dac_offset':3})]:
        mat=c[section]['cross_matrix']
        if not isinstance(mat,list) or len(mat)!=2 or any(not isinstance(v,list) or len(v)!=2 for v in mat): raise ConfigError(section+' matrix must be 2x2')
        for row in mat:
            for value in row: num(value,section+'.cross_matrix')
        if abs(mat[0][0]*mat[1][1]-mat[0][1]*mat[1][0])<1e-12: raise ConfigError(section+' matrix is singular')
        for field,size in sizes.items():
            v=c[section][field]
            if not isinstance(v,list) or len(v)!=size: raise ConfigError(section+'.'+field+' has wrong length')
            for value in v: num(value,section+'.'+field)
    for name,value in b['legacy_defaults'].items():
        num(value,'legacy_defaults.'+name,integer=True)
        bits=28 if name=='energy_hold_q22' else 32
        is_signed=name not in ('nco_fcw','bryan_q30','rate_alpha_q30')
        q(value,0,bits,is_signed)
    return c

def compile_values(c):
    b=c['build'];hz=int(b['fs_ctrl_hz']);ratio=int(b['fs_adc_hz']//hz)
    v={
      'ADC_HZ':(int(b['fs_adc_hz']),32,True),'CTRL_HZ':(hz,32,True),
      'DECIMATION':(ratio,32,True),'CIC_GAIN':(ratio**3,32,True),
      'PIPELINE_DELAY':(int(b['pipeline_delay_ctrl']),32,True),
      'I_LIMIT_Q30':(q(b['integrator_limit'],30,40),40,True),
      'E_LIMIT_Q30':(q(b['energy_limit'],30,64),64,True),'Q_LIMIT_Q30':(q(b['quad_limit'],30,64),64,True),
      'E_SLEW_Q22':(q(b['energy_slew_per_s']/hz,22,28),64,True),
      'Q_SLEW_Q22':(q(b['quad_slew_per_s']/hz,22,28),64,True),
      'STARTUP_DRIVE_Q30':(q(b['startup_drive'],30,64),64,True),
      'STARTUP_TICKS':(ceil(Decimal(str(b['startup_seconds']))*hz),32,False),
      'ACQUIRE_TICKS':(ceil(Decimal(str(b['acquire_seconds']))*hz),32,False),
      'ENERGY_TOL_Q30':(q(b['energy_lock_relative'],30,64),64,True),
      'QUAD_LOCK_Q24':(floor(Decimal(str(b['quad_lock_absolute']))*(1<<24)),32,True),
      'ENERGY_VALID_Q24':(ceil(Decimal(str(b['energy_valid_threshold']))*(1<<24)),32,True),
      'ENERGY_DENOM_Q24':(max(1,floor(Decimal(str(b['energy_valid_threshold']))*(1<<24))),32,True),
      'PHASE_VALID_SQUARED_Q48':(floor((Decimal(str(b['phase_valid_threshold']))*(1<<24))**2),65,False),
      'UNWRAP_CODE':(floor(Decimal(str(b['unwrap_limit_pi']))*(1<<23)),32,True),
      'PLL_KP_Q16':(q(b['pll_kp_hz'],16,32),32,True),
      'PLL_KI_Q16':(q(b['pll_ki_hz_per_s'],16,32),32,True),
      'PLL_I_LIMIT_Q30':(q(b['pll_integral_limit_hz']/b['pll_ki_hz_per_s'],30,40),40,True),
      'PLL_OUT_LIMIT_Q30':(q(b['pll_frequency_limit_hz'],30,64),64,True),
      'PLL_LOCK_Q24':(floor(Decimal(str(b['pll_lock_phase_error']))*(1<<24)),32,True),
      'DAC_E_FS_Q22':(q(b['dac_full_scale_energy'],22,28),64,True),
      'DAC_Q_FS_Q22':(q(b['dac_full_scale_quad'],22,28),64,True),
      'DAC_V_FS_Q22':(q(b['dac_full_scale_virtual_dps']*math.pi/180,22,28),64,True),
    }
    for name,key in [('E_BACK_GAIN','energy_back_gain_per_s'),('Q_BACK_GAIN','quad_back_gain_per_s'),('ACTUATOR_TRACK_GAIN','actuator_tracking_gain_per_s'),('SLEW_TRACK_GAIN','slew_tracking_gain_per_s'),('PLL_BACK_GAIN','pll_back_gain_per_s')]:
        v[name]=(int(b[key]),16,False)
    for name,value in b['legacy_defaults'].items():
        width=28 if name=='energy_hold_q22' else 32
        v['DEFAULT_'+name.upper()]=(int(value),width,name not in ('nco_fcw','bryan_q30','rate_alpha_q30'))
    # Validate every derived value, including threshold squares and integral states.
    for name,(value,width,signed) in v.items(): q(value,0,width,signed)
    if not v['PLL_KI_Q16'][0]: raise ConfigError('PLL Ki quantizes to zero')
    return v

def build_id(c):
    # JSON 40000 and 40000.0 denote the same integer clock; formatting changes
    # must not force a rebuild with an empty semantic difference list.
    integer_fields={'fs_adc_hz','fs_ctrl_hz','pipeline_delay_ctrl','energy_back_gain_per_s',
        'quad_back_gain_per_s','actuator_tracking_gain_per_s','slew_tracking_gain_per_s','pll_back_gain_per_s'}
    normalized={}
    for key,value in c['build'].items():
        if key=='legacy_defaults': normalized[key]={k:int(v) for k,v in value.items()}
        else: normalized[key]=int(value) if key in integer_fields else float(value)
    return sha(canonical({'build':normalized,'architecture':ARCH}))
def header(c):
    v=compile_values(c)
    lines=['// Generated from head profile build fields; do not edit.',
           '`ifndef HRG_HEAD_CONFIG_VH','`define HRG_HEAD_CONFIG_VH',
           "`define HRG_BUILD_SHA256 256'h"+build_id(c)]
    for name,(value,width,signed) in sorted(v.items()):
        literal=f"{width}'{'s' if signed else ''}d{abs(value)}"
        if value<0: literal='(-'+literal+')'
        lines.append('`define HRG_'+name+' '+literal)
    lines+=['`endif','']
    return '\n'.join(lines)

def runtime_words(c):
    m,b,r=c['mechanical'],c['build'],c['runtime']
    hold=r['energy_hold']
    if hold is None: hold=2*math.pi*m['f0_hz']/m['quality_factor']*m['energy_target']
    if abs(hold)>b['energy_limit'] or abs(r['quad_hold'])>b['quad_limit']: raise ConfigError('RUN hold command exceeds control limit')
    values=[('ENERGY_KP',0x28,r['energy_kp'],16,32,True),('ENERGY_KI',0x2c,r['energy_ki'],16,32,True),
      ('QUAD_KP',0x30,r['quad_kp'],16,32,True),('QUAD_KI',0x34,r['quad_ki'],16,32,True),
      ('ENERGY_REF',0x40,m['energy_target'],24,32,True),('VIRTUAL_RATE',0x44,r['virtual_rate_rad_s'],22,28,True),
      ('NCO_FCW',0x50,m['f0_hz']/b['fs_adc_hz'],32,32,False),('ENERGY_HOLD',0x54,hold,22,28,True),
      ('QUAD_HOLD',0x58,r['quad_hold'],22,28,True),('BRYAN',0x5c,m['bryan'],30,32,False),
      ('RATE_ALPHA',0x60,1-math.exp(-2*math.pi*r['rate_lpf_hz']/b['fs_ctrl_hz']),30,31,False)]
    words=[]
    for name,addr,value,frac,width,signed in values:
        code=q(value,frac,width,signed);word=code&0xffffffff
        if name in ('NCO_FCW','BRYAN','RATE_ALPHA') and code==0: raise ConfigError(name+' quantizes to zero')
        words.append(dict(name=name,address=addr,address_hex=f'0x{addr:02X}',requested=value,
            signed_code=code,word=word,word_hex=f'0x{word:08X}',bytes_le=[(word>>(8*i))&255 for i in range(4)],
            fractional_bits=frac,decoded=code/2**frac))
    return words

def sources():
    files=sorted((ROOT/'src').rglob('*.v'))+sorted((ROOT/'src').rglob('*.vh'))
    return {str(p.relative_to(ROOT)).replace('\\','/'):sha(p.read_text(encoding='utf-8-sig')) for p in files}
def flatten(value,prefix=''):
    out={}
    for key,v in value.items():
        path=prefix+'.'+key if prefix else key
        out.update(flatten(v,path) if isinstance(v,dict) else {path:v})
    return out
def compatibility(c,path=RECEIPT):
    if not Path(path).exists(): return dict(compatible=False,recompile_required=True,reasons=['No completed RTL build receipt'],changes=[])
    receipt=load(path);wanted=flatten({'build':c['build'],'architecture':c['architecture']})
    previous=flatten(receipt['compile_configuration'])
    changes=[dict(parameter=k,built=previous.get(k),requested=v) for k,v in wanted.items() if previous.get(k)!=v]
    reasons=[]
    if receipt.get('build_sha256')!=build_id(c): reasons.append('Compile-time configuration changed')
    if receipt.get('rtl_sources')!=sources(): reasons.append('RTL/header sources changed since completed build')
    if receipt.get('header_sha256')!=sha(header(c)): reasons.append('Generated header differs from completed build')
    return dict(compatible=not reasons,recompile_required=bool(reasons),reasons=reasons,changes=changes,
                built_head_id=receipt.get('head_id'),build_sha256=build_id(c))

def matlab(c,words):
    m,b,r=c['mechanical'],c['build'],c['runtime'];a=[]
    # MATLAB numeric arrays use semicolons for rows, not JSON nested arrays.
    def mat(value):
        if isinstance(value,list):
            if value and isinstance(value[0],list): return '['+'; '.join(' '.join(format(x,'.17g') for x in row) for row in value)+']'
            return '['+'; '.join(format(x,'.17g') for x in value)+']'
        return format(value,'.17g')
    def assign(path,value): a.append('u.'+path+' = '+mat(value)+';')
    for name,target in MECHANICAL.items(): assign('res.'+target,m[name])
    for name,target in [('cross_matrix','crossMatrix'),('offset','offset'),('phase_delay_deg','phaseDelayDeg')]: assign('afe.'+target,c['detection'][name])
    assign('drive.crossMatrix',c['drive']['cross_matrix']);assign('dac.gain',c['drive']['dac_gain']);assign('dac.offset',c['drive']['dac_offset'])
    for src,dst in [('energy_kp','energyKp'),('energy_ki','energyKi'),('quad_kp','quadKp'),('quad_ki','quadKi')]: assign('ctrl.'+dst,r[src])
    mapping={'sim.fsAdc':'fs_adc_hz','sim.fsCtrl':'fs_ctrl_hz','asic.pipelineDelayCtrl':'pipeline_delay_ctrl',
      'ctrl.energyLimit':'energy_limit','ctrl.quadLimit':'quad_limit','ctrl.integratorLimit':'integrator_limit',
      'ctrl.energySlewPerSec':'energy_slew_per_s','ctrl.quadSlewPerSec':'quad_slew_per_s',
      'ctrl.energyBackCalculationGain':'energy_back_gain_per_s','ctrl.quadBackCalculationGain':'quad_back_gain_per_s',
      'ctrl.actuatorTrackingGain':'actuator_tracking_gain_per_s','ctrl.slewTrackingGain':'slew_tracking_gain_per_s',
      'ctrl.startupDrive':'startup_drive','ctrl.startupTime':'startup_seconds','ctrl.acquireTime':'acquire_seconds',
      'ctrl.energyLockTolerance':'energy_lock_relative','ctrl.quadLockTolerance':'quad_lock_absolute',
      'pll.kpHz':'pll_kp_hz','pll.kiHz':'pll_ki_hz_per_s','pll.integratorLimitHz':'pll_integral_limit_hz',
      'pll.frequencyLimitHz':'pll_frequency_limit_hz','pll.backCalculationGain':'pll_back_gain_per_s',
      'pll.lockPhaseError':'pll_lock_phase_error','pll.energyValidThreshold':'energy_valid_threshold',
      'asic.phaseValidThreshold':'phase_valid_threshold','dac.fullScaleEnergy':'dac_full_scale_energy',
      'dac.fullScaleQuad':'dac_full_scale_quad','dac.fullScaleVirtualDps':'dac_full_scale_virtual_dps'}
    for target,name in mapping.items(): assign(target,b[name])
    assign('asic.unwrapLimit',b['unwrap_limit_pi']*math.pi);assign('ctrl.rateLpfHz',r['rate_lpf_hz'])
    virtual_on=bool(r['enable_mask']&1 and r['enable_mask']&8 and r['virtual_rate_rad_s']!=0)
    a.append('u.virtual.enable = '+('true' if virtual_on else 'false')+';')
    assign('virtual.amplitudeDps',r['virtual_rate_rad_s']*180/math.pi)
    assign('virtual.frequencyHz',0);assign('virtual.phaseRad',math.pi/2)
    a+=['u.asic.bitTrueEnable = true;','u.tune.autoApply = false;']
    lines=['function [p,u] = hrg_head_params(mode)',
      '% Generated head profile. Add the model directory and this folder to MATLAB path.',
      '% mode=rtl disables algorithms outside the implemented RTL boundary.',
      "if nargin<1, mode='rtl'; end", "assert(any(strcmp(mode,{'rtl','model'})), 'mode must be rtl or model');",
      'u = HRG_WA_v46_user_config();',*a,
      "if strcmp(mode,'rtl')",' u.kalman.enable=false; u.calib.enable=false; u.frp.enable=false;',
      ' u.comp.enableHarmonic=false; u.comp.enableTemperature=false; u.selftest.enable=false;',
      'end','p = HRG_WA_v46_params(u);',
      "p.meta.headId = '"+c['head_id']+"';", "p.meta.headConfigurationSha256 = '"+sha(canonical(c))+"';",
      '% SPI uses the rounded values below; real model gains above retain physical units.',
      'p.head.spiWords = uint32(['+' '.join(str(w['word']) for w in words)+']);',
      'p.head.energyHold = '+format(next(w['decoded'] for w in words if w['name']=='ENERGY_HOLD'),'.17g')+';',
      'p.head.quadHold = '+format(next(w['decoded'] for w in words if w['name']=='QUAD_HOLD'),'.17g')+';',
      'p.head.enableMask = '+str(r['enable_mask'])+';',
      "p.head.measurementStatus = '"+c['measurement_status']+"';",'end','']
    return '\n'.join(lines)

def generate(c,out,built=RECEIPT):
    validate(c);h=header(c);words=runtime_words(c);status=compatibility(c,built)
    out=Path(out);out.mkdir(parents=True,exist_ok=True)
    def write(name,text): (out/name).write_text(text,encoding='utf-8',newline='\n')
    def dump(name,value): write(name,json.dumps(value,ensure_ascii=False,indent=2)+'\n')
    write('hrg_head_config.vh',h);write('hrg_head_params.m',matlab(c,words));dump('spi_words.json',words)
    steps=[dict(op='write8',address=0x70,value=0),dict(op='write8',address=0,value=0),dict(op='write32',address=4,value=MAGIC)]
    steps += [dict(op='write32',address=w['address'],value=w['word']) for w in words]
    steps += [dict(op='wait_adc_samples',count=int(c['build']['fs_adc_hz']//c['build']['fs_ctrl_hz'])+2),
              dict(op='write8',address=0,value=c['runtime']['enable_mask'])]
    plan=dict(head_id=c['head_id'],measurement_status=c['measurement_status'],compatible_with_recorded_rtl_build=status['compatible'],hardware_image_identity_verified=False,
              spi_protocol='Each write8 is a separate CS transaction: 7-bit address (MSB=0), then data byte. Select page0 before executing.',steps=steps)
    dump('spi_plan.json',plan)
    byte_commands=[]
    for step in steps:
        if step['op']=='write32': byte_commands.extend((1,step['address']+i,(step['value']>>(8*i))&255) for i in range(4))
        elif step['op']=='write8': byte_commands.append((1,step['address'],step['value']))
        else: byte_commands.append((2,0,step['count']))
    write('spi_commands.txt',''.join(f'{op} {addr} {value}\n' for op,addr,value in byte_commands))
    write('spi_config.h','\n'.join(['/* Generated plan: op1=SPI write8; op2=wait ADC samples. No I/O is performed here. */',
        '#ifndef HRG_HEAD_SPI_CONFIG_H','#define HRG_HEAD_SPI_CONFIG_H','#include <stdint.h>',
        '#define HRG_PROFILE_REQUIRES_RECOMPILE '+str(int(not status['compatible'])),
        'typedef struct {uint8_t op; uint8_t address; uint32_t value;} hrg_head_command;',
        'static const hrg_head_command hrg_head_commands[] = {',
        *[f'    {{{op}, 0x{addr:02X}, {value}u}},' for op,addr,value in byte_commands],'};','#endif','']))
    dump('manifest.json',dict(head_id=c['head_id'],profile_sha256=sha(canonical(c)),build_sha256=build_id(c),
        compile_configuration={'build':c['build'],'architecture':c['architecture']},compile_values=compile_values(c),
        compatibility=status,warnings=['Measured/assumed status: '+c['measurement_status'],
        'Detection/drive matrices and mechanical error terms affect MATLAB only; no RTL online calibration is generated.',
        'Manual RUN hold values and CTRL loop enables are exported in p.head; the original MATLAB state machine retains its own feedforward/enable behavior.',
        'Automatic energy hold compensates mean damping in normalized model units only; it is not a drive voltage.']))
    return status

def active_matches(c):
    path=ROOT/'src/hrg_head_config.vh'
    if not path.exists() or path.read_text(encoding='utf-8-sig')!=header(c): raise ConfigError('Active RTL header differs. Run activate-build explicitly before compiling.')

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__);s=p.add_subparsers(dest='command',required=True)
    for cmd in ('generate','check','activate-build','begin-build'):
        sub=s.add_parser(cmd);sub.add_argument('config',type=Path)
        if cmd in ('generate','begin-build'): sub.add_argument('--out',type=Path,required=True)
        if cmd in ('generate','check'): sub.add_argument('--built',type=Path,default=RECEIPT)
    sub=s.add_parser('finish-build');sub.add_argument('--pending',type=Path,required=True)
    sub.add_argument('--simulation-log',type=Path,required=True);sub.add_argument('--elaboration-log',type=Path,required=True)
    sub.add_argument('--out',type=Path,default=RECEIPT)
    args=p.parse_args(argv)
    try:
        if args.command=='finish-build':
            pending=load(args.pending)
            if 'profile_sha256' in pending and sha(canonical(validate(load(pending['profile_path']))))!=pending['profile_sha256']: raise ConfigError('Head profile changed during build')
            if pending['rtl_sources']!=sources(): raise ConfigError('RTL changed during build; rebuild before creating receipt')
            for path,marker in [(args.simulation_log,('TOP_SCOREBOARD_PASS','HEAD_PROFILE_SCOREBOARD_PASS')),(args.elaboration_log,('HRG_RTL_ELABORATION_PASS',))]:
                if path.stat().st_mtime_ns<pending['started_ns']: raise ConfigError('Stale build evidence: '+str(path))
                log=path.read_text(encoding='utf-8-sig')
                if not any(token in log for token in marker) or 'Fatal:' in log or re.search(r'^ERROR:',log,re.M): raise ConfigError('Build evidence did not pass: '+str(path))
            pending['verification_scope']='closed-loop baseline scoreboard + RTL elaboration' if 'TOP_SCOREBOARD_PASS' in args.simulation_log.read_text() else 'profile SPI integration + RTL elaboration; closed-loop performance not established'
            pending['evidence']={str(path.resolve()):sha(path.read_text(encoding='utf-8-sig')) for path in (args.simulation_log,args.elaboration_log)}
            args.out.write_text(json.dumps(pending,indent=2)+'\n',encoding='utf-8')
            print('COMPLETED_RTL_BUILD_RECORDED');return 0
        c=validate(load(args.config));compile_values(c);runtime_words(c)
        if args.command=='generate':
            status=generate(c,args.out,args.built);print(json.dumps(status,ensure_ascii=False,indent=2));return 0
        if args.command=='check':
            status=compatibility(c,args.built);print(json.dumps(status,ensure_ascii=False,indent=2));return 0 if status['compatible'] else 2
        if args.command=='activate-build':
            (ROOT/'src/hrg_head_config.vh').write_text(header(c),encoding='utf-8',newline='\n')
            print('ACTIVE_RTL_HEADER_UPDATED; recompile and record build before applying SPI');return 0
        active_matches(c)
        pending=dict(head_id=c['head_id'],profile_path=str(args.config.resolve()),profile_sha256=sha(canonical(c)),started_ns=time.time_ns(),build_sha256=build_id(c),header_sha256=sha(header(c)),
                     compile_configuration={'build':c['build'],'architecture':c['architecture']},rtl_sources=sources())
        args.out.write_text(json.dumps(pending,indent=2)+'\n',encoding='utf-8');print('BUILD_STARTED');return 0
    except (ConfigError,KeyError,ValueError,OSError,OverflowError) as e:
        print('HEAD_CONFIG_ERROR: '+str(e),file=sys.stderr);return 3

if __name__=='__main__': sys.exit(main())
