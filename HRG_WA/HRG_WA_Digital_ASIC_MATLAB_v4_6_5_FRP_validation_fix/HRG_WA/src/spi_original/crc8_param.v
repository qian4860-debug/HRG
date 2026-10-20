////////////////////////////////////////////////////////////////////////////////
//  Module      : crc8_param
//  Description : Parameterizable CRC-8 module with fixed-length input.
//                Computes an 8-bit CRC checksum over BYTES bytes (BYTES*8 bits)
//                of input data in a single clock cycle using combinational logic.
//                Fully synthesizable, no registers inferred.
//
//  Parameters:
//    POLYNOMIAL  - CRC-8 generator polynomial (default: 0x07 = x^8 + x^2 + x + 1)
//    INIT_VALUE  - Initial CRC seed value (default: 0x00)
//    BYTES       - Fixed input data width in bytes (default: 32, range: 4~32)
//
//  Ports:
//    data_in     - Input data bus, BYTES*8 bits wide.
//                  Big-endian natural byte order:
//                    First byte processed     at data_in[BYTES*8-1 : BYTES*8-8] (MSB)
//                    ...
//                    Last byte processed      at data_in[7:0] (LSB)
//                  e.g. "123456789" → data_in = {8'h31, 8'h32, ..., 8'h39}
//    crc_out     - 8-bit CRC checksum output (combinational)
////////////////////////////////////////////////////////////////////////////////

module crc8_param #(
    parameter POLYNOMIAL = 8'h07,     // CRC-8 polynomial: x^8 + x^2 + x + 1
    parameter INIT_VALUE = 8'h00,     // Initial CRC register value
    parameter BYTES      = 32         // Fixed input data width in bytes (4 ~ 32)
) (
    input  wire [BYTES*8-1:0] data_in,      // Input data, big-endian natural byte order
    output wire [7:0]         crc_out        // 8-bit CRC result
);

    //----------------------------------------------------------------------
    // Function: crc8_process_byte
    // Process a single byte through the CRC-8 LFSR.
    // Implements one full 8-bit shift of the CRC engine.
    //----------------------------------------------------------------------
    function [7:0] crc8_process_byte;
        input [7:0] current_crc;     // Current CRC accumulator
        input [7:0] data_byte;       // Input data byte
        input [7:0] poly;            // Generator polynomial
        integer bit_idx;
        reg [7:0] result;
        begin
            result = current_crc ^ data_byte;
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                if (result[7])
                    result = {result[6:0], 1'b0} ^ poly;
                else
                    result = {result[6:0], 1'b0};
            end
            crc8_process_byte = result;
        end
    endfunction

    //----------------------------------------------------------------------
    // Function: crc8_compute
    // Compute CRC-8 over fixed-length input data (BYTES bytes).
    // First byte (at MSB) is processed first; last byte (at LSB) is last.
    // This matches the natural Verilog bit order where MSB=left, LSB=right.
    // The loop is fully unrolled during synthesis, producing a purely
    // combinational circuit — no registers, no byte_length mux overhead.
    //----------------------------------------------------------------------
    function [7:0] crc8_compute;
        input [BYTES*8-1:0] data;        // Full data bus
        integer byte_idx;
        reg [7:0] crc_accum;
        begin
            crc_accum = INIT_VALUE;
            // Process from MSB to LSB: byte (BYTES-1) first, byte 0 last
            for (byte_idx = BYTES-1; byte_idx >= 0; byte_idx = byte_idx - 1) begin
                crc_accum = crc8_process_byte(crc_accum,
                                              data[byte_idx*8 +: 8],
                                              POLYNOMIAL);
            end
            crc8_compute = crc_accum;
        end
    endfunction

    //----------------------------------------------------------------------
    // Combinational output assignment
    //----------------------------------------------------------------------
    assign crc_out = crc8_compute(data_in);

endmodule