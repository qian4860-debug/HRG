`timescale 1ns/1ps
`include "hrg_head_config.vh"

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
    output wire signed [47:0]          angle_o,
    output wire signed [31:0]          rate_o,
    output wire [31:0]                status_o
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
    // New generated profiles write the explicit-value marker before parameters.
    // Legacy clients retain zero-selects-default semantics; explicit mode allows
    // literal zero Ki, zero hold command and other representable zero values.
    wire explicit_profile=cfg_pg0[4*8 +: 32]==32'h48524731;
    wire [31:0] cfg_energy_kp = cfg_pg0[8'h28*8 +: 32];
    wire [31:0] cfg_energy_ki = cfg_pg0[8'h2c*8 +: 32];
    wire [31:0] cfg_quad_kp   = cfg_pg0[8'h30*8 +: 32];
    wire [31:0] cfg_quad_ki   = cfg_pg0[8'h34*8 +: 32];
    wire [31:0] cfg_energy_ref= cfg_pg0[8'h40*8 +: 32];
    wire [27:0] cfg_virtual   = cfg_pg0[8'h44*8 +: 28];
    wire [31:0] cfg_nco_fcw   = cfg_pg0[8'h50*8 +: 32];
    wire [31:0] base_fcw = (!explicit_profile && cfg_nco_fcw == 0) ? `HRG_DEFAULT_NCO_FCW : cfg_nco_fcw;
    wire [31:0] pll_fcw;
    wire [31:0] nco_fcw = ctrl_byte[4] && ctrl_byte[0] ? pll_fcw:base_fcw;
    wire signed [27:0] energy_hold = !explicit_profile && cfg_pg0[8'h54*8 +: 28]==0 ? `HRG_DEFAULT_ENERGY_HOLD_Q22:cfg_pg0[8'h54*8 +: 28];
    wire signed [27:0] quad_hold = cfg_pg0[8'h58*8 +: 28];
    wire [31:0] bryan_q30 = !explicit_profile && cfg_pg0[8'h5c*8 +: 32]==0 ? `HRG_DEFAULT_BRYAN_Q30:cfg_pg0[8'h5c*8 +: 32];
    wire [30:0] rate_alpha = !explicit_profile && cfg_pg0[8'h60*8 +: 31]==0 ? `HRG_DEFAULT_RATE_ALPHA_Q30:cfg_pg0[8'h60*8 +: 31];
    wire signed [31:0] energy_kp = (!explicit_profile && cfg_energy_kp == 0) ? `HRG_DEFAULT_ENERGY_KP_Q16 : cfg_energy_kp;
    wire signed [31:0] energy_ki = (!explicit_profile && cfg_energy_ki == 0) ? `HRG_DEFAULT_ENERGY_KI_Q16 : cfg_energy_ki;
    wire signed [31:0] quad_kp   = (!explicit_profile && cfg_quad_kp == 0)   ? `HRG_DEFAULT_QUAD_KP_Q16 : cfg_quad_kp;
    wire signed [31:0] quad_ki   = (!explicit_profile && cfg_quad_ki == 0)   ? `HRG_DEFAULT_QUAD_KI_Q16 : cfg_quad_ki;
    wire signed [31:0] energy_ref= (!explicit_profile && cfg_energy_ref == 0)? `HRG_DEFAULT_ENERGY_REF_Q24 : cfg_energy_ref;

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

    wire [63:0] r_squared=$signed(inv_r)*$signed(inv_r),s_squared=$signed(inv_s)*$signed(inv_s);
    wire [64:0] magnitude_squared={1'b0,r_squared}+{1'b0,s_squared};
    // Compare against the unrounded real 0.08 threshold in Q24 code units.
    wire phase_valid=energy>=`HRG_ENERGY_VALID_Q24 && magnitude_squared>`HRG_PHASE_VALID_SQUARED_Q48 && !dsp_overflow;
    wire pll_frozen,pll_limited,pll_locked;
    hrg_dpll u_dpll(clk,nrst,dsp_valid,ctrl_byte[4] && ctrl_byte[0],phase_valid,
        energy,inv_l,base_fcw,pll_fcw,pll_frozen,pll_limited,pll_locked);
    // CTRL[5] enables STARTUP(250 ms)/ACQUIRE(>=500 ms)/RUN sequencing.
    // Otherwise software manages loop enables and the controller uses RUN math.
    reg [1:0] mode;
    reg [31:0] mode_ticks;
    wire signed [127:0] energy_window_product=$signed(energy_ref)*`HRG_ENERGY_TOL_Q30;
    wire signed [63:0] energy_window=energy_window_product>>>30;
    wire signed [63:0] energy_error=$signed({energy_ref[31],energy_ref})-$signed({energy[31],energy});
    wire energy_locked=energy_error<=energy_window && energy_error>= -energy_window;
    wire quad_locked=quad<=`HRG_QUAD_LOCK_Q24 && quad>= -`HRG_QUAD_LOCK_Q24;
    wire entering_run=ctrl_byte[0] && ctrl_byte[5] && mode==2 && mode_ticks>=(`HRG_ACQUIRE_TICKS-1) && energy_locked && quad_locked && pll_locked;
    wire [1:0] control_mode=!ctrl_byte[0] ? 2'd0:(ctrl_byte[5] ? (entering_run ? 2'd3:mode):2'd3);
    always @(posedge clk or negedge nrst) begin
        if(!nrst) begin mode<=1;mode_ticks<=0;end
        else if(dsp_valid) begin
            if(!ctrl_byte[0]) begin mode<=1;mode_ticks<=0;end
            else begin
                if(mode_ticks!=32'hffffffff) mode_ticks<=mode_ticks+1;
                if(mode==1 && mode_ticks>=(`HRG_STARTUP_TICKS-1)) begin mode<=2;mode_ticks<=0;end
                if(entering_run) begin mode<=3;mode_ticks<=0;end
            end
        end
    end
    wire cordic_busy, cordic_valid;
    wire signed [23:0] phase4;
    hrg_cordic u_cordic (
        .clk(clk), .nrst(nrst), .start_i(dsp_valid),
        .x_i(inv_r), .y_i(inv_s), .busy_o(cordic_busy),
        .valid_o(cordic_valid), .angle_o(phase4)
    );

    wire signed [27:0] energy_cmd, quad_cmd, virtual_cmd;
    wire command_valid, control_limit;
    reg signed [27:0] actual_e,actual_q,actual_v,delivered_e,delivered_q;
    reg actuator_saturated;
    hrg_controller u_controller (
        .clk(clk), .nrst(nrst), .update_i(dsp_valid), .ctrl_i(ctrl_byte[4:0]),
        .energy_i(energy), .quad_i(quad), .energy_ref_i(energy_ref),
        .energy_kp_i(energy_kp), .energy_ki_i(energy_ki),
        .quad_kp_i(quad_kp), .quad_ki_i(quad_ki),
        .virtual_cmd_i(cfg_virtual), .energy_cmd_o(energy_cmd),
        .quad_cmd_o(quad_cmd), .virtual_cmd_o(virtual_cmd),
        .command_valid_o(command_valid), .limit_event_o(control_limit),
        .mode_i(control_mode),.run_entry_i(entering_run),.tracking_valid_i(actuator_saturated),
        .energy_actual_i(actual_e),.quad_actual_i(actual_q),
        .energy_delivered_i(delivered_e),.quad_delivered_i(delivered_q),
        .energy_hold_i(energy_hold),.quad_hold_i(quad_hold)
    );
    reg snapshot_valid,snapshot_zero;
    reg signed [27:0] snapshot_virtual;
    reg signed [31:0] snapshot_energy,snapshot_quad;
    reg signed [13:0] snapshot_temperature;
    wire nav_measurement_valid,nav_unwrap_fault;
    reg [31:0] status_base;
    reg status_seen;
    assign status_o=status_seen ? ((status_base & 32'hfffbffbf) |
        (nav_measurement_valid ? 32'h40:32'h40000) |
        (nav_unwrap_fault ? 32'h20:32'd0)):32'd0;
    hrg_navigation u_navigation(clk,nrst,cordic_valid,snapshot_valid,snapshot_zero,phase4,
        snapshot_virtual,bryan_q30,rate_alpha,nav_valid_o,angle_o,rate_o,
        nav_measurement_valid,nav_unwrap_fault);
    reg [31:0] sample_count;
    reg [31:0] overflow_count;
    reg [31:0] limit_count;
    reg [31:0] nco_wrap_count;
    reg signed [63:0] de,dq,dv;
    function signed [63:0] nearest;
        input signed [63:0] n,d;
        begin nearest=n<0 ? -((-n+d/2)/d):(n+d/2)/d;end
    endfunction
    function signed [15:0] sat_dac;
        input signed [63:0] code;
        begin sat_dac=code>32767 ? 16'sd32767:(code< -32768 ? -16'sd32768:code);end
    endfunction
    wire [31:0] next_status=32'h00c00001 |
        (snapshot_valid ? 32'h40:32'h40000) |
        (dsp_overflow ? 32'h10:32'd0) |
        (control_limit ? 32'h400:32'd0) |
        (pll_frozen ? 32'h800:32'd0);

    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            status_base<=0;status_seen<=0;snapshot_valid<=0;snapshot_zero<=0;snapshot_virtual<=0;
            snapshot_energy<=0;snapshot_quad<=0;snapshot_temperature<=0;
            actual_e<=0;actual_q<=0;actual_v<=0;delivered_e<=0;delivered_q<=0;actuator_saturated<=0;
            sample_count<=0; overflow_count<=0; limit_count<=0; nco_wrap_count<=0;
            dac_energy_o<=0; dac_quad_o<=0; dac_virtual_o<=0;
            ro_wen<=0; readout_wen<=0; ro_data<=0; readout_data<=0;
        end else begin
            ro_wen <= 1'b0;
            readout_wen <= 1'b0;
            if (dsp_valid) begin
                sample_count <= sample_count + 1'b1;
                snapshot_valid<=phase_valid;snapshot_zero<=entering_run;
                snapshot_virtual<=actual_v;
                snapshot_energy<=energy;snapshot_quad<=quad;snapshot_temperature<=temperature_i;
            end
            if (dsp_valid && dsp_overflow) overflow_count <= overflow_count + 1'b1;
            if (control_limit) limit_count <= limit_count + 1'b1;
            if (nco_wrap) nco_wrap_count <= nco_wrap_count + 1'b1;

            if (command_valid) begin
                de=nearest($signed(energy_cmd)*64'sd32768,`HRG_DAC_E_FS_Q22);
                dq=nearest($signed(quad_cmd)*64'sd32768,`HRG_DAC_Q_FS_Q22);
                dv=nearest($signed(virtual_cmd)*64'sd32768,`HRG_DAC_V_FS_Q22);
                dac_energy_o<=sat_dac(de);dac_quad_o<=sat_dac(dq);dac_virtual_o<=sat_dac(dv);
                actual_e<=nearest($signed(sat_dac(de))*`HRG_DAC_E_FS_Q22,32768);
                actual_q<=nearest($signed(sat_dac(dq))*`HRG_DAC_Q_FS_Q22,32768);
                actual_v<=nearest($signed(sat_dac(dv))*`HRG_DAC_V_FS_Q22,32768);
                delivered_e<=energy_cmd;delivered_q<=quad_cmd;
                actuator_saturated<=de>32767 || de< -32768 || dq>32767 || dq< -32768;
            end

            if (cordic_valid) begin
                status_base<=next_status;status_seen<=1;
            end
            // Navigation flags/data have now been registered together. Publish
            // the SPI snapshot one clock later using that same result status.
            if(nav_valid_o) begin
                ro_data <= {phase4, snapshot_quad, snapshot_energy, status_o};
                readout_data <= {8'h00, phase4, snapshot_temperature, 2'b11, 8'h00};
                if (!ro_full) ro_wen <= 1'b1;
                if (!readout_full) readout_wen <= 1'b1;
            end
        end
    end
endmodule
