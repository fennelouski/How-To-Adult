# Remote content editor

The independent content agent uses a restricted Bearer credential. It needs no AWS profile, console session, infrastructure permissions or paid generation subscription. AWS remains the single publication store. Vercel relays the permitted editor and reader routes during parallel operation.

Verified origins:

- `https://how-to-adult-guides.vercel.app` (preferred)
- `https://m0jxoitx8f.execute-api.us-west-2.amazonaws.com`

The credential is provided separately in a private JSON file. Transfer it securely to the agent's computer, outside Git, and set mode `0600`. Its fields are `HOWTOADULT_EDITOR_API_KEY` and `HOWTOADULT_EDITOR_BASE_URL`. Never paste its contents into source, prompts, screenshots or logs. Environment variables with the same names also work. The supplied Python client refuses other origins and redirects, and sends the credential only to editor routes.

## Authoring workflow

Read `CONTENT-EDITORIAL.md` first. Research, write, illustrate and review each guide. High-stakes material needs editorial approval under that policy before publication. Keep stable guide and step IDs. Use the current live catalog as the baseline, because it may contain updates newer than the bundled seed.

The client needs Python 3.10+ and the standard library only. From the repository root:

```sh
python3 backend/editor_client.py --credentials /secure/path/editor-credentials.json status
python3 backend/editor_client.py --credentials /secure/path/editor-credentials.json catalog --output live-catalog.json
python3 backend/editor_client.py --credentials /secure/path/editor-credentials.json upload-image content-assets/example.png
python3 backend/editor_client.py --credentials /secure/path/editor-credentials.json publish batches/example.json --expected-etag '"THE_QUOTED_ETAG_YOU_REVIEWED"' --receipt receipts/example.json
```

`catalog` prints the current quoted ETag. Review that snapshot and validate the merged candidate with both `scripts/content_validate.py` and `backend/handler.py:validate_catalog` before publishing. The endpoint also validates the merged catalog. A `412` means another editor changed it: fetch, compare, review and rebuild your batch. The client never blindly retries a write with a newer ETag. If a response was interrupted, inspect the live revision and guide content before retrying.

## Contract

| Route | Method | Access | Purpose |
| --- | --- | --- | --- |
| `/v1/editor/status` | GET | Bearer key | Scopes, limits, current revision |
| `/v1/editor/guides` | POST | Bearer key + `If-Match` | Merge 1–25 guides, preserving omitted guides |
| `/v1/editor/assets/{sha256}` | PUT | Bearer key | Immutable PNG upload |
| `/v1/assets/{sha256}` | GET | Public | Actual PNG bytes |
| `/v1/illustrations` | GET | Public | Image associations for the live catalog revision |
| `/v1/catalog` | GET | Public | Native schema-1 catalog and ETag |
| `/v1/publication` | PUT | AWS IAM, direct AWS only | Owner's complete-catalog publisher |

Editor routes use `Authorization: Bearer <securely loaded key>`. Query parameters cannot carry credentials. Editor keys cannot delete guides or assets, invoke the owner's full-catalog publisher, manage infrastructure, read reader activity or access the AWS account. The holder can publish public editorial text and images, so treat the key as a publishing credential.

`POST /v1/editor/guides` requires `Content-Type: application/json` and the exact current quoted `If-Match`. Every batch has exactly these fields:

```json
{
  "revision": "unique-publication-id",
  "publishedAt": "REAL_CURRENT_UTC_TIMESTAMP_ENDING_IN_Z",
  "articles": [],
  "categories": [],
  "replaceExisting": false,
  "illustrations": []
}
```

Supply 1–25 complete schema-1 articles, with precisely these fields: `id`, `title`, `summary`, `categoryID`, `symbol`, `minutes`, `jurisdiction`, `updatedAt`, `tags`, `tools`, `steps`, `cautions`, `sources`. Each step has `id`, `title`, `body`; each source has `title`, `url`. Consult the live catalog for a complete example. Use 3–6 steps when the task allows, and fit both native and backend validation limits.

Reuse existing categories. `categories` may add up to ten new categories; existing categories cannot be changed through this endpoint. A category has `id`, `title`, `symbol`, `colorKey`. Supported colors: teal, orange, green, blue, rose, purple, indigo.

New guides use `replaceExisting: false`. Set it to `true` only when intentionally replacing a reviewed existing guide; it still preserves every omitted guide. IDs must be unique within a batch. Each publication needs a new safe revision and a timestamp strictly later than the current catalog, no later than the actual current UTC time. The catalog supports up to 2,000 guides and 4 MB. Revision copies and uploaded assets are immutable; conflicting reuse is rejected.

## Images

Upload an actual non-interlaced, 8-bit RGB or RGBA PNG, at most 2 MB and 4096 × 4096. Export palette/grayscale images as RGB first. The upload path is the lowercase SHA-256 of the exact bytes. The server checks signature, chunks, checksums, dimensions and bounded pixel decompression. Repeating the same upload is safe. SVG, arbitrary files, corrupt images and digest mismatches are rejected.

Associate uploaded images through the batch's `illustrations` list, with at most 100 associations:

```json
{
  "guideID": "existing-or-new-guide-id",
  "stepID": "",
  "assetSHA256": "64_LOWERCASE_HEX_CHARACTERS_FROM_UPLOAD",
  "altText": "What this picture teaches, expressed in words.",
  "caption": "",
  "creator": "Who created the artwork",
  "license": "Rights that allow distribution in this app",
  "provenance": "How it was created, or the licensed original source and license evidence"
}
```

An empty `stepID` selects the guide's hero image. Otherwise reference an actual step ID. One image occupies each guide/step slot. Omitted associations persist; explicit replacement updates a slot. Every image needs meaningful alt text, creator, license and provenance. Inspect the actual exported image before publishing.

Illustrations live in a revision-bound sidecar so native schema 1 stays compatible. A failed or conflicting publication cannot switch the current illustration manifest. The existing native app does not yet render this sidecar; image assets and associations are ready for its next separately reviewed reader integration. Do not claim an image is visible in the current app solely because its upload succeeded.

## Owner operations

Generate a fresh private credential without printing it:

```sh
python3 backend/provision_editor.py /private/new-editor-credentials.json
backend/.venv/bin/python backend/deploy.py parallel --editor-key-file /private/new-editor-credentials.json
```

The parent directory must be owned by the user and mode `0700`; the new file is `0600`. Provisioning refuses existing files and paths inside the repository. Deployment reads the file in memory and sends only its SHA-256 to a `NoEcho` CloudFormation parameter. Neither template nor Lambda contains the plaintext key. Only one editor key is active. Rotate by generating a new file and deploying its hash; the previous token stops authorizing requests. A normal deployment omitting `--editor-key-file` preserves the existing hash. An empty hash disables editor routes.

Before infrastructure deployment, read `AGENTS.md`, `deployment-audit/deployment-policy.md`, `deployment-audit/parallel-deployments.json`, and `backend/deployment-record.json`. Deploy AWS and Vercel from the same committed revision during parallel operation. The content agent uses the editor API rather than deploying infrastructure for each article: this changes the shared AWS publication, which both hosts read.

No scheduler is installed by this endpoint. Persistent authoring requires an actively running agent or an explicitly configured recurring execution environment. Checkpoint drafts, reviews, assets, publication receipts and backlog so interrupted work can resume.
