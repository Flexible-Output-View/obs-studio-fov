#!/usr/bin/env bash
# Upload one or more CycloneDX SBOMs to an OWASP Dependency-Track project.
#
# Usage:
#   .github/scripts/dependency-track/upload-sbom.sh --project obs-studio-fov [--version dev] sbom/*.cdx.json
#
# Environment:
#   DEPENDENCY_TRACK_URL      API server URL (default http://localhost:8081)
#   DEPENDENCY_TRACK_API_KEY  API key with BOM_UPLOAD (required)
set -euo pipefail

PROJECT=""
VERSION="${DEPENDENCY_TRACK_PROJECT_VERSION:-dev}"
FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

[[ -n "$PROJECT" ]] || { echo "ERROR: --project is required" >&2; exit 1; }
[[ ${#FILES[@]} -gt 0 ]] || { echo "ERROR: no SBOM files given" >&2; exit 1; }

API_URL="${DEPENDENCY_TRACK_URL:-http://localhost:8081}"
API_KEY="${DEPENDENCY_TRACK_API_KEY:?DEPENDENCY_TRACK_API_KEY is not set}"

for bom in "${FILES[@]}"; do
  [[ -f "$bom" ]] || { echo "ERROR: $bom not found" >&2; exit 1; }
  echo "==> Uploading $bom -> $PROJECT@$VERSION"
  response=$(curl -sS --fail-with-body -X POST "$API_URL/api/v1/bom" \
    -H "X-Api-Key: $API_KEY" \
    -H "Accept: application/json" \
    -F "projectName=$PROJECT" \
    -F "projectVersion=$VERSION" \
    -F "autoCreate=true" \
    -F "bom=@$bom")
  token=$(jq -r '.token // empty' <<<"$response")
  echo "    accepted (processing token: ${token:-n/a})"
done

echo "==> Upload(s) accepted; Dependency-Track processes BOMs asynchronously."
