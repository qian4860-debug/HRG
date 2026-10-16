module SPIRegPG2 #(
    parameter READ_OUT_SIZE = (3 + 2 + 2) * 8
)
(
    input sysClk,
    input nrst,

    // config
    input realTimeNEn,
    input [1:0] readOutRealtimeMode,
    input burstMode,
    input RWMixEn,

    // Internal RW Interface
    input intWEn,
    input intREn,
    input intPageSel,
    input [7:0] intAddr,
    input [7:0] intWData,
    input intUsePgReg,
    output [7:0] intRData,
    output intWDone,

    // read only Reg
    input roDataWEn,
    input [15*8 - 1 : 0] roData,
    output roDataFull,

    // read out Data
    input readOutWEn,
    input [READ_OUT_SIZE - 1 : 0] readOutWData,
    output readOutFull,

    // Regs
    output [112*8 - 1 : 0] configRegPG0,
    output [112*8 - 1 : 0] configRegPG1,
    output [112*8 - 1 : 0] configRegPG2,

    output [15*8 - 1 : 0]  exConfigReg,

    // SPI Interface
    input sclk,
    input csn,
    input mosi,
    output miso
);
    wire nSck;
    assign nSck = ~sclk;

    wire [7:0] rwRegAddrSPI;

    wire roRegREn;
    wire readOutREn;
    wire [15*8 - 1 : 0] roRegData;
    wire [READ_OUT_SIZE - 1 : 0] readOutData;

    wire rwFifoFull;
    wire rwFifoWEn;
    wire roRegLockData;
    wire [15:0] rwFifoWData;
    SPIRegSlave #(
        .READ_OUT_SIZE(READ_OUT_SIZE)
    ) instSPISlave (
        .nrst           (nrst),
        .burstMode      (burstMode),
        .RWMixEn        (RWMixEn),

        .nSck           (nSck),
        .sclk           (sclk),
        .csn            (csn),
        .mosi           (mosi),
        .miso           (miso),

        .rwRegAddr      (rwRegAddrSPI),
        .rwRegData      (intRData),

        .roRegREn       (roRegREn),
        .readOutREn     (readOutREn),
        .roRegLockData  (roRegLockData),
        .roRegData      (roRegData),
        .readOutData    (readOutData),

        .rwFifoFull     (rwFifoFull),
        .rwFifoWEn      (rwFifoWEn),
        .rwFifoWData    (rwFifoWData)
    );

    reg [7:0] regReadAddr;
    always @(*) begin
        regReadAddr = intREn ? intAddr : rwRegAddrSPI;
    end
    RWRegPG2 instRWReg (
        .sysClk         (sysClk),
        .nrst           (nrst),

        .wFifoClk       (nSck),
        .wFifoFull      (rwFifoFull),
        .wFifowEn       (rwFifoWEn),
        .wData          (rwFifoWData),

        .intUsePgReg    (intUsePgReg),
        .intWEn         (intWEn),
        .intREn         (intREn),
        .intPageSel     (intPageSel),
        .intWDone       (intWDone),
        .intWData       ({intAddr, intWData}),

        .rAddr          (regReadAddr),
        .rData          (intRData),

        .configRegPG0   (configRegPG0),
        .configRegPG1   (configRegPG1),
        .configRegPG2   (configRegPG2),
        .exConfigReg    (exConfigReg)
    );

    ROReg #(
        .READ_OUT_SIZE(READ_OUT_SIZE)
    ) instRoReg (
        .sysClk         (sysClk),
        .nrst           (nrst),

        .realTimeNEn            (realTimeNEn),
        .readOutRealtimeMode    (readOutRealtimeMode),

        .roRegWEn       (roDataWEn),
        .roRegWData     (roData),
        .roRegFull      (roDataFull),

        .readOutWEn     (readOutWEn),
        .readOutWData   (readOutWData),
        .readOutFull    (readOutFull),

        .lockData       (roRegLockData),
        .roRegREn       (roRegREn),
        .readOutREn     (readOutREn),
        .regData        (roRegData),
        .readOutData    (readOutData)
    );

endmodule
