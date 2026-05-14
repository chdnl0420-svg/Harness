# step6. QA 테스트

**산출물**:
- `.harness/test-guide-<slug>.md` (테스트 가이드 — 작성/갱신)
- `.harness/results/qa-<slug>.md` (QA 보고서 — 회차 누적)

**흐름**:
1. **테스트 가이드 작성/갱신** (메인 Claude 직접 작성) — 양식·재료·갱신 규칙은 [../test-guide-format.md](../test-guide-format.md) 참조
   - 최초 진입 시: 새로 작성
   - 재진입 시 (step3 루프 후): 변경된 사양/구현 반영해 갱신
   - 가이드 없이는 절대 테스트 시작 금지
2. `harness-qa-engineer` 에 위임 (prior learning + **test-guide-<slug>.md 전문** prepend)
3. 도우미가 가이드 기능 목록 순서대로 스크린샷 + 클릭 기반 시나리오 실행
   - MCP 브라우저 도구 (`mcp__Claude_in_Chrome__*`, `mcp__Claude_Preview__*`) 우선
   - 없으면 프로젝트의 기존 Playwright/Puppeteer 스크립트만 호출 (신규 스크립트 작성 금지)
   - 자동화 도구 전부 없으면 → "수동 테스트 필요" 보고 후 사용자 결정 요청
4. 보고서에서 최종 판정 추출: **PASS / FAIL / BLOCKED**
5. 분기:
   - **PASS** → step7 로 진행
   - **FAIL** → step3 (구현 계획 수정) 로 되돌림
     - 동일 결함이 5회 반복되면 중단 + 사용자에게 알림
   - **BLOCKED** (테스트 자체 불가) → 사용자에게 원인 보고 후 결정 요청

**제약**:
- QA 도우미는 보고서·스크린샷 외 어떤 파일도 수정·생성하지 않음 (가이드 작성은 메인 Claude 가 담당)
- 버그를 직접 고치지 않음 — step3 루프에서 다른 도우미가 처리
