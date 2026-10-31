/**************************************************************
 - Project          : CPU_OS
 - File name        : Ctrlpath.sv
 - Description      : 
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.02 : Initial release
                      4) 2026.09.08 : Apply enum for selector
                      6) 2026.09.09 : Complete base opcode
                      7) 2026.10.30 : Add CSR decode (OP_SYSTEM : CSRRW/S/C, CSRRWI/SI/CI)
                      8) 2026.10.31 : Add CSR enum
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
    output byte_sel_e   oMemByteSel,
    // Output Ports: CSR Control
    output csr_op_e     oCsrCtrl,       // CSR operation : WRITE / SET / CLEAR
    output logic        oCsrEn,         // CSR instruction valid
    output logic        oCsrWrEn,       // CSR write enable
    output logic        oCsrRdEn,       // CSR read enable (guard against read side effects)
    output logic        oCsrImmSel      // 0 : rs1, 1 : zimm
);


    logic [2:0]     Func3;
    logic [6:0]     Func7;
    logic [4:0]     Rd;
    logic [4:0]     Rs;
    logic [4:0]     Imm;

    assign Func3 = iInstData[14:12];
    assign Func7 = iInstData[31:25];
    assign Rd    = iInstData[11:7];
    assign Rs    = iInstData[19:15];    // rs1 or zimm (same field)



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
        // CSR defaults (avoid latch for non-SYSTEM opcodes)
        oCsrCtrl    = CSR_WRITE;
        oCsrEn      = 1'b0;
        oCsrWrEn    = 1'b0;
        oCsrRdEn    = 1'b0;
        oCsrImmSel  = 1'b0;
        oWrEn_Reg   = 1'b0;

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

            OP_SYSTEM       :       // CSR instructions (ECALL/EBREAK/MRET : TBD)
            begin
                oImmCtrl   = IMM_Z;         // zimm for CSRRxI (unused for CSRRx)
                oCsrImmSel = Func3[2];      // funct3[2] = 1 : immediate version

                // All CSR instructions write old CSR value to rd in WB (rd = x0 is ignored by RegFile)
                case(Func3)
                    3'b001, 3'b101 :        // CSRRW / CSRRWI : read only if rd != x0
                    begin
                        oCsrCtrl    = CSR_WRITE;
                        oWBSel      = WB_CSR;
                        oCsrEn      = 1'b1;
                        oCsrWrEn    = 1'b1;
                        oCsrRdEn    = (Rd != 5'b0);
                        oWrEn_Reg   = 1'b1;
                    end 
                    3'b010, 3'b110 :        // CSRRS / CSRRSI : write only if rs1/zimm != 0
                    begin
                        oCsrCtrl    = CSR_SET;
                        oWBSel      = WB_CSR;
                        oCsrEn      = 1'b1;
                        oCsrWrEn    = (Rs != 5'b0);
                        oCsrRdEn    = 1'b1;
                        oWrEn_Reg   = 1'b1;
                    end
                    3'b011, 3'b111 :        // CSRRC / CSRRCI : write only if rs1/zimm != 0
                    begin
                        oCsrCtrl    = CSR_CLEAR;
                        oWBSel      = WB_CSR;
                        oCsrEn      = 1'b1;
                        oCsrWrEn    = (Rs != 5'b0);
                        oCsrRdEn    = 1'b1;
                        oWrEn_Reg   = 1'b1;
                    end
                    default : ;             // funct3 = 000 (ECALL/EBREAK/MRET), 100 : not implemented
                endcase
            end
        endcase
    end
endmodule
