#!/usr/bin/env python3
"""Build locally, then deploy and verify one committed revision on both hosts."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from handler import canonical, decode_json, validate_catalog
from infrastructure import template, vercel_output

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
CUTOFF = datetime(2026, 10, 22, 7, tzinfo=timezone.utc)
ACCOUNT = "074861507225"
RELEASE_FILES = ("backend/deploy.py", "backend/handler.py", "backend/infrastructure.py", "backend/publish.py",
                 "backend/local.py", "backend/tests/test_backend.py", "backend/tests/__init__.py", "backend/requirements-dev.txt", "Content/catalog.json")
RELEASE_FILES += ("backend/editor_client.py", "backend/provision_editor.py", "backend/tests/test_editor.py")


def command(args, cwd=ROOT, checked=True, timeout=180):
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True, timeout=timeout)
    if checked and result.returncode:
        # No command here embeds credentials; provider responses are retained only
        # in normal CLI diagnostics and are never copied into deployment receipts.
        raise RuntimeError("Command failed: " + " ".join(str(value) for value in args[:3]) + "\n" + result.stderr)
    return result


def aws(args, options):
    result = command(["aws", *args, "--profile", options.profile, "--region", options.region,
                      "--output", "json", "--no-cli-pager"])
    return json.loads(result.stdout or "{}")


def publication_state():
    return json.loads((BACKEND / "deployment-record.json").read_text())


def check_mode(mode, state, now):
    if mode == "parallel" and (now >= CUTOFF or state.get("actualCutoverAt") or state.get("mode") == "aws-only"):
        raise RuntimeError("Parallel deployment is closed after verified cutover or the policy cutoff. Review the recorded migration exception or cutover before releasing.")
    if mode == "aws-only" and not (state.get("mode") == "aws-only" and state.get("actualCutoverAt") and state.get("cutoverVerified") is True and state.get("productionRoutingOwner") == "AWS"):
        raise RuntimeError("AWS-only needs a recorded, verified cutover and AWS production routing. A date alone does not authorize cutover.")


def write_json(path, value):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(value, indent=2) + "\n")


def freeze_source(revision, paths=RELEASE_FILES):
    files = {}
    for path in paths:
        source = command(["git", "show", revision + ":" + path], cwd=ROOT).stdout
        files[path] = {"text": source, "sha256": hashlib.sha256(source.encode("utf-8")).hexdigest()}
    frozen = {"revision": revision, "files": files}
    assert_release_source(frozen)
    return frozen


def assert_release_source(frozen):
    if command(["git", "rev-parse", "HEAD"], cwd=ROOT).stdout.strip() != frozen["revision"]:
        raise RuntimeError("The release checkout changed commits. No complete release can be recorded.")
    if command(["git", "status", "--porcelain", "--untracked-files=all"], cwd=ROOT).stdout.strip():
        raise RuntimeError("The release checkout changed after it was frozen. Commit and review before retrying.")
    for relative, source in frozen["files"].items():
        if hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() != source["sha256"]:
            raise RuntimeError("A release source file changed after it was frozen: " + relative)


def assert_artifacts(hashes):
    for path, expected in hashes.items():
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise RuntimeError("A prepared release artifact changed: " + str(path))


def prepare(revision, output, handler_source=None, frozen=None):
    body = template(revision, handler_source=handler_source)
    path = output / "cloudformation.json"
    data = (json.dumps(body, separators=(",", ":")) + "\n").encode("utf-8")
    if len(data) > 51200:
        raise RuntimeError("CloudFormation inline template exceeds its supported request size.")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    if frozen is not None:
        frozen["templateSHA256"] = hashlib.sha256(data).hexdigest()
    return path


def deploy_aws(revision, options, output, frozen, path):
    assert_release_source(frozen)
    artifact = {path: frozen["templateSHA256"]}
    assert_artifacts(artifact)
    aws(["cloudformation", "validate-template", "--template-body", "file://" + str(path)], options)
    existing = command(["aws", "cloudformation", "describe-stacks", "--stack-name", options.stack,
        "--profile", options.profile, "--region", options.region, "--output", "json", "--no-cli-pager"], checked=False)
    if existing.returncode and "does not exist" not in existing.stderr:
        raise RuntimeError("Could not inspect the existing AWS stack; refusing to replace or recreate it.")
    status = json.loads(existing.stdout)["Stacks"][0]["StackStatus"] if existing.returncode == 0 else None
    kind = "CREATE" if status in {None, "REVIEW_IN_PROGRESS"} else "UPDATE"
    parameters = []
    if getattr(options, "editor_key_file", None):
        from editor_client import load_credentials
        credential = load_credentials(options.editor_key_file)
        digest = hashlib.sha256(credential["HOWTOADULT_EDITOR_API_KEY"].encode("ascii")).hexdigest()
        parameters = ["--parameters", "ParameterKey=EditorKeySHA256,ParameterValue=" + digest]
    elif kind == "UPDATE" and any(parameter["ParameterKey"] == "EditorKeySHA256" for parameter in json.loads(existing.stdout)["Stacks"][0].get("Parameters", [])):
        parameters = ["--parameters", "ParameterKey=EditorKeySHA256,UsePreviousValue=true"]
    name = "release-" + revision[:12] + "-" + str(int(time.time()))
    assert_release_source(frozen)
    assert_artifacts(artifact)
    changes = aws(["cloudformation", "create-change-set", "--stack-name", options.stack, "--change-set-name", name,
        "--change-set-type", kind, "--capabilities", "CAPABILITY_IAM", "--template-body", "file://" + str(path),
        "--description", "How to Adult source revision " + revision, *parameters], options)
    details = {}
    for _ in range(80):
        details = aws(["cloudformation", "describe-change-set", "--change-set-name", changes["Id"]], options)
        if details["Status"] in {"CREATE_COMPLETE", "FAILED"}:
            break
        time.sleep(3)
    write_json(output / "cloudformation-change-set.json", {key: details.get(key) for key in ("Status", "StatusReason", "Changes")})
    no_changes = details.get("Status") == "FAILED" and any(value in details.get("StatusReason", "") for value in ("didn't contain changes", "No updates are to be performed"))
    if not no_changes:
        if details.get("Status") != "CREATE_COMPLETE":
            raise RuntimeError("AWS change-set validation did not complete successfully. Inspect the saved change set before proceeding.")
        assert_release_source(frozen)
        assert_artifacts(artifact)
        print("AWS change set validated; deploying the committed API revision.", flush=True)
        aws(["cloudformation", "execute-change-set", "--change-set-name", changes["Id"]], options)
        for _ in range(240):
            stack = aws(["cloudformation", "describe-stacks", "--stack-name", options.stack], options)["Stacks"][0]
            state = stack["StackStatus"]
            if state in {"CREATE_COMPLETE", "UPDATE_COMPLETE"}:
                break
            if "FAILED" in state or "ROLLBACK" in state:
                raise RuntimeError("AWS stack did not deploy successfully: " + state)
            time.sleep(3)
        else:
            raise RuntimeError("AWS deployment is still pending; no success receipt has been written.")
    assert_release_source(frozen)
    assert_artifacts(artifact)
    stack = aws(["cloudformation", "describe-stacks", "--stack-name", options.stack], options)["Stacks"][0]
    deployed_template = aws(["cloudformation", "get-template", "--stack-name", options.stack, "--template-stage", "Original"], options)["TemplateBody"]
    if isinstance(deployed_template, str):
        deployed_template = json.loads(deployed_template)
    if deployed_template != json.loads(path.read_text()):
        raise RuntimeError("The deployed AWS template differs from the frozen release artifact.")
    return {item["OutputKey"]: item["OutputValue"] for item in stack.get("Outputs", [])}


def deploy_vercel(api_url, revision, options, output, frozen):
    assert_release_source(frozen)
    project = command([options.vercel, "project", "inspect", options.project], checked=False)
    if project.returncode:
        if not any(value in project.stderr.casefold() for value in ("not found", "does not exist", "there is no project")):
            raise RuntimeError("Vercel project inspection failed; no project was created.")
        assert_release_source(frozen)
        command([options.vercel, "project", "add", options.project])
    target = output / "vercel"
    target.mkdir(exist_ok=True)
    assert_release_source(frozen)
    command([options.vercel, "link", "--yes", "--project", options.project], cwd=target)
    assert_release_source(frozen)
    handler_sha = frozen["files"]["backend/handler.py"]["sha256"]
    artifacts = {}
    vercel_output(api_url, revision, target, handler_sha256=handler_sha, artifact_snapshot=artifacts)
    assert_release_source(frozen)
    assert_artifacts(artifacts)
    result = command([options.vercel, "deploy", "--prod", "--yes", "--prebuilt", "--project", options.project,
        "--meta", "sourceRevision=" + revision, "--meta", "githubCommitSha=" + revision, "--format", "json"], cwd=target, timeout=300)
    deployed = json.loads(result.stdout)
    identifier = deployed.get("id") or deployed.get("deployment", {}).get("id")
    if not identifier:
        raise RuntimeError("Vercel did not return a deployment ID; live verification is required before continuing.")
    assert_release_source(frozen)
    assert_artifacts(artifacts)
    details = json.loads(command([options.vercel, "api", "/v13/deployments/" + identifier, "--raw"]).stdout)
    if details.get("readyState") != "READY" or details.get("meta", {}).get("sourceRevision") != revision:
        raise RuntimeError("Vercel deployment is not ready at the expected source revision.")
    aliases = [value for value in details.get("alias", []) if value.endswith(".vercel.app")]
    if not aliases:
        raise RuntimeError("Vercel did not assign a public API alias.")
    preferred = options.project + ".vercel.app"
    alias = preferred if preferred in aliases else sorted(aliases, key=len)[0]
    deployment_url = details.get("url")
    if not deployment_url:
        raise RuntimeError("Vercel deployment URL is missing.")
    metadata = {"id": identifier, "url": "https://" + deployment_url.removeprefix("https://"), "aliases": aliases,
                "sourceRevision": revision, "readyState": "READY"}
    write_json(output / "vercel-metadata.json", metadata)
    return {"url": "https://" + alias, "deploymentURL": metadata["url"], "deploymentID": identifier,
            "artifactSHA256": {str(path.relative_to(target)): digest for path, digest in artifacts.items()}}


def probe(base, path, headers=None, method="GET", body=None):
    request = Request(base + path, data=body, method=method,
                      headers={"User-Agent": "HowToAdultReleaseCheck/1.0", **(headers or {})})
    try:
        with urlopen(request, timeout=30) as result:
            status, data, response_headers = result.status, result.read(), dict(result.headers)
    except HTTPError as error:
        status, data, response_headers = error.code, error.read(), dict(error.headers)
    try:
        value = json.loads(data) if data else None
    except ValueError:
        value = None
    return status, value, {key.casefold(): value for key, value in response_headers.items()}


def bootstrap(api_url, catalog, options, frozen=None):
    if frozen is not None:
        assert_release_source(frozen)
    current = probe(api_url, "/v1/catalog")
    if current[0] == 200:
        validate_catalog(current[1])
        return {"action": "existing-publication-preserved", "revision": current[1]["revision"]}
    if current[0] != 503 or current[1] != {"error": "The guide library has not been published yet."}:
        raise RuntimeError("Could not verify that the AWS catalog is empty. No seed was published.")
    import boto3
    from publish import publish
    session = boto3.Session(profile_name=options.profile, region_name=options.region)
    if frozen is not None:
        assert_release_source(frozen)
    result = publish(catalog, api_url, session, options.region, create=True)
    return {"action": "first-publication-created", "revision": result["revision"]}


def verify(base, revision, expected_catalog, vercel=False, handler_sha256=None):
    health = probe(base, "/health")
    if health[0] != 200 or not health[1] or health[1].get("sourceRevision") != revision or health[1].get("published") is not True or health[1].get("conditionalWritesSupported") is not True:
        raise RuntimeError("Health and storage readiness check failed for " + base)
    catalog = probe(base, "/v1/catalog")
    if catalog[0] != 200 or not catalog[1] or canonical(catalog[1]) != canonical(expected_catalog) or catalog[2].get("x-release-revision") != revision or not catalog[2].get("etag"):
        raise RuntimeError("Live catalog content or source revision does not match for " + base)
    cached = probe(base, "/v1/catalog", {"If-None-Match": catalog[2]["etag"]})
    if cached[0] != 304:
        raise RuntimeError("ETag revalidation failed for " + base)
    first = expected_catalog["articles"][0]
    article = probe(base, "/v1/articles/" + first["id"])
    if article[0] != 200 or article[1] != first:
        raise RuntimeError("Individual guide check failed for " + base)
    search = probe(base, "/v1/articles?" + urlencode({"category": first["categoryID"], "limit": 2}))
    if search[0] != 200 or not search[1] or search[1]["revision"] != expected_catalog["revision"] or not all(item["categoryID"] == first["categoryID"] for item in search[1]["articles"]):
        raise RuntimeError("Search and pagination check failed for " + base)
    missing = probe(base, "/v1/articles/release-check-does-not-exist")
    if missing[0] != 404:
        raise RuntimeError("Missing guide check failed for " + base)
    unauthorized = probe(base, "/v1/publication", {"Content-Type": "application/json"}, "PUT", b"{}")
    if unauthorized[0] not in ({404, 405} if vercel else {403}):
        raise RuntimeError("Unauthenticated publication was not rejected by " + base)
    editor_checks = {}
    for method, path in (("GET", "/v1/editor/status"), ("POST", "/v1/editor/guides"), ("PUT", "/v1/editor/assets/" + "0" * 64)):
        for label, headers in (("missing", {}), ("wrong", {"Authorization": "Bearer hta_ed_" + "a" * 43})):
            result = probe(base, path, headers, method, None if method == "GET" else b"{}")
            if result[0] != 401:
                raise RuntimeError("Restricted editor did not reject " + label + " credentials for " + base)
            editor_checks[method + " " + path + " " + label] = 401
    artwork = probe(base, "/v1/illustrations")
    if artwork[0] != 200 or artwork[1].get("revision") != expected_catalog["revision"]:
        raise RuntimeError("Illustration manifest does not match the live catalog.")
    if vercel:
        manifest = probe(base, "/release.json")
        expected_sha = handler_sha256 or hashlib.sha256((BACKEND / "handler.py").read_bytes()).hexdigest()
        if manifest[0] != 200 or manifest[1].get("sourceRevision") != revision or manifest[1].get("handlerSHA256") != expected_sha:
            raise RuntimeError("Vercel artifact provenance check failed.")
    return {"health": 200, "catalog": 200, "etagRevalidation": 304, "individualGuide": 200, "searchPagination": 200,
            "missingGuide": 404, "unauthenticatedPublication": unauthorized[0], "catalogRevision": expected_catalog["revision"],
            "catalogSHA256": hashlib.sha256(canonical(expected_catalog)).hexdigest(), "sourceRevision": revision,
            "restrictedEditor": editor_checks, "illustrationManifest": 200}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["prepare", "parallel", "aws-only"])
    parser.add_argument("--profile", default="fishbowl-head")
    parser.add_argument("--region", default="us-west-2")
    parser.add_argument("--stack", default="how-to-adult-guides-v1")
    parser.add_argument("--project", default="how-to-adult-guides")
    parser.add_argument("--vercel", default=os.getenv("VERCEL_BIN", "vercel"))
    parser.add_argument("--editor-key-file", type=Path, help="Private credential JSON; deploy only its SHA-256. Omit to preserve the existing key.")
    parser.add_argument("--receipt", type=Path, default=BACKEND / "release-output" / "deployment-record.json")
    options = parser.parse_args()
    state = publication_state()
    if options.mode != "prepare":
        check_mode(options.mode, state, datetime.now(timezone.utc))
    revision = command(["git", "rev-parse", "HEAD"]).stdout.strip()
    clean = not command(["git", "status", "--porcelain", "--untracked-files=all"]).stdout.strip()
    if options.mode != "prepare" and not clean:
        raise RuntimeError("Deploy from a clean checkout of the committed release revision.")
    if options.mode != "prepare":
        try:
            import boto3
        except ImportError as error:
            raise RuntimeError("Install backend/requirements-dev.txt in an isolated Python 3.10+ environment before deployment. No remote changes were made.") from error
    origin = command(["git", "remote", "get-url", "origin"]).stdout.strip()
    if origin.removesuffix(".git") not in {"https://github.com/fennelouski/How-To-Adult", "git@github.com:fennelouski/How-To-Adult"}:
        raise RuntimeError("Unexpected repository origin; refusing to deploy.")
    frozen = freeze_source(revision) if options.mode != "prepare" else None
    command([sys.executable, "-m", "unittest", "discover", "-s", str(BACKEND / "tests"), "-v"], cwd=BACKEND)
    if frozen is not None:
        assert_release_source(frozen)
    catalog_data = frozen["files"]["Content/catalog.json"]["text"].encode("utf-8") if frozen is not None else (ROOT / "Content" / "catalog.json").read_bytes()
    catalog = validate_catalog(decode_json(catalog_data))
    output = BACKEND / "release-output"
    output.mkdir(exist_ok=True)
    path = prepare(revision, output, handler_source=frozen["files"]["backend/handler.py"]["text"] if frozen is not None else None, frozen=frozen)
    if options.mode == "prepare":
        print(json.dumps({"mode": "local-prepare", "sourceRevision": revision, "cleanCheckout": clean, "remoteActions": False,
                          "template": str(path), "templateBytes": len(path.read_bytes()), "seedArticles": len(catalog["articles"])}))
        return
    identity = aws(["sts", "get-caller-identity"], options)
    if identity.get("Account") != ACCOUNT:
        raise RuntimeError("AWS account does not match the authorized account.")
    assert_release_source(frozen)
    receipt = {"mode": options.mode, "status": "in-progress", "sourceRevision": revision, "verifiedRevision": None,
        "awsURL": None, "vercelURL": None, "actualCutoverAt": state.get("actualCutoverAt"), "commands": ["python3 backend/deploy.py " + options.mode],
        "checks": {}, "singleDataOwner": "AWS versioned private S3; Vercel relays reads and restricted editor requests", "scheduledGenerationEnabled": False,
        "productionDomainsChanged": False, "readiness": "New API; repeat deployment, rollback and parallel observation remain pending"}
    receipt["sourceSHA256"] = {name: item["sha256"] for name, item in frozen["files"].items()}
    receipt["templateSHA256"] = frozen["templateSHA256"]
    write_json(options.receipt, receipt)
    try:
        print("Deploying committed source revision " + revision, flush=True)
        resources = deploy_aws(revision, options, output, frozen, path)
        receipt.update(awsURL=resources["ApiURL"], awsRegion=options.region, stack=options.stack)
        write_json(options.receipt, receipt)
        receipt["bootstrap"] = bootstrap(resources["ApiURL"], catalog, options, frozen=frozen)
        assert_release_source(frozen)
        live = probe(resources["ApiURL"], "/v1/catalog")
        if live[0] != 200:
            raise RuntimeError("AWS publication could not be verified.")
        validate_catalog(live[1])
        receipt["checks"]["aws"] = verify(resources["ApiURL"], revision, live[1])
        write_json(options.receipt, receipt)
        if options.mode == "parallel":
            deployed = deploy_vercel(resources["ApiURL"], revision, options, output, frozen)
            receipt.update(vercelURL=deployed["url"], vercelDeploymentURL=deployed["deploymentURL"], vercelDeploymentID=deployed["deploymentID"], vercelProject=options.project)
            receipt["vercelArtifactSHA256"] = deployed["artifactSHA256"]
            write_json(options.receipt, receipt)
            receipt["checks"]["vercel"] = verify(deployed["url"], revision, live[1], vercel=True,
                handler_sha256=frozen["files"]["backend/handler.py"]["sha256"])
        assert_release_source(frozen)
        assert_artifacts({path: receipt["templateSHA256"]})
        if receipt.get("vercelArtifactSHA256"):
            assert_artifacts({output / "vercel" / relative: digest for relative, digest in receipt["vercelArtifactSHA256"].items()})
        receipt.update(status="verified", verifiedRevision=revision, sameRevisionVerified=True,
            verifiedAt=datetime.now(timezone.utc).isoformat(), handlerSHA256=frozen["files"]["backend/handler.py"]["sha256"])
        write_json(options.receipt, receipt)
        print(json.dumps(receipt, indent=2), flush=True)
    except Exception as error:
        receipt.update(status="incomplete", errorType=type(error).__name__, failedAt=datetime.now(timezone.utc).isoformat())
        write_json(options.receipt, receipt)
        raise


if __name__ == "__main__":
    main()
