// 五电极数字核内部的定点算术、CORDIC 和载波查表。
// 统一 Q24。乘法和 DAC 编码以最近值舍入，负数半码远离零。
function signed [63:0] mulq;
    input signed [63:0] a,b;
    reg signed [127:0] p;
    begin
        p = a*b;
        if (p < 0)
            mulq = -(((-p)+128'sd8388608) >>> 24);
        else
            mulq = (p+128'sd8388608) >>> 24;
    end
endfunction

function signed [63:0] divq;
    input signed [63:0] a,b;
    reg signed [127:0] dividend;
    begin
        dividend = a;
        divq = (dividend <<< 24)/b;
    end
endfunction

// 每行使用四个 Q24 系数。低位存储第一个系数。
function signed [63:0] matrow;
    input [255:0] coeff;
    input signed [63:0] a,b,c,d;
    begin
        matrow = mulq($signed(coeff[63:0]),a)+mulq($signed(coeff[127:64]),b)+
                 mulq($signed(coeff[191:128]),c)+mulq($signed(coeff[255:192]),d);
    end
endfunction

function signed [63:0] dac_quantize;
    input signed [63:0] voltage;
    reg signed [63:0] magnitude,code;
    begin
        magnitude = voltage < 0 ? -voltage : voltage;
        code = (magnitude+(64'sd1 <<< (23-DAC_BITS))) >>> (24-DAC_BITS);
        if (voltage < 0) code = -code;
        if (code < DAC_MIN) code = DAC_MIN;
        if (code > DAC_MAX) code = DAC_MAX;
        dac_quantize = code;
    end
endfunction

// 非负 Q24 开平方。每一步处理两位，输出仍为 Q24。
function signed [63:0] sqrtq;
    input [63:0] value;
    reg [87:0] remain,root,trial;
    integer i;
    begin
        remain = {value,24'd0};
        root = 0;
        trial = 88'd1 << 86;
        for (i=0;i<44;i=i+1) begin
            if (remain >= root+trial) begin
                remain = remain-root-trial;
                root = (root >> 1)+trial;
            end else begin
                root = root >> 1;
            end
            trial = trial >> 2;
        end
        sqrtq = root[63:0];
    end
endfunction

function signed [63:0] cordic_angle;
    input [4:0] i;
    begin
        case (i)
                5'd0: cordic_angle = 64'sd13176795;
                5'd1: cordic_angle = 64'sd7778716;
                5'd2: cordic_angle = 64'sd4110060;
                5'd3: cordic_angle = 64'sd2086331;
                5'd4: cordic_angle = 64'sd1047214;
                5'd5: cordic_angle = 64'sd524117;
                5'd6: cordic_angle = 64'sd262123;
                5'd7: cordic_angle = 64'sd131069;
                5'd8: cordic_angle = 64'sd65536;
                5'd9: cordic_angle = 64'sd32768;
                5'd10: cordic_angle = 64'sd16384;
                5'd11: cordic_angle = 64'sd8192;
                5'd12: cordic_angle = 64'sd4096;
                5'd13: cordic_angle = 64'sd2048;
                5'd14: cordic_angle = 64'sd1024;
                5'd15: cordic_angle = 64'sd512;
                5'd16: cordic_angle = 64'sd256;
                5'd17: cordic_angle = 64'sd128;
                5'd18: cordic_angle = 64'sd64;
                5'd19: cordic_angle = 64'sd32;
                5'd20: cordic_angle = 64'sd16;
                5'd21: cordic_angle = 64'sd8;
                5'd22: cordic_angle = 64'sd4;
                5'd23: cordic_angle = 64'sd2;
                5'd24: cordic_angle = 64'sd1;
            default: cordic_angle = 0;
        endcase
    end
endfunction

// 向量模式得到 atan2，先将左半平面转入右半平面。
function signed [63:0] atan2q;
    input signed [63:0] y0,x0;
    reg signed [63:0] x,y,z,nx;
    integer i;
    begin
        // 扩大内部向量坐标，减小小幅 Stokes 向量的移位误差。
        x = x0 <<< 12;
        y = y0 <<< 12;
        z = 0;
        if (x0 < 0) begin
            x = -x; y = -y;
            z = y0 < 0 ? -PI_Q : PI_Q;
        end
        for (i=0;i<25;i=i+1) begin
            if (y > 0) begin
                nx = x+(y >>> i);
                y = y-(x >>> i);
                x = nx;
                z = z+cordic_angle(i[4:0]);
            end else if (y < 0) begin
                nx = x-(y >>> i);
                y = y+(x >>> i);
                x = nx;
                z = z-cordic_angle(i[4:0]);
            end
        end
        atan2q = z;
    end
endfunction

// 旋转模式同时计算 cos 和 sin。控制器的输入相位位于 ±π/2。
function [127:0] sincosq;
    input signed [63:0] phase_in;
    reg signed [63:0] x,y,z,nx;
    integer i;
    begin
        x = 64'sd10188014; y = 0; z = phase_in;
        for (i=0;i<25;i=i+1) begin
            if (z >= 0) begin
                nx = x-(y >>> i);
                y = y+(x >>> i);
                x = nx;
                z = z-cordic_angle(i[4:0]);
            end else begin
                nx = x+(y >>> i);
                y = y-(x >>> i);
                x = nx;
                z = z+cordic_angle(i[4:0]);
            end
        end
        sincosq = {x,y};
    end
endfunction

// 800 点相位栅格的 1/4 周期 ROM。连续版每拍跨五点，分时版每拍跨一点。
function signed [63:0] quarter_sine;
    input [7:0] index;
    begin
        case (index)
                8'd0: quarter_sine = 64'sd0;
                8'd1: quarter_sine = 64'sd131767;
                8'd2: quarter_sine = 64'sd263525;
                8'd3: quarter_sine = 64'sd395267;
                8'd4: quarter_sine = 64'sd526985;
                8'd5: quarter_sine = 64'sd658670;
                8'd6: quarter_sine = 64'sd790315;
                8'd7: quarter_sine = 64'sd921911;
                8'd8: quarter_sine = 64'sd1053450;
                8'd9: quarter_sine = 64'sd1184924;
                8'd10: quarter_sine = 64'sd1316325;
                8'd11: quarter_sine = 64'sd1447645;
                8'd12: quarter_sine = 64'sd1578875;
                8'd13: quarter_sine = 64'sd1710009;
                8'd14: quarter_sine = 64'sd1841036;
                8'd15: quarter_sine = 64'sd1971950;
                8'd16: quarter_sine = 64'sd2102743;
                8'd17: quarter_sine = 64'sd2233405;
                8'd18: quarter_sine = 64'sd2363930;
                8'd19: quarter_sine = 64'sd2494310;
                8'd20: quarter_sine = 64'sd2624535;
                8'd21: quarter_sine = 64'sd2754598;
                8'd22: quarter_sine = 64'sd2884492;
                8'd23: quarter_sine = 64'sd3014207;
                8'd24: quarter_sine = 64'sd3143737;
                8'd25: quarter_sine = 64'sd3273072;
                8'd26: quarter_sine = 64'sd3402206;
                8'd27: quarter_sine = 64'sd3531130;
                8'd28: quarter_sine = 64'sd3659836;
                8'd29: quarter_sine = 64'sd3788317;
                8'd30: quarter_sine = 64'sd3916563;
                8'd31: quarter_sine = 64'sd4044568;
                8'd32: quarter_sine = 64'sd4172324;
                8'd33: quarter_sine = 64'sd4299822;
                8'd34: quarter_sine = 64'sd4427055;
                8'd35: quarter_sine = 64'sd4554015;
                8'd36: quarter_sine = 64'sd4680694;
                8'd37: quarter_sine = 64'sd4807084;
                8'd38: quarter_sine = 64'sd4933178;
                8'd39: quarter_sine = 64'sd5058967;
                8'd40: quarter_sine = 64'sd5184445;
                8'd41: quarter_sine = 64'sd5309602;
                8'd42: quarter_sine = 64'sd5434432;
                8'd43: quarter_sine = 64'sd5558927;
                8'd44: quarter_sine = 64'sd5683079;
                8'd45: quarter_sine = 64'sd5806881;
                8'd46: quarter_sine = 64'sd5930324;
                8'd47: quarter_sine = 64'sd6053401;
                8'd48: quarter_sine = 64'sd6176105;
                8'd49: quarter_sine = 64'sd6298428;
                8'd50: quarter_sine = 64'sd6420363;
                8'd51: quarter_sine = 64'sd6541901;
                8'd52: quarter_sine = 64'sd6663036;
                8'd53: quarter_sine = 64'sd6783760;
                8'd54: quarter_sine = 64'sd6904065;
                8'd55: quarter_sine = 64'sd7023945;
                8'd56: quarter_sine = 64'sd7143391;
                8'd57: quarter_sine = 64'sd7262397;
                8'd58: quarter_sine = 64'sd7380954;
                8'd59: quarter_sine = 64'sd7499057;
                8'd60: quarter_sine = 64'sd7616697;
                8'd61: quarter_sine = 64'sd7733867;
                8'd62: quarter_sine = 64'sd7850560;
                8'd63: quarter_sine = 64'sd7966768;
                8'd64: quarter_sine = 64'sd8082485;
                8'd65: quarter_sine = 64'sd8197704;
                8'd66: quarter_sine = 64'sd8312417;
                8'd67: quarter_sine = 64'sd8426617;
                8'd68: quarter_sine = 64'sd8540298;
                8'd69: quarter_sine = 64'sd8653451;
                8'd70: quarter_sine = 64'sd8766071;
                8'd71: quarter_sine = 64'sd8878150;
                8'd72: quarter_sine = 64'sd8989682;
                8'd73: quarter_sine = 64'sd9100659;
                8'd74: quarter_sine = 64'sd9211074;
                8'd75: quarter_sine = 64'sd9320922;
                8'd76: quarter_sine = 64'sd9430194;
                8'd77: quarter_sine = 64'sd9538885;
                8'd78: quarter_sine = 64'sd9646987;
                8'd79: quarter_sine = 64'sd9754495;
                8'd80: quarter_sine = 64'sd9861400;
                8'd81: quarter_sine = 64'sd9967697;
                8'd82: quarter_sine = 64'sd10073380;
                8'd83: quarter_sine = 64'sd10178441;
                8'd84: quarter_sine = 64'sd10282874;
                8'd85: quarter_sine = 64'sd10386673;
                8'd86: quarter_sine = 64'sd10489831;
                8'd87: quarter_sine = 64'sd10592342;
                8'd88: quarter_sine = 64'sd10694200;
                8'd89: quarter_sine = 64'sd10795398;
                8'd90: quarter_sine = 64'sd10895930;
                8'd91: quarter_sine = 64'sd10995790;
                8'd92: quarter_sine = 64'sd11094972;
                8'd93: quarter_sine = 64'sd11193469;
                8'd94: quarter_sine = 64'sd11291276;
                8'd95: quarter_sine = 64'sd11388387;
                8'd96: quarter_sine = 64'sd11484795;
                8'd97: quarter_sine = 64'sd11580494;
                8'd98: quarter_sine = 64'sd11675479;
                8'd99: quarter_sine = 64'sd11769744;
                8'd100: quarter_sine = 64'sd11863283;
                8'd101: quarter_sine = 64'sd11956090;
                8'd102: quarter_sine = 64'sd12048160;
                8'd103: quarter_sine = 64'sd12139486;
                8'd104: quarter_sine = 64'sd12230064;
                8'd105: quarter_sine = 64'sd12319887;
                8'd106: quarter_sine = 64'sd12408951;
                8'd107: quarter_sine = 64'sd12497248;
                8'd108: quarter_sine = 64'sd12584775;
                8'd109: quarter_sine = 64'sd12671526;
                8'd110: quarter_sine = 64'sd12757495;
                8'd111: quarter_sine = 64'sd12842677;
                8'd112: quarter_sine = 64'sd12927067;
                8'd113: quarter_sine = 64'sd13010660;
                8'd114: quarter_sine = 64'sd13093450;
                8'd115: quarter_sine = 64'sd13175432;
                8'd116: quarter_sine = 64'sd13256601;
                8'd117: quarter_sine = 64'sd13336953;
                8'd118: quarter_sine = 64'sd13416482;
                8'd119: quarter_sine = 64'sd13495184;
                8'd120: quarter_sine = 64'sd13573053;
                8'd121: quarter_sine = 64'sd13650085;
                8'd122: quarter_sine = 64'sd13726275;
                8'd123: quarter_sine = 64'sd13801618;
                8'd124: quarter_sine = 64'sd13876109;
                8'd125: quarter_sine = 64'sd13949745;
                8'd126: quarter_sine = 64'sd14022521;
                8'd127: quarter_sine = 64'sd14094431;
                8'd128: quarter_sine = 64'sd14165472;
                8'd129: quarter_sine = 64'sd14235639;
                8'd130: quarter_sine = 64'sd14304928;
                8'd131: quarter_sine = 64'sd14373335;
                8'd132: quarter_sine = 64'sd14440855;
                8'd133: quarter_sine = 64'sd14507484;
                8'd134: quarter_sine = 64'sd14573219;
                8'd135: quarter_sine = 64'sd14638054;
                8'd136: quarter_sine = 64'sd14701986;
                8'd137: quarter_sine = 64'sd14765012;
                8'd138: quarter_sine = 64'sd14827127;
                8'd139: quarter_sine = 64'sd14888327;
                8'd140: quarter_sine = 64'sd14948609;
                8'd141: quarter_sine = 64'sd15007969;
                8'd142: quarter_sine = 64'sd15066403;
                8'd143: quarter_sine = 64'sd15123907;
                8'd144: quarter_sine = 64'sd15180479;
                8'd145: quarter_sine = 64'sd15236114;
                8'd146: quarter_sine = 64'sd15290810;
                8'd147: quarter_sine = 64'sd15344562;
                8'd148: quarter_sine = 64'sd15397368;
                8'd149: quarter_sine = 64'sd15449224;
                8'd150: quarter_sine = 64'sd15500126;
                8'd151: quarter_sine = 64'sd15550073;
                8'd152: quarter_sine = 64'sd15599061;
                8'd153: quarter_sine = 64'sd15647086;
                8'd154: quarter_sine = 64'sd15694147;
                8'd155: quarter_sine = 64'sd15740239;
                8'd156: quarter_sine = 64'sd15785360;
                8'd157: quarter_sine = 64'sd15829507;
                8'd158: quarter_sine = 64'sd15872678;
                8'd159: quarter_sine = 64'sd15914870;
                8'd160: quarter_sine = 64'sd15956081;
                8'd161: quarter_sine = 64'sd15996307;
                8'd162: quarter_sine = 64'sd16035546;
                8'd163: quarter_sine = 64'sd16073796;
                8'd164: quarter_sine = 64'sd16111055;
                8'd165: quarter_sine = 64'sd16147319;
                8'd166: quarter_sine = 64'sd16182588;
                8'd167: quarter_sine = 64'sd16216859;
                8'd168: quarter_sine = 64'sd16250129;
                8'd169: quarter_sine = 64'sd16282397;
                8'd170: quarter_sine = 64'sd16313660;
                8'd171: quarter_sine = 64'sd16343917;
                8'd172: quarter_sine = 64'sd16373166;
                8'd173: quarter_sine = 64'sd16401405;
                8'd174: quarter_sine = 64'sd16428633;
                8'd175: quarter_sine = 64'sd16454846;
                8'd176: quarter_sine = 64'sd16480045;
                8'd177: quarter_sine = 64'sd16504228;
                8'd178: quarter_sine = 64'sd16527392;
                8'd179: quarter_sine = 64'sd16549537;
                8'd180: quarter_sine = 64'sd16570661;
                8'd181: quarter_sine = 64'sd16590762;
                8'd182: quarter_sine = 64'sd16609841;
                8'd183: quarter_sine = 64'sd16627895;
                8'd184: quarter_sine = 64'sd16644923;
                8'd185: quarter_sine = 64'sd16660924;
                8'd186: quarter_sine = 64'sd16675898;
                8'd187: quarter_sine = 64'sd16689843;
                8'd188: quarter_sine = 64'sd16702758;
                8'd189: quarter_sine = 64'sd16714643;
                8'd190: quarter_sine = 64'sd16725497;
                8'd191: quarter_sine = 64'sd16735320;
                8'd192: quarter_sine = 64'sd16744110;
                8'd193: quarter_sine = 64'sd16751867;
                8'd194: quarter_sine = 64'sd16758591;
                8'd195: quarter_sine = 64'sd16764281;
                8'd196: quarter_sine = 64'sd16768937;
                8'd197: quarter_sine = 64'sd16772559;
                8'd198: quarter_sine = 64'sd16775146;
                8'd199: quarter_sine = 64'sd16776699;
                8'd200: quarter_sine = 64'sd16777216;
            default: quarter_sine = 0;
        endcase
    end
endfunction

function signed [63:0] carrier_sine;
    input [9:0] phase_in;
    begin
        if (phase_in < 200)
            carrier_sine = quarter_sine(phase_in[7:0]);
        else if (phase_in < 400)
            carrier_sine = quarter_sine(400-phase_in);
        else if (phase_in < 600)
            carrier_sine = -quarter_sine(phase_in-400);
        else
            carrier_sine = -quarter_sine(800-phase_in);
    end
endfunction
