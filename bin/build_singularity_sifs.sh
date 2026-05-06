#!/usr/bin/env bash
# Build Singularity SIF files for locally-built Docker images.
# Must be run from the pipeline root directory after building the Docker images:
#   docker build -t virtus2-kz:local modules/local/kz_filter/
#   docker build -t virtus2-aggregate:local modules/local/virtus_aggregate/
#
# Requires: Singularity/Apptainer and Docker daemon running.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(dirname "$SCRIPT_DIR")"
SIF_DIR="${PIPELINE_DIR}/singularity"

mkdir -p "$SIF_DIR"

echo "Building virtus2-kz.sif ..."
singularity build "${SIF_DIR}/virtus2-kz.sif" docker-daemon://virtus2-kz:local

echo "Building virtus2-aggregate.sif ..."
singularity build "${SIF_DIR}/virtus2-aggregate.sif" docker-daemon://virtus2-aggregate:local

echo "Done. SIF files written to ${SIF_DIR}/"
