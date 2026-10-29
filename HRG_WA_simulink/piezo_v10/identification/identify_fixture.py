"""Synthetic test-to-model identification: no manufacturer parameters supplied to fitter.
NumPy only. Electrical gauge and optional independently calibrated displacement.
"""
from pathlib import Path
import json
import numpy as np
HERE=Path(__file__).resolve().parent

def fit_complex(A,y):
    scale=np.linalg.norm(A,axis=0)
    X=np.vstack([(A/scale).real,(A/scale).imag]);Y=np.r_[y.real,y.imag]
    coef=np.linalg.lstsq(X,Y,rcond=None)[0]/scale
    return coef,float(np.linalg.norm(A@coef-y)/np.linalg.norm(y)),float(np.linalg.cond(X))

def identify(t,z,f,Y,Ycross):
    # Uniform quadrature ringdown, coherent carrier reference retained.
    dt=float(np.mean(np.diff(t)));assert np.allclose(np.diff(t),dt)
    rho=np.vdot(z[:-1],z[1:])/np.vdot(z[:-1],z[:-1])
    gamma=-np.log(abs(rho))/dt;wd=np.angle(rho)/dt
    assert gamma>0 and wd>0
    w0=float(np.hypot(wd,gamma));s=2j*np.pi*f;den=s*s+2*gamma*s+w0*w0
    coeff,res,cond=fit_complex(np.column_stack([np.ones(len(f)),s,s/den]),Y)
    cross,rc,cc=fit_complex(np.column_stack([s,s/den]),Ycross)
    G,Cs,kappa=coeff;Cds,b=cross
    assert Cs>0 and kappa>0
    return dict(f0_Hz=w0/(2*np.pi),Q=w0/(2*gamma),gamma_per_s=float(gamma),
        Cs_F=float(Cs),leakage_S=float(G),kappa_s=float(kappa),cross_b=float(b),
        Cds_F=float(Cds),motional_L_H=float(1/kappa),motional_R_ohm=float(2*gamma/kappa),
        motional_C_F=float(kappa/w0**2),fit_relative_residual=res,cross_residual=rc,
        scaled_condition=cond,cross_scaled_condition=cc)

def main():
    rng=np.random.default_rng(20261029)
    # Truth is used only by fixture generation and scoring, never identify().
    truth=dict(m=1e-4,theta_s=1e-5,theta_d=1.1e-5,f0=1000.,Q=1e4,Cs=1e-9,G=1e-10,Cds=.15e-12)
    w=2*np.pi*truth['f0'];gam=w/(2*truth['Q']);wd=np.sqrt(w*w-gam*gam)
    t=np.arange(20000)*1e-4
    z=1e-11*np.exp((-gam+1j*wd)*t)+1e-17*(rng.normal(size=len(t))+1j*rng.normal(size=len(t)))
    f=np.r_[np.linspace(950,1040,100),1000+np.linspace(-.2,.2,101)]
    s=2j*np.pi*f;den=s*s+2*gam*s+w*w
    Y=truth['G']+s*truth['Cs']+s*(truth['theta_s']**2/truth['m'])/den
    X=s*truth['Cds']+s*(truth['theta_s']*truth['theta_d']/truth['m'])/den
    Y+=1e-12*(rng.normal(size=len(f))+1j*rng.normal(size=len(f)))
    X+=1e-12*(rng.normal(size=len(f))+1j*rng.normal(size=len(f)))
    est=identify(t,z,f,Y,X)
    # Independent LDV+charge calibration points, not a fitted mass prior.
    q=np.linspace(-1e-6,1e-6,31);charge=truth['theta_s']*q+2e-16*rng.normal(size=len(q))
    theta=float(np.linalg.lstsq(np.column_stack([q,np.ones(len(q))]),charge,rcond=None)[0][0])
    physical=dict(theta_s_C_per_m=theta,mass_kg=theta**2/est['kappa_s'],
        theta_d_N_per_V=est['cross_b']*theta/est['kappa_s'])
    errors=dict(f0=abs(est['f0_Hz']/truth['f0']-1),Q=abs(est['Q']/truth['Q']-1),
        Cs=abs(est['Cs_F']/truth['Cs']-1),mass=abs(physical['mass_kg']/truth['m']-1),
        theta_s=abs(theta/truth['theta_s']-1),theta_d=abs(physical['theta_d_N_per_V']/truth['theta_d']-1))
    # Demonstrate non-identifiability, not just optimizer convergence.
    lam=3.;Yscaled=truth['G']+s*truth['Cs']+s*(lam*truth['theta_s'])**2/(lam**2*truth['m']*den)
    checks=dict(parameter_recovery=max(errors.values())<.002,
        gauge_ambiguity=float(np.max(abs(Yscaled-(truth['G']+s*truth['Cs']+s*truth['theta_s']**2/truth['m']/den))))<1e-15,
        impedance_residual=est['fit_relative_residual']<1e-5,
        acceptable_condition=est['scaled_condition']<100)
    # A withheld grid validates the fitted transfer, not the training residual alone.
    fv=np.linspace(999.7,1000.3,89);sv=2j*np.pi*fv
    predicted=est['leakage_S']+sv*est['Cs_F']+sv*est['kappa_s']/(sv**2+2*est['gamma_per_s']*sv+(2*np.pi*est['f0_Hz'])**2)
    actual=truth['G']+sv*truth['Cs']+sv*truth['theta_s']**2/truth['m']/(sv**2+2*gam*sv+w*w)
    holdout=float(np.linalg.norm(predicted-actual)/np.linalg.norm(actual));checks['holdout_frequency_grid']=holdout<.002
    profile=dict(schema='hrg_piezo_identification_v1',status='synthetic_identification_only',
        reference_boundary='intrinsic mechanical poles at short-circuit sensing boundary; fixture deembedded',
        electrical=est,physical=physical,physical_calibration='synthetic independent charge/LDV fixture',
        bryan_factor=None,drive_voltage_limit_V=None,displacement_limit_m=None)
    HERE.mkdir(parents=True,exist_ok=True)
    save=lambda name,v:(HERE/name).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    save('identified_profile.json',profile);save('identification_results.json',dict(checks=checks,relative_errors=errors,holdout_relative_error=holdout))
    np.savetxt(HERE/'sweep_fixture.csv',np.column_stack([f,Y.real,Y.imag,X.real,X.imag]),delimiter=',',header='f_Hz,Y_real,Y_imag,Ycross_real,Ycross_imag',comments='')
    assert all(checks.values());print('5 synthetic identification checks passed',errors)
if __name__=='__main__':main()
