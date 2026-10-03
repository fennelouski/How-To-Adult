# How to Adult content backend

The backend is implemented and verified locally. It has **not been deployed**. AWS CLI sign-in needs to be renewed before the first live release. The app's `AdultCatalogURL` must stay empty until the exact live reader endpoint is verified.

The app includes `Content/catalog.json`, so the starter guides work immediately without a network connection. Once configured, the app can download a new full catalog, validate it and retain its last valid copy. Reading, saved guides, checklist progress and reminders stay on the device.

## One publication store

An API Gateway HTTP API invokes a small Python Lambda. A private S3 bucket stores the current full catalog, immutable revision copies and S3 object versions. A complete publication replaces the current object atomically. The bucket blocks public access, requires HTTPS, encrypts its contents and is retained if the CloudFormation stack is deleted or replaced. The runtime cannot delete guides or previous object versions.

The Lambda role has `s3:ListBucket` for this one editorial bucket so a missing first catalog produces a distinct missing-object response. `GetObject` does not supply a listing prefix, so that bucket-level grant has no `s3:prefix` condition. Object reads and writes remain limited to the published catalog and revision prefixes. Access denials propagate as service failures and never count as an empty library. [AWS GetObject permissions](https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetObject.html).

Vercel serves an explicit GET-only gateway to the AWS reader routes during parallel operation. It has no database, AWS credentials, publishing route, background task or generation scheduler. `/release.json` records its own committed source revision and handler hash. Both endpoints therefore read the same AWS publication.

| Route | Method | Access | Result |
| --- | --- | --- | --- |
| `/health` | GET | Public | Source revision, publication readiness and conditional-write support |
| `/v1/catalog` | GET | Public | Full native catalog and publication ETag |
| `/v1/articles` | GET | Public | Searchable, paginated guide summaries |
| `/v1/articles/{id}` | GET | Public | One complete guide |
| `/v1/publication` | PUT | AWS IAM, direct AWS origin only | Validate and publish a complete library |

The reader needs no account. Search accepts `q`, `category`, `jurisdiction`, `limit` and `offset`. All query words must match the title, summary or tags. Jurisdiction matches the displayed jurisdiction string exactly, ignoring case. `limit` defaults to 50 and cannot exceed 100; results include `total` and `nextOffset`. The native app searches its downloaded catalog locally, so its searches do not use this server route.

Catalog and guide responses have ETags and a 60-second public cache lifetime. A matching `If-None-Match` returns HTTP 304. Missing guides return 404; an unpublished or unavailable library returns 503. A backend error does not turn into an empty successful catalog.

## Publication contract

Schema version 1 matches `Content/catalog.json`. The publication validator rejects missing or extra fields, duplicate IDs, unknown category references, invalid calendar dates, unsupported colors, duplicate list items or source URLs, credentials in source links, private source addresses and oversized content. Limits include 30 categories, 2,000 guides, 2–40 steps per guide, 8,000 characters per step body and a 4 MB complete catalog. These limits fit within the native reader's contract.

`revision` is a unique safe ID, such as `2026-10-04-guides-1`. `publishedAt` is a real UTC timestamp ending in `Z`. Each guide has a jurisdiction and an `updatedAt` date. `minutes` estimates the task or first session, rather than reading time. Keep article and step IDs stable when revising text so saved guides and completed steps keep their meaning.

Publishing requires one of these preconditions:

- `If-None-Match: *` creates the first publication and cannot replace an existing one.
- `If-Match: "current-etag"` replaces the exact publication the editor reviewed. A stale tag returns HTTP 412.

The store saves an immutable revision copy before updating the current object. Reusing a revision for different content or giving an update an older publication timestamp returns 409. A publication that loses a race can leave a harmless unpublished revision copy; it cannot change the winning live catalog. Bucket policies also enforce conditional writes. There is no unconditional force-publish option.

This validator checks structure and reader compatibility. It does not certify factual accuracy or decide whether a source is authoritative. Before publishing, review financial, tax, retirement, legal, health, food and safety guidance against current primary sources, identify the applicable jurisdiction and update the guide's review date. Original low-stakes lifestyle guidance may have an empty source list. Do not automatically publish generated advice without editorial review.

