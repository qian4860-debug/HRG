"""A1估计器：只读观测/独立电路校准；不读取生成器、机械参数或评分真值。"""
from pathlib import Path
import argparse
import math
import sys
import numpy as np

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'port_to_metric_20261103'))
from a0_common import read_json,write_json,write_csv,sha,constraints,solve_metric,angle_increment


def complex_value(row,prefix):
    return np.asarray(row[prefix+'_re'])+1j*np.asarray(row[prefix+'_im'])


def electrical(row,cal):
    s=2j*np.pi*row['frequency_Hz'];rs=cal['Rs'][row['load_index']-1]
    f=1/(1+s/(2*np.pi*np.asarray(cal['afe_bw'])))
    q=-s/((cal['Cs']*s+1/rs+cal['G0'])*rs*cal['Cf']*(s+1/(cal['Rf']*cal['Cf'])))
    Q=1/(rs*cal['Cf']*(s+1/(cal['Rf']*cal['Cf'])))
    vd=complex_value(row,'u')/(1+s*np.asarray(cal['driver_tau']))
    fixture=complex_value(row,'fixture')
    return s,rs,f,q,Q,vd,fixture


def deembed(row,cal):
    s,rs,f,q,Q,vd,fixture=electrical(row,cal)
    y=complex_value(row,'y')
    z=(y-fixture@vd)/f/q
    vsz=y/f/Q
    return z,vsz,vd


def predict(row,cal,model,mode):
    s,rs,f,q,Q,vd,fixture=electrical(row,cal)
    if mode=='raw_second_order':
        return np.linalg.solve(s*s*np.eye(2)+s*model['D']+model['K'],model['B']@complex_value(row,'u'))
    load=-s/(cal['Cs']*s+1/rs+cal['G0'])
    feed_vs=fixture/f[:,None]/Q
    z=np.linalg.solve(s*s*np.eye(2)+s*model['D']+model['K']-model['kappa']*load*np.eye(2),
                      (model['B']+model['kappa']*feed_vs)@vd)
    return f*q*z+fixture@vd


def equations(rows,cal,mode,pilot=None):
    design=[];rhs=[];instruments=[]
    joint=mode=='joint_loading';width=13 if joint else 12
    for row in rows:
        s=2j*np.pi*row['frequency_Hz']
        if mode=='raw_second_order':
            z=complex_value(row,'y');vsz=np.zeros(2);vd=complex_value(row,'u')
        else:
            z,vsz,vd=deembed(row,cal)
        zp,vsp=z,vsz
        if pilot is not None:
            synthetic=dict(row)
            yp=predict(row,cal,pilot,mode)
            synthetic.update(y_re=yp.real.tolist(),y_im=yp.imag.tolist())
            if mode=='raw_second_order':zp=yp
            else:zp,vsp,_=deembed(synthetic,cal)
        for j in range(2):
            x=np.zeros(width,dtype=complex);iv=x.copy()
            x[6*j:6*j+6]=np.r_[s*z,z,-vd]
            iv[6*j:6*j+6]=np.r_[s*zp,zp,-vd]
            if joint:x[-1]=-vsz[j];iv[-1]=-vsp[j]
            design.append(x);instruments.append(iv);rhs.append(-s*s*z[j])
    x=np.asarray(design);iv=np.asarray(instruments);y=np.asarray(rhs)
    return np.r_[x.real,x.imag],np.r_[iv.real,iv.imag],np.r_[y.real,y.imag]


def regress(rows,cal,mode,pilot=None):
    x,z,y=equations(rows,cal,mode,pilot)
    scale=np.maximum(np.linalg.norm(x,axis=0),1e-100);xn=x/scale
    if pilot is None:left,target=xn,y
    else:
        zn=z/np.maximum(np.linalg.norm(z,axis=0),1e-100)
        left,target=zn.T@xn,zn.T@y
    coef,_,rank,singular=np.linalg.lstsq(left,target,rcond=1e-12)
    if rank!=x.shape[1]:raise ValueError('二阶算子/共同加载参数缺少激励秩')
    coef=coef/scale;m=coef[:12].reshape(2,6)
    return dict(D=m[:,:2],K=m[:,2:4],B=m[:,4:6],kappa=float(coef[-1]) if mode=='joint_loading' else 0.,
                condition=float(singular[0]/singular[-1]))


def mean_model(models):
    return {key:np.mean([m[key] for m in models],axis=0) for key in ['D','K','B','kappa']}


