function result=p102_verify()
root=p102_setup;p=p101_config;c=p101_calibration;checks=struct;cases=struct;
mdl=p102_build(p,c);modelpath=fullfile(root,'models',[mdl '.slx']);
addpath(fullfile(root,'models'));
for k=1:3
 q=p;if k==2,q.noise_rms_V=5e-6;elseif k==3,q.split_hz=.01;q.damping_half_difference=.002;q.stiffness_axis=.61;q.damping_axis=-.29;end
 mw=get_param(mdl,'ModelWorkspace');assignin(mw,'p',q);[Ad,Bd,x0]=p101_plant(q);assignin(mw,'Ad',Ad);assignin(mw,'Bd',Bd);assignin(mw,'x0',x0);
 r=p101_reference(q,c);out=sim(mdl);actual=out.p102_states.Data;
 scale=max(max(abs(r.x),[],1),1e-15);xe=max(abs(actual-r.x)./scale,[],'all');
 ue=max(abs(out.p102_dac.Data-r.u),[],'all');ae=max(abs(out.p102_adc.Data-r.adc),[],'all');
 d=out.p102_diagnostics.Data;finite=isfinite(d)&isfinite(r.d);
 de=max(abs(d(finite)-r.d(finite)));sameNaN=isequal(isnan(d),isnan(r.d));
 checks.(['case' num2str(k) '_normalized_states'])=xe<1e-7;
 checks.(['case' num2str(k) '_DAC_scoreboard'])=ue<1e-12;
 checks.(['case' num2str(k) '_ADC_scoreboard'])=ae<1e-12;
 checks.(['case' num2str(k) '_diagnostics'])=de<1e-9&&sameNaN;
 cases.(['case' num2str(k)])=struct('state_error',xe,'dac_error',ue,'adc_error',ae,'diagnostic_error',de,'metrics',p101_metrics(r,q));
end
close_system(mdl,0);load_system(modelpath);set_param(mdl,'SimulationCommand','update');checks.saved_baseline_reopens=true;
parts=find_system([mdl '/Piezo_Head_and_Circuits'],'SearchDepth',1,'BlockType','SubSystem');
parts=setdiff(parts,{[mdl '/Piezo_Head_and_Circuits']});
checks.five_linked_physical_partitions=numel(parts)==5&&all(cellfun(@(s)startsWith(get_param(s,'ReferenceBlock'),'hrg_wa_v10_2_modules/'),parts));
checks.no_monolithic_state_space=isempty(find_system(mdl,'LookUnderMasks','all','BlockType','DiscreteStateSpace'));
checks.fourteen_scopes=numel(find_system(mdl,'LookUnderMasks','all','BlockType','Scope'))==14;
close_system(mdl,0);
bp=p;bp.duration=.03;bench=p102_build(bp,c,true);out=sim(bench);mw=get_param(bench,'ModelWorkspace');u=evalin(mw,'bench_input');
[Ad,Bd,x]=p101_plant(bp);expected=zeros(size(u,1),12);
for k=1:size(u,1),expected(k,:)=x';x=Ad*x+Bd*u(k,2:3)';end
err=max(abs(out.p102_states.Data-expected)./max(max(abs(expected),[],1),1e-15),[],'all');
checks.independent_open_port_stimulus=err<1e-8;
close_system(bench,0);load_system(fullfile(root,'models',[bench '.slx']));set_param(bench,'SimulationCommand','update');checks.port_bench_reopens=true;
result=struct('checks',checks,'cases',cases,'port_bench_normalized_error',err,'scope','Structural equivalence to sealed V10.1, not a new physical accuracy claim');
p101_json(fullfile(root,'evidence','results.json'),result);disp(result);disp(checks);
assert(all(structfun(@logical,checks)),'V10.2 structural scoreboard failed');
load_system(modelpath);print(['-s' mdl],'-dpng','-r120',fullfile(root,'evidence','architecture.png'));
end
