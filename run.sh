#!/bin/bash

CPU=4
MEM=4G
DAX=${MEM}
QEMU_PATH=/home/fotis/workspace/qemu/build/x86_64-softmmu/qemu-system-x86_64
REPS=1
IMG=./build/last/usr.img

USAGE="Usage: ${0} <fs> [--img <img>] [--reps <N>] [<args>]
where:
    fs: one of dax, virtiofs, auto
    img: the path to the image to use (default ${IMG})
    N: the number of repetitions for the run (default ${REPS})
    args: arguments to be passed through to run.py"


IMG_DIR=/home/fotis/workspace/ram/img
GUEST_DIR=/home/fotis/workspace/ram/guest

# Check the necessary tmpfs mounts
for d in ${IMG_DIR} ${GUEST_DIR}; do
    if ! findmnt -t tmpfs -T ${d} &> /dev/null ; then
        echo "${d} is not on a tmpfs filesystem"
        exit 1
    fi
done

# Ensure the necessary network bridge
# NOTE: Assumes 'allow br0' in /etc/qemu/bridge.conf. See
# https://wiki.archlinux.org/index.php/QEMU#Bridged_networking_using_qemu-bridge-helper
if ! ip link show type bridge dev br0 &> /dev/null ; then
    ip link add name br0 type bridge
fi
if [[ -z $(ip link show dev br0 up) ]]; then
    ip link set br0 up
fi
if [[ -z $(ip addr show dev br0 to 192.168.122.1) ]]; then
    ip addr add dev br0 192.168.122.1/24
fi

case ${1} in
    dax)
        # virtio-fs, DAX window
        DAX_WINDOW="--virtio-fs-dax=${DAX}"
        ;&  # fallthrough, bash >= 4.0
    virtiofs)
        # virtio-fs, no DAX window
        VIRTIO_FS_OPTS="--mount-fs=virtiofs,/dev/virtiofs0,/virtiofs
            --virtio-fs-tag=myfs
            --virtio-fs-dir=${GUEST_DIR}
            ${DAX_WINDOW}"
        ;;
    auto)
        # no virtio-fs
        ;;
    *)
        echo "${USAGE}"
        exit 1
        ;;
esac
shift

for i in {1..2}; do
    case ${1} in
        --img)
            shift
            if [[ -z ${1} ]]; then
                echo "${USAGE}"
                exit 1
            fi
            IMG=${1}
            shift
            ;;
        --reps)
            shift
            if [[ -z ${1} ]]; then
                echo "${USAGE}"
                exit 1
            fi
            REPS=${1}
            shift
            ;;
    esac
done


# Run image from tmpfs
cp ${IMG} ${IMG_DIR}/usr.img || exit 1

for (( i=0; i<REPS; i++ )); do
    ./scripts/run.py \
        -c ${CPU} \
        -m ${MEM} \
        --qemu-path ${QEMU_PATH} \
        --ip=eth0,192.168.122.15,255.255.255.0 \
        --networking \
        --vhost \
        --image=${IMG_DIR}/usr.img \
        ${VIRTIO_FS_OPTS} \
        "$@"
done
