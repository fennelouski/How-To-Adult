import copy
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import io
import json
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import deploy
from deploy import assert_artifacts, assert_release_source, bootstrap, check_mode, deploy_aws, deploy_vercel, freeze_source, prepare
from handler import canonical, CatalogError, decode_json, handle, S3CatalogStore, validate_catalog
from infrastructure import template, vercel_output
from local import FileCatalogStore
from publish import api_origin, publish

try:
    import boto3
    from botocore.stub import Stubber
except ImportError:
    boto3 = None


def fixture():
    return {"schemaVersion": 1, "revision": "fixture-1", "publishedAt": "2026-10-01T00:00:00Z",
        "categories": [{"id": "home", "title": "Home", "symbol": "house", "colorKey": "teal"}],
        "articles": [{"id": "wash-your-clothes", "title": "Wash your clothes", "summary": "Sort, wash, dry.",
            "categoryID": "home", "symbol": "washer", "minutes": 15, "jurisdiction": "General", "updatedAt": "2026-10-01",
            "tags": ["laundry", "clothes"], "tools": ["Detergent"], "steps": [
                {"id": "read-label", "title": "Read the label", "body": "Check the care instructions."},
                {"id": "sort", "title": "Sort your laundry", "body": "Separate clothes as their labels require."}],
            "cautions": [], "sources": []}]}


def event(path="/v1/catalog", method="GET", headers=None, body=None, iam=False, query=""):
    context = {"http": {"method": method}}
    if iam:
        context["authorizer"] = {"iam": {"userArn": "arn:aws:iam::111122223333:role/editor-fixture"}}
    return {"rawPath": path, "rawQueryString": query, "headers": headers or {}, "requestContext": context,
            "body": "" if body is None else canonical(body).decode(), "isBase64Encoded": False}


class ValidationTests(unittest.TestCase):
    def test_original_low_stakes_guides_can_have_no_sources(self):
        self.assertEqual(validate_catalog(fixture())["articles"][0]["sources"], [])

    def test_duplicate_ids_and_missing_category_are_rejected(self):
        for mutate in (lambda value: value["articles"].append(copy.deepcopy(value["articles"][0])),
                       lambda value: value["articles"][0].update(categoryID="missing"),
                       lambda value: value["categories"].append(copy.deepcopy(value["categories"][0])),
                       lambda value: value["articles"][0]["steps"].append(copy.deepcopy(value["articles"][0]["steps"][0]))):
            value = fixture()
            mutate(value)
            with self.assertRaises(CatalogError):
                validate_catalog(value)

    def test_schema_dates_and_unknown_fields_are_rejected(self):
        for update in ({"schemaVersion": True}, {"schemaVersion": 2}, {"notes": "Private user notes do not belong here"},
                       {"revision": "../../outside"}, {"publishedAt": "2026-02-31T00:00:00Z"},
                       {"publishedAt": "2026-10-01T00:00:00+00:00"}, {"publishedAt": "2099-01-01T00:00:00Z"}):
            with self.subTest(update=update):
                value = fixture()
                value.update(update)
                with self.assertRaises(CatalogError):
                    validate_catalog(value)

    def test_invalid_field_types_are_validation_errors(self):
        for mutate in (lambda value: value["categories"][0].update(colorKey=[]),
                       lambda value: value["articles"][0].update(categoryID=[]),
                       lambda value: value["articles"][0].update(minutes=True),
                       lambda value: value["articles"][0].update(steps=[]),
                       lambda value: value["articles"][0].update(updatedAt="2026-10-02")):
            value = fixture()
            mutate(value)
            with self.assertRaises(CatalogError):
                validate_catalog(value)

    def test_public_primary_source_url_passes(self):
        value = fixture()
        value["articles"][0]["sources"] = [{"title": "Federal Trade Commission", "url": "https://consumer.ftc.gov/"}]
        self.assertEqual(validate_catalog(value), value)

    def test_private_credential_and_invalid_sources_fail(self):
        for url in ("http://example.com/", "https://127.0.0.1/", "https://localhost/", "https://service.internal/", "https://user:password@example.com/", "https://example.com/?token=private", "https://example.com:8443/", "https://example.com/a b"):
            value = fixture()
            value["articles"][0]["sources"] = [{"title": "Invalid fixture", "url": url}]
            with self.subTest(url=url), self.assertRaises(CatalogError):
                validate_catalog(value)

    def test_duplicate_json_fields_and_nan_fail(self):
        for data in (b'{"revision":"a","revision":"b"}', b'{"number":NaN}', b"\xff"):
            with self.assertRaises(CatalogError):
                decode_json(data)

    def test_publications_stay_within_native_reader_contract(self):
        for mutate in (lambda value: value.update(categories=[{**value["categories"][0], "id": "category-" + str(index)} for index in range(31)]),
                       lambda value: value["articles"][0]["steps"][0].update(body="x" * 8001),
                       lambda value: value["articles"][0].update(tools=["Detergent", "Detergent"]),
                       lambda value: value["articles"][0].update(tags=["Laundry", "Laundry"]),
                       lambda value: value["articles"][0].update(cautions=["Read the label", "Read the label"]),
                       lambda value: value["articles"][0].update(sources=[{"title": "Source", "url": "https://consumer.ftc.gov/"}] * 2)):
            value = fixture()
            mutate(value)
            with self.assertRaises(CatalogError):
                validate_catalog(value)


