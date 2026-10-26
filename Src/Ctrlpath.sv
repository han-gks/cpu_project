/**************************************************************
 - Project          : CPU_OS
 - File name        : Ctrlpath.sv
 - Description      : 
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.02 : Initial release
                      4) 2026.09.08 : Apply enum for selector
                      6) 2026.09.09 : Complete base opcode
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;  

module Ctrlpath (
    // Input Ports: Data
    input  logic [31:0] iInstData,

    // Output Ports: Control
    output alu_op_e     oAluCtrl,
    output imm_type_e   oImmCtrl,
    output alu_src1_e   oAluSrc1,
    output alu_src2_e   oAluSrc2,
    output wb_sel_e     oWBSel,
    output pc_sel_e     oPcSel,
    output logic        oMemValid,
    output logic        oMemWrEn,
    output logic        oWrEn_Reg,
    output logic        oBranchEn,
    output branch_op_e  oBranchCtrl,
    output byte_sel_e   oMemByteSel
);


    logic [2:0] Func3;
    logic [6:0] Func7;

    assign Func3 = iInstData[14:12];
    assign Func7 = iInstData[31:25];

    always_comb
    begin
        oAluCtrl   = ALU_ADD;
        oImmCtrl   = IMM_I; 
        oAluSrc1   = ALU_SRC1_RS1;
        oAluSrc2   = ALU_SRC2_RS2;
        oWBSel     = WB_ALU;
        oPcSel     = PC_NEXT;
        oMemValid  = 1'b0;
        oMemWrEn   = 1'b0;
        oWrEn_Reg  = 1'b0;
        oBranchEn   = 1'b0;
        oBranchCtrl = BR_EQ;
        oMemByteSel = WORD; 

        case(opcode_e'(iInstData[6:0]))
            OP_OP       :           // R type
            begin
                oWrEn_Reg = 1'b1;  
                oAluSrc2  = ALU_SRC2_RS2;  
                oMemWrEn = 1'b0;  
                case(Func3)
                    3'b000 : 
                    begin
                        oAluCtrl  = (Func7 == 7'b010_0000) ? ALU_SUB : ALU_ADD; 
                        oWrEn_Reg = ((Func7 == 7'b000_0000) || (Func7 == 7'b010_0000)) ? 1'b1 : 1'b0;
                    end
                    3'b001 : 
                    begin
                        oAluCtrl  = ALU_SLL;
                        oWrEn_Reg = (Func7 == 7'b000_0000) ? 1'b1 : 1'b0;
                    end
                    3'b010 : 
                    begin
                        oAluCtrl  = ALU_SLT;
                        oWrEn_Reg = (Func7 == 7'b000_0000) ? 1'b1 : 1'b0;
                    end
                    3'b011 : 
                    begin
                        oAluCtrl  = ALU_SLTU;
                        oWrEn_Reg = (Func7 == 7'b000_0000) ? 1'b1 : 1'b0;
                    end
                    3'b100 : 
                    begin
                        oAluCtrl  = ALU_XOR;
                        oWrEn_Reg = (Func7 == 7'b000_0000) ? 1'b1 : 1'b0;
                    end
                    3'b101 : 
                    begin
                        oAluCtrl  = (Func7 == 7'b010_0000) ? ALU_SRA : ALU_SRL;
                        oWrEn_Reg = ((Func7 == 7'b000_0000) || (Func7 == 7'b010_0000)) ? 1'b1 : 1'b0;
                    end
                    3'b110 : 
                    begin
                        oAluCtrl  = ALU_OR;
                        oWrEn_Reg = (Func7 == 7'b000_0000) ? 1'b1 : 1'b0;
                    end
                    3'b111 : 
                    begin
                        oAluCtrl  = ALU_AND;
                        oWrEn_Reg = (Func7 == 7'b000_0000) ? 1'b1 : 1'b0;
                    end
                endcase
            end

            OP_BRANCH   :           // B type
            begin
                oWrEn_Reg  = 1'b0;
                oAluSrc2   = ALU_SRC2_RS2;
                oWBSel     = WB_ALU;
                oPcSel     = PC_BRANCH;
                oMemWrEn  = 1'b0;
                oImmCtrl   = IMM_B;
                oAluCtrl   = ALU_ADD;
                case(Func3)
                    3'b000, 3'b001, 3'b100, 
                    3'b101, 3'b110, 3'b111 : 
                    begin
                        oBranchEn   = 1'b1;
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
                case(Func3)
                    3'b000 : 
                    begin
                        oWrEn_Reg  = 1'b1;
                        oAluSrc2   = ALU_SRC2_IMM;
                        oWBSel     = WB_PC4;
                        oPcSel     = PC_JALR;
                        oMemWrEn   = 1'b0;
                        oImmCtrl   = IMM_I;
                        oAluSrc1   = ALU_SRC1_RS1;
                        oAluCtrl   = ALU_ADD;
                    end
                    default: 
                    begin
                    end
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
                case(Func3)
                    3'b000 : oMemByteSel = BYTE; 
                    3'b001 : oMemByteSel = HALF; 
                    3'b010 : oMemByteSel = WORD; 
                    default: oMemByteSel = WORD;
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
                case(Func3)
                    3'b000 : 
                    begin
                        oMemByteSel = BYTE;
                    end
                    3'b001 :  
                    begin
                        oMemByteSel = HALF;
                    end
                    3'b010 : 
                    begin
                        oMemByteSel = WORD;
                    end
                    3'b100 : 
                    begin
                        oMemByteSel = BYTE_U;
                    end
                    3'b101 : 
                    begin
                        oMemByteSel = HALF_U;
                    end
                    default: 
                    begin
                        oMemByteSel  = WORD;
                        oWrEn_Reg = 1'b0;
                    end
                endcase
            end
            
            OP_IMM      :           // I type - Imm
            begin
                oWrEn_Reg  = 1'b1;  
                oAluSrc2   = ALU_SRC2_IMM;  
                oWBSel     = WB_ALU;
                oMemWrEn   = 1'b0;  
                oImmCtrl   = IMM_I; 
                case(Func3)
                    3'b000 : oAluCtrl = ALU_ADD; 
                    3'b001 : 
                    begin
                        oAluCtrl  = ALU_SLL;
                        oWrEn_Reg = (Func7 == 7'b000_0000) ? 1'b1 : 1'b0;
                    end
                    3'b010 : oAluCtrl = ALU_SLT;
                    3'b011 : oAluCtrl = ALU_SLTU;
                    3'b100 : oAluCtrl = ALU_XOR;
                    3'b101 : 
                    begin
                        oAluCtrl  = (Func7 == 7'b010_0000) ? ALU_SRA : ALU_SRL;
                        oWrEn_Reg = ((Func7 == 7'b000_0000) || (Func7 == 7'b010_0000)) ? 1'b1 : 1'b0;
                    end
                    3'b110 : oAluCtrl = ALU_OR;
                    3'b111 : oAluCtrl = ALU_AND;
                endcase
            end
            
            default : 
            begin
            end

        endcase
    end

endmodule
