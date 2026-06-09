#!/bin/bash

# Set version once
NCS_VERSION=${1:-v3.3.0}  # Default to v3.3.0, or use first argument
GHCR_IMAGE="ghcr.io/illysky/nrfconnect-sdk:${NCS_VERSION}"

docker build \
  -t nrfconnect-sdk:${NCS_VERSION} \
  -t ${GHCR_IMAGE} \
  --build-arg USER_UID=$(id -u) \
  --build-arg sdk_nrf_revision=${NCS_VERSION} \
  --network=host \
  .

echo "Built image: nrfconnect-sdk:${NCS_VERSION}"
echo "Tagged as:   ${GHCR_IMAGE}"

echo "Pushing to ghcr.io..."
docker push ${GHCR_IMAGE}
echo "Pushed: ${GHCR_IMAGE}"