class StoreAndAPITests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.store = FileCatalogStore(self.directory.name)
        self.catalog = fixture()
        self.etag = self.store.publish(self.catalog, create=True)

    def tearDown(self):
        self.directory.cleanup()

    def result(self, request):
        return handle(request, self.store, "a" * 40)

    def test_full_catalog_offline_store_and_health(self):
        result = self.result(event())
        self.assertEqual(result["statusCode"], 200)
        self.assertEqual(json.loads(result["body"]), self.catalog)
        self.assertEqual(result["headers"]["etag"], self.etag)
        reopened = FileCatalogStore(self.directory.name)
        self.assertEqual(reopened.get(), self.store.get())
        health = json.loads(self.result(event("/health"))["body"])
        self.assertEqual(health["catalogRevision"], self.catalog["revision"])
        self.assertFalse(health["personalActivityStored"])

    def test_cache_304_includes_etag_without_body(self):
        for header in (self.etag, "W/" + self.etag, '"different", ' + self.etag, "*"):
            result = self.result(event(headers={"If-None-Match": header}))
            self.assertEqual(result["statusCode"], 304)
            self.assertEqual(result["body"], "")
            self.assertEqual(result["headers"]["etag"], self.etag)

    def test_individual_article_and_missing_route(self):
        found = self.result(event("/v1/articles/wash-your-clothes"))
        self.assertEqual(found["statusCode"], 200)
        self.assertEqual(json.loads(found["body"]), self.catalog["articles"][0])
        for path in ("/v1/articles/no-such-guide", "/v1/articles/../escape", "/private", "/v1/catalog/"):
            self.assertEqual(self.result(event(path))["statusCode"], 404)

    def test_search_matches_all_words_and_category(self):
        found = self.result(event("/v1/articles", query="q=wash+clothes&category=home&jurisdiction=General"))
        value = json.loads(found["body"])
        self.assertEqual(found["statusCode"], 200)
        self.assertEqual(value["total"], 1)
        self.assertNotIn("steps", value["articles"][0])
        self.assertEqual(json.loads(self.result(event("/v1/articles", query="q=unknown"))["body"])["total"], 0)

    def test_pagination_is_stable_and_bounded(self):
        value = fixture()
        value["revision"] = "fixture-many"
        value["articles"] = [{**copy.deepcopy(value["articles"][0]), "id": "guide-" + str(index)} for index in range(5)]
        self.store.publish(value, expected=self.etag)
        first = json.loads(self.result(event("/v1/articles", query="limit=2"))["body"])
        second = json.loads(self.result(event("/v1/articles", query="limit=2&offset=2"))["body"])
        last = json.loads(self.result(event("/v1/articles", query="limit=2&offset=4"))["body"])
        self.assertEqual(first["nextOffset"], 2)
        self.assertEqual(second["nextOffset"], 4)
        self.assertIsNone(last["nextOffset"])
        self.assertEqual([item["id"] for page in (first, second, last) for item in page["articles"]], ["guide-" + str(index) for index in range(5)])

    def test_unsupported_search_and_parameters_fail(self):
        for query in ("category=unknown", "q=a&q=b", "secret=private", "limit=0", "limit=101", "offset=-1", "offset=2001", "limit=wrong"):
            self.assertEqual(self.result(event("/v1/articles", query=query))["statusCode"], 400)
        self.assertEqual(self.result(event(query="q=test"))["statusCode"], 400)

    def test_unauthenticated_publication_does_not_write(self):
        result = self.result(event("/v1/publication", "PUT", {"Content-Type": "application/json", "If-Match": self.etag}, fixture()))
        self.assertEqual(result["statusCode"], 403)
        self.assertEqual(self.store.get()[1], self.etag)

    def test_missing_or_invalid_publication_precondition_does_not_write(self):
        for headers in ({}, {"If-Match": "*"}, {"If-None-Match": "wrong"}, {"If-Match": self.etag, "If-None-Match": "*"}):
            result = self.result(event("/v1/publication", "PUT", {"Content-Type": "application/json", **headers}, fixture(), iam=True))
            self.assertEqual(result["statusCode"], 428)
        self.assertEqual(self.store.get()[1], self.etag)

    def test_invalid_publication_and_media_type_do_not_write(self):
        invalid = fixture()
        invalid["privateNotes"] = "Not an editorial field"
        headers = {"Content-Type": "application/json", "If-Match": self.etag}
        self.assertEqual(self.result(event("/v1/publication", "PUT", headers, invalid, iam=True))["statusCode"], 422)
        self.assertEqual(self.result(event("/v1/publication", "PUT", {"If-Match": self.etag}, fixture(), iam=True))["statusCode"], 415)
        self.assertEqual(self.store.get()[1], self.etag)

    def test_publication_with_current_tag_changes_catalog_and_preserves_history(self):
        update = fixture()
        update["revision"] = "fixture-2"
        update["articles"][0]["title"] = "Laundry made simpler"
        result = self.result(event("/v1/publication", "PUT", {"Content-Type": "application/json", "If-Match": self.etag}, update, iam=True))
        self.assertEqual(result["statusCode"], 200)
        self.assertNotEqual(result["headers"]["etag"], self.etag)
        self.assertEqual(decode_json(self.store.get()[0]), update)
        self.assertEqual(decode_json((Path(self.directory.name) / "fixture-1.json").read_bytes()), fixture())

    def test_stale_update_and_revision_reuse_do_not_overwrite(self):
        update = fixture()
        update["revision"] = "fixture-2"
        current_etag = self.store.publish(update, expected=self.etag)
        stale = fixture()
        stale["revision"] = "fixture-3"
        with self.assertRaises(CatalogError) as stale_error:
            self.store.publish(stale, expected=self.etag)
        self.assertEqual(stale_error.exception.status, 412)
        reused = fixture()
        reused["articles"][0]["title"] = "Revision IDs are immutable"
        with self.assertRaises(CatalogError) as reuse_error:
            self.store.publish(reused, expected=current_etag)
        self.assertEqual(reuse_error.exception.status, 409)
        self.assertEqual(self.store.get()[1], current_etag)

    def test_two_concurrent_editors_cannot_both_overwrite(self):
        def update(index):
            value = fixture()
            value["revision"] = "editor-" + str(index)
            try:
                self.store.publish(value, expected=self.etag)
                return 200
            except CatalogError as error:
                return error.status
        with ThreadPoolExecutor(max_workers=2) as pool:
            self.assertEqual(sorted(pool.map(update, (1, 2))), [200, 412])

    def test_older_publication_date_cannot_create_update_native_reader_would_ignore(self):
        update = fixture()
        update["revision"] = "fixture-older"
        update["publishedAt"] = "2026-09-30T23:59:59Z"
        update["articles"][0]["updatedAt"] = "2026-09-30"
        with self.assertRaises(CatalogError) as error:
            self.store.publish(update, expected=self.etag)
        self.assertEqual(error.exception.status, 409)
        self.assertEqual(self.store.get()[1], self.etag)

    def test_empty_catalog_is_unavailable_and_first_publish_cannot_replace(self):
        with tempfile.TemporaryDirectory() as directory:
            empty = FileCatalogStore(directory)
            self.assertEqual(handle(event(), empty)["statusCode"], 503)
            self.assertFalse(json.loads(handle(event("/health"), empty)["body"])["published"])
            first = handle(event("/v1/publication", "PUT", {"Content-Type": "application/json", "If-None-Match": "*"}, fixture(), iam=True), empty)
            self.assertEqual(first["statusCode"], 200)
            second = handle(event("/v1/publication", "PUT", {"Content-Type": "application/json", "If-None-Match": "*"}, fixture(), iam=True), empty)
            self.assertEqual(second["statusCode"], 412)

    def test_sdk_without_conditional_writes_cannot_publish(self):
        result = handle(event("/v1/publication", "PUT", {"Content-Type": "application/json", "If-Match": self.etag}, fixture(), iam=True), self.store, conditional_writes=False)
        self.assertEqual(result["statusCode"], 503)


