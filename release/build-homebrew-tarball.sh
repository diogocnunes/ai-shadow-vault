#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(cat "$ROOT_DIR/VERSION")"
OUT_DIR="$ROOT_DIR/dist"
PKG_ROOT="$OUT_DIR/ai-vault-$VERSION"
ARCHIVE_PATH="$OUT_DIR/ai-vault-$VERSION.tar.gz"

rm -rf "$PKG_ROOT"
mkdir -p "$PKG_ROOT/bin" "$PKG_ROOT/libexec" "$OUT_DIR"

cp "$ROOT_DIR"/bin/ai-vault "$PKG_ROOT/bin/"
cp -R "$ROOT_DIR/libexec/ai-vault" "$PKG_ROOT/libexec/"
cp "$ROOT_DIR"/README.md "$ROOT_DIR"/README_PT.md "$ROOT_DIR"/LICENSE "$ROOT_DIR"/VERSION "$PKG_ROOT/"

tar -C "$OUT_DIR" -czf "$ARCHIVE_PATH" "ai-vault-$VERSION"
shasum -a 256 "$ARCHIVE_PATH"
