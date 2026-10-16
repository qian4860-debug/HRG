module ROReg #(
    parameter READ_OUT_SIZE = (3 + 2 + 2) * 8
)
(
    input sysClk,
    input nrst,

    // config
    input realTimeNEn,
    input [1:0] readOutRealtimeMode,

    input roRegWEn,  // sync with sysclk
    input [119 : 0] roRegWData,  // sync with sysclk
    output roRegFull,
    
    input readOutWEn,  // sync with sysclk
    input [READ_OUT_SIZE - 1 : 0] readOutWData,  // sync with sysclk
    output readOutFull,

    input lockData,  // must be sample by two sysClk period.
    input roRegREn,  // must be sample by two sysClk period.
    input readOutREn,  // must be sample by two sysClk period.
    output reg [119 : 0] regData,
    output reg [READ_OUT_SIZE - 1 : 0] readOutData
);
    reg roRegFifoREn;
    wire [119:0] roRegFifoRData;
    wire roRegFifoEmpty;
    AsyncFifo #(
        .WIDTH(120),
        .DEPTH(4)
    ) instRoRegFifo (
        .wclk(sysClk),
        .wNrst(nrst),

        .wEn(roRegWEn),
        .wData(roRegWData),
        .full(roRegFull),

        .rclk(sysClk),
        .rNrst(nrst),
        
        .rEn(roRegFifoREn),
        .rData(roRegFifoRData),
        .empty(roRegFifoEmpty)
    );

    reg readOutFifoREn;
    wire [READ_OUT_SIZE - 1 : 0] readOutFifoRData;
    wire readOutFifoEmpty;

    reg [READ_OUT_SIZE-1 : 0] readOutFIFOWData;
    reg readOutFIFOWEn;
    wire readOutFIFOFull;
    assign readOutFull = 0;
    AsyncFifo #(
        .WIDTH(READ_OUT_SIZE),
        .DEPTH(4)
    ) instReadOutFifo (
        .wclk(sysClk),
        .wNrst(nrst),
        
        .wEn(readOutFIFOWEn),
        .wData(readOutFIFOWData),
        .full(readOutFIFOFull),

        .rclk(sysClk),
        .rNrst(nrst),

        .rEn(readOutFifoREn),
        .rData(readOutFifoRData),
        .empty(readOutFifoEmpty)
    );

    // write & pop overflow
    reg popEn;
    reg popDone;
    reg writeDone;
    always @(posedge sysClk or negedge nrst) begin
        if(!nrst) begin
            popEn <= 0;
            writeDone <= 0;

            readOutFIFOWData <= 0;
            readOutFIFOWEn <= 0;
        end
        else begin
            if(readOutWEn) begin
                if(!readOutFIFOFull) begin
                    readOutFIFOWData <= readOutWData;
                    readOutFIFOWEn <= 1;
                    writeDone <= 1;
                end
                else begin
                    if(readOutRealtimeMode[1]) begin
                        popEn <= 1;
                        writeDone <= 0;
                        readOutFIFOWData <= readOutWData;
                    end
                    else begin
                        popEn <= 0;
                        writeDone <= 1;
                        readOutFIFOWData <= readOutWData;
                    end
                end
            end
            else if (!writeDone) begin
                if(popDone)
                    popEn <= 0;

                if(!readOutFIFOFull) begin
                    readOutFIFOWEn <= 1;
                    writeDone <= 1;
                end
            end
            else begin
                readOutFIFOWEn <= 0;
            end
        end
    end

    reg [1:0] roRegREnReg;
    reg [1:0] readOutREnReg;
    reg [1:0] lockDataReg;
    always @(posedge sysClk or negedge nrst) begin
        if(!nrst) begin
            roRegREnReg <= 0;
            lockDataReg <= 0;
            readOutREnReg <= 0;
        end
        else begin
            roRegREnReg <= {roRegREnReg[0], roRegREn};
            lockDataReg <= {lockDataReg[0], lockData};
            readOutREnReg <= {readOutREnReg[0], readOutREn};
        end
    end

    reg regReaded;
    always @(posedge sysClk or negedge nrst) begin
        if(!nrst) begin
            regData <= 0;
            roRegFifoREn <= 0;

            regReaded <= 1;
        end
        else begin
            if(lockDataReg == 2'b11) begin
                regData <= regData;
                roRegFifoREn <= 0;
                if(!regReaded && roRegREnReg == 2'b11) begin
                    regReaded <= 1;
                end
                else begin
                    regReaded <= regReaded;
                end
            end
            else begin
                if( (!roRegFifoEmpty) && (regReaded || ~realTimeNEn)) begin
                    regReaded <= 0;
                    regData <= roRegFifoREn ? regData : roRegFifoRData;
                    roRegFifoREn <= roRegFifoREn ? 0 : 1;
                end
                else begin
                    regReaded <= regReaded;
                    regData <= regData;
                    roRegFifoREn <= 0;
                end
            end
        end
    end

    wire [7:0] CRC_E7;
    wire [7:0] CRC_E6;
    crc8_param #(
        .POLYNOMIAL (8'h07),
        .INIT_VALUE (8'h00),
        .BYTES      ((READ_OUT_SIZE/8) - 1)
    )crc_e7_inst(
        .data_in({8'hE7, readOutFifoRData[READ_OUT_SIZE - 9 : 8]}),
        .crc_out(CRC_E7)
    );
    crc8_param #(
        .POLYNOMIAL (8'h07),
        .INIT_VALUE (8'h00),
        .BYTES      ((READ_OUT_SIZE/8) - 1)
    )crc_e6_inst(
        .data_in({8'hE6, readOutFifoRData[READ_OUT_SIZE - 9 : 8]}),
        .crc_out(CRC_E6)
    );

    reg readOutReaded;
    always @(posedge sysClk or negedge nrst) begin
        if(!nrst) begin
            readOutData <= 0;
            readOutFifoREn <= 0;

            readOutReaded <= 1;
            popDone <= 0;
        end
        else begin
            if(lockDataReg == 2'b11) begin
                readOutData <= readOutData;
                readOutFifoREn <= 0;

                if(!readOutReaded && readOutREnReg == 2'b11)
                    readOutReaded <= 1;
                else
                    readOutReaded <= readOutReaded;
            end
            else begin
                if(readOutReaded) begin
                    if(!readOutFifoEmpty) begin
                        readOutData <= {8'hE7, readOutFifoRData[READ_OUT_SIZE - 9 : 8], CRC_E7};
                        readOutReaded <= 0;
                        readOutFifoREn <= 1;
                    end
                    else begin
                        readOutData <= {8'hE6, readOutData[READ_OUT_SIZE - 9 : 8], CRC_E6};
                        readOutReaded <= readOutReaded;
                        readOutFifoREn <= 0;
                    end
                end
                else if(readOutRealtimeMode[0]) begin
                    if(popDone) begin
                        if(!readOutFIFOFull)
                            popDone <= 0;
                        readOutFifoREn <= 0;
                        readOutData <= readOutData;
                    end
                    else if(popEn) begin
                        readOutData <= {8'hE7, readOutFifoRData[READ_OUT_SIZE - 9 : 8], CRC_E7};
                        readOutFifoREn <= 1;
                        popDone <= 1;
                    end
                    else begin
                        popDone <= 0;
                        readOutData <= readOutData;
                        readOutFifoREn <= 0;
                    end
                end
                else begin
                    if(!readOutFifoEmpty) begin
                        readOutData <= {8'hE7, readOutFifoRData[READ_OUT_SIZE - 9 : 8], CRC_E7};
                        readOutReaded <= 0;
                        readOutFifoREn <= 1;
                    end
                    else begin
                        readOutFifoREn <= 0;
                    end
                end
            end
        end
    end
endmodule
