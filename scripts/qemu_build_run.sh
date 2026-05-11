#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
QEMU_DIR="$ROOT_DIR/qemu"
BUILD_DIR="$QEMU_DIR/build"
SRC_DIR="$ROOT_DIR/src"
DST_DIR="$QEMU_DIR/hw/i2c"
TARGET_CFG="$QEMU_DIR/configs/devices/aarch64-softmmu/default.mak"

SRC_C="$SRC_DIR/i2c_device.c"
SRC_H="$SRC_DIR/i2c_device.h"
DST_C="$DST_DIR/yadro_i2c.c"
DST_H="$DST_DIR/yadro_i2c.h"

# Добавление файлов устройства

install -m 0644 "$SRC_C" "$DST_C"
install -m 0644 "$SRC_H" "$DST_H"

MESON_FILE="$DST_DIR/meson.build"
KCONFIG_FILE="$DST_DIR/Kconfig"

if ! grep -q "yadro_i2c.c" "$MESON_FILE"; then
  printf "\ni2c_ss.add(when: 'CONFIG_YADRO_I2C', if_true: files('yadro_i2c.c'))\n" >> "$MESON_FILE"
fi

if ! grep -q "config YADRO_I2C" "$KCONFIG_FILE"; then
  cat >> "$KCONFIG_FILE" <<'EOF'

config YADRO_I2C
    bool "YADRO simple I2C device"
    depends on I2C_DEVICES
    select I2C
EOF
fi

if [[ -f "$TARGET_CFG" ]] && ! grep -q "CONFIG_YADRO_I2C" "$TARGET_CFG"; then
  printf "\nCONFIG_YADRO_I2C=y\n" >> "$TARGET_CFG"
fi

# Сборка QEMU

if [[ ! -d "$BUILD_DIR" ]]; then
  echo "Build directory not found: $BUILD_DIR" >&2
  echo "Run scripts/qemu_setup.sh first." >&2
  exit 1
fi

ninja -C "$BUILD_DIR" -j"$(nproc)"

# Запуск QEMU

cd "$BUILD_DIR"

./qemu-system-aarch64 \
    -M virt \
    -m 1G \
    -smp 2 \
    -cpu cortex-a72 \
    -nographic \
    -qmp unix:/tmp/qmp.sock,server=on,wait=off \
    -device yadro-i2c-device,addr=0x42 \
    "$@"
