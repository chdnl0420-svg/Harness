# step3. 구현 계획 (Chunks 모드 지원)

**산출물** (Chunks 임계값에 따라 둘 중 하나):
- **단일 모드** (임계값 미만): `implementation-<slug>.html` 파일 하나 (기존 동작)
- **Chunks 모드** (임계값 이상): `implementation-<slug>-chunks-overview.html` (분해 개요) + `implementation-<slug>-chunk-<N>.html` (각 chunk 별 상세 plan)

**입력 게이트 (skip 금지)**:
- `.harness/domain-<slug>.html` 전문을 **반드시 다시 읽어** 메인 컨텍스트에 올린다 ("step2 에서 만들었으니 기억" 으로 넘기지 않는다).
- 도메인 파일이 없거나 비어 있으면 step2 로 되돌린다.
- 도메인 파일의 **DDD 도메인 모델** 섹션을 확인한다. 공통 업무 언어, bounded context, aggregate/invariant 판단, context map 이 없으면 step2 로 되돌린다.
- **모드 판정 (CRITICAL — 본 step 첫 진입 시 1회만)**: 도메인 plan 의 *Chunks 임계값* 확인 후 모드 결정. 자세히는 아래 "Chunks 분해 절차" 참조.
- **회송 진입 모드 감지 (CRITICAL)**: 다음 둘 중 하나가 참이면 *회송 진입 모드*. 이 경우 아래 "회송 진입 모드 절차" 를 따른다 (최초 진입 절차와 다름).
  - `.harness/reviews/review-<slug>.md` 의 마지막 회차가 `LGTM: NO`
  - `.harness/results/qa-<slug>.md` 의 마지막 회차가 `FAIL`
  - Chunks 모드면 회송은 *현 chunk 의 implementation plan* 만 재작성 (다른 chunk 영향 없음).

## 회송 진입 모드 절차 (CRITICAL — no-op 회송 차단)

회송 진입 모드면 일반 절차 전에 다음을 **반드시 수행**한다. 누락하면 step4 가 직전 회차와 동일한 plan 으로 재실행 → 무한 루프 또는 자체 수정 우회.

1. **직전 결함 본문 Read** — 회송 트리거에 따라:
   - LGTM:NO 회송: `.harness/review-<slug>.md` 의 마지막 `## Run #<N>` 섹션 전문
   - FAIL 회송: `.harness/results/qa-<slug>.md` 의 마지막 FAIL 회차 섹션 전문
2. **plan skill 호출 prompt 에 prepend** — 일반 절차의 prompt 앞에 다음 양식으로 직전 결함 prepend (workflow.md "회송 시 결함 전달 양식" 참조):

```markdown
### 직전 결함 (회송 진입 입력 — 이번 plan 에 반드시 반영)

**회송 트리거**: step5 LGTM:NO | step6 FAIL
**직전 회차 번호**: <N>
**판정 근거 (직전 회차에서 인용)**:
> <review/qa 파일에서 라벨이 등장한 줄 인용>

**결함 항목** (모두 본 plan 의 변경 대상에 명시적으로 반영해야 함):
- <항목 1: 파일경로 / 유형 / 설명>
- <항목 2: ...>
- ...

**금지**: 직전 회차와 동일한 plan 본문을 재생성하지 말 것. 위 결함 항목이 plan 의 "변경 대상 파일 목록" / "단계별 구현 순서" 에 실제 차이로 반영되어야 step4 진입 가능.
```

3. **implementation-<slug>.html 수정 이력 섹션 강제** — 회송 모드에서는 새 plan 작성 후 `implementation-<slug>.html` 끝에 다음 섹션을 누적 append:

```markdown
## 수정 이력
### Revision #<N> — <날짜·시간>
- 회송 트리거: step5 LGTM:NO | step6 FAIL @ Run #<N>
- 반영한 결함 항목: <목록>
- 변경 요약: <plan 의 어떤 부분이 바뀌었는지 한 줄씩>
```

4. **변경분 검증 게이트** — 새 plan 의 "변경 대상 파일 목록" / "단계별 구현 순서" 가 직전 회차와 *바이트 단위로 동일* 하면 회송 무효 — step3 다시 수행 또는 사용자 결정 요청. *no-op 회송 차단의 마지막 방어선.*

