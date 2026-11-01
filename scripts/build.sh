#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Building Go helpers for Duskyport..."
mkdir -p "$REPO_ROOT/bin/x86_64"

(cd "$REPO_ROOT" && go build -v -ldflags="-s -w" -o bin/x86_64/duskyport-fetch ./cmd/duskyport-fetch)
(cd "$REPO_ROOT" && go build -v -ldflags="-s -w" -o bin/x86_64/duskyport-mon ./cmd/duskyport-mon)
(cd "$REPO_ROOT" && go build -v -ldflags="-s -w" -o bin/x86_64/duskyssh ./cmd/duskyssh)
(cd "$REPO_ROOT" && go build -v -ldflags="-s -w" -o bin/x86_64/duskyport-gpuvm ./cmd/duskyport-gpuvm)

echo "==> Binaries built successfully in bin/x86_64/"