## Local checks

Use the user's owned Mac for builds and tests. No paid build service is involved. Python 3.10 or newer is needed for the pinned development SDK. The requirements include the AWS CRT dependency that the SDK's `aws login` credential provider needs. The deployed Lambda uses Python 3.13 and its AWS-managed SDK. `/health` reports whether that SDK supports the conditional S3 operations, and publishing fails closed if it does not.

```sh
python3 -m venv backend/.venv
backend/.venv/bin/python -m pip install -r backend/requirements-dev.txt
backend/.venv/bin/python -m unittest discover -s backend/tests -t backend -v
backend/.venv/bin/python backend/publish.py --check
backend/.venv/bin/python backend/deploy.py prepare
```

Run tests from `backend` if your unittest installation cannot import the tests with the command above:

```sh
cd backend
.venv/bin/python -m unittest discover -s tests -v
```

`prepare` builds a CloudFormation artifact locally and makes no AWS or Vercel changes. It clearly records whether the checkout is clean. Generated release artifacts, virtual environments and local test data are ignored by Git.

For an actual local HTTP reader, run:

```sh
backend/.venv/bin/python backend/local.py --port 8769
```

The server binds to `127.0.0.1`, exposes only reads and seeds its separate `backend/local-store` once. It never reads or modifies native user data. Delete only this disposable backend test store if you want to reseed a local test. Stop the owned server when checks are finished.

## First live release

Read the workspace `deployment-audit/deployment-policy.md` and `deployment-audit/parallel-deployments.json` before deploying. Through 2026-10-22 07:00 UTC, the same committed revision must be deployed and verified on AWS and Vercel. A push is not a deployment check. This is a new API with no production domain to move.

After sign-in, from a clean committed checkout:

```sh
aws login --profile fishbowl-head
backend/.venv/bin/python backend/deploy.py parallel
```

The command verifies the repository origin, the authorized AWS account, local tests and catalog validation before deployment. It freezes handler and catalog content from the exact committed Git blobs, then records hashes for the generated AWS template and Vercel files. It checks HEAD, checkout cleanliness, source hashes and relevant artifacts before remote release phases and the final receipt. Changes during a release stop it from being recorded as complete.

It validates a CloudFormation change set, deploys AWS and compares the deployed original template with the frozen artifact. It creates the starter publication **only if the live store is confirmed empty**, and preserves any existing published library. It then deploys Vercel Build Output v3 with the same Git SHA, reads Vercel deployment metadata and verifies actual public routes on both hosts. An interrupted first publication can retry its matching immutable revision; create-only writes still prevent replacing a library published by another editor.

Live checks cover source revision, identical catalog content, ETag revalidation, a complete guide, category filtering and pagination, missing guides, unauthenticated publishing rejection and Vercel artifact provenance. An incomplete release writes an incomplete receipt, even when one host already succeeded. It does not claim that a dual release completed.

`backend/release-output/deployment-record.json` is the generated live receipt. Review and record its evidence in the tracked `backend/deployment-record.json` and the workspace migration record. Include the verified SHA, actual command, both URLs, publication revision and checks. Set `AdultCatalogURL` to the verified Vercel `/v1/catalog` URL during parallel operation; keep the offline library and last-good cache behavior.

No code changes DNS, transfers a production domain, disables an existing deployment or removes data. The `parallel` command refuses after the policy cutoff or a recorded cutover. `aws-only` refuses until the tracked record explicitly contains a verified actual cutover and AWS routing ownership. Resolve an incomplete migration as an exception rather than silently using one host.

## Add or revise guides later

The editorial guide and validator live in `CONTENT-EDITORIAL.md` and `scripts/content_validate.py`. Start there when preparing new writing. Update the full catalog and publication ID, then validate it locally. Public updates do not require a new app binary once the reader URL is configured, provided the schema and native contract stay compatible.

