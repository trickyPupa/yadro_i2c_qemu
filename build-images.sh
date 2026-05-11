#!/bin/bash
set -e

wget https://buildroot.org/downloads/buildroot-2023.02.tar.gz
tar xf buildroot-2023.02.tar.gz

cp buildroot_defconfig buildroot-2023.02/configs/yadro_qemu_defconfig
mkdir -p buildroot-2023.02/board/yadro_qemu
cp linux-fragment.config buildroot-2023.02/board/yadro_qemu/linux-fragment.config

cd buildroot-2023.02
make yadro_qemu_defconfig

cat ../linux-fragment.config >> output/build/linux-*/arch/arm/configs/versatile_defconfig
make linux-reconfigure

make -j$(nproc)

cp output/images/zImage output/images/rootfs.ext2 output/images/versatile-pb.dtb ../images/ 

echo "Образы готовы в images/"