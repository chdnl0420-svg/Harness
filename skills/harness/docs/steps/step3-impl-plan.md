# step3. 구현 계획

**산출물**: `implementation-<slug>.md` 파일 하나

**입력 게이트 (skip 금지)**:
- `.harness/domain-<slug>.md` 전문을 **반드시 다시 읽어** 메인 컨텍스트에 올린다 ("step2 에서 만들었으니 기억" 으로 넘기지 않는다).
- 도메인 파일이 없거나 비어 있으면 step2 로 되돌린다.

**흐름**:
1. **코드베이스 사전 탐색 (필수)** — `plan` skill 호출 전에 메인 Claude 가 직접 수행:
   - 도메인 설계의 *영향 영역* 에 해당하는 기존 파일 식별 (Glob/Grep)
   - 변경될 인터페이스·데이터 구조·의존성 목록화
   - 이미 존재하는 비슷한 패턴(naming, layout, error handling) 확인
   - 결과는 `.harness/implementation-<slug>.md` 작성 시 *"기존 코드 영향 영역"* 섹션으로 반영
   - 탐색 없이 plan 만 만들면 step4 에서 추측 코딩 → 리뷰 fail → step3 무한 루프
2. **(필요 시) 외부 리서치 — `harness-deep-researcher` 위임** — 다음 중 하나라도 해당하면 plan skill 호출 전에 리서치 실시:
   - 도입할 라이브러리·API 사용법이 학습 데이터 cutoff 이후 변경된 영역
   - 마이그레이션 비용 / breaking change 영향 평가가 필요
   - 보안 권고(OWASP/NIST/CVE) 가 구현 결정에 직접 영향
   - 도메인 단계의 *"외부 의존성: 조사 필요"* 항목이 미해결로 남음
   - 위임 방식·산출물 양식은 [harness-plan SKILL.md Phase 2](../../../harness-plan/SKILL.md) 와 동일 (Topic / Tier / Context / 조사 일자 필드 + `.harness/research/research-<slug>-<NN>-<topic>.md` 저장).
   - `.harness/.noagent` 있으면 메인 Claude 직접 (동일 환각 차단 4규칙 적용).
   - 불필요하면 *"리서치 필요 없음 — 사유: …"* 한 줄 기록.
3. `plan` skill 호출 (Skill tool, skill="plan") — 메인 Claude 가 직접 수행. 2번 리서치 결과 파일은 plan prompt 의 *"참고 자료"* 로 prepend.
4. skill 결과를 Codex 가 리뷰
5. 리뷰 결과를 메인 Claude 가 검토 / 반영
6. 파일 작성 → step4 로

**필수 산출 섹션** (`implementation-<slug>.md` 에 반드시 들어가야 함):
- **변경 대상 파일 목록** — 수정/신규 구분, 절대 경로
- **기존 코드 영향 영역** — 1번 탐색 결과
- **단계별 구현 순서** — 각 단계의 *입력 / 작업 / 검증 방법* 3축
- **테스트 전략** — 어떤 레벨(unit/integration/e2e) 로 무엇을 검증
- **위험·롤백 경로** — 실패 시 되돌리는 방법

위 5개 섹션 중 하나라도 비어 있으면 step4 진입 금지. 누락된 섹션은 plan skill 재호출 또는 메인이 직접 채운다.

**제약**:
- plan 본문에 *"적절히"*, *"필요시"*, *"어떻게든"* 같은 모호어 등장 시 step4 가 추측 코딩으로 빠진다. 발견되면 구체화 후 진행.
- domain 설계에 없는 기능을 plan 에 임의로 추가 금지. 추가가 필요하면 step2 로 되돌린다.
