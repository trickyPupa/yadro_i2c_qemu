ROOT_DIR := $(CURDIR)
QEMU_DIR := $(ROOT_DIR)/qemu
BUILD_DIR := $(QEMU_DIR)/build
SRC_DIR := $(ROOT_DIR)/src
DST_DIR := $(QEMU_DIR)/hw/i2c
MESON_FILE := $(DST_DIR)/meson.build
QEMU_BIN_ARM := $(BUILD_DIR)/qemu-system-arm
IMAGES_DIR := $(ROOT_DIR)/images

QEMU_REPO ?= https://gitlab.com/qemu-project/qemu.git
TARGET_LIST ?= arm-softmmu
I2C_ADDR ?= 0x10

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
	@"$(QEMU_BIN_ARM)" \
		-M versatilepb \
		-kernel $(IMAGES_DIR)/zImage \
		-dtb $(IMAGES_DIR)/versatile-pb.dtb \
		-append "root=/dev/sda console=ttyAMA0,115200" \
		-drive file=$(IMAGES_DIR)/rootfs.ext2,format=raw \
		-nographic \
		-device yadro-i2c-device,address=$(I2C_ADDR),bus=i2c,id=yadro-i2c \
		-qmp unix:/tmp/qmp.sock,server,nowait

clean:
	@ninja -C "$(BUILD_DIR)" clean

distclean:
	@rm -rf "$(BUILD_DIR)"
