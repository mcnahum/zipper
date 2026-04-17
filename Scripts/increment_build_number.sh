#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_FILE="$SCRIPT_DIR/../Config/BuildNumber.xcconfig"

if [[ ! -f "$BUILD_FILE" ]]; then
  exit 0
fi

current_value="$(/usr/bin/sed -n 's/^BUILD_NUMBER = //p' "$BUILD_FILE" | /usr/bin/head -n 1)"

if [[ -z "$current_value" ]]; then
  current_value=1
fi

next_value=$((current_value + 1))
/usr/bin/sed -i '' "s/^BUILD_NUMBER = .*/BUILD_NUMBER = $next_value/" "$BUILD_FILE"
