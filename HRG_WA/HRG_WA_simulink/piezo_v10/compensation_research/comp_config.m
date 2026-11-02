function p=comp_config(p)
if nargin<1,comp_setup;p=pcn_config;end
p.heading_start_s=0;p.zero_start_force=true;
p.enable_tensor_ff=false;p.identified_dK=zeros(2);p.identified_dD=zeros(2);
end
