/**************************************************************
 - Project          : CPU_OS
 - File name        : Forwarding.sv
 - Description      : 
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.10.18 : Initial release
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module Forwarding (
    input  logic        iEX_MEM_WbEn,
    input  logic        iMEM_WB_WbEn,

    input  logic [4:0]  iID_EX_Rs1,        // data cousumer rs1
    input  logic [4:0]  iID_EX_Rs2,        // data cousumer rs2
    input  logic [4:0]  iEX_MEM_Rd,        // data producer 1cycle
    input  logic [4:0]  iMEM_WB_Rd,        // data producer 2cycle

    output logic        oFwdRs1_En,        // 0 : RegFile 1 : Forwarding
    output logic        oFwdRs1_Sel,       // 0 : EX_MEM  1 : MEM_WB
    output logic        oFwdRs2_En,        // 0 : RegFile 1 : Forwarding
    output logic        oFwdRs2_Sel        // 0 : EX_MEM  1 : MEM_WB
);

    // rs1
    always_comb
    begin
        oFwdRs1_En  = 1'b0;
        oFwdRs1_Sel = 1'b0;
        if((iID_EX_Rs1 == iEX_MEM_Rd) && (iEX_MEM_WbEn == 1'b1) && (iEX_MEM_Rd != 5'b0))
        begin
            oFwdRs1_En  = 1'b1;
            oFwdRs1_Sel = 1'b0;
        end
        else if((iID_EX_Rs1 == iMEM_WB_Rd) && (iMEM_WB_WbEn == 1'b1) && (iMEM_WB_Rd != 5'b0))
        begin
            oFwdRs1_En  = 1'b1;
            oFwdRs1_Sel = 1'b1;
        end
    end 

    // rs2
    always_comb
    begin
        oFwdRs2_En  = 1'b0;
        oFwdRs2_Sel = 1'b0;
        if((iID_EX_Rs2 == iEX_MEM_Rd) && (iEX_MEM_WbEn == 1'b1) && (iEX_MEM_Rd != 5'b0))
        begin
            oFwdRs2_En  = 1'b1;
            oFwdRs2_Sel = 1'b0;
        end
        else if((iID_EX_Rs2 == iMEM_WB_Rd) && (iMEM_WB_WbEn == 1'b1) && (iMEM_WB_Rd != 5'b0))
        begin
            oFwdRs2_En  = 1'b1;
            oFwdRs2_Sel = 1'b1;
        end
    end 

endmodule

