# Harness Agent Learning Data

이 폴더는 harness 의 6개 도우미(agent)가 작업하며 축적한 학습을 저장한다.
각 도우미는 자기 이름의 `.md` 파일을 가진다 (예: `harness-planner.md`).

## 저장 위치 (Hybrid)

- **공용 (이 폴더)**: `~/.claude/skills/harness/agents/learning/<agent>.md`
  - 모든 프로젝트가 공유. 언어/프레임워크 무관한 일반 원칙.
- **프로젝트 (개별)**: `<PROJECT>/.harness/agents/learning/<agent>.md`
  - 그 프로젝트에서만 해당하는 로컬 컨벤션.

**로드 순서**: 공용 먼저 → 프로젝트로 덮어쓰기 (프로젝트가 이김).

## 파일 구조 (고정 5섹션)

```markdown
# Learning Data: <agent-name>

> Schema 1.0. dated entries only. add/update/delete via main loop (Claude).
> Max 800 lines. Over limit → /harness-distill <agent>.

## Principles
범용 원칙. 거의 안 바뀜.

## Patterns
잘 통하는 접근법.

## Anti-patterns
하면 안 되는 것.

## Project-Specific
프로젝트별 컨벤션. 공용 파일에는 비어 있음.

## Open Questions
아직 결론 안 난 것. distill 시 결론 났으면 Patterns/Anti-patterns 로 이동.
```

각 항목 형식:
```
- [YYYY-MM-DD] 1~2 문장 요약. (출처: REQUEST_ID 또는 general)
```

## 갱신 방식 (제안 → 승인)

1. 도우미가 작업 끝낼 때 응답 끝에 **## Learning Proposals** 섹션 출력.
2. 메인 Claude(대장) 가 이를 받아 검증:
   - 중복 확인 (grep)
   - 모순 확인 (Codex critique 호출)
   - 형식 검증 (날짜 태그, 섹션 존재)
   - 사이즈 캡 (800줄) 확인
3. OK 면 Edit 으로 learning 파일 갱신.
4. progress-<id>.md 에 diff 기록 (audit trail).

도우미가 직접 learning 파일을 쓰지 않는다. 항상 대장이 게이트.

## Learning Proposal 표준 형식

```markdown
## Learning Proposals

### Add
- **section**: Patterns | Anti-patterns | Principles | Project-Specific | Open Questions
- **entry**: [YYYY-MM-DD] 내용.
- **evidence**: REQUEST_ID 또는 출처.

### Update
- **section**: ...
- **old**: 기존 entry 그대로.
- **new**: 수정된 entry.

### Delete
- **section**: ...
- **entry**: 삭제할 entry 그대로.
- **reason**: 왜 지우는지.
```

Add/Update/Delete 중 필요한 것만 출력. 제안 없으면 섹션 자체 생략.

## 사이즈 관리

- 캡: 파일당 800 lines.
- 초과 시: 대장이 "✋ 800줄 초과. `/harness-distill <agent>` 실행 권고" 메시지.
- distill: 같은 카테고리 entry 통합 + 오래된 항목 정리.

## Git Tracking

- 공용 (이 폴더): HarnessRepo 에 push. 다른 컴퓨터/사용자와 학습 공유.
- 프로젝트 (`<PROJECT>/.harness/agents/learning/`): gitignore. 프로젝트별 격리.
- **민감 정보 주의**: 공용 learning 에 비밀번호/내부 URL/회사명 같은 것 절대 금지.
  대장이 검증 단계에서 "민감 정보 의심" 패턴 차단.
