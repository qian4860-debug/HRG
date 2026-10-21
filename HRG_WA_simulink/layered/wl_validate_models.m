function report=wl_validate_models()
root=fileparts(mfilename('fullpath'));addpath(root);checks=struct('name',{},'value',{},'limit',{},'pass',{});
for stage=2:6
 c=wl_config(stage);c.duration=.3;
 [out,c]=wl_sim(c,true);m=wl_metrics(out,c);
 check(sprintf('v%d_nonfinite',stage),double(~m.finite),0);
 check(sprintf('v%d_invalid_fraction',stage),1-m.validFraction,.1);
 check(sprintf('v%d_rate_tracking_mean_dps',stage),abs(m.rateMeanErrorDegS),.25);
 check(sprintf('v%d_quadrature_ratio',stage),m.quadratureRatioRms,.05);
 check(sprintf('v%d_ADC_clipping',stage),m.adcClipFraction,0);
 wl_save_evidence(out,c,sprintf('v%d_nominal',stage));
 if stage==3,referenceIQ=out.tap_iq.Data;referenceNavigation=out.tap_navigation.Data;end
 scopes=find_system(c.name,'LookUnderMasks','all','BlockType','Scope');
 spectra=find_system(c.name,'LookUnderMasks','all','RegExp','on','Name','^Spectrum_(?!Channel).*');
 check(sprintf('v%d_missing_scope_nodes',stage),max(0,15-numel(scopes)),0);
 check(sprintf('v%d_missing_spectrum_nodes',stage),max(0,10-numel(spectra)),0);
 close_system(c.name,0);
end
% Library observation instruments must not alter the simulated closed loop.
c=wl_config(3);c.duration=.3;c.observers=false;c.spectra=false;
[out,c]=wl_sim(c,true);
check('instrumentation_IQ_nonintrusive',max(abs(out.tap_iq.Data(:)-referenceIQ(:))),1e-10);
check('instrumentation_navigation_nonintrusive',max(abs(out.tap_navigation.Data(:)-referenceNavigation(:))),1e-10);
close_system(c.name,0);
% Restore the delivered interactive model with its library instruments.
wl_build(wl_config(3));close_system(c.name,0);
% Independent full carrier matrix-exponential oracle with all actuation off.
c=wl_config(2);c.head.loopEnable=0;c.duration=.06;c.name='hrg_wa_v2_free';c.observers=false;c.spectra=false;
[out,c]=wl_sim(c,true);x0=[evalin('base','wl_q0');evalin('base','wl_v0')];
w=2*pi*c.head.f0;J=[0 -1;1 0];D=2*c.head.gamma*eye(2)+4*c.head.bryan*c.inputRate*J;
A=[zeros(2) eye(2);-w*w*eye(2) -D];expected=expm(A*c.duration)*x0;
actual=[out.tap_head_displacement.Data(end,:).';out.tap_head_velocity.Data(end,:).'];
scale=[1;1;1/w;1/w];check('library_mechanical_expm',norm(scale.*(actual-expected))/norm(scale.*expected),.002);
close_system(c.name,0);
% Actual ADC overrange propagates through contamination windows to control/nav.
c=wl_config(4);c.name='hrg_wa_v4_overrange';c.adcFsV=.03;c.duration=.08;c.observers=false;c.spectra=false;
[out,c]=wl_sim(c,true);m=wl_metrics(out,c);check('overrange_not_detected',double(m.validFraction>.25),0);
check('overrange_nonfinite',double(~m.finite),0);close_system(c.name,0);
% Actual 1-bit ADC and DAC reference loops; no Gaussian substitute for bitstream.
c=wl_config(4);c.name='hrg_wa_v4_bitstream';c.duration=.04;c.adcArchitecture='sigma_delta';c.dacArchitecture='sigma_delta';
c.fsAdc=160000;c.fsPlant=640000;c.observers=false;c.spectra=false;c.maxLogPoints=80000;
[out,c]=wl_sim(c,true);
% Conversion latency is initialized to zero, which is not a converter code.
a=out.tap_adc.Data(out.tap_adc.Time>=c.adcDelay/c.fsAdc,:);
d=out.tap_dac.Data(out.tap_dac.Time>=c.dacDelay/c.fsAdc,:);
check('ADC_bitstream_nonbinary',max(min(abs(a(:)-c.sdmReferenceV),abs(a(:)+c.sdmReferenceV))),eps);
check('DAC_bitstream_nonbinary',max(min(abs(d(:)-c.sdmReferenceV),abs(d(:)+c.sdmReferenceV))),eps);
check('bitstream_model_nonfinite',double(any(~isfinite(out.tap_head_displacement.Data(:)))),0);
wl_save_evidence(out,c,'bitstream_reference');close_system(c.name,0);
report=struct('checks',checks,'pass',all([checks.pass]), ...
 'scope','Circuit closure/causality/library instruments. Short-run functional limits, not product noise signoff.');
wl_write_json(fullfile(root,'evidence','model_scoreboards.json'),report);
assert(report.pass,'Layered model scoreboard failed');
fprintf('PASS %d layered model scoreboards.\n',numel(checks));
    function check(name,value,limit)
     ok=isfinite(value)&&value<=limit;checks(end+1)=struct('name',name,'value',value,'limit',limit,'pass',ok);
     fprintf('%s %.9g <= %.9g : %d\n',name,value,limit,ok);
    end
end
