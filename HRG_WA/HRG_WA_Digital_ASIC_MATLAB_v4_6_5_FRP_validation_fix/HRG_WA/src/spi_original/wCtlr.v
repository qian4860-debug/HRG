module WCtrl #(
    parameter DEPTH = 8,
    parameter ADDR_WIDTH = DEPTH == 1 ? 1 : $clog2(DEPTH)
)
(
    input wclk,
    input wNrst,

    input [ADDR_WIDTH : 0] rIdx,
    output [ADDR_WIDTH : 0] wIdx,
    output [ADDR_WIDTH - 1 : 0] wAddr,
    output memWEn,

    input wEn,
    output wFull
);
    reg [ADDR_WIDTH : 0] wPtr;

    assign wAddr = wPtr[ADDR_WIDTH - 1 : 0];
    assign wIdx = (wPtr >> 1) ^ wPtr;

    assign memWEn = (wEn && !wFull);

    always @(posedge wclk or negedge wNrst) begin
        if(!wNrst) begin
            wPtr <= 0;
        end
        else begin
            if(memWEn) begin
                wPtr <= wPtr + 1;
            end
            else begin
                wPtr <= wPtr;
            end
        end
    end

    assign wFull = (
        ADDR_WIDTH == 1 ?
        wIdx == ~rIdx[ADDR_WIDTH : ADDR_WIDTH - 1] :
        wIdx == {~rIdx[ADDR_WIDTH : ADDR_WIDTH - 1], rIdx[ADDR_WIDTH - 2 : 0]}
    );

endmodule
