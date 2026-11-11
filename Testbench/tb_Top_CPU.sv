/*******************************************************************
 - Project          : CPU_OS
 - File name        : tb_Top_CPU.sv
 - Description      : Verification Testbench for Trap & Interrupt
                      Step 1: Sync Exceptions (ECALL, Illegal Inst, MRET)
                      Step 2: Async Interrupt & Pipeline Drain
                      Step 3: Corner Cases (Load-Use Stall, Branch in EX, Priority)
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.01 : Initial release
                      2) 2026.11.11 : Add Step 1~3 Trap/Interrupt verification
*******************************************************************/
`timescale 1ns / 1ps

module tb_Top_CPU;

    logic iClk;
    logic iRsn;
    logic wDummyLed;

    // Testbench interrupt stimulus signals
    logic rTb_MEIP;
    logic rTb_MTIP;
    logic rTb_MSIP;

    Top_CPU u_Top_CPU (
        .iClk      (iClk),
        .iRsn      (iRsn),
        .iIrq      (4'b0000),
        .oDummyLed (wDummyLed)
    );

    // 100MHz Clock (10ns period)
    always #5 iClk = ~iClk;

    // Drive Top_CPU internal interrupt wires via hierarchical force
    always_comb begin
        force u_Top_CPU.wMip_MEIP = rTb_MEIP;
        force u_Top_CPU.wMip_MTIP = rTb_MTIP;
        force u_Top_CPU.wMip_MSIP = rTb_MSIP;
    end

    // Hierarchical shortcuts for monitoring
    wire [31:0] wPc          = u_Top_CPU.u_cpu.u_datapath.wPc;
    wire        wTrapDrain   = u_Top_CPU.u_cpu.u_datapath.wTrapDrain;
    wire        wTrapBranch  = u_Top_CPU.u_cpu.u_datapath.wTrapBranch;
    wire [3:0]  wValidBits   = {u_Top_CPU.u_cpu.u_datapath.rIF_ID_Valid,
                                u_Top_CPU.u_cpu.u_datapath.rID_EX_Valid,
                                u_Top_CPU.u_cpu.u_datapath.rEX_MEM_Valid,
                                u_Top_CPU.u_cpu.u_datapath.rMEM_WB_Valid};
    wire        wLoadUseFlag = u_Top_CPU.u_cpu.u_datapath.u_hazardunit.wLoadUseFlag;
    wire        wTakeBranch  = u_Top_CPU.u_cpu.u_datapath.wTakeBranch;
    wire [31:0] wMcause      = u_Top_CPU.u_cpu.u_datapath.u_csrregisterfile.mcause;
    wire [31:0] wMepc        = u_Top_CPU.u_cpu.u_datapath.u_csrregisterfile.mepc;

    // Trace monitor for trap events
    always @(posedge iClk) begin
        if (iRsn && wTrapBranch) begin
            if (u_Top_CPU.u_cpu.u_datapath.rMEM_WB_Mret && u_Top_CPU.u_cpu.u_datapath.rMEM_WB_Valid) begin
                $display("[%0t ns] [MRET ] Return to MEPC = 0x%08h", $time, u_Top_CPU.u_cpu.u_datapath.wTrapAddr);
            end else begin
                $display("[%0t ns] [TRAP ] Jump to MTVEC = 0x%08h | Saved MEPC = 0x%08h | MCAUSE = 0x%08h | Valid = %b",
                         $time,
                         u_Top_CPU.u_cpu.u_datapath.wTrapAddr,
                         u_Top_CPU.u_cpu.u_datapath.wTrapMepc_Wr,
                         u_Top_CPU.u_cpu.u_datapath.wTrapMcause_Wr,
                         wValidBits);
            end
        end
    end

    initial begin
        iClk     = 1'b0;
        iRsn     = 1'b0;
        rTb_MEIP = 1'b0;
        rTb_MTIP = 1'b0;
        rTb_MSIP = 1'b0;

        #20;
        iRsn = 1'b1;
        $display("==================================================================");
        $display(" Starting Trap & Interrupt Verification (Steps 1, 2, 3)");
        $display("==================================================================");

        // ====================================================================
        // STEP 1: Synchronous Exceptions (ECALL & Illegal Instruction)
        // Wait until CPU finishes Step 1 and enters the main loop (0x090)
        // ====================================================================
        wait (wPc == 32'h0000_0090);
        @(posedge iClk);
        if (u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[24] !== 32'd2 ||
            u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[28] !== 32'd0) begin
            $fatal(1, "[STEP 1 FAIL] Sync Exception test failed! x24=%0d (exp 2), x28=%0d (exp 0)",
                   u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[24],
                   u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[28]);
        end
        $display("[%0t ns] [STEP 1 PASS] Sync Exceptions (ECALL & Illegal Inst) verified! (x24=%0d, x28=%0d)",
                 $time,
                 u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[24],
                 u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[28]);

        // ====================================================================
        // STEP 2: Basic Asynchronous Interrupt & Pipeline Drain
        // Inject MTIP when loop counter x11 == 1 and PC is at 0x098
        // ====================================================================
        wait (u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[11] == 32'd1 && wPc == 32'h0000_0098);
        @(negedge iClk);
        $display("[%0t ns] [STEP 2     ] Asserting iMip_MTIP during normal pipeline execution (PC=0x%08h, Valid=%b)",
                 $time, wPc, wValidBits);
        rTb_MTIP = 1'b1;

        // Wait for pipeline drain and trap entry to 0x100
        wait (wPc == 32'h0000_0100);
        if (wMcause !== 32'h8000_0007)
            $fatal(1, "[STEP 2 FAIL] Expected MCAUSE=0x80000007, got 0x%08h", wMcause);

        // Wait until MTI handler body (0x13C) is reached, then clear MTIP
        wait (wPc == 32'h0000_013C);
        @(negedge iClk);
        rTb_MTIP = 1'b0;
        $display("[%0t ns] [STEP 2 PASS] Basic MTIP Drain & Handler entry verified (MEPC=0x%08h)", $time, wMepc);

        // ====================================================================
        // STEP 3-1: Corner Case 1 - Interrupt during Load-Use Hazard Stall
        // Inject MTIP on the exact cycle when wLoadUseFlag == 1 (x11 == 3)
        // ====================================================================
        wait (u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[11] == 32'd3 && wLoadUseFlag == 1'b1);
        @(negedge iClk);
        $display("[%0t ns] [STEP 3-1   ] Asserting iMip_MTIP during Load-Use Stall (wLoadUseFlag=%b, PC=0x%08h)",
                 $time, wLoadUseFlag, wPc);
        rTb_MTIP = 1'b1;

        wait (wPc == 32'h0000_013C);
        @(negedge iClk);
        rTb_MTIP = 1'b0;
        $display("[%0t ns] [STEP 3-1 PASS] Load-Use Stall + Interrupt Drain verified (MEPC=0x%08h)", $time, wMepc);

        // ====================================================================
        // STEP 3-2: Corner Case 2 - Taken Branch in EX during Drain
        // Inject MSIP when beq (0x09C) is in ID so wTakeBranch fires during drain
        // ====================================================================
        wait (u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[11] == 32'd5 &&
              u_Top_CPU.u_cpu.u_datapath.rIF_ID_PC == 32'h0000_009C &&
              u_Top_CPU.u_cpu.u_datapath.rIF_ID_Valid == 1'b1);
        @(negedge iClk);
        $display("[%0t ns] [STEP 3-2   ] Asserting iMip_MSIP right before BEQ enters EX (IF_ID_PC=0x09C)", $time);
        rTb_MSIP = 1'b1;

        // Wait until MSI handler body (0x14C) is reached, verify MEPC was updated to branch target 0x0A4
        wait (wPc == 32'h0000_014C);
        if (wMepc !== 32'h0000_00A4)
            $fatal(1, "[STEP 3-2 FAIL] Expected MEPC=0x000000A4 (branch target), got 0x%08h", wMepc);
        @(negedge iClk);
        rTb_MSIP = 1'b0;
        $display("[%0t ns] [STEP 3-2 PASS] Taken Branch during Drain verified! (MEPC=0x%08h == Branch Target 0x0A4)",
                 $time, wMepc);

        // ====================================================================
        // STEP 3-3: Corner Case 3 - Simultaneous Interrupts (MEIP + MTIP + MSIP)
        // Verify strict priority order: MEI (11) -> MTI (7) -> MSI (3)
        // ====================================================================
        wait (u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[11] == 32'd7 && wPc == 32'h0000_0098);
        @(negedge iClk);
        $display("[%0t ns] [STEP 3-3   ] Asserting MEIP, MTIP, MSIP simultaneously!", $time);
        rTb_MEIP = 1'b1;
        rTb_MTIP = 1'b1;
        rTb_MSIP = 1'b1;

        // 1st serviced must be MEI (mcause = 0x8000_000B, handler at 0x12C)
        wait (wPc == 32'h0000_0100);
        @(posedge iClk);
        if (wMcause !== 32'h8000_000B)
            $fatal(1, "[STEP 3-3 FAIL] 1st interrupt should be MEI (0x8000000B), got 0x%08h", wMcause);
        wait (wPc == 32'h0000_012C);
        @(negedge iClk);
        rTb_MEIP = 1'b0;
        $display("[%0t ns] [STEP 3-3   ] 1st serviced: MEI (mcause=0x%08h) -> cleared MEIP", $time, wMcause);

        // 2nd serviced must be MTI (mcause = 0x8000_0007, handler at 0x13C)
        wait (wPc == 32'h0000_0100);
        @(posedge iClk);
        if (wMcause !== 32'h8000_0007)
            $fatal(1, "[STEP 3-3 FAIL] 2nd interrupt should be MTI (0x80000007), got 0x%08h", wMcause);
        wait (wPc == 32'h0000_013C);
        @(negedge iClk);
        rTb_MTIP = 1'b0;
        $display("[%0t ns] [STEP 3-3   ] 2nd serviced: MTI (mcause=0x%08h) -> cleared MTIP", $time, wMcause);

        // 3rd serviced must be MSI (mcause = 0x8000_0003, handler at 0x14C)
        wait (wPc == 32'h0000_0100);
        @(posedge iClk);
        if (wMcause !== 32'h8000_0003)
            $fatal(1, "[STEP 3-3 FAIL] 3rd interrupt should be MSI (0x80000003), got 0x%08h", wMcause);
        wait (wPc == 32'h0000_014C);
        @(negedge iClk);
        rTb_MSIP = 1'b0;
        $display("[%0t ns] [STEP 3-3 PASS] 3rd serviced: MSI (mcause=0x%08h) -> Priority MEI > MTI > MSI verified!",
                 $time, wMcause);

        // ====================================================================
        // Wait for program completion at DONE loop (0x0D0) and wait 5 clocks
        // for final WB writebacks to complete
        // ====================================================================
        wait (wPc == 32'h0000_00D0);
        repeat (5) @(posedge iClk);

        $display("==================================================================");
        $display(" Final Register Summary:");
        $display("   x10 (Loop Sum)       = %0d (Expected: 100)", u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[10]);
        $display("   x24 (Sync Exc Count) = %0d (Expected: 2)",   u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[24]);
        $display("   x25 (MEI Intr Count) = %0d (Expected: 1)",   u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[25]);
        $display("   x26 (MTI Intr Count) = %0d (Expected: 3)",   u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[26]);
        $display("   x27 (MSI Intr Count) = %0d (Expected: 2)",   u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[27]);
        $display("   x28 (Error Count)    = %0d (Expected: 0)",   u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[28]);
        $display("   x31 (Final Result)   = %0d (Expected: 0)",   u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[31]);
        $display("==================================================================");

        if (u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[31] !== 32'd0 ||
            u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[10] !== 32'd100 ||
            u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[24] !== 32'd2 ||
            u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[25] !== 32'd1 ||
            u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[26] !== 32'd3 ||
            u_Top_CPU.u_cpu.u_datapath.u_registerfile.rMem[27] !== 32'd2) begin
            $fatal(1, "FAIL: Verification check mismatch!");
        end

        $display("ALL TESTS PASSED SUCCESSFULLY!");
        $finish;
    end

    // Watchdog timeout
    initial begin
        #50000;
        $fatal(1, "TIMEOUT: Simulation did not reach DONE (0x0CC) within 50us! Current PC=0x%08h", wPc);
    end

endmodule
