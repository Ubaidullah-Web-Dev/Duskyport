#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Running Go unit tests..."
(cd "$REPO_ROOT" && go test -v ./...)

echo "==> Testing Duskyport CLI engine..."
"$REPO_ROOT/bin/duskyport" caps >/dev/null
"$REPO_ROOT/bin/duskyport" paths >/dev/null
"$REPO_ROOT/bin/duskyport" cloud-catalog >/dev/null

echo "==> Testing Duskyssh CLI..."
"$REPO_ROOT/bin/x86_64/duskyssh" keys >/dev/null

echo "==> Testing Duskyport GPU passthrough engine..."
"$REPO_ROOT/bin/x86_64/duskyport-gpuvm" list >/dev/null

echo "==> Verifying no legacy brand traces..."
target_pattern="ry""oku\|ry""oport\|ry""ovm\|ry""ossh"
if grep -rn "$target_pattern" \
  --exclude-dir=".git" \
  --exclude-dir="target" \
  --exclude-dir="scratch" \
  --exclude="test.sh" \
  "$REPO_ROOT"; then
    echo "ERROR: Legacy brand strings found!" >&2
    exit 1
fi

echo "==> All tests and verification checks passed!"
