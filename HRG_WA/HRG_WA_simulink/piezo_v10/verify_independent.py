"""Independent reconstruction of the continuous plant and its ZOH propagator.
Does not import MATLAB's plant/tick or use MATLAB matrices to generate answers.
"""
from pathlib import Path
import json
import numpy as np

def expm(A):
 # Independently implemented scaled Taylor series; no SciPy/MATLAB expm.
 n=max(0,int(np.ceil(np.log2(max(1.,np.linalg.norm(A,1)/.25)))))
 S=A/(2.**n);term=np.eye(len(A));result=term.copy()
 for k in range(1,80):
  term=term@S/k;result+=term
  if np.linalg.norm(term,1)<1e-18:break
 for _ in range(n):result=result@result
 return result

ROOT=Path(__file__).resolve().parent;EV=ROOT/'evidence'
def main():
 p=json.loads((EV/'parameters.json').read_text());w=2*np.pi*p['f0'];J=np.array([[0.,-1.],[1.,0.]])
 A=np.zeros((12,12));B=np.zeros((12,2));I=np.eye(2)
 A[:2,2:4]=I;A[2:4,:2]=-np.diag((w+np.array([-1,1])*np.pi*p['split_hz'])**2)
 A[2:4,2:4]=-np.diag(w/p['Q']+np.array([1,-1])*2*p['damping_delta'])-4*p['B']*p['Omega']*J
 A[2:4,4:6]=p['theta_d']/p['mass']*np.diag([1,p['drive_y']]);A[2:4,6:8]=p['theta_s']/p['mass']*I
 A[4:6,4:6]=-I/p['driver_tau'];B[4:6]=I/p['driver_tau']
 A[6:8,6:8]=-I/(p['Rs']*p['Cs']);A[6:8,2:4]=-p['theta_s']/p['Cs']*I
 A[6:8]+=p['Cds']/p['Cs']*A[4:6];B[6:8]=p['Cds']/p['Cs']*B[4:6]
 A[8:10,6:8]=I/(p['Rs']*p['Cf']);A[8:10,8:10]=-I/(p['Rf']*p['Cf'])
 A[10:12,8:10]=2*np.pi*p['afe_bw']*I;A[10:12,10:12]=-2*np.pi*p['afe_bw']*I
 M=np.zeros((14,14));M[:12,:12]=A;M[:12,12:]=B;E=expm(M*p['Ts'])
 checks={}
 for name,expected in [('continuous_A',A),('continuous_B',B),('discrete_A',E[:12,:12]),('discrete_B',E[:12,12:])]:
  actual=np.loadtxt(EV/(name+'.csv'),delimiter=',');err=float(np.max(abs(actual-expected))/max(1,np.max(abs(expected))))
  checks[name]=dict(passed=err<1e-10,relative_max_error=err)
 # Conservative mechanical plus clamped dielectric energy. No drive, no feedthrough.
 # Its derivative is -v^T C v - vs^T G vs; reciprocal terms cancel exactly.
 rng=np.random.default_rng(29);mx=0.
 for _ in range(100):
  q=rng.normal(size=2)*1e-6;v=rng.normal(size=2)*.01;vs=rng.normal(size=2)*.01
  force=-p['mass']*w*w*q-p['mass']*w/p['Q']*v-4*p['mass']*p['B']*p['Omega']*(J@v)+p['theta_s']*vs
  vsdot=(-vs/p['Rs']-p['theta_s']*v)/p['Cs']
  power=v@force+p['mass']*w*w*q@v+p['Cs']*vs@vsdot
  dissip=-p['mass']*w/p['Q']*(v@v)-(vs@vs)/p['Rs'];mx=max(mx,abs(power-dissip))
 checks['passive_energy_balance_100_states']=dict(passed=bool(mx<1e-16),max_absolute_residual_W=float(mx))
 eig=np.linalg.eigvals(A)
 checks['passive_stable_poles']=dict(passed=bool(np.max(eig.real)<0),largest_real_pole=float(np.max(eig.real)))
 receipt=dict(scope='Independent linear piezo/circuit plant only, not independent controller proof',checks=checks)
 (EV/'independent_checks.json').write_text(json.dumps(receipt,indent=2)+'\n')
 assert all(c['passed'] for c in checks.values());print('6 independent plant checks passed')
if __name__=='__main__':main()
