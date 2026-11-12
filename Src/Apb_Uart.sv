/**************************************************************
 - Project          : CPU_OS
 - File name        : Apb_Uart.sv
 - Description      : APB Slave Wrapper for UART + TX/RX FIFO
                      Base Address: 0x2003_0000
                      - 0x00 (STATUS)  : [3] TxFull, [2] TxEmpty, [1] RxFull, [0] RxEmpty
                      - 0x04 (TX_DATA) : Write [7:0] pushes byte to TX FIFO
                      - 0x08 (RX_DATA) : Read  [7:0] pops byte from RX FIFO
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.11.11 : Initial release wrapping Uart_Top & FIFO_Top
**************************************************************/
`timescale 1ns / 1ps

module Apb_Uart (
    input  logic        iClk,
    input  logic        iRsn,

    // APB Slave Interface
    input  logic [31:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic        PREADY,
    output logic [31:0] PRDATA,
    output logic        PSLVERR,

    // External Serial Pins
    input  logic        iRx,
    output logic        oTx,

    // Interrupt Output to PLIC
    output logic        oIrq
);

    logic        wRst;
    assign wRst = ~iRsn;

    // APB handshake (zero wait-state)
    assign PREADY  = PSEL && PENABLE;
    assign PSLVERR = 1'b0;

    // Internal FIFO & UART signals
    logic [7:0]  wUartRx_Data;
    logic        wUartRx_Done;
    logic [7:0]  wUartTx_Data;
    logic        wUartTx_Busy;
    logic        wUartTx_Done;

    logic        wRxFifo_Full;
    logic        wRxFifo_Empty;
    logic [7:0]  wRxFifo_RdData;

    logic        wTxFifo_Full;
    logic        wTxFifo_Empty;

    // APB Write to TX FIFO (Offset 0x04 -> PADDR[3:2] == 2'b01)
    logic        wTxFifo_Push;
    assign wTxFifo_Push = PSEL && PENABLE && PWRITE && (PADDR[3:2] == 2'b01) && !wTxFifo_Full;

    // Auto-start UART TX whenever TX FIFO is not empty and UART TX is idle
    logic        wUartTx_Start;
    logic        wTxFifo_Pop;
    assign wUartTx_Start = ~wTxFifo_Empty & ~wUartTx_Busy;
    assign wTxFifo_Pop   = wUartTx_Start;

    // APB Read from RX FIFO (Offset 0x08 -> PADDR[3:2] == 2'b10)
    logic        wRxFifo_Pop;
    assign wRxFifo_Pop  = PSEL && PENABLE && !PWRITE && (PADDR[3:2] == 2'b10) && !wRxFifo_Empty;

    // RX FIFO Instance
    FIFO_Top #(
        .ADDR_WIDTH (6)
    ) U_FIFO_Rx (
        .iClk       (iClk),
        .iRst       (wRst),
        .iPush      (wUartRx_Done),
        .iPop       (wRxFifo_Pop),
        .iWrDt      (wUartRx_Data),
        .oRdDt      (wRxFifo_RdData),
        .oFull      (wRxFifo_Full),
        .oEmpty     (wRxFifo_Empty)
    );

    // TX FIFO Instance
    FIFO_Top #(
        .ADDR_WIDTH (6)
    ) U_FIFO_Tx (
        .iClk       (iClk),
        .iRst       (wRst),
        .iPush      (wTxFifo_Push),
        .iPop       (wTxFifo_Pop),
        .iWrDt      (PWDATA[7:0]),
        .oRdDt      (wUartTx_Data),
        .oFull      (wTxFifo_Full),
        .oEmpty     (wTxFifo_Empty)
    );

    // UART Core Instance
    Uart_Top U_Uart_Top (
        .iClk       (iClk),
        .iRst       (wRst),
        .iTx_Start  (wUartTx_Start),
        .iTx_Data   (wUartTx_Data),
        .iRx        (iRx),
        .oTx        (oTx),
        .oTx_Done   (wUartTx_Done),
        .oTx_Busy   (wUartTx_Busy),
        .oRx_Data   (wUartRx_Data),
        .oRx_Done   (wUartRx_Done)
    );

    // APB Read Data Mux
    always_comb
    begin
        PRDATA = 32'h0000_0000;
        if (PSEL && !PWRITE)
        begin
            unique case (PADDR[3:2])
                2'b00:   PRDATA = {28'b0, wTxFifo_Full, wTxFifo_Empty, wRxFifo_Full, wRxFifo_Empty};
                2'b01:   PRDATA = {24'b0, wUartTx_Data};
                2'b10:   PRDATA = {24'b0, wRxFifo_RdData};
                default: PRDATA = 32'h0000_0000;
            endcase
        end
    end

    // Interrupt to PLIC when RX data is received (or RX FIFO is non-empty)
    assign oIrq = ~wRxFifo_Empty;

endmodule
