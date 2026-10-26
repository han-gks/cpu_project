/**************************************************************
 - Project          : CPU_OS
 - File name        : RegisterFile.sv
 - Description      : 
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.02 : Initial release
                      2) 2026.10.18 : Add Bypass logic for 3 cycle RAW
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module RegisterFile (
    // Input Ports: Clock and Control
    input  logic        iClk,
    input  logic        iWrEn_Reg,

    // Input Ports: Data
    input  logic [ 4:0] iRdAddr1,
    input  logic [ 4:0] iRdAddr2,
    input  logic [ 4:0] iWrAddr,
    input  logic [31:0] iWrData,

    // Output Ports: Data
    output logic [31:0] oRdData1,
    output logic [31:0] oRdData2
);

    logic [31:0] rMem [31:0];

    // for test
    //int i;
    //initial
    //begin
    //    for(i=0; i<8; i=i+1)
    //        rMem[i] = i;
    //end
    

    always_ff@(posedge iClk)
    begin
        if((iWrEn_Reg) && (iWrAddr != 5'b0))
            rMem[iWrAddr] <= iWrData;
    end

    always_comb
    begin
        // Rs1
        if(iRdAddr1 == 5'b0)
            oRdData1 = 32'b0;
        else if((iRdAddr1 == iWrAddr) && (iWrEn_Reg == 1'b1))
            oRdData1 = iWrData;
        else
            oRdData1 = rMem[iRdAddr1];
        // Rs2
        if(iRdAddr2 == 5'b0)
            oRdData2 = 32'b0;
        else if((iRdAddr2 == iWrAddr) && (iWrEn_Reg == 1'b1))
            oRdData2 = iWrData;
        else
            oRdData2 = rMem[iRdAddr2];
    end


endmodule
