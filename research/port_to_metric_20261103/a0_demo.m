function report=a0_demo()
% A0只读查看入口：显示已归档核对结果；图窗保留，便于检查。
% 不重建图片、不改写封存证据、不修改原V10模型；重新核对请调用a0_matlab_check。
root=fileparts(mfilename('fullpath'));
report=jsondecode(fileread(fullfile(root,'evidence','matlab_replay.json')));
figure('Name','A0 输入输出辨识与退化拒绝','NumberTitle','off','Color','w');
image(imread(fullfile(root,'evidence','a0_dashboard.png')));axis image off;
end
