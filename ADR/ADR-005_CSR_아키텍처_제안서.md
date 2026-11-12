# [ADR-005] 5단계 파이프라인 CPU의 CSR 연산·저장 구조 및 WB 완료 정책

- **작성일자:** 2026-10-30
- **작성자 장병옥 / 리뷰어:** 한대규, 정현재
- **상태:** 제안됨(Proposed) — *CSR 연산의 WB 배치는 설계 합의 완료; CSR 해저드·Trap 중재 정책은 후속 합의 필요*
- **영향 범위:** `Cpu_h.sv`, `Ctrlpath.sv`, `Cpu.sv`, `ImmExtend.sv`, `Datapath.sv`, `CsrOperation.sv`, `CsrRegisterFile.sv`, `Forwarding.sv`, `HazardUnit.sv`, Pipeline Registers, Trap Controller(후속)
- **관련 결정:** ADR-001(파이프라인 CPU), ADR-002(EX 분기 판정), ADR-003(Forwarding), ADR-004(Load-use Stall)

---

### 1. 배경 및 문제 정의 (Context & Problem Statement)

CPU는 ADR-001에 따라 명령어를 겹쳐 실행하는 5단계 파이프라인(IF–ID–EX–MEM–WB)을 사용한다. CSR(Control and Status Register)은 일반 레지스터와 달리 CPU의 제어·상태를 보관하며, CSR 명령어는 기존 CSR 값을 목적지 일반 레지스터 `rd`에 반환하면서 같은 CSR을 WRITE/SET/CLEAR 방식으로 변경할 수 있다.

파이프라인에 CSR을 도입하면 다음 문제가 발생한다.

1. **상태 변경 시점:** EX에서 CSR을 먼저 갱신할 경우, 나중에 해당 명령어가 잘못된 분기 경로로 판명되거나 Trap으로 취소되면 상태 복구가 필요할 수 있다.
2. **데이터 의존성:** CSR 명령어의 `rs1`이 앞선 ALU/load 결과를 참조할 수 있고, 뒤따르는 명령어는 CSR이 `rd`에 반환한 이전 CSR 값을 참조할 수 있다.
3. **CSR 간 의존성:** 같은 CSR에 대한 연속 WRITE/SET/CLEAR는 프로그램 순서의 최신 상태를 기반으로 실행되어야 한다.
4. **제어 충돌:** ADR-002의 taken 분기 Flush, ADR-004의 Load-use Stall, 이후 외부 인터럽트·ECALL 및 Trap 하드웨어 갱신과 CSR 쓰기가 충돌할 수 있다.

따라서 **CSR 연산을 어떤 단계에서 수행하고, CSR Register File을 어떻게 구성하며, 기존 Forwarding/Stall/Flush 정책과 어떻게 접합할 것인지**를 기록한다.

### 2. 설계 요구사항 및 제약조건 (Requirements & Constraints)

- **기능적 요구:** `CSRRW`, `CSRRS`, `CSRRC`, `CSRRWI`, `CSRRSI`, `CSRRCI`의 기존 CSR 값 반환과 WRITE/SET/CLEAR 동작을 구분한다.
- **읽기·쓰기 조건:** CSRRW/CSRRWI는 `rd=x0`일 때 CSR 읽기를 억제하되 쓰기는 수행한다. CSRRS/CSRRC는 `rs1=x0`, CSRRSI/CSRRCI는 `zimm=0`일 때 CSR 쓰기를 억제하되 CSR 읽기는 수행한다.
- **파이프라인 정합성:** 명령어 주소·CSR 주소·연산 방식·피연산자·활성화 신호가 동일 명령어의 것으로 WB에 도착해야 한다.
- **제어 정합성:** ADR-002의 EX taken 분기 시 IF/ID 및 ID/EX의 젊은 명령어는 무효화하고 부작용을 금지한다. ADR-004의 Load-use 보류/버블은 CSR의 실제 소스 사용 여부를 고려해 확장한다.
- **데이터 정합성:** ADR-003의 EX/MEM→EX 우선, MEM/WB→EX 다음, WB→ID 우회 원칙을 CSR의 일반 레지스터 입력에도 적용한다. x0은 의존성에서 제외한다.
- **구조/성능 제약:** 기존 ALU·Data Memory 경로를 가급적 유지하고, 파이프라인 레지스터·MUX 추가에 따른 면적 및 WB 임계 경로 영향을 평가한다.
- **Trap 경계:** 이미 정상 완료되어야 할 오래된 CSR 쓰기를 보존하면서 Trap을 처리한다는 방향은 합의했으나, 정확한 수락 단계·CSR 하드웨어 쓰기 중재·ECALL 배출 규칙은 아직 확정되지 않았다.

