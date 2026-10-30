"""Independent NumPy complex-envelope integration and angle/rate scoreboard.

Reads parameters and exported observations, never calls the MATLAB step/tick.
This checks an averaged model, not the accuracy of averaging against hardware.
"""
from pathlib import Path
import json
import numpy as np

HERE=Path(__file__).resolve().parent; EV=HERE/'evidence'

def replay(p,cp):
    rotate=lambda a:np.array([[np.cos(a),-np.sin(a)],[np.sin(a),np.cos(a)]])
    r=rotate(p['damping_axis'])
    damping=r@np.diag(p['gamma_intrinsic']+np.array([1,-1])*p['damping_half_difference'])@r.T
    r=rotate(p['stiffness_axis'])
    stiffness=r@np.diag(np.array([-1,1])*np.pi*p['split_hz'])@r.T
    J=np.array([[0.,-1.],[1.,0.]])
    linear=-damping-2*p['B']*p['Omega']*J+1j*stiffness
    def derivative(z):
        a=np.linalg.norm(z); direction=z.real/max(np.linalg.norm(z.real),1e-8)
        transverse=-z.imag-direction*(direction@(-z.imag))
        radial=p['gamma_intrinsic']*a+p['env_amplitude_gain']*(1-a)
        force=radial*direction+a*cp*(J@direction)+1j*p['env_quad_gain']*transverse
        phase=p['env_phase_gain']*(z.real@z.imag)/max(a*a,1e-12)
        return linear@z+force-1j*phase*z,2*(2*np.pi*p['f0'])*p['charge_target']*np.linalg.norm(force)/p['b']
    dt=p['envTs']; count=round(p['envDuration']/dt)+1
    z=p['initial_fraction']*np.array([np.cos(p['theta0']),np.sin(p['theta0'])],dtype=complex)
    result=np.empty((count,6))
    for i in range(count):
        k1,voltage=derivative(z); result[i]=[*z.real,*(-z.imag),cp,voltage]
        k2,_=derivative(z+dt*k1/2); k3,_=derivative(z+dt*k2/2); k4,_=derivative(z+dt*k3)
        z+=dt*(k1+2*k2+2*k3+k4)/6
    n=result[:,0]**2+result[:,2]**2-result[:,1]**2-result[:,3]**2
    m=2*(result[:,0]*result[:,1]+result[:,2]*result[:,3])
    theta=np.unwrap(np.angle(n+1j*m))/2
    t=np.arange(count)*dt; hold=t>.6*p['envDuration']
    slope=np.polyfit(t[hold]-np.mean(t[hold]),theta[hold],1)[0]
    return result,theta,(cp-slope)/(2*p['B'])

def main():
    p=json.loads((EV/'envelope_parameters.json').read_text())
    data=np.loadtxt(EV/'low_rate_traces.csv',delimiter=',')
    research=json.loads((EV/'research_results.json').read_text());checks={};errors={}
    for name,cp,col,theta_col in [('WA',0.,1,7),('virtual',2.,8,14)]:
        y,theta,rate=replay(p,cp)
        errors[name+'_state_max']=float(np.max(abs(y-data[:,col:col+6])))
        errors[name+'_angle_max']=float(np.max(abs(theta-data[:,theta_col])))
        errors[name+'_rate']=abs(float(rate)-research[name]['estimated_rate_rad_s'])
        checks[name+'_independent_states']=errors[name+'_state_max']<1e-8
        checks[name+'_independent_angle']=errors[name+'_angle_max']<1e-8
        checks[name+'_independent_rate']=errors[name+'_rate']<1e-9
    result=dict(checks=checks,errors=errors,scope='Independent averaged dynamics; ideal calibrated force, no fast ADC/clock equivalence claim')
    (EV/'independent_envelope_results.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    assert all(checks.values()),result
    print('PASS',len(checks),'independent envelope checks')

if __name__=='__main__':main()
