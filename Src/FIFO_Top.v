/**************************************************************
 - Project          : CPU_OS
 - File name        : FIFO_Top.v
 - Description      : Synchronous Byte FIFO for UART TX/RX
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.08.10 : Initial release
                      2) 2026.11.11 : Ported to CPU_OS (uses Fifo_RegFile)
**************************************************************/
`timescale 1ns / 1ps

module FIFO_Top #(
    parameter   ADDR_WIDTH = 6
)(
    input           iClk,
    input           iRst,
    input           iPush,
    input           iPop,

    input   [7:0]   iWrDt,
    output  [7:0]   oRdDt,

    output          oFull,
    output          oEmpty
);

    wire    [ADDR_WIDTH-1:0]    wWrPtr;
    wire    [ADDR_WIDTH-1:0]    wRdPtr;

    /***********************************************
    // Instance
    ***********************************************/
    Fifo_RegFile #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_RegisterFile (
        .iClk           (iClk),

        .iWrAddr        (wWrPtr),
        .iWrDt          (iWrDt),
        .iEnWr          ((~oFull) & iPush),

        .iRdAddr        (wRdPtr),
        .oRdDt          (oRdDt)
    );
      
    FIFO_Ctrl #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_FIFO_Ctrl (
        .iClk           (iClk),
        .iRst           (iRst),

        .iPush          (iPush),
        .iPop           (iPop),

        .oWrPtr         (wWrPtr),
        .oRdPtr         (wRdPtr),

        .oFull          (oFull),
        .oEmpty         (oEmpty)
    );

endmodule
