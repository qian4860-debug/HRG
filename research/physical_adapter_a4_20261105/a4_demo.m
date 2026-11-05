function result=a4_demo
% 只读展示；不重建已封存模型或证据。
root=a4_setup;result=jsondecode(fileread(fullfile(root,'evidence','results.json')));
disp(result);figure('Name','A4物理适配与最小旋转闭环','NumberTitle','off');
image(imread(fullfile(root,'evidence','a4_dashboard.png')));axis image off;
fprintf('原生模型：%s\n',fullfile(root,'models','hrg_wa_a4_physical_adapter.slx'));
end
