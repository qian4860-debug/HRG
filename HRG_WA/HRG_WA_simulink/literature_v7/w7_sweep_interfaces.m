function report=w7_sweep_interfaces()
% Short single-factor sensitivity screen, frozen baseline calibration.
names={'baseline','cv_pole_20pct_low','adc_14_bits','adc_extra_3_samples', ...
 'feedthrough_2fF','switched_baseline','slow_read_20us','switch_charge_2fC','switched_feedthrough_2fF'};
rows=struct('name',{},'metrics',{},'configuration',{});
for k=1:numel(names)
 opt=struct('startupEnable',false);if k>=6,opt.tdmMode='switched';end
 c=w7_config([],opt);c.duration=.08;c.noiseEnable=false;c.observers=false;c.spectra=false;
 switch k
  case 2,c.cvBandwidthHz=c.cvBandwidthHz*.8;
  case 3,c.adcBits=14;
  case 4,c.adcDelay=c.adcDelay+3;
  case 5,c.feedthroughF=2e-15;
  case 7,c.v7.acquisitionTauS=20e-6;
  case 8,c.v7.switchChargeC=[2e-15;-2e-15];
  case 9,c.feedthroughF=2e-15;
 end
 c.name=['hrg_wa_v7_sweep_' num2str(k)];[out,c]=w7_sim(c,false);m=w7_metrics(out,c);
 x=rmfield(c,'legacyP');x.v7.senseCalibration=[real(c.v7.senseCalibration),imag(c.v7.senseCalibration)];
 x.v7.driveCalibration=[real(c.v7.driveCalibration),imag(c.v7.driveCalibration)];
 x.v7.complexEncoding='[real, imaginary]';
 rows(end+1)=struct('name',names{k},'metrics',m,'configuration',x); %#ok<AGROW>
 close_system(c.name,0);
end
report=struct('cases',rows,'finite',all(arrayfun(@(x)x.metrics.finite,rows)), ...
 'scope','80ms single-factor screens, no calibration refit; not steady-state joint PVT qualification');
wl_write_json(fullfile(fileparts(mfilename('fullpath')),'evidence','interface_sweep.json'),report);
assert(report.finite,'Nonfinite interface screen');
end
