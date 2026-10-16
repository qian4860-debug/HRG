`timescale 1ns/1ps
// Navigation profile: Kalman/online calibration disabled. angle Q24 degrees,
// rate Q16 degrees/s, virtual_actual Q22 radians/s, Bryan Q30.
// One valid output for every CORDIC result, including invalid measurements.
module hrg_navigation (
    input wire clk,nrst,update_i,measurement_valid_i,zero_i,
    input wire signed [23:0] phase4_i,
    input wire signed [27:0] virtual_actual_i,
    input wire [31:0] bryan_q30_i,
    input wire [30:0] rate_alpha_q30_i,
    output reg valid_o,
    output reg signed [47:0] angle_o,
    output reg signed [31:0] rate_o,
    output reg measurement_valid_o,unwrap_fault_o
);
    reg signed [23:0] previous_phase;
    reg anchored;
    reg signed [63:0] angle_q40,rate_q32;
    reg signed [23:0] modular_delta;
    reg signed [127:0] theta_step,virtual_step,step_q40,raw_rate,next_rate,next_angle;
    function signed [127:0] nearest;
        input signed [127:0] n,d;
        begin if(d==0) nearest=0;
            else nearest=n<0 ? -((-n+d/2)/d):(n+d/2)/d;
        end
    endfunction
    always @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            previous_phase<=0;anchored<=0;angle_q40<=0;rate_q32<=0;
            valid_o<=0;angle_o<=0;rate_o<=0;measurement_valid_o<=0;unwrap_fault_o<=0;
        end else begin
            valid_o<=0;
            if(update_i) begin
                valid_o<=1;measurement_valid_o<=measurement_valid_i && bryan_q30_i!=0;unwrap_fault_o<=0;
                modular_delta=phase4_i-previous_phase;
                if(zero_i) begin
                    angle_q40<=0;rate_q32<=0;angle_o<=0;rate_o<=0;
                    previous_phase<=phase4_i;anchored<=measurement_valid_i;
                end else if(!measurement_valid_i || bryan_q30_i==0) anchored<=0;
                else begin
                    previous_phase<=phase4_i;anchored<=1;
                    if(anchored) begin
                        if(modular_delta>6710886 || modular_delta< -6710886) begin
                            unwrap_fault_o<=1;measurement_valid_o<=0;
                        end else begin
                            theta_step=$signed(modular_delta)*128'sd5898240; // 90*2^16, degree Q40
                            // 180/pi represented Q40; Ts=1/1000.
                            virtual_step=nearest($signed(virtual_actual_i)*128'sd62997375797124,128'sd4194304000);
                            step_q40=nearest((virtual_step-theta_step)*128'sd1073741824,$signed({1'b0,bryan_q30_i}));
                            next_angle=$signed(angle_q40)+step_q40;
                            raw_rate=nearest(step_q40*1000,256); // Q32 deg/s
                            next_rate=$signed(rate_q32)+nearest((raw_rate-$signed(rate_q32))*$signed({1'b0,rate_alpha_q30_i}),128'sd1073741824);
                            // Saturate public rate and internal filter coherently.
                            if(next_rate>128'sd140737488289792) next_rate=128'sd140737488289792;
                            if(next_rate< -128'sd140737488355328) next_rate=-128'sd140737488355328;
                            angle_q40<=next_angle;rate_q32<=next_rate;
                            angle_o<=nearest(next_angle,65536);rate_o<=nearest(next_rate,65536);
                        end
                    end
                end
            end
        end
    end
endmodule
