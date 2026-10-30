function result=p101_run_all()
% Python fixtures must be generated first; run_all.py automates both runtimes.
result.discretization=p101_verify_discretization;
result.contracts=p101_verify_contracts;
result.measurement=p101_verify_measurement;
result.research=p101_verify_research;
result.temperature=p101_verify_temperature;
root=fileparts(mfilename('fullpath'));p101_json(fullfile(root,'evidence','matlab_all_results.json'),result);
disp('PASS: V10.1 MATLAB/Simulink suites');
end
