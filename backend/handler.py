"""Public editorial catalog; personal app activity never belongs in this store."""
import base64
from datetime import date, datetime, timezone
import hashlib
import ipaddress
import json
import logging
import os
import re
import unicodedata
from urllib.parse import parse_qs, urlsplit

MAX_BYTES = 4 * 1024 * 1024
MAX_ARTICLES = 2000
CURRENT_KEY = "published/catalog.json"
SLUG = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")
REVISION = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,95}\Z")
ETAG = re.compile(r'"[A-Za-z0-9-]+"\Z')
COLOR_KEYS = {"teal", "orange", "green", "blue", "rose", "purple", "indigo"}


class CatalogError(Exception):
    def __init__(self, message, status=422):
        super().__init__(message)
        self.status = status


def canonical(value):
    return json.dumps(value, ensure_ascii=False, allow_nan=False, sort_keys=True,
                      separators=(",", ":")).encode("utf-8")


def decode_json(data):
    if not isinstance(data, bytes) or len(data) > MAX_BYTES:
        raise CatalogError("The catalog exceeds the 4 MB publication limit.", 413)

    def object_pairs(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise CatalogError("Duplicate JSON fields are not supported.")
            value[key] = item
        return value

    def invalid_constant(_):
        raise CatalogError("Use finite JSON numbers.")

    try:
        return json.loads(data.decode("utf-8"), object_pairs_hook=object_pairs,
                          parse_constant=invalid_constant)
    except (UnicodeDecodeError, ValueError, RecursionError) as error:
        raise CatalogError("Use a valid UTF-8 JSON catalog.") from error


def fields(value, required, label):
    if not isinstance(value, dict) or set(value) != set(required):
        raise CatalogError(label + " has missing or unsupported fields.")


def text(value, label, maximum=300, allow_empty=False):
    if not isinstance(value, str) or len(value) > maximum or (not allow_empty and not value.strip()):
        raise CatalogError(label + " must contain readable text within its length limit.")
    if any(unicodedata.category(char) == "Cc" and char not in "\n\t" for char in value):
        raise CatalogError(label + " contains control characters.")


def slug(value, label):
    if not isinstance(value, str) or len(value) > 100 or not SLUG.fullmatch(value):
        raise CatalogError(label + " must be a lowercase hyphenated ID.")


def string_list(value, label, count, maximum):
    if not isinstance(value, list) or len(value) > count:
        raise CatalogError(label + " has too many items.")
    for item in value:
        text(item, label, maximum)
    if len(set(value)) != len(value):
        raise CatalogError(label + " must not contain duplicate items.")


def iso_date(value, label):
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        raise CatalogError(label + " must use YYYY-MM-DD.")
    try:
        return date.fromisoformat(value)
    except ValueError as error:
        raise CatalogError(label + " is not a valid date.") from error


def timestamp(value):
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z", value):
        raise CatalogError("publishedAt must be an ISO 8601 UTC timestamp ending in Z.")
    try:
        return datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as error:
        raise CatalogError("publishedAt is not a valid timestamp.") from error


def source_url(value):
    text(value, "Source URL", 2048)
    try:
        parsed = urlsplit(value)
        host = (parsed.hostname or "").encode("idna").decode("ascii").lower().rstrip(".")
        if parsed.scheme != "https" or not host or parsed.username or parsed.password or parsed.port not in (None, 443):
            raise CatalogError("Sources must use public HTTPS URLs without credentials.")
        if "." not in host or host.endswith((".local", ".localhost", ".internal", ".invalid", ".test")):
            raise CatalogError("Sources must use public HTTPS URLs.")
        try:
            address = ipaddress.ip_address(host)
        except ValueError:
            address = None
        if address is not None and not address.is_global:
            raise CatalogError("Sources must use public HTTPS URLs.")
        if any(ord(char) <= 32 for char in value):
            raise CatalogError("Source URLs cannot contain spaces or control characters.")
        sensitive = {"token", "password", "secret", "key", "auth", "access_token", "api_key", "signature", "jwt", "session"}
        if any(key.casefold() in sensitive for key in parse_qs(parsed.query, keep_blank_values=True)):
            raise CatalogError("Sources cannot contain credentials or access tokens.")
    except (ValueError, UnicodeError) as error:
        raise CatalogError("Use a valid public HTTPS source URL.") from error


def validate_catalog(value, now=None):
    fields(value, {"schemaVersion", "revision", "publishedAt", "categories", "articles"}, "Catalog")
    if type(value["schemaVersion"]) is not int or value["schemaVersion"] != 1:
        raise CatalogError("Only catalog schema version 1 is supported.")
    if not isinstance(value["revision"], str) or not REVISION.fullmatch(value["revision"]):
        raise CatalogError("revision must be a unique safe publication ID.")
    published = timestamp(value["publishedAt"])
    now = now or datetime.now(timezone.utc)
    if published > now:
        raise CatalogError("Future publication timestamps are not supported.")
    categories = value["categories"]
    if not isinstance(categories, list) or not 1 <= len(categories) <= 30:
        raise CatalogError("Use between 1 and 30 categories.")
    category_ids = set()
    for category in categories:
        fields(category, {"id", "title", "symbol", "colorKey"}, "Category")
        slug(category["id"], "Category ID")
        if category["id"] in category_ids:
            raise CatalogError("Category IDs must be unique.")
        category_ids.add(category["id"])
        text(category["title"], "Category title", 80)
        text(category["symbol"], "Category symbol", 80)
        if not isinstance(category["colorKey"], str) or category["colorKey"] not in COLOR_KEYS:
            raise CatalogError("Category colorKey is unsupported.")
    articles = value["articles"]
    if not isinstance(articles, list) or not 1 <= len(articles) <= MAX_ARTICLES:
        raise CatalogError("Use between 1 and 2000 articles.")
    article_ids = set()
    article_fields = {"id", "title", "summary", "categoryID", "symbol", "minutes", "jurisdiction", "updatedAt", "tags", "tools", "steps", "cautions", "sources"}
    for article in articles:
        fields(article, article_fields, "Article")
        slug(article["id"], "Article ID")
        if article["id"] in article_ids:
            raise CatalogError("Article IDs must be unique.")
        article_ids.add(article["id"])
        text(article["title"], "Article title", 160)
        text(article["summary"], "Article summary", 500)
        text(article["symbol"], "Article symbol", 80)
        text(article["jurisdiction"], "Jurisdiction", 120)
        if not isinstance(article["categoryID"], str) or article["categoryID"] not in category_ids:
            raise CatalogError("Every article must reference an existing category.")
        if type(article["minutes"]) is not int or not 1 <= article["minutes"] <= 1440:
            raise CatalogError("minutes must be a whole number from 1 to 1440.")
        if iso_date(article["updatedAt"], "updatedAt") > published.date():
            raise CatalogError("Article updates cannot be later than publication.")
        string_list(article["tags"], "Tags", 30, 80)
        string_list(article["tools"], "Tools", 30, 240)
        string_list(article["cautions"], "Cautions", 20, 2000)
        steps = article["steps"]
        if not isinstance(steps, list) or not 2 <= len(steps) <= 40:
            raise CatalogError("Each guide needs between 2 and 40 steps.")
        step_ids = set()
        for step in steps:
            fields(step, {"id", "title", "body"}, "Step")
            slug(step["id"], "Step ID")
            if step["id"] in step_ids:
                raise CatalogError("Step IDs must be unique within an article.")
            step_ids.add(step["id"])
            text(step["title"], "Step title", 160)
            text(step["body"], "Step body", 8000)
        sources = article["sources"]
        if not isinstance(sources, list) or len(sources) > 30:
            raise CatalogError("An article can have at most 30 sources.")
        source_urls = set()
        for source in sources:
            fields(source, {"title", "url"}, "Source")
            text(source["title"], "Source title", 200)
            source_url(source["url"])
            if source["url"] in source_urls:
                raise CatalogError("Sources must not contain duplicate URLs.")
            source_urls.add(source["url"])
    if len(canonical(value)) > MAX_BYTES:
        raise CatalogError("The catalog exceeds the 4 MB publication limit.", 413)
    return value


class S3CatalogStore:
    """One AWS owner, immutable revision copies, and an atomic current catalog."""
    def __init__(self, client, bucket):
        self.client = client
        self.bucket = bucket

    def get_key(self, key):
        try:
            response = self.client.get_object(Bucket=self.bucket, Key=key)
        except self.client.exceptions.NoSuchKey:
            return None
        body = response["Body"]
        try:
            data = body.read(MAX_BYTES + 1)
        finally:
            body.close()
        if len(data) > MAX_BYTES:
            raise CatalogError("Stored catalog exceeds its supported size.", 503)
        return data, response["ETag"]

    def get(self):
        return self.get_key(CURRENT_KEY)

    def conditional_put(self, key, data, expected=None, create=False):
        condition = {"IfNoneMatch": "*"} if create else {"IfMatch": expected}
        # S3 has no modeled PreconditionFailed subclass; its generated ClientError
        # is handled only for the two conditional-write outcomes we can resolve.
        try:
            response = self.client.put_object(Bucket=self.bucket, Key=key, Body=data,
                ContentType="application/json; charset=utf-8", CacheControl="no-cache",
                ServerSideEncryption="AES256", **condition)
        except self.client.exceptions.ClientError as error:
            code = error.response.get("Error", {}).get("Code")
            if code in {"PreconditionFailed", "ConditionalRequestConflict"}:
                raise CatalogError("The catalog changed. Fetch the current ETag and review your update.", 412) from error
            raise
        return response["ETag"]

    def publish(self, catalog, expected=None, create=False):
        data = canonical(catalog)
        current = self.get()
        if (create and current is not None) or (not create and (current is None or current[1] != expected)):
            raise CatalogError("The catalog changed. Fetch the current ETag and review your update.", 412)
        if current is not None:
            previous_catalog = validate_catalog(decode_json(current[0]))
            if timestamp(catalog["publishedAt"]) < timestamp(previous_catalog["publishedAt"]):
                raise CatalogError("A new publication cannot have an earlier publishedAt than the live library.", 409)
        history_key = "revisions/" + catalog["revision"] + ".json"
        try:
            self.conditional_put(history_key, data, create=True)
        except CatalogError as error:
            if error.status != 412:
                raise
            previous = self.get_key(history_key)
            if previous is None or previous[0] != data:
                raise CatalogError("A publication revision cannot be reused for different content.", 409) from error
        return self.conditional_put(CURRENT_KEY, data, expected, create)


def response(status, value=None, etag=None, source_revision="local", content_revision=None, cache="no-store"):
    headers = {"content-type": "application/json; charset=utf-8", "cache-control": cache,
               "x-content-type-options": "nosniff", "x-release-revision": source_revision}
    if etag:
        headers["etag"] = etag
    if content_revision:
        headers["x-catalog-revision"] = content_revision
    return {"statusCode": status, "headers": headers,
            "body": "" if value is None else canonical(value).decode("utf-8"), "isBase64Encoded": False}


def cache_matches(header, etag):
    return any(token.strip().removeprefix("W/") in {etag, "*"} for token in header.split(","))


def query_params(event):
    values = parse_qs(event.get("rawQueryString", ""), keep_blank_values=True)
    if set(values) - {"q", "category", "jurisdiction", "limit", "offset"} or any(len(items) != 1 for items in values.values()):
        raise CatalogError("Use supported search parameters once each.", 400)
    return {key: items[0] for key, items in values.items()}


def article_summaries(catalog, query):
    needle = query.get("q", "").strip().casefold()
    text(needle, "Search", 160, allow_empty=True)
    category = query.get("category", "")
    if category and category not in {item["id"] for item in catalog["categories"]}:
        raise CatalogError("Choose an existing category.", 400)
    jurisdiction = query.get("jurisdiction", "").strip().casefold()
    text(jurisdiction, "Jurisdiction", 120, allow_empty=True)
    try:
        limit = int(query.get("limit", "50"))
        offset = int(query.get("offset", "0"))
    except ValueError as error:
        raise CatalogError("limit and offset must be whole numbers.", 400) from error
    if not 1 <= limit <= 100 or not 0 <= offset <= MAX_ARTICLES:
        raise CatalogError("Use limit 1–100 and offset 0–2000.", 400)
    matches = []
    for article in catalog["articles"]:
        searchable = " ".join([article["title"], article["summary"], *article["tags"]]).casefold()
        if category and article["categoryID"] != category:
            continue
        if jurisdiction and article["jurisdiction"].casefold() != jurisdiction:
            continue
        if not all(word in searchable for word in needle.split()):
            continue
        matches.append({key: article[key] for key in ("id", "title", "summary", "categoryID", "symbol", "minutes", "jurisdiction", "updatedAt", "tags")})
    return {"schemaVersion": 1, "revision": catalog["revision"], "total": len(matches),
            "offset": offset, "limit": limit, "articles": matches[offset:offset + limit],
            "nextOffset": offset + limit if offset + limit < len(matches) else None}


def handle(event, store, source_revision="local", conditional_writes=True):
    method = event.get("requestContext", {}).get("http", {}).get("method", "GET")
    path = event.get("rawPath", "")
    headers = {key.casefold(): value for key, value in event.get("headers", {}).items()}
    try:
        if method == "PUT" and path == "/v1/publication":
            iam = event.get("requestContext", {}).get("authorizer", {}).get("iam", {})
            if not iam.get("userArn"):
                raise CatalogError("Publishing requires AWS IAM authorization.", 403)
            if not conditional_writes:
                raise CatalogError("The storage SDK needs conditional-write support before publishing.", 503)
            expected, create = headers.get("if-match"), headers.get("if-none-match") == "*"
            if bool(expected) == create or (expected and not ETAG.fullmatch(expected)) or ("if-none-match" in headers and not create):
                raise CatalogError("Send the current quoted ETag in If-Match, or If-None-Match: * for the first publication.", 428)
            if headers.get("content-type", "").split(";")[0].strip().casefold() != "application/json":
                raise CatalogError("Publish an application/json catalog.", 415)
            raw = event.get("body", "")
            if not isinstance(raw, str) or len(raw) > MAX_BYTES * 2:
                raise CatalogError("The catalog exceeds the 4 MB publication limit.", 413)
            try:
                data = base64.b64decode(raw, validate=True) if event.get("isBase64Encoded") else raw.encode("utf-8")
            except (ValueError, UnicodeError) as error:
                raise CatalogError("Invalid publication body.") from error
            catalog = validate_catalog(decode_json(data))
            etag = store.publish(catalog, expected, create)
            return response(200, {"revision": catalog["revision"], "articles": len(catalog["articles"]), "publishedAt": catalog["publishedAt"]}, etag, source_revision, catalog["revision"])
        if method != "GET" or path not in {"/health", "/v1/catalog", "/v1/articles"} and not re.fullmatch(r"/v1/articles/[a-z0-9]+(?:-[a-z0-9]+)*", path):
            raise CatalogError("Route not found.", 404)
        current = store.get()
        if path == "/health":
            catalog = validate_catalog(decode_json(current[0])) if current else None
            return response(200, {"status": "ok", "sourceRevision": source_revision,
                "published": catalog is not None, "catalogRevision": catalog["revision"] if catalog else None,
                "conditionalWritesSupported": conditional_writes, "personalActivityStored": False}, source_revision=source_revision)
        if current is None:
            raise CatalogError("The guide library has not been published yet.", 503)
        catalog = validate_catalog(decode_json(current[0]))
        if path == "/v1/catalog":
            if event.get("rawQueryString"):
                raise CatalogError("The full catalog does not accept search parameters.", 400)
            value, etag = catalog, current[1]
        elif path == "/v1/articles":
            value = article_summaries(catalog, query_params(event))
            etag = '"' + hashlib.sha256(canonical(value)).hexdigest() + '"'
        else:
            if event.get("rawQueryString"):
                raise CatalogError("An article does not accept search parameters.", 400)
            article_id = path.rsplit("/", 1)[-1]
            value = next((article for article in catalog["articles"] if article["id"] == article_id), None)
            if value is None:
                raise CatalogError("Guide not found.", 404)
            etag = '"' + hashlib.sha256(canonical(value)).hexdigest() + '"'
        if cache_matches(headers.get("if-none-match", ""), etag):
            return response(304, etag=etag, source_revision=source_revision, content_revision=catalog["revision"], cache="public, max-age=60, must-revalidate")
        return response(200, value, etag, source_revision, catalog["revision"], cache="public, max-age=60, must-revalidate")
    except CatalogError as error:
        return response(error.status, {"error": str(error)}, source_revision=source_revision)


_store = None
_conditional_writes = False


def main(event, context):
    global _store, _conditional_writes
    revision = os.environ.get("SOURCE_REVISION", "unknown")
    try:
        if _store is None:
            import boto3
            from botocore.config import Config
            client = boto3.client("s3", config=Config(connect_timeout=3, read_timeout=5,
                retries={"total_max_attempts": 2, "mode": "standard"}))
            members = client.meta.service_model.operation_model("PutObject").input_shape.members
            _conditional_writes = {"IfMatch", "IfNoneMatch"}.issubset(members)
            _store = S3CatalogStore(client, os.environ["CATALOG_BUCKET"])
        return handle(event, _store, revision, _conditional_writes)
    except Exception as error:
        # Log the exception type only. Never log request URLs, bodies, IAM credentials,
        # search text, catalog text, personal app activity, or provider exception data.
        logging.error("Catalog service unavailable (%s)", type(error).__name__)
        return response(503, {"error": "The library is temporarily unavailable. Saved guides remain on your device."}, source_revision=revision)
