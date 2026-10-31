`timescale 1ns / 1ps
import Cpu_h::*;

module tb_SpikeCompare;
    logic iClk;
    logic iRsn;
    logic [31:0] iInstData;
    logic [31:0] oInstAddr;
    logic [31:0] oMemWrData;
    logic [31:0] oMemAddr;
    logic oMemValid;
    logic oMemWrEn;
    byte_sel_e oMemByteSel;
    logic [31:0] rom [0:31];

    initial $readmemh("../SpikeCompare/compare.hex", rom);
    assign iInstData = rom[oInstAddr[6:2]];

    Cpu u_cpu (
        .iClk(iClk), .iRsn(iRsn),
        .iInstData(iInstData), .iMemRdData(32'b0),
        .oInstAddr(oInstAddr), .oMemWrData(oMemWrData), .oMemAddr(oMemAddr),
        .oMemValid(oMemValid), .oMemWrEn(oMemWrEn), .oMemByteSel(oMemByteSel)
    );

    always #5 iClk = ~iClk;

    initial begin
        iClk = 0;
        iRsn = 0;
        #20 iRsn = 1;
        #2000;

        if (u_cpu.u_datapath.u_registerfile.rMem[31] !== 32'd0 ||
            u_cpu.u_datapath.u_registerfile.rMem[2]  !== 32'd0 ||
            u_cpu.u_datapath.u_registerfile.rMem[3]  !== 32'd5 ||
            u_cpu.u_datapath.u_registerfile.rMem[5]  !== 32'd5 ||
            u_cpu.u_datapath.u_registerfile.rMem[6]  !== 32'd7 ||
            u_cpu.u_datapath.u_registerfile.rMem[7]  !== 32'd5 ||
            u_cpu.u_datapath.u_registerfile.rMem[8]  !== 32'd13 ||
            u_cpu.u_datapath.U_csrregisterfile.mscratch !== 32'd13)
            $fatal(1, "RTL FAIL: x31=%h x2=%h x3=%h x5=%h x6=%h x7=%h x8=%h mscratch=%h",
                u_cpu.u_datapath.u_registerfile.rMem[31],
                u_cpu.u_datapath.u_registerfile.rMem[2],
                u_cpu.u_datapath.u_registerfile.rMem[3],
                u_cpu.u_datapath.u_registerfile.rMem[5],
                u_cpu.u_datapath.u_registerfile.rMem[6],
                u_cpu.u_datapath.u_registerfile.rMem[7],
                u_cpu.u_datapath.u_registerfile.rMem[8],
                u_cpu.u_datapath.U_csrregisterfile.mscratch);

        $display("RTL PASS: x31=0, mscratch=13 (matches Spike)");
        $finish;
    end
endmodule
