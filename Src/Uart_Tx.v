/**************************************************************
 - Project          : CPU_OS
 - File name        : Uart_Tx.v
 - Description      : UART 8N1 Transmitter
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.08.05 : Initial release
                      2) 2026.11.11 : Ported to CPU_OS
**************************************************************/
`timescale 1ns / 1ps

module Uart_Tx (
    input           iClk,
    input           iRst,
    input           iTick_Baud_16,

    input           iTx_Start,
    input   [7:0]   iTx_Data,           // Data in @ START state

    output          oTx_Busy,           // sign to operating this module
    output          oTx_Done,           // sign to operating done this module
    output          oTx_Data
);

    parameter IDLE  = 2'b00;
    parameter START = 2'b01;
    parameter DATA  = 2'b10;
    parameter STOP  = 2'b11;

    parameter BIT_MAX = 8;       // 0 to 7

    reg [1:0] rCurState;
    reg [1:0] rNxtState;

    reg [$clog2(BIT_MAX)-1:0] rTickCnt;
    reg [       BIT_MAX -1:0] rTx_Reg;
    reg                       rTx_Data;
    reg                       rTx_Done;

    reg [                3:0] rCnt_16; 

    /***********************************************
    // Counter for x16 sampling to normal
    ***********************************************/
    always @(posedge iClk or posedge iRst)
    begin
        if (iRst)
            rCnt_16 <= 0;
        else if (rCurState == IDLE)
            rCnt_16 <= 0;
        else if(iTick_Baud_16 == 1)
        begin
            if(rCnt_16 == 15)
                rCnt_16 <= 0;
            else
                rCnt_16 <= rCnt_16 + 1;
        end
        else
            rCnt_16 <= rCnt_16;
    end

    /***********************************************
    // Counter for DATA state
    ***********************************************/
    always @(posedge iClk or posedge iRst)
    begin
        if (iRst)
            rTickCnt <= 0;
        else if (rCurState == IDLE || rCurState == START)
            rTickCnt <= 0;
        else if((rCurState == DATA) && (rCnt_16 == 15) && (iTick_Baud_16 == 1'b1))
        begin
            if(rTickCnt == BIT_MAX - 1)
                rTickCnt <= 0;
            else
                rTickCnt <= rTickCnt + 1'b1;
        end
        else
            rTickCnt <= rTickCnt;
    end

    /***********************************************
    // Latch for Tx Data
    ***********************************************/
    always @(posedge iClk or posedge iRst)
    begin
        if (iRst)
            rTx_Reg <= 8'hFF;
        else if((rCurState == IDLE) && (iTx_Start == 1'b1)) 
            rTx_Reg <= iTx_Data;         
        else
            rTx_Reg <= rTx_Reg;
    end
    
    /***********************************************
    // FSM
    ***********************************************/
    always @(posedge iClk or posedge iRst)
    begin
        if (iRst)
            rCurState <= IDLE;
        else
            rCurState <= rNxtState;
    end

    always @(*)
    begin
        rNxtState = rCurState;

        case(rCurState)
            IDLE    :
                if(iTx_Start == 1'b1)
                    rNxtState = START;
                else
                    rNxtState = IDLE;
            START   :
               if((iTick_Baud_16) && (rCnt_16 == 15))
                   rNxtState = DATA;
               else
                   rNxtState = START;
            DATA    :
                if(iTick_Baud_16 && (rTickCnt == BIT_MAX-1) && (rCnt_16 == 15))
                    rNxtState = STOP;
                else
                    rNxtState = DATA;
            STOP    :
               if((iTick_Baud_16) && (rCnt_16 == 15))
                   rNxtState = IDLE;
                else
                   rNxtState = STOP;
            default :
                rNxtState = IDLE;
        endcase
    end

    always @(posedge iClk or posedge iRst)
    begin
        if(iRst)
            rTx_Data <= 1'b1;
        else
        begin
            case(rCurState)
                IDLE    : rTx_Data <= 1'b1;
                START   : rTx_Data <= 1'b0;
                DATA    : rTx_Data <= rTx_Reg[rTickCnt];
                STOP    : rTx_Data <= 1'b1;
                default : rTx_Data <= 1'b1;
            endcase
        end
    end

    /***********************************************
    // Output assign
    ***********************************************/
    always@(posedge iClk, posedge iRst)
    begin
        if(iRst)
            rTx_Done <= 1'b0;
        else if((rNxtState == IDLE) && (rCurState == STOP) && (rCnt_16 == 15) && (iTick_Baud_16 == 1'b1))
            rTx_Done <= 1'b1;
        else
            rTx_Done <= 1'b0;
    end

    assign oTx_Data = rTx_Data;
    assign oTx_Done = rTx_Done;
    assign oTx_Busy = (rCurState == IDLE) ? 1'b0 : 1'b1;

endmodule
