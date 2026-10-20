`timescale 1ns/1ps

module tb_hrg_sensor_if;
    logic clk=0, nrst=0;
    logic adc_valid;
    logic signed [17:0] adc_x, adc_y;
    logic signed [13:0] temperature;
    logic spi_sclk=0, spi_csn=1, spi_mosi=0;
    wire spi_miso;
    wire signed [15:0] dac_energy, dac_quad, dac_virtual;
    wire nav_valid;
    wire signed [47:0] angle_out;
    wire signed [31:0] rate_out;
    wire [31:0] status;
    integer sample_index, nav_count, errors;

    always #5 clk = ~clk;

    hrg_sensor_if_top dut (
        .clk(clk), .nrst(nrst), .adc_valid_i(adc_valid),
        .adc_x_i(adc_x), .adc_y_i(adc_y), .temperature_i(temperature),
        .spi_sclk_i(spi_sclk), .spi_csn_i(spi_csn), .spi_mosi_i(spi_mosi),
        .spi_miso_o(spi_miso), .dac_energy_o(dac_energy),
        .dac_quad_o(dac_quad), .dac_virtual_o(dac_virtual),
        .nav_valid_o(nav_valid), .angle_o(angle_out), .rate_o(rate_out),
        .status_o(status)
    );

    task automatic spi_byte(input logic [7:0] tx, output logic [7:0] rx);
        integer b;
        begin
            rx = 0;
            for (b=7; b>=0; b=b-1) begin
                spi_mosi = tx[b];
                #50; spi_sclk = 1;
                #1; rx[b] = spi_miso;
                #49; spi_sclk = 0;
            end
        end
    endtask

    task automatic spi_write(input logic [6:0] addr, input logic [7:0] data);
        logic [7:0] dummy;
        begin
            spi_csn = 0;
            spi_byte({1'b0,addr}, dummy);
            spi_byte(data, dummy);
            #100; spi_csn = 1;
            #1000;
        end
    endtask

    task automatic drive_adc_sample(input integer idx);
        begin
            // 5 kHz coherent carrier at 40 kS/s, spatial amplitudes 0.8/0.6.
            case (idx & 7)
                0: begin adc_x= 18'sd52429; adc_y= 18'sd39322; end
                1: begin adc_x= 18'sd37073; adc_y= 18'sd27805; end
                2: begin adc_x= 18'sd0;     adc_y= 18'sd0;     end
                3: begin adc_x=-18'sd37073; adc_y=-18'sd27805; end
                4: begin adc_x=-18'sd52429; adc_y=-18'sd39322; end
                5: begin adc_x=-18'sd37073; adc_y=-18'sd27805; end
                6: begin adc_x= 18'sd0;     adc_y= 18'sd0;     end
                default: begin adc_x=18'sd37073; adc_y=18'sd27805; end
            endcase
            @(negedge clk); adc_valid=1;
            @(negedge clk); adc_valid=0;
            repeat(23) @(negedge clk);
        end
    endtask

    always @(posedge clk) if (nav_valid) nav_count <= nav_count + 1;

    initial begin
        adc_valid=0; adc_x=0; adc_y=0; temperature=14'sd2500;
        nav_count=0; errors=0;
        repeat(8) @(posedge clk);
        nrst=1;

        // Original SPIRegPG2 protocol: write byte instruction then data byte.
        spi_write(7'h00, 8'h0f); // global, energy, quadrature, virtual enables
        if (dut.ctrl_byte !== 8'h0f) begin
            $error("SPI write did not reach page-0 CTRL byte"); errors=errors+1;
        end

        for (sample_index=0; sample_index<16000; sample_index=sample_index+1)
            drive_adc_sample(sample_index);
        repeat(100) @(posedge clk);

        if (nav_count < 300) begin
            $error("Too few navigation outputs: %0d",nav_count); errors=errors+1;
        end
        if ($signed(dut.energy) < 32'sd11744051 ||
            $signed(dut.energy) > 32'sd21810381) begin
            $error("Steady energy outside 0.7..1.3 Q24: %0d",$signed(dut.energy));
            errors=errors+1;
        end
        if (dut.dsp_overflow !== 1'b0) begin
            $error("Unexpected fixed-point overflow"); errors=errors+1;
        end
        if (!status[6] || !status[22] || !status[23]) begin
            $error("Expected phase-valid/bittrue/pipeline status bits: %h",status);
            errors=errors+1;
        end
        if ($signed(dut.phase4) < 24'sd2000000 ||
            $signed(dut.phase4) > 24'sd5000000) begin
            $error("CORDIC phase outside expected quadrant: %0d",$signed(dut.phase4));
            errors=errors+1;
        end

        if (errors==0) $display("HRG_SENSOR_IF_TB PASS nav=%0d E=%0d phase4=%0d",
                                nav_count,$signed(dut.energy),$signed(dut.phase4));
        else $fatal(1,"HRG_SENSOR_IF_TB FAIL errors=%0d",errors);
        $finish;
    end

    initial begin
        #10000000;
        $fatal(1,"Test timeout");
    end
endmodule
