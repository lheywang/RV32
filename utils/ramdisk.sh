#!/usr/bin/env bash
#
# mount_verilator_ramdisk.sh
# Creates a tmpfs RAM disk for fast Verilator builds
#
# Usage:
#   ./mount_verilator_ramdisk.sh [mountpoint] [size]
#
# Example:
#   ./mount_verilator_ramdisk.sh /mnt/ramdisk 8G
#
# Optional environment variables:
#   BUILD_DIR - path to your build directory (defaults to /mnt/ramdisk)
#   RAM_SIZE  - size of the tmpfs (defaults to 4G)
#
# To unmount:
#   ./mount_verilator_ramdisk.sh --unmount [mountpoint]
#

set -e

# Default config
MOUNT_POINT=${1:-${BUILD_DIR:-/mnt/ramdisk}}
SIZE=${2:-${RAM_SIZE:-4G}}

# Handle unmount
if [[ "$1" == "--unmount" ]]; then
    TARGET=${2:-${BUILD_DIR:-/mnt/ramdisk}}
    echo "Unmounting RAM disk at ${TARGET}..."
    if mountpoint -q "${TARGET}"; then
        sudo umount "${TARGET}"
        echo "✅ Unmounted ${TARGET}"
    else
        echo "⚠️  ${TARGET} is not mounted."
    fi
    exit 0
fi

# Create the mount point if it doesn't exist
if [ ! -d "${MOUNT_POINT}" ]; then
    echo "Creating mount point: ${MOUNT_POINT}"
    sudo mkdir -p "${MOUNT_POINT}"
fi

# Check if already mounted
if mountpoint -q "${MOUNT_POINT}"; then
    echo "✅ ${MOUNT_POINT} is already mounted."
    exit 0
fi

# Mount tmpfs
echo "Mounting tmpfs at ${MOUNT_POINT} with size ${SIZE}..."
sudo mount -t tmpfs -o size="${SIZE}",noatime tmpfs "${MOUNT_POINT}"

# Set permissions
sudo chown "$(id -u):$(id -g)" "${MOUNT_POINT}"

echo "✅ RAM disk mounted at ${MOUNT_POINT} (size ${SIZE})"
df -h "${MOUNT_POINT}"
