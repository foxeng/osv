#!/bin/bash

# Build all images, store and label them

# Common with run_nginx.sh
IMG_STORE=./apps/nginx/images


store_img () {
    mv ./build/last/usr.img ${IMG_STORE}/${1}.img
    mv ./build/last/cmdline ${IMG_STORE}/${1}.cmdline
}


mkdir -p ${IMG_STORE} || exit 1

for fs in zfs rofs ramfs; do
    ./scripts/build \
        -j 8 \
        fs=${fs} \
        testfs=${fs} \
        image=nginx \
        || exit 1
    store_img ${fs}
done
./scripts/build \
    -j 8 \
    fs=ramfs \
    testfs=virtiofs \
    image=nginx \
    || exit 1
store_img virtiofs
# NOTE: NFS doesn't work.
# ./scripts/build -j 8 fs=ramfs testfs=nfs image=nginx
# store_img nfs
