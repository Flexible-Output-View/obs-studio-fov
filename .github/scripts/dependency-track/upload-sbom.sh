#!/usr/bin/env bash
# Upload one or more CycloneDX SBOMs to an OWASP Dependency-Track project.
#
# Usage:
#   .github/scripts/dependency-track/upload-sbom.sh --project obs-studio-fov [--version dev] sbom/*.cdx.json
#   .github/scripts/dependency-track/upload-sbom.sh --project-uuid <uuid> sbom/*.cdx.json
#
# Options:
#   --project NAME        project name (with --version) to upload to
#   --version VERSION     project version (default: $DEPENDENCY_TRACK_PROJECT_VERSION or "dev")
#   --project-uuid UUID   upload straight to an existing project, no name lookup,
#                         no autoCreate, no PROJECT_CREATION_UPLOAD needed
#   --no-auto-create      fail instead of creating the project when it is missing
#   -h, --help
#
# Environment:
#   DEPENDENCY_TRACK_URL              API server URL (default http://localhost:8081)
#   DEPENDENCY_TRACK_API_KEY          API key with BOM_UPLOAD (required)
#   DEPENDENCY_TRACK_PROJECT_VERSION  default project version (dev)
#   DEPENDENCY_TRACK_PROJECT_UUID     default value for --project-uuid
set -euo pipefail

PROJECT=""
PROJECT_UUID="${DEPENDENCY_TRACK_PROJECT_UUID:-}"
VERSION="${DEPENDENCY_TRACK_PROJECT_VERSION:-dev}"
AUTO_CREATE="true"
FILES=()

usage() { awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --project-uuid) PROJECT_UUID="$2"; shift 2 ;;
    --no-auto-create) AUTO_CREATE="false"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

[[ -n "$PROJECT" || -n "$PROJECT_UUID" ]] || {
  echo "ERROR: --project or --project-uuid is required" >&2
  exit 1
}
[[ ${#FILES[@]} -gt 0 ]] || { echo "ERROR: no SBOM files given" >&2; exit 1; }

# A trailing slash (or /api suffix) silently produces //api/v1/bom, which a
# reverse proxy in front of Dependency-Track may answer with 403/404.
API_URL="${DEPENDENCY_TRACK_URL:-http://localhost:8081}"
while [[ "$API_URL" == */ ]]; do API_URL="${API_URL%/}"; done
API_URL="${API_URL%/api}"
API_KEY="${DEPENDENCY_TRACK_API_KEY:?DEPENDENCY_TRACK_API_KEY is not set}"

TARGET="$PROJECT@$VERSION"
[[ -n "$PROJECT_UUID" ]] && TARGET="uuid:$PROJECT_UUID"

BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT

# dt_get PATH -> prints the HTTP status, body lands in $BODY_FILE
dt_get() {
  curl -sS -o "$BODY_FILE" -w '%{http_code}' \
    -H "X-Api-Key: $API_KEY" -H "Accept: application/json" "$API_URL$1" || true
}

explain_403() {
  local body
  body="$(cat "$BODY_FILE" 2>/dev/null || true)"
  case "$body" in
    *"Access to the specified project is forbidden"*)
      echo "    hint: the API key's team is not mapped to the $TARGET project." >&2
      echo "          This happens when the project was recreated (new UUID) or was" >&2
      echo "          never added to the team. On the Dependency-Track host run:" >&2
      echo "            ./scripts/bootstrap.sh          # re-maps the ci team, regenerates the key" >&2
      echo "          or add the mapping by hand:" >&2
      echo "            curl -X PUT \"\$DEPENDENCY_TRACK_URL/api/v1/acl/mapping\" \\" >&2
      echo "              -H \"X-Api-Key: \$ADMIN_KEY\" -H 'Content-Type: application/json' \\" >&2
      echo "              -d '{\"team\":\"<team-uuid>\",\"project\":\"<project-uuid>\"}'" >&2
      ;;
    *"permission to create project"*)
      echo "    hint: autoCreate=true needs the PROJECT_CREATION_UPLOAD permission." >&2
      echo "          Grant it to the key's team, or upload to an existing project" >&2
      echo "          with --project-uuid / --no-auto-create." >&2
      ;;
    *"<html"*|*"<!DOCTYPE"*)
      echo "    hint: that HTML page did not come from Dependency-Track; a reverse" >&2
      echo "          proxy, WAF or tunnel is blocking the request. Allow POST" >&2
      echo "          /api/v1/bom for the GitHub Actions egress." >&2
      ;;
    *Permission*|*"Access Denied"*)
      echo "    hint: the API key exists but lacks a permission the endpoint needs." >&2
      echo "          Re-run scripts/bootstrap.sh on the Dependency-Track host." >&2
      ;;
    *)
      echo "    hint: verify the URL with 'curl -fsS \"\$DEPENDENCY_TRACK_URL/api/version\"'" >&2
      echo "          and the key with 'curl -fsS -H \"X-Api-Key: \$KEY\" \"\$DEPENDENCY_TRACK_URL/api/v1/project\"'." >&2
      ;;
  esac
}

