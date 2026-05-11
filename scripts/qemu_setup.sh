#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
QEMU_DIR="$ROOT_DIR/qemu"
QEMU_REPO=${QEMU_REPO:-"https://gitlab.com/qemu-project/qemu.git"}
BUILD_DIR="$QEMU_DIR/build"
TARGET_LIST=${TARGET_LIST:-"aarch64-softmmu"}

if [[ ! -d "$QEMU_DIR/.git" ]]; then
  git clone --branch master "$QEMU_REPO" "$QEMU_DIR"
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

"$QEMU_DIR/configure" \
  --target-list="$TARGET_LIST" \
  --enable-debug
