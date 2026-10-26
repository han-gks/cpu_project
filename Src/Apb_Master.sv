/**************************************************************
 - Project          : 20260902_CPU
 - File name        : Apb_Master.sv
 - Description      : Generic request/response to APB master adapter
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.09.11 : Initial release
**************************************************************/
`timescale 1ns / 1ps

module Apb_Master (
    // Clock and Reset
    input  logic        iClk,
    input  logic        iRsn,

    // Generic Request Interface
    input  logic        iReqValid,
    output logic        oReqReady,
    input  logic [31:0] iReqAddr,
    input  logic        iReqWrite,
    input  logic [31:0] iReqWrData,
    input  logic [ 3:0] iReqWrStrb,

    // Generic Response Interface
    output logic        oRspValid,
    output logic [31:0] oRspRdData,
    output logic        oRspError,

    // APB Master Interface
    output logic [31:0] PADDR,
    output logic [31:0] PWDATA,
    output logic        PWRITE,
    output logic [ 3:0] PSTRB,
    output logic        PSEL,
    output logic        PENABLE,

    input  logic [31:0] PRDATA,
    input  logic        PREADY,
    input  logic        PSLVERR
);

    typedef enum logic [1:0] {
        ST_IDLE     = 2'd0,
        ST_SETUP    = 2'd1,
        ST_ACCESS   = 2'd2
    } apb_state_e;

    apb_state_e rCurState;
    apb_state_e wNxtState;

    logic [31:0] rReqAddr;
    logic        rReqWrite;
    logic [31:0] rReqWrData;
    logic [ 3:0] rReqWrStrb;

    logic        wReqAccept;
    logic        wApbComplete;

    assign oReqReady   = (rCurState == ST_IDLE);
    assign wReqAccept  = iReqValid && oReqReady;
    assign wApbComplete = (rCurState == ST_ACCESS) && PREADY;

    always_ff @(posedge iClk or negedge iRsn)
    begin
        if (!iRsn)
        begin
            rCurState  <= ST_IDLE;
            rReqAddr   <= 32'b0;
            rReqWrite  <= 1'b0;
            rReqWrData <= 32'b0;
            rReqWrStrb <= 4'b0;
        end
        else
        begin
            rCurState <= wNxtState;

            if (wReqAccept)
            begin
                rReqAddr   <= iReqAddr;
                rReqWrite  <= iReqWrite;
                rReqWrData <= iReqWrData;
                rReqWrStrb <= iReqWrStrb;
            end

        end
    end

    always_comb
    begin
        wNxtState = rCurState;

        case (rCurState)
            ST_IDLE:
                if (wReqAccept)
                    wNxtState = ST_SETUP;

            ST_SETUP:
                wNxtState = ST_ACCESS;

            ST_ACCESS:
                if (PREADY)
                    wNxtState = ST_IDLE;

            default:
                wNxtState = ST_IDLE;
        endcase
    end

    assign PADDR   = rReqAddr;
    assign PWDATA  = rReqWrData;
    assign PWRITE  = rReqWrite;
    assign PSTRB   = rReqWrite ? rReqWrStrb : 4'b0000;
    assign PSEL    = (rCurState == ST_SETUP) || (rCurState == ST_ACCESS);
    assign PENABLE = (rCurState == ST_ACCESS);

    // APB completes in its final access cycle.  The response sink must sample
    // this valid/data/error bundle on that clock edge; there is no buffering
    // or response-side backpressure in this simple master.
    assign oRspValid  = wApbComplete;
    assign oRspRdData = PRDATA;
    assign oRspError  = PSLVERR;

endmodule
