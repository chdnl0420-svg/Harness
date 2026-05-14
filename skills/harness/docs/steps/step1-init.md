# step1. harness 초기화

1. **REQUEST_ID 생성** — slug 형식 (예: `jwt-middleware`). 중복 시 숫자 추가.
2. **`.harness/` 폴더 보장** — 마스터(`~/.claude/skills/harness/`) 의 `core/`, `wrappers/` 폴더를 프로젝트 `.harness/` 로 복사. 그 안에서 구동.
3. 마스터의 `core/`, `wrappers/` 내용과 프로젝트의 `.harness/` 내용이 일치하는지 확인. 불일치 시 마스터로 덮어쓰기.
4. **`--noagent` 플래그 처리** — 사용자 입력에 `--noagent` 가 포함되어 있으면 `.harness/.noagent` 빈 파일을 생성, 포함되어 있지 않으면 기존 파일이 있어도 **삭제**해 모드를 호출별로 깨끗하게 초기화한다. 이후 step 들은 매번 이 파일 존재 여부만 보고 모드 분기.
