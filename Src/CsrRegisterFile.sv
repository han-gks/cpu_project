/**************************************************************
 - Project          : CPU_OS
 - File name        : CsrRegisterFile.sv
 - Description      : Machine-mode CSR register file
                      - Read  : combinational (WB stage)
                      - Write : synchronous   (WB stage, posedge)
                      - Reset : asynchronous  (same as pipeline registers)
                      - No bypass needed : read and write are in the same stage
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.10.30 : Initial release
                                      - mstatus, mie, mtvec, mscratch, mepc, mcause
                                      - WARL write mask (M-mode only)
                                      - mtval, mip : TBD (trap/interrupt)
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module CsrRegisterFile(
    // Input Ports: Clock and Reset
    input  logic        iClk,
    input  logic        iRsn,

    // Input Ports: Control (WB stage)
    input  logic        iCsrWrEn,
    input  logic        iCsrRdEn,       // read guard (against read side effects)
    input  logic [11:0] iCsrAddr,

    // Input Ports: Data
    input  logic [31:0] iCsrWrData,

    // Output Ports: Data
    output logic [31:0] oCsrRdData
);

    // CSR address
    localparam logic [11:0] ADDR_MSTATUS  = 12'h300;
    localparam logic [11:0] ADDR_MIE      = 12'h304;
    localparam logic [11:0] ADDR_MTVEC    = 12'h305;
    localparam logic [11:0] ADDR_MSCRATCH = 12'h340;
    localparam logic [11:0] ADDR_MEPC     = 12'h341;
    localparam logic [11:0] ADDR_MCAUSE   = 12'h342;

    // Writable bit mask (WARL)
    localparam logic [31:0] MASK_MSTATUS  = 32'h0000_0088;  // MPIE[7], MIE[3]
    localparam logic [31:0] MASK_MIE      = 32'h0000_0888;  // MEIE[11], MTIE[7], MSIE[3]
    localparam logic [31:0] MSTATUS_MPP   = 32'h0000_1800;  // MPP = 2'b11 (M-mode only, read-only)

    logic [31:0] mstatus, mie, mtvec, mscratch, mepc, mcause;

    // Write : WB stage, posedge
    always_ff @(posedge iClk or negedge iRsn)
    begin
        if (!iRsn)
        begin
            mstatus  <= 32'b0;
            mie      <= 32'b0;
            mtvec    <= 32'b0;
            mscratch <= 32'b0;
            mepc     <= 32'b0;
            mcause   <= 32'b0;
        end
        else if (iCsrWrEn)
        begin
            case (iCsrAddr)
                ADDR_MSTATUS  : mstatus  <= iCsrWrData & MASK_MSTATUS;
                ADDR_MIE      : mie      <= iCsrWrData & MASK_MIE;
                ADDR_MTVEC    : mtvec    <= {iCsrWrData[31:2], 2'b00};  // direct mode
                ADDR_MSCRATCH : mscratch <= iCsrWrData;
                ADDR_MEPC     : mepc     <= {iCsrWrData[31:2], 2'b00};  // 4-byte align
                ADDR_MCAUSE   : mcause   <= iCsrWrData;
                default       : ;
            endcase
        end
    end

    // Read : WB stage, combinational
    always_comb
    begin
        oCsrRdData = 32'b0;
        if (iCsrRdEn)
        begin
            case (iCsrAddr)
                ADDR_MSTATUS  : oCsrRdData = mstatus | MSTATUS_MPP;
                ADDR_MIE      : oCsrRdData = mie;
                ADDR_MTVEC    : oCsrRdData = mtvec;
                ADDR_MSCRATCH : oCsrRdData = mscratch;
                ADDR_MEPC     : oCsrRdData = mepc;
                ADDR_MCAUSE   : oCsrRdData = mcause;
                default       : ;                       // unimplemented CSR : 0
            endcase
        end
    end

endmodule