### 3. 고려된 대안 비교 (Considered Alternatives)

#### 3.1 CSR 연산 및 소프트웨어 쓰기 단계 선택

| 비교 항목 | 대안 A: EX 읽기·연산·쓰기 | **대안 B: WB 읽기·연산·쓰기 (선택)** | 대안 C: EX 읽기·연산, WB 쓰기 |
| :--- | :--- | :--- | :--- |
| **핵심 메커니즘** | EX에서 CSR 상태 직접 변경 | CSR 정보 전달 후 WB에서 한 번에 처리 | EX에서 새 CSR 값 계산, WB에서 확정 |
| **추가 자원 (Area)** | WB까지의 CSR 피연산자 전달은 줄일 수 있으나 취소·복구 제어 필요 | CSR 주소·제어·소스 데이터 파이프라인 FF와 WB 선택 경로 추가 | 연산 결과·이전 CSR 값 및 제어의 파이프라인 저장 필요 |
| **타이밍 (Fmax/Slack)** | EX 연산/분기 경로 길어질 수 있음 | WB의 CSR 읽기→연산→쓰기 데이터 경로 부담 | 연산과 쓰기 단계 분리로 경로 분산 가능 |
| **제어 복잡도** | Flush/Trap 취소 시 조기 쓰기 복구 문제 | 명령어의 최종 쓰기 지점을 WB로 모으기 쉬움 | EX 계산 이후 CSR 값 변경이나 연속 CSR 접근 시 우회/재계산 필요 |
| **검증 난이도** | 잘못된 경로의 CSR 쓰기와 복구 확인 필요 | WB 유효성·연속 접근·Trap 중재 확인 필요 | 단계 간 결과 정합성과 의존성 확인 필요 |

**Option A — EX 처리:** 기존 EX Forwarding과 가까워 피연산자 사용이 자연스럽다. 그러나 ADR-002의 분기 판정이 EX인 구조에서 조기 CSR 쓰기와 취소 처리가 맞물리며, Precise Trap 구현 부담이 커진다.

**Option B — WB 처리(선택):** ID에서 명령어를 해독하고 EX에서 최신 rs1을 확보한 후, MEM을 거쳐 WB에서 기존 CSR 값을 읽고 새 값을 계산·저장한다. CSR의 **건축적 상태(architectural state)** 변경을 WB로 늦춰 Flush된 명령어의 부작용을 억제하기 쉽다. 대신 데이터 전달 FF가 늘어나고 CSR의 결과가 늦게 준비되므로 추가 Hazard 제어가 필요하다.

**Option C — EX 계산, WB 쓰기:** 상태 변경은 WB까지 미뤄 복구 부담을 줄이면서 연산 경로를 분산한다. 하지만 EX에서 읽은 CSR 값이 WB 전에 바뀔 수 있어 연속 CSR 접근 시 별도 중재/우회가 필요하다.

> **정량 비교 한계:** 면적, Fmax, Slack, CPI 값은 아직 합성·타이밍 분석·시뮬레이션으로 확인하지 않았다. 표의 내용은 구조별 예상 Trade-off이며 측정 결과가 아니다.

#### 3.2 CSR 연산기와 저장소의 조직 방식

| 비교 항목 | 대안 A: Datapath/ALU에 CSR 로직 통합 | **대안 B: 독립 `CsrOperation` + `CsrRegisterFile` (선택)** |
| :--- | :--- | :--- |
| **구조** | 기존 연산·저장 경로와 CSR 처리 혼합 | CSR 연산과 주소 기반 CSR 저장을 모듈로 분리 |
| **장점** | 일부 기존 제어·MUX 재활용 가능 | 역할과 인터페이스 명확, CSR 단독 테스트 및 Trap 연계 확장 용이 |
| **비용** | ALU/Datapath 결합도 증가, 일반 연산 변경 시 영향 커짐 | 모듈 간 신호 및 선택 경로 증가, CSR 별도 자원 필요 |
| **선택 이유** | — | 일반 정수 연산과 제어·상태 레지스터의 기능을 분리해 검증·유지보수성을 우선 |

현재 `CsrOperation`은 rs1/zimm 선택 후 기존 CSR 값에 대해 WRITE(덮어쓰기), SET(OR), CLEAR(AND NOT)를 수행한다. `CsrRegisterFile`은 주소로 CSR을 선택하여 **조합논리 읽기**, 클럭 엣지에서 **동기식 쓰기**, 일부 CSR 비트 마스킹을 수행한다. 현재 구현에는 읽기 허용(`CsrRdEn`)과 쓰기 허용(`CsrWrEn`)이 구분되어 있다.

