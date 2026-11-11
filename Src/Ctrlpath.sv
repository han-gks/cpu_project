/**************************************************************
 - Project          : CPU_OS
 - File name        : Ctrlpath.sv
 - Description      : Control Path Decoder (RV32I + Zicsr + Trap)
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.02 : Initial release
                      4) 2026.09.08 : Apply enum for selector
                      6) 2026.09.09 : Complete base opcode
                      7) 2026.10.30 : Add CSR decode (OP_SYSTEM : CSRRW/S/C, CSRRWI/SI/CI)
                      8) 2026.10.31 : Add CSR enum
                      9) 2026.11.08 : Add Trap decode (ECALL, MRET, Illegal Instruction)
                     10) 2026.11.11 : Integrate Trap decode outputs for TrapController
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;  

module Ctrlpath (
    // Input Ports: Data
    input  logic [31:0]         iInstData,

    // Output Ports: Control
    output alu_op_e             oAluCtrl,
    output imm_type_e           oImmCtrl,
    output alu_src1_e           oAluSrc1,
    output alu_src2_e           oAluSrc2,
    output wb_sel_e             oWBSel,
    output pc_sel_e             oPcSel,
    output logic                oMemValid,
    output logic                oMemWrEn,
    output logic                oWrEn_Reg,
    output logic                oBranchEn,
    output branch_op_e          oBranchCtrl,
    output byte_sel_e           oMemByteSel,

    // Output Ports: CSR Control
    output csr_op_e             oCsrCtrl,       // CSR operation : WRITE / SET / CLEAR
    output logic                oCsrEn,         // CSR instruction valid
    output logic                oCsrWrEn,       // CSR write enable
    output logic                oCsrRdEn,       // CSR read enable
    output logic                oCsrImmSel,     // 0 : rs1, 1 : zimm

    // Output Ports: Trap Decode
    output logic                oIsMret,
    output logic                oIsException,
    output exception_cause_e    oExceptionCause
);

    logic [2:0]     Func3;
    logic [6:0]     Func7;
    logic [4:0]     Rd;
    logic [4:0]     Rs;

    logic           wEcall;
    logic           wIllegal;

    assign Func3 = iInstData[14:12];
    assign Func7 = iInstData[31:25];
    assign Rd    = iInstData[11:7];
    assign Rs    = iInstData[19:15];    // rs1 or zimm (same field)

    assign oIsException    = wIllegal || wEcall || oIsMret;
    assign oExceptionCause = wIllegal ? EXC_ILLEGAL_INST : EXC_ECALL_M;

    always_comb
    begin
        oAluCtrl        = ALU_ADD;
        oImmCtrl        = IMM_I; 
        oAluSrc1        = ALU_SRC1_RS1;
        oAluSrc2        = ALU_SRC2_RS2;
        oWBSel          = WB_ALU;
        oPcSel          = PC_NEXT;
        oMemValid       = 1'b0;
        oMemWrEn        = 1'b0;
        oWrEn_Reg       = 1'b0;
        oBranchEn       = 1'b0;
        oBranchCtrl     = BR_EQ;
        oMemByteSel     = WORD;
        // CSR defaults
        oCsrCtrl        = CSR_WRITE;
        oCsrEn          = 1'b0;
        oCsrWrEn        = 1'b0;
        oCsrRdEn        = 1'b0;
        oCsrImmSel      = 1'b0;
        // Trap defaults
        oIsMret         = 1'b0;
        wIllegal        = 1'b1;
        wEcall          = 1'b0;

        case (opcode_e'(iInstData[6:0]))
            OP_OP       :           // R type
            begin
                oWrEn_Reg = 1'b1;
                oAluSrc2  = ALU_SRC2_RS2;  
                oMemWrEn  = 1'b0;  
                case (Func3)
                    3'b000 : 
                    begin
                        oAluCtrl = (Func7 == 7'b010_0000) ? ALU_SUB : ALU_ADD; 
                        wIllegal = !((Func7 == 7'b000_0000) || (Func7 == 7'b010_0000));
                    end
                    3'b001 :
                    begin
                        oAluCtrl = ALU_SLL;
                        wIllegal = (Func7 != 7'b000_0000);
                    end
                    3'b010 :
                    begin
                        oAluCtrl = ALU_SLT;
                        wIllegal = (Func7 != 7'b000_0000);
                    end
                    3'b011 :
                    begin
                        oAluCtrl = ALU_SLTU;
                        wIllegal = (Func7 != 7'b000_0000);
                    end
                    3'b100 :
                    begin
                        oAluCtrl = ALU_XOR;
                        wIllegal = (Func7 != 7'b000_0000);
                    end
                    3'b101 :
                    begin
                        oAluCtrl = (Func7 == 7'b010_0000) ? ALU_SRA : ALU_SRL;
                        wIllegal = !((Func7 == 7'b000_0000) || (Func7 == 7'b010_0000));
                    end
                    3'b110 :
                    begin
                        oAluCtrl = ALU_OR;
                        wIllegal = (Func7 != 7'b000_0000);
                    end
                    3'b111 :
                    begin
                        oAluCtrl = ALU_AND;
                        wIllegal = (Func7 != 7'b000_0000);
                    end
                    default: ;
                endcase
            end

            OP_BRANCH   :           // B type
            begin
                oWrEn_Reg  = 1'b0;
                oAluSrc2   = ALU_SRC2_RS2;
                oWBSel     = WB_ALU;
                oPcSel     = PC_BRANCH;
                oMemWrEn   = 1'b0;
                oImmCtrl   = IMM_B;
                oAluCtrl   = ALU_ADD;
                case (Func3)
                    3'b000, 3'b001, 3'b100, 
                    3'b101, 3'b110, 3'b111 : 
                    begin
                        oBranchEn   = 1'b1;
                        wIllegal    = 1'b0;
                        oBranchCtrl = branch_op_e'(Func3);
                    end
                    default: 
                    begin
                        oBranchEn   = 1'b0;
                        oBranchCtrl = BR_EQ;
                    end
                endcase
            end

            OP_AUIPC    :           // U type - auipc
            begin
                wIllegal   = 1'b0;
                oWrEn_Reg  = 1'b1;
                oAluSrc2   = ALU_SRC2_IMM;
                oWBSel     = WB_ALU;
                oMemWrEn   = 1'b0;
                oImmCtrl   = IMM_U;
                oAluSrc1   = ALU_SRC1_PC;
                oAluCtrl   = ALU_ADD;
            end

            OP_LUI      :           // U type - lui
            begin
                wIllegal   = 1'b0;
                oWrEn_Reg  = 1'b1;
                oAluSrc2   = ALU_SRC2_IMM;
                oWBSel     = WB_ALU;
                oMemWrEn   = 1'b0;
                oImmCtrl   = IMM_U;
                oAluSrc1   = ALU_SRC1_ZERO;
                oAluCtrl   = ALU_ADD;
            end

            OP_JAL      :           // J type - jal
            begin
                wIllegal   = 1'b0;
                oWrEn_Reg  = 1'b1;
                oAluSrc2   = ALU_SRC2_IMM;
                oWBSel     = WB_PC4;
                oPcSel     = PC_JAL;
                oMemWrEn   = 1'b0;
                oImmCtrl   = IMM_J;
                oAluSrc1   = ALU_SRC1_PC;
                oAluCtrl   = ALU_ADD;
            end

            OP_JALR     :           // I type - jalr
            begin
                case (Func3)
                    3'b000 : 
                    begin
                        wIllegal   = 1'b0;
                        oWrEn_Reg  = 1'b1;
                        oAluSrc2   = ALU_SRC2_IMM;
                        oWBSel     = WB_PC4;
                        oPcSel     = PC_JALR;
                        oMemWrEn   = 1'b0;
                        oImmCtrl   = IMM_I;
                        oAluSrc1   = ALU_SRC1_RS1;
                        oAluCtrl   = ALU_ADD;
                    end
                    default: ;
                endcase
            end

            OP_STORE    :           // S type
            begin
                oWrEn_Reg  = 1'b0;  
                oAluSrc2   = ALU_SRC2_IMM;  
                oWBSel     = WB_ALU;
                oMemValid  = 1'b1;
                oMemWrEn   = 1'b1;  
                oImmCtrl   = IMM_S; 
                oAluCtrl   = ALU_ADD; 
                case (Func3)
                    3'b000 :
                    begin
                        oMemByteSel = BYTE;
                        wIllegal    = 1'b0;
                    end
                    3'b001 :
                    begin
                        oMemByteSel = HALF;
                        wIllegal    = 1'b0;
                    end
                    3'b010 :
                    begin
                        oMemByteSel = WORD;
                        wIllegal    = 1'b0;
                    end
                    default: ;
                endcase
            end
            
            OP_LOAD     :           // I type - Load
            begin
                oWrEn_Reg  = 1'b1;  
                oAluSrc2   = ALU_SRC2_IMM;  
                oWBSel     = WB_MEM;
                oMemValid  = 1'b1;
                oMemWrEn   = 1'b0;  
                oImmCtrl   = IMM_I; 
                oAluCtrl   = ALU_ADD;
                case (Func3)
                    3'b000 :
                    begin
                        oMemByteSel = BYTE;
                        wIllegal    = 1'b0;
                    end
                    3'b001 :
                    begin
                        oMemByteSel = HALF;
                        wIllegal    = 1'b0;
                    end
                    3'b010 :
                    begin
                        oMemByteSel = WORD;
                        wIllegal    = 1'b0;
                    end
                    3'b100 :
                    begin
                        oMemByteSel = BYTE_U;
                        wIllegal    = 1'b0;
                    end
                    3'b101 :
                    begin
                        oMemByteSel = HALF_U;
                        wIllegal    = 1'b0;
                    end
                    default: ;
                endcase
            end
            
            OP_IMM      :           // I type - Imm
            begin
                oWrEn_Reg  = 1'b1;  
                oAluSrc2   = ALU_SRC2_IMM;  
                oWBSel     = WB_ALU;
                oMemWrEn   = 1'b0;  
                oImmCtrl   = IMM_I; 
                case (Func3)
                    3'b000 :
                    begin
                        oAluCtrl = ALU_ADD;
                        wIllegal = 1'b0;
                    end
                    3'b001 :
                    begin
                        oAluCtrl = ALU_SLL;
                        wIllegal = (Func7 != 7'b000_0000);
                    end
                    3'b010 :
                    begin
                        oAluCtrl = ALU_SLT;
                        wIllegal = 1'b0;
                    end
                    3'b011 :
                    begin
                        oAluCtrl = ALU_SLTU;
                        wIllegal = 1'b0;
                    end
                    3'b100 :
                    begin
                        oAluCtrl = ALU_XOR;
                        wIllegal = 1'b0;
                    end
                    3'b101 :
                    begin
                        oAluCtrl = (Func7 == 7'b010_0000) ? ALU_SRA : ALU_SRL;
                        wIllegal = !((Func7 == 7'b000_0000) || (Func7 == 7'b010_0000));
                    end
                    3'b110 :
                    begin
                        oAluCtrl = ALU_OR;
                        wIllegal = 1'b0;
                    end
                    3'b111 :
                    begin
                        oAluCtrl = ALU_AND;
                        wIllegal = 1'b0;
                    end
                    default: ;
                endcase
            end

            OP_SYSTEM   :           // CSR & System instructions (ECALL / MRET)
            begin
                oImmCtrl   = IMM_Z;
                oCsrImmSel = Func3[2];
                wIllegal   = 1'b1;
                case (Func3)
                    3'b000 :
                    begin
                        case (iInstData)
                            32'h0000_0073 : // ECALL
                            begin
                                wIllegal = 1'b0;
                                wEcall   = 1'b1;
                            end
                            32'h3020_0073 : // MRET
                            begin
                                oIsMret  = 1'b1;
                                wIllegal = 1'b0;
                            end
                            default: ;
                        endcase
                    end
                    3'b001, 3'b101 :        // CSRRW / CSRRWI
                    begin
                        oCsrCtrl  = CSR_WRITE;
                        oWBSel    = WB_CSR;
                        wIllegal  = 1'b0;
                        oCsrEn    = 1'b1;
                        oCsrWrEn  = 1'b1;
                        oCsrRdEn  = (Rd != 5'b0);
                        oWrEn_Reg = 1'b1;
                    end 
                    3'b010, 3'b110 :        // CSRRS / CSRRSI
                    begin
                        oCsrCtrl  = CSR_SET;
                        oWBSel    = WB_CSR;
                        wIllegal  = 1'b0;
                        oCsrEn    = 1'b1;
                        oCsrWrEn  = (Rs != 5'b0);
                        oCsrRdEn  = 1'b1;
                        oWrEn_Reg = 1'b1;
                    end
                    3'b011, 3'b111 :        // CSRRC / CSRRCI
                    begin
                        oCsrCtrl  = CSR_CLEAR;
                        oWBSel    = WB_CSR;
                        wIllegal  = 1'b0;
                        oCsrEn    = 1'b1;
                        oCsrWrEn  = (Rs != 5'b0);
                        oCsrRdEn  = 1'b1;
                        oWrEn_Reg = 1'b1;
                    end
                    default: ;
                endcase 
            end

            default: ;
        endcase

        // Suppress side effects on exception / trap instruction
        if (wIllegal || wEcall || oIsMret)
        begin
            oWrEn_Reg = 1'b0;
            oMemValid = 1'b0;
            oMemWrEn  = 1'b0;
            oCsrEn    = 1'b0;
            oCsrWrEn  = 1'b0;
            oCsrRdEn  = 1'b0;
            oBranchEn = 1'b0;
            oPcSel    = PC_NEXT;
        end 
    end

endmodule
