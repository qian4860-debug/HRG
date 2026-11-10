`timescale 1ns/1ps
// 五电极连续/分时复用全角陀螺数字核。
// 一个 clk 上升沿对应一个物理 ADC 采样时刻。机电表头、C/V、抗混叠、
// 模拟开关及功率驱动器在本模块外。ADC 端口提供尚未经过数字延迟的转换码。
module hrg_five_digital #(
    parameter TDM = 0,
    parameter ADC_BITS = TDM ? 10 : 16,
    parameter DAC_BITS = TDM ? 14 : 16,
    parameter ADC_LATENCY = TDM ? 5 : 1,
    parameter DAC_DIVISOR = 1
) (
    input clk,
    input reset_n,
    input signed [ADC_BITS-1:0] adc_x,
    input signed [ADC_BITS-1:0] adc_y,
    input adc_overrange,
    // Q24 实矩阵按行展开，首元素位于最低 64 位。配置在运行期间保持稳定。
    input [1023:0] detect_matrix,
    input [1023:0] drive_matrix,
    input signed [63:0] minimum_energy,
    input signed [63:0] minimum_linearity,
    input signed [63:0] intrinsic_damping,
    input signed [63:0] agc_gain,
    input signed [63:0] quadrature_gain,
    input signed [63:0] angle_scale,
    input [31:0] seed_ticks,
    input [255:0] seed_command,
    output drive_on,
    output sense_on,
    output sample_valid,
    output reg signed [DAC_BITS-1:0] dac_x,
    output reg signed [DAC_BITS-1:0] dac_y,
    output reg dac_clip,
    output reg published,
    output reg angle_valid,
    output reg tracking_lost,
    output reg signed [63:0] angle,
    output reg signed [63:0] ix,
    output reg signed [63:0] iy,
    output reg signed [63:0] qx,
    output reg signed [63:0] qy
);
    localparam SAMPLES = TDM ? 800 : 160;
    localparam STRIDE = TDM ? 1 : 5;
    localparam FRAME = TDM ? 4*SAMPLES : SAMPLES;
    localparam SENSE_START = TDM ? 3*SAMPLES/2 : 0;
    localparam VALID_START = TDM ? 5*SAMPLES/2 : 0;
    localparam VALID_END = TDM ? 7*SAMPLES/2 : SAMPLES;
    localparam FIFO_DEPTH = ADC_LATENCY > 0 ? ADC_LATENCY : 1;
    localparam signed [63:0] DAC_MIN = -(64'sd1 <<< (DAC_BITS-1));
    localparam signed [63:0] DAC_MAX = (64'sd1 <<< (DAC_BITS-1)) - 1;
    localparam signed [63:0] DAC_MIN_Q = DAC_MIN <<< (24-DAC_BITS);
    localparam signed [63:0] DAC_MAX_Q = DAC_MAX <<< (24-DAC_BITS);
    localparam signed [63:0] UNITY = 64'sd16777216;
    localparam signed [63:0] PI_Q = 64'sd52707179;
    localparam signed [63:0] TWOPI_Q = 64'sd105414357;

    reg [11:0] slot;
    reg [9:0] phase;
    reg [11:0] dac_div_count;
    reg [31:0] seed_left;
    reg [31:0] warm;
    reg signed [ADC_BITS-1:0] adc_pipe_x [0:FIFO_DEPTH-1];
    reg signed [ADC_BITS-1:0] adc_pipe_y [0:FIFO_DEPTH-1];
    reg clip_pipe [0:FIFO_DEPTH-1];
    reg signed [DAC_BITS-1:0] held_dac_x, held_dac_y;
    reg signed [63:0] command [0:3];
    reg signed [63:0] accum [0:3];
    reg signed [63:0] iq_hold [0:3];
    reg signed [63:0] previous_azimuth, angle_hold;
    reg seen, lost, clipped, publish_next, first_tick;
    integer k;

    `include "hrg_five_math.vh"

    // 物理开关按采样时刻控制。连续版驱检均保持接通。
    assign drive_on = reset_n && slot < SAMPLES;
    assign sense_on = reset_n && slot >= SENSE_START && slot < VALID_END;
    assign sample_valid = sense_on && slot >= VALID_START;
    wire [11:0] source_slot = slot >= ADC_LATENCY
        ? slot - ADC_LATENCY : slot + FRAME - ADC_LATENCY;
    wire [9:0] source_phase = phase >= ADC_LATENCY*STRIDE
        ? phase - ADC_LATENCY*STRIDE : phase + 800 - ADC_LATENCY*STRIDE;
    wire source_ready = warm == ADC_LATENCY;
    wire signed [ADC_BITS-1:0] valid_adc_x = sample_valid ? adc_x : {ADC_BITS{1'b0}};
    wire signed [ADC_BITS-1:0] valid_adc_y = sample_valid ? adc_y : {ADC_BITS{1'b0}};
    wire signed [63:0] rx_code_x = ADC_LATENCY == 0 ? valid_adc_x : adc_pipe_x[FIFO_DEPTH-1];
    wire signed [63:0] rx_code_y = ADC_LATENCY == 0 ? valid_adc_y : adc_pipe_y[FIFO_DEPTH-1];
    wire rx_clip = ADC_LATENCY == 0 ? sample_valid && adc_overrange : clip_pipe[FIFO_DEPTH-1];
    wire signed [63:0] received_x = rx_code_x <<< (25-ADC_BITS);
    wire signed [63:0] received_y = rx_code_y <<< (25-ADC_BITS);
    wire signed [63:0] cosine = carrier_sine(phase < 600 ? phase+200 : phase-600);
    wire signed [63:0] sine = carrier_sine(phase);
    wire signed [63:0] source_cos = carrier_sine(source_phase < 600 ? source_phase+200 : source_phase-600);
    wire signed [63:0] source_sin = carrier_sine(source_phase);

    // 数字调制和 DAC 独立分频。驱动窗口外关断送往输出级的命令。
    wire seed_active = first_tick ? seed_ticks != 0 : seed_left != 0;
    wire signed [63:0] cx = seed_active ? seed_command[63:0] : command[0];
    wire signed [63:0] cy = seed_active ? seed_command[127:64] : command[1];
    wire signed [63:0] sx = seed_active ? seed_command[191:128] : command[2];
    wire signed [63:0] sy = seed_active ? seed_command[255:192] : command[3];
    wire signed [63:0] raw_x = mulq(cx,cosine)+mulq(sx,sine);
    wire signed [63:0] raw_y = mulq(cy,cosine)+mulq(sy,sine);
    wire signed [63:0] code_x = dac_quantize(raw_x);
    wire signed [63:0] code_y = dac_quantize(raw_y);

    // 混频采用采集时刻的相位。窗首清除上帧累加和，窗末包含当拍样本。
    wire signed [63:0] ai0 = (source_slot == 0 ? 64'sd0 : accum[0])+mulq(received_x,source_cos);
    wire signed [63:0] ai1 = (source_slot == 0 ? 64'sd0 : accum[1])+mulq(received_y,source_cos);
    wire signed [63:0] aq0 = (source_slot == 0 ? 64'sd0 : accum[2])+mulq(received_x,source_sin);
    wire signed [63:0] aq1 = (source_slot == 0 ? 64'sd0 : accum[3])+mulq(received_y,source_sin);
    wire frame_clipped = (source_slot != 0 && clipped) || rx_clip;

    reg signed [63:0] e0,e1,e2,e3,stokes_n,stokes_m,ii,qq,iq_cross,energy,azimuth;
    reg signed [63:0] phi,cp,sp,p0,p1,p2,p3,pnorm,amp_force,f0,f1,g0,g1,delta;
    reg signed [63:0] fc0,fc1,fs0,fs1;
    reg signed [127:0] phase_pair;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            slot <= 0; phase <= 0; warm <= 0; dac_div_count <= 0;
            seed_left <= 0; first_tick <= 1;
            held_dac_x <= 0; held_dac_y <= 0; dac_x <= 0; dac_y <= 0; dac_clip <= 0;
            angle <= 0; angle_hold <= 0; previous_azimuth <= 0;
            seen <= 0; lost <= 0; clipped <= 0; publish_next <= 0;
            published <= 0; angle_valid <= 0; tracking_lost <= 0;
            ix <= 0; iy <= 0; qx <= 0; qy <= 0;
            for (k=0;k<FIFO_DEPTH;k=k+1) begin
                adc_pipe_x[k] <= 0; adc_pipe_y[k] <= 0; clip_pipe[k] <= 0;
            end
            for (k=0;k<4;k=k+1) begin
                command[k] <= 0; accum[k] <= 0; iq_hold[k] <= 0;
            end
        end else begin
            slot <= slot == FRAME-1 ? 12'd0 : slot+1'b1;
            phase <= phase == 800-STRIDE ? 10'd0 : phase+STRIDE;
            dac_div_count <= dac_div_count == DAC_DIVISOR-1 ? 12'd0 : dac_div_count+1'b1;
            first_tick <= 0;
            if (seed_active) seed_left <= (first_tick ? seed_ticks : seed_left)-1'b1;
            if (warm < ADC_LATENCY) warm <= warm+1'b1;
            adc_pipe_x[0] <= valid_adc_x;
            adc_pipe_y[0] <= valid_adc_y;
            clip_pipe[0] <= sample_valid && adc_overrange;
            for (k=1;k<FIFO_DEPTH;k=k+1) begin
                adc_pipe_x[k] <= adc_pipe_x[k-1];
                adc_pipe_y[k] <= adc_pipe_y[k-1];
                clip_pipe[k] <= clip_pipe[k-1];
            end
            if (dac_div_count == 0) begin
                held_dac_x <= code_x[DAC_BITS-1:0]; held_dac_y <= code_y[DAC_BITS-1:0];
            end
            dac_x <= !drive_on ? {DAC_BITS{1'b0}} : dac_div_count == 0 ? code_x[DAC_BITS-1:0] : held_dac_x;
            dac_y <= !drive_on ? {DAC_BITS{1'b0}} : dac_div_count == 0 ? code_y[DAC_BITS-1:0] : held_dac_y;
            dac_clip <= drive_on && (raw_x < DAC_MIN_Q || raw_x > DAC_MAX_Q ||
                                    raw_y < DAC_MIN_Q || raw_y > DAC_MAX_Q);
            // 与行为模型的逐拍 trace 对齐，发布脉冲和状态对应本拍入口。
            published <= publish_next;
            publish_next <= 0;
            angle_valid <= seen && !lost;
            tracking_lost <= lost;
            angle <= angle_hold;
            ix <= iq_hold[0]; iy <= iq_hold[1]; qx <= iq_hold[2]; qy <= iq_hold[3];
            if (source_ready) begin
                accum[0] <= ai0; accum[1] <= ai1; accum[2] <= aq0; accum[3] <= aq1;
                clipped <= frame_clipped;
                if (source_slot == VALID_END-1) begin
                    // 窗末对四分量施加 C/V 等效增益、通道极性和相位校准。
                    e0 = matrow(detect_matrix[255:0],(2*ai0)/SAMPLES,(2*ai1)/SAMPLES,(2*aq0)/SAMPLES,(2*aq1)/SAMPLES);
                    e1 = matrow(detect_matrix[511:256],(2*ai0)/SAMPLES,(2*ai1)/SAMPLES,(2*aq0)/SAMPLES,(2*aq1)/SAMPLES);
                    e2 = matrow(detect_matrix[767:512],(2*ai0)/SAMPLES,(2*ai1)/SAMPLES,(2*aq0)/SAMPLES,(2*aq1)/SAMPLES);
                    e3 = matrow(detect_matrix[1023:768],(2*ai0)/SAMPLES,(2*ai1)/SAMPLES,(2*aq0)/SAMPLES,(2*aq1)/SAMPLES);
                    ii = mulq(e0,e0)+mulq(e1,e1);
                    qq = mulq(e2,e2)+mulq(e3,e3);
                    iq_cross = 2*(mulq(e0,e2)+mulq(e1,e3));
                    energy = ii+qq;
                    stokes_n = mulq(e0,e0)+mulq(e2,e2)-mulq(e1,e1)-mulq(e3,e3);
                    stokes_m = 2*(mulq(e0,e1)+mulq(e2,e3));
                    if (!frame_clipped && !lost && energy >= minimum_energy &&
                        $signed(sqrtq(mulq(stokes_m,stokes_m)+mulq(stokes_n,stokes_n))) >= mulq(minimum_linearity,energy)) begin
                        iq_hold[0] <= e0; iq_hold[1] <= e1; iq_hold[2] <= e2; iq_hold[3] <= e3;
                        // 椭圆主轴分解，主分量稳幅，正交分量闭环压制。
                        phi = atan2q(iq_cross,ii-qq)/2;
                        phase_pair = sincosq(phi);
                        cp = phase_pair[127:64]; sp = phase_pair[63:0];
                        p0 = mulq(e0,cp)+mulq(e2,sp); p1 = mulq(e1,cp)+mulq(e3,sp);
                        p2 = mulq(e2,cp)-mulq(e0,sp); p3 = mulq(e3,cp)-mulq(e1,sp);
                        pnorm = sqrtq(mulq(p0,p0)+mulq(p1,p1));
                        if (pnorm < 1) pnorm = 1;
                        amp_force = -(intrinsic_damping+mulq(agc_gain,UNITY-sqrtq(energy)));
                        f0 = mulq(amp_force,divq(p0,pnorm)); f1 = mulq(amp_force,divq(p1,pnorm));
                        g0 = -mulq(quadrature_gain,p2); g1 = -mulq(quadrature_gain,p3);
                        fc0 = mulq(g0,cp)-mulq(f0,sp); fc1 = mulq(g1,cp)-mulq(f1,sp);
                        fs0 = mulq(g0,sp)+mulq(f0,cp); fs1 = mulq(g1,sp)+mulq(f1,cp);
                        command[0] <= matrow(drive_matrix[255:0],fc0,fc1,fs0,fs1);
                        command[1] <= matrow(drive_matrix[511:256],fc0,fc1,fs0,fs1);
                        command[2] <= matrow(drive_matrix[767:512],fc0,fc1,fs0,fs1);
                        command[3] <= matrow(drive_matrix[1023:768],fc0,fc1,fs0,fs1);
                        // 方位角解缠按最短弧计算。首个有效帧只建立角度参考。
                        azimuth = atan2q(stokes_m,stokes_n);
                        if (seen) begin
                            delta = azimuth-previous_azimuth;
                            if (delta > PI_Q) delta = delta-TWOPI_Q;
                            if (delta < -PI_Q) delta = delta+TWOPI_Q;
                            angle_hold <= angle_hold-mulq(delta,angle_scale);
                        end
                        previous_azimuth <= azimuth;
                        seen <= 1;
                        publish_next <= 1;
                    end else begin
                        // 捕获前坏帧可以重试。捕获后失锁保持，直到外部复位。
                        for (k=0;k<4;k=k+1) command[k] <= 0;
                        lost <= lost || seen;
                    end
                end
            end
        end
    end
endmodule