class InfrastructureTests(unittest.TestCase):
    def test_first_publication_can_distinguish_missing_key_from_denied_access(self):
        resources = template("a" * 40)["Resources"]
        statements = resources["Role"]["Properties"]["Policies"][0]["PolicyDocument"]["Statement"]
        grants = [statement for statement in statements if statement.get("Effect") == "Allow" and statement.get("Action") == "s3:ListBucket"]
        self.assertEqual(len(grants), 1)
        self.assertEqual(grants[0]["Resource"], {"Fn::GetAtt": ["Catalog", "Arn"]})
        # GetObject supplies no ListObjects Prefix parameter, so an s3:prefix
        # condition here would recreate the first-publication denial.
        self.assertNotIn("Condition", grants[0])
        self.assertFalse(any("s3:Delete" in str(statement.get("Action")) for statement in statements))

    def test_retained_private_versioned_store_and_iam_editor_only(self):
        resources = template("a" * 40)["Resources"]
        bucket = resources["Catalog"]
        self.assertEqual(bucket["DeletionPolicy"], "Retain")
        self.assertEqual(bucket["UpdateReplacePolicy"], "Retain")
        self.assertEqual(bucket["Properties"]["VersioningConfiguration"]["Status"], "Enabled")
        self.assertTrue(all(bucket["Properties"]["PublicAccessBlockConfiguration"].values()))
        self.assertEqual(resources["Publication"]["Properties"]["AuthorizationType"], "AWS_IAM")
        self.assertTrue(all(resources[name]["Properties"]["AuthorizationType"] == "NONE" for name in ("Health", "ReadCatalog", "ReadArticle", "SearchArticles")))
        self.assertNotIn("AccessLogSettings", resources["Stage"]["Properties"])
        self.assertEqual(resources["Logs"]["Properties"]["RetentionInDays"], 7)
        self.assertFalse(any("EventBridge" in value["Type"] or "Scheduler" in value["Type"] for value in resources.values()))

    def test_vercel_is_a_read_only_gateway_with_independent_provenance(self):
        with tempfile.TemporaryDirectory() as directory:
            release = vercel_output("https://test123.execute-api.us-west-2.amazonaws.com", "b" * 40, directory)
            build = Path(directory) / ".vercel" / "output"
            routes = json.loads((build / "config.json").read_text())["routes"]
            self.assertEqual(routes[0]["methods"], ["GET"])
            self.assertNotIn("publication", routes[0]["src"])
            self.assertEqual(release["sourceRevision"], "b" * 40)
            self.assertEqual(json.loads((build / "static" / "release.json").read_text()), release)
            self.assertFalse(json.loads((Path(directory) / "vercel.json").read_text())["git"]["deploymentEnabled"])

    def test_cutoff_and_cutover_prevent_old_parallel_command(self):
        before = datetime(2026, 10, 21, tzinfo=timezone.utc)
        cutoff = datetime(2026, 10, 22, 7, tzinfo=timezone.utc)
        check_mode("parallel", {}, before)
        for state, now in (({}, cutoff), ({"mode": "aws-only"}, before), ({"actualCutoverAt": "2026-10-21T07:00:00Z"}, before)):
            with self.assertRaises(RuntimeError):
                check_mode("parallel", state, now)
        with self.assertRaises(RuntimeError):
            check_mode("aws-only", {"actualCutoverAt": "2026-10-22T07:00:00Z"}, cutoff)
        check_mode("aws-only", {"mode": "aws-only", "actualCutoverAt": "2026-10-22T07:00:00Z", "cutoverVerified": True, "productionRoutingOwner": "AWS"}, cutoff)

    def test_signed_publication_credentials_cannot_be_sent_to_other_origins(self):
        valid = "https://test123.execute-api.us-west-2.amazonaws.com"
        self.assertEqual(api_origin(valid, "us-west-2"), valid)
        for origin in ("https://example.com", valid + "/path", valid + "?redirect=https://example.com", "http://test123.execute-api.us-west-2.amazonaws.com", "https://test123.execute-api.us-east-1.amazonaws.com"):
            with self.assertRaises(ValueError):
                api_origin(origin, "us-west-2")

    def test_template_fits_cloudformation_inline_request_limit(self):
        with tempfile.TemporaryDirectory() as directory:
            path = prepare("a" * 40, Path(directory))
            self.assertLess(len(path.read_bytes()), 51200)


class ReleaseSourceTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        (self.root / "backend").mkdir()
        (self.root / "Content").mkdir()
        (self.root / ".gitignore").write_text("release-output/\n")
        (self.root / "backend" / "handler.py").write_text("def main(event, context):\n    return 1\n")
        (self.root / "Content" / "catalog.json").write_bytes(canonical(fixture()))
        self.git("init", "--quiet")
        self.git("add", ".")
        self.git("-c", "user.name=Release Fixture", "-c", "user.email=release@example.invalid", "commit", "--quiet", "-m", "Initial fixture")
        self.revision = self.git("rev-parse", "HEAD").stdout.strip()
        self.paths = ("backend/handler.py", "Content/catalog.json")
        self.root_patch = patch("deploy.ROOT", self.root)
        self.root_patch.start()
        self.frozen = freeze_source(self.revision, self.paths)

    def tearDown(self):
        self.root_patch.stop()
        self.directory.cleanup()

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.root, text=True, capture_output=True, check=True)

    def test_generated_template_uses_committed_source_even_after_local_mutation(self):
        source = self.frozen["files"]["backend/handler.py"]["text"]
        (self.root / "backend" / "handler.py").write_text("def main(event, context):\n    return 2\n")
        built = template(self.revision, handler_source=source)
        self.assertEqual(built["Resources"]["Function"]["Properties"]["Code"]["ZipFile"], source)
        with self.assertRaises(RuntimeError):
            assert_release_source(self.frozen)

    def test_untracked_change_and_changed_head_are_rejected(self):
        (self.root / "new-source.py").write_text("# An uncommitted source change\n")
        with self.assertRaises(RuntimeError):
            assert_release_source(self.frozen)
        self.git("add", ".")
        self.git("-c", "user.name=Release Fixture", "-c", "user.email=release@example.invalid", "commit", "--quiet", "-m", "Changed fixture")
        with self.assertRaises(RuntimeError):
            assert_release_source(self.frozen)

    def test_source_hash_catches_changes_hidden_by_assume_unchanged(self):
        self.git("update-index", "--assume-unchanged", "backend/handler.py")
        (self.root / "backend" / "handler.py").write_text("def main(event, context):\n    return 3\n")
        self.assertEqual(self.git("status", "--porcelain").stdout, "")
        with self.assertRaises(RuntimeError):
            assert_release_source(self.frozen)

    def test_frozen_config_digest_rejects_artifact_tampering(self):
        artifacts = {}
        target = self.root / "release-output" / "vercel"
        handler_sha = self.frozen["files"]["backend/handler.py"]["sha256"]
        release = vercel_output("https://test123.execute-api.us-west-2.amazonaws.com", self.revision, target,
            handler_sha256=handler_sha, artifact_snapshot=artifacts)
        self.assertEqual(release["handlerSHA256"], handler_sha)
        assert_artifacts(artifacts)
        config = target / ".vercel" / "output" / "config.json"
        config.write_text(config.read_text().replace("execute-api", "changed-origin"))
        with self.assertRaises(RuntimeError):
            assert_artifacts(artifacts)

    def test_template_mutation_after_validation_stops_before_aws_change_set(self):
        output = self.root / "release-output"
        path = prepare(self.revision, output, handler_source=self.frozen["files"]["backend/handler.py"]["text"], frozen=self.frozen)
        actual_command = deploy.command
        calls = []

        def fake_aws(args, options):
            calls.append(args)
            path.write_text(path.read_text() + " ")
            return {}

        def fake_command(args, **kwargs):
            if args[0] == "git":
                return actual_command(args, **kwargs)
            return subprocess.CompletedProcess(args, 1, "", "Stack does not exist")

        options = SimpleNamespace(profile="fixture", region="us-west-2", stack="fixture-stack")
        with patch("deploy.aws", side_effect=fake_aws), patch("deploy.command", side_effect=fake_command):
            with self.assertRaises(RuntimeError):
                deploy_aws(self.revision, options, output, self.frozen, path)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][:2], ["cloudformation", "validate-template"])

    def test_source_mutation_after_vercel_link_stops_before_deploy(self):
        output = self.root / "release-output"
        output.mkdir()
        actual_command = deploy.command
        calls = []

        def fake_command(args, **kwargs):
            if args[0] == "git":
                return actual_command(args, **kwargs)
            calls.append(args)
            if args[1] == "link":
                (self.root / "backend" / "handler.py").write_text("# Source changed during the release\n")
            return subprocess.CompletedProcess(args, 0, "{}", "")

        options = SimpleNamespace(vercel="fixture-vercel", project="fixture-project")
        with patch("deploy.command", side_effect=fake_command):
            with self.assertRaises(RuntimeError):
                deploy_vercel("https://test123.execute-api.us-west-2.amazonaws.com", self.revision, options, output, self.frozen)
        self.assertFalse(any(args[1] == "deploy" for args in calls))

    @unittest.skipIf(boto3 is None, "Install backend/requirements-dev.txt for bootstrap SDK checks")
    def test_source_mutation_after_empty_probe_stops_before_seed_write(self):
        def fake_probe(*args):
            (self.root / "backend" / "handler.py").write_text("# Source changed before publishing\n")
            return 503, {"error": "The guide library has not been published yet."}, {}

        options = SimpleNamespace(profile="fixture", region="us-west-2")
        with patch("deploy.probe", side_effect=fake_probe), patch("boto3.Session", return_value=object()), patch("publish.publish") as publisher:
            with self.assertRaises(RuntimeError):
                bootstrap("https://test123.execute-api.us-west-2.amazonaws.com", fixture(), options, frozen=self.frozen)
        publisher.assert_not_called()


