function report=a1_demo()
% 只读查看已封存的结果；不重算、不改证据，关闭图窗由用户决定。
root=fileparts(mfilename('fullpath'));report=jsondecode(fileread(fullfile(root,'evidence','scores.json')));
disp(report.summary);
for file={'a1_dashboard.png','simulink_waveforms.png'}
 figure('Name',file{1},'NumberTitle','off','Color','w');
 image(imread(fullfile(root,'evidence',file{1})));axis image off;
end
fprintf('打开模型：open_system(''%s'')\n',fullfile(root,'models','hrg_wa_a1_port_deembedding.slx'));
end
