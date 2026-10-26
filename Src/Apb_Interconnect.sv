/**************************************************************
 - Project          : 20260902_CPU
 - File name        : Apb_Interconnect.sv
 - Description      : 
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.11 : Initial release
**************************************************************/
`timescale 1ns / 1ps

module Apb_Interconnect (
    // APB Master Interface
    input  logic [31:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    input  logic [ 3:0] PSTRB,
    input  logic        PSEL,
    input  logic        PENABLE,

    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic        PSLVERR,

    // Shared APB Bus to Slaves
    output logic [31:0] PADDR_SLV,
    output logic [31:0] PWDATA_SLV,
    output logic        PWRITE_SLV,
    output logic [ 3:0] PSTRB_SLV,
    output logic        PENABLE_SLV,

    // Individual Slave Select Signals
    output logic        PSEL_RAM,
    output logic        PSEL_GPI,
    output logic        PSEL_GPO,
    output logic        PSEL_GPIO,
    output logic        PSEL_UART,
    output logic        PSEL_FND,

    // Individual Slave Response Inputs
    input  logic [31:0] PRDATA_RAM,
    input  logic        PREADY_RAM,
    input  logic        PSLVERR_RAM,

    input  logic [31:0] PRDATA_GPI,
    input  logic        PREADY_GPI,
    input  logic        PSLVERR_GPI,

    input  logic [31:0] PRDATA_GPO,
    input  logic        PREADY_GPO,
    input  logic        PSLVERR_GPO,

    input  logic [31:0] PRDATA_GPIO,
    input  logic        PREADY_GPIO,
    input  logic        PSLVERR_GPIO,

    input  logic [31:0] PRDATA_UART,
    input  logic        PREADY_UART,
    input  logic        PSLVERR_UART,

    input  logic [31:0] PRDATA_FND,
    input  logic        PREADY_FND,
    input  logic        PSLVERR_FND
);

    // Internal Decode Flags
    // RAM  : 0x1000_0000 ~ 0x1000_FFFF
    // GPI  : 0x2000_0000 ~ 0x2000_FFFF
    // GPO  : 0x2001_0000 ~ 0x2001_FFFF
    // GPIO : 0x2002_0000 ~ 0x2002_FFFF
    // UART : 0x2003_0000 ~ 0x2003_FFFF
    // FND  : 0x2004_0000 ~ 0x2004_FFFF
    logic wDecode_RAM;
    logic wDecode_GPI;
    logic wDecode_GPO;
    logic wDecode_GPIO;
    logic wDecode_UART;
    logic wDecode_FND;

    // Address Decoding Logic
    always_comb
    begin
        wDecode_RAM  = 1'b0;
        wDecode_GPI  = 1'b0;
        wDecode_GPO  = 1'b0;
        wDecode_GPIO = 1'b0;
        wDecode_UART = 1'b0;
        wDecode_FND  = 1'b0;

        if (PADDR[31:16] == 16'h1000)
            wDecode_RAM = 1'b1;
        else if (PADDR[31:20] == 12'h200)
            case (PADDR[19:16])
                4'h0: wDecode_GPI  = 1'b1;
                4'h1: wDecode_GPO  = 1'b1;
                4'h2: wDecode_GPIO = 1'b1;
                4'h3: wDecode_UART = 1'b1;
                4'h4: wDecode_FND  = 1'b1;
                default: ;
            endcase
    end

    // Slave Response Multiplexer (PRDATA, PREADY & PSLVERR)
    always_comb
    begin
        case (1'b1)
            wDecode_RAM     :  
            begin 
                PREADY = PREADY_RAM;  
                PRDATA = PRDATA_RAM;
                PSLVERR = PSLVERR_RAM;
            end
            
            wDecode_GPI     :  
            begin 
                PREADY = PREADY_GPI;  
                PRDATA = PRDATA_GPI;  
                PSLVERR = PSLVERR_GPI;
            end
            
            wDecode_GPO     :  
            begin 
                PREADY = PREADY_GPO;  
                PRDATA = PRDATA_GPO;  
                PSLVERR = PSLVERR_GPO;
            end
            
            wDecode_GPIO    : 
            begin 
                PREADY = PREADY_GPIO; 
                PRDATA = PRDATA_GPIO; 
                PSLVERR = PSLVERR_GPIO;
            end
            
            wDecode_UART    : 
            begin 
                PREADY = PREADY_UART; 
                PRDATA = PRDATA_UART; 
                PSLVERR = PSLVERR_UART;
            end
            
            wDecode_FND     : 
            begin 
                PREADY = PREADY_FND;  
                PRDATA = PRDATA_FND;  
                PSLVERR = PSLVERR_FND;
            end
           
            default         : 
            begin
                // Prevent CPU hang on accessing unmapped regions
                PREADY = 1'b1;
                PRDATA = 32'h0000_0000;
                PSLVERR = 1'b1;
            end
        endcase
    end

    // Broadcast Common Bus Signals
    assign PADDR_SLV   = PADDR;
    assign PWDATA_SLV  = PWDATA;
    assign PWRITE_SLV  = PWRITE;
    assign PSTRB_SLV   = PSTRB;
    assign PENABLE_SLV = PENABLE;

    // Slave Select Signal Gating
    assign PSEL_RAM  = PSEL & wDecode_RAM;
    assign PSEL_GPI  = PSEL & wDecode_GPI;
    assign PSEL_GPO  = PSEL & wDecode_GPO;
    assign PSEL_GPIO = PSEL & wDecode_GPIO;
    assign PSEL_UART = PSEL & wDecode_UART;
    assign PSEL_FND  = PSEL & wDecode_FND;

endmodule
