/**************************************************************
 - Project          : CPU_OS
 - File name        : Fifo_RegFile.v
 - Description      : Register File for UART FIFO (renamed from
                      RegisterFile to avoid name clash with CPU RF)
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.08.10 : Initial release
                      2) 2026.11.11 : Ported to CPU_OS as Fifo_RegFile
**************************************************************/
`timescale 1ns / 1ps

module Fifo_RegFile #(
    parameter ADDR_WIDTH = 2,           
    parameter DATA_WIDTH = 8            
)(
    input                       iClk,

    input   [ADDR_WIDTH - 1:0]  iWrAddr,
    input   [DATA_WIDTH - 1:0]  iWrDt,
    input                       iEnWr,

    input   [ADDR_WIDTH - 1:0]  iRdAddr,
    output  [DATA_WIDTH - 1:0]  oRdDt
);

    localparam DEPTH = 2 ** ADDR_WIDTH; 

    reg [DATA_WIDTH - 1:0] rMem [0:DEPTH - 1];

    always@(posedge iClk)
    begin
        if(iEnWr)
            rMem[iWrAddr] <= iWrDt;
    end

    assign oRdDt = rMem[iRdAddr];

endmodule
