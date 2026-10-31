/*******************************************************************
 - Project          : CPU_OS
 - File name        : tb_Top_CPU.sv
 - Description      : UVM Testbench for tb_sum_cpu
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.01 : Initial release
*******************************************************************/
`timescale 1ns / 1ps


module tb_Top_CPU;

    logic       iClk;
    logic       iRsn;

    Top_CPU u_Top_CPU (
        .iClk (iClk),
        .iRsn (iRsn)
    );

    always #5 iClk = ~iClk;

    //initial begin
    //    $dumpfile("dump.vcd");
    //    $dumpvars(0, tb_sum_cpu);
    //end

    initial begin
        iClk = 0;
        iRsn = 0;   

        #20;
        iRsn = 1;

        #50000;

        if (u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[31] !== 32'd0)
            $fatal(1, "FAIL: x31=%h", u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[31]);

        $display("PASS: x31=0");
        $finish;
    end


endmodule
