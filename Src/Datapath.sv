/**************************************************************
 - Project          : CPU_OS
 - File name        : Datapath.sv
 - Description      : Fully Synchronized 5-Stage Pipelined Datapath
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.02 : Initial release
                      5) 2026.09.08 : Apply enum for selector
                      8) 2026.09.09 : Complete base opcode
                      9) 2026.09.10 : Fully pipe 
                     11) 2026.09.10 : [Bug  FIX] Relocate Branch/Jump logic to EX stage
                     12) 2026.10.18 : Add Forwarding logic
                     13) 2026.10.19 : Add Hazard Detection logic
                     14) 2026.10.30 : Add CSR path (Zicsr)
                     15) 2026.10.31 : Add CSR remain logic
                     16) 2026.11.08 : Add WB trap metadata, trap-handler interfaces
                     17) 2026.11.11 : Integrate TrapController, 4-stage Valid/Flush, and CSR Trap ports
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module Datapath (
    // Input Ports: Clock and Reset
    input  logic                iClk,
    input  logic                iRsn,

    // Input Ports: Control (from Ctrlpath)
    input  logic                iWrEn_Reg,
    input  wb_sel_e             iWBSel,
    input  alu_op_e             iAluCtrl,    
    input  imm_type_e           iImmCtrl,    
    input  alu_src1_e           iAluSrc1,
    input  alu_src2_e           iAluSrc2,
    input  pc_sel_e             iPcSel,
    input  logic                iBranchEn,
    input  branch_op_e          iBranchCtrl,
    input  logic                iMemValid,
    input  logic                iMemWrEn,
    input  byte_sel_e           iMemByteSel,

    // Input Ports: CSR Control (decoded in ID, used in WB)
    input  csr_op_e             iCsrCtrl,       // CSR operation : WRITE / SET / CLEAR
    input  logic                iCsrEn,         // CSR instruction valid
    input  logic                iCsrWrEn,       // CSR write enable
    input  logic                iCsrRdEn,       // CSR read enable
    input  logic                iCsrImmSel,     // 0 : rs1, 1 : zimm (CSRRxI)

    // Input Ports: Trap Decode (from Ctrlpath)
    input  logic                iIsMret,
    input  logic                iIsException,
    input  exception_cause_e    iExceptionCause,

    // Input Ports: External Interrupt Pending (from CLINT / PLIC)
    input  logic                iMip_MEIP,
    input  logic                iMip_MTIP,
    input  logic                iMip_MSIP,

    // Input Ports: Data
    input  logic [31:0]         iInstData,
    input  logic [31:0]         iMemRdData,

    // Output Ports: Control
    output logic                oMemValid,
    output logic                oMemWrEn,
    output byte_sel_e           oMemByteSel,

    // Output Ports: Data
    output logic [31:0]         oInstAddr,
    output logic [31:0]         oInstData,
    output logic [31:0]         oMemWrData,
    output logic [31:0]         oMemAddr
);

    // =========================================================
    // Internal Signals & Pipeline Registers
    // =========================================================
    // IF Stage
    logic [31:0]        wPc;     
    logic [31:0]        wPcPlus4;
    logic               wBranchCond;
    logic               wIF_ID_Stall;
    logic               wIF_ID_Flush;
    logic               wID_EX_Flush;
    logic               wEX_MEM_Flush;
    logic               wMEM_WB_Flush;
    logic               wPC_Stall;

    // IF -> ID Registers
    logic [31:0]        rIF_ID_InstData;
    logic [31:0]        rIF_ID_PC;
    logic [31:0]        rIF_ID_PCPlus4;
    logic               rIF_ID_Valid;

    // ID Stage
    logic [31:0]        wRdData1;
    logic [31:0]        wRdData2;
    logic [31:0]        wExtdData;

    // ID -> EX Registers
    logic [31:0]        rID_EX_Rs1;
    logic [31:0]        rID_EX_Rs2;
    logic [31:0]        rID_EX_Imm;
    logic [31:0]        rID_EX_PC;
    logic [31:0]        rID_EX_PCPlus4;
    logic [ 4:0]        rID_EX_Rd;
    logic [ 4:0]        rID_EX_Rs1Addr;
    logic [ 4:0]        rID_EX_Rs2Addr;

    logic               rID_EX_Valid;
    logic               rID_EX_WrEn_Reg;
    wb_sel_e            rID_EX_WBSel;
    alu_op_e            rID_EX_AluCtrl;
    alu_src1_e          rID_EX_AluSrc1;
    alu_src2_e          rID_EX_AluSrc2;
    pc_sel_e            rID_EX_PcSel;
    logic               rID_EX_BranchEn;
    branch_op_e         rID_EX_BranchCtrl;
    logic               rID_EX_MemValid;
    logic               rID_EX_MemWrEn;
    byte_sel_e          rID_EX_MemByteSel;

    // ID -> EX Registers: CSR & Trap
    logic [11:0]        rID_EX_CsrAddr;
    csr_op_e            rID_EX_CsrCtrl;
    logic               rID_EX_CsrEn;
    logic               rID_EX_CsrWrEn;
    logic               rID_EX_CsrRdEn;
    logic               rID_EX_CsrImmSel;
    logic               rID_EX_Mret;
    logic               rID_EX_Exc;
    exception_cause_e   rID_EX_Cause;

    // EX Stage
    logic [31:0]        wAluRs1;
    logic [31:0]        wAluRs2; 
    logic [31:0]        wAluData;
    logic [31:0]        wBranchTarget;
    logic               wTakeBranch;

    logic [31:0]        wAluRs1_Bypass;
    logic [31:0]        wAluRs1_Fwd;
    logic [31:0]        wAluRs2_Bypass;
    logic [31:0]        wAluRs2_Fwd;
    logic               wFwdRs1_En;
    logic               wFwdRs1_Sel;
    logic               wFwdRs2_En;
    logic               wFwdRs2_Sel;

    // EX -> MEM Registers
    logic [31:0]        rEX_MEM_AluData;
    logic [31:0]        rEX_MEM_RdData2;
    logic [31:0]        rEX_MEM_PC;
    logic [31:0]        rEX_MEM_PCPlus4;
    logic [ 4:0]        rEX_MEM_Rd;

    logic               rEX_MEM_Valid;
    logic               rEX_MEM_WrEn_Reg;
    wb_sel_e            rEX_MEM_WBSel;
    logic               rEX_MEM_MemValid;
    logic               rEX_MEM_MemWrEn;
    byte_sel_e          rEX_MEM_MemByteSel;

    // EX -> MEM Registers: CSR & Trap
    logic [31:0]        rEX_MEM_CsrSrc;
    logic [31:0]        rEX_MEM_Imm;
    logic [11:0]        rEX_MEM_CsrAddr;
    csr_op_e            rEX_MEM_CsrCtrl;
    logic               rEX_MEM_CsrEn;
    logic               rEX_MEM_CsrWrEn;
    logic               rEX_MEM_CsrRdEn;
    logic               rEX_MEM_CsrImmSel;
    logic               rEX_MEM_Mret;
    logic               rEX_MEM_Exc;
    exception_cause_e   rEX_MEM_Cause;

    // MEM -> WB Registers
    logic [31:0]        rMEM_WB_AluData;
    logic [31:0]        rMEM_WB_MemRdData;
    logic [31:0]        rMEM_WB_PC;
    logic [31:0]        rMEM_WB_PCPlus4;
    logic [ 4:0]        rMEM_WB_Rd;

    logic               rMEM_WB_Valid;
    logic               rMEM_WB_WrEn_Reg;
    wb_sel_e            rMEM_WB_WBSel;

    // MEM -> WB Registers: CSR & Trap
    logic [31:0]        rMEM_WB_CsrSrc;
    logic [31:0]        rMEM_WB_Imm;
    logic [11:0]        rMEM_WB_CsrAddr;
    csr_op_e            rMEM_WB_CsrCtrl;
    logic               rMEM_WB_CsrEn;
    logic               rMEM_WB_CsrWrEn;
    logic               rMEM_WB_CsrRdEn;
    logic               rMEM_WB_CsrImmSel;
    logic               rMEM_WB_Mret;
    logic               rMEM_WB_Exc;
    exception_cause_e   rMEM_WB_Cause;

    // WB Stage
    logic [31:0]        wWrData_Reg;
    logic               wWB_RegWrEn;
    logic               wWB_CsrWrEn;
    logic               wWB_CsrRdEn;

    // WB Stage: CSR & TrapController Wires
    logic [31:0]        wCsrRdData;
    logic [31:0]        wCsrWrData;

    logic [ 3:0]        wTrapFlush;
    logic               wTrapDrain;
    logic               wTrapBranch;
    logic [31:0]        wTrapAddr;

    logic               wTrapCsrWrEn;
    logic [31:0]        wTrapMcause_Wr;
    logic [31:0]        wTrapMepc_Wr;
    logic [31:0]        wTrapMstatus_Wr;
    logic [31:0]        wTrapMtval_Wr;

    logic [31:0]        wTrapMstatus_Rd;
    logic [31:0]        wTrapMie_Rd;
    logic [31:0]        wTrapMip_Rd;
    logic [31:0]        wTrapMtvec_Rd;
    logic [31:0]        wTrapMepc_Rd;

    /***********************************************
    // IF Stage
    ***********************************************/
    ProgramCounter u_programcnt (
        .iClk          (iClk),
        .iRsn          (iRsn),
        .iStall        (wPC_Stall),

        .iTrapBranch   (wTrapBranch),
        .iTrapAddr     (wTrapAddr),

        .iPcSel        (rID_EX_PcSel),
        .iBchSel       (wBranchCond),
        .iBranchTarget (wBranchTarget),
        .iJalrAddr     (wAluData),
        .oPc           (wPc),
        .oPcPlus4      (wPcPlus4)
    );

    assign oInstAddr = wPc;

    /***********************************************
    // IF -> ID
    ***********************************************/
    always_ff @(posedge iClk or negedge iRsn) 
    begin
        if (!iRsn) 
        begin
            rIF_ID_InstData <= 32'h0000_0013;
            rIF_ID_PC       <= 32'b0;
            rIF_ID_PCPlus4  <= 32'b0;
            rIF_ID_Valid    <= 1'b0;
        end 
        else if (wIF_ID_Flush)
        begin
            rIF_ID_InstData <= 32'h0000_0013;
            rIF_ID_PC       <= 32'b0;
            rIF_ID_PCPlus4  <= 32'b0;
            rIF_ID_Valid    <= 1'b0;
        end
        else if (!wIF_ID_Stall)
        begin
            rIF_ID_InstData <= iInstData;
            rIF_ID_PC       <= wPc;
            rIF_ID_PCPlus4  <= wPcPlus4;
            rIF_ID_Valid    <= 1'b1;
        end
    end

    /***********************************************
    // ID Stage
    ***********************************************/
    assign wWB_RegWrEn = rMEM_WB_Valid && rMEM_WB_WrEn_Reg;

    RegisterFile u_registerfile (
        .iClk       (iClk),
        .iRdAddr1   (rIF_ID_InstData[19:15]),
        .iRdAddr2   (rIF_ID_InstData[24:20]),
        .iWrAddr    (rMEM_WB_Rd),
        .iWrData    (wWrData_Reg),
        .iWrEn_Reg  (wWB_RegWrEn), 

        .oRdData1   (wRdData1),
        .oRdData2   (wRdData2)
    );

    ImmExtend u_immextend (
        .iInstData  (rIF_ID_InstData),
        .iImmCtrl   (iImmCtrl),      
        .oExtdData  (wExtdData)
    );

    assign oInstData = rIF_ID_InstData;

    /***********************************************
    // Hazard Unit & ID -> EX
    ***********************************************/
    HazardUnit u_hazardunit (
        .iIF_ID_Rs1     (rIF_ID_InstData[19:15]),       
        .iIF_ID_Rs2     (rIF_ID_InstData[24:20]),
        .iID_EX_Rd      (rID_EX_Rd),    

        .iID_EX_CsrEn   (rID_EX_CsrEn),
        .iEX_MEM_CsrEn  (rEX_MEM_CsrEn),
        .iMEM_WB_CsrEn  (rMEM_WB_CsrEn),

        .iTakeBranch    (wTakeBranch),
        .iID_EX_WBSel   (rID_EX_WBSel),

        .iTrapFlush     (wTrapFlush),
        .iTrapDrain     (wTrapDrain),
        .iTrapBranch    (wTrapBranch),

        .oIF_ID_Stall   (wIF_ID_Stall),
        .oIF_ID_Flush   (wIF_ID_Flush),
        .oID_EX_Flush   (wID_EX_Flush),
        .oEX_MEM_Flush  (wEX_MEM_Flush),
        .oMEM_WB_Flush  (wMEM_WB_Flush),
        
        .oPC_Stall      (wPC_Stall)
    );   

    always_ff @(posedge iClk or negedge iRsn) 
    begin
        if (!iRsn) 
        begin
            // Data
            rID_EX_Rs1        <= 32'b0;
            rID_EX_Rs2        <= 32'b0;
            rID_EX_Imm        <= 32'b0;
            rID_EX_PC         <= 32'b0;
            rID_EX_PCPlus4    <= 32'b0;
            rID_EX_Rd         <= 5'b0;
            rID_EX_Rs1Addr    <= 5'b0;
            rID_EX_Rs2Addr    <= 5'b0;
            // Ctrl
            rID_EX_Valid      <= 1'b0;
            rID_EX_WrEn_Reg   <= 1'b0;
            rID_EX_WBSel      <= WB_ALU;
            rID_EX_AluCtrl    <= ALU_ADD;
            rID_EX_AluSrc1    <= ALU_SRC1_RS1;
            rID_EX_AluSrc2    <= ALU_SRC2_RS2;
            rID_EX_PcSel      <= PC_NEXT;
            rID_EX_BranchEn   <= 1'b0;
            rID_EX_BranchCtrl <= BR_EQ;
            rID_EX_MemValid   <= 1'b0;
            rID_EX_MemWrEn    <= 1'b0;
            rID_EX_MemByteSel <= WORD;
            // CSR & Trap
            rID_EX_CsrAddr    <= 12'b0;
            rID_EX_CsrCtrl    <= CSR_WRITE;
            rID_EX_CsrEn      <= 1'b0;
            rID_EX_CsrWrEn    <= 1'b0;
            rID_EX_CsrRdEn    <= 1'b0;
            rID_EX_CsrImmSel  <= 1'b0;
            rID_EX_Mret       <= 1'b0;
            rID_EX_Exc        <= 1'b0;
            rID_EX_Cause      <= EXC_INST_ADDR_MISALIGNED;
        end
        else if (wID_EX_Flush)
        begin
            rID_EX_Rs1        <= 32'b0;
            rID_EX_Rs2        <= 32'b0;
            rID_EX_Imm        <= 32'b0;
            rID_EX_PC         <= 32'b0;
            rID_EX_PCPlus4    <= 32'b0;
            rID_EX_Rd         <= 5'b0;
            rID_EX_Rs1Addr    <= 5'b0;
            rID_EX_Rs2Addr    <= 5'b0;
            rID_EX_Valid      <= 1'b0;
            rID_EX_WrEn_Reg   <= 1'b0;
            rID_EX_WBSel      <= WB_ALU;
            rID_EX_AluCtrl    <= ALU_ADD;
            rID_EX_AluSrc1    <= ALU_SRC1_RS1;
            rID_EX_AluSrc2    <= ALU_SRC2_RS2;
            rID_EX_PcSel      <= PC_NEXT;
            rID_EX_BranchEn   <= 1'b0;
            rID_EX_BranchCtrl <= BR_EQ;
            rID_EX_MemValid   <= 1'b0;
            rID_EX_MemWrEn    <= 1'b0;
            rID_EX_MemByteSel <= WORD;
            // CSR & Trap
            rID_EX_CsrAddr    <= 12'b0;
            rID_EX_CsrCtrl    <= CSR_WRITE;
            rID_EX_CsrEn      <= 1'b0;
            rID_EX_CsrWrEn    <= 1'b0;
            rID_EX_CsrRdEn    <= 1'b0;
            rID_EX_CsrImmSel  <= 1'b0;
            rID_EX_Mret       <= 1'b0;
            rID_EX_Exc        <= 1'b0;
            rID_EX_Cause      <= EXC_INST_ADDR_MISALIGNED;
        end
        else 
        begin
            // Data
            rID_EX_Rs1        <= wRdData1;
            rID_EX_Rs2        <= wRdData2;
            rID_EX_Imm        <= wExtdData;
            rID_EX_PC         <= rIF_ID_PC;
            rID_EX_PCPlus4    <= rIF_ID_PCPlus4;
            rID_EX_Rd         <= rIF_ID_InstData[11:7];
            rID_EX_Rs1Addr    <= rIF_ID_InstData[19:15];
            rID_EX_Rs2Addr    <= rIF_ID_InstData[24:20];
            // Ctrl
            rID_EX_Valid      <= rIF_ID_Valid;
            rID_EX_WrEn_Reg   <= rIF_ID_Valid && iWrEn_Reg;
            rID_EX_WBSel      <= iWBSel;
            rID_EX_AluCtrl    <= iAluCtrl;
            rID_EX_AluSrc1    <= iAluSrc1;
            rID_EX_AluSrc2    <= iAluSrc2;
            rID_EX_PcSel      <= rIF_ID_Valid ? iPcSel : PC_NEXT;
            rID_EX_BranchEn   <= rIF_ID_Valid && iBranchEn;
            rID_EX_BranchCtrl <= iBranchCtrl;
            rID_EX_MemValid   <= rIF_ID_Valid && iMemValid;
            rID_EX_MemWrEn    <= rIF_ID_Valid && iMemWrEn;
            rID_EX_MemByteSel <= iMemByteSel;
            // CSR & Trap
            rID_EX_CsrAddr    <= rIF_ID_InstData[31:20];
            rID_EX_CsrCtrl    <= iCsrCtrl;
            rID_EX_CsrEn      <= rIF_ID_Valid && iCsrEn;
            rID_EX_CsrWrEn    <= rIF_ID_Valid && iCsrWrEn;
            rID_EX_CsrRdEn    <= rIF_ID_Valid && iCsrRdEn;
            rID_EX_CsrImmSel  <= iCsrImmSel;
            rID_EX_Mret       <= rIF_ID_Valid && iIsMret;
            rID_EX_Exc        <= rIF_ID_Valid && iIsException;
            rID_EX_Cause      <= iExceptionCause;
        end                      
    end

    /***********************************************
    // EX Stage
    ***********************************************/
    Forwarding u_forwarding (
        .iEX_MEM_WbEn    (rEX_MEM_WrEn_Reg),
        .iMEM_WB_WbEn    (rMEM_WB_WrEn_Reg),
                         
        .iID_EX_Rs1      (rID_EX_Rs1Addr),
        .iID_EX_Rs2      (rID_EX_Rs2Addr),
        .iEX_MEM_Rd      (rEX_MEM_Rd),       
        .iMEM_WB_Rd      (rMEM_WB_Rd),       
                         
        .oFwdRs1_En      (wFwdRs1_En),      // 0 : RegFile 1 : Forwarding 
        .oFwdRs1_Sel     (wFwdRs1_Sel),     // 0 : EX_MEM  1 : MEM_WB     
        .oFwdRs2_En      (wFwdRs2_En),      // 0 : RegFile 1 : Forwarding 
        .oFwdRs2_Sel     (wFwdRs2_Sel)      // 0 : EX_MEM  1 : MEM_WB
    );

    // EX/MEM or MEM/WB mux
    always_comb 
    begin
        case (wFwdRs1_Sel)
            1'b0    : wAluRs1_Bypass = rEX_MEM_AluData;
            1'b1    : wAluRs1_Bypass = wWrData_Reg;
            default : wAluRs1_Bypass = rID_EX_Rs1;
        endcase
    end
    
    always_comb 
    begin
        case (wFwdRs2_Sel)
            1'b0    : wAluRs2_Bypass = rEX_MEM_AluData;
            1'b1    : wAluRs2_Bypass = wWrData_Reg;
            default : wAluRs2_Bypass = rID_EX_Rs2;
        endcase
    end

    // Forwarding or Not mux
    always_comb 
    begin
        case (wFwdRs1_En)
            1'b0    : wAluRs1_Fwd = rID_EX_Rs1;
            1'b1    : wAluRs1_Fwd = wAluRs1_Bypass;      
            default : wAluRs1_Fwd = rID_EX_Rs1;
        endcase
    end

    always_comb 
    begin
        case (wFwdRs2_En)
            1'b0    : wAluRs2_Fwd = rID_EX_Rs2;
            1'b1    : wAluRs2_Fwd = wAluRs2_Bypass;      
            default : wAluRs2_Fwd = rID_EX_Rs2;
        endcase
    end

    // ALU Src mux
    always_comb 
    begin
        case (rID_EX_AluSrc1)
            ALU_SRC1_RS1  : wAluRs1 = wAluRs1_Fwd;
            ALU_SRC1_PC   : wAluRs1 = rID_EX_PC;      
            ALU_SRC1_ZERO : wAluRs1 = 32'b0;
            default       : wAluRs1 = rID_EX_Rs1;
        endcase
    end

    always_comb 
    begin
        case (rID_EX_AluSrc2)
            ALU_SRC2_RS2 : wAluRs2 = wAluRs2_Fwd;
            ALU_SRC2_IMM : wAluRs2 = rID_EX_Imm;
            default      : wAluRs2 = wAluRs2_Fwd;
        endcase
    end

    Alu u_alu (
        .iRs1       (wAluRs1),
        .iRs2       (wAluRs2),
        .iAluCtrl   (rID_EX_AluCtrl),
        .iBranchEn  (rID_EX_BranchEn),
        .iBranchCtrl(rID_EX_BranchCtrl),
        .oData      (wAluData),
        .oBchSel    (wBranchCond)
    );

    // Branch / Jump Target Adder (Using EX Stage PC + Imm)
    assign wBranchTarget = rID_EX_PC + rID_EX_Imm;

    // Branch / Jump Occurrence Detection
    always_comb 
    begin
        if (rID_EX_PcSel == PC_JAL) 
        begin
            wTakeBranch = 1'b1;
        end
        else if (rID_EX_PcSel == PC_JALR) 
        begin
            wTakeBranch = 1'b1;
        end
        else if ((rID_EX_PcSel == PC_BRANCH) && (wBranchCond == 1'b1))
        begin
            wTakeBranch = 1'b1;
        end
        else 
        begin
            wTakeBranch = 1'b0;
        end
    end

    /***********************************************
    // EX -> MEM 
    ***********************************************/
    always_ff @(posedge iClk or negedge iRsn) 
    begin
        if (!iRsn) 
        begin
            // Data
            rEX_MEM_AluData    <= 32'b0;
            rEX_MEM_RdData2    <= 32'b0;
            rEX_MEM_PC         <= 32'b0;
            rEX_MEM_PCPlus4    <= 32'b0;
            rEX_MEM_Rd         <= 5'b0;
            // Ctrl
            rEX_MEM_Valid      <= 1'b0;
            rEX_MEM_WrEn_Reg   <= 1'b0;
            rEX_MEM_WBSel      <= WB_ALU;
            rEX_MEM_MemValid   <= 1'b0;
            rEX_MEM_MemWrEn    <= 1'b0;
            rEX_MEM_MemByteSel <= WORD;
            // CSR & Trap
            rEX_MEM_CsrCtrl    <= CSR_WRITE;
            rEX_MEM_CsrAddr    <= 12'b0;
            rEX_MEM_CsrEn      <= 1'b0;
            rEX_MEM_CsrWrEn    <= 1'b0;
            rEX_MEM_CsrRdEn    <= 1'b0;
            rEX_MEM_CsrImmSel  <= 1'b0;
            rEX_MEM_Imm        <= 32'b0; 
            rEX_MEM_CsrSrc     <= 32'b0;
            rEX_MEM_Mret       <= 1'b0;
            rEX_MEM_Exc        <= 1'b0;
            rEX_MEM_Cause      <= EXC_INST_ADDR_MISALIGNED;
        end 
        else if (wEX_MEM_Flush)
        begin
            rEX_MEM_AluData    <= 32'b0;
            rEX_MEM_RdData2    <= 32'b0;
            rEX_MEM_PC         <= 32'b0;
            rEX_MEM_PCPlus4    <= 32'b0;
            rEX_MEM_Rd         <= 5'b0;
            rEX_MEM_Valid      <= 1'b0;
            rEX_MEM_WrEn_Reg   <= 1'b0;
            rEX_MEM_WBSel      <= WB_ALU;
            rEX_MEM_MemValid   <= 1'b0;
            rEX_MEM_MemWrEn    <= 1'b0;
            rEX_MEM_MemByteSel <= WORD;
            rEX_MEM_CsrCtrl    <= CSR_WRITE;
            rEX_MEM_CsrAddr    <= 12'b0;
            rEX_MEM_CsrEn      <= 1'b0;
            rEX_MEM_CsrWrEn    <= 1'b0;
            rEX_MEM_CsrRdEn    <= 1'b0;
            rEX_MEM_CsrImmSel  <= 1'b0;
            rEX_MEM_Imm        <= 32'b0; 
            rEX_MEM_CsrSrc     <= 32'b0;
            rEX_MEM_Mret       <= 1'b0;
            rEX_MEM_Exc        <= 1'b0;
            rEX_MEM_Cause      <= EXC_INST_ADDR_MISALIGNED;
        end
        else 
        begin
            // Data
            rEX_MEM_AluData    <= wAluData;
            rEX_MEM_RdData2    <= wAluRs2_Fwd;
            rEX_MEM_PC         <= rID_EX_PC;
            rEX_MEM_PCPlus4    <= rID_EX_PCPlus4;
            rEX_MEM_Rd         <= rID_EX_Rd;
            // Ctrl
            rEX_MEM_Valid      <= rID_EX_Valid;
            rEX_MEM_WrEn_Reg   <= rID_EX_WrEn_Reg;
            rEX_MEM_WBSel      <= rID_EX_WBSel; 
            rEX_MEM_MemValid   <= rID_EX_MemValid;
            rEX_MEM_MemWrEn    <= rID_EX_MemWrEn;
            rEX_MEM_MemByteSel <= rID_EX_MemByteSel;
            // CSR & Trap
            rEX_MEM_CsrAddr    <= rID_EX_CsrAddr;
            rEX_MEM_CsrCtrl    <= rID_EX_CsrCtrl;              
            rEX_MEM_CsrEn      <= rID_EX_CsrEn;              
            rEX_MEM_CsrWrEn    <= rID_EX_CsrWrEn;            
            rEX_MEM_CsrRdEn    <= rID_EX_CsrRdEn;          
            rEX_MEM_CsrImmSel  <= rID_EX_CsrImmSel; 
            rEX_MEM_CsrSrc     <= wAluRs1_Fwd;
            rEX_MEM_Imm        <= rID_EX_Imm;
            rEX_MEM_Mret       <= rID_EX_Mret;
            rEX_MEM_Exc        <= rID_EX_Exc;
            rEX_MEM_Cause      <= rID_EX_Cause;
        end
    end
   
    /***********************************************
    // MEM Stage
    ***********************************************/
    assign oMemAddr    = rEX_MEM_AluData;
    assign oMemWrData  = rEX_MEM_RdData2;
    assign oMemValid   = rEX_MEM_MemValid;
    assign oMemWrEn    = oMemValid && rEX_MEM_MemWrEn;
    assign oMemByteSel = rEX_MEM_MemByteSel;

    /***********************************************
    // MEM -> WB 
    ***********************************************/
    always_ff @(posedge iClk or negedge iRsn) 
    begin
        if (!iRsn) 
        begin
            // Data
            rMEM_WB_AluData   <= 32'b0;
            rMEM_WB_MemRdData <= 32'b0;
            rMEM_WB_PC        <= 32'b0;
            rMEM_WB_PCPlus4   <= 32'b0;
            rMEM_WB_Rd        <= 5'b0;
            // Ctrl
            rMEM_WB_Valid     <= 1'b0;
            rMEM_WB_WrEn_Reg  <= 1'b0;
            rMEM_WB_WBSel     <= WB_ALU;
            // CSR & Trap
            rMEM_WB_CsrCtrl   <= CSR_WRITE;
            rMEM_WB_CsrAddr   <= 12'b0;
            rMEM_WB_CsrEn     <= 1'b0;
            rMEM_WB_CsrWrEn   <= 1'b0;
            rMEM_WB_CsrRdEn   <= 1'b0;
            rMEM_WB_CsrImmSel <= 1'b0;
            rMEM_WB_CsrSrc    <= 32'b0;
            rMEM_WB_Imm       <= 32'b0;
            rMEM_WB_Mret      <= 1'b0;
            rMEM_WB_Exc       <= 1'b0;
            rMEM_WB_Cause     <= EXC_INST_ADDR_MISALIGNED;
        end 
        else if (wMEM_WB_Flush)
        begin
            rMEM_WB_AluData   <= 32'b0;
            rMEM_WB_MemRdData <= 32'b0;
            rMEM_WB_PC        <= 32'b0;
            rMEM_WB_PCPlus4   <= 32'b0;
            rMEM_WB_Rd        <= 5'b0;
            rMEM_WB_Valid     <= 1'b0;
            rMEM_WB_WrEn_Reg  <= 1'b0;
            rMEM_WB_WBSel     <= WB_ALU;
            rMEM_WB_CsrCtrl   <= CSR_WRITE;
            rMEM_WB_CsrAddr   <= 12'b0;
            rMEM_WB_CsrEn     <= 1'b0;
            rMEM_WB_CsrWrEn   <= 1'b0;
            rMEM_WB_CsrRdEn   <= 1'b0;
            rMEM_WB_CsrImmSel <= 1'b0;
            rMEM_WB_CsrSrc    <= 32'b0;
            rMEM_WB_Imm       <= 32'b0;
            rMEM_WB_Mret      <= 1'b0;
            rMEM_WB_Exc       <= 1'b0;
            rMEM_WB_Cause     <= EXC_INST_ADDR_MISALIGNED;
        end
        else 
        begin
            // Data
            rMEM_WB_AluData   <= rEX_MEM_AluData;
            rMEM_WB_MemRdData <= iMemRdData;
            rMEM_WB_PC        <= rEX_MEM_PC;
            rMEM_WB_PCPlus4   <= rEX_MEM_PCPlus4;
            rMEM_WB_Rd        <= rEX_MEM_Rd;
            // Ctrl
            rMEM_WB_Valid     <= rEX_MEM_Valid;
            rMEM_WB_WrEn_Reg  <= rEX_MEM_WrEn_Reg;
            rMEM_WB_WBSel     <= rEX_MEM_WBSel; 
            // CSR & Trap
            rMEM_WB_CsrAddr   <= rEX_MEM_CsrAddr;
            rMEM_WB_CsrCtrl   <= rEX_MEM_CsrCtrl;              
            rMEM_WB_CsrEn     <= rEX_MEM_CsrEn;              
            rMEM_WB_CsrWrEn   <= rEX_MEM_CsrWrEn;            
            rMEM_WB_CsrRdEn   <= rEX_MEM_CsrRdEn;          
            rMEM_WB_CsrImmSel <= rEX_MEM_CsrImmSel; 
            rMEM_WB_Imm       <= rEX_MEM_Imm;
            rMEM_WB_CsrSrc    <= rEX_MEM_CsrSrc;
            rMEM_WB_Mret      <= rEX_MEM_Mret;
            rMEM_WB_Exc       <= rEX_MEM_Exc;
            rMEM_WB_Cause     <= rEX_MEM_Cause;
        end
    end

    /***********************************************
    // WB Stage
    ***********************************************/
    always_comb 
    begin
        case (rMEM_WB_WBSel)
            WB_ALU  : wWrData_Reg = rMEM_WB_AluData;
            WB_MEM  : wWrData_Reg = rMEM_WB_MemRdData;
            WB_PC4  : wWrData_Reg = rMEM_WB_PCPlus4; 
            WB_CSR  : wWrData_Reg = wCsrRdData;
            default : wWrData_Reg = rMEM_WB_AluData;
        endcase
    end

    assign wWB_CsrWrEn = rMEM_WB_Valid && rMEM_WB_CsrWrEn;
    assign wWB_CsrRdEn = rMEM_WB_Valid && rMEM_WB_CsrRdEn;

    CsrRegisterFile u_csrregisterfile (
        .iClk           (iClk),
        .iRsn           (iRsn),
        .iCsrWrEn       (wWB_CsrWrEn),
        .iCsrRdEn       (wWB_CsrRdEn),
        .iCsrAddr       (rMEM_WB_CsrAddr),

        .iCsrWrEn_Trap  (wTrapCsrWrEn),
        .iTrapMstatus   (wTrapMstatus_Wr),
        .iTrapMepc      (wTrapMepc_Wr),
        .iTrapMcause    (wTrapMcause_Wr),
        .iTrapMtval     (wTrapMtval_Wr),
        .iIsMret        (rMEM_WB_Mret),

        .iMip_MEIP      (iMip_MEIP),
        .iMip_MTIP      (iMip_MTIP),
        .iMip_MSIP      (iMip_MSIP),

        .iCsrWrData     (wCsrWrData),
        .oCsrRdData     (wCsrRdData),

        .oTrapMstatus   (wTrapMstatus_Rd),
        .oTrapMie       (wTrapMie_Rd),
        .oTrapMip       (wTrapMip_Rd),
        .oTrapMtvec     (wTrapMtvec_Rd),
        .oTrapMepc      (wTrapMepc_Rd)
    );

    CsrOperation u_csroperation (
        .iCsrOp         (rMEM_WB_CsrCtrl),
        .iCsrImmSel     (rMEM_WB_CsrImmSel),
        .iCsrData       (wCsrRdData),
        .iRs1Data       (rMEM_WB_CsrSrc),
        .iZimm          (rMEM_WB_Imm[4:0]),
        .oCsrData       (wCsrWrData)
    );

    TrapController u_trapcontroller (
        .iClk           (iClk),
        .iRsn           (iRsn),

        .iPc            (wPc),
        .iMEM_WB_Pc     (rMEM_WB_PC),

        .iIF_ID_Valid   (rIF_ID_Valid),
        .iID_EX_Valid   (rID_EX_Valid),
        .iEX_MEM_Valid  (rEX_MEM_Valid),
        .iMEM_WB_Valid  (rMEM_WB_Valid),

        .iID_EX_Exc     (rID_EX_Exc),
        .iEX_MEM_Exc    (rEX_MEM_Exc),
        .iMEM_WB_Exc    (rMEM_WB_Exc),

        .iMEM_WB_Mret   (rMEM_WB_Mret),
        .iMEM_WB_Cause  (rMEM_WB_Cause),

        .iMstatus       (wTrapMstatus_Rd),
        .iMip           (wTrapMip_Rd),
        .iMie           (wTrapMie_Rd),
        .iMtvec         (wTrapMtvec_Rd),
        .iMepc          (wTrapMepc_Rd),

        .oTrapFlush     (wTrapFlush),
        .oTrapDrain     (wTrapDrain),

        .oCsrWrEn       (wTrapCsrWrEn),
        .oMcause        (wTrapMcause_Wr),
        .oMepc          (wTrapMepc_Wr),
        .oMstatus       (wTrapMstatus_Wr),
        .oMtval         (wTrapMtval_Wr),

        .oTrapBranch    (wTrapBranch),
        .oTrapAddr      (wTrapAddr)
    );

endmodule
