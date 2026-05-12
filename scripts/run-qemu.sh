#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

OUTPUT_DIR="${OUTPUT_DIR:-output}"
MEMORY_MB="${MEMORY_MB:-4096}"
CPUS="${CPUS:-4}"
SSH_PORT="${SSH_PORT:-2222}"

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
  echo "qemu-system-x86_64 is not installed" >&2
  exit 1
fi

DISK_IMAGE="${1:-}"
if [[ -z "${DISK_IMAGE}" ]]; then
  DISK_IMAGE="$(find "${OUTPUT_DIR}" -type f -name '*.qcow2' | sort | tail -n 1)"
fi

if [[ -z "${DISK_IMAGE}" || ! -f "${DISK_IMAGE}" ]]; then
  echo "No qcow2 image found. Run ./scripts/build-disk.sh first." >&2
  exit 1
fi

OVMF_CODE=""
for candidate in \
  /usr/share/OVMF/OVMF_CODE.fd \
  /usr/share/edk2/ovmf/OVMF_CODE.fd \
  /usr/share/edk2/x64/OVMF_CODE.fd \
  /usr/share/qemu/OVMF.fd \
  /usr/share/OVMF/OVMF_CODE_4M.fd
do
  if [[ -f "${candidate}" ]]; then
    OVMF_CODE="${candidate}"
    break
  fi
done

if [[ -z "${OVMF_CODE}" ]]; then
  echo "OVMF firmware not found. Install OVMF/edk2-ovmf." >&2
  exit 1
fi

QEMU_ARGS=(
  -m "${MEMORY_MB}"
  -smp "${CPUS}"
  -drive "file=${DISK_IMAGE},if=virtio,format=qcow2"
  -nic "user,model=virtio-net-pci,hostfwd=tcp::${SSH_PORT}-:22"
  -bios "${OVMF_CODE}"
  -device virtio-gpu-pci
  -display default
  -usb
  -device usb-tablet
)

if [[ -e /dev/kvm ]]; then
  QEMU_ARGS+=( -enable-kvm -cpu host )
else
  QEMU_ARGS+=( -cpu max )
fi

echo "Booting ${DISK_IMAGE}"
echo "SSH forward: localhost:${SSH_PORT} -> guest:22"
exec qemu-system-x86_64 "${QEMU_ARGS[@]}"
