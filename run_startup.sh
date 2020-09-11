#!/bin/bash

# Run all OSv application startup tests

# Common with build_startup.sh
IMG_STORE=./apps/spring-boot-example/images
VIRTIOFS_ROOTFS=./apps/spring-boot-example/virtiofs_rootfs
# Common with run.sh
IMG_DIR=/home/fotis/workspace/ram/img
GUEST_DIR=/home/fotis/workspace/ram/guest

RESULTS_DIR=./apps/spring-boot-example/results
REPS=10
QEMU_TIMEOUT=10
# TODO OPT: collect resource usage?
EXTRA_ARGS="--reps ${REPS} --isolcpus --disable-freq-scale --bootchart --qemu-timeout ${QEMU_TIMEOUT}"


# Ensure the necessary tmpfs mounts
for d in ${IMG_DIR} ${GUEST_DIR}; do
    mkdir -p ${d} || exit 1
    if ! findmnt -t tmpfs -T ${d} &> /dev/null ; then
        # NOTE: Assumes fstab entries like:
        # tmpfs	/home/fotis/workspace/ram/guest	tmpfs	rw,user,noauto,size=40%,uid=fotis,gid=fotis	0 0
        # TODO OPT: Don't rely on fstab entry, but mount here directly? But what
        # about user mount?
        mount ${d} || exit 1
    fi
done
# Place virtiofs root fs contents in tmpfs
rm -rf ${GUEST_DIR}/*
cp -r ${VIRTIOFS_ROOTFS}/* ${GUEST_DIR}/


mkdir -p ${RESULTS_DIR} || exit 1

for fs in zfs rofs ramfs; do
    sudo ./run.sh \
        auto \
        --img ${IMG_STORE}/${fs}.img \
        ${EXTRA_ARGS} \
        -e "$(< ${IMG_STORE}/${fs}.cmdline)" \
        |& tee ${RESULTS_DIR}/${fs}
done
for fs in virtiofs dax; do
    sudo ./run.sh \
        ${fs} \
        --img ${IMG_STORE}/virtiofs.img \
        ${EXTRA_ARGS} \
        -e "$(< ${IMG_STORE}/virtiofs.cmdline)" \
        |& tee ${RESULTS_DIR}/${fs}
done
