/**************************************************************
 - Project          : 20260902_CPU
 - File name        : ImmExtend.sv
 - Description      : 
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.03 : Initial release
                      2) 2026.09.08 : Implement U type
                      3) 2026.09.08 : Implement J type
                      4) 2026.10.30 : Implement Z type (CSR zimm)
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module ImmExtend (
    // Input Ports: Control
    input  imm_type_e   iImmCtrl, 

    // Input Ports: Data
    input  logic [31:0] iInstData,

    // Output Ports: Data
    output logic [31:0] oExtdData
);

    always_comb
    begin
        case(iImmCtrl)
            IMM_I : oExtdData = {{20{iInstData[31]}}, iInstData[31:20]};
            IMM_S : oExtdData = {{20{iInstData[31]}}, iInstData[31:25], iInstData[11:7]};
            IMM_B : oExtdData = {{20{iInstData[31]}}, iInstData[7], iInstData[30:25], iInstData[11:8], 1'b0};
            IMM_U : oExtdData = {iInstData[31:12], 12'b0};
            IMM_J : oExtdData = {{12{iInstData[31]}}, iInstData[19:12], iInstData[20], iInstData[30:21], 1'b0};
            IMM_Z : oExtdData = {27'b0, iInstData[19:15]};     // CSR zimm (zero-extend)
            default : oExtdData = 32'b0;
        endcase
    end

endmodule
