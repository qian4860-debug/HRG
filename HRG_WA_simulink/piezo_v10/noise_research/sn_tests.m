function result=sn_tests()
root=sn_setup;p=comp_config;p.enable_iq_estimator=true;s=sn_state('unpack',sn_state('init',p));q=p.charge_target;worst=0;
for k=1:64
 s.k=20000+40*k;z=q*[.98+.0001*k+1i*.0002;.1-1i*.0001];[s,out]=sn_smooth(s,z,p,1,false);
 if k>=3,worst=max(worst,max(abs(out-z))/q);end
end
checks.linear_endpoint_no_delay=worst<1e-12;
[s,~]=sn_smooth(s,q*[1;-1i],p,1,false);checks.circular_input_resets_history=s.raw_valid==0&&s.history_count==0;
[s,~]=sn_smooth(s,q*[1;0],p,1,true);checks.clip_resets_history=s.raw_valid==0&&s.history_count==0;
s.k=10;z=q*[1;.1];[s,out]=sn_smooth(s,z,p,1,false);checks.startup_bypass=isequal(out,z);
result=struct('checks',checks,'linear_max_relative_error',worst);pcn_json(fullfile(root,'evidence','filter_tests.json'),result);disp(checks);assert(all(structfun(@logical,checks)));
end
