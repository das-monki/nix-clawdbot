#!/bin/sh
set -e

store_path_file="${PNPM_STORE_PATH_FILE:-.pnpm-store-path}"
if [ -f "$store_path_file" ]; then
  store_path="$(cat "$store_path_file")"
  export PNPM_STORE_DIR="$store_path"
  export PNPM_STORE_PATH="$store_path"
  export NPM_CONFIG_STORE_DIR="$store_path"
  export NPM_CONFIG_STORE_PATH="$store_path"
fi
export HOME="$(mktemp -d)"
export TMPDIR="${HOME}/tmp"
mkdir -p "$TMPDIR"
export CLAWDBOT_LOG_DIR="${TMPDIR}/clawdbot-logs"
export CLAWDBOT_LOG_PATH="${CLAWDBOT_LOG_DIR}/clawdbot-gateway.log"
mkdir -p "$CLAWDBOT_LOG_DIR"
mkdir -p /tmp/clawdbot || true
chmod 700 /tmp/clawdbot || true
export VITEST_POOL="threads"
export VITEST_MIN_THREADS="1"
export VITEST_MAX_THREADS="1"
export VITEST_MIN_WORKERS="1"
export VITEST_MAX_WORKERS="1"

pnpm test
