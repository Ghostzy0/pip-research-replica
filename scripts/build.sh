#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
edition="${1:-}"
case "$edition" in
  baseline) product=ResearchBaseline ;;
  *) echo 'Usage: scripts/build.sh [baseline]' >&2; exit 2 ;;
esac
swift build -c release --product "$product" --jobs 2
./scripts/package.sh "$edition" ".build/release/$product"
