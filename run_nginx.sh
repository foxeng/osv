#!/bin/bash

# Run all OSv nginx tests

# Common with build_nginx.sh
IMG_STORE=./apps/nginx/images
# Common with run.sh
IMG_DIR=/home/fotis/workspace/ram/img
GUEST_DIR=/home/fotis/workspace/ram/guest

NGINX_DATA=./apps/nginx/data
NGINX_CLIENT=./apps/nginx/vegeta.sh
RESULTS_DIR=./apps/nginx/results
REPS=10
CLIENT_DELAY=1
EXTRA_ARGS="--reps ${REPS} --isolcpus --disable-freq-scale --perf qemu --memu qemu --client-path ${NGINX_CLIENT} --client-delay ${CLIENT_DELAY}"


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
# Place nginx data files in tmpfs
rm -rf ${GUEST_DIR}/*
cp -r ${NGINX_DATA}/* ${GUEST_DIR}/


mkdir -p ${RESULTS_DIR} || exit 1

# NOTE: NFS doesn't work.
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
        --perf virtiofsd \
        --memu virtiofsd \
        -e "$(< ${IMG_STORE}/virtiofs.cmdline)" \
        |& tee ${RESULTS_DIR}/${fs}
done
# NOTE: NFS doesn't work.
# sudo ./run.sh \
#     auto \
#     --img ${IMG_STORE}/nfs.img \
#     ${EXTRA_ARGS} \
#     --perf nfs \
#     -e "$(< ${IMG_STORE}/nfs.cmdline)" \
#     |& tee ${RESULTS_DIR}/nfs

# TODO OPT: Run host nginx?
