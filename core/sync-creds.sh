#!/bin/bash
# sync-creds.sh - Claude credentials 동기화 (Windows → WSL)
#
# 매 CLI 호출 전에 실행되어야 함. 빠른 stat 체크로 변경 없으면 즉시 종료.
#
# 사용법: bash ~/.harness/core/sync-creds.sh

WSL_CRED="$HOME/.claude/.credentials.json"

# Windows USERPROFILE → WSL 경로로 동적 변환 (사용자명 하드코딩 회피)
WIN_USERPROFILE=$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')
if [ -z "$WIN_USERPROFILE" ]; then
    exit 0  # WSL only 환경 — 동기화 불필요
fi
WIN_HOME=$(wslpath -u "$WIN_USERPROFILE" 2>/dev/null)
[ -d "$WIN_HOME" ] || exit 0

WIN_CRED="$WIN_HOME/.claude/.credentials.json"

# Windows credentials 없으면 스킵
[ -f "$WIN_CRED" ] || exit 0

# 심볼릭 링크가 정상이면 OK (가장 자주 일어나는 경로)
if [ -L "$WSL_CRED" ]; then
    LINK_TARGET=$(readlink "$WSL_CRED")
    if [ "$LINK_TARGET" = "$WIN_CRED" ] && [ -f "$WSL_CRED" ]; then
        exit 0
    fi
    # 링크 깨짐 → 복구
    rm -f "$WSL_CRED"
    ln -s "$WIN_CRED" "$WSL_CRED"
    exit 0
fi

# WSL 파일 없음 → 심볼릭 링크 생성
if [ ! -f "$WSL_CRED" ]; then
    ln -s "$WIN_CRED" "$WSL_CRED"
    exit 0
fi

# 실제 파일인 경우: Windows 쪽이 더 새것이면 복사
WSL_MTIME=$(stat -c %Y "$WSL_CRED" 2>/dev/null)
WIN_MTIME=$(stat -c %Y "$WIN_CRED" 2>/dev/null)
if [ -n "$WIN_MTIME" ] && [ -n "$WSL_MTIME" ] && [ "$WIN_MTIME" -gt "$WSL_MTIME" ]; then
    cp "$WSL_CRED" "${WSL_CRED}.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null
    cp "$WIN_CRED" "$WSL_CRED" && chmod 600 "$WSL_CRED"
fi
exit 0
