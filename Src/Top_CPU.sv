/**************************************************************
 - Project          : CPU_OS
 - File name        : Top_CPU.sv
 - Description      : Top-Level SoC Integration for FreeRTOS Porting
                      - InstRom (16KB)
                      - Cpu (RV32I + Zicsr + Trap + BusStall)
                      - MemDecoder (0x8000_0000 DataMem Bypass / APB Bus)
                      - DataMem (16KB @ 0x8000_0000 ~ 0x8FFF_FFFF)
                      - Apb_Master & Apb_Interconnect
                      - Clint    (0x0200_0000 ~ 0x0200_FFFF) -> MSIP, MTIP
                      - Plic     (0x0C00_0000 ~ 0x0C3F_FFFF) -> MEIP
                      - GPI      (0x2000_0000 ~ 0x2000_FFFF)
                      - GPO      (0x2001_0000 ~ 0x2001_FFFF)
                      - GPIO     (0x2002_0000 ~ 0x2002_FFFF)
                      - Apb_Uart (0x2003_0000 ~ 0x2003_FFFF)
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.02 : Initial release
                      2) 2026.09.03 : Add DataMem instance
                      3) 2026.11.11 : Integrate MemDecoder, Apb_Master,
                                      Apb_Interconnect, Clint, and Plic
                      4) 2026.11.11 : Integrate GPI, GPO, GPIO, Apb_Uart,
                                      PLIC IRQ wiring, and wBusStall
**************************************************************/
`timescale 1ns / 1ps
import Cpu_h::*;

module Top_CPU (
    // Input Ports: Clock & Reset
    input  logic        iClk,
    input  logic        iRsn,

    // External Button Interrupt Source (PLIC)
    input  logic        iBtnIrq,

    // GPI Outside Interface (0x2000_0000)
    input  logic [ 7:0] iGpiData,
    output logic [ 7:0] oGpiCtrl,

    // GPO Outside Interface (0x2001_0000)
    output logic [ 7:0] oGpoLed,

    // GPIO Outside Interface (0x2002_0000)
    inout  wire  [ 7:0] ioGpioLedSw,

    // UART Outside Interface (0x2003_0000)
    input  logic        iUartRx,
    output logic        oUartTx,

    // Output Ports: For Synthesis Test
    output logic        oDummyLed
);

    // -------------------------------------------------------------------------
    // 1. Instruction ROM Wires
    // -------------------------------------------------------------------------
    logic [31:0] wInstAddr;
    logic [31:0] wInstData;

    // -------------------------------------------------------------------------
    // 2. CPU <-> MemDecoder Wires
    // -------------------------------------------------------------------------
    logic        wCpuMemValid;
    logic        wCpuMemWrEn;
    byte_sel_e   wCpuMemByteSel;
    logic [31:0] wCpuMemAddr;
    logic [31:0] wCpuMemWrData;
    logic [31:0] wCpuMemRdData;
    logic        wBusStall;

    // -------------------------------------------------------------------------
    // 3. Interrupt Pending Wires (CLINT & PLIC -> CPU)
    // -------------------------------------------------------------------------
    logic        wMip_MEIP;
    logic        wMip_MTIP;
    logic        wMip_MSIP;
    logic        wUartIrq;
    logic [ 3:0] wPlicIrq;

    // Map peripheral & external interrupt sources to PLIC inputs:
    //   ID 1 (wPlicIrq[1]) : UART RX FIFO non-empty interrupt
    //   ID 2 (wPlicIrq[2]) : GPI input activity
    //   ID 3 (wPlicIrq[3]) : External Button IRQ (iBtnIrq)
    assign wPlicIrq = {iBtnIrq, (|iGpiData), wUartIrq, iBtnIrq};

    // -------------------------------------------------------------------------
    // 4. MemDecoder <-> DataMem (Bypass @ 0x8000_0000) Wires
    // -------------------------------------------------------------------------
    logic        wDmemWrEn;
    byte_sel_e   wDmemByteSel;
    logic [31:0] wDmemAddr;
    logic [31:0] wDmemWrData;
    logic [31:0] wDmemRdData;

    // -------------------------------------------------------------------------
    // 5. MemDecoder <-> Apb_Master Wires
    // -------------------------------------------------------------------------
    logic        wApbReqValid;
    logic        wApbReqReady;
    logic [31:0] wApbReqAddr;
    logic        wApbReqWrite;
    logic [31:0] wApbReqWrData;
    logic [ 3:0] wApbReqWrStrb;

    logic        wApbRspValid;
    logic [31:0] wApbRspRdData;
    logic        wApbRspError;

    // -------------------------------------------------------------------------
    // 6. Apb_Master <-> Apb_Interconnect Wires
    // -------------------------------------------------------------------------
    logic [31:0] wMstPADDR;
    logic [31:0] wMstPWDATA;
    logic        wMstPWRITE;
    logic [ 3:0] wMstPSTRB;
    logic        wMstPSEL;
    logic        wMstPENABLE;
    logic [31:0] wMstPRDATA;
    logic        wMstPREADY;
    logic        wMstPSLVERR;

    // -------------------------------------------------------------------------
    // 7. Apb_Interconnect <-> APB Slaves Wires
    // -------------------------------------------------------------------------
    logic [31:0] wSlvPADDR;
    logic [31:0] wSlvPWDATA;
    logic        wSlvPWRITE;
    logic [ 3:0] wSlvPSTRB;
    logic        wSlvPENABLE;

    logic        wPSEL_CLINT;
    logic [31:0] wPRDATA_CLINT;
    logic        wPREADY_CLINT;
    logic        wPSLVERR_CLINT;

    logic        wPSEL_PLIC;
    logic [31:0] wPRDATA_PLIC;
    logic        wPREADY_PLIC;
    logic        wPSLVERR_PLIC;

    logic        wPSEL_GPI;
    logic [31:0] wPRDATA_GPI;
    logic        wPREADY_GPI;

    logic        wPSEL_GPO;
    logic [31:0] wPRDATA_GPO;
    logic        wPREADY_GPO;

    logic        wPSEL_GPIO;
    logic [31:0] wPRDATA_GPIO;
    logic        wPREADY_GPIO;

    logic        wPSEL_UART;
    logic [31:0] wPRDATA_UART;
    logic        wPREADY_UART;
    logic        wPSLVERR_UART;

    logic        wPSEL_FND;

    // =========================================================================
    // Module Instantiations
    // =========================================================================

    // 1. Instruction ROM (16KB)
    InstRom u_instrom (
        .iInstAddr   (wInstAddr),
        .oInstData   (wInstData)
    );

    // 2. RISC-V CPU Core
    Cpu u_cpu (
        .iClk        (iClk),
        .iRsn        (iRsn),

        .iMip_MEIP   (wMip_MEIP),
        .iMip_MTIP   (wMip_MTIP),
        .iMip_MSIP   (wMip_MSIP),

        .iBusStall   (wBusStall),

        .iInstData   (wInstData),
        .iMemRdData  (wCpuMemRdData),

        .oInstAddr   (wInstAddr),
        .oMemValid   (wCpuMemValid),
        .oMemWrEn    (wCpuMemWrEn),
        .oMemByteSel (wCpuMemByteSel),
        .oMemAddr    (wCpuMemAddr),
        .oMemWrData  (wCpuMemWrData)
    );

    // 3. Memory Address Decoder (0x8000_0000 Bypass vs. APB Bus)
    MemDecoder u_memdecoder (
        // CPU Side
        .iMemValid   (wCpuMemValid),
        .iMemWrEn    (wCpuMemWrEn),
        .iMemByteSel (wCpuMemByteSel),
        .iMemAddr    (wCpuMemAddr),
        .iMemWrData  (wCpuMemWrData),
        .oMemRdData  (wCpuMemRdData),
        .oBusStall   (wBusStall),

        // DataMem Bypass Side (0x8000_0000)
        .oDmemWrEn    (wDmemWrEn),
        .oDmemByteSel (wDmemByteSel),
        .oDmemAddr    (wDmemAddr),
        .oDmemWrData  (wDmemWrData),
        .iDmemRdData  (wDmemRdData),

        // APB Master Request/Response Side
        .oReqValid   (wApbReqValid),
        .iReqReady   (wApbReqReady),
        .oReqAddr    (wApbReqAddr),
        .oReqWrite   (wApbReqWrite),
        .oReqWrData  (wApbReqWrData),
        .oReqWrStrb  (wApbReqWrStrb),

        .iRspValid   (wApbRspValid),
        .iRspRdData  (wApbRspRdData),
        .iRspError   (wApbRspError)
    );

    // 4. Data Memory (16KB Direct Bypass @ 0x8000_0000)
    DataMem u_datamem (
        .iClk        (iClk),
        .iMemAddr    (wDmemAddr),
        .iMemWrData  (wDmemWrData),
        .iMemWrEn    (wDmemWrEn),
        .iMemByteSel (wDmemByteSel),
        .oMemRdData  (wDmemRdData)
    );

    // 5. APB Master
    Apb_Master u_apb_master (
        .iClk        (iClk),
        .iRsn        (iRsn),

        .iReqValid   (wApbReqValid),
        .oReqReady   (wApbReqReady),
        .iReqAddr    (wApbReqAddr),
        .iReqWrite   (wApbReqWrite),
        .iReqWrData  (wApbReqWrData),
        .iReqWrStrb  (wApbReqWrStrb),

        .oRspValid   (wApbRspValid),
        .oRspRdData  (wApbRspRdData),
        .oRspError   (wApbRspError),

        .PADDR       (wMstPADDR),
        .PWDATA      (wMstPWDATA),
        .PWRITE      (wMstPWRITE),
        .PSTRB       (wMstPSTRB),
        .PSEL        (wMstPSEL),
        .PENABLE     (wMstPENABLE),
        .PRDATA      (wMstPRDATA),
        .PREADY      (wMstPREADY),
        .PSLVERR     (wMstPSLVERR)
    );

    // 6. APB Interconnect
    Apb_Interconnect u_apb_interconnect (
        // Master Side
        .PADDR         (wMstPADDR),
        .PWDATA        (wMstPWDATA),
        .PWRITE        (wMstPWRITE),
        .PSTRB         (wMstPSTRB),
        .PSEL          (wMstPSEL),
        .PENABLE       (wMstPENABLE),
        .PRDATA        (wMstPRDATA),
        .PREADY        (wMstPREADY),
        .PSLVERR       (wMstPSLVERR),

        // Shared Bus to Slaves
        .PADDR_SLV     (wSlvPADDR),
        .PWDATA_SLV    (wSlvPWDATA),
        .PWRITE_SLV    (wSlvPWRITE),
        .PSTRB_SLV     (wSlvPSTRB),
        .PENABLE_SLV   (wSlvPENABLE),

        // Slave Selects
        .PSEL_CLINT    (wPSEL_CLINT),
        .PSEL_PLIC     (wPSEL_PLIC),
        .PSEL_GPI      (wPSEL_GPI),
        .PSEL_GPO      (wPSEL_GPO),
        .PSEL_GPIO     (wPSEL_GPIO),
        .PSEL_UART     (wPSEL_UART),
        .PSEL_FND      (wPSEL_FND),

        // Slave Responses: CLINT & PLIC
        .PRDATA_CLINT  (wPRDATA_CLINT),
        .PREADY_CLINT  (wPREADY_CLINT),
        .PSLVERR_CLINT (wPSLVERR_CLINT),

        .PRDATA_PLIC   (wPRDATA_PLIC),
        .PREADY_PLIC   (wPREADY_PLIC),
        .PSLVERR_PLIC  (wPSLVERR_PLIC),

        // Slave Responses: GPI, GPO, GPIO, UART
        .PRDATA_GPI    (wPRDATA_GPI),
        .PREADY_GPI    (wPREADY_GPI),
        .PSLVERR_GPI   (1'b0),

        .PRDATA_GPO    (wPRDATA_GPO),
        .PREADY_GPO    (wPREADY_GPO),
        .PSLVERR_GPO   (1'b0),

        .PRDATA_GPIO   (wPRDATA_GPIO),
        .PREADY_GPIO   (wPREADY_GPIO),
        .PSLVERR_GPIO  (1'b0),

        .PRDATA_UART   (wPRDATA_UART),
        .PREADY_UART   (wPREADY_UART),
        .PSLVERR_UART  (wPSLVERR_UART),

        // Slave Response: FND (Default Tie-off)
        .PRDATA_FND    (32'b0),
        .PREADY_FND    (1'b1),
        .PSLVERR_FND   (1'b0)
    );

    // 7. CLINT (Core Local Interruptor @ 0x0200_0000)
    Clint u_clint (
        .iClk          (iClk),
        .iRsn          (iRsn),

        .PADDR         (wSlvPADDR),
        .PWDATA        (wSlvPWDATA),
        .PWRITE        (wSlvPWRITE),
        .PSTRB         (wSlvPSTRB),
        .PSEL          (wPSEL_CLINT),
        .PENABLE       (wSlvPENABLE),

        .PRDATA        (wPRDATA_CLINT),
        .PREADY        (wPREADY_CLINT),
        .PSLVERR       (wPSLVERR_CLINT),

        .oMsip         (wMip_MSIP),
        .oMtip         (wMip_MTIP)
    );

    // 8. PLIC (Platform-Level Interrupt Controller @ 0x0C00_0000)
    Plic u_plic (
        .iClk          (iClk),
        .iRsn          (iRsn),

        .PADDR         (wSlvPADDR),
        .PWDATA        (wSlvPWDATA),
        .PWRITE        (wSlvPWRITE),
        .PSTRB         (wSlvPSTRB),
        .PSEL          (wPSEL_PLIC),
        .PENABLE       (wSlvPENABLE),

        .PRDATA        (wPRDATA_PLIC),
        .PREADY        (wPREADY_PLIC),
        .PSLVERR       (wPSLVERR_PLIC),

        .iIrq          (wPlicIrq),
        .oMeip         (wMip_MEIP)
    );

    // 9. GPI (General Purpose Input @ 0x2000_0000)
    GPI u_gpi (
        .iClk          (iClk),
        .iRsn          (iRsn),

        .PADDR         (wSlvPADDR),
        .PWDATA        (wSlvPWDATA),
        .PWRITE        (wSlvPWRITE),
        .PENABLE       (wSlvPENABLE),
        .PSEL          (wPSEL_GPI),
        .PREADY        (wPREADY_GPI),
        .PRDATA        (wPRDATA_GPI),

        .iData         (iGpiData),
        .oCtrl         (oGpiCtrl)
    );

    // 10. GPO (General Purpose Output @ 0x2001_0000)
    GPO u_gpo (
        .iClk          (iClk),
        .iRsn          (iRsn),

        .PADDR         (wSlvPADDR),
        .PWDATA        (wSlvPWDATA),
        .PWRITE        (wSlvPWRITE),
        .PENABLE       (wSlvPENABLE),
        .PSEL          (wPSEL_GPO),
        .PREADY        (wPREADY_GPO),
        .PRDATA        (wPRDATA_GPO),

        .oLed          (oGpoLed)
    );

    // 11. GPIO (General Purpose I/O @ 0x2002_0000)
    GPIO u_gpio (
        .iClk          (iClk),
        .iRsn          (iRsn),

        .PADDR         (wSlvPADDR),
        .PWDATA        (wSlvPWDATA),
        .PWRITE        (wSlvPWRITE),
        .PENABLE       (wSlvPENABLE),
        .PSEL          (wPSEL_GPIO),
        .PREADY        (wPREADY_GPIO),
        .PRDATA        (wPRDATA_GPIO),

        .ioLedSw       (ioGpioLedSw)
    );

    // 12. APB UART with TX/RX FIFO (@ 0x2003_0000)
    Apb_Uart u_uart (
        .iClk          (iClk),
        .iRsn          (iRsn),

        .PADDR         (wSlvPADDR),
        .PWDATA        (wSlvPWDATA),
        .PWRITE        (wSlvPWRITE),
        .PENABLE       (wSlvPENABLE),
        .PSEL          (wPSEL_UART),
        .PREADY        (wPREADY_UART),
        .PRDATA        (wPRDATA_UART),
        .PSLVERR       (wPSLVERR_UART),

        .iRx           (iUartRx),
        .oTx           (oUartTx),
        .oIrq          (wUartIrq)
    );

    // Dummy Output for Synthesis Preservation
    assign oDummyLed = ^wCpuMemWrData ^ ^wCpuMemAddr ^ wCpuMemValid ^ wCpuMemWrEn ^
                       ^wInstAddr ^ ^wCpuMemRdData ^ wApbRspValid ^ wApbRspError ^ wPSEL_FND;

endmodule
