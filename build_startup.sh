#!/bin/bash

# Build all images, store and label them

# Common with run_startup.sh
IMG_STORE=./apps/spring-boot-example/images
VIRTIOFS_ROOTFS=./apps/spring-boot-example/virtiofs_rootfs


store_img () {
    mv ./build/last/usr.img ${IMG_STORE}/${1}.img
    mv ./build/last/cmdline ${IMG_STORE}/${1}.cmdline
}


for d in ${IMG_STORE} ${VIRTIOFS_ROOTFS}; do
    mkdir -p ${d} || exit 1
done
rm -rf ${VIRTIOFS_ROOTFS}/*

for fs in zfs rofs ramfs; do
    ./scripts/build \
        -j 8 \
        fs=${fs} \
        image=openjdk8-zulu-full,spring-boot-example \
        || exit 1
    store_img ${fs}
done
./scripts/build \
    -j 8 \
    fs=virtiofs \
    export=all \
    image=openjdk8-zulu-full,spring-boot-example \
    || exit 1
store_img virtiofs
# NOTE: There is also an "export_dir" option to scripts/build, but it interprets
# paths relative to the build directory.
mv ./build/export/* ${VIRTIOFS_ROOTFS}/