#### 3.3 의존성 처리 대안

| 비교 항목 | 대안 A: CSR 전후 모든 명령어 보수적 Stall | **대안 B: 기존 Forwarding 재사용 + 필요한 경우 Stall (적용 방향)** |
| :--- | :--- | :--- |
| **장점** | 정확성 확인이 상대적으로 간단 | 독립 명령어 진행 유지, ADR-003과 데이터 경로 공유 |
| **단점** | 불필요한 성능 저하 | 소스 사용 판정, CSR 결과 준비 시점, 연속 CSR 접근 조건 추가 필요 |
| **적용 방식** | CSR이 안전할 때까지 파이프라인 보류 | CSR의 rs1은 EX의 최신 Forwarding 결과를 사용하고, WB에서야 준비되는 CSR 반환값은 별도 정지/우회 조건 검토 |

ADR-003은 **EX/MEM 우선 → MEM/WB 다음 → 일반 RegisterFile**의 일반 정수 피연산자 선택을 확정했다. ADR-004는 값이 늦게 나오는 Load-use에 대해 **PC와 IF/ID 보류 + ID/EX 버블**을 확정했다. CSR도 그 정책과 정합되어야 하지만, *CSR RAW에 몇 사이클 정지가 필요한지*는 CSR 결과가 WB에서 생성되는 실제 타이밍을 기준으로 별도 검증해야 한다.

### 4. 최종 결정 및 근거 (Decision & Rationale)

- **선택된 안:** ① **WB에서 CSR 읽기·연산·소프트웨어 쓰기 수행**, ② **독립 CSR 연산기/CSR Register File**, ③ 기존 ADR의 Forwarding·Stall·Flush를 CSR에 확장하는 방향.
- **선택 이유:**
  1. **명령어 순서와 상태 변경의 결합:** WB를 CSR 변경 지점으로 삼아, EX에서 판정되는 taken 분기(ADR-002)의 젊은 CSR 명령어를 쓰기 전에 제거할 수 있다.
  2. **기존 5단계 설계 보존:** 일반 ALU/메모리 경로의 대규모 변경 대신 CSR 주소·제어·피연산자만 파이프라인으로 추가한다(ADR-001).
  3. **데이터 최신성 유지:** CSR용 레지스터 피연산자에도 EX Forwarding을 재사용할 수 있어 별도의 ID 우회망을 크게 늘리지 않는다(ADR-003).
  4. **검증과 역할 분리:** `CsrOperation`은 연산만, `CsrRegisterFile`은 상태 보존과 CSR별 허용 비트 처리를 담당한다.
- **감수한 Trade-off:** CSR용 FF/제어 신호와 WB 선택 MUX 증가, 늦은 결과로 인한 CSR 의존성 Stall 가능성, WB의 조합 경로 부담, Trap 하드웨어 쓰기와의 중재 필요.
- **구체 흐름:** IF(명령 인출) → ID(SYSTEM/`funct3` 디코딩, CSR 주소 및 zimm 추출) → EX(일반 rs1 최신값 Forwarding) → MEM(정보 보존·전달) → WB(기존 CSR 읽기 → 새 값 계산 → 허용 시 CSR 쓰기; 기존 CSR 값은 rd로 반환).

> **현행 RTL과 설계 의도 구분:** 현재 설계는 두 CSR 모듈과 WB 연결을 포함하지만, `Datapath.sv`의 정상 ID/EX 갱신에서 `rID_EX_CsrCtrl`이 `iCsrCtrl`이 아니라 `CSR_WRITE`로 고정되어 있다. 그러므로 SET/CLEAR가 설계 의도대로 전달된다고 아직 볼 수 없다. 또한 HazardUnit의 CSR 의존성 조건은 추가 검증이 필요하다. 본 ADR은 **채택한 아키텍처**를 기록하며 구현 완료·검증 통과를 선언하지 않는다.

### 5. 예상 부작용 및 후속 조치 (Consequences & Action Items)

#### 5.1 주의할 코너 케이스

