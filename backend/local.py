"""Read-only localhost API and a durable local store for backend verification."""
import argparse
import base64
import fcntl
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import re
import tempfile
from urllib.parse import urlsplit

from handler import canonical, CatalogError, decode_json, handle, png_dimensions, timestamp, validate_catalog


class FileCatalogStore:
    def __init__(self, directory, illustration_manifest=None, assets=None):
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True)
        self.illustration_manifest = Path(illustration_manifest) if illustration_manifest else None
        self.assets = Path(assets) if assets else None

    def get_key(self, key):
        # Expose only the selected public snapshot, never the recovered draft art.
        history = re.fullmatch(r"revisions/([A-Za-z0-9][A-Za-z0-9._-]{0,95})\.json", key)
        if history:
            path = self.directory / (history[1] + ".json")
            if path.is_file():
                data = path.read_bytes()
                return data, '"' + hashlib.sha256(data).hexdigest() + '"'
            return None
        current = self.get()
        if current is None or self.illustration_manifest is None or not self.illustration_manifest.is_file():
            return None
        catalog = decode_json(current[0])
        manifest = decode_json(self.illustration_manifest.read_bytes())
        if manifest.get("schemaVersion") != 1 or manifest.get("revision") != catalog["revision"]:
            return None
        if key == "illustrations/" + catalog["revision"] + ".json":
            data = canonical(manifest)
            return data, '"' + hashlib.sha256(data).hexdigest() + '"'
        asset = re.fullmatch(r"assets/([0-9a-f]{64})\.png", key)
        if asset and self.assets and any(item.get("assetSHA256") == asset[1] for item in manifest.get("items", [])):
            path = self.assets / (asset[1] + ".png")
            if path.is_file():
                data = path.read_bytes()
                if hashlib.sha256(data).hexdigest() != asset[1]:
                    raise CatalogError("The local artwork does not match its publication digest.", 503)
                png_dimensions(data)
                return data, '"' + asset[1] + '"'
        return None

    def get(self):
        path = self.directory / "catalog.json"
        if not path.exists():
            return None
        import hashlib
        data = path.read_bytes()
        return data, '"' + hashlib.sha256(data).hexdigest() + '"'

    def publish(self, catalog, expected=None, create=False):
        validate_catalog(catalog)
        data = canonical(catalog)
        with (self.directory / "publication.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            current = self.get()
            if (create and current is not None) or (not create and (current is None or current[1] != expected)):
                raise CatalogError("The catalog changed. Fetch the current ETag and review your update.", 412)
            if current is not None and timestamp(catalog["publishedAt"]) < timestamp(decode_json(current[0])["publishedAt"]):
                raise CatalogError("A new publication cannot have an earlier publishedAt than the live library.", 409)
            history = self.directory / (catalog["revision"] + ".json")
            if history.exists() and history.read_bytes() != data:
                raise CatalogError("A publication revision cannot be reused for different content.", 409)
            if not history.exists():
                with history.open("xb") as file:
                    file.write(data)
                    file.flush()
                    os.fsync(file.fileno())
            with tempfile.NamedTemporaryFile(dir=self.directory, delete=False) as file:
                temporary = Path(file.name)
                try:
                    file.write(data)
                    file.flush()
                    os.fsync(file.fileno())
                    os.replace(temporary, self.directory / "catalog.json")
                finally:
                    temporary.unlink(missing_ok=True)
            return self.get()[1]


def serve(store, port):
    class Reader(BaseHTTPRequestHandler):
        def do_GET(self):
            parts = urlsplit(self.path)
            event = {"rawPath": parts.path, "rawQueryString": parts.query, "headers": dict(self.headers),
                     "requestContext": {"http": {"method": "GET"}}}
            result = handle(event, store)
            self.send_response(result["statusCode"])
            for key, value in result["headers"].items():
                self.send_header(key, value)
            body = base64.b64decode(result["body"], validate=True) if result.get("isBase64Encoded") else result["body"].encode("utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format, *args):
            # Search query text should not be printed even during local checks.
            pass

    server = ThreadingHTTPServer(("127.0.0.1", port), Reader)
    print("Read-only local guide API: http://127.0.0.1:" + str(server.server_port), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=Path(__file__).resolve().parents[1] / "Content" / "catalog.json")
    parser.add_argument("--store", type=Path, default=Path(__file__).resolve().parent / "local-store")
    parser.add_argument("--illustrations", type=Path, default=Path(__file__).resolve().parents[1] / "Content" / "illustrations.json")
    parser.add_argument("--assets", type=Path, default=Path(__file__).resolve().parents[1] / "content-assets" / "recovered")
    parser.add_argument("--port", type=int, default=8769)
    options = parser.parse_args()
    store = FileCatalogStore(options.store, options.illustrations, options.assets)
    if store.get() is None:
        store.publish(validate_catalog(decode_json(options.catalog.read_bytes())), create=True)
    serve(store, options.port)


if __name__ == "__main__":
    main()
