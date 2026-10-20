
// ============================================================================
// 详细注释补充说明
// ----------------------------------------------------------------------------
// 本模块由四路同步解调基带量 Cx/Sx/Cy/Sy 计算全角模式慢变量。
//
// 物理含义：
//   E：谐振能量，用于能量闭环；
//   Q：正交误差，用于正交闭环；
//   S/R：驻波角解算向量，atan2(S,R)=4θ。
//
// 定点处理：
//   输入为 Q2.30，乘法得到 Q4.60；右移 FRAC 后回到 Q2.30。
//   sat_q30 用于防止中间运算超过 32-bit 输出范围。
// ============================================================================

// ============================================================================
// hrg_eqsr_calc.v
// ----------------------------------------------------------------------------
// 根据同步解调后的四个慢变量 Cx/Sx/Cy/Sy 计算 HRG 全角模式 E/Q/S/R。
//
// 输入 Cx/Sx/Cy/Sy 格式：signed Q2.30。
// 输出 E/Q/S/R 格式：signed Q2.30。
//
// 数学关系：
//   E = Cx^2 + Sx^2 + Cy^2 + Sy^2
//   Q = 2*(Cx*Sy - Cy*Sx)
//   R = Cx^2 + Sx^2 - Cy^2 - Sy^2
//   S = 2*(Cx*Cy + Sx*Sy)
//
// 对二阶模态 HRG，atan2(S,R) = 4*theta。
// ============================================================================

`timescale 1ns/1ps

module hrg_eqsr_calc #(
    parameter DATA_W = 32,
    parameter FRAC   = 30
)(
    input                         clk,
    input                         rst_n,
    input                         in_valid,
    input signed [DATA_W-1:0]     cx,
    input signed [DATA_W-1:0]     sx,
    input signed [DATA_W-1:0]     cy,
    input signed [DATA_W-1:0]     sy,
    output reg                    out_valid,
    output reg signed [DATA_W-1:0] e_out,
    output reg signed [DATA_W-1:0] q_out,
    output reg signed [DATA_W-1:0] s_out,
    output reg signed [DATA_W-1:0] r_out
);

    wire signed [63:0] cx2_w = ($signed(cx) * $signed(cx)) >>> FRAC;
    wire signed [63:0] sx2_w = ($signed(sx) * $signed(sx)) >>> FRAC;
    wire signed [63:0] cy2_w = ($signed(cy) * $signed(cy)) >>> FRAC;
    wire signed [63:0] sy2_w = ($signed(sy) * $signed(sy)) >>> FRAC;

    wire signed [63:0] cxsy_w = ($signed(cx) * $signed(sy)) >>> FRAC;
    wire signed [63:0] cysx_w = ($signed(cy) * $signed(sx)) >>> FRAC;
    wire signed [63:0] cxcy_w = ($signed(cx) * $signed(cy)) >>> FRAC;
    wire signed [63:0] sxsy_w = ($signed(sx) * $signed(sy)) >>> FRAC;

    wire signed [63:0] e_w = cx2_w + sx2_w + cy2_w + sy2_w;
    wire signed [63:0] q_w = (cxsy_w - cysx_w) <<< 1;
    wire signed [63:0] r_w = cx2_w + sx2_w - cy2_w - sy2_w;
    wire signed [63:0] s_w = (cxcy_w + sxsy_w) <<< 1;

    function signed [DATA_W-1:0] sat_q30;
        input signed [63:0] v;
        begin
            if (v > 64'sh0000_0000_7fff_ffff)
                sat_q30 = 32'sh7fff_ffff;
            else if (v < 64'shffff_ffff_8000_0000)
                sat_q30 = 32'sh8000_0000;
            else
                sat_q30 = v[DATA_W-1:0];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            e_out <= {DATA_W{1'b0}};
            q_out <= {DATA_W{1'b0}};
            s_out <= {DATA_W{1'b0}};
            r_out <= {DATA_W{1'b0}};
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                e_out <= sat_q30(e_w);
                q_out <= sat_q30(q_w);
                s_out <= sat_q30(s_w);
                r_out <= sat_q30(r_w);
            end
        end
    end

endmodule
