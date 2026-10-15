import base64
from concurrent.futures import ThreadPoolExecutor
import copy
import hashlib
import json
import os
from pathlib import Path
import struct
import tempfile
import threading
import unittest
import zlib

from editor_client import api_origin, EditorClient, load_credentials, NoRedirect
from handler import canonical, CatalogError, decode_json, handle, png_dimensions, S3CatalogStore
from infrastructure import template, vercel_output
from provision_editor import provision
from test_backend import fixture, event

TOKEN = "hta_ed_" + "A" * 43
DIGEST = hashlib.sha256(TOKEN.encode()).hexdigest()


def png(width=2, height=2):
    def chunk(kind, data):
        return struct.pack("!I", len(data)) + kind + data + struct.pack("!I", zlib.crc32(kind + data) & 0xffffffff)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack("!IIBBBBB", width, height, 8, 2, 0, 0, 0)) + chunk(
        b"IDAT", zlib.compress((b"\x00" + b"\x24\xb3\xa8" * width) * height)) + chunk(b"IEND", b"")


class MemoryStore(S3CatalogStore):
    def __init__(self):
        self.objects = {}
        self.lock = threading.Lock()

    def get_key(self, key):
        with self.lock:
            return self.objects.get(key)

    def conditional_put(self, key, data, expected=None, create=False, **options):
        with self.lock:
            current = self.objects.get(key)
            if (create and current is not None) or (not create and (current is None or current[1] != expected)):
                raise CatalogError("Conditional write conflict", 412)
            etag = '"' + hashlib.sha256(data).hexdigest() + '"'
            self.objects[key] = data, etag
            return etag


