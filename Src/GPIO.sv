/**************************************************************
 - Project          : CPU_OS
 - File name        : GPIO.sv
 - Description      : General Purpose I/O (APB Slave @ 0x2002_0000)
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.14 : Initial release
                      2) 2026.11.11 : Ported to CPU_OS
**************************************************************/
`timescale 1ns / 1ps

module GPIO (
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
    inout  wire  [ 7:0] ioLedSw
);

  // Register map:
  //   0x0 CTR - per-bit output-enable, read/write
  //   0x4 IDR - pin input data, read-only
  //   0x8 ODR - output data, read/write
  logic [7:0] rCTR;
  logic [7:0] rIDR;
  logic [7:0] rODR;

  assign PREADY = PSEL && PENABLE;

  generate
    for (genvar i = 0; i < 8; i++) 
    begin : g_gpio_pad
      assign ioLedSw[i] = rCTR[i] ? rODR[i] : 1'bz;
    end
  endgenerate

  always_ff @(posedge iClk) 
  begin
    if (!iRsn)
    begin
      rCTR <= 8'h00;
      rIDR <= 8'h00;
      rODR <= 8'h00;
    end
    
    else
    begin
      rIDR <= ioLedSw;

      if (PSEL && PENABLE && PWRITE && PREADY)
      begin
        case (PADDR[3:2])
          2'b00:  rCTR <= PWDATA[7:0];
          2'b10:  rODR <= PWDATA[7:0];
          default: ;
        endcase

      end
    end
  end

  always_comb 
  begin
    PRDATA = 32'h0000_0000;

    if (PSEL && !PWRITE)
    begin
      unique case (PADDR[3:2])
        2'b00:  PRDATA = {24'h0, rCTR};
        2'b01:  PRDATA = {24'h0, rIDR};
        2'b10:  PRDATA = {24'h0, rODR};
        default: PRDATA = 32'h0000_0000;
      endcase

    end
  end

endmodule
