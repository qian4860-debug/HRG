function result = three_angle_load_phasor(outPath)
% 固定窗口的被动端口加载诊断。冻结开关与 DAC，运动电荷相量驱动四组端。
% 坐标为 C、V、s。输出每窗的等效同轴加载和非标量偏差。
arguments
    outPath (1,:) char = fullfile(fileparts(mfilename('fullpath')),'load_phasor.json')
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','three_mode_split_20261113'));
c = three_mode_split_config('tdm_shared',0,.05,22.5,.01,16);
p = c.p;
H = c.portCoupling;
C = c.portCapacitance_F;
ron = c.portOptions.drive_on_resistance_ohm;
% 独立版 A/B 连接驱动器输出阻抗，C/D 持续接 C/V。复用版四组一起换路。
conductance = [1/ron, 1/ron, 1/p.Rs, 1/p.Rs;
               repmat(1/ron,1,4);
               repmat(1/p.bleed_R,1,4);
               repmat(1/p.Rs,1,4)];
names = ["dedicated","shared_drive","shared_bleed","shared_sense"];
rows = struct([]);
for k = 1:numel(names)
    % KCL 给出 v=−(G+jωC)⁻¹jωHq；把反作用移到机械方程左侧。
    G = diag(conductance(k,:)+p.G0);
    loading = p.b*H'*((G+1i*c.w*C)\(1i*c.w*H));
    scalar = trace(loading)/2;
    mismatch = norm(loading-scalar*eye(2),'fro')/norm(loading,'fro');
    % 弱加载近似：幅值衰减率 Im(Kload)/(2ω)，固有频率改变量 Re(Kload)/(4πω)。
    rows = [rows;struct('window',names(k),'non_scalar_fraction',mismatch, ...
        'decay_increment_per_s',imag(scalar)/(2*c.w), ...
        'frequency_increment_mHz',1e3*real(scalar)/(4*pi*c.w))]; %#ok<AGROW>
end
assert(max([rows.non_scalar_fraction])<1e-12 && all([rows.decay_increment_per_s]>0));
result = struct('release',version('-release'),'carrier_Hz',p.f0,'mutual_capacitance_F',p.Cds, ...
    'scope','Nominal frozen-slot small-signal estimate; excludes transitions and periodic memory', ...
    'windows',rows);
if ~isempty(outPath)
    fid = fopen(outPath,'w','n','UTF-8');
    assert(fid>=0,'无法写入固定窗加载的回执。');
    closeOutput = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end
end
