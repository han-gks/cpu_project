`timescale 1ns / 1ps


module CsrRegisterFile(

    input  logic        iClk,
    input  logic        CsrWrEn,
    input  logic        CsrRdEn,

    input  logic [11:0] iCsrAddr,
    input  logic [31:0] iCsrWrData,
    output logic [31:0] oCsrRdData
);

    // 머신 모드 CSR 저장 공간
    logic [31:0] mstatus, mie, mtvec, mscratch, mepc, mcause;

    //  클럭 상승 에지에서 CsrWrEn이 1일 때 주소에 해당하는 CSR을 갱신
    always_ff@(posedge iClk)
    begin
        if(CsrWrEn) 
        begin
        case(iCsrAddr)
            12'h300: mstatus <= iCsrWrData;
            12'h304: mie     <= iCsrWrData;
            12'h305: mtvec   <= iCsrWrData;
            12'h340: mscratch<= iCsrWrData;
            12'h341: mepc    <= iCsrWrData;   
            12'h342: mcause  <= iCsrWrData; 
            default: ;
        endcase
        end
    end 

    // 선택한 CSR의 기존 값을 출력하여 rd의 WB 값과 CSR 연산 입력으로 사용한다.
    // 확인 필요: 현재 CsrRdEn=0인 경로에는 출력 대입이 없어 이전 값을 유지하는 래치가 나올듯, 차후 수정
    always_comb 
    begin
    // SET/CLEAR는 rd가 x0이어도 기존 CSR 값을 계산에 사용하므로 읽기가 필요
      if(CsrRdEn) 
      begin 
        oCsrRdData = 32'b0;
        case(iCsrAddr)
            12'h300: oCsrRdData = mstatus;
            12'h304: oCsrRdData = mie;
            12'h305: oCsrRdData = mtvec;
            12'h340: oCsrRdData = mscratch;
            12'h341: oCsrRdData = mepc;   
            12'h342: oCsrRdData = mcause; 
            default: oCsrRdData = 32'b0;
        endcase
        end
    end
    
endmodule
