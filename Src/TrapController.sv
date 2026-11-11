/**************************************************************
 - Project          : CPU_OS
 - File name        : TrapController.sv
 - Description      : 
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.11.08 : Initial release
                      2) 2026.11.11 : Implement synchronous exception & interrupt drain logic
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module TrapController (
    input  logic iClk,
    input  logic iRsn,
    
    // PC
    input  logic [31:0] iPc,                   // Return PC for interrupt
    // RegisterWall
    input  logic [31:0] iMEM_WB_Pc,            // Return PC for exception

    input  logic        iIF_ID_Valid,          // 1: valid instruction, 0: bubble/flushed
    input  logic        iID_EX_Valid,          
    input  logic        iEX_MEM_Valid,
    input  logic        iMEM_WB_Valid,

    input  logic        iID_EX_Exc,
    input  logic        iEX_MEM_Exc,
    input  logic        iMEM_WB_Exc,

    input  logic        iMEM_WB_Mret,
    input  exception_cause_e iMEM_WB_Cause,
    // CSR Reg
    input  logic [31:0] iMstatus,
    input  logic [31:0] iMip,
    input  logic [31:0] iMie,
    input  logic [31:0] iMtvec,
    input  logic [31:0] iMepc,

    // HazardUnit
    output logic [3:0]  oTrapFlush,            // Flush mask: [3:0] = {IF_ID, ID_EX, EX_MEM, MEM_WB}
    output logic        oTrapDrain,            // Pipeline drain request
    // Csr Reg
    output logic        oCsrWrEn,
    output logic [31:0] oMcause,
    output logic [31:0] oMepc,
    output logic [31:0] oMstatus,
    output logic [31:0] oMtval,
    // PC
    output logic        oTrapBranch,
    output logic [31:0] oTrapAddr
);

    // Exception Handling
    // 1. Detect exception in ID (ecall, mret, illegal inst)
    // 2. Propagate exception flag through pipeline stages
    // 3. Commit trap atomically at WB stage (update CSRs & PC)
    // * Current scope: ID-stage exceptions
    //   Future scope : MEM-stage exceptions (load/store fault)

    // Interrupt Handling
    // 1. Check pending & enable (mstatus.MIE, mie, mip)
    // 2. Request pipeline drain to HazardUnit
    // 3. Wait until pipeline is fully drained (all valid == 0)
    // 4. Enter interrupt trap (save mepc = current PC)

    logic wDrainDone;
    logic wSwIntr;
    logic wTmrIntr;
    logic wExtIntr;

    assign wDrainDone = (iIF_ID_Valid  == 1'b0) && (iID_EX_Valid  == 1'b0) && 
                        (iEX_MEM_Valid == 1'b0) && (iMEM_WB_Valid == 1'b0);

    assign wSwIntr  = ((iMstatus[3] == 1'b1) && (iMie[3]  == 1'b1) && (iMip[3]  == 1'b1));
    assign wTmrIntr = ((iMstatus[3] == 1'b1) && (iMie[7]  == 1'b1) && (iMip[7]  == 1'b1));
    assign wExtIntr = ((iMstatus[3] == 1'b1) && (iMie[11] == 1'b1) && (iMip[11] == 1'b1));

    always_comb
    begin
        // Default outputs (prevent latch inference)
        oTrapFlush   = 4'b0000;
        oTrapDrain   = 1'b0;
        oCsrWrEn     = 1'b0;
        oMcause      = 32'b0;
        oMepc        = 32'b0;
        oMstatus     = iMstatus;
        oMtval       = 32'b0;
        oTrapBranch  = 1'b0;
        oTrapAddr    = 32'b0;

        // ==============================================================
        // 1. Exception (Synchronous Trap): Priority 1st
        // ==============================================================
        if (iMEM_WB_Exc)
        begin
            oTrapFlush = 4'b1111;
            oCsrWrEn   = 1'b1;

            if (iMEM_WB_Mret)
            begin
                // mret: Return from trap
                oTrapBranch   = 1'b1;
                oTrapAddr     = iMepc;
                oMstatus[3]   = iMstatus[7];  // MIE  <= MPIE
                oMstatus[7]   = 1'b1;         // MPIE <= 1
                oMepc         = iMepc;
            end
            else
            begin
                // ecall, illegal instruction, etc.
                oTrapBranch   = 1'b1;
                oTrapAddr     = iMtvec;
                oMepc         = iMEM_WB_Pc;
                oMcause       = {28'b0, iMEM_WB_Cause};
                oMstatus[7]   = iMstatus[3];  // MPIE <= MIE
                oMstatus[3]   = 1'b0;         // MIE  <= 0
            end
        end
        else if (iEX_MEM_Exc)
        begin
            // Flush preceding instructions: IF_ID, ID_EX, EX_MEM
            oTrapFlush = 4'b1110;
        end
        else if (iID_EX_Exc)
        begin
            // Flush preceding instructions: IF_ID, ID_EX
            oTrapFlush = 4'b1100;
        end

        // ==============================================================
        // 2. Interrupt (Asynchronous Trap): Priority External > Timer > SW
        // ==============================================================
        else if (wExtIntr || wTmrIntr || wSwIntr)
        begin
            if (!wDrainDone)
            begin
                // Step 1: Request HazardUnit to drain pipeline
                oTrapDrain = 1'b1;
            end
            else
            begin
                // Step 2: Pipeline drained! Commit interrupt trap
                oTrapBranch   = 1'b1;
                oTrapAddr     = iMtvec;
                oCsrWrEn      = 1'b1;
                oMepc         = iPc;          // Interrupted PC
                oMstatus[7]   = iMstatus[3];  // MPIE <= MIE
                oMstatus[3]   = 1'b0;         // MIE  <= 0
                // Note: IF_ID flush on trap jump is handled by HazardUnit via oTrapBranch

                if (wExtIntr)
                    oMcause = 32'h8000_000B;  // Machine External Interrupt
                else if (wTmrIntr)
                    oMcause = 32'h8000_0007;  // Machine Timer Interrupt
                else if (wSwIntr)
                    oMcause = 32'h8000_0003;  // Machine Software Interrupt
            end
        end
    end

endmodule

