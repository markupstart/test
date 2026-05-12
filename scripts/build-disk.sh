#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

IMAGE_NAME="${IMAGE_NAME:-localhost/bootc-desktop:latest}"
BUILD_CONFIG="${BUILD_CONFIG:-blueprint/user-example.toml}"
OUTPUT_DIR="${OUTPUT_DIR:-output}"
ROOTFS="${ROOTFS:-ext4}"
BUILDER_IMAGE="${BUILDER_IMAGE:-quay.io/centos-bootc/bootc-image-builder:latest}"
PODMAN_BIN="${PODMAN_BIN:-podman}"
PODMAN_USE_SUDO="${PODMAN_USE_SUDO:-0}"
STORE_DIR="${STORE_DIR:-.cache/bib-store}"
RPMMD_DIR="${RPMMD_DIR:-.cache/bib-rpmmd}"

PODMAN_CMD=("${PODMAN_BIN}")
if [[ "${PODMAN_USE_SUDO}" == "1" ]]; then
  PODMAN_CMD=(sudo "${PODMAN_BIN}")
fi

if [[ ! -f "${BUILD_CONFIG}" ]]; then
  echo "Build config not found: ${BUILD_CONFIG}" >&2
  exit 1
fi

if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  echo "Docker image not found: ${IMAGE_NAME}" >&2
  echo "Build it first with ./scripts/build.sh or docker compose build" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"
mkdir -p "${STORE_DIR}" "${RPMMD_DIR}"

if [[ "${PODMAN_USE_SUDO}" == "1" ]]; then
  echo "Requesting sudo access for rootful Podman"
  sudo -v
fi

if ! "${PODMAN_CMD[@]}" image exists "${BUILDER_IMAGE}"; then
  echo "Builder image not present in this Podman context; pulling ${BUILDER_IMAGE}"
  "${PODMAN_CMD[@]}" pull "${BUILDER_IMAGE}"
fi

echo "Loading ${IMAGE_NAME} into Podman image storage"
docker save "${IMAGE_NAME}" | "${PODMAN_CMD[@]}" load >/dev/null

ROOTLESS="$("${PODMAN_CMD[@]}" info --format '{{.Host.Security.Rootless}}')"
PODMAN_ARGS=(
  run --rm
  --pull=never
  -v "${PROJECT_ROOT}/${BUILD_CONFIG}:/config.toml:ro"
  -v "${PROJECT_ROOT}/${OUTPUT_DIR}:/output"
  -v "${PROJECT_ROOT}/${STORE_DIR}:/store"
  -v "${PROJECT_ROOT}/${RPMMD_DIR}:/rpmmd"
)

BUILD_ARGS=(
  build
  --type qcow2
  --rootfs "${ROOTFS}"
  --use-librepo=True
  --chown "$(id -u):$(id -g)"
)

if [[ "${ROOTLESS}" == "true" ]]; then
  STORAGE_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/containers/storage"
  mkdir -p "${STORAGE_DIR}"
  PODMAN_ARGS+=( --privileged --security-opt label=disable -v "${STORAGE_DIR}:/var/lib/containers/storage" )
  BUILD_ARGS+=( --in-vm )
  echo "Detected rootless Podman; using --privileged --in-vm mode with SELinux label=disable"
  if [[ -f /etc/debian_version ]]; then
    echo "Rootless bootc-image-builder may fail on Debian with chcon /store errors." >&2
    echo "If this build fails, rerun with: PODMAN_USE_SUDO=1 ./scripts/build-disk.sh" >&2
  fi
else
  PODMAN_ARGS+=( --privileged --security-opt label=type:unconfined_t -v /var/lib/containers/storage:/var/lib/containers/storage )
  echo "Detected rootful Podman"
fi

echo "Building qcow2 in ${OUTPUT_DIR} using ${BUILD_CONFIG}"
"${PODMAN_CMD[@]}" "${PODMAN_ARGS[@]}" \
  "${BUILDER_IMAGE}" \
  "${BUILD_ARGS[@]}" \
  "${IMAGE_NAME}"

echo "Disk image build complete"
find "${OUTPUT_DIR}" -type f \( -name '*.qcow2' -o -name '*.raw' -o -name '*.img' \) | sort
