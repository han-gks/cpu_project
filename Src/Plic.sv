/**************************************************************
 - Project          : CPU_OS
 - File name        : Plic.sv
 - Description      : Platform-Level Interrupt Controller (APB slave)
                      - 4 interrupt sources (ID 1 ~ 4), 1 context (M-mode)
                      - priority  : 0x00_0004 ~ 0x00_0010
                      - pending   : 0x00_1000 (read-only)
                      - enable    : 0x00_2000
                      - threshold : 0x20_0000
                      - claim     : 0x20_0004 (read : claim / write : complete)
 - Owner            : Hyunjae.Jung
 - Revision history : 1) 2026.11.11 : Initial release
                      2) 2026.11.16 : Register oMeip output (rMeip) for STA timing
                      3) 2026.11.19 : Unify interrupt source indexing to [4:1] per RISC-V PLIC spec (ID 0 reserved)
**************************************************************/
`timescale 1ns / 1ps

module Plic (
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

    // Input Ports: Interrupt Source (RISC-V PLIC spec: ID 0 is reserved, valid source IDs are 1 ~ 4)
    input  logic [ 4:1] iIrq,

    // Output Ports: Interrupt
    output logic        oMeip           // machine external interrupt pending
);

    // Register address (offset)
    localparam logic [21:0] ADDR_PRIORITY_1 = 22'h00_0004;
    localparam logic [21:0] ADDR_PRIORITY_2 = 22'h00_0008;
    localparam logic [21:0] ADDR_PRIORITY_3 = 22'h00_000C;
    localparam logic [21:0] ADDR_PRIORITY_4 = 22'h00_0010;
    localparam logic [21:0] ADDR_PENDING    = 22'h00_1000;
    localparam logic [21:0] ADDR_ENABLE     = 22'h00_2000;
    localparam logic [21:0] ADDR_THRESHOLD  = 22'h20_0000;
    localparam logic [21:0] ADDR_CLAIM      = 22'h20_0004;

    // Indexed [4:1] to match RISC-V PLIC interrupt source IDs (ID 0 is reserved for "no interrupt")
    logic [4:1] rPending;
    logic [4:1] rEnable;
    logic [2:0] rPriority [1:4];
    logic [2:0] rThreshold;
    logic [4:1] rBusy;                  // gateway : block re-trigger until complete
    logic       rMeip;

    logic [2:0] wClaimId;
    logic [2:0] wClaimPriority;

    // APB response : always ready, no error
    assign PREADY  = 1'b1;
    assign PSLVERR = 1'b0;

    // Interrupt output : registered highest pending source above threshold
    assign oMeip   = rMeip;

    // Claim arbitration : highest priority among pending & enabled sources
    // Per RISC-V PLIC spec, lowest interrupt ID wins ties (ID 1 > ID 2 > ID 3 > ID 4)
    always_comb
    begin
        wClaimId       = 3'd0;          // ID 0 = no pending/enabled interrupt
        wClaimPriority = 3'd0;
        for (int i = 1; i <= 4; i++)
        begin
            if (rPending[i] && rEnable[i] && (rPriority[i] > wClaimPriority))
            begin
                wClaimId       = i[2:0];
                wClaimPriority = rPriority[i];
            end
        end
    end

    // Write : gateway (pending/busy) + APB write + claim
    always_ff @(posedge iClk or negedge iRsn)
    begin
        if (!iRsn)
        begin
            rPending   <= 4'b0000;
            rEnable    <= 4'b0000;
            rBusy      <= 4'b0000;
            rThreshold <= 3'b000;
            rMeip      <= 1'b0;
            for (int i = 1; i <= 4; i++)
            begin
                rPriority[i] <= 3'b0;
            end
        end
        else
        begin
            rMeip <= (wClaimId != 3'd0) && (wClaimPriority > rThreshold);

            // Gateway : latch new request (Source ID 1 ~ 4)
            for (int i = 1; i <= 4; i++)
            begin
                if (iIrq[i] && !rBusy[i])
                begin
                    rPending[i] <= 1'b1;
                    rBusy[i]    <= 1'b1;
                end
            end

            // APB write
            if (PSEL && PENABLE && PWRITE)
            begin
                case (PADDR[21:0])
                    ADDR_PRIORITY_1 : if (PSTRB[0]) rPriority[1] <= PWDATA[2:0];
                    ADDR_PRIORITY_2 : if (PSTRB[0]) rPriority[2] <= PWDATA[2:0];
                    ADDR_PRIORITY_3 : if (PSTRB[0]) rPriority[3] <= PWDATA[2:0];
                    ADDR_PRIORITY_4 : if (PSTRB[0]) rPriority[4] <= PWDATA[2:0];

                    // Bit 0 is reserved (ID 0); bits [4:1] map to interrupt source IDs 1 ~ 4
                    ADDR_ENABLE     : if (PSTRB[0]) rEnable      <= PWDATA[4:1];

                    ADDR_THRESHOLD  : if (PSTRB[0]) rThreshold   <= PWDATA[2:0];

                    // Complete : release gateway of written source ID (1 ~ 4)
                    ADDR_CLAIM      :
                    begin
                        if ((PSTRB == 4'b1111) && (PWDATA >= 32'd1) && (PWDATA <= 32'd4))
                        begin
                            if (rEnable[PWDATA[2:0]])
                            begin
                                rBusy[PWDATA[2:0]] <= 1'b0;
                            end
                        end
                    end

                    default         : ;
                endcase
            end

            // Claim : APB read of claim register clears pending bit of claimed ID (1 ~ 4)
            if (PSEL && PENABLE && !PWRITE && (PADDR[21:0] == ADDR_CLAIM) && (wClaimId != 3'd0))
            begin
                rPending[wClaimId] <= 1'b0;
            end
        end
    end

    // Read : combinational
    always_comb
    begin
        PRDATA = 32'd0;
        case (PADDR[21:0])
            ADDR_PRIORITY_1 : PRDATA = {29'b0, rPriority[1]};
            ADDR_PRIORITY_2 : PRDATA = {29'b0, rPriority[2]};
            ADDR_PRIORITY_3 : PRDATA = {29'b0, rPriority[3]};
            ADDR_PRIORITY_4 : PRDATA = {29'b0, rPriority[4]};
            // Bit 0 is hardwired to 0 per RISC-V PLIC spec (ID 0 does not exist)
            ADDR_PENDING    : PRDATA = {27'b0, rPending, 1'b0};
            ADDR_ENABLE     : PRDATA = {27'b0, rEnable,  1'b0};
            ADDR_THRESHOLD  : PRDATA = {29'b0, rThreshold};
            ADDR_CLAIM      : PRDATA = {29'b0, wClaimId};
            default         : ;                 // unmapped : 0
        endcase
    end

endmodule
