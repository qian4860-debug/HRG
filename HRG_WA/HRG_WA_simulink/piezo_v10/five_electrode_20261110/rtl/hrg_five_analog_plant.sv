// 压电表头、驱动和 C/V 的离散行为模型，仅供 SystemVerilog 仿真。
// MATLAB 导出五电极模型的 26 状态或 6800 Hz 分时不复用对照的 18 状态。
// 每个采样时刻先观察 x[k]，
// 再用 RTL 实际输出的 DAC 码推进到 x[k+1]，闭环运行期间不回放 ADC。
module hrg_five_analog_plant #(
    parameter integer N = 26
);
    real transitions [0:3*N*N-1];
    real drive_matrix [0:2*N-1];
    real readout_matrix [0:2*N-1];
    real state [0:N-1];
    real next_state [0:N-1];
    real adc_step, adc_min, adc_max, dac_step, sample_period, rotation_rate;

    task automatic read_model(input string file_name);
        integer file_id, row;
        begin
            file_id = $fopen(file_name, "r");
            if (!file_id) $fatal(1, "Cannot open analog model %s", file_name);
            // 三套状态矩阵依次为驱动、检测和浮置/泄放，每套按行存放。
            for (row=0; row<3*N*N; row=row+1)
                if ($fscanf(file_id,"%f",transitions[row]) != 1) $fatal(1,"Missing transition %d",row);
            for (row=0; row<2*N; row=row+1)
                if ($fscanf(file_id,"%f",drive_matrix[row]) != 1) $fatal(1,"Missing drive coefficient %d",row);
            for (row=0; row<2*N; row=row+1)
                if ($fscanf(file_id,"%f",readout_matrix[row]) != 1) $fatal(1,"Missing readout coefficient %d",row);
            for (row=0; row<N; row=row+1)
                if ($fscanf(file_id,"%f",state[row]) != 1) $fatal(1,"Missing initial state %d",row);
            if ($fscanf(file_id,"%f %f %f %f %f %f", adc_step, adc_min, adc_max,
                        dac_step, sample_period, rotation_rate) != 6)
                $fatal(1,"Missing converter scales or scenario timing");
            $fclose(file_id);
        end
    endtask

    function automatic integer encode(input real voltage);
        real limited, normalized;
        begin
            limited = voltage;
            if (limited < adc_min) limited = adc_min;
            if (limited > adc_max) limited = adc_max;
            normalized = limited / adc_step;
            // MATLAB round 的半码处理：正负半码都远离零。
            encode = $rtoi(normalized >= 0.0 ? normalized + 0.5 : normalized - 0.5);
        end
    endfunction

    task automatic acquire(input logic valid, output integer code_x, code_y, output logic clip);
        real x, y;
        integer col;
        begin
            code_x = 0;
            code_y = 0;
            clip = 0;
            if (valid) begin
                x = 0.0;
                y = 0.0;
                for (col=0; col<N; col=col+1) begin
                    x = x + readout_matrix[col] * state[col];
                    y = y + readout_matrix[N+col] * state[col];
                end
                clip = x < adc_min || x > adc_max || y < adc_min || y > adc_max;
                code_x = encode(x);
                code_y = encode(y);
            end
        end
    endtask

    task automatic advance(input logic drive_on, sense_on, input integer dac_x, dac_y);
        integer offset, row, col;
        real v_x, v_y;
        begin
            // 连续版驱检同时接通，状态推进走已包含读出负载的驱动矩阵。
            offset = drive_on ? 0 : (sense_on ? N*N : 2*N*N);
            v_x = dac_x * dac_step;
            v_y = dac_y * dac_step;
            for (row=0; row<N; row=row+1) begin
                next_state[row] = 0.0;
                for (col=0; col<N; col=col+1)
                    next_state[row] = next_state[row] + transitions[offset+row*N+col] * state[col];
                if (drive_on)
                    next_state[row] = next_state[row] + drive_matrix[2*row]*v_x + drive_matrix[2*row+1]*v_y;
            end
            for (row=0; row<N; row=row+1) state[row] = next_state[row];
        end
    endtask
endmodule
