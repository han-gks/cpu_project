/**************************************************************
 - Project          : CPU_OS
 - File name        : HazardUnit.sv
 - Description      : 
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.10.19 : Initial release
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module HazardUnit (
    input  logic [4:0]  iIF_ID_Rs1,        
    input  logic [4:0]  iIF_ID_Rs2,
    input  logic [4:0]  iID_EX_Rd,

    input  logic        iTakeBranch,
    input  logic [1:0]  iID_EX_WBSel,      // check Load @ 2'b01

    output logic        oIF_ID_Stall,
    output logic        oIF_ID_Flush,
    output logic        oID_EX_Flush,
    
    output logic        oPC_Stall
);

    logic   wLoadUseFlag;

    assign wLoadUseFlag = ((iID_EX_WBSel == WB_MEM) && 
                           ((iIF_ID_Rs1 == iID_EX_Rd) || (iIF_ID_Rs2 == iID_EX_Rd)));

    // what about priortiy??
    always_comb
    begin
        oIF_ID_Stall = 1'b0;
        oIF_ID_Flush = 1'b0;
        oID_EX_Flush = 1'b0;
        oPC_Stall    = 1'b0;

        if(iTakeBranch == 1'b1)
        begin
            oIF_ID_Flush = 1'b1;
            oID_EX_Flush = 1'b1;
        end

        else if(wLoadUseFlag == 1'b1)
        begin
            oIF_ID_Stall = 1'b1;
            oID_EX_Flush = 1'b1;
            oPC_Stall    = 1'b1;
        end
    end


endmodule

