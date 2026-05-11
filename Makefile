SHELL := /bin/bash

ROOT_DIR := $(CURDIR)
QEMU_DIR := $(ROOT_DIR)/qemu
BUILD_DIR := $(QEMU_DIR)/build
SRC_DIR := $(ROOT_DIR)/src
DST_DIR := $(QEMU_DIR)/hw/i2c
MESON_FILE := $(DST_DIR)/meson.build
QEMU_BIN := $(BUILD_DIR)/qemu-system-aarch64

QEMU_REPO ?= https://gitlab.com/qemu-project/qemu.git
TARGET_LIST ?= aarch64-softmmu
RUN_ARGS ?=
I2C_ADDR ?= 0x42

.PHONY: setup sync build run clean distclean

setup:
	@if [ ! -d "$(QEMU_DIR)/.git" ]; then \
		git clone --branch master "$(QEMU_REPO)" "$(QEMU_DIR)"; \
	fi
	@mkdir -p "$(BUILD_DIR)"
	@cd "$(BUILD_DIR)" && "$(QEMU_DIR)/configure" \
		--target-list="$(TARGET_LIST)" \
		--enable-debug

sync:
	@install -m 0644 "$(SRC_DIR)/i2c_device.c" "$(DST_DIR)/yadro_i2c.c"
	@if ! grep -q "yadro_i2c.c" "$(MESON_FILE)"; then \
		awk '/system_ss.add_all/ && !added {print "i2c_ss.add(when: \047CONFIG_I2C\047, if_true: files(\047yadro_i2c.c\047))"; added=1} {print}' "$(MESON_FILE)" > "$(MESON_FILE).tmp"; \
		mv "$(MESON_FILE).tmp" "$(MESON_FILE)"; \
	fi

build: sync
	@ninja -C "$(BUILD_DIR)" -j"$$(nproc)"

run: build
	@"$(QEMU_BIN)" \
		-M raspi3b \
		-m 1G \
		-smp 4 \
		-cpu cortex-a72 \
		-nographic \
		-qmp unix:/tmp/qmp.sock,server=on,wait=off \
		-device yadro-i2c-device,address=$(I2C_ADDR) \
		$(RUN_ARGS)

test-run: build
	@"$(QEMU_BIN)" \
		-M virt \
		-m 1G \
		-smp 2 \
		-cpu cortex-a72 \
		-nographic \
		-kernel $(CURDIR)/images/tmp.img \
		-drive file=$(CURDIR)/images/rootfs.img,if=virtio,format=raw \
		-qmp unix:/tmp/qmp.sock,server=on,wait=off \
		-device remote-i2c-controller,i2cbus=i2c0.0,devname=i2c-33 \
		-device yadro-i2c-device,bus=i2c0.0,address=$(I2C_ADDR) 

clean:
	@ninja -C "$(BUILD_DIR)" clean

distclean:
	@rm -rf "$(BUILD_DIR)"
