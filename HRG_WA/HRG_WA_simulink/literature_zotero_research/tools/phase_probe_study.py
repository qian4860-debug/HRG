"""Averaged calibration experiment: phase/frequency-split identifiability.

Not an RF Simulink implementation, not a reproduction of a source experiment.
"""
from pathlib import Path
import json
import numpy as np

ROOT=Path(__file__).resolve().parents[1]

def main():
    truth=np.array([2*np.pi*.002,np.pi/180,1e-5])
    output=[]
    for label,duration,collinear,permit in [('integer_cycles',10,False,True),
            ('short_noninteger',.31,False,True),('too_short',.005,False,True),
            ('collinear_probe',1,True,True),('unknown_motion',10,False,False)]:
        t=np.arange(0,duration,.001);w=2*np.pi;ratio=.01
        x1=.5*ratio*np.sin(w*t+.17)
        x2=-.5*w*ratio*np.cos(w*t+.17)
        if collinear:x1=2*x2
        X=np.column_stack((x1,x2,np.ones_like(t)))
        y=X@truth
        # Unknown motion at the injection frequency is observationally identical
        # to a parameter error: numerical rank alone cannot authorize calibration.
        if not permit:y=y+x2*.01
        scale=np.linalg.norm(X,axis=0);Z=X/scale
        singular=np.linalg.svd(Z,compute_uv=False);condition=float(singular[0]/singular[-1])
        rank=int(np.linalg.matrix_rank(Z,tol=1e-8))
        eligible=bool(permit and rank==3 and condition<=1e4)
        coefficients=np.linalg.lstsq(Z,y,rcond=None)[0]/scale
        single=np.linalg.lstsq(np.column_stack((x2,np.ones_like(t))),y,rcond=None)[0][0]
        rec=dict(name=label,duration_s=duration,samples=len(t),fixture_zero_motion_permit=permit,
            normalized_design_rank=rank,normalized_condition=condition,update_allowed=eligible,
            unguarded_joint_phase_error_rad=float(coefficients[1]-truth[1]),
            omitted_split_phase_error_rad=float(single-truth[1]),
            joint_frequency_split_error_rad_s=float(coefficients[0]-truth[0]))
        if eligible:assert np.max(abs(coefficients-truth))<1e-10
        if collinear or not permit or label=='too_short':assert not eligible
        output.append(rec)
    assert abs(output[0]['omitted_split_phase_error_rad'])<1e-12
    assert abs(output[1]['omitted_split_phase_error_rad'])>1e-5
    assert abs(output[-1]['unguarded_joint_phase_error_rad']-.01)<1e-12
    result=dict(date='2026-10-24',pass_=True,truth=dict(split_hz=.002,phase_rad=float(truth[1]),background_rad_s=1e-5),
        cases=output,boundary='Noiseless averaged linear calibration model; requires externally known zero motion, not an online unknown-motion estimator')
    (ROOT/'evidence/phase_probe_study.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps(result))

if __name__=='__main__':main()
