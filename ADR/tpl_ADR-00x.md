# [ADR-00X] 제목: 간결하고 명확한 결정 주제

- **작성일자:** YYYY-MM-DD
- **작성자 / 리뷰어:** 본인, 팀원 이름
- **상태:** 제안됨(Proposed) / 승인됨(Accepted) / 대체됨(Deprecated)
- **영향 범위:** Datapath, Hazard Unit, CSR Regfile, Pipeline Registers

---

### 1. 배경 및 문제 정의 (Context & Problem Statement)
- 현재 어떤 구조적 한계나 요구사항이 발생하는가?
- 왜 지금 이 결정을 내려야 하는가? (예: 타이밍 지연, 코너 케이스, 하드웨어 리소스 문제 등)

### 2. 설계 요구사항 및 제약조건 (Requirements & Constraints)
- **기능적 제약:** (예: Precise Interrupt 보장, 단일 사이클 트랩 처리)
- **하드웨어/성능 제약:** (예: Critical Path 연장 방지, 추가 FF/MUX 최소화)

### 3. 고려된 대안 비교 (Considered Alternatives)

| 비교 항목                | 대안 A (구조명) | 대안 B (구조명) | 대안 C (구조명) |
| :------------------- | :--------- | :--------- | :--------- |
| **핵심 메커니즘**          | ...        | ...        | ...        |
| **추가 자원 (Area)**     | ...        | ...        | ...        |
| **타이밍 (Fmax/Slack)** | ...        | ...        | ...        |
| **제어 복잡도**           | ...        | ...        | ...        |
| **검증 난이도**           | ...        | ...        | ...        |

#### Option 1: [대안 A 이름]
- **설명:** 동작 방식 서술
- **장점:** 
- **단점/리스크:** 

#### Option 2: [대안 B 이름]
...

---

### 4. 최종 결정 및 근거 (Decision & Rationale)
- **선택된 안:** [Option X: 선택한 대안 이름]
- **선택 이유 (Trade-off 근거):**
  1. ...
  2. ...
- **포기한 것 (Trade-off 감수 사항):** (예: 면적 32-bit FF 증가 감수)

### 5. 예상 부작용 및 후속 조치 (Consequences & Action Items)
- **주의할 코너 케이스:** (예: Branch Mispredict 발생 시 Flush 연동 등)
- **검증 계획 (Verification Plan):** (예: riscv-tests 특정 스위트, Spike Lockstep 비교)