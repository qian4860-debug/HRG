"""Independent integer boundary, timing and passive electrical plant checks."""
from pathlib import Path
import json
import numpy as np

HERE=Path(__file__).resolve().parent;EV=HERE/'evidence'


def expm(a):
    n=max(0,int(np.ceil(np.log2(max(1.,np.linalg.norm(a,1)/.25)))))
    x=a/(2.**n);r=np.eye(len(a));t=r.copy()
    for k in range(1,100):
        t=t@x/k;r+=t
        if np.linalg.norm(t,1)<1e-18:break
    for _ in range(n):r=r@r
    return r


def main():
    p=json.loads((EV/'parameters.json').read_text());w=2*np.pi*p['f0'];checks={}
    for bits in [2,8,18,20]:
        lsb=2/2**bits;codes=np.array([-2**(bits-1),2**(bits-1)-1]);values=codes*lsb
        checks['code_domain_'+str(bits)]=bool(values[0]==-1 and values[1]==1-lsb)
    frames=np.genfromtxt(EV/'baseline_frames.csv',delimiter=',',names=True)
    center=frames['source_center_s'];start=frames['window_start_s'];end=frames['window_end_s'];avail=frames['available_s']
    checks['centers_arithmetic_mean']=bool(np.max(abs(center-(start+end)/2))<1e-12)
    checks['availability_one_sample_after_end']=bool(np.max(abs(avail-end-p['Ts']))<1e-12)
    checks['windows_nonoverlap']=bool(np.all(np.diff(start)>end[0]-start[0]))
    checks['unweighted_sample_pseudoreplication_absent']=len(frames)==round(p['duration']/p['Tc'])
    A=np.zeros((12,12));B=np.zeros((12,2));I=np.eye(2);J=np.array([[0.,-1.],[1.,0.]])
    R=lambda t:np.array([[np.cos(t),-np.sin(t)],[np.sin(t),np.cos(t)]])
    K=R(p['stiffness_axis'])@np.diag((w+np.array([-1,1])*np.pi*p['split_hz'])**2)@R(p['stiffness_axis']).T
    D=R(p['damping_axis'])@np.diag(2*(p['gamma_intrinsic']+np.array([1,-1])*p['damping_half_difference']))@R(p['damping_axis']).T
    A[:2,2:4]=I;A[2:4,:2]=-K;A[2:4,2:4]=-D-4*p['B']*p['Omega']*J
    A[2:4,4:6]=p['b']*np.array(p['drive_matrix']);A[2:4,6:8]=p['kappa']*I
    A[4:6,4:6]=-np.diag(1/np.array(p['driver_tau']));B[4:6]=np.diag(1/np.array(p['driver_tau']))
    A[6:8,6:8]=-(1/p['Rs']+p['G0'])/p['Cs']*I;A[6:8,2:4]=-I/p['Cs']
    A[6:8]+=p['Cds']/p['Cs']*A[4:6];B[6:8]=p['Cds']/p['Cs']*B[4:6]
    A[8:10,6:8]=I/(p['Rs']*p['Cf']);A[8:10,8:10]=-I/(p['Rf']*p['Cf'])
    A[10:12,8:10]=np.diag(2*np.pi*np.array(p['afe_bw']))@np.array(p['detect_matrix']);A[10:12,10:12]=-np.diag(2*np.pi*np.array(p['afe_bw']))
    m=np.zeros((14,14));m[:12,:12]=A;m[:12,12:]=B;E=expm(m*p['Ts']);errors={}
    for name,expected in [('A',A),('B',B),('Ad',E[:12,:12]),('Bd',E[:12,12:])]:
        actual=np.loadtxt(EV/(name+'.csv'),delimiter=',');err=float(np.max(abs(actual-expected))/max(1.,np.max(abs(expected))))
        checks[name+'_independent']=err<1e-10;errors[name]=err
    rng=np.random.default_rng(31);error=0
    for _ in range(128):
        q=rng.normal(size=2)*1e-11;vel=rng.normal(size=2)*1e-7;vs=rng.normal(size=2)*.001
        acc=-K@q-D@vel-4*p['B']*p['Omega']*J@vel+p['kappa']*vs
        vd=(-vel-(1/p['Rs']+p['G0'])*vs)/p['Cs']
        power=(vel@acc+q@K@vel)/p['kappa']+p['Cs']*vs@vd
        diss=-vel@D@vel/p['kappa']-(1/p['Rs']+p['G0'])*(vs@vs)
        error=max(error,abs(power-diss))
    checks['reciprocal_port_energy_128_states']=error<1e-15
    checks['passive_plant_poles']=bool(np.max(np.linalg.eigvals(A).real)<0)
    checks={k:bool(v) for k,v in checks.items()}
    result=dict(checks=checks,errors=errors,boundary='Independent plant/quantizer/time contracts; controller tick replay is a separate scheduling check')
    (EV/'independent_measurement_results.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    assert all(checks.values()),result;print('PASS',len(checks),'independent measurement/plant checks')


if __name__=='__main__':main()
