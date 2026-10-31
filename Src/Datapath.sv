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
                                      - CSR read/modify/write all in WB stage
                                      - CSR ctrl/data carried through ID/EX, EX/MEM, MEM/WB
                                      - CSR result written back to rd via WB_CSR
                     15) 2026.10.31 : Add CSR remain logic
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module Datapath (
    // Input Ports: Clock and Reset
    input  logic        iClk,
    input  logic        iRsn,

    // Input Ports: Control
    input  logic        iWrEn_Reg,
    input  wb_sel_e     iWBSel,
    input  alu_op_e     iAluCtrl,    
    input  imm_type_e   iImmCtrl,    
    input  alu_src1_e   iAluSrc1,
    input  alu_src2_e   iAluSrc2,
    input  pc_sel_e     iPcSel,
    input  logic        iBranchEn,
    input  branch_op_e  iBranchCtrl,
    input  logic        iMemValid,
    input  logic        iMemWrEn,
    input  byte_sel_e   iMemByteSel,

    // Input Ports: CSR Control (decoded in ID, used in WB)
    input csr_op_e       iCsrCtrl,      // CSR operation : WRITE / SET / CLEAR
    input logic          iCsrEn,        // CSR instruction valid
    input logic          iCsrWrEn,      // CSR write enable
    input logic          iCsrRdEn,      // CSR read enable
    input logic          iCsrImmSel,    // 0 : rs1, 1 : zimm (CSRRxI)

    // Input Ports: Data
    input  logic [31:0] iInstData,
    input  logic [31:0] iMemRdData,

    // Output Ports: Control
    output logic        oMemValid,
    output logic        oMemWrEn,
    output byte_sel_e   oMemByteSel,

    // Output Ports: Data
    output logic [31:0] oInstAddr,
    output logic [31:0] oInstData,
    output logic [31:0] oMemWrData,
    output logic [31:0] oMemAddr
);

    // ==========================================
    // Internal Signals & Pipeline Registers
    // ==========================================
    // IF Stage
    logic [31:0]        wPc;     
    logic [31:0]        wPcPlus4;
    logic               wBranchCond;
    logic               wIF_ID_Stall;
    logic               wIF_ID_Flush;
    logic               wID_EX_Flush;
    logic               wPC_Stall;

    // IF -> ID Registers
    logic [31:0]        rIF_ID_InstData;
    logic [31:0]        rIF_ID_PC;
    logic [31:0]        rIF_ID_PCPlus4;

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

    // ID -> EX Registers: CSR
    logic [11:0]        rID_EX_CsrAddr;
    csr_op_e            rID_EX_CsrCtrl;
    logic               rID_EX_CsrEn;
    logic               rID_EX_CsrWrEn;
    logic               rID_EX_CsrRdEn;
    logic               rID_EX_CsrImmSel;


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
    logic [31:0]        rEX_MEM_PCPlus4;
    logic [ 4:0]        rEX_MEM_Rd;

    logic               rEX_MEM_WrEn_Reg;
    wb_sel_e            rEX_MEM_WBSel;
    logic               rEX_MEM_MemValid;
    logic               rEX_MEM_MemWrEn;
    byte_sel_e          rEX_MEM_MemByteSel;

    // EX -> MEM Registers: CSR
    logic [31:0]       rEX_MEM_CsrSrc;  // forwarded rs1 value for CSR operation
    logic [31:0]       rEX_MEM_Imm;     // zimm (IMM_Z) for CSRRxI
    logic [11:0]       rEX_MEM_CsrAddr;
    csr_op_e           rEX_MEM_CsrCtrl;
    logic              rEX_MEM_CsrEn;
    logic              rEX_MEM_CsrWrEn;
    logic              rEX_MEM_CsrRdEn;
    logic              rEX_MEM_CsrImmSel;

    // MEM -> WB Registers
    logic [31:0]        rMEM_WB_AluData;
    logic [31:0]        rMEM_WB_MemRdData;
    logic [31:0]        rMEM_WB_PCPlus4;
    logic [ 4:0]        rMEM_WB_Rd;

    logic               rMEM_WB_WrEn_Reg;
    wb_sel_e            rMEM_WB_WBSel;

    // MEM -> WB Registers: CSR
    logic [31:0]        rMEM_WB_CsrSrc;
    logic [31:0]        rMEM_WB_Imm;
    logic [11:0]        rMEM_WB_CsrAddr;
    csr_op_e            rMEM_WB_CsrCtrl;
    logic               rMEM_WB_CsrEn;
    logic               rMEM_WB_CsrWrEn;
    logic               rMEM_WB_CsrRdEn;
    logic               rMEM_WB_CsrImmSel;

    // WB Stage
    logic [31:0]        wWrData_Reg;

    // WB Stage: CSR
    logic [31:0]        wCsrRdData;         // old CSR value -> rd
    logic [31:0]        wCsrWrData;         // CSR operation result -> CSR register

    /***********************************************
    // IF Stage
    ***********************************************/
    ProgramCounter u_programcnt (
        .iClk          (iClk),
        .iRsn          (iRsn),
        .iStall        (wPC_Stall),

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
        end 
        else if (wIF_ID_Flush)
        begin
            rIF_ID_InstData <= 32'h0000_0013;
            rIF_ID_PC       <= 32'b0;
            rIF_ID_PCPlus4  <= 32'b0;
        end
        else if (!wIF_ID_Stall)
        begin
            rIF_ID_InstData <= iInstData;
            rIF_ID_PC       <= wPc;
            rIF_ID_PCPlus4  <= wPcPlus4;
        end
    end

    /***********************************************
    // ID Stage
    ***********************************************/
    RegisterFile u_registerfile (
        .iClk       (iClk),
        .iRdAddr1   (rIF_ID_InstData[19:15]),
        .iRdAddr2   (rIF_ID_InstData[24:20]),
        .iWrAddr    (rMEM_WB_Rd),
        .iWrData    (wWrData_Reg),
        .iWrEn_Reg  (rMEM_WB_WrEn_Reg), 

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
    // ID -> EX
    ***********************************************/
    HazardUnit u_hazardunit(
        .iIF_ID_Rs1     (rIF_ID_InstData[19:15]),       
        .iIF_ID_Rs2     (rIF_ID_InstData[24:20]),
        .iID_EX_Rd      (rID_EX_Rd),    

        .iTakeBranch    (wTakeBranch),
        .iID_EX_WBSel   (rID_EX_WBSel),

        .iID_EX_CsrEn   (rID_EX_CsrEn),
        .iEX_MEM_CsrEn  (rEX_MEM_CsrEn),
        .iMEM_WB_CsrEn  (rMEM_WB_CsrEn),

        .oIF_ID_Stall   (wIF_ID_Stall),
        .oIF_ID_Flush   (wIF_ID_Flush),
        .oID_EX_Flush   (wID_EX_Flush),
        
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
            // Csr
            rID_EX_CsrAddr     <= 12'b0;
            rID_EX_CsrCtrl     <= CSR_WRITE;    // don't care while CsrWrEn = 0
            rID_EX_CsrEn       <= 1'b0;
            rID_EX_CsrWrEn     <= 1'b0;
            rID_EX_CsrRdEn     <= 1'b0;
            rID_EX_CsrImmSel   <= 1'b0;
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
            // Csr : flushed CSR instruction never writes CSR (no speculative CSR write)
            rID_EX_CsrAddr     <= 12'b0;
            rID_EX_CsrCtrl     <= CSR_WRITE;
            rID_EX_CsrEn       <= 1'b0;
            rID_EX_CsrWrEn     <= 1'b0;
            rID_EX_CsrRdEn     <= 1'b0;
            rID_EX_CsrImmSel   <= 1'b0;
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
            rID_EX_WrEn_Reg   <= iWrEn_Reg;
            rID_EX_WBSel      <= iWBSel;
            rID_EX_AluCtrl    <= iAluCtrl;
            rID_EX_AluSrc1    <= iAluSrc1;
            rID_EX_AluSrc2    <= iAluSrc2;
            rID_EX_PcSel      <= iPcSel;
            rID_EX_BranchEn   <= iBranchEn;
            rID_EX_BranchCtrl <= iBranchCtrl;
            rID_EX_MemValid   <= iMemValid;
            rID_EX_MemWrEn    <= iMemWrEn;
            rID_EX_MemByteSel <= iMemByteSel;
            // Csr
            rID_EX_CsrAddr     <= rIF_ID_InstData[31:20];   // csr field of instruction
            rID_EX_CsrCtrl     <= iCsrCtrl;
            rID_EX_CsrEn       <= iCsrEn;
            rID_EX_CsrWrEn     <= iCsrWrEn;
            rID_EX_CsrRdEn     <= iCsrRdEn;
            rID_EX_CsrImmSel   <= iCsrImmSel;
        end                      
    end

    /***********************************************
    // EX Stage
    ***********************************************/
    Forwarding u_forwarding(
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
    // Src1
    always_comb 
    begin
        case (wFwdRs1_Sel)
            0 : wAluRs1_Bypass = rEX_MEM_AluData;
            1 : wAluRs1_Bypass = wWrData_Reg;
            default : wAluRs1_Bypass = rID_EX_Rs1;
        endcase
    end
    
    // Src2
    always_comb 
    begin
        case (wFwdRs2_Sel)
            0 : wAluRs2_Bypass = rEX_MEM_AluData;
            1 : wAluRs2_Bypass = wWrData_Reg;
            default : wAluRs2_Bypass = rID_EX_Rs2;
        endcase
    end
    // Forwarding or Not mux
    // Src1
    always_comb 
    begin
        case (wFwdRs1_En)
            0 : wAluRs1_Fwd = rID_EX_Rs1;
            1 : wAluRs1_Fwd = wAluRs1_Bypass;      
            default : wAluRs1_Fwd = rID_EX_Rs1;
        endcase
    end

    // Src2
    always_comb 
    begin
        case (wFwdRs2_En)
            0 : wAluRs2_Fwd = rID_EX_Rs2;
            1 : wAluRs2_Fwd = wAluRs2_Bypass;      
            default : wAluRs2_Fwd = rID_EX_Rs2;
        endcase
    end

    // Alu Scr mux
    // Src1 mux
    always_comb 
    begin
        case (rID_EX_AluSrc1)
            ALU_SRC1_RS1 : wAluRs1 = wAluRs1_Fwd;
            ALU_SRC1_PC  : wAluRs1 = rID_EX_PC;      
            ALU_SRC1_ZERO: wAluRs1 = 32'b0;
            default      : wAluRs1 = rID_EX_Rs1;
        endcase
    end

    // Src2 mux
    always_comb 
    begin
        case (rID_EX_AluSrc2)
            ALU_SRC2_RS2: wAluRs2 = wAluRs2_Fwd;
            ALU_SRC2_IMM: wAluRs2 = rID_EX_Imm;
            default     : wAluRs2 = wAluRs2_Fwd;
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
            rEX_MEM_PCPlus4    <= 32'b0;
            rEX_MEM_Rd         <= 5'b0;
            // Ctrl
            rEX_MEM_WrEn_Reg   <= 1'b0;
            rEX_MEM_WBSel      <= WB_ALU;
            rEX_MEM_MemValid   <= 1'b0;
            rEX_MEM_MemWrEn    <= 1'b0;
            rEX_MEM_MemByteSel <= WORD;
            // Csr
            rEX_MEM_CsrCtrl     <= CSR_WRITE;
            rEX_MEM_CsrAddr     <= 12'b0;
            rEX_MEM_CsrEn       <= 1'b0;
            rEX_MEM_CsrWrEn     <= 1'b0;
            rEX_MEM_CsrRdEn     <= 1'b0;
            rEX_MEM_CsrImmSel   <= 1'b0;
            rEX_MEM_Imm         <= 32'b0; 
            rEX_MEM_CsrSrc      <= 32'b0;     
        end 
        else 
        begin
            // Data
            rEX_MEM_AluData    <= wAluData;
            rEX_MEM_RdData2    <= wAluRs2_Fwd;
            rEX_MEM_PCPlus4    <= rID_EX_PCPlus4;
            rEX_MEM_Rd         <= rID_EX_Rd;
            // Ctrl
            rEX_MEM_WrEn_Reg   <= rID_EX_WrEn_Reg;
            rEX_MEM_WBSel      <= rID_EX_WBSel; 
            rEX_MEM_MemValid   <= rID_EX_MemValid;
            rEX_MEM_MemWrEn    <= rID_EX_MemWrEn;
            rEX_MEM_MemByteSel <= rID_EX_MemByteSel;
            // Csr : carried to WB only (no CSR operation before WB)
            rEX_MEM_CsrAddr     <= rID_EX_CsrAddr;
            rEX_MEM_CsrCtrl     <= rID_EX_CsrCtrl;              
            rEX_MEM_CsrEn       <= rID_EX_CsrEn;              
            rEX_MEM_CsrWrEn     <= rID_EX_CsrWrEn;            
            rEX_MEM_CsrRdEn     <= rID_EX_CsrRdEn;          
            rEX_MEM_CsrImmSel   <= rID_EX_CsrImmSel; 
            rEX_MEM_CsrSrc      <= wAluRs1_Fwd;   // CSR-only path: forwarded rs1 (not ALU input), used in WB
            rEX_MEM_Imm         <= rID_EX_Imm;    // zimm from ImmExtend (IMM_Z)
        end
    end
   
    /***********************************************
    // MEM Stage
    ***********************************************/
    assign oMemAddr    = rEX_MEM_AluData;
    assign oMemWrData  = rEX_MEM_RdData2;
    assign oMemValid   = rEX_MEM_MemValid;
    assign oMemWrEn    = rEX_MEM_MemWrEn;
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
            rMEM_WB_PCPlus4   <= 32'b0;
            rMEM_WB_Rd        <= 5'b0;
            // Ctrl
            rMEM_WB_WrEn_Reg  <= 1'b0;
            rMEM_WB_WBSel     <= WB_ALU;
            // Csr
            rMEM_WB_CsrCtrl     <= CSR_WRITE;
            rMEM_WB_CsrAddr     <= 12'b0;
            rMEM_WB_CsrEn       <= 1'b0;
            rMEM_WB_CsrWrEn     <= 1'b0;
            rMEM_WB_CsrRdEn     <= 1'b0;
            rMEM_WB_CsrImmSel   <= 1'b0;
            rMEM_WB_CsrSrc      <= 32'b0;
            rMEM_WB_Imm         <= 32'b0;
      end 
        else 
        begin
            // Data
            rMEM_WB_AluData   <= rEX_MEM_AluData;
            rMEM_WB_MemRdData <= iMemRdData;
            rMEM_WB_PCPlus4   <= rEX_MEM_PCPlus4;
            rMEM_WB_Rd        <= rEX_MEM_Rd;
            // Ctrl
            rMEM_WB_WrEn_Reg  <= rEX_MEM_WrEn_Reg;
            rMEM_WB_WBSel     <= rEX_MEM_WBSel; 
            // Csr
            rMEM_WB_CsrAddr     <= rEX_MEM_CsrAddr;
            rMEM_WB_CsrCtrl     <= rEX_MEM_CsrCtrl;              
            rMEM_WB_CsrEn       <= rEX_MEM_CsrEn;              
            rMEM_WB_CsrWrEn     <= rEX_MEM_CsrWrEn;            
            rMEM_WB_CsrRdEn     <= rEX_MEM_CsrRdEn;          
            rMEM_WB_CsrImmSel   <= rEX_MEM_CsrImmSel; 
            rMEM_WB_Imm         <= rEX_MEM_Imm;
            rMEM_WB_CsrSrc      <= rEX_MEM_CsrSrc;

        end
    end

    /***********************************************
    // WB Stage
    ***********************************************/
    always_comb 
    begin
        case (rMEM_WB_WBSel)
            WB_ALU : wWrData_Reg = rMEM_WB_AluData;
            WB_MEM : wWrData_Reg = rMEM_WB_MemRdData;
            WB_PC4 : wWrData_Reg = rMEM_WB_PCPlus4; 
            WB_CSR : wWrData_Reg = wCsrRdData;      // old CSR value -> rd (also MEM/WB forwarding source)
            default: wWrData_Reg = rMEM_WB_AluData;
        endcase
    end

    // CSR read (comb) -> CsrOperation -> CSR write (posedge), all in WB stage
    // Back-to-back CSR instructions need no bypass: the next one reads in the next cycle
    CsrRegisterFile U_csrregisterfile (
        .iClk       (iClk),
        .iRsn       (iRsn),
        .iCsrWrEn   (rMEM_WB_CsrWrEn),
        .iCsrRdEn   (rMEM_WB_CsrRdEn),
        .iCsrAddr   (rMEM_WB_CsrAddr),
        .iCsrWrData (wCsrWrData),
        .oCsrRdData (wCsrRdData)
    );

    CsrOperation U_csroperation (
        .iCsrOp     (rMEM_WB_CsrCtrl),
        .iCsrImmSel (rMEM_WB_CsrImmSel),
        .iCsrData   (wCsrRdData),           // old CSR value
        .iRs1Data   (rMEM_WB_CsrSrc),       // forwarded rs1
        .iZimm      (rMEM_WB_Imm[4:0]),     // zimm
        .oCsrData   (wCsrWrData)
    );


endmodule
