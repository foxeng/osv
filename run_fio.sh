#!/bin/bash

# Run all OSv fio tests

# Common with build_fio.sh
IMG_STORE=./modules/fio/images
# Common with run.sh
IMG_DIR=/home/fotis/workspace/ram/img
GUEST_DIR=/home/fotis/workspace/ram/guest

FIO_DATA=./modules/fio/data
RESULTS_DIR=./modules/fio/results
REPS=10
EXTRA_ARGS="--reps ${REPS} --isolcpus --disable-freq-scale --perf qemu --memu qemu"


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
# Place fio files in tmpfs
rm -rf ${GUEST_DIR}/*
cp -r ${FIO_DATA}/* ${GUEST_DIR}/


mkdir -p ${RESULTS_DIR}/{single,many}/{serial,random} || exit 1

for i in single many; do
    for j in serial random; do
        for fs in zfs rofs ramfs; do
            sudo ./run.sh \
                auto \
                --img ${IMG_STORE}/${fs}-${i}-${j}.img \
                ${EXTRA_ARGS} \
                -e "$(< ${IMG_STORE}/${fs}-${i}-${j}.cmdline)" \
                |& tee ${RESULTS_DIR}/${i}/${j}/${fs}
        done
        for fs in virtiofs dax; do
            sudo ./run.sh \
                ${fs} \
                --img ${IMG_STORE}/virtiofs-${i}-${j}.img \
                ${EXTRA_ARGS} \
                --perf virtiofsd \
                --memu virtiofsd \
                -e "$(< ${IMG_STORE}/virtiofs-${i}-${j}.cmdline)" \
                |& tee ${RESULTS_DIR}/${i}/${j}/${fs}
        done
        sudo ./run.sh \
            auto \
            --img ${IMG_STORE}/nfs-${i}-${j}.img \
            ${EXTRA_ARGS} \
            --perf nfs \
            -e "$(< ${IMG_STORE}/nfs-${i}-${j}.cmdline)" \
            |& tee ${RESULTS_DIR}/${i}/${j}/nfs
    done
done

# Overwrite possible previous results (since tee appends below)
rm -f ${RESULTS_DIR}/{single,many}/{serial,random}/host
for i in single many; do
    for j in serial random; do
        for (( r=0; r<REPS; r++ )); do
            if [[ ${i} == "single" ]]; then
                ./modules/fio/fio/fio \
                    --readonly \
                    --minimal \
                    --directory ${GUEST_DIR}/ \
                    ./modules/fio/tests/${i}-read-${j}.fio \
                    |& tee -a ${RESULTS_DIR}/${i}/${j}/host
            else
                ./modules/fio/fio/fio \
                    --readonly \
                    --minimal \
                    --opendir ${GUEST_DIR}/many/ \
                    ./modules/fio/tests/${i}-read-${j}.fio \
                    |& tee -a ${RESULTS_DIR}/${i}/${j}/host
            fi
        done
    done
done
