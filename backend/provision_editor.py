#!/usr/bin/env python3
"""Generate a new content-only key without printing it or placing it in Git."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import secrets

from editor_client import ALLOWED_ORIGINS


def provision(path):
    path = Path(path).expanduser().absolute()
    root = Path(__file__).resolve().parents[1]
    if path.is_relative_to(root) or path.exists() or path.is_symlink():
        raise ValueError("Choose a new credential path outside the repository. Existing credentials are never overwritten.")
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    if os.name == "posix" and (path.parent.stat().st_uid != os.getuid() or path.parent.stat().st_mode & 0o077):
        raise ValueError("Use a private parent directory owned by you, mode 0700.")
    value = {"HOWTOADULT_EDITOR_API_KEY": "hta_ed_" + secrets.token_urlsafe(32),
             "HOWTOADULT_EDITOR_BASE_URL": "https://how-to-adult-guides.vercel.app",
             "allowedOrigins": sorted(ALLOWED_ORIGINS), "scopes": ["guides:upsert", "assets:create"],
             "createdAt": datetime.now(timezone.utc).isoformat()}
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as stream:
        json.dump(value, stream, indent=2)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    return path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print("Created private credential file: " + str(provision(args.output)))
    print("No secret was printed. Deploy its hash using backend/deploy.py --editor-key-file.")
