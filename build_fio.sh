#!/bin/bash

# Build all images, store and label them

# Common with run_fio.sh
IMG_STORE=./modules/fio/images


store_img () {
    mv ./build/last/usr.img ${IMG_STORE}/${1}.img
    mv ./build/last/cmdline ${IMG_STORE}/${1}.cmdline
}


mkdir -p ${IMG_STORE} || exit 1

for i in single many; do
    for j in serial random; do
        tc=${i}-${j}

        ./scripts/build \
            -j 8 \
            fs=zfs \
            fs_size_mb=2048 \
            testfs=zfs \
            testcase=${tc} \
            image=fio \
            || exit 1
        store_img zfs-${tc}
        for fs in rofs ramfs; do
            ./scripts/build \
                -j 8 \
                fs=${fs} \
                testfs=${fs} \
                testcase=${tc} \
                image=fio \
                || exit 1
            store_img ${fs}-${tc}
        done
        for fs in virtiofs nfs; do
            ./scripts/build \
                -j 8 \
                fs=ramfs \
                testfs=${fs} \
                testcase=${tc} \
                image=fio \
                || exit 1
            store_img ${fs}-${tc}
        done
    done
done
