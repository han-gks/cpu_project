/**************************************************************
 - Project          : CPU_OS
 - File name        : GPI.sv
 - Description      : General Purpose Input (APB Slave @ 0x2000_0000)
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.14 : Initial release
                      2) 2026.11.11 : Ported to CPU_OS
**************************************************************/
`timescale 1ns / 1ps

module GPI (
    input  logic        iClk,
    input  logic        iRsn,
    
    // APB interface
    input  logic [31:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic        PSEL,
    output logic        PREADY,
    output logic [31:0] PRDATA,

    // Outside interface
    input  logic [ 7:0] iData,
    output logic [ 7:0] oCtrl
);

  // Register map, as used by test.c:
  //   0x0 CTR - input/control setting, read/write
  //   0x4 IDR - input data register, read-only
  logic [7:0] rCTR;
  logic [7:0] rIDR;

  // This peripheral has no wait states.  PREADY is asserted solely for a
  // valid APB access phase, matching the other APB slave in this design.
  assign PREADY = PSEL && PENABLE;
  // GPI does not drive iData. oCtrl is an external per-bit input-enable
  // indication; a disabled channel is disconnected.
  always_comb 
  begin
    for (int i = 0; i < 8; i++) 
    begin
      if (rCTR[i])
        oCtrl[i] = 1'b1;
      else
        oCtrl[i] = 1'bz;
    end
  end

  always_ff @(posedge iClk) 
  begin
    if (!iRsn)
    begin
      rCTR   <= 8'h00;
      rIDR   <= 8'h00;
    end
    else
    begin
      rIDR <= iData;

      if (PSEL && PENABLE && PWRITE && PREADY && !PADDR[2])
        rCTR <= PWDATA[7:0];
    end
  end

  always_comb 
  begin
    PRDATA = 32'h0000_0000;
    if (PSEL && !PWRITE)
    begin
      unique case (PADDR[2])
        1'b0:    PRDATA = {24'h0, rCTR}; // CTR
        1'b1:    PRDATA = {24'h0, rIDR}; // IDR
        default: PRDATA = 32'h0000_0000;
      endcase
    end
  end

endmodule
