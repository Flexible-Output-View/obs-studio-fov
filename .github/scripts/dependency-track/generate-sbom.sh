#!/usr/bin/env bash
# Generate the CycloneDX SBOM for obs-studio-fov.
#
# Usage: ./scripts/generate-sbom.sh [output-file]
# Requires: python3, and a git checkout with submodules (for exact versions).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:-$ROOT_DIR/sbom/obs-studio-fov.cdx.json}"

exec python3 "$ROOT_DIR/scripts/generate-sbom.py" -o "$OUTPUT"
