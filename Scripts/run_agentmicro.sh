#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-debug}"
APP="$ROOT/AgentMicro.app"
PROCESS_PATTERN="$APP/Contents/MacOS/AgentMicro"

"$ROOT/Scripts/package_agentmicro.sh" "$CONFIGURATION"
pkill -f "$PROCESS_PATTERN" 2>/dev/null || true
open -n "$APP"

for _ in {1..20}; do
  if pgrep -f "$PROCESS_PATTERN" >/dev/null 2>&1; then
    echo "AgentMicro is running from $APP"
    exit 0
  fi
  sleep 0.25
done

echo "ERROR: AgentMicro did not remain running" >&2
exit 1
