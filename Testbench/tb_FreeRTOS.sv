`timescale 1ns / 1ps

module tb_FreeRTOS;

    logic        iClk;
    logic        iRsn;
    logic [7:0]  iGpi;
    logic [7:0]  oGpiCtrl;
    logic [7:0]  oGpo;
    wire  [7:0]  ioGpio;
    logic        iUartRx;
    logic        oUartTx;
    logic        oDummyLed;

    assign iUartRx = 1'b1; // Idle high

    Top_CPU u_dut (
        .iClk        (iClk),
        .iRsn        (iRsn),
        .iBtnIrq     (1'b0),
        .iGpiData    (iGpi),
        .oGpiCtrl    (oGpiCtrl),
        .oGpoLed     (oGpo),
        .ioGpioLedSw (ioGpio),
        .iUartRx     (iUartRx),
        .oUartTx     (oUartTx),
        .oDummyLed   (oDummyLed)
    );

    initial iClk = 1'b0;
    always #5 iClk = ~iClk; // 100 MHz

    // Monitor APB writes to GPO, GPIO, and UART TX
    always @(posedge iClk)
    begin
        if (iRsn && u_dut.wMstPSEL && u_dut.wMstPENABLE && u_dut.wMstPWRITE && u_dut.wMstPREADY)
        begin
            if (u_dut.wMstPADDR == 32'h2001_0004)
                $display("[%0t ns] [GPO LED0~7]  ODR write = 0x%02h", $time, u_dut.wMstPWDATA[7:0]);
            else if (u_dut.wMstPADDR == 32'h2002_0008)
                $display("[%0t ns] [GPIO LED8~15] ODR write = 0x%02h", $time, u_dut.wMstPWDATA[7:0]);
            else if (u_dut.wMstPADDR == 32'h2003_0004)
                $display("[%0t ns] [UART TX FIFO] Push char = '%c' (0x%02h)", $time,
                         (u_dut.wMstPWDATA[7:0] >= 8'h20 && u_dut.wMstPWDATA[7:0] < 8'h7F) ?
                         u_dut.wMstPWDATA[7:0] : 8'h2E, u_dut.wMstPWDATA[7:0]);
            else if (u_dut.wMstPADDR == 32'h0200_4000)
                $display("[%0t ns] [CLINT MTIMECMP_L] = %0d", $time, u_dut.wMstPWDATA);
        end
    end

    // Monitor Trap / MRET events (ecall yield & MTIP timer interrupt)
    always @(posedge iClk)
    begin
        if (iRsn && u_dut.u_cpu.u_datapath.wTrapBranch)
        begin
            if (u_dut.u_cpu.u_datapath.rMEM_WB_Mret && u_dut.u_cpu.u_datapath.rMEM_WB_Valid)
                $display("[%0t ns] [MRET TAKEN] target mepc=0x%08h",
                         $time, u_dut.u_cpu.u_datapath.wTrapAddr);
            else
                $display("[%0t ns] [TRAP TAKEN] mcause=0x%08h mepc=0x%08h -> mtvec=0x%08h",
                         $time,
                         u_dut.u_cpu.u_datapath.wTrapMcause_Wr,
                         u_dut.u_cpu.u_datapath.wTrapMepc_Wr,
                         u_dut.u_cpu.u_datapath.wTrapAddr);
        end
    end

    initial
    begin
        iRsn = 1'b0;
        iGpi = 8'h5A; // Test switch value SW0~SW7 = 0x5A
        repeat (10) @(posedge iClk);
        iRsn = 1'b1;
        $display("=== FreeRTOS Boot & Multitasking Simulation Start ===");

        // Run for 130,000 cycles (1.3 ms) so we see:
        // 1) Boot & main() peripheral init
        // 2) vTaskStartScheduler() -> mret into Task 1
        // 3) Task 1 -> vTaskDelay(1) (ecall yield) -> Task 2 -> vTaskDelay(1) -> Task 3 (SW mirror) -> Idle
        // 4) CLINT Timer Interrupt (MTIP @ 100,000 cycles = 1 ms) -> Preemptive wakeup of Task 1, Task 2, Task 3!
        repeat (130000) @(posedge iClk);

        $display("=== Final Board Outputs: oGpo(LED0~7)=0x%02h, ioGpio(LED8~15)=0x%02h ===", oGpo, ioGpio);
        if (oGpo === 8'h22 && ioGpio === 8'h5A)
            $display("=== FREERTOS SIMULATION PASSED! ===");
        else
            $display("=== FREERTOS SIMULATION FINISHED (Check logs above) ===");
        $finish;
    end

endmodule
