/**************************************************************
 - Project          : 20260902_CPU
 - File name        : Alu.sv
 - Description      : 
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.02 : Initial release
                      2) 2026.09.04 : Apply Enum for ALU Control
                      3) 2026.09.09 : Complete base type
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module Alu (
    // Input Ports: Control
    input  alu_op_e     iAluCtrl, 
    input  logic        iBranchEn,
    input  branch_op_e  iBranchCtrl,

    // Input Ports: Data
    input  logic [31:0] iRs1,
    input  logic [31:0] iRs2,

    // Output Ports: Control
    output logic        oBchSel,

    // Output Ports: Data
    output logic [31:0] oData
);

    always_comb
    begin
        oData = 32'h0000_0000;
        case(iAluCtrl)
            ALU_ADD  : oData = iRs1 + iRs2;
            ALU_SUB  : oData = iRs1 - iRs2;
            ALU_XOR  : oData = iRs1 ^ iRs2;
            ALU_OR   : oData = iRs1 | iRs2;
            ALU_AND  : oData = iRs1 & iRs2;
            ALU_SLL  : oData = iRs1 << iRs2[4:0];
            ALU_SRL  : oData = iRs1 >> iRs2[4:0];
            ALU_SRA  : oData = $signed(iRs1) >>> iRs2[4:0];
            ALU_SLT  : oData = ($signed(iRs1) < $signed(iRs2)) ? 32'd1 : 0; 
            ALU_SLTU : oData = (iRs1 < iRs2) ? 32'd1 : 0;
            default  : oData = 32'h0000_0000;
        endcase
    end

    always_comb
    begin
        oBchSel = 1'b0;
        if(iBranchEn)
        begin
            case(iBranchCtrl)
                BR_EQ  : oBchSel = (iRs1 == iRs2) ? 1'b1 : 1'b0;
                BR_NE  : oBchSel = (iRs1 != iRs2) ? 1'b1 : 1'b0;
                BR_LT  : oBchSel = ($signed(iRs1) <  $signed(iRs2)) ? 1'b1 : 1'b0;
                BR_GE  : oBchSel = ($signed(iRs1) >= $signed(iRs2)) ? 1'b1 : 1'b0;
                BR_LTU : oBchSel = (iRs1 <  iRs2) ? 1'b1 : 1'b0;
                BR_GEU : oBchSel = (iRs1 >= iRs2) ? 1'b1 : 1'b0;
                default: oBchSel = 1'b0;
            endcase
        end
    end

endmodule
