module RWRegPG2 (
    input sysClk,
    input nrst,

    // SPI Write
    input wFifoClk,
    output wFifoFull,
    input wFifowEn,
    input [15:0] wData, // addr + data

    // Int Write
    input intWEn,
    input intREn,
    input intPageSel,
    input [15:0] intWData, // addr + data
    output reg intWDone,
    input intUsePgReg,

    input [7:0] rAddr,
    output reg [7:0] rData,

    output [112*8 - 1:0] configRegPG0,
    output [112*8 - 1:0] configRegPG1,
    output [112*8 - 1:0] configRegPG2,

    output [15*8 - 1 : 0] exConfigReg // base 0x71
);
    reg [7:0] regFile [2:0][111:0];
    // pageCtrl: exRegFile[0][0x70]
    reg [7:0] exRegFile [15:0];

    reg fifoREn;
    wire [15:0] fifoRData;
    wire fifoEmpty;
    AsyncFifo #(
        .WIDTH(16),
        .DEPTH(16)
    ) instFifo (
        .wclk(wFifoClk),
        .wNrst(nrst),

        .wEn(wFifowEn),
        .wData(wData),
        .full(wFifoFull),
        
        .rclk(sysClk),
        .rNrst(nrst),

        .rEn(fifoREn),
        .rData(fifoRData),
        .empty(fifoEmpty)
    );

    reg regWEn;
    reg [7:0] regWData;
    reg [7:0] addr;
    reg [3:0] exAddr;
    reg [1:0] regWPage;
    reg isExReg;
    always @(posedge sysClk or negedge nrst) begin
        if(!nrst) begin
            regWEn <= 0;
            fifoREn <= 0;

            regWData <= 0;
            addr <= 0;
            exAddr <= 0;
            regWPage <= 0;
            isExReg <= 0;

            intWDone <= 0;
        end
        else begin
            if(!fifoREn && intWEn && ~intWDone) begin
                regWEn <= 1;

                regWData <= intWData[7:0];
                addr <= {1'b0, intWData[14:8]};
                exAddr <= intWData[11:8];
                regWPage <= intUsePgReg ? exRegFile[0][1:0] : {1'b0, intPageSel};
                isExReg <= intWData[14:8] < 7'h70 ? 0 : 1;

                intWDone <= 1;
            end
            else if(!fifoREn && !fifoEmpty && !intWEn) begin
                regWEn <= 1;

                regWData <= fifoRData[7:0];
                addr <= {1'b0, fifoRData[14:8]};
                exAddr <= fifoRData[11:8];
                regWPage <= exRegFile[0][1:0];
                isExReg <= fifoRData[14:8] < 7'h70 ? 0 : 1;

                intWDone <= 0;
            end
            else begin
                intWDone <= 0;
                regWEn <= 0;
            end

            if(fifoREn == 1)
                fifoREn <= 0;
            else if(!fifoEmpty && !intWEn) begin
                fifoREn <= 1;
            end
            else begin
                fifoREn <= 0;
            end
        end
    end

    /**** write Reg ****/
    integer i;
    integer k;
    always @(posedge sysClk or negedge nrst ) begin
        if(!nrst) begin
            for(k = 0; k < 3; k = k + 1) begin
                for(i = 0; i < 112; i = i + 1)
                    regFile[k][i] <= 0;
            end
            for(i = 0; i < 16; i = i + 1)
                exRegFile[i] <= 0;
        end
        else begin
            if(regWEn) begin
                if(isExReg)
                    exRegFile[exAddr] <= regWData[7:0];
                else if(addr < 8'h70) begin
                    if(regWPage <= 2)
                        regFile[regWPage][addr] <= regWData[7:0];
                end
            end
        end
    end

    /**** read Reg ****/
    wire [1:0] rPage;
    assign rPage = (intREn && ~intUsePgReg) ? {1'b0, intPageSel} : exRegFile[0][1:0];
    always @(*) begin
        if(rAddr[6:0] < 112)
            if(rPage <= 2)
                rData = regFile[rPage][rAddr[6:0]];
            else
                rData = 0;
        else
            rData = exRegFile[rAddr[3:0]];
    end
    
    genvar j;
    generate
        for(j = 0; j < 112; j = j + 1) begin
            assign configRegPG0[j * 8 + 7: j * 8] = regFile[0][j];
        end
        for(j = 0; j < 112; j = j + 1) begin
            assign configRegPG1[j * 8 + 7: j * 8] = regFile[1][j];
        end
        for(j = 0; j < 112; j = j + 1) begin
            assign configRegPG2[j * 8 + 7: j * 8] = regFile[2][j];
        end
        for(j = 0; j < 15; j = j + 1) begin
            assign exConfigReg[j * 8 + 7: j * 8] = exRegFile[j + 1];
        end
    endgenerate
endmodule
