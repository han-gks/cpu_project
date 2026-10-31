/**************************************************************
 - Project          : CPU_OS
 - File name        : InstRom.sv
 - Description      : 
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.02 : Initial release
**************************************************************/
`timescale 1ns / 1ps

module InstRom #(
    parameter integer ROM_WORDS = 1024,
    parameter ROM_FILE = "../../Src/code/rom_code_CSR.hex"
) (
    // Input Ports: Data
    input  logic [31:0] iInstAddr,

    // Output Ports: Data
    output logic [31:0] oInstData
);

    logic [31:0] rInstRom [0:ROM_WORDS-1];

    initial
    begin
        $readmemh(ROM_FILE, rInstRom);
        // for test
        //$readmemh("./code/rom_code_CSR.hex", rInstRom);
        //rInstRom[0]  = 32'hfe01_0113;
        //rInstRom[1]  = 32'h0011_2e23;
        //rInstRom[2]  = 32'h0081_2c23;
        //rInstRom[3]  = 32'h0201_0413;
        //rInstRom[4]  = 32'h00a0_0793;
        //rInstRom[5]  = 32'hfef4_2623;
        //rInstRom[6]  = 32'h0140_0793;
        //rInstRom[7]  = 32'hfef4_2423;
        //rInstRom[8]  = 32'hfec4_2703;
        //rInstRom[9]  = 32'hfe84_2783;
        //rInstRom[10] = 32'h00f7_07b3;
        //rInstRom[11] = 32'hfef4_2223;
        //rInstRom[12] = 32'h0000_0013;
        //rInstRom[13] = 32'h01c1_2083;
        //rInstRom[14] = 32'h0181_2403;
        //rInstRom[15] = 32'h0201_0113;
        //rInstRom[16] = 32'h0000_8067;
    end

    assign oInstData = rInstRom[iInstAddr[31:2]];

endmodule
