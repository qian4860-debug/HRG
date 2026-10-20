
// ============================================================================
// 详细注释补充说明
// ----------------------------------------------------------------------------
// 本模块是可综合 NCO + sin/cos 查表参考源。
//
// phase_acc 每个 raw_valid/en 有效拍累加 phase_inc：
//   f_out = phase_inc / 2^32 * f_clk_en
// 例如 f_clk_en=64 kHz、f_out=8 kHz 时：
//   phase_inc = 2^32 * 8000 / 64000 = 0x2000_0000。
//
// ROM 说明：
//   使用 phase[31:24] 作为 256 点整周期查表地址。
//   sin_ref/cos_ref 输出为 signed Q1.15。
//   当前实现使用 case ROM，便于综合到 LUT/ROM，也便于 ASIC 迁移为查表 ROM。
// ============================================================================

// ============================================================================
// hrg_nco_sincos.v
// ----------------------------------------------------------------------------
// 可综合 NCO 正弦/余弦参考发生器。
//
// phase_acc 采用 32-bit binary-turn：2^32 对应 360 度。
// 取 phase_acc[31:24] 查 256 点正弦 ROM，输出 signed Q1.15。
// cos 通过 sin(index+64) 得到。
//
// 该实现为了便于 ASIC/FPGA 原型验证，使用常量 case ROM。
// FPGA 综合会推断为 LUT/ROM；ASIC 可替换为查找表 ROM 或 CORDIC。
// ============================================================================

