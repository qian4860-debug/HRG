function HRG_WA_print_metrics(m)
% HRG_WA_PRINT_METRICS  Pretty-print performance metrics.

fprintf('\n================ ASIC/FPGA interface simulation metrics ================\n');
fprintf('Final input angle          : %10.3f deg\n', m.finalInputAngleDeg);
fprintf('Final output angle         : %10.3f deg\n', m.finalOutputAngleDeg);
fprintf('Final angle error          : %10.5f deg\n', m.finalAngleErrorDeg);
fprintf('RMS angle error            : %10.5f deg\n', m.rmsAngleErrorDeg);
fprintf('RMS rate error             : %10.5f deg/s\n', m.rmsRateErrorDps);
fprintf('Max abs rate error         : %10.5f deg/s\n', m.maxAbsRateErrorDps);
if isfield(m,'maxAbsRateErrorAllDps')
    fprintf('Max abs rate error all     : %10.5f deg/s\n', m.maxAbsRateErrorAllDps);
end
fprintf('Mean E                     : %10.6f\n', m.meanE);
fprintf('Std E                      : %10.6g\n', m.stdE);
fprintf('Max |Q|                    : %10.6g\n', m.maxAbsQ);
fprintf('Lock time                  : %10.3f s\n', m.lockTime);
fprintf('Zero-rate bias             : %10.6f deg/s\n', m.zeroRateBiasDps);
fprintf('Zero-rate noise std        : %10.6f deg/s\n', m.zeroRateNoiseStdDps);
fprintf('Min Allan deviation        : %10.6f deg/s\n', m.minAllanDps);
fprintf('ADC saturation count       : %10d\n', m.adcSatCount);
fprintf('DAC saturation count       : %10d\n', m.dacSatCount);
fprintf('Fixed-point sat count      : %10d\n', m.fxSatCount);
fprintf('Angle jump count           : %10d\n', m.angleJumpCount);
fprintf('E fault count              : %10d\n', m.EFaultCount);
fprintf('Q fault count              : %10d\n', m.QFaultCount);
fprintf('Data-ready count           : %10d\n', m.dataReadyCount);
fprintf('Final status word          : 0x%08X\n', m.finalStatusWord);
fprintf('PASS angle RMS             : %d\n', m.passAngleRms);
fprintf('PASS rate RMS              : %d\n', m.passRateRms);
fprintf('PASS energy                : %d\n', m.passEnergy);
fprintf('PASS quadrature            : %d\n', m.passQuadrature);
fprintf('PASS ADC saturation        : %d\n', m.passAdcSat);
fprintf('PASS DAC saturation        : %d\n', m.passDacSat);
fprintf('PASS ALL                   : %d\n', m.passAll);
fprintf('=======================================================================\n\n');
end