| 상황 | 요구되는 처리 및 검증 포인트 |
| :--- | :--- |
| **Taken Branch 직후의 CSR** | ADR-002에 따라 IF/ID 및 ID/EX의 젊은 CSR 명령어 Flush. `CsrEn`, `CsrWrEn`, 일반 `WrEn_Reg` 등 부작용 신호 무효화 |
| **WB의 CSR + EX의 Branch taken** | Branch보다 오래된 WB CSR은 정상 완료, 젊은 명령어만 취소 |
| **Load → CSR(rs1) 의존성** | ADR-004의 보류·버블 후 EX에서 최신 load 값 확보 |
| **CSR(rd) → ALU/Branch/Store** | CSR 값은 WB에서 반환되므로 기존 ALU Forwarding만으로 충분한지 확인하고 필요 시 CSR 전용 Stall |
| **같은 CSR 연속 WRITE/SET/CLEAR** | 앞선 쓰기가 반영된 CSR 값을 뒤 명령어가 읽는지 확인; 동일 클럭 에지 읽기/쓰기 의미 검증 |
| **CSRRW/CSRRWI, rd=x0** | CSR 읽기 억제, CSR 쓰기는 유지 |
| **CSRRS/CSRRC에서 rs1=x0; CSRRSI/CSRRCI에서 zimm=0** | CSR 읽기는 수행, CSR 쓰기는 억제 |
| **Flush와 Stall 동시 요청** | ADR-002/004에 따라 taken 분기 redirect/flush 우선; 잘못된 CSR 명령어 보존 금지 |
| **외부 인터럽트와 WB CSR 쓰기** | 오래된 CSR 완료 후 Trap 처리 방향을 유지하되, 실제 인터럽트 수락 경계·상태 재평가·쓰기 중재 우선순위 별도 합의 |
| **ECALL 중 앞선/뒤 CSR 명령어** | ECALL보다 오래된 명령어만 완료시키고 젊은 명령어는 취소; ECALL의 `mepc` 기록과 Trap 시점 별도 정의 |
| **CSR 쓰기와 Trap의 mstatus/mepc/mcause 갱신** | 소프트웨어 CSR 쓰기 포트와 Trap 하드웨어 갱신의 충돌 중재 필요. 현행 Register File에 Trap 쓰기 포트가 구현됐다고 가정하지 않음 |
| **지원하지 않는 CSR 주소·미지원 SYSTEM 인코딩** | 조용히 무시하는 정책의 적절성 및 향후 illegal-instruction 예외 처리 범위 확정 필요 |

#### 5.2 검증 계획

1. **기본 기능:** 6개 CSR 명령어의 WRITE/SET/CLEAR 및 rd 반환값, 레지스터형/즉시값형, 0 필드 특례 확인.
2. **연산기·레지스터 파일 단위 검증:** 비트 마스크(`mstatus`, `mie` 등), 정렬(`mtvec`, `mepc`), 리셋, 읽기 허용/쓰기 허용 분리 확인.
3. **일반 레지스터 의존성:** `ALU→CSR`, `LW→CSR`, `CSR→ALU`, `CSR→Branch`, `CSR→Store`의 소스 값 및 정지 횟수 확인.
4. **CSR 간 의존성:** 같은 주소에 대한 연속 SET/CLEAR/WRITE로 최종 CSR 값과 rd에 반환된 이전 값 비교.
5. **제어 해저드:** taken 분기의 CSR Flush, Branch와 Load-use Stall 동시 발생, 버블의 CSR/일반 레지스터 쓰기 비활성 확인.
6. **Trap 연동(후속):** 외부 인터럽트/ECALL의 정확한 명령어 경계, 오래된 CSR 쓰기 완료, 젊은 명령어 취소, `mepc/mcause/mstatus` 갱신 순서 확인.
7. **PPA(후속):** 합성 후 FF/LUT 및 타이밍(Fmax/Slack)을 비교해 본 문서의 정성적 비용 평가를 갱신.

#### 5.3 별도 결정이 필요한 항목

- **Trap Detection/Acceptance/Entry** 단계와 Precise Trap을 위한 파이프라인 배출(Drain)·Flush 범위
- **Trap 하드웨어의 CSR 갱신 인터페이스** 및 동일 CSR에 대한 소프트웨어/하드웨어 쓰기 우선순위
- **CSR 결과 RAW에 필요한 Stall 길이**, 연속 CSR 접근의 유효한 우회/대기 정책
- **CSR 지원 범위**(`mip`, `mtval`, 쓰기 가능 비트 등)와 미지원 CSR 접근 시 예외 정책

---

**관련 문서 근거:** ADR-001의 파이프라인 채택 및 순차 실행 의미, ADR-002의 EX 분기 및 Flush, ADR-003의 Forwarding 우선순위와 WB→ID 우회, ADR-004의 Load-use 보류·버블/분기 우선 정책을 전제로 작성하였다. 기존 ADR에서 정하지 않은 CSR·Trap 세부사항은 본 문서에서 *설계 선택* 또는 *후속 결정*으로 구분한다.
