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
export TMPDIR="$HOME/tmp"
mkdir -p "$TMPDIR"

if [ -z "${CONFIG_OPTIONS_GENERATOR:-}" ]; then
  echo "CONFIG_OPTIONS_GENERATOR is not set" >&2
  exit 1
fi
if [ ! -f "$CONFIG_OPTIONS_GENERATOR" ]; then
  echo "CONFIG_OPTIONS_GENERATOR not found: $CONFIG_OPTIONS_GENERATOR" >&2
  exit 1
fi
if [ -z "${CONFIG_OPTIONS_GOLDEN:-}" ]; then
  echo "CONFIG_OPTIONS_GOLDEN is not set" >&2
  exit 1
fi
if [ ! -f "$CONFIG_OPTIONS_GOLDEN" ]; then
  echo "CONFIG_OPTIONS_GOLDEN not found: $CONFIG_OPTIONS_GOLDEN" >&2
  exit 1
fi
if [ -z "${CONFIG_SCHEMA_GOLDEN:-}" ]; then
  echo "CONFIG_SCHEMA_GOLDEN is not set" >&2
  exit 1
fi
if [ ! -f "$CONFIG_SCHEMA_GOLDEN" ]; then
  echo "CONFIG_SCHEMA_GOLDEN not found: $CONFIG_SCHEMA_GOLDEN" >&2
  exit 1
fi
if [ -z "${NODE_ENGINE_CHECK:-}" ]; then
  echo "NODE_ENGINE_CHECK is not set" >&2
  exit 1
fi
if [ ! -f "$NODE_ENGINE_CHECK" ]; then
  echo "NODE_ENGINE_CHECK not found: $NODE_ENGINE_CHECK" >&2
  exit 1
fi

cp "$CONFIG_OPTIONS_GENERATOR" ./generate-config-options.ts
cp "$NODE_ENGINE_CHECK" ./check-node-engine.ts

if [ ! -x "./node_modules/.bin/tsx" ]; then
  echo "tsx not found at ./node_modules/.bin/tsx (run gateway-tests-build.sh first)" >&2
  exit 1
fi

./node_modules/.bin/tsx ./check-node-engine.ts --repo .

output_path="./generated-config-options.nix"
schema_output_path="./generated-config-schema.json"

./node_modules/.bin/tsx ./generate-config-options.ts --repo . --out "$output_path" --schema-out "$schema_output_path"

echo "Comparing generated config options..."
diff -u "$CONFIG_OPTIONS_GOLDEN" "$output_path"

echo "Comparing generated JSON schema..."
diff -u "$CONFIG_SCHEMA_GOLDEN" "$schema_output_path"
