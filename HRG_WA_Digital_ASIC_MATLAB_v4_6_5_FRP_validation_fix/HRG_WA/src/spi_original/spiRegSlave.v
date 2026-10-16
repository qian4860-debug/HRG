module SPIRegSlave #(
    parameter READ_OUT_SIZE = (3 + 2 + 2) * 8,

    parameter RO_REG_SIZE = 15 * 8,
    parameter INS_READ_OUT = 8'hF0
)
(
    input nrst,

    // config
    input burstMode,
    input RWMixEn,

    input sclk,
    input nSck,
    input csn,
    input mosi,
    output reg miso,

    output [7:0] rwRegAddr,
    input [7:0] rwRegData,

    output reg roRegREn,
    output reg readOutREn,
    output roRegLockData,
    input [RO_REG_SIZE - 1 : 0] roRegData,
    input [READ_OUT_SIZE - 1 : 0] readOutData,

    input rwFifoFull,
    output reg rwFifoWEn,
    output [15:0] rwFifoWData
);

    wire cs = ~csn;

    reg[12:0] cnt;
    wire [2:0] bitCnt;
    wire [8:0] ByteCnt; // 512Byte Max
    assign bitCnt = cnt[2:0];
    assign ByteCnt = cnt[11:3];
    always @(posedge sclk or negedge cs) begin
        if(!cs) begin
            cnt <= 0;
        end
        else if(!nrst) begin
            cnt <= 0;
        end
        else begin
            if(!cnt[12])
                cnt <= cnt + 1;
            else
                cnt <= cnt;
        end
    end

    /*** Recieve ***/
    reg [7:0] rxData;
    always @(posedge sclk or negedge cs) begin
        if(!cs) begin
            rxData <= 8'hFF;
        end
        else if(!nrst) begin
            rxData <= 8'hFF;
        end
        else begin
            rxData <= {rxData[6:0], mosi};
        end
    end

    // get instruction
    reg [7:0] ins;
    reg [8:0] insByteCnt;
    reg [8:0] nextByteCnt;
    reg [1:0] burst;
    reg rwMode;
    wire [6:0] nextAddr;
    wire [7:0] nextIns;
    assign nextAddr = ins[6:0] + 1;
    assign nextIns = {ins[7], nextAddr};

    always @(posedge nSck or negedge cs) begin // negedge @ sclk
        if(!cs) begin
            ins <= 0;

            insByteCnt <= 0;
            nextByteCnt <= 0;
            rwMode <= 0;
            burst <= 2'b01;
        end
        else if(!nrst) begin
            ins <= 0;

            insByteCnt <= 0;
            nextByteCnt <= 0;
            rwMode <= 0;
            burst <= 2'b01;
        end
        else begin
            // rwMode
            if(ByteCnt == 0 && bitCnt == 1) begin
                rwMode <= rxData[0];
            end
            else begin
                rwMode <= rwMode;
            end

            // burst
            if(ByteCnt == 0) begin
                burst <= burst;
            end
            else if(ByteCnt == nextByteCnt && bitCnt == 1) begin
                if(burstMode && ~RWMixEn) begin
                    if(!burst[1]) begin
                        if(ins[7] == rxData[0]) begin
                            burst <= 2'b11;
                        end
                        else begin
                            burst <= 2'b10;
                        end
                    end
                    else begin
                        if(burst[0] && rxData[0] != rwMode) begin
                            burst[0] <= 0;
                        end
                        else begin
                            burst <= burst;
                        end
                    end
                end
                else begin
                    burst <= 2'b11;
                end
            end
            else 
                burst <= burst;

            // nextByteCnt
            if(ByteCnt == (nextByteCnt + 1) && bitCnt == 0) begin
                if(burstMode) begin
                    if(rxData[7:0] == INS_READ_OUT)
                        nextByteCnt <= nextByteCnt + (READ_OUT_SIZE/8);
                    else if(!rxData[7])
                        nextByteCnt <= nextByteCnt + 2;
                    else
                        nextByteCnt <= nextByteCnt + 1;
                end
                else begin
                    if((ByteCnt == 1 ? rxData[7:0] : nextIns[7:0]) == INS_READ_OUT)
                        nextByteCnt <= nextByteCnt + (READ_OUT_SIZE/8);
                    else
                        nextByteCnt <= nextByteCnt + 1;
                end
            end
            else
                nextByteCnt <= nextByteCnt;

            // ins
            if(ByteCnt == 1 && bitCnt == 0) begin
                ins <= rxData[7:0];
                insByteCnt <= 0;
            end
            else if(ByteCnt == (nextByteCnt + 1) && bitCnt == 0) begin
                if(burstMode) begin
                    if(burst[0]) begin
                        ins <= rxData[7:0];
                        insByteCnt <= nextByteCnt;
                    end
                    else begin
                        ins <= ins;
                        insByteCnt <= insByteCnt;
                    end
                end
                else begin
                    ins <= nextIns;
                    insByteCnt <= nextByteCnt;
                end
            end
            else begin
                ins <= ins;
                insByteCnt <= insByteCnt;
            end
        end
    end

    // write Reg
    assign rwFifoWData = {1'b0, ins[6:0], rxData[7:0]};
    always @(posedge nSck or negedge cs) begin // negedge @ sclk
        if(!cs) begin
            rwFifoWEn <= 0;
        end
        else if(!nrst) begin
            rwFifoWEn <= 0;
        end
        else begin
            if(ByteCnt == (insByteCnt + 1) && bitCnt == 7) begin
                if((~ins[7]) && (!rwFifoFull)) begin
                    rwFifoWEn <= 1;
                end
                else begin
                    rwFifoWEn <= 0;
                end
            end
            else
                rwFifoWEn <= 0;
        end
    end

    // read reg
    assign roRegLockData = ~csn;
    wire [7:0] insImm;
    assign insImm = burstMode ? rxData : 
                    ~(ByteCnt == (nextByteCnt + 1) && bitCnt == 0) ? nextIns :
                    ByteCnt == 1 ? rxData : nextIns ;
    always @(posedge nSck or negedge cs) begin // negedge @ sclk
        if(!cs) begin
            roRegREn <= 0;
            readOutREn <= 0;
        end
        else if(!nrst) begin
            roRegREn <= 0;
            readOutREn <= 0;
        end
        else begin
            if(roRegREn) begin
                roRegREn <= 1;
            end
            else begin
                if(ByteCnt == (nextByteCnt + 1) && bitCnt == 0) begin
                    if(insImm[7:4] == 4'hF && (insImm[3:0])) begin // todo
                        roRegREn <= 1;
                    end
                    else begin
                        roRegREn <= 0;
                    end
                end
            end

            if(readOutREn) begin
                readOutREn <= 1;
            end
            else begin
                if(ByteCnt == (nextByteCnt + 1) && bitCnt == 0) begin
                    if(insImm[7:4] == 4'hF && (!insImm[3:0])) begin // todo
                        readOutREn <= 1;
                    end
                    else begin
                        readOutREn <= 0;
                    end
                end
            end
        end
    end

    /*** transmit ***/
    // insDec
    wire [7:0] ins2Dec;
    wire [4:0] curInsByteCnt;
    wire [4:0] readOutIdx;
    assign ins2Dec = (ByteCnt == (nextByteCnt + 1) && bitCnt == 0) ? 
                        (burst[0] ? insImm[7:0] : ins[7:0])
                        : ins[7:0];
    assign curInsByteCnt = ByteCnt - insByteCnt;
    assign readOutIdx = (READ_OUT_SIZE / 8) - curInsByteCnt;

    reg [7:0] txData;
    assign rwRegAddr = (ins2Dec[6:0] < 7'd112) ? {1'b0, ins2Dec[6:0]} : 8'd0;
    always @(*) begin
        if(ins2Dec[7]) begin
            case (ins2Dec[6:0])
                7'h7F: txData = roRegData[14*8+7 : 14*8];
                7'h7E: txData = roRegData[13*8+7 : 13*8];
                7'h7D: txData = roRegData[12*8+7 : 12*8];
                7'h7C: txData = roRegData[11*8+7 : 11*8];
                7'h7B: txData = roRegData[10*8+7 : 10*8];
                7'h7A: txData = roRegData[ 9*8+7 :  9*8];
                7'h79: txData = roRegData[ 8*8+7 :  8*8];
                7'h78: txData = roRegData[ 7*8+7 :  7*8];
                7'h77: txData = roRegData[ 6*8+7 :  6*8];
                7'h76: txData = roRegData[ 5*8+7 :  5*8];
                7'h75: txData = roRegData[ 4*8+7 :  4*8];
                7'h74: txData = roRegData[ 3*8+7 :  3*8];
                7'h73: txData = roRegData[ 2*8+7 :  2*8];
                7'h72: txData = roRegData[ 1*8+7 :  1*8];
                7'h71: txData = roRegData[ 0*8+7 :  0*8];
                7'h70: begin
                    if(curInsByteCnt > (READ_OUT_SIZE / 8)) begin
                        txData = 0;
                    end
                    else begin
                        txData = readOutData[{readOutIdx, 3'b000} +: 8];
                    end
                end
                default: begin
                    txData = rwRegData;
                end
            endcase
        end
        else
            txData = 0;
    end

    reg transmitEn;
    always @(posedge nSck or negedge cs) begin // negedge @ sclk
        if(!cs) begin
            transmitEn <= 0;
        end
        else if(!nrst) begin
            transmitEn <= 0;
        end
        else begin
            if(ByteCnt == nextByteCnt && bitCnt == 7) begin
                if((burstMode | (ByteCnt == 0)) ? rxData[6] : insImm[7])
                    transmitEn <= 1;
                else
                    transmitEn <= 0;
            end
            else begin
                transmitEn <= transmitEn;
            end
        end
    end

    always @(posedge nSck or negedge cs) begin // negedge @ sclk
        if(!cs) begin
            miso <= 0;
        end
        else if(!nrst) begin
            miso <= 0;
        end
        else begin
            if(transmitEn) begin
                miso <= txData[(~bitCnt)];
            end
            else begin
                miso <= 0;
            end
        end
    end

endmodule