Download and review the live catalog and its ETag before publishing. The editor's AWS role needs `execute-api:Invoke` only for the `PublisherResourceArn` output. Never put editorial credentials in the native app or in Vercel.

```sh
backend/.venv/bin/python backend/publish.py --check --catalog Content/catalog.json
backend/.venv/bin/python backend/publish.py --api-url https://VERIFIED_API_ID.execute-api.us-west-2.amazonaws.com --expected-etag '"REVIEWED_ETAG"'
```

The URL above is a placeholder, not a deployed endpoint. Use the exact verified AWS API origin from the release receipt. The publication client signs with the owner's AWS profile, accepts only an AWS API origin in the selected region and never prints credentials. A stale edit must be reviewed against the new live library before retrying.

To restore older editorial content, retrieve an immutable `revisions/{revision}.json` from the retained S3 bucket using the owner's authenticated AWS access. Review it, give the restored publication a **new** revision and current `publishedAt`, then publish with the current live ETag. Do not bypass the API by writing directly to S3. Code rollback uses a clean checkout of a known prior committed backend revision and the appropriate guarded deployment command. Both content and code rollback still need live verification and a recorded receipt; local tests do not prove a production rollback.

No daily generator or schedule is enabled. A later authoring loop can produce drafts, run the existing validators and submit explicitly reviewed publications through the same IAM endpoint.

## Privacy and logs

The API contains public editorial guides only. It does not accept reader identities, bookmarks, checklist progress, reminders, location, device tokens, contacts or private notes. No custom analytics or advertising code is installed.

API Gateway access logging is disabled in this template. Lambda retains operational CloudWatch logs for seven days. The handler logs only a generic failure and its exception class; it never logs request URLs, queries, bodies, IAM credentials, catalog text or personal activity. AWS runtime records can include request IDs, execution timing and memory usage.

AWS and Vercel process normal network request metadata, including IP addresses and requested paths, to provide hosting and security. Vercel may retain ordinary provider request logs under its account settings; this implementation does not claim that provider logging is disabled. Calling the optional server search route would transmit its query text to the hosting providers, while the native app's local search does not. There is no tracking identifier or private user activity store. The app privacy policy should disclose ordinary hosting requests before a live endpoint is enabled.

## Local evidence and remaining verification

On 2026-10-03, the 49 backend checks passed, including nine checks against the actual pinned boto3 service model, stubbed S3 conditional requests and the signed editorial client. First-publication permissions, interrupted publication retry, live-library preservation and rejected storage failures have regression coverage. Seven release tests cover frozen committed source, changed HEAD, untracked files, source edits hidden from Git status, artifact tampering and mutations before AWS, Vercel or publication writes. CloudFormation lint passed with cfn-lint 1.57.1 for the generated template. The real 56-guide starter catalog passed backend validation and actual loopback HTTP reader checks. These checks used an isolated environment on the user's Mac; no remote deployment, editorial publication, provider account or recurring job was created.

Live authentication, AWS CloudFormation validation, initial publication, both public reader deployments, repeat deployment, production rollback and the parallel observation period remain unverified.

## Primary implementation references

- [API Gateway IAM authorization](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-access-control-iam.html): route-specific IAM and SigV4 publishing.
- [S3 conditional requests](https://docs.aws.amazon.com/AmazonS3/latest/userguide/conditional-requests.html) and [enforced conditional writes](https://docs.aws.amazon.com/AmazonS3/latest/userguide/conditional-writes-enforce.html): atomic edit preconditions and bucket policy protection.
- [Boto3 PutObject](https://docs.aws.amazon.com/boto3/latest/reference/services/s3/client/put_object.html): `IfMatch` and `IfNoneMatch` SDK fields, checked against boto3 1.43.108 locally.
- [Python Lambda runtimes](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html): supported Python 3.13 runtime and managed SDK behavior.
- [CloudFormation Lambda function](https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-lambda-function.html): inline Python code and execution role.
- [Vercel Build Output configuration](https://vercel.com/docs/build-output-api/configuration): method-restricted external rewrites and independently deployed static provenance.
