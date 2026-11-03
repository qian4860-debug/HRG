function report=a3_demo()
% 只读显示封存结果，图窗保留；重算入口见07号说明。
root=fileparts(mfilename('fullpath'));report=jsondecode(fileread(fullfile(root,'evidence','scores.json')));
disp(report.summary);figure('Name','A3 参考帧协方差与重锚定','NumberTitle','off','Color','w');
image(imread(fullfile(root,'evidence','a3_dashboard.png')));axis image off;
fprintf('打开模型：open_system(''%s'')\n',fullfile(root,'models','hrg_wa_a3_reference_manager.slx'));
end
