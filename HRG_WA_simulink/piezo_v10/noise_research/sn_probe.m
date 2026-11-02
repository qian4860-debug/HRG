function result=sn_probe()
root=sn_setup;profiles=jsondecode(fileread(fullfile(fileparts(root),'compensation_research','independent_profiles.json')));v=profiles.noise_500u;
p=comp_config;p.noise_rms_V=500e-6;p.enable_iq_estimator=true;p.enable_tensor_ff=true;p.identified_dK=v.dK;p.identified_dD=v.dD;
c=pcn_calibration;c.detect=v.detect_real+1i*v.detect_imag;c.drive=v.drive_real+1i*v.drive_imag;
r=sn_reference(p,c);result=pcn_metrics(r,p);if ~exist(fullfile(root,'evidence'),'dir'),mkdir(fullfile(root,'evidence'));end
pcn_json(fullfile(root,'evidence','probe.json'),result);disp(result);
end
