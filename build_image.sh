#!/bin/bash
set -e

# ── Versioning ────────────────────────────────────────────────────────────
# Image tags are `<zephyr_revision>-b<build_num>` — decoupled from the Zephyr
# version itself, since we bump tool versions independently of Zephyr upgrades.
# Bump build_num when only tools/Dockerfile change; reset to 1 when
# zephyr_revision changes. See CHANGELOG.md.
ZEPHYR_REVISION=${1:-v4.4.1}
BUILD_NUM=${2:-1}
IMAGE_TAG="${ZEPHYR_REVISION}-b${BUILD_NUM}"

GHCR_IMAGE="ghcr.io/illysky/zephyr-docker:${IMAGE_TAG}"
GHCR_ALIAS="ghcr.io/illysky/zephyr-docker:${ZEPHYR_REVISION}"  # floating: newest build for this Zephyr revision

docker build \
  -t zephyr-docker:${IMAGE_TAG} \
  -t ${GHCR_IMAGE} \
  -t ${GHCR_ALIAS} \
  --build-arg USER_UID=$(id -u) \
  --build-arg zephyr_revision=${ZEPHYR_REVISION} \
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
