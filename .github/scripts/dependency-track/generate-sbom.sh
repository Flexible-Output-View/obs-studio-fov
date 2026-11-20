#!/usr/bin/env bash
# Generate the CycloneDX SBOM for obs-studio-fov.
#
# Usage: .github/scripts/dependency-track/generate-sbom.sh [output-file]
# Requires: python3, and a git checkout with submodules (for exact versions).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUTPUT="${1:-$ROOT_DIR/sbom/obs-studio-fov.cdx.json}"

exec python3 "$SCRIPT_DIR/generate-sbom.py" -o "$OUTPUT"
