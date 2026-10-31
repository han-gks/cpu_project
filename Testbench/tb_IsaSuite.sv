`timescale 1ns / 1ps
import Cpu_h::*;

module tb_IsaSuite;
    logic iClk;
    logic iRsn;
    logic [31:0] inst_addr, inst_data;
    logic [31:0] mem_addr, mem_wr_data, mem_rd_data;
    logic mem_valid, mem_wr_en;
    byte_sel_e mem_byte_sel;
    logic [31:0] expected_regs [0:31];

    initial $readmemh("../IsaSuite/expected_regs.hex", expected_regs);

    InstRom #(
        .ROM_FILE("../IsaSuite/rom.hex")
    ) u_rom (
        .iInstAddr(inst_addr), .oInstData(inst_data)
    );

    Cpu u_cpu (
        .iClk(iClk), .iRsn(iRsn),
        .iInstData(inst_data), .iMemRdData(mem_rd_data),
        .oInstAddr(inst_addr), .oMemWrData(mem_wr_data), .oMemAddr(mem_addr),
        .oMemValid(mem_valid), .oMemWrEn(mem_wr_en), .oMemByteSel(mem_byte_sel)
    );

    DataMem u_data (
        .iClk(iClk), .iMemAddr(mem_addr), .iMemWrData(mem_wr_data),
        .iMemWrEn(mem_wr_en), .iMemByteSel(mem_byte_sel), .oMemRdData(mem_rd_data)
    );

    always #5 iClk = ~iClk;

    always @(posedge iClk) begin
        if (iRsn && mem_valid === 1'b1 && mem_addr[31:9] !== 23'h40)
            $fatal(1, "RTL FAIL: data access outside 0x8000-0x81ff: %h", mem_addr);
    end

    initial begin
        iClk = 0;
        iRsn = 0;
        #20 iRsn = 1;
        #20000;

        if (u_cpu.u_datapath.u_registerfile.rMem[28] !== 32'h0000_05a5)
            $fatal(1, "RTL FAIL: suite did not finish; x28=%h, pc=%h",
                u_cpu.u_datapath.u_registerfile.rMem[28], inst_addr);
        if (u_cpu.u_datapath.u_registerfile.rMem[31] !== 32'd0)
            $fatal(1, "RTL FAIL: check %0d", u_cpu.u_datapath.u_registerfile.rMem[31]);

        for (int index = 1; index < 32; index++) begin
            if (u_cpu.u_datapath.u_registerfile.rMem[index] !== expected_regs[index])
                $fatal(1, "RTL FAIL: x%0d=%h, Spike=%h", index,
                    u_cpu.u_datapath.u_registerfile.rMem[index], expected_regs[index]);
        end
        if (u_cpu.u_datapath.U_csrregisterfile.mscratch !== 32'd13)
            $fatal(1, "RTL FAIL: mscratch=%h", u_cpu.u_datapath.U_csrregisterfile.mscratch);
        if (u_data.rMem[0] !== 32'h7f01_abcd || u_data.rMem[1] !== 32'h7f01_abcd)
            $fatal(1, "RTL FAIL: data words 0=%h 1=%h", u_data.rMem[0], u_data.rMem[1]);

        $display("RTL PASS: ISA suite complete; 31 registers match Spike");
        $finish;
    end
endmodule
