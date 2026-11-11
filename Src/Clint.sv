/**************************************************************
 - Project          : CPU_OS
 - File name        : Clint.sv
 - Description      : Core Local Interruptor (APB slave)
                      - msip     : 0x0000 (machine software interrupt)
                      - mtimecmp : 0x4000 (low) / 0x4004 (high)
                      - mtime    : 0xBFF8 (low) / 0xBFFC (high)
 - Owner            : Hyunjae.Jung
 - Revision history : 1) 2026.11.10 : Initial release
**************************************************************/
`timescale 1ns / 1ps

module Clint (
    // Input Ports: Clock and Reset
    input  logic        iClk,
    input  logic        iRsn,

    // APB Slave Interface
    input  logic [31:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic [ 3:0] PSTRB,
    input  logic        PSEL,
    input  logic        PENABLE,

    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic        PSLVERR,

    // Output Ports: Interrupt
    output logic        oMsip,          // machine software interrupt pending
    output logic        oMtip           // machine timer interrupt pending
);

    // Register address (offset)
    localparam logic [15:0] ADDR_MSIP       = 16'h0000;
    localparam logic [15:0] ADDR_MTIMECMP_L = 16'h4000;
    localparam logic [15:0] ADDR_MTIMECMP_H = 16'h4004;
    localparam logic [15:0] ADDR_MTIME_L    = 16'hBFF8;
    localparam logic [15:0] ADDR_MTIME_H    = 16'hBFFC;

    logic [63:0] rMtime;
    logic [63:0] rMtimecmp;
    logic        rMsip;

    // Interrupt output
    assign oMsip   = rMsip;
    assign oMtip   = (rMtime >= rMtimecmp);

    // APB response : always ready, no error
    assign PREADY  = 1'b1;
    assign PSLVERR = 1'b0;

    // Write : mtime free-running counter + APB write (byte strobe)
    always_ff @(posedge iClk or negedge iRsn)
    begin
        if (!iRsn)
        begin
            rMtime    <= 64'd0;
            rMtimecmp <= 64'hFFFF_FFFF_FFFF_FFFF;   // no timer interrupt after reset
            rMsip     <= 1'b0;
        end
        else
        begin
            rMtime <= rMtime + 64'd1;

            if (PSEL && PENABLE && PWRITE)
            begin
                case (PADDR[15:0])
                    ADDR_MSIP       :
                    begin
                        if (PSTRB[0]) rMsip <= PWDATA[0];
                    end

                    ADDR_MTIMECMP_L :
                    begin
                        if (PSTRB[0]) rMtimecmp[ 7: 0] <= PWDATA[ 7: 0];
                        if (PSTRB[1]) rMtimecmp[15: 8] <= PWDATA[15: 8];
                        if (PSTRB[2]) rMtimecmp[23:16] <= PWDATA[23:16];
                        if (PSTRB[3]) rMtimecmp[31:24] <= PWDATA[31:24];
                    end

                    ADDR_MTIMECMP_H :
                    begin
                        if (PSTRB[0]) rMtimecmp[39:32] <= PWDATA[ 7: 0];
                        if (PSTRB[1]) rMtimecmp[47:40] <= PWDATA[15: 8];
                        if (PSTRB[2]) rMtimecmp[55:48] <= PWDATA[23:16];
                        if (PSTRB[3]) rMtimecmp[63:56] <= PWDATA[31:24];
                    end

                    ADDR_MTIME_L    :
                    begin
                        if (PSTRB[0]) rMtime[ 7: 0] <= PWDATA[ 7: 0];
                        if (PSTRB[1]) rMtime[15: 8] <= PWDATA[15: 8];
                        if (PSTRB[2]) rMtime[23:16] <= PWDATA[23:16];
                        if (PSTRB[3]) rMtime[31:24] <= PWDATA[31:24];
                    end

                    ADDR_MTIME_H    :
                    begin
                        if (PSTRB[0]) rMtime[39:32] <= PWDATA[ 7: 0];
                        if (PSTRB[1]) rMtime[47:40] <= PWDATA[15: 8];
                        if (PSTRB[2]) rMtime[55:48] <= PWDATA[23:16];
                        if (PSTRB[3]) rMtime[63:56] <= PWDATA[31:24];
                    end

                    default         : ;
                endcase
            end
        end
    end

    // Read : combinational
    always_comb
    begin
        PRDATA = 32'd0;
        case (PADDR[15:0])
            ADDR_MSIP       : PRDATA = {31'b0, rMsip};
            ADDR_MTIMECMP_L : PRDATA = rMtimecmp[31: 0];
            ADDR_MTIMECMP_H : PRDATA = rMtimecmp[63:32];
            ADDR_MTIME_L    : PRDATA = rMtime[31: 0];
            ADDR_MTIME_H    : PRDATA = rMtime[63:32];
            default         : ;                     // unmapped : 0
        endcase
    end

endmodule
