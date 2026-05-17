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
- [2026-05-15] (training) **`ERR_REQUIRE_ASYNC_MODULE` 진단 순서** — Node v20.19.0+ / v22.12.0+ 에서 `require(esm)` 안정화로 dual package hazard 대부분 해소. 잔존 함정은 **top-level await 를 사용하는 ESM 모듈은 require() 불가**. 진단 순서: (1) 패키지 내부 top-level await 검색, (2) 의존성 전이 체인 확인 `node --trace-require-or-import`, (3) `"module-sink"` 조건을 exports 에 추가 (Node 22.10+) 하거나 top-level await 제거. ESM-only 배포 시 `"engines": { "node": "^20.19.0 || >=22.12.0" }` 명시 필수. 실측 영향 패키지: firebase-tools, prettier, angular-cli, lru-cache 등 전이적 top-level await. 근거: Joyee Cheung Blog "require(esm) from experiment to stability" 2025-12-30; Node.js 22.12.0 Release Notes; nodejs/node PR #54648 (module-sink).
- [2026-05-15] (training) **pnpm 11 마이그레이션 체크리스트** — pnpm 9→11 업그레이드 시 빌드 중단 원인 순서: (1) `ERR_PNPM_IGNORED_BUILDS` → `pnpm approve-builds` 실행 후 `allowBuilds` 맵 커밋 (기본값 `strictDepBuilds: true` 로 변경). `onlyBuiltDependencies` / `neverBuiltDependencies` / `ignoredBuiltDependencies` 모두 제거 → `allowBuilds` 맵으로 통합. (2) `ERR_PNPM_CATALOG_ENTRY_NOT_FOUND_FOR_SPEC` → catalog 에서 workspace root 외부경로 (`../`) 제거 (Issue #11537 미해결 회귀). (3) 캐시 충돌 → `node_modules/.modules.yaml` 삭제. **추가**: pnpm 11 은 `minimumReleaseAge: 24h` 기본 + `blockExoticSubdeps` 기본 활성으로 공급망 보호. `pnpm sbom` 명령 추가. 근거: pnpm 11.0 블로그; GitHub pnpm/pnpm#11537; nrwl/nx#35563.
- [2026-05-15] (training) **TypeScript 5.7 빌드 에러 핫스팟 3종** — (1) `--module nodenext` 에서 JSON import 에 `with { type: "json" }` attribute 필수화 — `import myConfig from "./myConfig.json"` 만 쓰면 에러. (2) `@types/node` 미업데이트 시 `Buffer` → `Uint8Array<ArrayBufferLike>` 타입 변경으로 TS2322 발생. (3) `rewriteRelativeImportExtensions` 활성화 시 `baseUrl/paths` 별칭이 **재작성되지 않아** 런타임 경로 불일치 — paths 별칭 사용 프로젝트는 이 옵션 비활성화 권장. Node `--experimental-strip-types` 와 함께 쓸 때만 활성화. 근거: TypeScript 5.7 공식 릴리즈 노트 (typescriptlang.org/docs/handbook/release-notes/typescript-5-7).
- [2026-05-15] (training) **Lockfile 무결성 2026 레이어드 방어** — (1) `npm ci` / `pnpm install --frozen-lockfile` — drift 시 빌드 즉시 중단. (2) `lockfile-lint` — 레지스트리 출처 화이트리스트 검증 (신뢰 외 소스 차단). (3) Socket.dev — 악성 패턴 사전 탐지 (Bitwarden CLI 2026-03 침해 탐지 사례). (4) Renovate `lockFileMaintenance` + `minimumReleaseAge`. (5) pnpm 11 내장 `minimumReleaseAge: 24h` + `blockExoticSubdeps`. **TanStack 2026-05-13 공격 교훈**: Renovate/Dependabot 자동 업데이트가 감염 확산 가속 — `minimumReleaseAge` 72h 이상 권장. 근거: docs.npmjs.com npm-ci; lockfile-lint npm; socket.dev "pnpm 11 supply chain"; charlesjones.dev.
- [2026-05-15] (training) **Bun/Deno 호환성 함정** — `__dirname` / `__filename`: Bun CJS 전역 완전 구현, **Node ESM 사용 불가** → `import.meta.dirname` / `import.meta.filename` 로 대체 (Node 20.11.0+ / Deno 1.40.0+ / Bun 1.0.23+). 교차 런타임 권장 = `import.meta.dirname`. Bun 미구현 API: `node:repl`, `node:sqlite`, `node:trace_events`. 부분 구현: `node:http2` (pushStream 없음), `node:crypto` (setFips 없음), `node:worker_threads` (stdio 옵션 없음). Bun 95% npm 호환 주장에도 Prisma / native database driver / 구형 `__dirname` 의존 패키지는 추가 workaround. 근거: bun.com/docs/runtime/nodejs-compat 공식; esmodules.com/runtimes/; sonarsource.com "__dirname Node.js ES Modules".

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

- [2026-05-15] **TypeScript nodenext vs bundler 산업 채택률** — State of JS 2025 등 공식 설문에 구체 채택 비율 미공개.
- [2026-05-15] **pnpm 11 catalog 외부경로 회귀 (#11537) 수정 ETA** — 2026-05-08 보고 후 수정 일정 미공개. 우회는 `../` 제거.
- [2026-05-15] **module-sink 조건의 Webpack/Vite/esbuild 지원** — Node PR #54648 은 확인했으나 번들러별 지원 교차검증 미완.

## Resolved Questions
- [2026-05-15] **Dual package hazard 완전 방지: exports 만으로 충분한가?** → **조건부 해소**. 충족 조건: ① 소비자 Node v20.19.0+ 또는 v22.12.0+, ② 패키지 내부에 top-level await 없을 것. 둘 다 만족 시 ESM-only 배포 + exports 단독으로 hazard 실질 해소. 불충족 경우: Node 18 이하 / Webpack·Rollup require / 전이적 top-level await 존재 시. 대안: `"module-sink"` 조건 추가 (Node 22.10+) + 문서화. (Patterns 의 "ERR_REQUIRE_ASYNC_MODULE 진단 순서" entry 로 이동)
