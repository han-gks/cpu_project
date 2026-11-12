/**************************************************************
 - Project          : CPU_OS
 - File name        : InstRom.sv
 - Description      : Instruction ROM (16KB = 4096 Words)
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.02 : Initial release
                      2) 2026.11.11 : Expand ROM_WORDS to 4096 (16KB) for OS porting
**************************************************************/
`timescale 1ns / 1ps

module InstRom #(
    parameter integer ROM_WORDS = 4096,
    parameter ROM_FILE = "C:/__Project/CPU_OS/Src/code/rom_code_FreeRTOS.hex"
) (
    // Input Ports: Data
    input  logic [31:0] iInstAddr,

    // Output Ports: Data
    output logic [31:0] oInstData
);

    localparam integer ADDR_BITS = $clog2(ROM_WORDS);

    logic [31:0] rInstRom [0:ROM_WORDS-1];

    initial
    begin
        for (int i = 0; i < ROM_WORDS; i++)
            rInstRom[i] = 32'h0000_0013; // Default NOP
        $readmemh(ROM_FILE, rInstRom);
    end

    assign oInstData = rInstRom[iInstAddr[ADDR_BITS+1:2]];

endmodule
