#!/bin/bash

# Set version once
NCS_VERSION=${1:-v3.1.1}  # Default to v3.1.1, or use first argument

docker build \
  -t nrfconnect-sdk:${NCS_VERSION} \
  --build-arg USER_UID=$(id -u) \
  --build-arg sdk_nrf_revision=${NCS_VERSION} \
  --network=host \
  .

echo "Built image: nrfconnect-sdk:${NCS_VERSION}"