class EditorTests(unittest.TestCase):
    def setUp(self):
        self.store = MemoryStore()
        self.etag = self.store.publish(fixture(), create=True)
        self.headers = {"Authorization": "Bearer " + TOKEN, "Content-Type": "application/json", "If-Match": self.etag}

    def call(self, path, method="GET", body=None, headers=None, key=DIGEST, conditional=True):
        return handle(event(path, method, self.headers if headers is None else headers, body), self.store,
                      "a" * 40, conditional, key)

    def batch(self, revision="fixture-editor-2", **changes):
        article = copy.deepcopy(fixture()["articles"][0])
        article["id"] = "new-useful-guide"
        return {"revision": revision, "publishedAt": "2026-10-02T00:00:00Z", "articles": [article],
                "categories": [], "replaceExisting": False, "illustrations": [], **changes}

    def test_fail_closed_missing_wrong_disabled_and_query_credentials(self):
        for headers, key in (({}, DIGEST), ({"Authorization": "Bearer " + TOKEN[:-1] + "B"}, DIGEST),
                             (self.headers, ""), ({"Authorization": "Basic " + TOKEN}, DIGEST)):
            self.assertEqual(self.call("/v1/editor/status", headers=headers, key=key)["statusCode"], 401)
        e = event("/v1/editor/status", headers={})
        e["rawQueryString"] = "api_key=" + TOKEN
        self.assertEqual(handle(e, self.store, editor_key_sha256=DIGEST)["statusCode"], 401)

    def test_status_reports_scopes_without_secret(self):
        result = self.call("/v1/editor/status")
        self.assertEqual(result["statusCode"], 200)
        self.assertEqual(json.loads(result["body"])["scopes"], ["guides:upsert", "assets:create"])
        self.assertNotIn(TOKEN, result["body"])
        self.assertNotIn(DIGEST, result["body"])

    def test_editor_cannot_use_iam_full_replacement_route(self):
        result = self.call("/v1/publication", "PUT", fixture())
        self.assertEqual(result["statusCode"], 403)
        self.assertEqual(self.store.get()[1], self.etag)

    def test_new_batch_preserves_omitted_guides_and_history(self):
        result = self.call("/v1/editor/guides", "POST", self.batch())
        self.assertEqual(result["statusCode"], 200, result)
        current = decode_json(self.store.get()[0])
        self.assertEqual(len(current["articles"]), 2)
        self.assertEqual(current["articles"][0], fixture()["articles"][0])
        self.assertEqual(decode_json(self.store.get_key("revisions/fixture-1.json")[0]), fixture())

    def test_explicit_updates_only_and_no_unknown_fields(self):
        updated = copy.deepcopy(fixture()["articles"][0])
        updated["title"] = "An explicitly reviewed correction"
        value = self.batch(articles=[updated])
        self.assertEqual(self.call("/v1/editor/guides", "POST", value)["statusCode"], 409)
        value["replaceExisting"] = True
        self.assertEqual(self.call("/v1/editor/guides", "POST", value)["statusCode"], 200)
        self.headers["If-Match"] = self.store.get()[1]
        value = self.batch(revision="fixture-editor-3", delete=[updated["id"]])
        self.assertEqual(self.call("/v1/editor/guides", "POST", value)["statusCode"], 422)

    def test_stale_or_missing_precondition_and_batch_limits(self):
        for etag, expected in ((None, 428), ('"outdated"', 412), ("*", 428)):
            headers = self.headers.copy()
            if etag is None:
                del headers["If-Match"]
            else:
                headers["If-Match"] = etag
            self.assertEqual(self.call("/v1/editor/guides", "POST", self.batch(), headers)["statusCode"], expected)
        for articles in ([], [fixture()["articles"][0]] * 26):
            self.assertEqual(self.call("/v1/editor/guides", "POST", self.batch(articles=articles))["statusCode"], 422)
        self.assertEqual(self.store.get()[1], self.etag)

    def test_publication_time_must_advance(self):
        self.assertEqual(self.call("/v1/editor/guides", "POST", self.batch(publishedAt=fixture()["publishedAt"]))["statusCode"], 409)

    def test_failed_revision_reuse_cannot_attach_images_to_old_history(self):
        self.assertEqual(self.call("/v1/editor/guides", "POST", self.batch())["statusCode"], 200)
        self.headers["If-Match"] = self.store.get()[1]
        reused = self.batch(revision="fixture-1", publishedAt="2026-10-02T00:00:01Z")
        self.assertEqual(self.call("/v1/editor/guides", "POST", reused)["statusCode"], 409)
        self.assertIsNone(self.store.get_key("illustrations/fixture-1.json"))

    def test_parallel_publish_has_one_winner(self):
        def write(index):
            return self.call("/v1/editor/guides", "POST", self.batch(revision="parallel-" + str(index)))["statusCode"]
        with ThreadPoolExecutor(max_workers=2) as pool:
            self.assertEqual(sorted(pool.map(write, (1, 2))), [200, 412])

    def upload(self, data=None):
        data = png() if data is None else data
        digest = hashlib.sha256(data).hexdigest()
        e = event("/v1/editor/assets/" + digest, "PUT", {"Authorization": "Bearer " + TOKEN, "Content-Type": "image/png"})
        e.update(body=base64.b64encode(data).decode(), isBase64Encoded=True)
        return handle(e, self.store, editor_key_sha256=DIGEST), digest

    def test_upload_retries_and_binary_round_trip(self):
        result, digest = self.upload()
        self.assertEqual(result["statusCode"], 200, result)
        self.assertEqual(self.upload()[0]["statusCode"], 200)
        read = self.call("/v1/assets/" + digest, headers={})
        self.assertEqual(read["statusCode"], 200)
        self.assertEqual(base64.b64decode(read["body"]), png())
        self.assertTrue(read["isBase64Encoded"])
        self.assertEqual(read["headers"]["content-type"], "image/png")

    def test_unsafe_corrupt_oversize_and_mismatched_images_rejected(self):
        for data, status in ((b"<svg></svg>", 415), (png()[:-1], 422), (png() + b"extra", 422), (b"x" * (2 * 1024 * 1024 + 1), 413)):
            self.assertEqual(self.upload(data)[0]["statusCode"], status)
        e = event("/v1/editor/assets/" + "0" * 64, "PUT", {"Authorization": "Bearer " + TOKEN, "Content-Type": "image/png"})
        e.update(body=base64.b64encode(png()).decode(), isBase64Encoded=True)
        self.assertEqual(handle(e, self.store, editor_key_sha256=DIGEST)["statusCode"], 422)
        with self.assertRaises(CatalogError):
            png_dimensions(png(width=4097, height=1))

    def test_illustrations_follow_catalog_and_survive_iam_publication(self):
        _, digest = self.upload()
        image = {"guideID": "new-useful-guide", "stepID": "", "assetSHA256": digest,
                 "altText": "A teaching diagram", "caption": "", "creator": "How to Adult", "license": "Original artwork", "provenance": "Created for this guide"}
        value = self.batch(illustrations=[image])
        self.assertEqual(self.call("/v1/editor/guides", "POST", value)["statusCode"], 200)
        manifest = json.loads(self.call("/v1/illustrations", headers={})["body"])
        self.assertEqual(manifest["revision"], value["revision"])
        self.assertEqual(manifest["items"], [image])
        current = decode_json(self.store.get()[0])
        current.update(revision="iam-next", publishedAt="2026-10-02T00:00:01Z")
        self.store.publish(current, self.store.get()[1])
        manifest = json.loads(self.call("/v1/illustrations", headers={})["body"])
        self.assertEqual(manifest["revision"], "iam-next")
        self.assertEqual(manifest["items"], [image])
        historical = self.call("/v1/illustrations/" + value["revision"], headers={})
        self.assertEqual(json.loads(historical["body"])["revision"], value["revision"])
        self.assertEqual(json.loads(historical["body"])["items"], [image])
        self.assertIn("immutable", historical["headers"]["cache-control"])
        self.assertEqual(self.call("/v1/illustrations/unpublished-revision", headers={})["statusCode"], 404)

    def test_missing_asset_or_empty_alt_text_cannot_be_associated(self):
        image = {"guideID": "new-useful-guide", "stepID": "", "assetSHA256": "0" * 64,
                 "altText": "A diagram", "caption": "", "creator": "How to Adult", "license": "Original", "provenance": "Created locally"}
        self.assertEqual(self.call("/v1/editor/guides", "POST", self.batch(illustrations=[image]))["statusCode"], 422)
        _, image["assetSHA256"] = self.upload()
        image["altText"] = ""
        self.assertEqual(self.call("/v1/editor/guides", "POST", self.batch(illustrations=[image]))["statusCode"], 422)
        self.assertEqual(self.store.get()[1], self.etag)

    def test_write_disabled_sdk_and_unsupported_routes(self):
        self.assertEqual(self.call("/v1/editor/guides", "POST", self.batch(), conditional=False)["statusCode"], 503)
        self.assertEqual(self.call("/v1/editor/guides", "DELETE")["statusCode"], 404)


