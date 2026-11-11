/**************************************************************
 - Project          : CPU_OS
 - File name        : HazardUnit.sv
 - Description      : 
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.10.19 : Initial release
                      2) 2026.10.30 : Add CSR-use stall (WB_CSR, same as load-use)
                      3) 2026.10.31 : Add CSR stall/flush logic(CSR only in pipline)
                      4) 2026.11.11 : Add Trap flush logic
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module HazardUnit (
    input  logic [4:0]  iIF_ID_Rs1,        
    input  logic [4:0]  iIF_ID_Rs2,
    input  logic [4:0]  iID_EX_Rd,

    input  logic        iID_EX_CsrEn,
    input  logic        iEX_MEM_CsrEn,
    input  logic        iMEM_WB_CsrEn,

    input  logic        iTakeBranch,
    input  logic [1:0]  iID_EX_WBSel,      // check Load (WB_MEM) / CSR (WB_CSR)

    // Trap Controller Ports
    input  logic [3:0]  iTrapFlush,        // Flush mask: [3:0] = {IF_ID, ID_EX, EX_MEM, MEM_WB}
    input  logic        iTrapDrain,        // Pipeline drain request
    input  logic        iTrapBranch,       // Trap jump

    output logic        oIF_ID_Stall,
    output logic        oIF_ID_Flush,
    output logic        oID_EX_Flush,
    output logic        oEX_MEM_Flush,
    output logic        oMEM_WB_Flush,
    
    output logic        oPC_Stall
);

    logic   wLoadUseFlag;
    logic   wCsrStallFlag;

    // Load-use / CSR-use : result is ready only in WB -> stall 1 cycle, then MEM/WB forwarding
    assign wLoadUseFlag = ((iID_EX_WBSel == WB_MEM) || (iID_EX_WBSel == WB_CSR)) && 
                           ((iIF_ID_Rs1 == iID_EX_Rd) || (iIF_ID_Rs2 == iID_EX_Rd));

    assign wCsrStallFlag = ((iID_EX_CsrEn == 1'b1)  ||
                            (iEX_MEM_CsrEn == 1'b1) ||
                            (iMEM_WB_CsrEn == 1'b1)   ) ? 1'b1 : 1'b0;

    // Priority: TrapBranch > TrapFlush > Branch > Load-Use > CSR Stall / Trap Drain
    always_comb
    begin
        oIF_ID_Stall  = 1'b0;
        oIF_ID_Flush  = 1'b0;
        oID_EX_Flush  = 1'b0;
        oEX_MEM_Flush = 1'b0;
        oMEM_WB_Flush = 1'b0;
        oPC_Stall     = 1'b0;

        if (iTrapBranch == 1'b1)
        begin
            oIF_ID_Flush  = 1'b1;
            oID_EX_Flush  = iTrapFlush[2];
            oEX_MEM_Flush = iTrapFlush[1];
            oMEM_WB_Flush = iTrapFlush[0];
        end
        else if (iTrapFlush != 4'b0000)
        begin
            oIF_ID_Flush  = iTrapFlush[3];
            oID_EX_Flush  = iTrapFlush[2];
            oEX_MEM_Flush = iTrapFlush[1];
            oMEM_WB_Flush = iTrapFlush[0];
            oPC_Stall     = 1'b1;
        end
        else if (iTakeBranch == 1'b1)
        begin
            oIF_ID_Flush = 1'b1;
            oID_EX_Flush = 1'b1;
        end
        else if (wLoadUseFlag == 1'b1)
        begin
            oIF_ID_Stall = 1'b1;
            oID_EX_Flush = 1'b1;
            oPC_Stall    = 1'b1;
        end
        else if ((wCsrStallFlag == 1'b1) || (iTrapDrain == 1'b1))
        begin
            oPC_Stall    = 1'b1;
            oIF_ID_Flush = 1'b1;
        end
    end


endmodule