@unittest.skipIf(boto3 is None, "Install backend/requirements-dev.txt for actual SDK conditional-write checks")
class S3SDKTests(unittest.TestCase):
    def setUp(self):
        self.client = boto3.client("s3", region_name="us-west-2", aws_access_key_id="fixture", aws_secret_access_key="fixture")
        self.store = S3CatalogStore(self.client, "editorial-fixture-bucket")

    def test_sdk_models_support_both_conditional_headers(self):
        members = self.client.meta.service_model.operation_model("PutObject").input_shape.members
        self.assertTrue({"IfMatch", "IfNoneMatch"}.issubset(members))

    def test_first_s3_publication_uses_create_only_headers_for_both_keys(self):
        value = fixture()
        data = canonical(value)
        with Stubber(self.client) as stub:
            stub.add_client_error("get_object", service_error_code="NoSuchKey", http_status_code=404)
            for key in ("revisions/fixture-1.json", "published/catalog.json"):
                stub.add_response("put_object", {"ETag": '"first"'}, {"Bucket": "editorial-fixture-bucket", "Key": key, "Body": data,
                    "ContentType": "application/json; charset=utf-8", "CacheControl": "no-cache", "ServerSideEncryption": "AES256", "IfNoneMatch": "*"})
            self.assertEqual(self.store.publish(value, create=True), '"first"')
            stub.assert_no_pending_responses()

    def test_interrupted_first_publish_can_retry_matching_orphan_revision(self):
        value = fixture()
        data = canonical(value)
        with Stubber(self.client) as stub:
            stub.add_client_error("get_object", service_error_code="NoSuchKey", http_status_code=404,
                expected_params={"Bucket": "editorial-fixture-bucket", "Key": "published/catalog.json"})
            stub.add_client_error("put_object", service_error_code="PreconditionFailed", http_status_code=412)
            stub.add_response("get_object", {"Body": io.BytesIO(data), "ETag": '"history"'},
                {"Bucket": "editorial-fixture-bucket", "Key": "revisions/fixture-1.json"})
            stub.add_response("put_object", {"ETag": '"first"'}, {"Bucket": "editorial-fixture-bucket", "Key": "published/catalog.json", "Body": data,
                "ContentType": "application/json; charset=utf-8", "CacheControl": "no-cache", "ServerSideEncryption": "AES256", "IfNoneMatch": "*"})
            self.assertEqual(self.store.publish(value, create=True), '"first"')
            stub.assert_no_pending_responses()

    def test_denied_storage_is_an_error_and_never_an_empty_catalog(self):
        with Stubber(self.client) as stub:
            stub.add_client_error("get_object", service_error_code="AccessDenied", http_status_code=403)
            with self.assertRaises(self.client.exceptions.ClientError) as error:
                self.store.get()
            self.assertEqual(error.exception.response["Error"]["Code"], "AccessDenied")
            stub.assert_no_pending_responses()

    def test_editorial_client_signs_current_etag_and_body_without_credentials_in_url(self):
        catalog = fixture()
        session = boto3.Session(region_name="us-west-2", aws_access_key_id="fixture", aws_secret_access_key="fixture")
        captured = []

        class FakeResponse:
            status = 200
            headers = {"ETag": '"new"'}

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

            def read(self):
                return canonical({"revision": catalog["revision"], "articles": 1, "publishedAt": catalog["publishedAt"]})

        def capture(request, timeout):
            captured.append(request)
            return FakeResponse()

        with patch("publish.urlopen", side_effect=capture):
            result = publish(catalog, "https://test123.execute-api.us-west-2.amazonaws.com", session, "us-west-2", expected='"old"')
        request = captured[0]
        headers = {key.casefold(): value for key, value in request.header_items()}
        self.assertEqual(request.get_method(), "PUT")
        self.assertEqual(request.data, canonical(catalog))
        self.assertEqual(headers["if-match"], '"old"')
        self.assertTrue(headers["authorization"].startswith("AWS4-HMAC-SHA256 "))
        self.assertIn("if-match", headers["authorization"])
        self.assertNotIn("fixture", request.full_url)
        self.assertEqual(result["etag"], '"new"')

    def test_current_put_uses_server_side_if_match_and_encryption(self):
        value = fixture()
        data = canonical(value)
        with Stubber(self.client) as stub:
            stub.add_response("get_object", {"Body": io.BytesIO(canonical({**value, "revision": "fixture-0"})), "ETag": '"old"'})
            stub.add_client_error("get_object", service_error_code="NoSuchKey", http_status_code=404,
                expected_params={"Bucket": "editorial-fixture-bucket", "Key": "illustrations/fixture-1.json"})
            stub.add_client_error("get_object", service_error_code="NoSuchKey", http_status_code=404,
                expected_params={"Bucket": "editorial-fixture-bucket", "Key": "illustrations/fixture-0.json"})
            stub.add_response("put_object", {"ETag": '"images"'}, {"Bucket": "editorial-fixture-bucket", "Key": "illustrations/fixture-1.json",
                "Body": canonical({"schemaVersion": 1, "revision": "fixture-1", "items": []}),
                "ContentType": "application/json; charset=utf-8", "CacheControl": "no-cache", "ServerSideEncryption": "AES256", "IfNoneMatch": "*"})
            stub.add_response("put_object", {"ETag": '"history"'}, {"Bucket": "editorial-fixture-bucket", "Key": "revisions/fixture-1.json", "Body": data,
                "ContentType": "application/json; charset=utf-8", "CacheControl": "no-cache", "ServerSideEncryption": "AES256", "IfNoneMatch": "*"})
            stub.add_response("put_object", {"ETag": '"new"'}, {"Bucket": "editorial-fixture-bucket", "Key": "published/catalog.json", "Body": data,
                "ContentType": "application/json; charset=utf-8", "CacheControl": "no-cache", "ServerSideEncryption": "AES256", "IfMatch": '"old"'})
            self.assertEqual(self.store.publish(value, expected='"old"'), '"new"')
            stub.assert_no_pending_responses()

    def test_s3_precondition_failure_is_not_silently_retried_as_overwrite(self):
        with Stubber(self.client) as stub:
            stub.add_client_error("put_object", service_error_code="PreconditionFailed", http_status_code=412)
            with self.assertRaises(CatalogError) as error:
                self.store.conditional_put("published/catalog.json", b"{}", expected='"old"')
            self.assertEqual(error.exception.status, 412)
            stub.assert_no_pending_responses()

    def test_reused_revision_compares_saved_bytes_before_current_write(self):
        data = canonical(fixture())
        with Stubber(self.client) as stub:
            stub.add_response("get_object", {"Body": io.BytesIO(canonical({**fixture(), "revision": "fixture-0"})), "ETag": '"current"'})
            stub.add_response("get_object", {"Body": io.BytesIO(canonical({"schemaVersion": 1, "revision": "fixture-1", "items": []})), "ETag": '"images"'},
                {"Bucket": "editorial-fixture-bucket", "Key": "illustrations/fixture-1.json"})
            stub.add_client_error("put_object", service_error_code="PreconditionFailed", http_status_code=412)
            stub.add_response("get_object", {"Body": io.BytesIO(b"{}"), "ETag": '"history"'})
            with self.assertRaises(CatalogError) as error:
                self.store.publish(fixture(), expected='"current"')
            self.assertEqual(error.exception.status, 409)
            stub.assert_no_pending_responses()

    def test_s3_missing_key_returns_unpublished(self):
        with Stubber(self.client) as stub:
            stub.add_client_error("get_object", service_error_code="NoSuchKey", http_status_code=404)
            self.assertIsNone(self.store.get())


