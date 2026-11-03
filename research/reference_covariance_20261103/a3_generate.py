"""归档A2物理端口观测，并增加有状态传感失效/非白噪声负例；不执行估计器。"""
import argparse
import copy
import numpy as np
from a3_common import HERE,A2,read_json,write_json,sha


def correlated_noise(rng,n,sigma,rho=.98):
    x=rng.standard_normal((n+4096,2));state=np.zeros(2);result=[]
    for v in x:
        state=rho*state+np.sqrt(1-rho*rho)*sigma*v;result.append(state.copy())
    return np.asarray(result[4096:])


def generate(fresh=False):
    specs=read_json(A2/'data/observations/protocol.json')['cases']
    truth=read_json(A2/'data/private_score/truth.json')['cases']
    protocol=dict(schema='A3-observed-stream-v1',cases=[]);targets=[];provenance=[]
    def add(data,target,cid,source):
        data=copy.deepcopy(data);data.setdefault('sensor_invalid_intervals_s',[])
        data.setdefault('noise_model','white');target=copy.deepcopy(target);target['id']=cid
        target['source']=source;target.setdefault('fault_kind','none')
        write_json(HERE/'data/observations'/(cid+'.json'),data)
        protocol['cases'].append(dict(id=cid,file=cid+'.json'));targets.append(target)
    for spec,t in zip(specs,truth):
        source=A2/'data/observations'/spec['file'];data=read_json(source)
        add(data,t,spec['id'],'A2_'+spec['id']);provenance.append(dict(source=str(source.relative_to(HERE.parent.parent)),sha256=sha(source)))
    base=read_json(A2/'data/observations/case_004.json');target=truth[3]
    for cid,interval,label in [('case_016',[.65,.66],'short_dropout'),('case_017',[.65,.77],'long_dropout'),('case_019',[.24,.29],'initial_dropout')]:
        d=copy.deepcopy(base);d['sensor_invalid_intervals_s']=[interval]
        t=dict(target,fault_kind=label);add(d,t,cid,'A2_case_004_with_declared_sensor_fault')
    d=read_json(A2/'data/observations/case_005.json');d['noise_model']='AR1';d['noise_rho']=.98
    d['noise_probe_V']=correlated_noise(np.random.default_rng(18018),4096,d['stream_noise_RMS_V']).tolist()
    add(d,dict(truth[4],fault_kind='nonwhite_noise'),'case_018','A2_case_005_with_AR1_sample_noise')
    if fresh:
        for index,(sigma,seed) in enumerate([(500e-6,8801),(500e-6,8802),(1e-3,8803),(1e-3,8804)],20):
            d=read_json(A2/'data/observations/case_005.json');d['stream_noise_RMS_V']=sigma;d['stream_noise_seed']=seed
            d['noise_probe_V']=(sigma*np.random.default_rng(seed+100000).standard_normal((4096,2))).tolist()
            add(d,dict(truth[4],extra_seed=True,fault_kind='fresh_noise_seed'),f'case_{index:03d}','post-freeze new stream/probe seeds')
    protocol['cases'].sort(key=lambda c:c['id']);targets.sort(key=lambda c:c['id'])
    write_json(HERE/'data/observations/protocol.json',protocol);write_json(HERE/'data/private_score/truth.json',dict(cases=targets))
    write_json(HERE/'data/provenance.json',dict(sources=provenance,fresh_seeds_included=fresh,
        scope='A2 compact physical port records; sensor fault is explicitly injected after AFE, not a claimed mechanical trajectory'))
    print('A3 generated',len(targets),'cases; fresh=',fresh)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--fresh',action='store_true');generate(p.parse_args().fresh)
