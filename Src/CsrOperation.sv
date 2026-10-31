/**************************************************************
 - Project          : CPU_OS
 - File name        : CsrOperation.sv
 - Description      : CSR read-modify-write operation (WB stage)
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.10.30 : Initial release
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module CsrOperation (
    // Input Ports: Control
    input  csr_op_e     iCsrOp,         // WRITE / SET / CLEAR
    input  logic        iCsrImmSel,     // 0 : rs1, 1 : zimm

    // Input Ports: Data
    input  logic [31:0] iCsrData,       // old CSR value
    input  logic [31:0] iRs1Data,       // forwarded rs1
    input  logic [4:0]  iZimm,          // zimm (inst[19:15])

    // Output Ports: Data
    output logic [31:0] oCsrData        // new CSR value
);
    logic [31:0] wSrcData;

    // Source select : rs1 (CSRRx) or zero-extended zimm (CSRRxI)
    assign wSrcData = iCsrImmSel ? {27'b0, iZimm} : iRs1Data;

    // Decode by enum name, independent of encoding
    always_comb 
    begin
        case(iCsrOp)
            CSR_WRITE   : oCsrData = wSrcData;
            CSR_SET     : oCsrData = iCsrData | wSrcData;
            CSR_CLEAR   : oCsrData = iCsrData & ~wSrcData;
            default     : oCsrData = iCsrData;          // keep old value
        endcase
    end

endmodule