@unittest.skipIf(boto3 is None, "Install backend/requirements-dev.txt for bootstrap SDK checks")
class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.origin = "https://test123.execute-api.us-west-2.amazonaws.com"
        self.options = SimpleNamespace(profile="test-fixture", region="us-west-2")

    def test_retry_preserves_already_published_library_even_if_seed_changed(self):
        live = fixture()
        live["revision"] = "live-editorial-update"
        live["articles"][0]["title"] = "Already published editorial update"
        with patch("deploy.probe", return_value=(200, live, {})), patch("publish.publish") as publisher:
            result = bootstrap(self.origin, fixture(), self.options)
        self.assertEqual(result, {"action": "existing-publication-preserved", "revision": "live-editorial-update"})
        publisher.assert_not_called()

    def test_storage_errors_cannot_trigger_seed_publication(self):
        for result in ((503, {"error": "The library is temporarily unavailable."}, {}),
                       (403, {"error": "AccessDenied"}, {}), (404, None, {}), (500, None, {})):
            with self.subTest(status=result[0]), patch("deploy.probe", return_value=result), patch("publish.publish") as publisher:
                with self.assertRaises(RuntimeError):
                    bootstrap(self.origin, fixture(), self.options)
                publisher.assert_not_called()

    def test_confirmed_empty_store_uses_create_only_publication(self):
        catalog = fixture()
        session = object()
        with patch("deploy.probe", return_value=(503, {"error": "The guide library has not been published yet."}, {})), \
             patch("boto3.Session", return_value=session), patch("publish.publish", return_value={"revision": catalog["revision"]}) as publisher:
            result = bootstrap(self.origin, catalog, self.options)
        publisher.assert_called_once_with(catalog, self.origin, session, "us-west-2", create=True)
        self.assertEqual(result["action"], "first-publication-created")

    def test_empty_store_race_is_not_retried_as_overwrite(self):
        with patch("deploy.probe", return_value=(503, {"error": "The guide library has not been published yet."}, {})), \
             patch("boto3.Session", return_value=object()), patch("publish.publish", side_effect=RuntimeError("The live catalog changed.")) as publisher:
            with self.assertRaises(RuntimeError):
                bootstrap(self.origin, fixture(), self.options)
        self.assertEqual(publisher.call_count, 1)
        self.assertEqual(publisher.call_args.kwargs, {"create": True})


if __name__ == "__main__":
    unittest.main()
