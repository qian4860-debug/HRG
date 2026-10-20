
// ============================================================================
// 详细注释补充说明
// ----------------------------------------------------------------------------
// 本模块实现可综合 CORDIC atan2，用于从 S/R 向量计算驻波角相位。
//
// 输入向量：
//   x_in = R，y_in = S。
// 输出相位：
//   phase 为 32-bit binary-turn，2^32 对应 360°。
//   在 HRG 二阶模态中 phase = 4θ 的相位。
//
// 算法说明：
//   先根据象限修正初始向量和初始相位；
//   再使用旋转模式/向量模式迭代逼近 atan2；
//   atan_lut 中保存 atan(2^-i) 对应的 binary-turn 常数。
// ============================================================================

// ============================================================================
// hrg_cordic_atan2.v
// ----------------------------------------------------------------------------
// 功能：
//   可综合 CORDIC 向量模式 atan2 计算模块。
//   输入为已解调得到的 R、S 两个正交量，输出 phi = atan2(S,R)。
//   相位采用 binary-turn 格式：
//      32'h0000_0000 = 0 turn = 0 deg
//      32'h4000_0000 = 1/4 turn = 90 deg
//      32'h8000_0000 = 1/2 turn = 180 deg 或 -180 deg
//      32'hFFFF_FFFF ≈ -1 LSB
//
// 说明：
//   1. 本模块是逐次迭代结构，ITER=32 时延约 32 个 clk。
//   2. start 拉高 1 拍后，busy 拉高；valid 拉高 1 拍时 phase 有效。
//   3. 该模块不使用 real、不使用 initial 表达式初始化寄存器，适合综合。
//   4. atan_lut 为常量查找表，单位为 32-bit binary-turn。
// ============================================================================

`timescale 1ns/1ps

module hrg_cordic_atan2 #(
    parameter IN_W  = 32,
    parameter XY_W  = 36,
    parameter ITER  = 32
)(
    input                       clk,
    input                       rst_n,

    input                       start,
    input      signed [IN_W-1:0] x_in,   // R 分量
    input      signed [IN_W-1:0] y_in,   // S 分量

    output reg                  busy,
    output reg                  valid,
    output reg        [31:0]    phase    // atan2(S,R), binary-turn
);

    reg signed [XY_W-1:0] x_reg;
    reg signed [XY_W-1:0] y_reg;
    reg        [31:0]     z_reg;
    reg        [5:0]      iter_cnt;

    wire signed [XY_W-1:0] x_shift = x_reg >>> iter_cnt;
    wire signed [XY_W-1:0] y_shift = y_reg >>> iter_cnt;

    // atan(2^-i) / (2*pi) * 2^32
    function [31:0] atan_lut;
        input [5:0] idx;
        begin
            case (idx)
            6'd 0: atan_lut = 32'h20000000;
            6'd 1: atan_lut = 32'h12E4051E;
            6'd 2: atan_lut = 32'h09FB385B;
            6'd 3: atan_lut = 32'h051111D4;
            6'd 4: atan_lut = 32'h028B0D43;
            6'd 5: atan_lut = 32'h0145D7E1;
            6'd 6: atan_lut = 32'h00A2F61E;
            6'd 7: atan_lut = 32'h00517C55;
            6'd 8: atan_lut = 32'h0028BE53;
            6'd 9: atan_lut = 32'h00145F2F;
            6'd10: atan_lut = 32'h000A2F98;
            6'd11: atan_lut = 32'h000517CC;
            6'd12: atan_lut = 32'h00028BE6;
            6'd13: atan_lut = 32'h000145F3;
            6'd14: atan_lut = 32'h0000A2FA;
            6'd15: atan_lut = 32'h0000517D;
            6'd16: atan_lut = 32'h000028BE;
            6'd17: atan_lut = 32'h0000145F;
            6'd18: atan_lut = 32'h00000A30;
            6'd19: atan_lut = 32'h00000518;
            6'd20: atan_lut = 32'h0000028C;
            6'd21: atan_lut = 32'h00000146;
            6'd22: atan_lut = 32'h000000A3;
            6'd23: atan_lut = 32'h00000051;
            6'd24: atan_lut = 32'h00000029;
            6'd25: atan_lut = 32'h00000014;
            6'd26: atan_lut = 32'h0000000A;
            6'd27: atan_lut = 32'h00000005;
            6'd28: atan_lut = 32'h00000003;
            6'd29: atan_lut = 32'h00000001;
            6'd30: atan_lut = 32'h00000001;
            6'd31: atan_lut = 32'h00000000;
            default: atan_lut = 32'h00000000;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_reg    <= {XY_W{1'b0}};
            y_reg    <= {XY_W{1'b0}};
            z_reg    <= 32'd0;
            iter_cnt <= 6'd0;
            busy     <= 1'b0;
            valid    <= 1'b0;
            phase    <= 32'd0;
        end else begin
            valid <= 1'b0;

            if (start && !busy) begin
                // 预旋转处理 x<0 的象限，使 CORDIC 收敛区间覆盖 atan2 全平面。
                // 若 (x,y) 在左半平面，则把向量取反，并给相位加 180 度。
                if (x_in[IN_W-1]) begin
                    x_reg <= -{{(XY_W-IN_W){x_in[IN_W-1]}}, x_in};
                    y_reg <= -{{(XY_W-IN_W){y_in[IN_W-1]}}, y_in};
                    z_reg <= 32'h8000_0000;
                end else begin
                    x_reg <=  {{(XY_W-IN_W){x_in[IN_W-1]}}, x_in};
                    y_reg <=  {{(XY_W-IN_W){y_in[IN_W-1]}}, y_in};
                    z_reg <= 32'h0000_0000;
                end
                iter_cnt <= 6'd0;
                busy     <= 1'b1;
            end else if (busy) begin
                // CORDIC vectoring mode:
                // 目标是把 y_reg 旋转到 0，同时累计旋转角 z_reg。
                if (!y_reg[XY_W-1]) begin
                    x_reg <= x_reg + y_shift;
                    y_reg <= y_reg - x_shift;
                    z_reg <= z_reg + atan_lut(iter_cnt);
                end else begin
                    x_reg <= x_reg - y_shift;
                    y_reg <= y_reg + x_shift;
                    z_reg <= z_reg - atan_lut(iter_cnt);
                end

                if (iter_cnt == ITER-1) begin
                    busy     <= 1'b0;
                    valid    <= 1'b1;
                    phase    <= z_reg;
                    iter_cnt <= 6'd0;
                end else begin
                    iter_cnt <= iter_cnt + 6'd1;
                end
            end
        end
    end

endmodule
