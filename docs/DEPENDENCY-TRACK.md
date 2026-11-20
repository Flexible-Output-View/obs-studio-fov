# Dependency tracking (OWASP Dependency-Track)

`obs-studio-fov` publishes a CycloneDX SBOM to a self-hosted
[OWASP Dependency-Track](https://dependencytrack.org) server. The shared
server and its bootstrap tooling live in `/Users/raphael/Code/DependencyTrack`
(see its `README.md`).

## Project

| Property | Value |
| -------- | ----- |
| Dependency-Track project | `obs-studio-fov` |
| Version | `dev` |
| BOM | `sbom/obs-studio-fov.cdx.json` |

## What is in the SBOM

C/C++ has no lockfile, so `.github/scripts/dependency-track/generate-sbom.py` inventories what the
build actually pins:

| Component | Version source |
| --------- | -------------- |
| `obs-studio-fov` | `git describe --tags` |
| `obs-deps` | `buildspec.json` → `dependencies.prebuilt.version` |
| `obs-deps-qt6` | `buildspec.json` → `dependencies.qt6.version` |
| `cef` | `buildspec.json` → `dependencies.cef.version` (+ per-platform revision properties) |
| `sparkle` | `buildspec.json` → `tools.sparkle.version` |
| `obs-browser` | git submodule (tag-derived version, commit property) |
| `obs-websocket` | git submodule (tag-derived version, commit property) |
| `libdshowcapture` | git submodule (commit) |

OS packages and the libraries *inside* the pre-built bundles (FFmpeg, x264,
SRT, RIST, mbedTLS, …) are not decomposed yet. They are tracked through the
`obs-deps@<release>` component; decomposing the bundles from a build artifact
is a possible follow-up (`syft`/`cdxgen` on `build/rundir` in the Linux build
workflow). This also means the project can legitimately show zero findings
while the bundle-level inventory is coarse: the OSV npm mirror enabled for
`web-fov` does not cover these components.

## Local usage

```bash
.github/scripts/dependency-track/generate-sbom.sh          # writes sbom/obs-studio-fov.cdx.json

export DEPENDENCY_TRACK_URL=http://localhost:8081
export DEPENDENCY_TRACK_API_KEY=... # from DependencyTrack/integration.env
.github/scripts/dependency-track/upload-sbom.sh --project obs-studio-fov --version dev sbom/*.cdx.json
```

Run the generator from a checkout **with initialized submodules**
(`git submodule update --init --recursive`); otherwise the submodule components
are missing from the SBOM.

`sbom/` is git-ignored.

## CI

`.github/workflows/dependency-track.yml` runs on pushes to `dev`/`master` that
touch `buildspec.json` or `.gitmodules`, on matching pull requests, weekly, and
on manual dispatch. It checks out submodules, generates the SBOM, archives it
as the `sbom-cyclonedx` artifact, and uploads it when these repository values
exist:

| Value | Description |
| ----- | ----------- |
| `DEPENDENCY_TRACK_URL` | API base URL reachable from GitHub runners (repo variable or secret) |
| `DEPENDENCY_TRACK_API_KEY` | API key of the `ci` team (`BOM_UPLOAD`, `PROJECT_CREATION_UPLOAD`, `VIEW_PORTFOLIO`) |

Missing values are not an error: the SBOM is still generated and archived.

## Troubleshooting uploads

`upload-sbom.sh` prints Dependency-Track's own error body, so the server's
reason is in the workflow log. It also probes `GET /api/version` and
`GET /api/v1/project/lookup` first, which is enough to tell the cases apart:

| Symptom | Cause | Fix |
| ------- | ----- | --- |
| `HTTP 401` | Key unknown to the server. `bootstrap.sh` **regenerates** the `ci` key every time it runs. | Copy the fresh key from `DependencyTrack/integration.env` into the secret |
| `HTTP 403` + `Access to the specified project is forbidden` | The key's team has no ACL mapping for that project UUID (project recreated, or mapping never created). | Re-run `scripts/bootstrap.sh`, which re-maps the team, or `PUT /api/v1/acl/mapping` |
| `HTTP 403` + `The principal does not have permission to create project` | `autoCreate=true` without `PROJECT_CREATION_UPLOAD`. | Grant the permission, or upload with `--project-uuid` / `--no-auto-create` |
| `HTTP 403` + an HTML body | A proxy, WAF or tunnel in front of Dependency-Track blocked the POST. | Allow `POST /api/v1/bom` for GitHub Actions egress |
| `HTTP 404` | Project missing with `--no-auto-create`, or `DEPENDENCY_TRACK_URL` contains a path (e.g. `/api`). | Create the project first; the script strips trailing `/` and `/api` |
| `unreachable` | Wrong host, or the port is only bound to `127.0.0.1` on the VM. | Use the public URL, or a self-hosted runner |

Reproduce from a laptop before re-running CI:

```bash
export DEPENDENCY_TRACK_URL=https://dt.example.com
export DEPENDENCY_TRACK_API_KEY=$(grep '^DEPENDENCY_TRACK_API_KEY=' ../DependencyTrack/integration.env | cut -d= -f2-)

curl -fsS "$DEPENDENCY_TRACK_URL/api/version"
curl -fsS -H "X-Api-Key: $DEPENDENCY_TRACK_API_KEY" \
  "$DEPENDENCY_TRACK_URL/api/v1/project/lookup?name=obs-studio-fov&version=dev"
```

The last call returns the project UUID when the key may read the project and
`403`/`404` when the ACL mapping is missing — the same condition that makes the
BOM upload fail.

