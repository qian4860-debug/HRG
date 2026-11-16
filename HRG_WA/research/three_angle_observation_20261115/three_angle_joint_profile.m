function profile = three_angle_joint_profile()
% 读取在开环拟合试验中预先指定并冻结的组合系数。
reportName = fullfile(fileparts(mfilename('fullpath')),'joint_bleed_shape.json');
assert(isfile(reportName),'Run the joint bleed and shape fit before building the native models.');
report = jsondecode(fileread(reportName));
candidate = report.candidate;
profile = struct('source','joint_bleed_shape.json', ...
    'method',candidate.method,'bleed_R_ohm',candidate.bleed_Ohm, ...
    'coeffs',candidate.correction_coefficients(:),'taus_s',candidate.tau_s(:), ...
    'coefficient_order',{candidate.coefficient_order});
end