`timescale 1ns/1ps

module hrg_nco_sincos #(
    parameter PHASE_W = 32,
    parameter OUT_W   = 16
)(
    input                       clk,
    input                       rst_n,
    input                       en,
    input      [PHASE_W-1:0]    phase_inc,
    input      [PHASE_W-1:0]    phase_offset,
    output reg signed [OUT_W-1:0] sin_ref,
    output reg signed [OUT_W-1:0] cos_ref,
    output reg                  ref_valid,
    output reg [PHASE_W-1:0]    phase_acc
);

    wire [7:0] addr_sin = phase_acc[31:24];
    wire [7:0] addr_cos = phase_acc[31:24] + 8'd64;

    function signed [15:0] sin_lut;
        input [7:0] a;
        begin
            case (a)
                8'd  0: sin_lut = 16'sd0;
                8'd  1: sin_lut = 16'sd804;
                8'd  2: sin_lut = 16'sd1608;
                8'd  3: sin_lut = 16'sd2410;
                8'd  4: sin_lut = 16'sd3212;
                8'd  5: sin_lut = 16'sd4011;
                8'd  6: sin_lut = 16'sd4808;
                8'd  7: sin_lut = 16'sd5602;
                8'd  8: sin_lut = 16'sd6393;
                8'd  9: sin_lut = 16'sd7179;
                8'd 10: sin_lut = 16'sd7962;
                8'd 11: sin_lut = 16'sd8739;
                8'd 12: sin_lut = 16'sd9512;
                8'd 13: sin_lut = 16'sd10278;
                8'd 14: sin_lut = 16'sd11039;
                8'd 15: sin_lut = 16'sd11793;
                8'd 16: sin_lut = 16'sd12539;
                8'd 17: sin_lut = 16'sd13279;
                8'd 18: sin_lut = 16'sd14010;
                8'd 19: sin_lut = 16'sd14732;
                8'd 20: sin_lut = 16'sd15446;
                8'd 21: sin_lut = 16'sd16151;
                8'd 22: sin_lut = 16'sd16846;
                8'd 23: sin_lut = 16'sd17530;
                8'd 24: sin_lut = 16'sd18204;
                8'd 25: sin_lut = 16'sd18868;
                8'd 26: sin_lut = 16'sd19519;
                8'd 27: sin_lut = 16'sd20159;
                8'd 28: sin_lut = 16'sd20787;
                8'd 29: sin_lut = 16'sd21403;
                8'd 30: sin_lut = 16'sd22005;
                8'd 31: sin_lut = 16'sd22594;
                8'd 32: sin_lut = 16'sd23170;
                8'd 33: sin_lut = 16'sd23731;
                8'd 34: sin_lut = 16'sd24279;
                8'd 35: sin_lut = 16'sd24811;
                8'd 36: sin_lut = 16'sd25329;
                8'd 37: sin_lut = 16'sd25832;
                8'd 38: sin_lut = 16'sd26319;
                8'd 39: sin_lut = 16'sd26790;
                8'd 40: sin_lut = 16'sd27245;
                8'd 41: sin_lut = 16'sd27683;
                8'd 42: sin_lut = 16'sd28105;
                8'd 43: sin_lut = 16'sd28510;
                8'd 44: sin_lut = 16'sd28898;
                8'd 45: sin_lut = 16'sd29268;
                8'd 46: sin_lut = 16'sd29621;
                8'd 47: sin_lut = 16'sd29956;
                8'd 48: sin_lut = 16'sd30273;
                8'd 49: sin_lut = 16'sd30571;
                8'd 50: sin_lut = 16'sd30852;
                8'd 51: sin_lut = 16'sd31113;
                8'd 52: sin_lut = 16'sd31356;
                8'd 53: sin_lut = 16'sd31580;
                8'd 54: sin_lut = 16'sd31785;
                8'd 55: sin_lut = 16'sd31971;
                8'd 56: sin_lut = 16'sd32137;
                8'd 57: sin_lut = 16'sd32285;
                8'd 58: sin_lut = 16'sd32412;
                8'd 59: sin_lut = 16'sd32521;
                8'd 60: sin_lut = 16'sd32609;
                8'd 61: sin_lut = 16'sd32678;
                8'd 62: sin_lut = 16'sd32728;
                8'd 63: sin_lut = 16'sd32757;
                8'd 64: sin_lut = 16'sd32767;
                8'd 65: sin_lut = 16'sd32757;
                8'd 66: sin_lut = 16'sd32728;
                8'd 67: sin_lut = 16'sd32678;
                8'd 68: sin_lut = 16'sd32609;
                8'd 69: sin_lut = 16'sd32521;
                8'd 70: sin_lut = 16'sd32412;
                8'd 71: sin_lut = 16'sd32285;
                8'd 72: sin_lut = 16'sd32137;
                8'd 73: sin_lut = 16'sd31971;
                8'd 74: sin_lut = 16'sd31785;
                8'd 75: sin_lut = 16'sd31580;
                8'd 76: sin_lut = 16'sd31356;
                8'd 77: sin_lut = 16'sd31113;
                8'd 78: sin_lut = 16'sd30852;
                8'd 79: sin_lut = 16'sd30571;
                8'd 80: sin_lut = 16'sd30273;
                8'd 81: sin_lut = 16'sd29956;
                8'd 82: sin_lut = 16'sd29621;
                8'd 83: sin_lut = 16'sd29268;
                8'd 84: sin_lut = 16'sd28898;
                8'd 85: sin_lut = 16'sd28510;
                8'd 86: sin_lut = 16'sd28105;
                8'd 87: sin_lut = 16'sd27683;
                8'd 88: sin_lut = 16'sd27245;
                8'd 89: sin_lut = 16'sd26790;
                8'd 90: sin_lut = 16'sd26319;
                8'd 91: sin_lut = 16'sd25832;
                8'd 92: sin_lut = 16'sd25329;
                8'd 93: sin_lut = 16'sd24811;
                8'd 94: sin_lut = 16'sd24279;
                8'd 95: sin_lut = 16'sd23731;
                8'd 96: sin_lut = 16'sd23170;
                8'd 97: sin_lut = 16'sd22594;
                8'd 98: sin_lut = 16'sd22005;
                8'd 99: sin_lut = 16'sd21403;
                8'd100: sin_lut = 16'sd20787;
                8'd101: sin_lut = 16'sd20159;
                8'd102: sin_lut = 16'sd19519;
                8'd103: sin_lut = 16'sd18868;
                8'd104: sin_lut = 16'sd18204;
                8'd105: sin_lut = 16'sd17530;
                8'd106: sin_lut = 16'sd16846;
                8'd107: sin_lut = 16'sd16151;
                8'd108: sin_lut = 16'sd15446;
                8'd109: sin_lut = 16'sd14732;
                8'd110: sin_lut = 16'sd14010;
                8'd111: sin_lut = 16'sd13279;
                8'd112: sin_lut = 16'sd12539;
                8'd113: sin_lut = 16'sd11793;
                8'd114: sin_lut = 16'sd11039;
                8'd115: sin_lut = 16'sd10278;
                8'd116: sin_lut = 16'sd9512;
                8'd117: sin_lut = 16'sd8739;
                8'd118: sin_lut = 16'sd7962;
                8'd119: sin_lut = 16'sd7179;
                8'd120: sin_lut = 16'sd6393;
                8'd121: sin_lut = 16'sd5602;
                8'd122: sin_lut = 16'sd4808;
                8'd123: sin_lut = 16'sd4011;
                8'd124: sin_lut = 16'sd3212;
                8'd125: sin_lut = 16'sd2410;
                8'd126: sin_lut = 16'sd1608;
                8'd127: sin_lut = 16'sd804;
                8'd128: sin_lut = 16'sd0;
                8'd129: sin_lut = -16'sd804;
                8'd130: sin_lut = -16'sd1608;
                8'd131: sin_lut = -16'sd2410;
                8'd132: sin_lut = -16'sd3212;
                8'd133: sin_lut = -16'sd4011;
                8'd134: sin_lut = -16'sd4808;
                8'd135: sin_lut = -16'sd5602;
                8'd136: sin_lut = -16'sd6393;
                8'd137: sin_lut = -16'sd7179;
                8'd138: sin_lut = -16'sd7962;
                8'd139: sin_lut = -16'sd8739;
                8'd140: sin_lut = -16'sd9512;
                8'd141: sin_lut = -16'sd10278;
                8'd142: sin_lut = -16'sd11039;
                8'd143: sin_lut = -16'sd11793;
                8'd144: sin_lut = -16'sd12539;
                8'd145: sin_lut = -16'sd13279;
                8'd146: sin_lut = -16'sd14010;
                8'd147: sin_lut = -16'sd14732;
                8'd148: sin_lut = -16'sd15446;
                8'd149: sin_lut = -16'sd16151;
                8'd150: sin_lut = -16'sd16846;
                8'd151: sin_lut = -16'sd17530;
                8'd152: sin_lut = -16'sd18204;
                8'd153: sin_lut = -16'sd18868;
                8'd154: sin_lut = -16'sd19519;
                8'd155: sin_lut = -16'sd20159;
                8'd156: sin_lut = -16'sd20787;
                8'd157: sin_lut = -16'sd21403;
                8'd158: sin_lut = -16'sd22005;
                8'd159: sin_lut = -16'sd22594;
                8'd160: sin_lut = -16'sd23170;
                8'd161: sin_lut = -16'sd23731;
                8'd162: sin_lut = -16'sd24279;
                8'd163: sin_lut = -16'sd24811;
                8'd164: sin_lut = -16'sd25329;
                8'd165: sin_lut = -16'sd25832;
                8'd166: sin_lut = -16'sd26319;
                8'd167: sin_lut = -16'sd26790;
                8'd168: sin_lut = -16'sd27245;
                8'd169: sin_lut = -16'sd27683;
                8'd170: sin_lut = -16'sd28105;
                8'd171: sin_lut = -16'sd28510;
                8'd172: sin_lut = -16'sd28898;
                8'd173: sin_lut = -16'sd29268;
                8'd174: sin_lut = -16'sd29621;
                8'd175: sin_lut = -16'sd29956;
                8'd176: sin_lut = -16'sd30273;
                8'd177: sin_lut = -16'sd30571;
                8'd178: sin_lut = -16'sd30852;
                8'd179: sin_lut = -16'sd31113;
                8'd180: sin_lut = -16'sd31356;
                8'd181: sin_lut = -16'sd31580;
                8'd182: sin_lut = -16'sd31785;
                8'd183: sin_lut = -16'sd31971;
                8'd184: sin_lut = -16'sd32137;
                8'd185: sin_lut = -16'sd32285;
                8'd186: sin_lut = -16'sd32412;
                8'd187: sin_lut = -16'sd32521;
                8'd188: sin_lut = -16'sd32609;
                8'd189: sin_lut = -16'sd32678;
                8'd190: sin_lut = -16'sd32728;
                8'd191: sin_lut = -16'sd32757;
                8'd192: sin_lut = -16'sd32767;
                8'd193: sin_lut = -16'sd32757;
                8'd194: sin_lut = -16'sd32728;
                8'd195: sin_lut = -16'sd32678;
                8'd196: sin_lut = -16'sd32609;
                8'd197: sin_lut = -16'sd32521;
                8'd198: sin_lut = -16'sd32412;
                8'd199: sin_lut = -16'sd32285;
                8'd200: sin_lut = -16'sd32137;
                8'd201: sin_lut = -16'sd31971;
                8'd202: sin_lut = -16'sd31785;
                8'd203: sin_lut = -16'sd31580;
                8'd204: sin_lut = -16'sd31356;
                8'd205: sin_lut = -16'sd31113;
                8'd206: sin_lut = -16'sd30852;
                8'd207: sin_lut = -16'sd30571;
                8'd208: sin_lut = -16'sd30273;
                8'd209: sin_lut = -16'sd29956;
                8'd210: sin_lut = -16'sd29621;
                8'd211: sin_lut = -16'sd29268;
                8'd212: sin_lut = -16'sd28898;
                8'd213: sin_lut = -16'sd28510;
                8'd214: sin_lut = -16'sd28105;
                8'd215: sin_lut = -16'sd27683;
                8'd216: sin_lut = -16'sd27245;
                8'd217: sin_lut = -16'sd26790;
                8'd218: sin_lut = -16'sd26319;
                8'd219: sin_lut = -16'sd25832;
                8'd220: sin_lut = -16'sd25329;
                8'd221: sin_lut = -16'sd24811;
                8'd222: sin_lut = -16'sd24279;
                8'd223: sin_lut = -16'sd23731;
                8'd224: sin_lut = -16'sd23170;
                8'd225: sin_lut = -16'sd22594;
                8'd226: sin_lut = -16'sd22005;
                8'd227: sin_lut = -16'sd21403;
                8'd228: sin_lut = -16'sd20787;
                8'd229: sin_lut = -16'sd20159;
                8'd230: sin_lut = -16'sd19519;
                8'd231: sin_lut = -16'sd18868;
                8'd232: sin_lut = -16'sd18204;
                8'd233: sin_lut = -16'sd17530;
                8'd234: sin_lut = -16'sd16846;
                8'd235: sin_lut = -16'sd16151;
                8'd236: sin_lut = -16'sd15446;
                8'd237: sin_lut = -16'sd14732;
                8'd238: sin_lut = -16'sd14010;
                8'd239: sin_lut = -16'sd13279;
                8'd240: sin_lut = -16'sd12539;
                8'd241: sin_lut = -16'sd11793;
                8'd242: sin_lut = -16'sd11039;
                8'd243: sin_lut = -16'sd10278;
                8'd244: sin_lut = -16'sd9512;
                8'd245: sin_lut = -16'sd8739;
                8'd246: sin_lut = -16'sd7962;
                8'd247: sin_lut = -16'sd7179;
                8'd248: sin_lut = -16'sd6393;
                8'd249: sin_lut = -16'sd5602;
                8'd250: sin_lut = -16'sd4808;
                8'd251: sin_lut = -16'sd4011;
                8'd252: sin_lut = -16'sd3212;
                8'd253: sin_lut = -16'sd2410;
                8'd254: sin_lut = -16'sd1608;
                8'd255: sin_lut = -16'sd804;
                default: sin_lut = 16'sd0;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc <= {PHASE_W{1'b0}};
            sin_ref   <= {OUT_W{1'b0}};
            cos_ref   <= {OUT_W{1'b0}};
            ref_valid <= 1'b0;
        end else begin
            ref_valid <= 1'b0;
            if (en) begin
                phase_acc <= phase_acc + phase_inc;
                sin_ref   <= sin_lut(addr_sin + phase_offset[31:24]);
                cos_ref   <= sin_lut(addr_cos + phase_offset[31:24]);
                ref_valid <= 1'b1;
            end
        end
    end

endmodule
