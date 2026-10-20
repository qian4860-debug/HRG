function varargout = HRG_WA_v46_advanced(action, varargin)
% HRG_WA V4.6三个独立可开关模块：物理源级FRP、检测相位自校准、驱动非线性实时校正。
switch lower(action)
    case 'init'
        p = varargin{1};
        s.sampleCount = 0;
        s.physical.detTheta = [1 0; 0 1];
        s.physical.detP = repmat(p.advanced.physicalFrp.delta * eye(2), 1, 1, 2);
        s.physical.mechanicalTheta = zeros(4, 1); % [dCos dSin splitCos splitSin]
        s.physical.mechanicalP = p.advanced.physicalFrp.delta * eye(4);
        s.physical.updateCount = 0;
        s.physical.lastCorrection = 0; s.physical.correctionClipCount = 0;
        s.phase.hat = 0;
        s.phase.updateCount = 0;
        s.phase.lastInnovation = 0;
        s.nonlinear.theta = zeros(2, 2); % 每行[q c]
        s.nonlinear.updateCount = 0;
        s.nonlinear.clipCount = 0;
        s.nonlinear.previousE = NaN; s.nonlinear.previousQ = NaN; % 非线性辨识使用独立历史状态，避免与物理FRP抽取节拍互相污染。
        s.previousE = NaN;
        s.previousQ = NaN;
        s.previousTheta = NaN;
        varargout{1} = s;
    case 'apply_rate'
        nav = varargin{1}; o = varargin{2}; s = varargin{3}; p = varargin{4}; correction = 0;
        if p.advanced.physicalFrp.enable && s.physical.updateCount >= p.advanced.physicalFrp.minimumUpdatesForCorrection
            v = s.physical.mechanicalTheta; th = o.theta;
            dampingDrift = 0.5 * (v(1)*sin(4*th)-v(2)*cos(4*th));
            splitDrift = pi * (v(3)*cos(4*th)+v(4)*sin(4*th)) * o.inv.Q/max(o.inv.E,eps);
            correction = (dampingDrift+splitDrift)/p.res.bryan;
            lim = p.advanced.physicalFrp.maxCorrectionDps*pi/180;
            if abs(correction)>lim
                correction=min(max(correction,-lim),lim); s.physical.correctionClipCount=s.physical.correctionClipCount+1;
            end
            nav.compensatedRate = nav.compensatedRate + correction;
        end
        s.physical.lastCorrection = correction;
        varargout{1}=nav; varargout{2}=correction; varargout{3}=s;
    case 'apply_phase'
        demod = varargin{1}; s = varargin{2}; p = varargin{3};
        if p.advanced.phaseSelfCal.enable
            c = cos(s.phase.hat); q = sin(s.phase.hat);
            x = [demod.Cx; demod.Cy]; y = [demod.Sx; demod.Sy];
            xc = c * x + q * y; yc = -q * x + c * y;
            demod.Cx = xc(1); demod.Cy = xc(2); demod.Sx = yc(1); demod.Sy = yc(2);
        end
        varargout{1} = demod; varargout{2} = s;
    case 'update'
        o = varargin{1}; s = varargin{2}; p = varargin{3};
        s.sampleCount = s.sampleCount + 1;
        runValid = o.mode == 3 && isfinite(o.inv.E) && o.inv.E > p.pll.energyValidThreshold;
        ideal = sqrt(max(o.inv.E, eps)) * [cos(2 * o.theta); sin(2 * o.theta)];
        rawI = [o.rawDemod.Cx; o.rawDemod.Cy]; rawQ = [o.rawDemod.Sx; o.rawDemod.Sy];
        if p.advanced.phaseSelfCal.enable && runValid && o.t >= p.advanced.phaseSelfCal.startTime
            den = dot(rawI, ideal); num = dot(rawQ, ideal);
            innovation = atan2(num, den) - s.phase.hat;
            innovation = atan2(sin(innovation), cos(innovation));
            s.phase.hat = s.phase.hat + p.advanced.phaseSelfCal.adaptationGain * innovation;
            lim = p.advanced.phaseSelfCal.maxCorrectionDeg * pi / 180;
            s.phase.hat = min(max(s.phase.hat, -lim), lim);
            s.phase.lastInnovation = innovation; s.phase.updateCount = s.phase.updateCount + 1;
        end
        due = mod(s.sampleCount - 1, max(round(p.advanced.physicalFrp.updateDecimation), 1)) == 0;
        if p.advanced.physicalFrp.enable && runValid && due && o.t >= p.advanced.physicalFrp.startTime
            for ch = 1:2
                P = s.physical.detP(:, :, ch); th = s.physical.detTheta(ch, :)';
                g = P * ideal / max(p.advanced.physicalFrp.lambda + ideal' * P * ideal, eps);
                th = th + g * (rawI(ch) - ideal' * th);
                P = (P - g * ideal' * P) / p.advanced.physicalFrp.lambda;
                s.physical.detTheta(ch, :) = th'; s.physical.detP(:, :, ch) = 0.5 * (P + P');
            end
            if isfinite(s.previousE)
                dt = max(p.sim.TsCtrl * p.advanced.physicalFrp.updateDecimation, eps);
                eDot = (o.inv.E - s.previousE) / dt; qDot = (o.inv.Q - s.previousQ) / dt;
                th = s.previousTheta; E = max(s.previousE, eps); Q = s.previousQ;
                y = [eDot + 2 * p.res.meanDamping * E - o.previousAct(1); qDot + 2 * p.res.meanDamping * Q - o.previousAct(2)];
                H = [-E*cos(4*th), -E*sin(4*th), 0, 0; 0, 0, -4*pi*E*sin(4*th), 4*pi*E*cos(4*th)];
                P = s.physical.mechanicalP; R = 1e-4 * eye(2);
                K = P * H' / (H * P * H' + R);
                s.physical.mechanicalTheta = s.physical.mechanicalTheta + K * (y - H * s.physical.mechanicalTheta);
                P = (eye(4) - K * H) * P + 1e-10 * eye(4);
                s.physical.mechanicalP = 0.5 * (P + P');
            end
            s.physical.updateCount = s.physical.updateCount + 1;
        end
        nonlinearDue = mod(s.sampleCount - 1, max(round(p.advanced.nonlinearityCorrection.updateDecimation), 1)) == 0;
        if p.advanced.nonlinearityCorrection.enable && runValid && nonlinearDue && isfinite(s.nonlinear.previousE) && o.t >= p.advanced.nonlinearityCorrection.startTime
            dt = max(p.sim.TsCtrl * p.advanced.nonlinearityCorrection.updateDecimation, eps); u = o.previousAct(:);
            model = [-2*p.res.meanDamping*s.nonlinear.previousE; -2*p.res.meanDamping*s.nonlinear.previousQ];
            residual = [(o.inv.E-s.nonlinear.previousE)/dt; (o.inv.Q-s.nonlinear.previousQ)/dt] - model - u;
            for ch = 1:2
                phi = [u(ch)^2; u(ch)^3];
                mu = p.advanced.nonlinearityCorrection.adaptationGain / max(1 + phi' * phi, 1);
                s.nonlinear.theta(ch, :) = s.nonlinear.theta(ch, :) + (mu * phi * (residual(ch) - phi' * s.nonlinear.theta(ch, :)'))';
            end
            s.nonlinear.theta(:, 1) = min(max(s.nonlinear.theta(:, 1), -p.advanced.nonlinearityCorrection.maxQuadratic), p.advanced.nonlinearityCorrection.maxQuadratic);
            s.nonlinear.theta(:, 2) = min(max(s.nonlinear.theta(:, 2), -p.advanced.nonlinearityCorrection.maxCubic), p.advanced.nonlinearityCorrection.maxCubic);
            s.nonlinear.updateCount = s.nonlinear.updateCount + 1;
        end
        if due
            s.previousE = o.inv.E; s.previousQ = o.inv.Q; s.previousTheta = o.theta;
        end
        if nonlinearDue
            s.nonlinear.previousE = o.inv.E; s.nonlinear.previousQ = o.inv.Q;
        end
        varargout{1} = s;
    case 'command'
        tk = varargin{1}; cmd = varargin{2}; s = varargin{3}; p = varargin{4};
        if p.advanced.phaseSelfCal.enable && tk >= p.advanced.phaseSelfCal.startTime
            cmd(2) = cmd(2) + p.advanced.phaseSelfCal.probeAmplitude * sin(2*pi*p.advanced.phaseSelfCal.probeFrequencyHz*tk);
        end
        if p.advanced.nonlinearityCorrection.enable && tk >= p.advanced.nonlinearityCorrection.startTime
            u = cmd(1:2); delta = -(s.nonlinear.theta(:,1).*u.^2 + s.nonlinear.theta(:,2).*u.^3);
            lim = p.advanced.nonlinearityCorrection.maxPredistortionFraction * max(abs(u), 1e-3);
            clipped = abs(delta) > lim; delta = min(max(delta, -lim), lim);
            s.nonlinear.clipCount = s.nonlinear.clipCount + sum(clipped); cmd(1:2) = u + delta;
        end
        varargout{1} = cmd; varargout{2} = s;
    case 'metrics'
        s = varargin{1}; p = varargin{2};
        a = 2 * p.afe.assemblyAngleRad; R = [cos(a) -sin(a); sin(a) cos(a)];
        truthDet = p.afe.crossMatrix * diag(cos(p.afe.phaseDelayRad(:))) * R;
        estDet = s.physical.detTheta;
        truthDet = truthDet / max(mean(diag(truthDet)), eps); estDet = estDet / max(mean(diag(estDet)), eps);
        truthMechanical = [p.res.dampingAnisotropy*cos(4*p.res.dampingAxis); p.res.dampingAnisotropy*sin(4*p.res.dampingAxis); p.res.frequencySplitHz*cos(4*p.res.stiffnessAxis); p.res.frequencySplitHz*sin(4*p.res.stiffnessAxis)];
        m.physicalFrp.enabled = p.advanced.physicalFrp.enable; m.physicalFrp.updateCount = s.physical.updateCount;
        m.physicalFrp.detectionTruth = truthDet; m.physicalFrp.detectionEstimate = estDet; m.physicalFrp.detectionError = norm(estDet-truthDet, 'fro');
        m.physicalFrp.mechanicalTruth = truthMechanical; m.physicalFrp.mechanicalEstimate = s.physical.mechanicalTheta; m.physicalFrp.mechanicalError = norm(s.physical.mechanicalTheta-truthMechanical);
        m.physicalFrp.lastCorrectionDps = s.physical.lastCorrection*180/pi; m.physicalFrp.correctionClipCount = s.physical.correctionClipCount;
        phaseTruth = mean(p.afe.phaseDelayRad(:));
        m.phaseSelfCal.enabled = p.advanced.phaseSelfCal.enable; m.phaseSelfCal.truthRad = phaseTruth; m.phaseSelfCal.estimateRad = s.phase.hat; m.phaseSelfCal.errorDeg = abs(s.phase.hat-phaseTruth)*180/pi; m.phaseSelfCal.updateCount = s.phase.updateCount;
        nlTruth = [p.drive.quadraticNonlinearity(:), p.drive.cubicNonlinearity(:)];
        m.nonlinearityCorrection.enabled = p.advanced.nonlinearityCorrection.enable; m.nonlinearityCorrection.truth = nlTruth; m.nonlinearityCorrection.estimate = s.nonlinear.theta; m.nonlinearityCorrection.error = norm(s.nonlinear.theta-nlTruth, 'fro'); m.nonlinearityCorrection.updateCount = s.nonlinear.updateCount; m.nonlinearityCorrection.clipCount = s.nonlinear.clipCount;
        varargout{1} = m;
    otherwise
        error('HRG_WA_v46_advanced:UnknownAction', '未知动作: %s', action);
end
end
