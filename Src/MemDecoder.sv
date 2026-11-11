/**************************************************************
 - Project          : CPU_OS
 - File name        : MemDecoder.sv
 - Description      : Memory Address Decoder & Bus Multiplexer
                      - 0x8000_0000 ~ 0x8FFF_FFFF : DataMem (Direct Bypass)
                      - Other Addresses           : APB Master (Bus Path)
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.11.11 : Initial release
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module MemDecoder (
    // CPU Memory Interface (From/To Core MEM Stage)
    input  logic        iMemValid,
    input  logic        iMemWrEn,
    input  byte_sel_e   iMemByteSel,
    input  logic [31:0] iMemAddr,
    input  logic [31:0] iMemWrData,
    output logic [31:0] oMemRdData,

    // DataMem Bypass Interface (0x8000_0000)
    output logic        oDmemWrEn,
    output byte_sel_e   oDmemByteSel,
    output logic [31:0] oDmemAddr,
    output logic [31:0] oDmemWrData,
    input  logic [31:0] iDmemRdData,

    // APB Master Generic Request/Response Interface
    output logic        oReqValid,
    input  logic        iReqReady,
    output logic [31:0] oReqAddr,
    output logic        oReqWrite,
    output logic [31:0] oReqWrData,
    output logic [ 3:0] oReqWrStrb,

    input  logic        iRspValid,
    input  logic [31:0] iRspRdData,
    input  logic        iRspError
);

    // -------------------------------------------------------------------------
    // 1. Address Decoding (0x8000_0000 ~ 0x8FFF_FFFF -> DataMem Bypass)
    // -------------------------------------------------------------------------
    logic wIsDmem;
    assign wIsDmem = (iMemAddr[31:28] == 4'h8);

    // -------------------------------------------------------------------------
    // 2. DataMem Bypass Path
    // -------------------------------------------------------------------------
    assign oDmemWrEn    = iMemValid && wIsDmem && iMemWrEn;
    assign oDmemByteSel = iMemByteSel;
    assign oDmemAddr    = iMemAddr;
    assign oDmemWrData  = iMemWrData;

    // -------------------------------------------------------------------------
    // 3. APB Master Request Path
    // -------------------------------------------------------------------------
    logic [3:0] wReqWrStrb;

    always_comb
    begin
        wReqWrStrb = 4'b0000;
        case (iMemByteSel[1:0])
            2'b00: // SB (Byte)
            begin
                wReqWrStrb[0] = (iMemAddr[1:0] == 2'b00);
                wReqWrStrb[1] = (iMemAddr[1:0] == 2'b01);
                wReqWrStrb[2] = (iMemAddr[1:0] == 2'b10);
                wReqWrStrb[3] = (iMemAddr[1:0] == 2'b11);
            end
            2'b01: // SH (Halfword)
            begin
                wReqWrStrb[0] = (iMemAddr[1] == 1'b0);
                wReqWrStrb[1] = (iMemAddr[1] == 1'b0);
                wReqWrStrb[2] = (iMemAddr[1] == 1'b1);
                wReqWrStrb[3] = (iMemAddr[1] == 1'b1);
            end
            2'b10: // SW (Word)
            begin
                wReqWrStrb = 4'b1111;
            end
            default: wReqWrStrb = 4'b0000;
        endcase
    end

    assign oReqValid  = iMemValid && !wIsDmem;
    assign oReqAddr   = iMemAddr;
    assign oReqWrite  = iMemWrEn;
    assign oReqWrData = iMemWrData;
    assign oReqWrStrb = wReqWrStrb;

    // -------------------------------------------------------------------------
    // 4. Read Data Multiplexer (To CPU)
    // -------------------------------------------------------------------------
    assign oMemRdData = wIsDmem ? iDmemRdData : iRspRdData;

endmodule
