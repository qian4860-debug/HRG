`timescale 1ns/1ps

// Energy and quadrature PI loops. Gains are Q16.16, measurements Q8.24,
// command/integrator states Q6.22. Integral gains include the 1 kHz Ts.
module hrg_controller (
    input  wire                    clk,
    input  wire                    nrst,
    input  wire                    update_i,
    input  wire [4:0]              ctrl_i,
    input  wire signed [31:0]       energy_i,
    input  wire signed [31:0]       quad_i,
    input  wire signed [31:0]       energy_ref_i,
    input  wire signed [31:0]       energy_kp_i,
    input  wire signed [31:0]       energy_ki_i,
    input  wire signed [31:0]       quad_kp_i,
    input  wire signed [31:0]       quad_ki_i,
    input  wire signed [27:0]       virtual_cmd_i,
    output reg signed [27:0]        energy_cmd_o,
    output reg signed [27:0]        quad_cmd_o,
    output reg signed [27:0]        virtual_cmd_o,
    output reg                      command_valid_o,
    output reg                      limit_event_o
);
    localparam signed [31:0] ENERGY_LIMIT = 32'sd2306867; // 0.55 Q22
    localparam signed [31:0] QUAD_LIMIT   = 32'sd1887437; // 0.45 Q22
    reg signed [39:0] energy_int;
    reg signed [39:0] quad_int;
    reg signed [63:0] e_err, q_err, e_p, q_p, e_step, q_step;
    reg signed [63:0] e_sum, q_sum;
    reg signed [27:0] e_pipe [0:2];
    reg signed [27:0] q_pipe [0:2];
    reg signed [27:0] v_pipe [0:2];
    integer i;

    function signed [27:0] clamp_cmd;
        input signed [63:0] value;
        input signed [31:0] limit;
        begin
            if (value > limit) clamp_cmd = limit[27:0];
            else if (value < -limit) clamp_cmd = -limit[27:0];
            else clamp_cmd = value[27:0];
        end
    endfunction

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            energy_int<=0; quad_int<=0; energy_cmd_o<=0; quad_cmd_o<=0;
            virtual_cmd_o<=0; command_valid_o<=0; limit_event_o<=0;
            for (i=0;i<3;i=i+1) begin e_pipe[i]<=0; q_pipe[i]<=0; v_pipe[i]<=0; end
        end else begin
            command_valid_o <= 1'b0;
            limit_event_o <= 1'b0;
            if (update_i) begin
                e_err = $signed(energy_ref_i) - $signed(energy_i);
                q_err = -$signed(quad_i);
                e_p = (e_err * $signed(energy_kp_i)) >>> 18;
                q_p = (q_err * $signed(quad_kp_i)) >>> 18;
                e_step = ((e_err * $signed(energy_ki_i)) >>> 18) / 1000;
                q_step = ((q_err * $signed(quad_ki_i)) >>> 18) / 1000;

                if (ctrl_i[0] && ctrl_i[1]) begin
                    e_sum = e_p + energy_int + e_step;
                    if (!((e_sum > ENERGY_LIMIT && e_err > 0) ||
                          (e_sum < -ENERGY_LIMIT && e_err < 0)))
                        energy_int <= energy_int + e_step;
                    e_pipe[0] <= clamp_cmd(e_sum, ENERGY_LIMIT);
                    if (e_sum > ENERGY_LIMIT || e_sum < -ENERGY_LIMIT)
                        limit_event_o <= 1'b1;
                end else begin
                    energy_int <= 0;
                    e_pipe[0] <= 0;
                end

                if (ctrl_i[0] && ctrl_i[2]) begin
                    q_sum = q_p + quad_int + q_step;
                    if (!((q_sum > QUAD_LIMIT && q_err > 0) ||
                          (q_sum < -QUAD_LIMIT && q_err < 0)))
                        quad_int <= quad_int + q_step;
                    q_pipe[0] <= clamp_cmd(q_sum, QUAD_LIMIT);
                    if (q_sum > QUAD_LIMIT || q_sum < -QUAD_LIMIT)
                        limit_event_o <= 1'b1;
                end else begin
                    quad_int <= 0;
                    q_pipe[0] <= 0;
                end
                v_pipe[0] <= (ctrl_i[0] && ctrl_i[3]) ? virtual_cmd_i : 28'sd0;
                e_pipe[1] <= e_pipe[0]; e_pipe[2] <= e_pipe[1];
                q_pipe[1] <= q_pipe[0]; q_pipe[2] <= q_pipe[1];
                v_pipe[1] <= v_pipe[0]; v_pipe[2] <= v_pipe[1];
                energy_cmd_o <= e_pipe[2];
                quad_cmd_o <= q_pipe[2];
                virtual_cmd_o <= v_pipe[2];
                command_valid_o <= 1'b1;
            end
        end
    end
endmodule
