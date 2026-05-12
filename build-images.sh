#!/bin/bash
set -e

wget https://buildroot.org/downloads/buildroot-2023.02.tar.gz
tar xf buildroot-2023.02.tar.gz

cd buildroot-2023.02

cp ../buildroot_defconfig configs/yadro_qemu_defconfig
mkdir -p board/yadro_qemu
cp ../full-linux-config board/yadro_qemu/

make yadro_qemu_defconfig

make -j$(nproc)

cp output/images/zImage output/images/rootfs.ext2 output/images/versatile-pb.dtb ../images/ 

echo "Image files are ready in images/"