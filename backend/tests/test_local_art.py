import base64
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from handler import handle
from local import FileCatalogStore
from test_backend import event

ROOT = Path(__file__).resolve().parents[2]

class PublicSnapshotTests(unittest.TestCase):
    def test_local_reader_uses_exact_public_manifest_and_png_bytes(self):
        catalog = json.loads((ROOT / 'Content/catalog.json').read_bytes())
        manifest = json.loads((ROOT / 'Content/illustrations.json').read_bytes())
        with tempfile.TemporaryDirectory() as directory:
            store = FileCatalogStore(directory, ROOT / 'Content/illustrations.json', ROOT / 'content-assets/recovered')
            store.publish(catalog, create=True)
            response = handle(event('/v1/illustrations/' + catalog['revision']), store)
            self.assertEqual(response['statusCode'], 200)
            self.assertEqual(json.loads(response['body']), manifest)
            digest = manifest['items'][0]['assetSHA256']
            response = handle(event('/v1/assets/' + digest), store)
            self.assertEqual(response['statusCode'], 200)
            data = base64.b64decode(response['body'], validate=True)
            self.assertEqual(hashlib.sha256(data).hexdigest(), digest)
            self.assertEqual(data, (ROOT / 'content-assets/recovered' / (digest + '.png')).read_bytes())
            # A file on disk is not public merely because it has a digest name.
            # Synthetic fixture keeps this boundary check independent of private drafts.
            unlisted = Path(directory) / 'unlisted-art'
            unlisted.mkdir()
            fixture = b'not an admitted illustration'
            unlisted_digest = hashlib.sha256(fixture).hexdigest()
            (unlisted / (unlisted_digest + '.png')).write_bytes(fixture)
            isolated = FileCatalogStore(directory, ROOT / 'Content/illustrations.json', unlisted)
            self.assertEqual(handle(event('/v1/assets/' + unlisted_digest), isolated)['statusCode'], 404)

    def test_changed_catalog_cannot_use_an_older_snapshot_art(self):
        catalog = json.loads((ROOT / 'Content/catalog.json').read_bytes())
        manifest = json.loads((ROOT / 'Content/illustrations.json').read_bytes())
        with tempfile.TemporaryDirectory() as directory:
            store = FileCatalogStore(directory, ROOT / 'Content/illustrations.json', ROOT / 'content-assets/recovered')
            catalog['revision'] = 'local-different-revision'
            store.publish(catalog, create=True)
            response = handle(event('/v1/illustrations/' + catalog['revision']), store)
            self.assertEqual(json.loads(response['body'])['items'], [])
            self.assertEqual(handle(event('/v1/assets/' + manifest['items'][0]['assetSHA256']), store)['statusCode'], 404)
            self.assertEqual(handle(event('/v1/illustrations/' + manifest['revision']), store)['statusCode'], 404)
