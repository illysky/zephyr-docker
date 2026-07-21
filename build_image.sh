#!/bin/bash
set -e

# ── Versioning ────────────────────────────────────────────────────────────
# Image tags are `<sdk_nrf_revision>-b<build_num>` — decoupled from the NCS
# version itself, since we bump tool versions independently of NCS upgrades.
# Bump build_num when only tools/Dockerfile change; reset to 1 when
# sdk_nrf_revision changes. See CHANGELOG.md.
SDK_NRF_REVISION=${1:-v3.5.0-preview1}
BUILD_NUM=${2:-1}
IMAGE_TAG="${SDK_NRF_REVISION}-b${BUILD_NUM}"

GHCR_IMAGE="ghcr.io/illysky/nrfconnect-sdk:${IMAGE_TAG}"
GHCR_ALIAS="ghcr.io/illysky/nrfconnect-sdk:${SDK_NRF_REVISION}"  # floating: newest build for this NCS revision

docker build \
  -t nrfconnect-sdk:${IMAGE_TAG} \
  -t ${GHCR_IMAGE} \
  -t ${GHCR_ALIAS} \
  --build-arg USER_UID=$(id -u) \
  --build-arg sdk_nrf_revision=${SDK_NRF_REVISION} \
  --build-arg IMAGE_VERSION=${IMAGE_TAG} \
  --network=host \
  .

echo "Built image: ${IMAGE_TAG}"
echo "Tagged as:   ${GHCR_IMAGE}"
echo "Tagged as:   ${GHCR_ALIAS} (floating alias)"

# Pass --push as the third argument to also push both tags to GHCR
if [ "$3" == "--push" ]; then
  docker push ${GHCR_IMAGE}
  docker push ${GHCR_ALIAS}
  echo "Pushed: ${GHCR_IMAGE}"
  echo "Pushed: ${GHCR_ALIAS}"
fi
