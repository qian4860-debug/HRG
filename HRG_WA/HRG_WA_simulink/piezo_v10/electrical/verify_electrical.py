"""Independent electrical plant and transfer checks; no mechanical mass or Theta."""
from pathlib import Path
import sys,json
import numpy as np
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent))
from verify_independent import expm
def main():
 p=json.loads((HERE/'evidence/parameters.json').read_text());EV=HERE/'evidence';w=2*np.pi*p['f0'];I=np.eye(2)
 A=np.zeros((12,12));B=np.zeros((12,2));A[:2,2:4]=I;A[2:4,:2]=-w*w*I;A[2:4,2:4]=-2*p['gamma']*I
 A[2:4,4:6]=p['b']*I;A[2:4,6:8]=p['kappa']*I
 A[4:6,4:6]=-I/p['driver_tau'];B[4:6]=I/p['driver_tau']
 A[6:8,2:4]=-I/p['Cs'];A[6:8,6:8]=-(1/p['Rs']+p['G0'])/p['Cs']*I
 A[6:8]+=p['Cds']/p['Cs']*A[4:6];B[6:8]=p['Cds']/p['Cs']*B[4:6]
 A[8:10,6:8]=I/(p['Rs']*p['Cf']);A[8:10,8:10]=-I/(p['Rf']*p['Cf']);A[10:12,8:10]=I*2*np.pi*p['afe_bw'];A[10:12,10:12]=-I*2*np.pi*p['afe_bw']
 M=np.zeros((14,14));M[:12,:12]=A;M[:12,12:]=B;E=expm(M*p['Ts']);checks={}
 for name,expected in [('A',A),('B',B),('Ad',E[:12,:12]),('Bd',E[:12,12:])]:
  actual=np.loadtxt(EV/(name+'.csv'),delimiter=',');err=float(np.max(abs(actual-expected))/max(1,np.max(abs(expected))))
  checks[name]=dict(passed=err<1e-9,relative_error=err)
 errs=[]
 for f in [p['f0']-.1,p['f0'],p['f0']+.1]:
  s=2j*np.pi*f;load=1/p['Rs']+p['G0']+s*p['Cs'];D=s*s+2*p['gamma']*s+w*w
  eta=(p['b']+p['kappa']*p['Cds']*s/load)/(D+p['kappa']*s/load)
  vs=(-s*eta+p['Cds']*s)/load
  vo=vs/p['Rs']/(p['Cf']*(s+1/(p['Rf']*p['Cf'])))/(1+s/(2*np.pi*p['afe_bw']))/(1+s*p['driver_tau'])
  measured=np.linalg.solve(s*np.eye(12)-np.loadtxt(EV/'A.csv',delimiter=','),np.loadtxt(EV/'B.csv',delimiter=',')[:,0])[10]
  errs.append(abs(measured-vo)/max(abs(vo),1e-20))
 checks['closed_form_loaded_transfer_3points']=dict(passed=bool(max(errs)<1e-8),relative_error=float(max(errs)))
 checks['no_physical_mass_or_piezo_constants']=dict(passed=not any(k in p for k in ['mass','theta_s','theta_d']))
 assert all(x['passed'] for x in checks.values())
 (EV/'independent_checks.json').write_text(json.dumps(checks,indent=2)+'\n',encoding='utf-8',newline='\n');print('6 independent electrical-domain checks passed')
if __name__=='__main__':main()
