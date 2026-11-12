/**************************************************************
 - Project          : CPU_OS
 - File name        : Uart_Top.v
 - Description      : UART Transceiver Core (TickGen + Tx + Rx)
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.08.06 : Initial release
                      2) 2026.11.11 : Ported to CPU_OS
**************************************************************/
`timescale 1ns / 1ps

module Uart_Top (
    input           iClk,
    input           iRst,
    input           iTx_Start,
    input   [7:0]   iTx_Data,
    input           iRx,

    output          oTx,
    output          oTx_Done,
    output          oTx_Busy,

    output  [7:0]   oRx_Data,
    output          oRx_Done
);

    wire            wTick_Baud_16;

    /***********************************************
    // Instance
    ***********************************************/
    TickGen_Baud_16 U_TickGen_Baud_16 (
        .iClk           (iClk),
        .iRst           (iRst),
        
        .oTick_Baud_16  (wTick_Baud_16)
    );

    Uart_Tx U_Uart_Tx (
        .iClk           (iClk),
        .iRst           (iRst),
        .iTick_Baud_16  (wTick_Baud_16),

        .iTx_Start      (iTx_Start),
        .iTx_Data       (iTx_Data),

        .oTx_Data       (oTx),
        .oTx_Done       (oTx_Done),
        .oTx_Busy       (oTx_Busy)
    );  

    Uart_Rx U_Uart_Rx (
        .iClk           (iClk),
        .iRst           (iRst),
        .iTick_Baud_16  (wTick_Baud_16),

        .iRx            (iRx),

        .oRx_Done       (oRx_Done),
        .oRx_Data       (oRx_Data)
    );  

endmodule