**흐름**:
1. **코드베이스 사전 탐색 (필수)** — `plan` skill 호출 전에 메인 Claude 가 직접 수행:
   - 도메인 설계의 *영향 영역* 에 해당하는 기존 파일 식별 (Glob/Grep)
   - 변경될 인터페이스·데이터 구조·의존성 목록화
   - 이미 존재하는 비슷한 패턴(naming, layout, error handling) 확인
   - 기존 코드의 업무 용어가 step2 의 **공통 업무 언어** 와 일치하는지 확인
   - 현재 모듈·레이어·서비스 경계가 step2 의 **bounded context** 와 어떻게 맞거나 어긋나는지 정리
   - persistence / transaction / validation / event 처리 위치를 찾아 aggregate·invariant 후보와 연결
   - 결과는 `.harness/implementation-<slug>.html` 작성 시 *"기존 코드 영향 영역"* 과 *"DDD 코드베이스 매핑"* 섹션으로 반영
   - 탐색 없이 plan 만 만들면 step4 에서 추측 코딩 → 리뷰 fail → step3 무한 루프
2. **코드베이스 설계 리서치 (필수)** — 외부 리서치와 로컬 탐색을 분리해 둘 다 판단한다:
   - **로컬 코드베이스 리서치**: `rg --files`, `rg`, 관련 문서(`docs/ARCHITECTURE.md`, `docs/ADR.md`, `CLAUDE.md`, `README*`)를 읽고 현재 설계의 실제 경계를 확인한다.
   - **외부 딥 리서치**: DDD 전술 패턴, Clean Architecture, 의존성 역전, migration / anti-corruption boundary 판단이 구현 구조에 영향을 주면 `harness-deep-researcher` 를 호출한다.
   - 결과는 implementation plan 의 *"코드베이스 설계 리서치"* 섹션에 남긴다. 단순 작업이라 외부 리서치가 필요 없더라도 *"로컬 코드베이스 리서치 완료 — DDD 목표 구조 적용 경로 확인"* 을 쓴다.
