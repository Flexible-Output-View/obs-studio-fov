#!/usr/bin/env python3
"""Generate a CycloneDX SBOM for obs-studio-fov.

C/C++ has no lockfile, so the inventory is built from the things the build
actually pins:

  * the OBS/FOV source tree itself (git describe)
  * pre-built dependency bundles from buildspec.json
    (obs-deps, Qt6, CEF, Sparkle)
  * git submodules (obs-browser, obs-websocket, libdshowcapture)

Bundled source-only libraries under deps/ carry no version metadata and are
therefore not emitted (a version-less component cannot be matched against
vulnerability data).

Usage: python3 .github/scripts/dependency-track/generate-sbom.py [-o sbom/obs-studio-fov.cdx.json]
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[3]
VERSION_RE = re.compile(r"^v?(\d+\.\d+\.\d+)")
GITHUB_RE = re.compile(r"github\.com[:/](?P<org>[^/]+)/(?P<repo>[^/.]+)")


def git(*args: str) -> str:
    try:
        return subprocess.check_output(
            ("git", *args), cwd=ROOT, text=True, stderr=subprocess.DEVNULL
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""


def purl_version(version: str) -> str:
    return quote(version, safe=".+-_")


def add_component(components: list[dict], **component) -> str:
    component.setdefault("type", "library")
    component["bom-ref"] = component["purl"]
    components.append(component)
    return component["bom-ref"]


def project_version() -> str:
    described = git("describe", "--always", "--tags", "--dirty=-modified")
    return described.lstrip("v") or "dev"


def load_buildspec() -> dict:
    path = ROOT / "buildspec.json"
    if not path.is_file():
        return {}
    return json.loads(path.read_text())


def parse_gitmodules() -> dict[str, str]:
    """Return {submodule path: url} without requiring a git config parser."""
    path = ROOT / ".gitmodules"
    if not path.is_file():
        return {}
    urls: dict[str, str] = {}
    current_path = None
    for line in path.read_text().splitlines():
        line = line.strip()
        if line.startswith("[submodule"):
            current_path = None
        elif line.startswith("path") and current_path is None:
            current_path = line.split("=", 1)[1].strip()
        elif line.startswith("url") and current_path:
            urls[current_path] = line.split("=", 1)[1].strip()
    return urls


def github_purl(url: str, version: str) -> str | None:
    match = GITHUB_RE.search(url)
    if not match:
        return None
    org, repo = match.group("org"), match.group("repo")
    if repo.endswith(".git"):
        repo = repo[:-4]
    return f"pkg:github/{org}/{repo}@{purl_version(version)}"


def submodule_components(components: list[dict]) -> list[str]:
    refs: list[str] = []
    urls = parse_gitmodules()

    for line in git("submodule", "status").splitlines():
        match = re.match(r"\s*([0-9a-f]{40})\s+(\S+)(?:\s+\((.*)\))?", line)
        if not match:
            continue
        commit, path, describe = match.group(1), match.group(2), match.group(3) or ""

        version_match = VERSION_RE.search(describe)
        version = version_match.group(1) if version_match else commit[:12]

        url = urls.get(path)
        purl = github_purl(url, version) if url else None
        if not purl:
            purl = f"pkg:generic/{path.replace('/', '-')}@{purl_version(version)}"

        name = path.rsplit("/", 1)[-1]
        # deps/libdshowcapture/src -> libdshowcapture, not "src"
        if name == "src" and "/" in path:
            name = path.rsplit("/", 2)[-2]
        ref = add_component(
            components,
            name=name,
            version=version,
            purl=purl,
            description=f"git submodule at {path}",
            properties=[
                {"name": "cdx:git:commit", "value": commit},
                {"name": "cdx:git:path", "value": path},
                *(
                    [{"name": "cdx:git:describe", "value": describe}]
                    if describe
                    else []
                ),
            ],
        )
        refs.append(ref)

    return refs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "-o",
        "--output",
        default="sbom/obs-studio-fov.cdx.json",
        help="output file (default: sbom/obs-studio-fov.cdx.json)",
    )
    args = parser.parse_args()

    version = project_version()
    app_purl = (
        "pkg:github/Flexible-Output-View/obs-studio-fov@" + purl_version(version)
    )

    components: list[dict] = []
    refs = submodule_components(components)

    buildspec = load_buildspec()
    deps = buildspec.get("dependencies", {})
    tools = buildspec.get("tools", {})

    prebuilt = deps.get("prebuilt", {})
    if prebuilt.get("version"):
        refs.append(
            add_component(
                components,
                name="obs-deps",
                version=prebuilt["version"],
                purl="pkg:github/obsproject/obs-deps@"
                + purl_version(prebuilt["version"]),
                description="Pre-built FFmpeg/x264/SRT/RIST/mbedTLS bundle",
            )
        )

    qt6 = deps.get("qt6", {})
    if qt6.get("version"):
        refs.append(
            add_component(
                components,
                name="obs-deps-qt6",
                version=qt6["version"],
                purl="pkg:generic/obs-deps-qt6@"
                + purl_version(qt6["version"]),
                description="Pre-built Qt6 bundle from obs-deps",
            )
        )

    cef = deps.get("cef", {})
    if cef.get("version"):
        revisions = cef.get("revision", {})
        props = [
            {"name": f"cdx:cef:revision:{platform}", "value": str(rev)}
            for platform, rev in revisions.items()
        ]
        refs.append(
            add_component(
                components,
                name="cef",
                version=str(cef["version"]),
                purl="pkg:generic/cef@" + purl_version(str(cef["version"])),
                description="Chromium Embedded Framework (obs-browser)",
                properties=props,
            )
        )

    sparkle = tools.get("sparkle", {})
    if sparkle.get("version"):
        refs.append(
            add_component(
                components,
                name="sparkle",
                version=sparkle["version"],
                purl="pkg:github/sparkle-project/Sparkle@"
                + purl_version(sparkle["version"]),
                description="macOS auto-updater",
            )
        )

    bom = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.6",
        "serialNumber": f"urn:uuid:{uuid.uuid4()}",
        "version": 1,
        "metadata": {
            "timestamp": datetime.now(timezone.utc)
            .replace(microsecond=0)
            .isoformat()
            .replace("+00:00", "Z"),
            "tools": {
                "components": [
                    {
                        "type": "application",
                        "name": "obs-studio-fov-sbom",
                        "version": "1.0.0",
                    }
                ]
            },
            "component": {
                "type": "application",
                "name": "obs-studio-fov",
                "version": version,
                "bom-ref": app_purl,
                "purl": app_purl,
            },
        },
        "components": components,
        "dependencies": [{"ref": app_purl, "dependsOn": refs}],
    }

    output = Path(args.output)
    if not output.is_absolute():
        output = ROOT / output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(bom, indent=2) + "\n")

    print(f"Wrote {output} ({len(components)} components)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