echo "==> Checking $API_URL"
status="$(curl -sS -o "$BODY_FILE" -w '%{http_code}' "$API_URL/api/version" || true)"
case "$status" in
  200) echo "    API reachable ($(cat "$BODY_FILE"))" ;;
  000) echo "ERROR: $API_URL is unreachable from here." >&2; exit 1 ;;
  *)   echo "ERROR: GET $API_URL/api/version returned HTTP $status; is DEPENDENCY_TRACK_URL the API base URL?" >&2; exit 1 ;;
esac

if [[ -z "$PROJECT_UUID" ]]; then
  status="$(dt_get "/api/v1/project/lookup?name=$(jq -rn --arg v "$PROJECT" '$v|@uri')&version=$(jq -rn --arg v "$VERSION" '$v|@uri')")"
  case "$status" in
    200) echo "    project exists: $PROJECT@$VERSION ($(jq -r '.uuid // "?"' "$BODY_FILE"))" ;;
    401) echo "ERROR: the API key was rejected (HTTP 401)." >&2
         echo "       bootstrap.sh regenerates the key on every run; refresh" >&2
         echo "       DEPENDENCY_TRACK_API_KEY from integration.env." >&2
         exit 1 ;;
    403) echo "    WARNING: the key cannot read $PROJECT@$VERSION (HTTP 403)." >&2 ;;
    404) echo "    project not found; relying on autoCreate=$AUTO_CREATE" ;;
    *)   echo "    WARNING: project lookup returned HTTP $status; continuing." >&2 ;;
  esac
fi

for bom in "${FILES[@]}"; do
  [[ -f "$bom" ]] || { echo "ERROR: $bom not found" >&2; exit 1; }
  echo "==> Uploading $bom -> $TARGET"

  form=()
  if [[ -n "$PROJECT_UUID" ]]; then
    form=(-F "project=$PROJECT_UUID")
  else
    form=(-F "projectName=$PROJECT" -F "projectVersion=$VERSION")
    [[ "$AUTO_CREATE" == "true" ]] && form+=(-F "autoCreate=true")
  fi

  status="$(curl -sS -o "$BODY_FILE" -w '%{http_code}' -X POST "$API_URL/api/v1/bom" \
    -H "X-Api-Key: $API_KEY" \
    -H "Accept: application/json" \
    "${form[@]}" \
    -F "bom=@$bom")" || {
      rc=$?
      echo "ERROR: upload failed, could not complete the request (curl exit $rc)." >&2
      exit 1
    }

  if [[ "$status" != "200" && "$status" != "201" ]]; then
    echo "ERROR: upload of $bom failed with HTTP $status" >&2
    echo "       Dependency-Track said: $(head -c 500 "$BODY_FILE" 2>/dev/null)" >&2
    [[ "$status" == "401" ]] && {
      echo "    hint: the API key was rejected. bootstrap.sh regenerates the key on" >&2
      echo "          every run; refresh DEPENDENCY_TRACK_API_KEY from integration.env." >&2
    }
    [[ "$status" == "403" ]] && explain_403
    [[ "$status" == "404" ]] && echo "    hint: the project does not exist; drop --no-auto-create or create it first." >&2
    exit 1
  fi

  token=$(jq -r '.token // empty' < "$BODY_FILE")
  echo "    accepted (processing token: ${token:-n/a})"
done

echo "==> Upload(s) accepted; Dependency-Track processes BOMs asynchronously."
