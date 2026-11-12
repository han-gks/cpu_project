/**************************************************************
 - Project          : CPU_OS
 - File name        : DataMem.sv
 - Description      : Data Memory (16KB = 4096 Words @ 0x8000_0000)
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.03 : Initial release (128 Words)
                      2) 2026.11.11 : Expand MEM_WORDS to 4096 (16KB) for FreeRTOS
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module DataMem #(
    parameter integer MEM_WORDS = 4096
) (
    // Input Ports: Clock
    input  logic        iClk,

    // Input Ports: Control
    input  logic        iMemWrEn,
    input  byte_sel_e   iMemByteSel,

    // Input Ports: Data
    input  logic [31:0] iMemAddr,
    input  logic [31:0] iMemWrData,

    // Output Ports: Data
    output logic [31:0] oMemRdData
);

    localparam integer ADDR_BITS = $clog2(MEM_WORDS);

    logic [31:0] rMem [0:MEM_WORDS-1];

    // wire & reg declaration
    logic [ 3:0]          wByteEn;          // Make byte write enable from iMemAddr
    logic [ADDR_BITS-1:0] wWordAddr;        // Make SRAM address from iMemAddr
    logic [31:0]          wBroadcastWrData; // Make concatenated data from iMemWrData
    logic [31:0]          wRdWord;
    logic [ 7:0]          wRdByte;
    logic [15:0]          wRdHalf;

    /*************************************************************************
    // Wire assign combinational logic
    *************************************************************************/
    // 1. Data Broadcasting
    always_comb
    begin
        case (iMemByteSel[1:0])
            2'b00:   wBroadcastWrData = {4{iMemWrData[7:0]}};    // SB: Broadcast Byte to the entire 32-bit bus
            2'b01:   wBroadcastWrData = {2{iMemWrData[15:0]}};   // SH: Broadcast HalfWord to the entire 32-bit bus
            2'b10:   wBroadcastWrData = iMemWrData[31:0];        // SW: Pass Word data as is
            default: wBroadcastWrData = iMemWrData[31:0];
        endcase
    end

    // 2. Write Selection logic
    always_comb 
    begin
        wByteEn = 4'b0000;
        case (iMemByteSel[1:0])
            2'b00:
            begin // SB (Byte selection)
                wByteEn[0] = (iMemAddr[1:0] == 2'b00) ? 1'b1 : 1'b0;
                wByteEn[1] = (iMemAddr[1:0] == 2'b01) ? 1'b1 : 1'b0;
                wByteEn[2] = (iMemAddr[1:0] == 2'b10) ? 1'b1 : 1'b0;
                wByteEn[3] = (iMemAddr[1:0] == 2'b11) ? 1'b1 : 1'b0;
            end
            2'b01:
            begin // SH (HalfWord selection)
                wByteEn[0] = (iMemAddr[1] == 1'b0) ? 1'b1 : 1'b0;
                wByteEn[1] = (iMemAddr[1] == 1'b0) ? 1'b1 : 1'b0;
                wByteEn[2] = (iMemAddr[1] == 1'b1) ? 1'b1 : 1'b0;
                wByteEn[3] = (iMemAddr[1] == 1'b1) ? 1'b1 : 1'b0;
            end
            2'b10:
            begin // SW (Word selection)
                wByteEn[0] = 1'b1;
                wByteEn[1] = 1'b1;
                wByteEn[2] = 1'b1;
                wByteEn[3] = 1'b1;
            end
            default: wByteEn = 4'b0000;
        endcase
    end

    // 3. Address Mapping
    assign wWordAddr = iMemAddr[ADDR_BITS+1:2];

    /****************************************************************************
    // Memory Write Operation
    ****************************************************************************/
    always_ff @(posedge iClk)
    begin
        if (wByteEn[0] && iMemWrEn) rMem[wWordAddr][ 7: 0] <= wBroadcastWrData[ 7: 0];
        if (wByteEn[1] && iMemWrEn) rMem[wWordAddr][15: 8] <= wBroadcastWrData[15: 8];
        if (wByteEn[2] && iMemWrEn) rMem[wWordAddr][23:16] <= wBroadcastWrData[23:16];
        if (wByteEn[3] && iMemWrEn) rMem[wWordAddr][31:24] <= wBroadcastWrData[31:24];
    end

    /****************************************************************************
    // Memory Read Operation
    ****************************************************************************/
    assign wRdWord = rMem[wWordAddr][31:0];

    always_comb 
    begin
        case (iMemAddr[1:0])
            2'b00  : wRdByte = wRdWord[ 7: 0];
            2'b01  : wRdByte = wRdWord[15: 8];
            2'b10  : wRdByte = wRdWord[23:16];
            2'b11  : wRdByte = wRdWord[31:24];
            default: wRdByte = wRdWord[ 7: 0];
        endcase
    end

    always_comb 
    begin
        case (iMemAddr[1])
            1'b0   : wRdHalf = wRdWord[15: 0];
            1'b1   : wRdHalf = wRdWord[31:16];
            default: wRdHalf = wRdWord[15: 0];
        endcase
    end

    always_comb 
    begin
        case (iMemByteSel)
            BYTE   : oMemRdData = {{24{wRdByte[7]}}, wRdByte};
            HALF   : oMemRdData = {{16{wRdHalf[15]}}, wRdHalf};
            WORD   : oMemRdData = wRdWord;
            BYTE_U : oMemRdData = {24'b0, wRdByte};
            HALF_U : oMemRdData = {16'b0, wRdHalf};
            default: oMemRdData = wRdWord;
        endcase
    end

endmodule
