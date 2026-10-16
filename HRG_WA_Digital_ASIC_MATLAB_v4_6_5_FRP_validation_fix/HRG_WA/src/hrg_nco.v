`timescale 1ns/1ps

// 32-bit phase accumulator and 18-bit quarter-wave ROM NCO.
// The ROM uses the midpoint of each of 64 segments in a quadrant.
module hrg_nco (
    input  wire                    clk,
    input  wire                    nrst,
    input  wire                    sample_en,
    input  wire [31:0]             fcw,
    output reg  signed [17:0]       cos_o,
    output reg  signed [17:0]       sin_o,
    output reg  [31:0]              phase_o,
    output reg                      wrap_pulse_o
);
    reg [31:0] phase_acc;
    wire [31:0] phase_next = phase_acc + fcw;
    wire signed [17:0] sin_next;
    wire signed [17:0] cos_next;

    hrg_sin_lut u_sin (.phase_i(phase_next),              .value_o(sin_next));
    hrg_sin_lut u_cos (.phase_i(phase_next + 32'h40000000), .value_o(cos_next));

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            phase_acc    <= 32'd0;
            phase_o      <= 32'd0;
            sin_o        <= 18'sd0;
            cos_o        <= 18'sd131071;
            wrap_pulse_o <= 1'b0;
        end else begin
            wrap_pulse_o <= 1'b0;
            if (sample_en) begin
                phase_acc    <= phase_next;
                phase_o      <= phase_next;
                sin_o        <= sin_next;
                cos_o        <= cos_next;
                wrap_pulse_o <= (phase_next < phase_acc);
            end
        end
    end
endmodule

module hrg_sin_lut (
    input  wire [31:0]          phase_i,
    output reg signed [17:0]    value_o
);
    wire [1:0] quadrant = phase_i[31:30];
    wire [5:0] raw_idx  = phase_i[29:24];
    wire [5:0] lut_idx  = quadrant[0] ? (6'd63 - raw_idx) : raw_idx;
    reg signed [17:0] magnitude;

    always @(*) begin
        case (lut_idx)
            6'd0: magnitude=18'sd1608; 6'd1: magnitude=18'sd4824;
            6'd2: magnitude=18'sd8037; 6'd3: magnitude=18'sd11246;
            6'd4: magnitude=18'sd14447; 6'd5: magnitude=18'sd17640;
            6'd6: magnitude=18'sd20822; 6'd7: magnitude=18'sd23991;
            6'd8: magnitude=18'sd27146; 6'd9: magnitude=18'sd30285;
            6'd10: magnitude=18'sd33405; 6'd11: magnitude=18'sd36506;
            6'd12: magnitude=18'sd39584; 6'd13: magnitude=18'sd42639;
            6'd14: magnitude=18'sd45668; 6'd15: magnitude=18'sd48669;
            6'd16: magnitude=18'sd51641; 6'd17: magnitude=18'sd54582;
            6'd18: magnitude=18'sd57490; 6'd19: magnitude=18'sd60363;
            6'd20: magnitude=18'sd63200; 6'd21: magnitude=18'sd65999;
            6'd22: magnitude=18'sd68758; 6'd23: magnitude=18'sd71476;
            6'd24: magnitude=18'sd74151; 6'd25: magnitude=18'sd76781;
            6'd26: magnitude=18'sd79365; 6'd27: magnitude=18'sd81901;
            6'd28: magnitude=18'sd84388; 6'd29: magnitude=18'sd86823;
            6'd30: magnitude=18'sd89207; 6'd31: magnitude=18'sd91537;
            6'd32: magnitude=18'sd93812; 6'd33: magnitude=18'sd96030;
            6'd34: magnitude=18'sd98190; 6'd35: magnitude=18'sd100291;
            6'd36: magnitude=18'sd102332; 6'd37: magnitude=18'sd104311;
            6'd38: magnitude=18'sd106227; 6'd39: magnitude=18'sd108080;
            6'd40: magnitude=18'sd109867; 6'd41: magnitude=18'sd111588;
            6'd42: magnitude=18'sd113242; 6'd43: magnitude=18'sd114827;
            6'd44: magnitude=18'sd116344; 6'd45: magnitude=18'sd117790;
            6'd46: magnitude=18'sd119166; 6'd47: magnitude=18'sd120469;
            6'd48: magnitude=18'sd121700; 6'd49: magnitude=18'sd122858;
            6'd50: magnitude=18'sd123942; 6'd51: magnitude=18'sd124951;
            6'd52: magnitude=18'sd125885; 6'd53: magnitude=18'sd126743;
            6'd54: magnitude=18'sd127524; 6'd55: magnitude=18'sd128229;
            6'd56: magnitude=18'sd128857; 6'd57: magnitude=18'sd129407;
            6'd58: magnitude=18'sd129879; 6'd59: magnitude=18'sd130272;
            6'd60: magnitude=18'sd130588; 6'd61: magnitude=18'sd130824;
            6'd62: magnitude=18'sd130982; default: magnitude=18'sd131061;
        endcase
        value_o = quadrant[1] ? -magnitude : magnitude;
    end
endmodule
