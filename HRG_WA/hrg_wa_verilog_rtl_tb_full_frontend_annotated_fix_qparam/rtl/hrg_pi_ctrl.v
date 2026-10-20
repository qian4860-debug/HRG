
// ============================================================================
// 详细注释补充说明
// ----------------------------------------------------------------------------
// 本模块是通用定点 PI 控制器，可用于能量环和正交环。
//
// 计算关系：
//   p_term = kp * err
//   i_acc  = i_acc + ki * err
//   out    = sat((p_term + i_acc) >> FRAC)
//
// 限幅设计：
//   integ_limit 限制积分器，防止长期误差导致 wind-up；
//   out_limit 限制输出控制量，模拟 DAC/驱动最大幅值。
// ============================================================================

// ============================================================================
// hrg_pi_ctrl.v
// ----------------------------------------------------------------------------
// 功能：
//   可综合定点 PI 控制器，带积分限幅、输出限幅和饱和标志。
//   用于半球谐振陀螺全角模式的能量环 E 和正交环 Q 控制。
// 
// 定点格式建议：
//   err、out、out_limit：Q2.30
//   kp、ki：Q2.30
//   integ：内部 64-bit，保持更多余量
//
// 控制律：
//   p_term = kp * err
//   integ  = integ + ki * err
//   out    = sat(p_term + integ)
// ============================================================================

`timescale 1ns/1ps

module hrg_pi_ctrl #(
    parameter DATA_W = 32,
    parameter GAIN_W = 32,
    parameter ACC_W  = 64,
    parameter FRAC   = 30
)(
    input                         clk,
    input                         rst_n,

    input                         en,
    input                         clear,

    input      signed [DATA_W-1:0] err,
    input      signed [GAIN_W-1:0] kp,
    input      signed [GAIN_W-1:0] ki,
    input      signed [DATA_W-1:0] out_limit,
    input      signed [ACC_W-1:0]  integ_limit,

    output reg signed [DATA_W-1:0] out,
    output reg signed [ACC_W-1:0]  integ,
    output reg                     sat
);

    wire signed [DATA_W+GAIN_W-1:0] p_mult = err * kp;
    wire signed [DATA_W+GAIN_W-1:0] i_mult = err * ki;

    wire signed [ACC_W-1:0] p_term = p_mult >>> FRAC;
    wire signed [ACC_W-1:0] i_step = i_mult >>> FRAC;

    reg signed [ACC_W-1:0] integ_next;
    reg signed [ACC_W-1:0] integ_try;
    reg signed [ACC_W-1:0] sum_try;
    reg signed [ACC_W-1:0] sum_next;
    reg signed [ACC_W-1:0] pos_lim_ext;
    reg signed [ACC_W-1:0] neg_lim_ext;
    reg signed [DATA_W-1:0] pos_lim;
    reg signed [DATA_W-1:0] neg_lim;
    reg                     hold_integ;

    always @(*) begin
        pos_lim = out_limit;
        neg_lim = -out_limit;
        pos_lim_ext = {{(ACC_W-DATA_W){pos_lim[DATA_W-1]}}, pos_lim};
        neg_lim_ext = {{(ACC_W-DATA_W){neg_lim[DATA_W-1]}}, neg_lim};

        // 积分器候选值先按原 PI 关系累加，再按 integ_limit 限幅。
        integ_try = integ + i_step;
        if (integ_try > integ_limit) begin
            integ_try = integ_limit;
        end else if (integ_try < -integ_limit) begin
            integ_try = -integ_limit;
        end

        // 抗积分饱和：
        // 当输出已经将要撞正限幅且误差仍为正时，继续积分只会把积分器推得更深，
        // 因此保持积分器；负限幅同理。若误差方向有利于退出饱和，则允许积分器回退。
        sum_try = p_term + integ_try;
        hold_integ = 1'b0;
        if ((sum_try > pos_lim_ext) && (err > 0)) begin
            hold_integ = 1'b1;
        end else if ((sum_try < neg_lim_ext) && (err < 0)) begin
            hold_integ = 1'b1;
        end

        if (hold_integ) begin
            integ_next = integ;
        end else begin
            integ_next = integ_try;
        end

        sum_next = p_term + integ_next;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out   <= {DATA_W{1'b0}};
            integ <= {ACC_W{1'b0}};
            sat   <= 1'b0;
        end else if (clear) begin
            out   <= {DATA_W{1'b0}};
            integ <= {ACC_W{1'b0}};
            sat   <= 1'b0;
        end else if (en) begin
            integ <= integ_next;
            sat   <= 1'b0;

            if (sum_next > {{(ACC_W-DATA_W){pos_lim[DATA_W-1]}}, pos_lim}) begin
                out <= pos_lim;
                sat <= 1'b1;
            end else if (sum_next < {{(ACC_W-DATA_W){neg_lim[DATA_W-1]}}, neg_lim}) begin
                out <= neg_lim;
                sat <= 1'b1;
            end else begin
                out <= sum_next[DATA_W-1:0];
            end
        end
    end

endmodule
