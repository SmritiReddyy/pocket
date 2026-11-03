#!/usr/bin/env bash
# Quality gate: unit tests plus a release build where any warning fails.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Picks an SDK that can build SwiftUI and finds Swift Testing (see sdk.sh).
source "$ROOT/Scripts/sdk.sh"

cd "$ROOT"
echo "› Unit tests…"
# One compile at a time: with the Command Line Tools, the Swift Testing macro plugin can fail to
# load when several test files compile at once.
swift test --build-system native -j 1 ${POCKET_TEST_FLAGS[@]+"${POCKET_TEST_FLAGS[@]}"}
echo "› Release build, warnings as errors…"
swift build --build-system native -c release -Xswiftc -warnings-as-errors -Xcc -Werror
echo "✓ All checks passed"
