#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

if [[ ! -f .env && -f .env.example ]]; then
  cp .env.example .env
  echo "Created .env from .env.example"
fi

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

BASE_IMAGE="${BASE_IMAGE:-quay.io/hummingbird-community/bootc-os:latest}"
IMAGE_NAME="${IMAGE_NAME:-localhost/bootc-desktop:latest}"
ENABLE_FEDORA_RAWHIDE_REPO="${ENABLE_FEDORA_RAWHIDE_REPO:-0}"
COPR_REPO="${COPR_REPO:-}"
COPR_CHROOT="${COPR_CHROOT:-}"

echo "Building ${IMAGE_NAME} from ${BASE_IMAGE}"
if [[ "${ENABLE_FEDORA_RAWHIDE_REPO}" == "1" ]]; then
  echo "Enabling Fedora Rawhide repo"
fi
if [[ -n "${COPR_REPO}" ]]; then
  echo "Enabling COPR repo: ${COPR_REPO}"
  if [[ -n "${COPR_CHROOT}" ]]; then
    echo "Using COPR chroot: ${COPR_CHROOT}"
  fi
fi

docker build \
  --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
  --build-arg "ENABLE_FEDORA_RAWHIDE_REPO=${ENABLE_FEDORA_RAWHIDE_REPO}" \
  --build-arg "COPR_REPO=${COPR_REPO}" \
  --build-arg "COPR_CHROOT=${COPR_CHROOT}" \
  -t "${IMAGE_NAME}" \
  -f Containerfile .

echo "Build complete: ${IMAGE_NAME}"
