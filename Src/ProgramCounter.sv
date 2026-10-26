/**************************************************************
 - Project          : CPU_OS
 - File name        : ProgramCounter.sv
 - Description      : Program Counter with Multi-Cycle Enable
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.02 : Initial release
                      4) 2026.09.08 : Move PC logic from Datapath
                      5) 2026.09.09 : Complete base opcode
                      7) 2026.09.10 : [Bug  FIX] Relocate Branch/Jump logic to EX stage
                      8) 2026.09.10 : Add Stall logic
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module ProgramCounter (
    // Input Ports: Clock and Reset
    input  logic        iClk,
    input  logic        iRsn,
    input  logic        iStall,

    // Input Ports: Control
    input  pc_sel_e     iPcSel,
    input  logic        iBchSel,

    // Input Ports: Data
    input  logic [31:0] iBranchTarget, 
    input  logic [31:0] iJalrAddr,

    // Output Ports: Data
    output logic [31:0] oPc,
    output logic [31:0] oPcPlus4
);

    logic [31:0] rMem_PC;
    logic [31:0] wPcNext;

    assign oPcPlus4 = rMem_PC + 32'd4;

    always_comb
    begin
        wPcNext = oPcPlus4;
        case(iPcSel)
            PC_BRANCH: wPcNext = (iBchSel) ? iBranchTarget : oPcPlus4;
            PC_JAL   : wPcNext = iBranchTarget;
            PC_JALR  : wPcNext = {iJalrAddr[31:1], 1'b0};
            default  : wPcNext = oPcPlus4;
        endcase
    end

    always_ff @(posedge iClk or negedge iRsn)
    begin
        if (!iRsn)
        begin
            rMem_PC <= 32'b0;
        end
        else if (!iStall)
        begin
            rMem_PC <= wPcNext;
        end
    end

    assign oPc = rMem_PC;

endmodule
