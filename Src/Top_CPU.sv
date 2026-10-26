/**************************************************************
 - Project          : CPU_OS
 - File name        : Top_CPU.sv
 - Description      : 
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.02 : Initial release
                      2) 2026.09.03 : Add DataMem instance
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module Top_CPU (
    // Input Ports
    input  logic iClk,
    input  logic iRsn,

    // for test
    output logic oDummyLed
);

    logic [31:0]    wInstAddr;
    logic [31:0]    wInstData;
    
    logic [31:0]    wMemAddr;
    logic [31:0]    wMemWrData;
    logic [31:0]    wMemRdData;
    logic           wMemWrEn;
    byte_sel_e      wMemByteSel;

    InstRom u_instrom (
        .iInstAddr  (wInstAddr),
        .oInstData  (wInstData)
    );

    Cpu u_cpu (
        .iClk       (iClk),
        .iRsn       (iRsn),
        .iInstData  (wInstData),
        .iMemRdData (wMemRdData),

        .oInstAddr  (wInstAddr),
        .oMemWrData (wMemWrData),      
        .oMemAddr   (wMemAddr),      
        
        .oMemWrEn   (wMemWrEn),
        .oMemByteSel(wMemByteSel)
    );

    DataMem u_datamem (
        .iClk       (iClk),
        .iMemAddr   (wMemAddr),
        .iMemWrData (wMemWrData),
        .iMemWrEn   (wMemWrEn),
        .iMemByteSel(wMemByteSel),
        .oMemRdData (wMemRdData)
    );


    // for test
    assign oDummyLed = ^wMemWrData ^ ^wMemAddr ^ wMemWrEn;
    //
endmodule
