function report=run_all()
% One reproducible entry point: build, simulate, assert, save evidence.
root=fileparts(mfilename('fullpath'));addpath(root);
work=fullfile(root,'_work');if ~isfolder(work),mkdir(work);end
Simulink.fileGenControl('set','CacheFolder',fullfile(work,'cache'), ...
 'CodeGenFolder',fullfile(work,'codegen'),'createDir',true);
build_wa_models();report=run_wa_validation();
end
