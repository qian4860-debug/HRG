`timescale 1ns/1ps

// 18-cycle vectoring CORDIC. angle_o is a signed 24-bit phase word where
// +pi maps to +2^23 (and therefore wraps to the equivalent -pi code).
module hrg_cordic (
    input  wire                    clk,
    input  wire                    nrst,
    input  wire                    start_i,
    input  wire signed [31:0]       x_i,
    input  wire signed [31:0]       y_i,
    output reg                     busy_o,
    output reg                     valid_o,
    output reg signed [23:0]        angle_o
);
    reg signed [31:0] x;
    reg signed [31:0] y;
    reg signed [29:0] z;
    reg [4:0] iter;
    reg signed [31:0] x_next;
    reg signed [31:0] y_next;
    reg signed [29:0] z_next;

    function signed [29:0] atan_word;
        input [4:0] index;
        begin
            case(index)
                0:atan_word=30'sd67108864; 1:atan_word=30'sd39616676;
                2:atan_word=30'sd20932363; 3:atan_word=30'sd10625595;
                4:atan_word=30'sd5333416;  5:atan_word=30'sd2669308;
                6:atan_word=30'sd1334980;  7:atan_word=30'sd667531;
                8:atan_word=30'sd333770;   9:atan_word=30'sd166886;
                10:atan_word=30'sd83443;   11:atan_word=30'sd41722;
                12:atan_word=30'sd20861;   13:atan_word=30'sd10430;
                14:atan_word=30'sd5215;    15:atan_word=30'sd2608;
                16:atan_word=30'sd1304;    default:atan_word=30'sd652;
            endcase
        end
    endfunction

    always @(*) begin
        if (y >= 0) begin
            x_next = x + (y >>> iter);
            y_next = y - (x >>> iter);
            z_next = z + atan_word(iter);
        end else begin
            x_next = x - (y >>> iter);
            y_next = y + (x >>> iter);
            z_next = z - atan_word(iter);
        end
    end

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            x<=0; y<=0; z<=0; iter<=0; busy_o<=0; valid_o<=0; angle_o<=0;
        end else begin
            valid_o <= 1'b0;
            if (start_i && !busy_o) begin
                iter <= 0;
                busy_o <= 1'b1;
                if (x_i < 0) begin
                    x <= -x_i;
                    y <= -y_i;
                    z <= (y_i >= 0) ? 30'sd268435456 : -30'sd268435456;
                end else begin
                    x <= x_i;
                    y <= y_i;
                    z <= 0;
                end
            end else if (busy_o) begin
                x <= x_next;
                y <= y_next;
                z <= z_next;
                if (iter == 17) begin
                    angle_o <= z_next >>> 5;
                    valid_o <= 1'b1;
                    busy_o <= 1'b0;
                end else begin
                    iter <= iter + 1'b1;
                end
            end
        end
    end
endmodule
