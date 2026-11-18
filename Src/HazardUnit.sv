/**************************************************************
 - Project          : CPU_OS
 - File name        : HazardUnit.sv
 - Description      : Pipeline Hazard Detection & Stall/Flush Control
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.10.19 : Initial release
                      2) 2026.10.30 : Add CSR-use stall (WB_CSR, same as load-use)
                      3) 2026.10.31 : Add CSR stall/flush logic(CSR only in pipline)
                      4) 2026.11.11 : Add Trap flush logic
                      5) 2026.11.11 : Add APB Bus wait-state stall (iBusStall)
                      6) 2026.11.16 : Decouple Load-Use from Branch and pre-compute early hazard flags for STA
                      7) 2026.11.18 : [Bug FIX] Move wCsrStallFlag to wEarlyPC_DrainStall so iTakeBranch overrides CSR stall
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

    // APB Bus Wait-State Stall
    input  logic        iBusStall,

    // Trap Controller Ports
    input  logic [3:0]  iTrapFlush,        // Flush mask: [3:0] = {IF_ID, ID_EX, EX_MEM, MEM_WB}
    input  logic        iTrapDrain,        // Pipeline drain request
    input  logic        iTrapBranch,       // Trap jump

    output logic        oIF_ID_Stall,
    output logic        oID_EX_Stall,
    output logic        oEX_MEM_Stall,
    output logic        oMEM_WB_Stall,

    output logic        oIF_ID_Flush,
    output logic        oID_EX_Flush,
    output logic        oEX_MEM_Flush,
    output logic        oMEM_WB_Flush,
    
    output logic        oPC_Stall
);

    logic   wLoadUseFlag;
    logic   wCsrStallFlag;

    // Early hazard terms (independent of late iTakeBranch / wBranchCond)
    (* keep = "true" *) logic wBranchValid;
    (* keep = "true" *) logic wEarlyIF_ID_Flush;
    (* keep = "true" *) logic wEarlyID_EX_Flush;
    (* keep = "true" *) logic wEarlyPC_ForceStall;
    (* keep = "true" *) logic wEarlyPC_DrainStall;

    // Load-use / CSR-use : result is ready only in WB -> stall 1 cycle, then MEM/WB forwarding
    assign wLoadUseFlag = ((iID_EX_WBSel == WB_MEM) || (iID_EX_WBSel == WB_CSR)) && 
                           ((iIF_ID_Rs1 == iID_EX_Rd) || (iIF_ID_Rs2 == iID_EX_Rd));

    assign wCsrStallFlag = ((iID_EX_CsrEn == 1'b1)  ||
                            (iEX_MEM_CsrEn == 1'b1) ||
                            (iMEM_WB_CsrEn == 1'b1)   ) ? 1'b1 : 1'b0;

    // Pre-compute early conditions so late iTakeBranch only traverses 1 LUT stage
    assign wBranchValid        = !iTrapBranch && !iBusStall && (iTrapFlush == 4'b0000) && !wLoadUseFlag;
    assign wEarlyIF_ID_Flush   = iTrapBranch || (!iBusStall && ((iTrapFlush != 4'b0000) ? iTrapFlush[3] : (!wLoadUseFlag && (wCsrStallFlag || iTrapDrain))));
    assign wEarlyID_EX_Flush   = iTrapBranch ? iTrapFlush[2] : (!iBusStall && ((iTrapFlush != 4'b0000) ? iTrapFlush[2] : wLoadUseFlag));
    assign wEarlyPC_ForceStall = !iTrapBranch && (iBusStall || (iTrapFlush != 4'b0000) || wLoadUseFlag);
    assign wEarlyPC_DrainStall = !iTrapBranch && (wCsrStallFlag || iTrapDrain);

    // Priority: TrapBranch > BusStall > TrapFlush > Load-Use > Branch > CSR Stall / Trap Drain
    always_comb
    begin
        // Stall signals (oIF_ID_Stall, oID_EX_Stall, oEX_MEM_Stall, oMEM_WB_Stall are independent of iTakeBranch)
        oIF_ID_Stall  = !iTrapBranch && (iBusStall || ((iTrapFlush == 4'b0000) && wLoadUseFlag));
        oID_EX_Stall  = !iTrapBranch && iBusStall;
        oEX_MEM_Stall = !iTrapBranch && iBusStall;
        oMEM_WB_Stall = !iTrapBranch && iBusStall;

        // EX/MEM and MEM/WB Flush (independent of iTakeBranch)
        if (iTrapBranch == 1'b1)
        begin
            oEX_MEM_Flush = iTrapFlush[1];
            oMEM_WB_Flush = iTrapFlush[0];
        end
        else if (!iBusStall && (iTrapFlush != 4'b0000))
        begin
            oEX_MEM_Flush = iTrapFlush[1];
            oMEM_WB_Flush = iTrapFlush[0];
        end
        else
        begin
            oEX_MEM_Flush = 1'b0;
            oMEM_WB_Flush = 1'b0;
        end

        // Final 1-LUT combination with late iTakeBranch
        oIF_ID_Flush  = wEarlyIF_ID_Flush   || (wBranchValid && iTakeBranch);
        oID_EX_Flush  = wEarlyID_EX_Flush   || (wBranchValid && iTakeBranch);
        oPC_Stall     = wEarlyPC_ForceStall || (wEarlyPC_DrainStall && !iTakeBranch);
    end

endmodule
