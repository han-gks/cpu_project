/**************************************************************
 - Project          : CPU_OS
 - File name        : GPO.sv
 - Description      : General Purpose Output (APB Slave @ 0x2001_0000)
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.14 : Initial release
                      2) 2026.11.11 : Ported to CPU_OS
**************************************************************/
`timescale 1ns / 1ps

module GPO (
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
    output logic [ 7:0] oLed
);

  // Register map, as used by test.c:
  //   0x0 CTR - output-enable/control value
  //   0x4 ODR  - LED output data
  // APB writes complete only during the access phase, so a setup cycle
  // cannot change either register.
  logic [7:0] rCTR;
  logic [7:0] rODR;

  assign PREADY = PSEL && PENABLE;
  always_comb 
  begin
    unique case (PADDR[2])
      1'b0:    PRDATA = {24'h0, rCTR};
      1'b1:    PRDATA = {24'h0, rODR};
      default: PRDATA = 32'h0000_0000;
    endcase
  end
  // Each CTR bit is an output-enable. A disabled output releases its pin.
  always_comb begin
    for (int i = 0; i < 8; i++) 
    begin
      if (rCTR[i])
        oLed[i] = rODR[i];
      else
        oLed[i] = 1'bz;
    end
  end

  always_ff @(posedge iClk) 
  begin
    if (!iRsn)
    begin
      rCTR <= 8'h00;
      rODR <= 8'h00;
    end
    else if (PSEL && PENABLE && PWRITE && PREADY)
    begin
      if (PADDR[2])
        rODR <= PWDATA[7:0];
      else
        rCTR <= PWDATA[7:0];
    end
  end

endmodule