class CredentialTests(unittest.TestCase):
    def test_private_provisioning_non_overwrite_and_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            os.chmod(directory, 0o700)
            path = Path(directory) / "key.json"
            provision(path)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            credential = load_credentials(path)
            self.assertTrue(credential["HOWTOADULT_EDITOR_API_KEY"].startswith("hta_ed_"))
            with self.assertRaises(ValueError):
                provision(path)
            path.chmod(0o644)
            with self.assertRaises(ValueError):
                load_credentials(path)

    def test_credential_origin_and_redirect_restrictions(self):
        for value in ("https://example.com", "http://how-to-adult-guides.vercel.app", "https://how-to-adult-guides.vercel.app/", "https://how-to-adult-guides.vercel.app@evil.example"):
            with self.assertRaises(ValueError):
                api_origin(value)
        self.assertIsNone(NoRedirect().redirect_request(None, None, 302, "Moved", {}, "https://example.com"))
        client = EditorClient({"HOWTOADULT_EDITOR_BASE_URL": "https://how-to-adult-guides.vercel.app", "HOWTOADULT_EDITOR_API_KEY": TOKEN})
        with self.assertRaises(ValueError):
            client.request("/v1/publication")
        with self.assertRaises(ValueError):
            client.request("/v1/editor/../publication")

    def test_infrastructure_hash_only_and_exact_relay_routes(self):
        body = template("a" * 40)
        self.assertTrue(body["Parameters"]["EditorKeySHA256"]["NoEcho"])
        self.assertEqual(body["Resources"]["Function"]["Properties"]["Environment"]["Variables"]["EDITOR_KEY_SHA256"], {"Ref": "EditorKeySHA256"})
        self.assertNotIn(TOKEN, json.dumps(body))
        with tempfile.TemporaryDirectory() as directory:
            vercel_output("https://test123.execute-api.us-west-2.amazonaws.com", "a" * 40, directory)
            routes = json.loads((Path(directory) / ".vercel/output/config.json").read_text())["routes"]
            self.assertEqual(routes[1]["methods"], ["POST"])
            self.assertEqual(routes[2]["methods"], ["PUT"])
            self.assertFalse(any("publication" in route.get("src", "") for route in routes))
