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
                      2) 2026.11.10 : Fix for Trap
                      3) 2026.11.11 : Preserve mepc/mcause/mtval on mret (iIsMret)
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module CsrRegisterFile(
    // Input Ports: Clock and Reset
    input  logic        iClk,
    input  logic        iRsn,

    // Input Ports: Control (WB stage)
    input  logic        iCsrWrEn,
    input  logic        iCsrRdEn,       // for Inst read
    input  logic [11:0] iCsrAddr,       // for Inst read

    // Input Ports: Data
    input  logic [31:0] iCsrWrData,     // for Inst write
    
    // Trap Controller write
    input  logic        iCsrWrEn_Trap,
    input  logic [31:0] iTrapMstatus,
    input  logic [31:0] iTrapMepc,
    input  logic [31:0] iTrapMcause,
    input  logic [31:0] iTrapMtval,

    input  logic        iIsMret,

    // MIP Wire(CLINT, PLIC)
    input  logic        iMip_MEIP,
    input  logic        iMip_MTIP,
    input  logic        iMip_MSIP,


    // Output Ports: Data
    output logic [31:0] oCsrRdData,     // for Inst read

    output logic [31:0] oTrapMstatus,   // for TrapController
    output logic [31:0] oTrapMie,
    output logic [31:0] oTrapMip,
    output logic [31:0] oTrapMtvec,
    output logic [31:0] oTrapMepc
);

    // CSR address
    localparam logic [11:0] ADDR_MSTATUS  = 12'h300;
    localparam logic [11:0] ADDR_MIE      = 12'h304;
    localparam logic [11:0] ADDR_MTVEC    = 12'h305;
    localparam logic [11:0] ADDR_MSCRATCH = 12'h340;
    localparam logic [11:0] ADDR_MEPC     = 12'h341;
    localparam logic [11:0] ADDR_MCAUSE   = 12'h342;
    localparam logic [11:0] ADDR_MTVAL    = 12'h343;
    localparam logic [11:0] ADDR_MIP      = 12'h344;

    // Writable bit mask (WARL / WLRL)
    localparam logic [31:0] MASK_MSTATUS  = 32'h0000_0088;  // MPIE[7], MIE[3]
    localparam logic [31:0] MSTATUS_MPP   = 32'h0000_1800;  // MPP = 2'b11 (M-mode only, read-only)
    localparam logic [31:0] MASK_MIE      = 32'h0000_0888;  // MEIE[11], MTIE[7], MSIE[3]
    localparam logic [31:0] MASK_MTVEC    = 32'hFFFF_FFC1;  // BASE[31:2], MODE[0] (0:Direct, 1:Vectored)
    localparam logic [31:0] MASK_MEPC     = 32'hFFFF_FFFC;  // Alignment: 4-byte boundary (WARL)
    localparam logic [31:0] MASK_MCAUSE   = 32'h8000_000F;  // Interrupt[31], Code[3:0]

    // Registers
    logic [31:0] mstatus, mie, mtvec, mscratch, mepc, mcause, mtval;

    // Pure wire
    logic [31:0] wMip;

    // *************************************************************************
    // 1. SW and HW  Registers (mstatus, mepc, mcause, mtval)
    // *************************************************************************
    // mstatus
    always_ff @(posedge iClk or negedge iRsn)
    begin
        if (!iRsn)
            mstatus <= 32'b0;
        else if (iCsrWrEn_Trap)
            mstatus <= iTrapMstatus & MASK_MSTATUS;
        else if (iCsrWrEn && (iCsrAddr == ADDR_MSTATUS))
            mstatus <= iCsrWrData & MASK_MSTATUS;
    end
    // mepc
    always_ff @(posedge iClk or negedge iRsn)
    begin
        if (!iRsn)
            mepc <= 32'b0;
        else if (iCsrWrEn_Trap && !iIsMret)
            mepc <= iTrapMepc & MASK_MEPC;
        else if (iCsrWrEn && (iCsrAddr == ADDR_MEPC))
            mepc <= iCsrWrData & MASK_MEPC;
    end
    // mcause
    always_ff @(posedge iClk or negedge iRsn)
    begin
        if (!iRsn)
            mcause <= 32'b0;
        else if (iCsrWrEn_Trap && !iIsMret)
            mcause <= iTrapMcause & MASK_MCAUSE;
        else if (iCsrWrEn && (iCsrAddr == ADDR_MCAUSE))
            mcause <= iCsrWrData & MASK_MCAUSE;
    end
    // mtval
    always_ff @(posedge iClk or negedge iRsn)
    begin
        if (!iRsn)
            mtval <= 32'b0;
        else if (iCsrWrEn_Trap && !iIsMret)
            mtval <= iTrapMtval;
        else if (iCsrWrEn && (iCsrAddr == ADDR_MTVAL))
            mtval <= iCsrWrData;
    end

    // *************************************************************************
    // 2. SW-Only  (mie, mtvec, mscratch)
    // *************************************************************************
    // mie
    always_ff @(posedge iClk or negedge iRsn)
    begin
        if (!iRsn)
            mie <= 32'b0;
        else if (iCsrWrEn && (iCsrAddr == ADDR_MIE))
            mie <= iCsrWrData & MASK_MIE;
    end
    // mtvec
    always_ff @(posedge iClk or negedge iRsn)
    begin
        if (!iRsn)
            mtvec <= 32'b0;
        else if (iCsrWrEn && (iCsrAddr == ADDR_MTVEC))
            mtvec <= iCsrWrData & MASK_MTVEC;
    end
    // mscratch
    always_ff @(posedge iClk or negedge iRsn)
    begin
        if (!iRsn)
            mscratch <= 32'b0;
        else if (iCsrWrEn && (iCsrAddr == ADDR_MSCRATCH))
            mscratch <= iCsrWrData;
    end

    // *************************************************************************
    // 3. MIP 
    // *************************************************************************
    assign wMip = {20'b0, iMip_MEIP, 3'b0, iMip_MTIP, 3'b0, iMip_MSIP, 3'b0};

    // *************************************************************************
    // Trap Controller 
    // *************************************************************************
    assign oTrapMstatus = mstatus | MSTATUS_MPP;
    assign oTrapMie     = mie;
    assign oTrapMip     = wMip;
    assign oTrapMtvec   = mtvec;
    assign oTrapMepc    = mepc;

    // *************************************************************************
    // Read : WB stage, combinational
    // *************************************************************************
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
                ADDR_MTVAL    : oCsrRdData = mtval;
                ADDR_MIP      : oCsrRdData = wMip;
                default       : ;                       // unimplemented CSR : 0
            endcase
        end
    end

endmodule
