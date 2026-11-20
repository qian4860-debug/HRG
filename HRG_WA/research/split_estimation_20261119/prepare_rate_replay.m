function prepare_rate_replay(cacheFolder,project)
% 用第49号两种分时闭环生成机体角和可观测的四倍驻波角。真值只用于激励与评分。
% 中间文件可重建；二进制每帧两个 little-endian double，单位均为 rad。
arguments
    cacheFolder (1,:) char
    project (1,:) char = fileparts(fileparts(fileparts(mfilename('fullpath'))))
end
old=fullfile(project,'research','three_angle_observation_20261115');
addpath(old,fullfile(project,'research','three_mode_split_20261113'));
source=jsondecode(fileread(fullfile(old,'split_bias_verification.json')));
if ~exist(cacheFolder,'dir'), mkdir(cacheFolder); end
catalog={};
for m=1:numel(source.modes)
    mode=source.modes(m).mode;
    for split=[0 25 50 -1]
        for rate=[-1 -.3 0 .3 1]
            % 与旧回执同初角、增益、驱动极点、无限精度近似和有效窗。
            startSplit=split; if split==-1, startSplit=50; end
            c=three_mode_split_config(mode,rate/1000,startSplit/1000,28.125,20,40, ...
                struct('Cs',720e-12,'bleed_R',1/(720e-12/2e-6-1e-10),'dac_bits',40));
            c.periodicCarrier=true; L=three_angle_frame_lift(c);
            if split==-1
                % 阶跃与独立测频支路同在10.25 s。跨段传递真实状态和延迟命令。
                c.duration=10.25+L.T; before=three_angle_lift_run(c,L);
                d=three_mode_split_config(mode,rate/1000,.025,28.125,9.75,40, ...
                    struct('Cs',720e-12,'bleed_R',1/(720e-12/2e-6-1e-10),'dac_bits',40));
                d.periodicCarrier=true; d.x0=before.trace(end,1:c.stateCount)';
                d.startCommand=before.trace(end,c.stateCount+(1:4))';
                s=three_angle_lift_run(d,three_angle_frame_lift(d)); assert(before.rail_free);
                s.angleCandidates=[before.angleCandidates(1:end-1,:);s.angleCandidates];
                z=s.angleCandidates(:,4);
                s.angleCandidates(:,9)=-[0;cumsum(atan2(sin(diff(z)),cos(diff(z))))]/(4*c.B);
            else
                s=three_angle_lift_run(c,L);
            end
            a=s.angleCandidates; assert(s.rail_free && all(a(:,5:8)==1,'all'));
            file=sprintf('%s_%d_%d.bin',mode,split,round(rate*10));
            fid=fopen(fullfile(cacheFolder,file),'w','ieee-le'); assert(fid>=0);
            closer=onCleanup(@() fclose(fid));
            count=fwrite(fid,a(:,[4 9]).','double'); assert(count==size(a,1)*2); clear closer
            catalog{end+1}=struct('file',file,'mode',mode,'split_mHz',split, ...
                'rate_mrad_s',rate,'dt_s',L.T,'frames',size(a,1)); %#ok<AGROW>
        end
    end
    fprintf('Prepared %s\n',mode);
end
fid=fopen(fullfile(cacheFolder,'catalog.json'),'w','n','UTF-8'); assert(fid>=0);
closer=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode([catalog{:}]));
end
