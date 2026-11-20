#!/usr/bin/env python3
import json
import os
import urllib.request
from typing import Any, Dict, Optional, TypedDict, Union


class AuthUser(TypedDict):
    id: int
    username: str
    email: str
    created_at: str


class AuthResponse(TypedDict):
    token: str
    user: AuthUser


class StreamSettings(TypedDict, total=False):
    streamId: str
    title: str
    description: str
    visibility: str
    thumbnailUrl: Optional[str]
    categoryId: Optional[int]
    category: str
    streamKey: Optional[str]
    isLive: bool
    createdAt: str
    updatedAt: str


class StreamKeyResponse(TypedDict):
    streamKey: str
    streamId: str
    isLive: bool
    updatedAt: str


API_BASE: str = "http://localhost:4000"
USERNAME: str = "TestStreamer"
EMAIL: str = "teststreamer@integration.local"
PASSWORD: str = "SecurePassword123!"
STREAM_TITLE: str = "Automated E2E Integration Test Stream"
STREAM_DESC: str = "Testing multi-track streaming, titles, descriptions, and authentication."


def api_request(
    endpoint: str,
    method: str = "GET",
    data: Optional[Dict[str, Any]] = None,
    token: Optional[str] = None,
) -> Any:
    url = f"{API_BASE}{endpoint}"
    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    body = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)

    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main() -> None:
    print("1. Registering test user account...")
    token: Optional[str] = None
    try:
        reg_res: AuthResponse = api_request(
            "/api/auth/register",
            method="POST",
            data={"username": USERNAME, "email": EMAIL, "password": PASSWORD},
        )
        token = reg_res.get("token")
    except Exception as e:
        print(f"Registration failed (might already exist): {e}, attempting login...")
        login_res: AuthResponse = api_request(
            "/api/auth/login",
            method="POST",
            data={"login": USERNAME, "password": PASSWORD},
        )
        token = login_res.get("token")

    if not token:
        raise RuntimeError("Failed to obtain authentication token.")
    print("Authentication token acquired successfully.")

    print("2. Updating stream title and description...")
    api_request(
        "/api/streams/me",
        method="PUT",
        data={
            "title": STREAM_TITLE,
            "description": STREAM_DESC,
            "visibility": "public",
        },
        token=token,
    )
    print(f"Stream metadata updated -> Title: '{STREAM_TITLE}'")

    print("3. Retrieving stream key...")
    key_res: StreamKeyResponse = api_request(
        "/api/streams/me/stream-key",
        method="GET",
        token=token,
    )
    stream_key: Optional[str] = key_res.get("streamKey")
    if not stream_key:
        raise RuntimeError("Stream key was not returned by the backend.")

    print(f"Stream key successfully retrieved: {stream_key[:8]}...")

    # Export stream key for GitHub Actions environment or local execution file
    github_env = os.getenv("GITHUB_ENV")
    if github_env:
        with open(github_env, "a") as f:
            f.write(f"FOV_INTEGRATION_TEST_KEY={stream_key}\n")

    # Also save locally for OBS startup script reference
    with open("obs_stream_key.txt", "w") as f:
        f.write(stream_key)
    print("Stream key saved to environment and obs_stream_key.txt")


if __name__ == "__main__":
    main()
