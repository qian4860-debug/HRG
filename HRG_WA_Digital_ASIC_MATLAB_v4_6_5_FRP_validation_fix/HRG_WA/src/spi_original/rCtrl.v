module RCtrl #(
    parameter DEPTH = 8,
    parameter ADDR_WIDTH = DEPTH == 1 ? 1 : $clog2(DEPTH)
)
(
    input rclk,
    input rNrst,
    
    input [ADDR_WIDTH : 0] wIdx,
    output [ADDR_WIDTH : 0] rIdx,
    output [ADDR_WIDTH - 1 : 0] rAddr,

    input rEn,
    output rEmpty
);
    reg [ADDR_WIDTH : 0] rPtr;

    assign rAddr = rPtr[ADDR_WIDTH - 1 : 0];
    assign rIdx = (rPtr >> 1) ^ rPtr; // gray code

    always @(posedge rclk or negedge rNrst) begin
        if(!rNrst) begin
            rPtr <= 0;
        end
        else begin
            if(rEn && !rEmpty)
                rPtr <= rPtr + 1;
        end
    end

    assign rEmpty = (wIdx == rIdx);
endmodule
