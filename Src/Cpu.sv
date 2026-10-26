/**************************************************************
 - Project          : CPU_OS
 - File name        : Cpu.sv
 - Description      : Multi-Cycle Controller over Pipelined Datapath
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.02 : Initial release
                      3) 2026.09.08 : Apply enum for selector
                      4) 2026.09.08 : Implement base type
                      5) 2026.09.10 : Implement variable step multi-cycle
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module Cpu (
    // Input Ports: Clock and Reset
    input  logic        iClk,
    input  logic        iRsn,

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
    alu_op_e    wAluCtrl;
    imm_type_e  wImmCtrl;
    alu_src1_e  wAluSrc1;
    alu_src2_e  wAluSrc2;
    wb_sel_e    wWBSel;
    pc_sel_e    wPcSel;
    branch_op_e wBranchCtrl;
    logic       wBranchEn;
    logic       wWrEn_Reg;  
    logic       wMemValid;
    logic       wMemWrEn;  
    byte_sel_e  wMemByteSel;  

    // Data Signals
    logic [31:0] wInstData;

    Datapath u_datapath (
        .iClk       (iClk),
        .iRsn       (iRsn),

        .iWrEn_Reg  (wWrEn_Reg),
        .iWBSel     (wWBSel),
        .iAluCtrl   (wAluCtrl),
        .iImmCtrl   (wImmCtrl),
        .iAluSrc1   (wAluSrc1),
        .iAluSrc2   (wAluSrc2),
        .iPcSel     (wPcSel),
        .iBranchEn  (wBranchEn),
        .iBranchCtrl(wBranchCtrl),
        .iMemValid  (wMemValid),
        .iMemWrEn   (wMemWrEn),
        .iMemByteSel(wMemByteSel),

        .iInstData  (iInstData),
        .iMemRdData (iMemRdData),

        .oInstAddr  (oInstAddr),
        .oInstData  (wInstData),
        .oMemWrData (oMemWrData),
        .oMemAddr   (oMemAddr),
        .oMemValid  (oMemValid),
        .oMemWrEn   (oMemWrEn),
        .oMemByteSel(oMemByteSel)
    );

    Ctrlpath u_ctrlpath (
        .iInstData  (wInstData),
        
        .oWrEn_Reg  (wWrEn_Reg), 
        .oAluCtrl   (wAluCtrl),
        .oImmCtrl   (wImmCtrl),
        .oAluSrc1   (wAluSrc1),
        .oAluSrc2   (wAluSrc2),
        .oWBSel     (wWBSel),
        .oPcSel     (wPcSel),
        .oMemValid  (wMemValid),
        .oMemWrEn   (wMemWrEn),  
        .oBranchEn  (wBranchEn),
        .oBranchCtrl(wBranchCtrl),
        .oMemByteSel(wMemByteSel)
    );

endmodule
