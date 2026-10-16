module FIFO_TPRAM #(
    parameter WIDTH = 8,
    parameter DEPTH = 8
)
(
    input nrst,
    input wclk,

    input wEn,
    input [DEPTH==1 ? 0 : ($clog2(DEPTH) - 1) : 0] wAddr,
    input [WIDTH - 1 : 0] wData,

    input [DEPTH==1 ? 0 : ($clog2(DEPTH) - 1) : 0] rAddr,
    output reg [WIDTH - 1 : 0] rData
);
    reg [WIDTH - 1 : 0] mem[DEPTH - 1 : 0];

    integer i;
    always @(posedge wclk or negedge nrst) begin
        if(!nrst) begin
            for(i = 0; i < DEPTH; i = i + 1)
                mem[i] <= 0;
        end
        else begin
            if(wEn) begin
                mem[wAddr] <= wData;
            end
        end
    end

    always @(*) begin
        rData = mem[rAddr];
    end
endmodule
