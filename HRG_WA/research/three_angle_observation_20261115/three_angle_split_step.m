function report=three_angle_split_step(folder)
% 频差突变的恢复代理试验。跨事件保留全部机电状态、反馈命令、驻波角与发布积分。
arguments
    folder (1,:) char=fileparts(mfilename('fullpath'))
end
addpath(fullfile(folder,'..','three_mode_split_20261113'));
cal=jsondecode(fileread(fullfile(folder,'split_bias_verification.json')));
rows={}; stepTime=5; refreshDelay=.5; total=15;
for m=1:numel(cal.modes)
    mode=cal.modes(m).mode; tables=cal.modes(m).calibration_rad_s;
    % 真值只在生成物理工况及离线误差评分时使用。读数刷新时刻由外部触发给定。
    conditions=[.05 .05 0;.05 .025 0;.025 .05 0;.05 .025 .0003;.05 .025 -.0003];
    for j=1:size(conditions,1)
        from=conditions(j,1); to=conditions(j,2); rate=conditions(j,3);
        c=config(mode,rate,from,stepTime); L=three_angle_frame_lift(c);dt=L.T;
        % 多算一帧，仅用于取得事件时刻尚未执行该帧驱动的 x 和 u。
        c.duration=stepTime+dt; before=three_angle_lift_run(c,L);
        d=config(mode,rate,to,total-stepTime); d.x0=before.trace(end,1:c.stateCount)';
        d.startCommand=before.trace(end,c.stateCount+(1:4))';
        after=three_angle_lift_run(d,three_angle_frame_lift(d));
        a=[before.angleCandidates(1:end-1,:);after.angleCandidates];
        assert(all(a(:,5:8)==1,'all') && before.rail_free && after.rail_free);
        az=a(:,4); t=(0:numel(az)-1)'*dt;
        raw=-[0;cumsum(atan2(sin(diff(az)),cos(diff(az))))]/(4*c.B);
        [stale,oldBias]=split_bias_angle(az,raw,dt,tables,from);
        [~,newBias]=split_bias_angle(az,raw,dt,tables,to);
        bias=oldBias; refreshed=t>=stepTime+refreshDelay; bias(refreshed)=newBias(refreshed);
        updated=raw-[0;cumsum(bias(1:end-1))*dt]; angles=[raw stale updated];
        seamError=NaN;
        if from==to
            c.duration=total; one=three_angle_lift_run(c,L);
            seamError=max(abs(raw-one.angleCandidates(:,9)));assert(seamError<1e-9);
        end
        % 0.5秒非重叠窗；恢复定义为连续两个合格窗结束，报告确认时刻距阶跃时长。
        width=round(.5/dt);start=round(stepTime/dt)+1; count=floor((size(angles,1)-start+1)/width);
        errors=zeros(count,3); windowT=t(1:width);center=windowT-mean(windowT);
        for w=1:count
            ix=start+(w-1)*width+(0:width-1);
            errors(w,:)=1000*(center'*angles(ix,:)/(center'*center)-rate);
        end
        passed=abs(errors)<=.25; recovery=nan(1,3); fraction=mean(passed,1);
        for k=1:3
            second=find(passed(2:end,k)&passed(1:end-1,k),1)+1;
            if ~isempty(second),recovery(k)=second*width*dt;end
        end
        rows{end+1}=struct('mode',mode,'before_Hz',from,'after_Hz',to,'rate_rad_s',rate, ...
            'seam_baseline_max_delta_rad',seamError,'post_step_error_mrad_s',errors, ...
            'confirmed_recovery_s',recovery,'fraction_passing_windows',fraction); %#ok<AGROW>
    end
end
report=struct('scope','synthetic frequency split step, constant other head parameters', ...
    'step_s',stepTime,'duration_s',total,'refresh_delay_assumed_s',refreshDelay,'window_s',.5, ...
    'consecutive_windows_required',2,'method_order',{{'raw','stale','refresh'}},'cases',[rows{:}]);
fid=fopen(fullfile(folder,'split_step_recovery.json'),'w','n','UTF-8');assert(fid>=0);
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
end

function c=config(mode,rate,split,duration)
c=three_mode_split_config(mode,rate,split,28.125,duration,40,struct('Cs',720e-12, ...
    'bleed_R',1/(720e-12/2e-6-1e-10),'dac_bits',40));c.periodicCarrier=true;
end
