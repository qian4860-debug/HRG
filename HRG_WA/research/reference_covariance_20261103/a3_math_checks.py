"""独立移位核Gram矩阵核对相关和公式；准备MATLAB线性白噪声试验输入。"""
import numpy as np
from a3_common import HERE,config,read_json,write_json,CausalFrontend,orientation
from a3_covariance import KernelBank,projection,covariance
from a3_source import stream


def prepare():
    data=read_json(HERE/'data/observations/case_005.json');records=[];maximum=0.
    for window in [40,240]:
        cfg=config(window);t,u,y,_=stream(data,cfg,False);front=CausalFrontend(data['calibration'],cfg)
        sig=front.process(u,y);idx=np.arange(0,len(t),cfg['frame_decimation']);tf=t[idx]
        metric=orientation(sig['envelope'][idx],data['calibration']['W']);c,psi=projection(metric,data['calibration'],tf,cfg)
        bank=KernelBank(front.coefficients,cfg);selected=np.array([250,251,256,270,350,450]);sample=idx[selected]
        variance=np.full(2,data['stream_noise_RMS_V']**2)
        predicted=np.array([[covariance(bank,c,psi,idx,variance,int(i),int(j)) for j in selected] for i in selected])
        # 另一种实现：每一帧直接构造对同一段白噪声的线性权重，再相乘。
        width=int(max(sample))+1;weights=np.zeros((len(selected),2*width))
        for row,index in enumerate(selected):
            for j,kernel in enumerate(bank.kernels):
                count=min(len(kernel),int(idx[index])+1);lag=np.arange(count)
                beta=2*c[index,j]*np.real(np.exp(-1j*psi[index])*kernel[:count])
                weights[row,j*width+idx[index]-lag]=np.sqrt(variance[j])*beta
        direct=weights@weights.T
        error=float(np.linalg.norm(predicted-direct)/np.linalg.norm(direct));maximum=max(maximum,error)
        assert error<1e-7 and np.min(np.linalg.eigvalsh(predicted))>-1e-18
        relative=np.maximum(0,np.diag(predicted)+predicted[0,0]-2*predicted[:,0])
        records.append(dict(window_samples=window,sample_rate_Hz=cfg['sample_rate_Hz'],carrier_Hz=cfg['carrier_Hz'],
            inverse_sos=front.coefficients['inverse_sos'],sample_indices=sample.tolist(),projection_sensitivity=c[selected].tolist(),
            projection_phase_phi=metric['phase'][selected].tolist(),noise_sigma_V=data['stream_noise_RMS_V'],
            expected_covariance=predicted.tolist(),expected_relative_variance=relative.tolist(),gram_relative_difference=error))
    # 原始参考更差时，重锚定把旧offset当精确值会低估误差。
    original,anchor,current=4e-6,1e-6,1e-6
    offset=anchor+original;local=current+anchor;cross=-anchor
    correct=offset+local+2*cross;assert np.isclose(correct,current+original)
    result=dict(maximum_shifted_kernel_Gram_relative_difference=maximum,
        retained_origin_variance_example=dict(original=original,anchor=anchor,current=current,
            correct_global=correct,incorrect_drop_offset=local,incorrect_zero_anchor=current))
    write_json(HERE/'evidence/math_checks.json',result)
    write_json(HERE/'evidence/matlab_covariance_input.json',dict(cases=records,monte_carlo_trials=512,seed=18819))
    return result


if __name__=='__main__':print(prepare())
