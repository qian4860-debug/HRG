function result=three_angle_boundary_probe(folder)
% 量化边界诊断：原模型临时添加原生只读探针，核对首次码差对应的真实采样拍。
arguments
    folder (1,:) char = fileparts(mfilename('fullpath'))
end
addpath(fullfile(folder,'..','three_mode_split_20261113'));
modes={'continuous','tdm_separate'};
models={'hrg_dq_continuous','hrg_dq_separate'};
rows={};
for k=1:2
    c=three_mode_split_config(modes{k},0,.05,22.5,.12,16, ...
        struct('Cs',720e-12,'bleed_R',1/(720e-12/2e-6-1e-10)));
    c.logDecimation=1;
    [~,trace,~,~,angles,probe]=five_reference(c,false);
    model=models{k}; load_system(fullfile(folder,'drift_quant_models',[model '.slx']));
    closeModel=onCleanup(@() close_system(model,0));
    tap(model,'Carrier/Cosine NCO','probeCos'); tap(model,'Carrier/Sine NCO','probeSin');
    tap(model,'Converters/Startup or feedback drive','probeDAC');
    tap(model,'Converters/ADC input with dither','probeADC');
    tap(model,'Four electrode groups and COM/State vector','probeState');
    input=Simulink.SimulationInput(model);input=input.setVariable('c',c,'Workspace',model);
    out=sim(input);
    actual=[out.probeCos,out.probeSin,out.probeDAC,out.probeADC,out.probeState];
    assert(isequal(size(actual),size(probe)));
    mismatch=trace(:,5:8)~=out.trace(:,5:8);
    first=find(any(mismatch,2),1); assert(~isempty(first));
    columns=find(mismatch(first,:)); details={};
    for j=columns
        sampleRow=first; step=c.dacStep; rawCol=j;
        kind='DAC';
        if j<=2
            kind='ADC'; step=c.adcStep; sampleRow=first-c.adcLatency; rawCol=j+4;
        end
        a=probe(sampleRow,rawCol)/step; b=actual(sampleRow,rawCol)/step;
        threshold=floor(a)+.5;
        details{end+1}=struct('converter',kind,'axis',mod(j-1,2)+1, ...
            'sample_tick',sampleRow-1,'reference_scaled_code',a,'native_scaled_code',b, ...
            'threshold_code',threshold,'reference_minus_threshold_LSB',a-threshold, ...
            'native_minus_threshold_LSB',b-threshold,'raw_delta_V',(b-a)*step, ...
            'reference_round',round(a),'native_round',round(b)); %#ok<AGROW>
    end
    before=1:(first-c.adcLatency-1);
    ad=actual(before,:)-probe(before,:);
    carrier=max(abs(ad(:,1:2)),[],'all'); states=max(abs(ad(:,7:end)),[],'all');
    angleDelta=out.angleCandidates(:,2:4)-angles(:,2:4);
    row=struct('mode',modes{k},'first_code_difference_row',first, ...
        'first_output_time_s',(first-1)*c.Ts,'converter_mismatches',nnz(mismatch), ...
        'max_carrier_difference_before_first_code',carrier,'max_state_difference_before_first_code',states, ...
        'first_code_details',[details{:}], ...
        'max_angle_difference_rad',max(abs(atan2(sin(angleDelta),cos(angleDelta))),[],'all'));
    % 同一 native 状态用 MATLAB 矩阵再投影，区分状态分歧和输出矩阵求和差异。
    sample=first-c.adcLatency;
    row.native_state_matlab_cv_V=(c.pickoff*actual(sample,7:end)')';
    row.native_adc_V=actual(sample,5:6);
    rows{end+1}=row; %#ok<AGROW>
    fprintf('%s first tick %d, carrier delta %.3g, state delta %.3g\n', ...
        c.mode,first-1,carrier,states);
    disp(row.first_code_details);
    clear closeModel
end
result=struct('status','diagnostic_complete','cases',[rows{:}]);
fid=fopen(fullfile(folder,'boundary_probe.json'),'w','n','UTF-8');assert(fid>=0);
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(result,'PrettyPrint',true));
end

function tap(model,relative,name)
% 只读 To Workspace 支路不馈回模型，保持原有原生元件及采样时刻。
src=[model '/' relative]; parent=get_param(src,'Parent');
dst=[parent '/' name]; add_block('simulink/Sinks/To Workspace',dst, ...
    'VariableName',name,'SaveFormat','Array','MaxDataPoints','inf','Decimation','1');
a=get_param(src,'PortHandles');b=get_param(dst,'PortHandles');
add_line(parent,a.Outport(1),b.Inport(1),'autorouting','on');
end
