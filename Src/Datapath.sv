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

    // MEM -> WB Registers
    logic [31:0]        rMEM_WB_AluData;
    logic [31:0]        rMEM_WB_MemRdData;
    logic [31:0]        rMEM_WB_PCPlus4;
    logic [ 4:0]        rMEM_WB_Rd;

    logic               rMEM_WB_WrEn_Reg;
    wb_sel_e            rMEM_WB_WBSel;

    // WB Stage
    logic [31:0]        wWrData_Reg;


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
            default: wWrData_Reg = rMEM_WB_AluData;
        endcase
    end

endmodule
