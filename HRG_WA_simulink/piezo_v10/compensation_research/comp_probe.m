function result=comp_probe()
root=comp_setup;p=comp_config;c=pcn_calibration;result=struct;
for rate=[0 .5 2 -.5]
 p.Omega=rate;r=comp_reference(p,c);m=pcn_metrics(r,p);result.(matlab.lang.makeValidName(['rate' num2str(rate)]))=m;
end
pcn_json(fullfile(root,'probe.json'),result);disp(result);
end
