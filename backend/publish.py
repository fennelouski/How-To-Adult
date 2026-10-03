#!/usr/bin/env python3
"""Validate an editorial catalog, then explicitly publish it through AWS IAM."""
import argparse
import json
from pathlib import Path
import re
import sys
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

from handler import canonical, CatalogError, decode_json, ETAG, validate_catalog


def api_origin(value, region):
    parsed = urlsplit(value)
    pattern = r"[a-z0-9]+\.execute-api\." + re.escape(region) + r"\.amazonaws\.com"
    if parsed.scheme != "https" or not re.fullmatch(pattern, parsed.hostname or "") or parsed.path or parsed.query or parsed.fragment or parsed.username or parsed.password or parsed.port is not None:
        raise ValueError("Use the AWS API origin for the selected region, without a path.")
    return value


def publish(catalog, api_url, session, region, expected=None, create=False):
    from botocore.auth import SigV4Auth
    from botocore.awsrequest import AWSRequest
    if bool(expected) == create or (expected and not ETAG.fullmatch(expected)):
        raise ValueError("Use exactly one of create or a current quoted ETag.")
    validate_catalog(catalog)
    url = api_origin(api_url, region) + "/v1/publication"
    body = canonical(catalog)
    headers = {"Content-Type": "application/json", "User-Agent": "HowToAdultEditorialPublisher/1.0"}
    headers["If-None-Match" if create else "If-Match"] = "*" if create else expected
    credentials = session.get_credentials()
    if credentials is None:
        raise RuntimeError("AWS sign-in is required before publishing.")
    request = AWSRequest(method="PUT", url=url, data=body, headers=headers)
    SigV4Auth(credentials.get_frozen_credentials(), "execute-api", region).add_auth(request)
    signed = request.prepare()
    try:
        with urlopen(Request(url, data=body, method="PUT", headers=dict(signed.headers)), timeout=30) as result:
            if result.status != 200:
                raise RuntimeError("Publication was not confirmed.")
            value = json.loads(result.read())
            if value.get("revision") != catalog["revision"]:
                raise RuntimeError("Publication response revision does not match the reviewed catalog.")
            return {**value, "etag": result.headers.get("ETag")}
    except HTTPError as error:
        # Provider authentication errors can include details we should not print.
        if error.code == 412:
            raise RuntimeError("The live catalog changed. Fetch its current ETag and review before retrying.") from error
        if error.code == 409:
            raise RuntimeError("This publication conflicts with the live library. Use a unique revision and a current publication timestamp.") from error
        raise RuntimeError("Publication rejected with HTTP " + str(error.code) + ". No successful publication was confirmed.") from error


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=Path(__file__).resolve().parents[1] / "Content" / "catalog.json")
    parser.add_argument("--check", action="store_true", help="Validate locally without AWS or any remote writes")
    parser.add_argument("--api-url")
    parser.add_argument("--profile", default="fishbowl-head")
    parser.add_argument("--region", default="us-west-2")
    condition = parser.add_mutually_exclusive_group()
    condition.add_argument("--create", action="store_true", help="First publication only; refuses to overwrite a live catalog")
    condition.add_argument("--expected-etag", help="Exact current quoted ETag obtained after reviewing the live catalog")
    options = parser.parse_args()
    try:
        catalog = validate_catalog(decode_json(options.catalog.read_bytes()))
        if options.check:
            print(json.dumps({"valid": True, "revision": catalog["revision"], "articles": len(catalog["articles"]), "bytes": len(canonical(catalog))}))
            return 0
        if not options.api_url or not (options.create or options.expected_etag):
            parser.error("Publishing needs --api-url and either --create or --expected-etag.")
        import boto3
        session = boto3.Session(profile_name=options.profile, region_name=options.region)
        print(json.dumps(publish(catalog, options.api_url, session, options.region, options.expected_etag, options.create), indent=2))
        return 0
    except (CatalogError, ValueError, RuntimeError, OSError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
