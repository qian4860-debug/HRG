
// ============================================================================
// 详细注释补充说明
// ----------------------------------------------------------------------------
// 本模块是 5 抽头对称 FIR 低通，系数为 [1 4 6 4 1]/16。
//
// 作用：
//   在 CIC 抽取后进一步抑制残余载波纹波和抽取镜像；
//   同时保持结构简单，便于 FPGA/ASIC 实现。
//
// 由于系数和为 16，最终右移 4 位完成归一化，不需要通用乘法器。
// ============================================================================

// ============================================================================
// hrg_fir5_lpf.v
// ----------------------------------------------------------------------------
// 五抽头二项式低通 FIR： [1 4 6 4 1] / 16。
// 用在 CIC 抽取后，进一步抑制残余载波和抽取镜像。
// ============================================================================

`timescale 1ns/1ps

module hrg_fir5_lpf #(
    parameter DATA_W = 32
)(
    input                         clk,
    input                         rst_n,
    input                         in_valid,
    input signed [DATA_W-1:0]     din,
    output reg                    out_valid,
    output reg signed [DATA_W-1:0] dout
);

    reg signed [DATA_W-1:0] z0, z1, z2, z3, z4;
    wire signed [DATA_W+4:0] acc =
        {{5{din[DATA_W-1]}}, din} +
        ({{5{z0[DATA_W-1]}}, z0} <<< 2) +
        ({{5{z1[DATA_W-1]}}, z1} <<< 2) + ({{5{z1[DATA_W-1]}}, z1} <<< 1) +
        ({{5{z2[DATA_W-1]}}, z2} <<< 2) +
        {{5{z3[DATA_W-1]}}, z3};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            z0 <= {DATA_W{1'b0}};
            z1 <= {DATA_W{1'b0}};
            z2 <= {DATA_W{1'b0}};
            z3 <= {DATA_W{1'b0}};
            z4 <= {DATA_W{1'b0}};
            dout <= {DATA_W{1'b0}};
            out_valid <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            if (in_valid) begin
                z0 <= din;
                z1 <= z0;
                z2 <= z1;
                z3 <= z2;
                z4 <= z3;
                dout <= acc >>> 4;
                out_valid <= 1'b1;
            end
        end
    end

endmodule
