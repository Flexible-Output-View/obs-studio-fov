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
as the `sbom-cyclonedx` artifact, and uploads it when these repository secrets
exist:

| Secret | Description |
| ------ | ----------- |
| `DEPENDENCY_TRACK_URL` | API base URL reachable from GitHub runners |
| `DEPENDENCY_TRACK_API_KEY` | API key of the `ci` team (`BOM_UPLOAD`) |

Missing secrets are not an error: the SBOM is still generated and archived.
