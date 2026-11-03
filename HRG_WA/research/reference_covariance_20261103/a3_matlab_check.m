function report=a3_matlab_check()
% 独立MATLAB白噪声线性试验，以及原生有状态S函数对Python参考管理器。
root=fileparts(mfilename('fullpath'));addpath(root);input=jsondecode(fileread(fullfile(root,'evidence','matlab_covariance_input.json')));
if ~isfolder(fullfile(root,'models')),mkdir(fullfile(root,'models'));end
reports=[];
for c=1:numel(input.cases)
 p=input.cases(c);indices=p.sample_indices(:)+1;N=max(indices);trials=input.monte_carlo_trials;
 rng(input.seed+c,'twister');theta=zeros(numel(indices),trials);t=(0:N-1)'/p.sample_rate_Hz;
 for first=1:64:trials
  count=min(64,trials-first+1);total=zeros(numel(indices),count);
  for j=1:2
   x=p.noise_sigma_V*randn(N,count);
   if iscell(p.inverse_sos),sections=p.inverse_sos{j};else,sections=p.inverse_sos(j,:);end
   for k=1:numel(sections),sec=sections(k);x=filter(sec.b(:)',sec.a(:)',x,[],1);end
   x=x.*(2*exp(-2i*pi*p.carrier_Hz*t));
   for stage=1:2
    accum=[zeros(p.window_samples,count);cumsum(x,1)];
    x=(accum(p.window_samples+1:end,:)-accum(1:end-p.window_samples,:))/p.window_samples;
   end
   total=total+p.projection_sensitivity(:,j).*real(exp(-1i*p.projection_phase_phi(:)).*x(indices,:));
  end
  theta(:,first:first+count-1)=total;
 end
 observed=cov(theta');relative=var(theta-theta(1,:),0,2);expected=p.expected_relative_variance(:);
 ratio=relative(2:end)./expected(2:end);
 covariance_difference=norm(observed-p.expected_covariance,'fro')/norm(p.expected_covariance,'fro');
 assert(covariance_difference<.35 && all(abs(ratio-1)<.35));
 reports=[reports;struct('window_samples',p.window_samples,'trials',trials,...
  'covariance_relative_difference',covariance_difference,'relative_variance_observed_to_predicted',ratio',...
  'scope','独立filter/cumsum对白噪声线性投影协方差；非非线性角度或硬件统计认证')]; %#ok<AGROW>
end
writej(fullfile(root,'evidence','matlab_noise_scoreboard.json'),struct('cases',reports));
% 原生状态机模型：质量/协方差输入来自处理器，S函数实际执行分支、偏置和状态更新。
cfg=jsondecode(fileread(fullfile(root,'config.json')));a2=jsondecode(fileread(fullfile(fileparts(root),'causal_deembedding_20261103','config.json')));
names=fieldnames(a2);for k=1:numel(names),if ~isfield(cfg,names{k}),cfg.(names{k})=a2.(names{k});end,end
cfg.demod_window_samples=240;
cases={'case_005','case_016','case_017','case_019'};labels={'Noise500u','ShortGap','LongGap','InitialGap'};
name='hrg_wa_a3_reference_manager';if bdIsLoaded(name),close_system(name,0);end
load_system('simulink');new_system(name);mws=get_param(name,'ModelWorkspace');assignin(mws,'a3_cfg',cfg);
set_param(name,'SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','.001','StopTime','1.999',...
 'ReturnWorkspaceOutputs','on','InitFcn','addpath(fileparts(fileparts(get_param(bdroot,''FileName''))));');
expected=[];
for k=1:numel(cases)
 v=readmatrix(fullfile(root,'evidence','window_240',[cases{k} '_manager_scoreboard.csv']));
 source=v(:,1:5);
 % From Workspace要求有限输入：仅把未就绪quality的NaN编码为超预算哨兵。
 % 健康标志仍为0，原始CSV和期望输出NaN保留；不把无效角度改成零。
 source(~isfinite(source(:,4)),4)=1e9;assert(all(isfinite(source),'all'));
 assignin(mws,['input_' labels{k}],[(0:size(v,1)-1)'*.001 source]);expected=[expected v(:,6:14)]; %#ok<AGROW>
 add_block('simulink/Sources/From Workspace',[name '/Input_' labels{k}],'VariableName',['input_' labels{k}],...
  'SampleTime','.001','Interpolate','off','OutputAfterFinalValue','Holding final value','Position',[30 140*k 190 140*k+40]);
 add_block('simulink/User-Defined Functions/Level-2 MATLAB S-Function',[name '/Manager_' labels{k}],...
  'FunctionName','a3_reference_sfun','Parameters','a3_cfg','Position',[310 140*k 520 140*k+50]);
 add_line(name,['Input_' labels{k} '/1'],['Manager_' labels{k} '/1'],'autorouting','on');
 add_block('simulink/Sinks/Scope',[name '/Scope_' labels{k}],'OpenAtSimulationStart','off','Position',[870 140*k 1030 140*k+40]);
 add_line(name,['Manager_' labels{k} '/1'],['Scope_' labels{k} '/1'],'autorouting','on');
end
add_block('simulink/Signal Routing/Mux',[name '/All_Managers'],'Inputs','4','ShowName','off','Position',[660 155 665 600]);
for k=1:4,add_line(name,['Manager_' labels{k} '/1'],['All_Managers/' num2str(k)],'autorouting','on');end
add_block('simulink/Sinks/To Workspace',[name '/Log_Managers'],'VariableName','a3_managers','SaveFormat','Timeseries','Position',[870 700 1030 740]);
add_line(name,'All_Managers/1','Log_Managers/1','autorouting','on');
note=Simulink.Annotation(name,sprintf(['A3 参考管理器｜真实DWork状态更新｜非期望结果回放\n'...
 '输入：绝对发布时间、模π角、健康状态、联合噪声预算、延迟通过标志。\n'...
 '输出：全局角、发布角、有效性、锚点数、需外部参考、段号、局部角、重锚事件、原点保留。\n'...
 '协方差由Python处理器计算并另用MATLAB白噪声试验核对，不在S函数内部重算。\n'...
 '模型横轴以首帧发布时间为零；输入的绝对时间保留25us原点偏移。未接AGC/PLL闭环。']));
note.Position=[25 -40];model=fullfile(root,'models',[name '.slx']);save_system(name,model);
out=sim(name);actual=out.a3_managers.Data;
assert(isequal(size(actual),size(expected)) && isequal(isnan(actual),isnan(expected)));
mask=isfinite(expected);difference=max(abs(actual(mask)-expected(mask)));assert(difference<1e-10);
report=struct('frames',size(actual,1),'cases',4,'outputs_per_case',9,'maximum_absolute_difference',difference,'NaN_masks_match',true,...
 'scope','S函数状态机独立实现；不含完整前端/协方差实时成本或控制闭环');
writej(fullfile(root,'evidence','simulink_scoreboard.json'),report);
print(['-s' name],'-dpng','-r120',fullfile(root,'models','a3_structure.png'));close_system(name,0);
fprintf('A3 MATLAB noise covariance and Simulink reference state checks passed; max difference %.5g\n',difference);
end
function writej(path,v)
fid=fopen(path,'w','n','UTF-8');assert(fid>0);cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',jsonencode(v));
end
