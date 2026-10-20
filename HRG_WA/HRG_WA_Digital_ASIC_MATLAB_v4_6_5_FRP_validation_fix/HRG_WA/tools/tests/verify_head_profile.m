function verify_head_profile()
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fileparts(root));
addpath(fullfile(root,'generated','nominal_unmeasured'));
[p,u]=hrg_head_params('rtl');
assert(p.res.f0==5000 && p.res.Q==2e6 && p.res.bryan==.277);
assert(abs(p.res.meanDamping-pi*5000/2e6)<1e-14);
assert(p.sim.fsAdc==40000 && p.sim.fsCtrl==1000 && p.sim.samplesPerCtrl==40);
assert(p.ctrl.energyKp==2.4 && p.ctrl.energyKi==.35);
assert(p.ctrl.energyLimit==.55 && p.ctrl.quadLimit==.45);
assert(p.asic.bitTrueEnable && ~p.kalman.enable && ~p.frp.enable && ~p.calib.enable);
assert(~p.comp.enableHarmonic && ~p.comp.enableTemperature);
assert(p.head.spiWords(7)==uint32(hex2dec('20000000')));
assert(p.head.energyHold==65884/2^22);
assert(isequal(p.afe.crossMatrix,[1 .003;-.002 1]));
assert(isequal(size(p.afe.offset),[2 1]) && isequal(size(p.dac.gain),[3 1]));
fprintf('GENERATED_MATLAB_HEAD_PROFILE_PASS\n');
end
