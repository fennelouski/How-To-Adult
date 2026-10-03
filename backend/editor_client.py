#!/usr/bin/env python3
"""Content editor client: Python standard library only, no AWS login required."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
from urllib.error import HTTPError
from urllib.request import HTTPRedirectHandler, Request, build_opener

from handler import EDITOR_TOKEN, ETAG, canonical, decode_json, png_dimensions

ALLOWED_ORIGINS = {
    "https://how-to-adult-guides.vercel.app",
    "https://m0jxoitx8f.execute-api.us-west-2.amazonaws.com",
}


def api_origin(value):
    if value not in ALLOWED_ORIGINS:
        raise ValueError("Use a verified How to Adult API origin from the credential file.")
    return value


def load_credentials(path=None):
    if path is None:
        value = {"HOWTOADULT_EDITOR_API_KEY": os.environ.get("HOWTOADULT_EDITOR_API_KEY", ""),
                 "HOWTOADULT_EDITOR_BASE_URL": os.environ.get("HOWTOADULT_EDITOR_BASE_URL", "https://how-to-adult-guides.vercel.app")}
    else:
        descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
        with os.fdopen(descriptor, "rb") as stream:
            info = os.fstat(stream.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_size > 16384:
                raise ValueError("Use a small, regular credential JSON file.")
            if os.name == "posix" and (info.st_uid != os.getuid() or info.st_mode & 0o077):
                raise ValueError("The credential file must belong to you and have mode 0600.")
            value = json.load(stream)
    if not isinstance(value, dict) or not isinstance(value.get("HOWTOADULT_EDITOR_API_KEY"), str) or not EDITOR_TOKEN.fullmatch(value["HOWTOADULT_EDITOR_API_KEY"]):
        raise ValueError("The editor credential is absent or malformed. Supply the securely provided credential file or environment variable.")
    api_origin(value.get("HOWTOADULT_EDITOR_BASE_URL"))
    return value


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Authorization is never forwarded to a redirected origin or path.
        return None


class EditorClient:
    def __init__(self, credential):
        self.base = api_origin(credential["HOWTOADULT_EDITOR_BASE_URL"])
        self.token = credential["HOWTOADULT_EDITOR_API_KEY"]
        self.opener = build_opener(NoRedirect())

    def request(self, path, method="GET", body=None, headers=None, authenticated=True):
        if not path.startswith("/v1/") or "?" in path or "#" in path or ".." in path:
            raise ValueError("Use a supported versioned API path.")
        request_headers = {"User-Agent": "HowToAdultEditor/1.0", **(headers or {})}
        if authenticated:
            if not path.startswith("/v1/editor/"):
                raise ValueError("The editor key may only be sent to editor routes.")
            request_headers["Authorization"] = "Bearer " + self.token
        request = Request(self.base + path, method=method, data=body, headers=request_headers)
        try:
            with self.opener.open(request, timeout=30) as result:
                data, status, response_headers = result.read(4 * 1024 * 1024 + 1), result.status, dict(result.headers)
        except HTTPError as error:
            # Never print a request object, raw response, or secret value.
            raise RuntimeError("Editor request returned HTTP " + str(error.code) + ". For 412, fetch the catalog, review the conflict, and rebuild the batch. For 401, check the securely supplied credential.") from None
        return status, data, {key.lower(): value for key, value in response_headers.items()}

    def status(self):
        return decode_json(self.request("/v1/editor/status")[1])

    def upload(self, path):
        data = Path(path).read_bytes()
        if len(data) > 2 * 1024 * 1024:
            raise ValueError("PNG uploads may not exceed 2 MB.")
        png_dimensions(data)
        digest = hashlib.sha256(data).hexdigest()
        return decode_json(self.request("/v1/editor/assets/" + digest, "PUT", data, {"Content-Type": "image/png"})[1])

    def publish(self, value, expected_etag):
        if not ETAG.fullmatch(expected_etag):
            raise ValueError("Supply the quoted ETag of the catalog you reviewed.")
        result = self.request("/v1/editor/guides", "POST", canonical(value),
                              {"Content-Type": "application/json", "If-Match": expected_etag})
        receipt = decode_json(result[1])
        receipt.update(etag=result[2].get("etag"), sourceRevision=result[2].get("x-release-revision"), api=self.base)
        return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--credentials", type=Path, help="Private mode-0600 credential JSON on this computer.")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("status")
    catalog = sub.add_parser("catalog")
    catalog.add_argument("--output", type=Path, required=True)
    upload = sub.add_parser("upload-image")
    upload.add_argument("image", type=Path)
    publish = sub.add_parser("publish")
    publish.add_argument("batch", type=Path)
    publish.add_argument("--expected-etag", required=True)
    publish.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    client = EditorClient(load_credentials(args.credentials))
    if args.command == "status":
        value = client.status()
    elif args.command == "catalog":
        status, data, headers = client.request("/v1/catalog", authenticated=False)
        decode_json(data)
        args.output.write_bytes(data)
        value = {"status": status, "etag": headers.get("etag"), "catalog": str(args.output)}
    elif args.command == "upload-image":
        value = client.upload(args.image)
    else:
        value = client.publish(decode_json(args.batch.read_bytes()), args.expected_etag)
        if args.receipt:
            args.receipt.write_text(json.dumps(value, indent=2) + "\n")
    print(json.dumps(value, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, RuntimeError, OSError) as error:
        raise SystemExit(str(error)) from None
