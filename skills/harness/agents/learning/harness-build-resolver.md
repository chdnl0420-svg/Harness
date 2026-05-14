# Learning Data: harness-build-resolver

> Schema 1.0. dated entries only (`[YYYY-MM-DD]` 태그 필수).
> add/update/delete 는 메인 Claude 가 검증 후 반영.
> Max 800 lines. 초과 시 `/harness-distill harness-build-resolver` 권고.

## Principles
범용 원칙. 거의 안 바뀜.

- [2026-05-14] npm peer dependency 충돌 시 `--legacy-peer-deps` 대신 `package.json` 의 `overrides` 필드에 1줄 핀 버전 추가가 재현 가능한 최소 외과적 수정. pnpm 은 `pnpm.overrides` 또는 `pnpm.peerDependencyRules`, peer dep 자체 override 는 `.pnpmfile.cjs` Hook 만 가능. 근거: npm-cli overrides 문서; pnpm overrides 가이드.
- [2026-05-14] CI 는 반드시 `npm ci` (또는 `pnpm install --frozen-lockfile`) 사용해야 lockfile 불변. 로컬-CI lockfile out-of-sync 보고 시 로컬에서 `npm install` 한 번 더 실행해 lockfile 정규화 후 커밋이 단계 최소. 근거: npm ci 공식 문서.
- [2026-05-14] (training) 빌드 에러는 첫 줄만 본다. cascading 으로 N+1 ~ N+M 의 후속 에러는 첫 에러 해결 후 다수가 자동 소멸. 전체 로그 길이에 압도되어 중간 라인부터 손대면 시간 낭비. 근거: TypeScript 컴파일러 에러 모델; rustc 진단 가이드.
- [2026-05-14] (training) "재현 가능한 빌드" 가 최우선. 같은 commit + 같은 lockfile + 같은 Node 마이너 버전에서 결과가 다르면 캐시·환경 변수·플랫폼 차이 셋 중 하나. `docker run` 등 격리 환경에서 재현되지 않으면 환경 문제로 분류. 근거: Reproducible Builds 프로젝트; npm scripts 가이드.

## Patterns
잘 통하는 접근법.

- [2026-05-14] Node v20.19.0+ / v22.12.0+ 에서 `require(esm)` stable(unflagged) 전환. CJS 코드베이스가 ESM-only 라이브러리 import 실패 시 Node 버전 업그레이드 또는 동적 `await import()` wrapping 이 `"type":"module"` 전환보다 영향 범위 작음. 근거: joyeecheung blog 2025 "require(esm) 안정화".
- [2026-05-14] TypeScript `"moduleResolution": "node16"` / `"nodenext"` 는 상대 import 에 `.js` 확장자 필수. 번들러 기반 프로젝트 (Vite 등) 는 `"bundler"` 로 설정해야 TS2835/TS2307 해결. `verbatimModuleSyntax` 활성 시 `import type { Foo }` 명시. 근거: TypeScript Handbook "Modules - Choosing Compiler Options".
- [2026-05-14] `.tsbuildinfo` stale 캐시로 `tsc --build` 가 변경 없이 에러 반복 / 재빌드 건너뜀 → 해당 `.tsbuildinfo` 만 삭제 후 재빌드가 최소 수정. `node_modules` 전체 삭제나 `npm ci` 불필요. 근거: TypeScript incremental 옵션 문서; GitHub Issue #54501.
- [2026-05-14] (training) 빌드 에러 메시지에서 패키지명+버전+에러 종류 3축으로 GitHub Issues / Stack Overflow 검색 → 최근 1년 내 동일 보고 우선. 8할 이상은 이미 해결책이 있다. 근거: Stack Overflow Developer Survey 2024.
- [2026-05-14] (training) ESLint flat config (`eslint.config.js`) 와 legacy `.eslintrc` 동시 존재 시 ESLint v9+ 는 flat 만 인식. 마이그레이션 중간 상태에서 "왜 룰이 안 먹혀" 가 흔함. 한 파일만 남기는 게 정답. 근거: ESLint 공식 마이그레이션 가이드.

## Anti-patterns
하면 안 되는 것.

- [2026-05-14] 빌드 오류 첫 반응으로 `node_modules` 삭제 + `npm cache clean --force` 실행은 캐시 상태가 실제 원인일 때만 유효. 대부분 수 분 시간 낭비. 먼저 오류 메시지에서 패키지 이름/버전/경로 읽고 원인 (lockfile 불일치, peer dep 충돌, 타입 불일치) 특정 후 해당 파일/설정 1곳만 수정. 근거: npm cache 공식 문서.
- [2026-05-14] Windows `node-gyp` 빌드 실패 시 `windows-build-tools` 전역 설치 (deprecated) 사용 금지. 현재 권장: VS 2022 "Desktop development with C++" 워크로드 + `npm config set python C:\path\to\python3.exe` 핀. 네이티브 모듈 필수 아니면 순수 JS 대체 (`bcrypt` → `bcryptjs`) 가 장기 유지보수 비용 낮음. 근거: node-gyp v10+ Windows 트러블슈팅.
- [2026-05-14] (training) `npm install --force` / `--legacy-peer-deps` 로 peer dep 충돌 무시 = 런타임 에러로 미루기. CI 는 통과해도 production 에서 두 버전 동시 로드로 인한 instanceof 실패·싱글톤 분기. `overrides` 또는 버전 정렬이 정답. 근거: npm peerDependencies 가이드.
- [2026-05-14] (training) `package-lock.json` 과 `yarn.lock` 가 한 리포에 동시 존재 = 패키지 매니저 미정 상태. CI 가 환경따라 둘 중 하나만 인식해 빌드 결과 비결정. 즉시 합의 후 하나 삭제 + `engines` 또는 `packageManager` 필드 명시. 근거: npm/yarn/pnpm 공식 cohabitation 안내 없음 (=비공식 anti-pattern).

## Project-Specific
프로젝트별 컨벤션. 공용 파일에서는 비어 있음.

(비어 있음)

## Open Questions
아직 결론 안 난 것.

- [2026-05-14] Dual package hazard (같은 패키지가 CJS·ESM 동시 로드) 로 singleton 상태가 두 인스턴스로 쪼개지는 문제: `instanceof` 실패 / 공유 Map 비어있음 증상으로 진단. `package.json` `exports` 조건부 필드 설계만으로 완전 방지 가능한지, 소비자 번들러 설정까지 강제해야 하는지 2026 현재 생태계 미해결. 근거: NodeBook CJS/ESM Interop; Snyk dual package 가이드 2024.
