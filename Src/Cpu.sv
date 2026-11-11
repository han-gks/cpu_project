/**************************************************************
 - Project          : CPU_OS
 - File name        : Cpu.sv
 - Description      : 5-Stage Pipelined RISC-V CPU Core (RV32I + Zicsr + Trap)
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.02 : Initial release
                      3) 2026.09.08 : Apply enum for selector
                      4) 2026.09.08 : Implement base type
                      5) 2026.09.10 : Implement variable step multi-cycle
                      6) 2026.10.30 : Connect CSR control (Ctrlpath -> Datapath)
                      7) 2026.11.11 : Connect Trap decode & external interrupt (MIP) ports
                      8) 2026.11.11 : Add iBusStall port for APB wait-state stall
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module Cpu (
    // Input Ports: Clock and Reset
    input  logic        iClk,
    input  logic        iRsn,

    // Input Ports: External Interrupt Pending (CLINT / PLIC)
    input  logic        iMip_MEIP,
    input  logic        iMip_MTIP,
    input  logic        iMip_MSIP,

    // Input Ports: Bus Wait-State Stall
    input  logic        iBusStall,

    // Input Ports: Data
    input  logic [31:0] iInstData,
    input  logic [31:0] iMemRdData,

    // Output Ports: Control
    output logic        oMemValid,
    output logic        oMemWrEn,
    output byte_sel_e   oMemByteSel,

    // Output Ports: Data
    output logic [31:0] oInstAddr,
    output logic [31:0] oMemWrData,
    output logic [31:0] oMemAddr
);

    // Control Signals
    alu_op_e            wAluCtrl;
    imm_type_e          wImmCtrl;
    alu_src1_e          wAluSrc1;
    alu_src2_e          wAluSrc2;
    wb_sel_e            wWBSel;
    pc_sel_e            wPcSel;
    branch_op_e         wBranchCtrl;
    logic               wBranchEn;
    logic               wWrEn_Reg;  
    logic               wMemValid;
    logic               wMemWrEn;  
    byte_sel_e          wMemByteSel;

    // CSR Control Signals
    csr_op_e            wCsrCtrl;
    logic               wCsrEn;
    logic               wCsrImmSel;
    logic               wCsrRdEn;
    logic               wCsrWrEn;

    // Trap Decode Signals
    logic               wIsMret;
    logic               wIsException;
    exception_cause_e   wExceptionCause;

    // Data Signals
    logic [31:0]        wInstData;

    Datapath u_datapath (
        .iClk            (iClk),
        .iRsn            (iRsn),

        .iWrEn_Reg       (wWrEn_Reg),
        .iWBSel          (wWBSel),
        .iAluCtrl        (wAluCtrl),
        .iImmCtrl        (wImmCtrl),
        .iAluSrc1        (wAluSrc1),
        .iAluSrc2        (wAluSrc2),
        .iPcSel          (wPcSel),
        .iBranchEn       (wBranchEn),
        .iBranchCtrl     (wBranchCtrl),
        .iMemValid       (wMemValid),
        .iMemWrEn        (wMemWrEn),
        .iMemByteSel     (wMemByteSel),

        .iCsrCtrl        (wCsrCtrl),
        .iCsrEn          (wCsrEn),
        .iCsrWrEn        (wCsrWrEn),
        .iCsrRdEn        (wCsrRdEn),
        .iCsrImmSel      (wCsrImmSel),

        .iIsMret         (wIsMret),
        .iIsException    (wIsException),
        .iExceptionCause (wExceptionCause),

        .iMip_MEIP       (iMip_MEIP),
        .iMip_MTIP       (iMip_MTIP),
        .iMip_MSIP       (iMip_MSIP),

        .iBusStall       (iBusStall),

        .iInstData       (iInstData),
        .iMemRdData      (iMemRdData),

        .oInstAddr       (oInstAddr),
        .oInstData       (wInstData),
        .oMemWrData      (oMemWrData),
        .oMemAddr        (oMemAddr),
        .oMemValid       (oMemValid),
        .oMemWrEn        (oMemWrEn),
        .oMemByteSel     (oMemByteSel)
    );

    Ctrlpath u_ctrlpath (
        .iInstData       (wInstData),
        
        .oWrEn_Reg       (wWrEn_Reg), 
        .oAluCtrl        (wAluCtrl),
        .oImmCtrl        (wImmCtrl),
        .oAluSrc1        (wAluSrc1),
        .oAluSrc2        (wAluSrc2),
        .oWBSel          (wWBSel),
        .oPcSel          (wPcSel),
        .oMemValid       (wMemValid),
        .oMemWrEn        (wMemWrEn),  
        .oBranchEn       (wBranchEn),
        .oBranchCtrl     (wBranchCtrl),
        .oMemByteSel     (wMemByteSel),

        .oCsrCtrl        (wCsrCtrl),
        .oCsrEn          (wCsrEn),
        .oCsrWrEn        (wCsrWrEn),   
        .oCsrRdEn        (wCsrRdEn),
        .oCsrImmSel      (wCsrImmSel),

        .oIsMret         (wIsMret),
        .oIsException    (wIsException),
        .oExceptionCause (wExceptionCause)
    );

endmodule
