`timescale 1ns/1ps

module hrg_sensor_if_top (
    input  wire                       clk,
    input  wire                       nrst,
    input  wire                       adc_valid_i,
    input  wire signed [17:0]          adc_x_i,
    input  wire signed [17:0]          adc_y_i,
    input  wire signed [13:0]          temperature_i,
    input  wire                       spi_sclk_i,
    input  wire                       spi_csn_i,
    input  wire                       spi_mosi_i,
    output wire                       spi_miso_o,
    output reg signed [15:0]           dac_energy_o,
    output reg signed [15:0]           dac_quad_o,
    output reg signed [15:0]           dac_virtual_o,
    output wire                       nav_valid_o,
    output reg signed [47:0]           angle_o,
    output reg signed [31:0]           rate_o,
    output reg [31:0]                 status_o
);
    wire [895:0] cfg_pg0, cfg_pg1, cfg_pg2;
    wire [119:0] ext_cfg;
    wire [7:0] int_rdata;
    wire int_wdone;
    wire ro_full, readout_full;
    reg ro_wen, readout_wen;
    reg [119:0] ro_data;
    reg [55:0] readout_data;

    SPIRegPG2 #(.READ_OUT_SIZE(56)) u_spi (
        .sysClk(clk), .nrst(nrst), .realTimeNEn(1'b0),
        .readOutRealtimeMode(2'b10), .burstMode(1'b0), .RWMixEn(1'b0),
        .intWEn(1'b0), .intREn(1'b0), .intPageSel(1'b0), .intAddr(8'd0),
        .intWData(8'd0), .intUsePgReg(1'b1), .intRData(int_rdata),
        .intWDone(int_wdone), .roDataWEn(ro_wen), .roData(ro_data),
        .roDataFull(ro_full), .readOutWEn(readout_wen),
        .readOutWData(readout_data), .readOutFull(readout_full),
        .configRegPG0(cfg_pg0), .configRegPG1(cfg_pg1),
        .configRegPG2(cfg_pg2), .exConfigReg(ext_cfg),
        .sclk(spi_sclk_i), .csn(spi_csn_i), .mosi(spi_mosi_i), .miso(spi_miso_o)
    );

    // Native SPI register bytes are little-endian within each 32-bit word.
    wire [7:0] ctrl_byte = cfg_pg0[0*8 +: 8];
    wire [31:0] cfg_energy_kp = cfg_pg0[8'h28*8 +: 32];
    wire [31:0] cfg_energy_ki = cfg_pg0[8'h2c*8 +: 32];
    wire [31:0] cfg_quad_kp   = cfg_pg0[8'h30*8 +: 32];
    wire [31:0] cfg_quad_ki   = cfg_pg0[8'h34*8 +: 32];
    wire [31:0] cfg_energy_ref= cfg_pg0[8'h40*8 +: 32];
    wire [27:0] cfg_virtual   = cfg_pg0[8'h44*8 +: 28];
    wire [31:0] cfg_nco_fcw   = cfg_pg0[8'h50*8 +: 32];
    wire [31:0] nco_fcw = (cfg_nco_fcw == 0) ? 32'h20000000 : cfg_nco_fcw;
    wire signed [31:0] energy_kp = (cfg_energy_kp == 0) ? 32'sd157286 : cfg_energy_kp;
    wire signed [31:0] energy_ki = (cfg_energy_ki == 0) ? 32'sd22938  : cfg_energy_ki;
    wire signed [31:0] quad_kp   = (cfg_quad_kp == 0)   ? 32'sd458752 : cfg_quad_kp;
    wire signed [31:0] quad_ki   = (cfg_quad_ki == 0)   ? 32'sd91750  : cfg_quad_ki;
    wire signed [31:0] energy_ref= (cfg_energy_ref == 0)? 32'sd16777216 : cfg_energy_ref;

    wire dsp_valid, dsp_overflow, nco_wrap;
    wire signed [27:0] cx, sx, cy, sy;
    wire signed [31:0] energy, quad, inv_r, inv_s, inv_l;
    wire [31:0] nco_phase;
    hrg_dsp_core u_dsp (
        .clk(clk), .nrst(nrst), .adc_valid_i(adc_valid_i),
        .adc_x_i(adc_x_i), .adc_y_i(adc_y_i), .nco_fcw_i(nco_fcw),
        .ctrl_valid_o(dsp_valid), .cx_o(cx), .sx_o(sx), .cy_o(cy), .sy_o(sy),
        .energy_o(energy), .quad_o(quad), .r_o(inv_r), .s_o(inv_s),
        .pll_l_o(inv_l), .overflow_o(dsp_overflow), .nco_phase_o(nco_phase),
        .nco_wrap_o(nco_wrap)
    );

    wire phase_valid = (energy > 32'sd1342177) &&
                       (($signed(inv_r) > 32'sd1342177) || ($signed(inv_r) < -32'sd1342177) ||
                        ($signed(inv_s) > 32'sd1342177) || ($signed(inv_s) < -32'sd1342177));
    wire cordic_busy, cordic_valid;
    wire signed [23:0] phase4;
    hrg_cordic u_cordic (
        .clk(clk), .nrst(nrst), .start_i(dsp_valid && phase_valid),
        .x_i(inv_r), .y_i(inv_s), .busy_o(cordic_busy),
        .valid_o(cordic_valid), .angle_o(phase4)
    );

    wire signed [27:0] energy_cmd, quad_cmd, virtual_cmd;
    wire command_valid, control_limit;
    hrg_controller u_controller (
        .clk(clk), .nrst(nrst), .update_i(dsp_valid), .ctrl_i(ctrl_byte[4:0]),
        .energy_i(energy), .quad_i(quad), .energy_ref_i(energy_ref),
        .energy_kp_i(energy_kp), .energy_ki_i(energy_ki),
        .quad_kp_i(quad_kp), .quad_ki_i(quad_ki),
        .virtual_cmd_i(cfg_virtual), .energy_cmd_o(energy_cmd),
        .quad_cmd_o(quad_cmd), .virtual_cmd_o(virtual_cmd),
        .command_valid_o(command_valid), .limit_event_o(control_limit)
    );

    reg signed [23:0] phase4_prev;
    reg phase_seen;
    reg signed [24:0] phase_delta;
    reg [31:0] sample_count;
    reg [31:0] overflow_count;
    reg [31:0] limit_count;
    reg [31:0] nco_wrap_count;
    reg signed [63:0] dac_tmp;
    assign nav_valid_o = cordic_valid;

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            phase4_prev<=0; phase_seen<=0; phase_delta<=0;
            angle_o<=0; rate_o<=0; status_o<=0;
            sample_count<=0; overflow_count<=0; limit_count<=0; nco_wrap_count<=0;
            dac_energy_o<=0; dac_quad_o<=0; dac_virtual_o<=0;
            ro_wen<=0; readout_wen<=0; ro_data<=0; readout_data<=0;
        end else begin
            ro_wen <= 1'b0;
            readout_wen <= 1'b0;
            if (dsp_valid) sample_count <= sample_count + 1'b1;
            if (dsp_valid && dsp_overflow) overflow_count <= overflow_count + 1'b1;
            if (control_limit) limit_count <= limit_count + 1'b1;
            if (nco_wrap) nco_wrap_count <= nco_wrap_count + 1'b1;

            if (command_valid) begin
                dac_tmp = $signed(energy_cmd) * 32767;
                dac_energy_o <= dac_tmp / 2516582;
                dac_tmp = $signed(quad_cmd) * 32767;
                dac_quad_o <= dac_tmp / 2097152;
                dac_tmp = $signed(virtual_cmd) * 32767;
                dac_virtual_o <= dac_tmp / 2928177;
            end

            if (cordic_valid) begin
                if (phase_seen) begin
                    phase_delta = $signed(phase4 - phase4_prev);
                    angle_o <= angle_o + (phase_delta >>> 2);
                    rate_o <= (phase_delta >>> 2) * 1000;
                end else begin
                    phase_seen <= 1'b1;
                end
                phase4_prev <= phase4;
                status_o <= 32'h00c00001 |
                            (phase_valid ? 32'h00000040 : 32'h00040000) |
                            (dsp_overflow ? 32'h00000010 : 32'h00000000) |
                            (control_limit ? 32'h00000400 : 32'h00000000);
                ro_data <= {phase4, quad, energy, status_o};
                readout_data <= {8'h00, phase4, temperature_i, 2'b11, 8'h00};
                if (!ro_full) ro_wen <= 1'b1;
                if (!readout_full) readout_wen <= 1'b1;
            end
        end
    end
endmodule
