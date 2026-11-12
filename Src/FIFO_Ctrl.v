/**************************************************************
 - Project          : CPU_OS
 - File name        : FIFO_Ctrl.v
 - Description      : Synchronous FIFO Pointer & Status Controller
 - Owner            : Daegyu.Han
 - Revision history : 1) 2026.08.10 : Initial release
                      2) 2026.11.11 : Ported to CPU_OS
**************************************************************/
`timescale 1ns / 1ps

module FIFO_Ctrl #(
    parameter ADDR_WIDTH = 2           
)(
    input                       iClk,
    input                       iRst,

    input                       iPush,
    input                       iPop,

    output  [ADDR_WIDTH-1:0]    oWrPtr,
    output  [ADDR_WIDTH-1:0]    oRdPtr,

    output                      oFull,
    output                      oEmpty
);

    reg     [ADDR_WIDTH-1:0] rWrPtr;
    reg     [ADDR_WIDTH-1:0] rWrPtr_d;
    reg     [ADDR_WIDTH-1:0] rRdPtr;
    reg     [ADDR_WIDTH-1:0] rRdPtr_d;

    reg                 rFull;
    reg                 rFull_d;
    reg                 rEmpty;
    reg                 rEmpty_d;

    always@(posedge iClk, posedge iRst)
    begin
        if(iRst)
        begin
            rWrPtr <= 0;
            rRdPtr <= 0;
            rFull  <= 0;
            rEmpty <= 1;
        end
        else
        begin
            rWrPtr <= rWrPtr_d;
            rRdPtr <= rRdPtr_d;
            rFull  <= rFull_d;
            rEmpty <= rEmpty_d;
        end
    end

    always @(*)
    begin
        rWrPtr_d = rWrPtr;
        rRdPtr_d = rRdPtr;
        rFull_d  = rFull;
        rEmpty_d = rEmpty;

        case({iPush, iPop})
            2'b00   :       // init
            begin
            end

            2'b01   :       // pop only
            begin
                if(rEmpty != 1'b1)
                begin
                    rRdPtr_d = rRdPtr + 1;
                    rFull_d  = 1'b0;
                    if(rWrPtr == rRdPtr_d)
                        rEmpty_d = 1'b1;
                end
            end

            2'b10   :       // push only
            begin
                if(rFull != 1'b1)
                begin
                    rWrPtr_d = rWrPtr + 1;
                    rEmpty_d = 1'b0;
                    if(rWrPtr_d == rRdPtr)
                        rFull_d = 1'b1;
                end
            end

            2'b11   :       // push & pop
                if(rFull == 1'b1)
                begin
                    rRdPtr_d = rRdPtr + 1;
                    rFull_d  = 1'b0;
                end
                else if(rEmpty == 1'b1)
                begin
                    rWrPtr_d = rWrPtr + 1;
                    rEmpty_d = 1'b0;
                end
                else
                begin
                    rWrPtr_d = rWrPtr + 1;
                    rRdPtr_d = rRdPtr + 1;
                end
        endcase
    end

    assign oWrPtr = rWrPtr;
    assign oRdPtr = rRdPtr;
    assign oFull  = rFull;
    assign oEmpty = rEmpty;

endmodule
