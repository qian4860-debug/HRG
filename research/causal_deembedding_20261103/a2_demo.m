function report=a2_demo()
% 只读展示已归档图表和模型位置，保留图窗，不重写封存证据。
root=fileparts(mfilename('fullpath'));report=jsondecode(fileread(fullfile(root,'evidence','scores.json')));
disp(report.summary);figure('Name','A2 因果去嵌与噪声延迟预算','NumberTitle','off','Color','w');
image(imread(fullfile(root,'evidence','a2_dashboard.png')));axis image off;
fprintf('打开模型：open_system(''%s'')\n',fullfile(root,'models','hrg_wa_a2_causal_frontend.slx'));
end
