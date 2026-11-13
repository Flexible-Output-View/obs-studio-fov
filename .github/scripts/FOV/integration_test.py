#!/usr/bin/env python3

import json
import os
import sys
import time
import urllib.request
from typing import List, Optional, TypedDict, Any


class Track(TypedDict):
    trackId: str
    name: str
    videoUrl: str
    isVideo: bool
    isAudio: bool


class Stream(TypedDict):
    streamId: str
    trackCount: int
    tracks: List[Track]
    title: str
    description: str
    visibility: str
    category: str
    viewers: int
    streamer: str
    streamerUsername: Optional[str]
    avatarUrl: str
    thumbnailUrl: str


ApiResponse = List[Stream]

API_URL: str = "http://localhost:4000/api/streams/available"
EXPECTED_TITLE: str = "Automated E2E Integration Test Stream"
EXPECTED_DESC: str = "Testing multi-track streaming, titles, descriptions, and authentication."
MAX_RETRIES: int = 180
INTERVAL: float = 1.0


def tail_log(filename: str = "obs-stdout.log", lines: int = 50) -> None:
    paths_to_check = [filename, f"../{filename}", f"web-fov/{filename}"]
    log_path: Optional[str] = None
    for p in paths_to_check:
        if os.path.exists(p):
            log_path = p
            break

    if log_path:
        print(f"=== Last {lines} lines of {log_path} ===")
        try:
            with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f.readlines()[-lines:]:
                    print(line, end="")
        except Exception as e:
            print(f"Could not read {log_path}: {e}")
    else:
        print(f"Log file '{filename}' not found.")


def main() -> None:
    print(f"Waiting for live stream with 2 video and 2 audio tracks in {API_URL}...")
    last_response: Optional[ApiResponse] = None

    for count in range(MAX_RETRIES + 1):
        try:
            req = urllib.request.Request(API_URL, headers={"Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=5) as resp:
                parsed: Any = json.loads(resp.read().decode("utf-8"))
                last_response = parsed if isinstance(parsed, list) else None
        except Exception:
            last_response = None

        stream_count = len(last_response) if last_response else 0
        target_stream: Optional[Stream] = None

        # Look for any non-demo active stream (or match our criteria)
        if last_response:
            for stream in last_response:
                # Skip permanent demo stream FOVDemo
                if stream.get("streamId") == "FOVDemo":
                    continue

                v_count = sum(1 for t in stream.get("tracks", []) if t.get("isVideo") is True)
                a_count = sum(1 for t in stream.get("tracks", []) if t.get("isAudio") is True)
                if v_count == 2 and a_count == 2:
                    target_stream = stream
                    break

        video_count = 0
        audio_count = 0
        stream_title = ""
        stream_desc = ""

        if target_stream:
            video_count = sum(1 for t in target_stream["tracks"] if t.get("isVideo") is True)
            audio_count = sum(1 for t in target_stream["tracks"] if t.get("isAudio") is True)
            stream_title = target_stream.get("title", "")
            stream_desc = target_stream.get("description", "")

        target_found = target_stream is not None

        if count % 5 == 0 or stream_count > 0:
            print(
                f"[{count}/{MAX_RETRIES}s] Total Streams: {stream_count} | Target Found: {int(target_found)} "
                f"| Video: {video_count} | Audio: {audio_count}"
            )

        # Verify tracks AND metadata (title/description)
        title_matches = stream_title == EXPECTED_TITLE
        desc_matches = stream_desc == EXPECTED_DESC

        if target_found and video_count == 2 and audio_count == 2:
            print("Stream successfully verified with 2 video and 2 audio tracks!")
            print(f"Verified Title: '{stream_title}' (Expected: '{EXPECTED_TITLE}') -> Match: {title_matches}")
            print(f"Verified Description: '{stream_desc}' (Expected: '{EXPECTED_DESC}') -> Match: {desc_matches}")
            print("Final API Payload:")
            print(json.dumps(last_response, indent=2))

            if not (title_matches and desc_matches):
                print("ERROR: Stream metadata (title or description) did not match expected values!")
                sys.exit(1)
            sys.exit(0)

        if count < MAX_RETRIES:
            time.sleep(INTERVAL)

    print(f"ERROR: Stream with required tracks and metadata was not detected after {MAX_RETRIES} seconds.")
    if last_response is not None:
        print(json.dumps(last_response, indent=2))
    tail_log("obs-stdout.log", 50)
    sys.exit(1)


if __name__ == "__main__":
    main()
