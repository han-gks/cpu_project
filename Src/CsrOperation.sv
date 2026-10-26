`timescale 1ns / 1ps

// CSR WRITE/SET/CLEAR를 계산하는 조합논리 모듈. 저장은 CsrRegisterFile에서 수행한다.
module CsrOperation (
    //  WB 단계에서 전달한 연산 종류. 현재 분기는 bit1=1이면 WRITE, 그 외 bit0=1이면 SET, 나머지는 CLEAR
    input  logic [1:0]  iCsrOp,         //oSCRCtrl
    // 1이면 zimm, 0이면 일반 레지스터 rs1의 값을 피연산자로 선택
    input  logic        iCsrImmSel,     //oCSRImmSel
    // CSR에서 읽은 변경 전 값. SET/CLEAR 연산에 사용
    input  logic [31:0] iCsrData,
    //  명령어의 rs1 번호가 아니라, 그 레지스터에서 읽어 전달한 32비트 데이터
    input  logic [31:0] iRs1Data,
    // 명령어 [19:15]에서 추출되어 전달되어야 하는 5비트 즉시값
    input  logic [4:0]  iZimm,
    // 계산한 새로운 CSR 값. 일반 레지스터 rd로 보내는 기존 CSR 값과 구별
    output logic [31:0] oCsrData
);
    logic [31:0] wSrcData;

    //  전달받은 zimm을 0으로 확장하거나 rs1 값을 선택
    assign wSrcData = iCsrImmSel ? {27'b0, iZimm} : iRs1Data;

    always_comb begin
    // WRITE: 선택한 피연산자로 CSR 값을 교체한다. CSR_NONE 인코딩도 이 분기에 들어오면 쓰기 허용 신호로 저장을 막아야 함
        if(iCsrOp[1])
        begin
            oCsrData = wSrcData;                //CSR_WRITE
        end
    //  SET: 피연산자가 1인 비트만 OR로 설정하며 다른 비트는 유지
        else if(iCsrOp[0])
        begin
            oCsrData = iCsrData | wSrcData;    //CSR_SET
        end
        else 
        begin
    //  CLEAR: 피연산자가 1인 비트만 0으로 지우며 다른 비트는 유지
            oCsrData = iCsrData & ~wSrcData;   //CSR_CLEAR
        end
    end

endmodule