3. **(필요 시) 외부 리서치 — `harness-deep-researcher` 위임** — 다음 중 하나라도 해당하면 plan skill 호출 전에 리서치 실시:
   - 도입할 라이브러리·API 사용법이 학습 데이터 cutoff 이후 변경된 영역
   - 마이그레이션 비용 / breaking change 영향 평가가 필요
   - 보안 권고(OWASP/NIST/CVE) 가 구현 결정에 직접 영향
   - 도메인 단계의 *"외부 의존성: 조사 필요"* 항목이 미해결로 남음
   - DDD 모델의 bounded context / aggregate / domain event / anti-corruption boundary 를 코드 구조로 옮기는 방식이 불명확함
   - 위임 방식·산출물 양식은 [harness-plan SKILL.md Phase 2](../../../harness-plan/SKILL.md) 와 동일 (Topic / Tier / Context / 조사 일자 필드 + `.harness/research/research-<slug>-<NN>-<topic>.md` 저장).
   - 위임 prompt 는 **[Learning Prepend 계약](../workflow.md#critical-learning-prepend-계약-모든-harness--agent-공통) 1·2·3·4 단계 수행 필수** — `harness-deep-researcher.md` 공용 학습 파일 Read 후 `## Prior Learning (READ FIRST — DO NOT SKIP)` 헤더로 prepend. 누락 시 도우미가 `[BLOCKED]` 로 거부. (2026-05-20: 프로젝트 learning 폐기 — 공용만 prepend.)
   - 불필요하면 *"리서치 필요 없음 — 사유: …"* 한 줄 기록.
4. **DDD → 코드 매핑 게이트** — `plan` skill 호출 전에 다음 결정을 명시한다:
   - 이번 변경이 속한 bounded context 와 건드리면 안 되는 인접 context
   - aggregate root 또는 기존 transaction boundary 를 바꿀지 여부
   - 새 domain event / integration event 가 필요한지 여부
   - 외부 모델이 들어오면 anti-corruption boundary 를 어디에 둘지
   - 기존 구조와 DDD 이상형이 충돌할 때의 적용 순서. 기본값은 **DDD 목표 구조 우선 + 단계적 마이그레이션**.
   - DDD 목표 구조에 필요한 새 계층·모듈·폴더·인터페이스가 있으면 명시적으로 추가한다.
5. `plan` skill 호출 (Skill tool, skill="plan") — 메인 Claude 가 직접 수행. 2~3번 리서치 결과 파일과 4번 DDD 매핑 결정을 plan prompt 의 *"참고 자료"* 로 prepend.
6. **(필요 시) 시스템 차원 검토 — `architect` agent 호출** — 다음 중 하나라도 해당하면 plan 본문 완성 후 Codex 리뷰 *전에* 시스템 차원 검토를 거친다:
   - 새 모듈·경계·인터페이스가 도입됨 (기존 계층 구조에 새 layer 추가)
   - 둘 이상의 서비스·프로세스·외부 API 간 통신 경로가 신설됨
   - 데이터 모델·스키마 변경이 다른 코드 영역으로 파급
   - 동시성·트랜잭션·캐싱 같은 시스템 차원 결정이 plan 에 포함
   - bounded context 분리, aggregate 경계 변경, domain event 도입, anti-corruption layer 추가가 plan 에 포함
   - 호출 방식: `Task` 도구 `subagent_type="architect"`. 입력은 `implementation-<slug>.html` 본문 + 도메인 plan 본문. 응답은 *경계·일관성·확장성* 관점 권고. 반영 후 Codex 리뷰로.
   - 결과는 `implementation-<slug>.html` 의 *"시스템 차원 검토"* 섹션으로 누적.
7. skill 결과를 Codex 가 리뷰
8. 리뷰 결과를 메인 Claude 가 검토 / 반영
9. **모드별 파일 작성 분기**:
   - **단일 모드**: `implementation-<slug>.html` 작성 → step4 로 (1 회만)
   - **Chunks 모드**: 아래 "Chunks 분해 절차" 의 4단계 수행 → 첫 chunk 의 step4 로 진입 → chunk loop 시작
10. **DDD 코드베이스 검증 실행** — implementation 파일 작성 직후 다음 검증기를 실행한다. 실패하면 step4 진입 금지, 누락 섹션을 보강한 뒤 재실행한다.
   ```bash
   python ~/.codex/skills/harness/core/validate-ddd-codebase.py --skill-root ~/.codex/skills/harness --project <PROJECT_ROOT> --slug <slug> --require-artifacts
   ```
   Windows 경로에서는 같은 스크립트를 `python C:\Users\<USER>\.codex\skills\harness\core\validate-ddd-codebase.py --skill-root C:\Users\<USER>\.codex\skills\harness --project <PROJECT_ROOT> --slug <slug> --require-artifacts` 형태로 실행한다.

**필수 산출 섹션** (`implementation-<slug>.html` 에 반드시 들어가야 함):
- **변경 대상 파일 목록** — 수정/신규 구분, 절대 경로
- **기존 코드 영향 영역** — 1번 탐색 결과
- **코드베이스 설계 리서치** — 로컬 구조 분석 + 외부 딥 리서치 수행 여부 + 참고 research 파일
- **DDD 코드베이스 매핑** — bounded context, aggregate/invariant, application service, repository/adapter boundary, domain event, anti-corruption boundary 를 실제 모듈·파일·테스트로 어떻게 옮길지
- **DDD 마이그레이션 계획** — 기존 구조와 DDD 목표 구조의 차이, 새 경계·계층·모듈 추가 순서, rollback 경로
- **단계별 구현 순서** — 각 단계의 *입력 / 작업 / 검증 방법* 3축
- **테스트 전략** — 어떤 레벨(unit/integration/e2e) 로 무엇을 검증
- **위험·롤백 경로** — 실패 시 되돌리는 방법

위 8개 섹션 중 하나라도 비어 있으면 step4 진입 금지. 누락된 섹션은 plan skill 재호출 또는 메인이 직접 채운다.

**제약**:
- plan 본문에 *"적절히"*, *"필요시"*, *"어떻게든"* 같은 모호어 등장 시 step4 가 추측 코딩으로 빠진다. 발견되면 구체화 후 진행.
- domain 설계에 없는 기능을 plan 에 임의로 추가 금지. 추가가 필요하면 step2 로 되돌린다.
- DDD 목표 구조와 기존 코드베이스가 맞지 않으면 DDD 목표 구조를 우선한다. 변경 폭이 커지면 Chunks 모드로 나누고, migration/rollback 을 명시한 뒤 진행한다.

---

## 외부 리서치 호출 — Single Source (2026-05-20 정합화)

step3 의 *외부 리서치* 분기 (라이브러리 비교·최신 모범 사례·보안 권고·API 마이그레이션 등 필요 시) 는 [`docs/procedures/deep-research-procedure.md`](../procedures/deep-research-procedure.md) 의 5단계 흐름을 따른다. 다음 3가지 어댑터 중 하나로 위임 (셋 다 동일 procedure):

- `harness-deep-researcher` skill (`Skill` 도구) — workflow 안에서 권장
- `harness-deep-researcher` agent (`Task` 도구) — subagent 별도 컨텍스트
- `/harness-deep-researcher` slash (사용자 진입점 — workflow 내부에선 사용 안 함)

(2026-05-20: `.harness/.noagent` 폐기. `harness-deep-researcher` skill 또는 동명 agent 호출 — 본 워크플로우는 Skill 도구 호출이 기본.)

---

## Chunks 분해 절차 (CRITICAL — 2026-05-20 신규)

큰 도메인 plan 을 *작은 vertical slice* 로 쪼개 step4→5→6 사이클을 chunk 별로 반복하는 모드. 사용자가 *작은 작업* 부담을 피하면서 *큰 작업* 의 변경량을 관리 가능한 단위로 분할.

### Step 1: 임계값 판정 (단일 모드 vs Chunks 모드)

도메인 plan 의 다음 신호를 종합 판단해 **임계값 통과** 여부 결정:

| 신호 | 임계값 (이상이면 Chunks 모드) |
|------|---------------------------|
| 핵심 사용자 시나리오 (도메인 문서의 *"핵심 사용자 시나리오"* 섹션 항목 수) | **3개 이상** |
| 변경 대상 파일 수 (사전 탐색 결과) | **5개 이상** |
| 의존성 레이어 수 (data → API → UI 같은 수직 깊이) | **2개 이상** |
| UX 변경 시나리오 수 (UX 카테고리 *"변경 대상 화면·요소"* 항목 수) | **2개 이상** |

위 4개 신호 중 **2개 이상이 임계값 통과** 하면 Chunks 모드. 그 외는 단일 모드 (기존 동작).

판정 결과를 `progress-<slug>.html` 의 *진행 상태* 카드에 1줄 기록:
```
mode: single | chunks (chunks=N, 분해 사유: <어떤 신호 어떤 값>)
```

### Step 2: Chunks 분해 (메인 Claude 자동 — Chunks 모드일 때만)

도메인 plan 을 *vertical slice* 단위로 분해. 각 chunk 는 다음 원칙을 따른다:

- **vertical slice**: 1 chunk = 1 사용자 시나리오의 끝까지 (data → API → UI 한 줄 다 포함). horizontal layer 분리 금지.
- **의존성 순서**: chunk i+1 은 chunk i 의 산출물에 의존 가능 (역방향 금지).
- **크기**: 1 chunk 의 예상 변경량 ≤ 400 LOC 또는 ≤ 5 파일 (어느 쪽 먼저 도달).
- **독립 가능성**: 1 chunk 만으로 *부분 동작 가능* 한 단위 (절반 만든 기능 X — 완성된 1개 시나리오).

### Step 3: chunks-overview 파일 작성

`.harness/implementation-<slug>-chunks-overview.html` 생성. 양식:

| 컬럼 | 내용 |
|------|------|
| chunk_id | `chunk-1`, `chunk-2`, ... |
| title | 1줄 제목 (사용자 시나리오 한 줄) |
| 의존 chunks | 이 chunk 가 의존하는 chunk_id 목록 |
| 변경 대상 파일 | 예상 파일 경로 목록 |
| DDD 코드베이스 매핑 | bounded context / aggregate·invariant / application service / repository·adapter boundary / domain event / anti-corruption boundary 중 이 chunk 가 다루는 항목 |
| DDD 마이그레이션 계획 | 기존 구조에서 DDD 목표 구조로 옮기는 순서와 rollback 기준 |
| 성공 기준 | 이 chunk 완료 시 *관찰 가능한 결과* 1줄 |
| 상태 | `pending` / `in-progress` / `done` / `paused` |

분해 사유, DDD 적용 요약, 의존성 그래프 (가능하면 ASCII 박스 또는 inline SVG) 도 포함. `chunks-overview` 는 요약 산출물이므로 chunk 별 상세 구현 plan 을 대체하지 않는다.

### Step 4: 첫 chunk 의 implementation plan 작성

`chunk-1` (의존성 없는 가장 첫 chunk) 의 `.harness/implementation-<slug>-chunk-1.html` 작성. 양식은 단일 모드의 *필수 산출 섹션 8개 전체* 그대로. 즉 변경 대상 파일 목록 / 기존 코드 영향 영역 / 코드베이스 설계 리서치 / DDD 코드베이스 매핑 / DDD 마이그레이션 계획 / 단계별 구현 순서 / 테스트 전략 / 위험·롤백 경로를 모두 포함한다. 단 *해당 chunk 범위* 로만 한정한다.

### Chunk Loop 동작 (step4~6 의 사이클)

step4 진입 후 다음 자동 흐름:

```
chunk_i = 1
while chunk_i ≤ N:
  step4 (chunk_i 의 implementation plan 만 본다) →
  step5 (chunk_i 만 리뷰) →
    LGTM:NO → 본 step3 의 회송 진입 모드 (chunk_i 의 plan 재작성, 다른 chunk 영향 없음) → step4 (chunk_i)
    LGTM:YES → step6 →
      FAIL → 본 step3 의 회송 진입 모드 (chunk_i 한정) → step4 (chunk_i)
      PASS →
        chunk_i 의 git commit 자동 (incremental delivery — step8 commit 절차 따름)
        chunks-overview 의 chunk_i 상태 `done` 으로 갱신
        if chunk_i == N: → step7 (전체 production install 테스트, 1회만)
        else: chunk_i += 1, step3 의 Step 4 (다음 chunk 의 plan 작성) → step4 진입
```

chunk 사이 전환은 **noask 정신상 자동** (사용자 결정 불필요). 다음 chunk 의 plan 작성 시 *이전 chunk 의 산출물* 을 *기존 코드 영향 영역* 에 포함해 의존성 흐름 유지.

### 회송 카운터 (chunk 별 독립)

- 각 chunk 의 step5 LGTM:NO 누적 카운터 / step6 FAIL 누적 카운터는 **chunk 별 독립**. 각 chunk 안에서 *동일 문제·결함이 5회 반복* 될 때만 게이트 발동 (서로 다른 문제로 5회 누적은 정상 진행).
- 한 chunk 에서 *동일* 문제·결함이 5회 초과 시 워크플로우 *전체* 자동 중단 (다른 chunk 도 정지). report 에 *"chunk-N 의 동일 문제 5회 반복 — 전체 워크플로우 자동 중단"* 기록. 동일성 판정 = `(유형 enum, 파일경로 normalized)` 튜플 일치.

### 산출물 경로 정리

```
.harness/
├── domain-<slug>.html                            (step2)
├── implementation-<slug>-chunks-overview.html    (chunks 모드 — 분해 개요)
├── implementation-<slug>-chunk-1.html            (chunks 모드 — chunk 1 plan)
├── implementation-<slug>-chunk-2.html            ...
├── implementation-<slug>.html                    (단일 모드 — chunks 모드와 상호 배타)
├── reviews/review-<slug>-chunk-<N>.md            (chunks 모드 — chunk 별 리뷰)
├── results/qa-<slug>-chunk-<N>.md                (chunks 모드 — chunk 별 QA)
└── progress/progress-<slug>.html                 (전체 + chunks 진행 상태)
```

단일 모드는 *chunk 접미사 없음* — 기존 그대로.
