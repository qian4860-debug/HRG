function report=same_head_pause_test(project,folder)
% 同一表头的停驱测频。直接取分时闭环 C/V 解调量，保留所有机电状态和反馈寄存器。
% 可观测量为两路 C/V 的 I/Q。机械频差及机体速率只用于构造试验和离线统计。
arguments
    project (1,:) char=fileparts(fileparts(fileparts(mfilename('fullpath'))))
    folder (1,:) char=fileparts(mfilename('fullpath'))
end
old=fullfile(project,'research','three_angle_observation_20261115');
addpath(old,fullfile(project,'research','three_mode_split_20261113'),fullfile(project,'research','split_estimation_20261119'));
model='hrg_same_head_pause';
assert(~bdIsLoaded(model),'请先关闭同名模型后再重建。');
build_model(model,old,folder); closeModel=onCleanup(@()close_system(model,0)); %#ok<NASGU>
rows={}; start=1; configs=[0 0;25 0;50 0;50 -.3;50 .3];
for mode=["tdm_shared","tdm_separate"]
    for k=1:size(configs,1)
        split=configs(k,1); rate=configs(k,2);
        c=three_mode_split_config(mode,rate/1000,split/1000,28.125,5,40, ...
            struct('Cs',720e-12,'bleed_R',1/(720e-12/2e-6-1e-10),'dac_bits',40));
        c.periodicCarrier=true; L=three_angle_frame_lift(c);
        for trial=[0 0;.5 0;.5 1;1 0;1 1;1.5 0;1.5 1]'
            width=trial(1); limited=trial(2);
            simIn=Simulink.SimulationInput(model);
            for var=["c","L","pauseStart","pauseWidth","useLimiter"]
                switch var
                    case "c", val=c;
                    case "L", val=L;
                    case "pauseStart", val=start;
                    case "pauseWidth", val=width;
                    case "useLimiter", val=limited;
                end
                simIn=simIn.setVariable(char(var),val,'Workspace',model);
            end
            out=sim(simIn); a=out.liftTrace; n=c.stateCount; t=(0:size(a,1)-1)'*L.T;
            assert(size(a,1)==round(5/L.T)); u=a(:,n+(1:4)); cv=a(:,n+(5:8));
            iq=complex(cv(:,1:2),cv(:,3:4)); e=sum(abs(iq).^2,2);
            h=abs(iq(:,1)).^2-abs(iq(:,2)).^2+1i*2*real(iq(:,1).*conj(iq(:,2)));
            valid=e>=c.minEnergy & abs(h)>=c.minLinearity*e;
            if width==0
                main=three_angle_lift_run(c,L); delta=max(abs(main.trace-a),[],'all');
                assert(delta<1e-7 && main.rail_free); base=a; baseh=h; baseiq=iq;
                continue
            end
            first=round(start/L.T)+1; last=round((start+width)/L.T);
            assert(isequal(a(1:first-1,:),base(1:first-1,:)) && all(u(first:last,:)==0,'all'));
            assert(any(u(last+1,:)~=0) && all(isfinite(a),'all'));
            % 用已知的有效窗投影逐拍复算停驱、复驱两段的 C/V 峰值，防止饱和被线性模型隐藏。
            peak=0;
            for j=1:256:size(a,1)
                seg=a(j:min(j+255,end),1:n+4); peak=max(peak,max(abs(L.cvMap*seg'),[],'all'));
            end
            drive=max(hypot(u(:,1:2),u(:,3:4)),[],'all');
            rail=peak<min(c.adcMax,-c.adcMin) && drive<min(c.dacMax,-c.dacMin);
            % 在停驱期仅用已经取得的复基带，每8帧取一个样本；固定噪声只加到测频回放入口。
            ix=first:8:last; tt=t(ix)-t(first);
            rs=RandStream('mt19937ar','Seed',731);
            noise=10^(-46/20)/sqrt(2)*(randn(rs,numel(ix),2)+1i*randn(rs,numel(ix),2));
            quiet=estimate_ringdown_split(tt,iq(ix,:));
            noisy=estimate_ringdown_split(tt,iq(ix,:)+noise);
            driven=estimate_ringdown_split(tt,baseiq(ix,:)+noise);
            % 机体等效角以共同的停驱前状态为锚，相对原闭环比较。限制为未失锁、未超量程轨迹。
            dtheta=-(unwrap(angle(h))-unwrap(angle(baseh)))/(4*c.B);
            post=last+(1:round(1/L.T)); x=t(post)-mean(t(post));
            cost=1000*max(abs(dtheta)); drift=1000*(x'*dtheta(post))/(x'*x);
            if ~all(valid) || ~rail, cost=NaN; drift=NaN; end
            row=struct('mode',mode,'split_mHz',split,'truth_rate_mrad_s',rate,'pause_s',width,'limited',limited, ...
                'duration_s',c.duration,'frames',numel(t),'valid_fraction',mean(valid),'rail_free',rail, ...
                'cv_peak_V',peak,'dac_peak_V',drive,'baseline_delta',delta, ...
                'dac_limit_V',min(c.dacMax,-c.dacMin),'adc_limit_V',min(c.adcMax,-c.adcMin), ...
                'end_to_start_amp_ratio',sqrt(e(last)/e(first)), ...
                'peak_body_delta_mrad',cost,'post_1s_delta_slope_mrad_s',drift, ...
                'quiet',quiet,'noisy',noisy,'drive_on_noisy',driven);
            rows{end+1}=row; %#ok<AGROW>
        end
    end
end
report=struct('scope','unquantized same-head native force blanking, frozen mode axes; optional noise on estimator input only', ...
    'start_s',start,'baseline_angle_deg',28.125,'rows',[rows{:}]);
fid=fopen(fullfile(folder,'same_head_pause.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
end

function build_model(model,old,folder)
% 复用已经对拍的原生提升模型；在所有驱动到机电/读出的路径上插入同一个实际命令开关。
template='hrg_lift_tdm_shared';
assert(~bdIsLoaded(template),'请关闭已打开的模板后重建。');
load_system(fullfile(old,'lift_models',[template '.slx']));
save_system(template,fullfile(folder,[model '.slx']));
if bdIsLoaded(template), close_system(template,0); end
ws=get_param(model,'ModelWorkspace'); c=ws.getVariable('c'); c.duration=5; ws.assignin('c',c);
ws.assignin('pauseStart',1); ws.assignin('pauseWidth',.5); ws.assignin('useLimiter',1);
add_block('simulink/Sources/Step',[model '/Pause start'],'Time','pauseStart','Before','0','After','1','SampleTime','L.T');
add_block('simulink/Sources/Step',[model '/Pause end'],'Time','pauseStart+pauseWidth','Before','0','After','1','SampleTime','L.T');
add_block('simulink/Math Operations/Sum',[model '/During pause'],'Inputs','+-');
add_block('simulink/Sources/Constant',[model '/Zero command'],'Value','zeros(4,1)');
add_block('simulink/Signal Routing/Switch',[model '/Applied drive'],'Threshold','0.5');
for target=["Gu/1","Jc/1","Jm/1","Trace/2"]
    delete_line(model,'Control/1',char(target));
    add_line(model,'Applied drive/1',char(target),'autorouting','on');
end
% 用四分量向量范数约束两路载波包络，统一缩放保留命令相位和通道比例。
add_block('simulink/Math Operations/Dot Product',[model '/Squared command']);
add_block('simulink/Math Operations/Sqrt',[model '/Command norm']);
add_block('simulink/Sources/Constant',[model '/Envelope budget'],'Value','0.9*min(c.dacMax,-c.dacMin)');
add_block('simulink/Math Operations/MinMax',[model '/Denominator'],'Function','max','Inputs','2');
add_block('simulink/Math Operations/Product',[model '/Scale'],'Inputs','*/');
add_block('simulink/Math Operations/Product',[model '/Scaled drive']);
add_block('simulink/Sources/Constant',[model '/Limit enabled'],'Value','useLimiter');
add_block('simulink/Math Operations/Product',[model '/Limit after event']);
add_block('simulink/Signal Routing/Switch',[model '/Restore drive'],'Threshold','0.5');
w('Control/1','Squared command/1'); w('Control/1','Squared command/2'); w('Squared command/1','Command norm/1');
w('Envelope budget/1','Denominator/1'); w('Command norm/1','Denominator/2');
w('Envelope budget/1','Scale/1'); w('Denominator/1','Scale/2');
w('Control/1','Scaled drive/1'); w('Scale/1','Scaled drive/2');
w('Limit enabled/1','Limit after event/1'); w('Pause start/1','Limit after event/2');
w('Scaled drive/1','Restore drive/1'); w('Limit after event/1','Restore drive/2');
w('Control/1','Restore drive/3'); w('Restore drive/1','Applied drive/3');
add_line(model,'Zero command/1','Applied drive/1','autorouting','on');
add_line(model,'Pause start/1','During pause/1','autorouting','on');
add_line(model,'Pause end/1','During pause/2','autorouting','on');
add_line(model,'During pause/1','Applied drive/2','autorouting','on');
add_block('simulink/Sinks/Scope',[model '/CV and pause'],'NumInputPorts','2');
add_line(model,'Estimate/1','CV and pause/1','autorouting','on');
add_line(model,'During pause/1','CV and pause/2','autorouting','on');
set_param([model '/Applied drive'],'Description','停驱窗内施加四路零命令；反馈继续更新。停止窗口以外使用当前反馈命令。');
Simulink.BlockDiagram.arrangeSystem(model);
save_system(model);
    function w(src,dst)
        add_line(model,src,dst,'autorouting','on');
    end
end