def estimate(observations,output,mode='joint_loading'):
    observations=Path(observations).resolve();output=Path(output).resolve();used=[]
    def load(name):
        path=(observations/name).resolve();assert path.is_relative_to(observations)
        used.append(dict(path=name,sha256=sha(path)));return read_json(path)
    protocol=load('protocol.json');threshold=read_json(HERE/'acceptance.json')
    assert protocol['Omega']==0 and protocol['known_handedness']==1
    results=[]
    for spec in protocol['cases']:
        data=load(spec['file']);cal=data['electronics']
        groups=[[r for r in data['train'] if r['repeat']==i] for i in range(1,protocol['repeats']+1)]
        ols=[regress(g,cal,mode) for g in groups]
        fits=[regress(g,cal,mode,mean_model([m for j,m in enumerate(ols) if j!=i])) for i,g in enumerate(groups)]
        model=mean_model(fits)
        cs=np.array([constraints(f,threshold['reference_omega']) for f in fits]);cm=cs.mean(axis=0)
        se=math.sqrt(float(np.sum((cs-cm)**2)/(len(cs)*(len(cs)-1))))
        eps=threshold['constraint_floor']+threshold['repeat_inflation']*se
        W,singular=solve_metric(cm);gap=float(singular[-1]);bound=eps/(gap-eps) if gap>eps else None
        geometry=W is not None and bound is not None and bound<=math.sin(threshold['null_direction_budget_rad'])
        # validation只用于模型适用性；最终角度记录在适用性冻结之后处理。
        byfreq={}
        for row in data['validation']:
            key=(row['frequency_Hz'],row['load_index']);byfreq.setdefault(key,[0.,0.])
            yp=predict(row,cal,model,mode);y=complex_value(row,'y')
            byfreq[key][0]+=float(np.sum(abs(yp-y)**2));byfreq[key][1]+=float(np.sum(abs(y)**2))
        errors=[math.sqrt(a/max(b,1e-100)) for a,b in byfreq.values()]
        max_error=max(errors);compatible=max_error<=threshold['heldout_max_relative']
        positive_kappa=bool(model['kappa']>0) if mode=='joint_loading' else True
        eligible=bool(geometry and compatible and positive_kappa)
        # 以下只对已冻结W应用，不利用运动真值做偏置/时延对齐。
        times=np.asarray(data['motion_time']);envelope=np.zeros((len(times),2),complex)
        raw_envelope=envelope.copy()
        for row in data['motion']:
            side_omega=2*np.pi*(row['frequency_Hz']-data['carrier_Hz'])
            phase=np.exp(1j*side_omega*times)[:,None]
            z,_,_=deembed(row,cal)
            envelope+=phase*z;raw_envelope+=phase*complex_value(row,'y')
        raw=angle_increment(raw_envelope.real)
        # W的坐标必须与拟合算子一致：raw基线在AFE坐标，其余方法在去嵌z坐标。
        coordinates=raw_envelope.real if mode=='raw_second_order' else envelope.real
        candidate=angle_increment(coordinates,W) if W is not None else np.full(len(times),np.nan)
        published=candidate if eligible else np.full(len(times),np.nan)
        write_csv(output/(spec['id']+'_angles.csv'),np.c_[times,raw,candidate,published],
                  ['time_s','raw_increment_rad','candidate_increment_rad','published_increment_rad'])
        results.append(dict(id=spec['id'],mode=mode,D=model['D'].tolist(),K=model['K'].tolist(),B=model['B'].tolist(),
            kappa=float(model['kappa']),W=W.tolist() if W is not None else None,C=cm.tolist(),
            epsilon_C=eps,constraint_gap=gap,null_direction_bound=bound,geometry_eligible=bool(geometry),
            electrical_model_compatible=bool(compatible),positive_loading=positive_kappa,eligible=eligible,
            maximum_validation_relative_error=max_error,validation_by_frequency_load=[dict(frequency_Hz=k[0],load_index=k[1],relative_error=e) for k,e in zip(byfreq,errors)],
            maximum_fit_condition=max(f['condition'] for f in fits),
            reason='pass' if eligible else 'electrical_model_mismatch_or_noise' if not compatible else 'nonpositive_loading' if not positive_kappa else 'insufficient_metric_information'))
    result=dict(schema='A1-estimates-v1',mode=mode,cases=results,source_inputs=used,
                estimator_sha256=sha(__file__),threshold_sha256=sha(HERE/'acceptance.json'),
                scope='实常数检测矩阵、静止、线性12状态；独立电路夹具校准；经验门控')
    write_json(output/'estimates.json',result)
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--observations',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--mode',choices=['joint_loading','no_loading','raw_second_order'],default='joint_loading');args=parser.parse_args()
    for r in estimate(args.observations,args.output,args.mode)['cases']:
        print(r['id'],r['mode'],r['eligible'],r['reason'],'validation=%.4g'%r['maximum_validation_relative_error'],'kappa=%.4g'%r['kappa'])
