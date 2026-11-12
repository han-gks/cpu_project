/**************************************************************
 - Project          : CPU_OS
 - File name        : Uart_Rx.v
 - Description      : UART 8N1 Receiver
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.08.06 : Initial release
                      2) 2026.11.11 : Ported to CPU_OS
**************************************************************/
`timescale 1ns / 1ps

module Uart_Rx (
    input           iClk,
    input           iRst,
    input           iRx,
    input           iTick_Baud_16,

    output          oRx_Done,
    output  [7:0]   oRx_Data
);

    parameter   IDLE  = 2'b00;
    parameter   START = 2'b01;
    parameter   DATA  = 2'b10;
    parameter   STOP  = 2'b11;

    reg [1:0]   rCurState;
    reg [1:0]   rNxtState;

    reg [2:0]   rBit_Cnt;
    reg [3:0]   rTick_16;

    reg [7:0]   rRx_Reg;
    reg [7:0]   rRx_Data;
    reg         rRx_Done;

    /***********************************************
    // Baudrate x16 sampling for all state
    ***********************************************/
    always @(posedge iClk or posedge iRst)
    begin
        if (iRst)
            rTick_16 <= 0;
        else if ((rCurState != rNxtState) || (rCurState == IDLE && iRx == 1'b1))
            rTick_16 <= 0;
        else if (iTick_Baud_16)
            rTick_16 <= rTick_16 + 1;
        else
            rTick_16 <= rTick_16;
    end

    /***********************************************
    // Bit count for DATA state
    ***********************************************/
    always @(posedge iClk, posedge iRst)
    begin
        if(iRst)
            rBit_Cnt <= 0;
        else if(rCurState == IDLE || rCurState == START)
            rBit_Cnt <= 0;
        else if((rCurState == DATA) && (rTick_16 == 15) && (iTick_Baud_16 == 1'b1))
            rBit_Cnt <= rBit_Cnt + 1;
        else
            rBit_Cnt <= rBit_Cnt;
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
                if((iRx == 1'b0) && (rTick_16 == 7) && (iTick_Baud_16 == 1'b1))
                    rNxtState = START;
                else
                    rNxtState = IDLE;

            START   :
                if((rTick_16 == 15) && (iTick_Baud_16 == 1'b1))
                    rNxtState = DATA;
                else
                    rNxtState = START;

            DATA    :
                if((rBit_Cnt == 7) && (rTick_16 == 15) && iTick_Baud_16)    
                    rNxtState = STOP;                                       
                else
                    rNxtState = DATA;

            STOP    :
                if((iTick_Baud_16 == 1) && (rTick_16 == 7))
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
        begin
            rRx_Reg  <= 0;
            rRx_Data <= 0;
        end
        else
        begin
            case(rCurState)
                IDLE    : rRx_Reg <= 0;
                START   : rRx_Reg <= 0;
                DATA    :
                    if((rTick_16 == 0) && (iTick_Baud_16))        
                        rRx_Reg <= {iRx, rRx_Reg[7:1]};           
                STOP    : rRx_Data <= rRx_Reg;                        
                default : rRx_Reg <= 0;
            endcase
        end
    end  

    /***********************************************
    // output assign
    ***********************************************/
    always @(posedge iClk or posedge iRst)
    begin
        if (iRst)
            rRx_Done <= 0;
        else if((rNxtState == IDLE) && (rCurState == STOP))  
            rRx_Done <= 1;
        else
            rRx_Done <= 0;
    end

    assign oRx_Data = rRx_Data;     
    assign oRx_Done = rRx_Done;

endmodule
