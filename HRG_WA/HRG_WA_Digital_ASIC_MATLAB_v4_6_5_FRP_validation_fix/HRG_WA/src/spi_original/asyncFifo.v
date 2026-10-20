module AsyncFifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 8
)
(
    input wclk,
    input wNrst,

    input wEn,
    input [WIDTH - 1 : 0] wData,
    output full,

    input rclk,
    input rNrst,
    
    input rEn,
    output [WIDTH - 1 : 0] rData,
    output empty

);
    localparam ADDR_WIDTH = DEPTH == 1 ? 1 : $clog2(DEPTH);

    wire fifoNrst = wNrst & rNrst;

    wire memWEn;
    wire [ADDR_WIDTH - 1 : 0] wAddr;
    wire [ADDR_WIDTH - 1 : 0] rAddr;
    FIFO_TPRAM #(
        .WIDTH(WIDTH),
        .DEPTH(2**ADDR_WIDTH)
    ) instRAM (
        .nrst(fifoNrst),
        .wclk(wclk),

        .wEn(memWEn),
        .wAddr(wAddr),
        .wData(wData),

        .rAddr(rAddr),
        .rData(rData)
    );

    wire [ADDR_WIDTH : 0] rIdx;
    reg [ADDR_WIDTH : 0] rIdxWSync;
    reg [ADDR_WIDTH : 0] rIdxSync;
    wire [ADDR_WIDTH : 0] wIdx;
    reg [ADDR_WIDTH : 0] wIdxRSync;
    reg [ADDR_WIDTH : 0] wIdxSync;

    always @(posedge wclk or negedge fifoNrst) begin
        if(!fifoNrst) begin
            rIdxWSync <= 0;
            rIdxSync <= 0;
        end
        else begin
            rIdxWSync <= rIdx;
            rIdxSync <= rIdxWSync;
        end
    end

    always @(posedge rclk or negedge fifoNrst) begin
        if(!fifoNrst) begin
            wIdxRSync <= 0;
            wIdxSync <= 0;
        end
        else begin
            wIdxRSync <= wIdx;
            wIdxSync <= wIdxRSync;
        end
    end

    WCtrl #(
        .DEPTH(2**ADDR_WIDTH)
    ) instWCtlr (
        .wclk(wclk),
        .wNrst(fifoNrst),

        .rIdx(rIdxSync),
        .wIdx(wIdx),
        .wAddr(wAddr),
        .memWEn(memWEn),

        .wEn(wEn),
        .wFull(full)
    );

    RCtrl #(
        .DEPTH(2**ADDR_WIDTH)
    ) instRCtrl (
        .rclk(rclk),
        .rNrst(fifoNrst),

        .wIdx(wIdxSync),
        .rIdx(rIdx),
        .rAddr(rAddr),

        .rEn(rEn),
        .rEmpty(empty)
    );
endmodule
