/**************************************************************
 - Project          : CPU_OS
 - File name        : TickGen_Baud_16.v
 - Description      : 9600Hz baudrate * 16 sampling
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.08.05 : Initial release
                      2) 2026.11.11 : Ported to CPU_OS
**************************************************************/
`timescale 1ns / 1ps

module TickGen_Baud_16 (
    input           iClk,
    input           iRst,

    output          oTick_Baud_16
);

    parameter   BAUD_RATE  = 9600;
    parameter   CLOCK_RATE = 100_000_000;
    parameter   COUNT_MAX  = CLOCK_RATE / (BAUD_RATE * 16);
    parameter   BIT_WIDTH  = $clog2(COUNT_MAX);

    reg     [BIT_WIDTH-1 : 0]   rCnt;
    reg                         rTick;

    always @(posedge iClk or posedge iRst)
    begin
        if (iRst)
        begin
            rCnt  <= 0;
            rTick <= 0;
        end
        else
        begin
            if(rCnt == COUNT_MAX - 1)
            begin
                rCnt  <= 0;
                rTick <= 1;
            end
            else
            begin
                rCnt  <= rCnt + 1;
                rTick <= 0;
            end
        end
    end

    assign oTick_Baud_16 = rTick;

endmodule
