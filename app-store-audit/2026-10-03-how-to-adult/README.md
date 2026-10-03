# How to Adult release evidence

The native app and publishing backend are implemented. The iPhone and iPad checks, signed exports and 20 marketing images are complete for the recorded source freeze. **The app has not been uploaded or submitted for review, and its backend and public privacy/support pages are not deployed.**

## Current source and evidence

Native source revision: `ab95cedbe7401da1f11f52e5befeafbc0b04848d`. The 35 native inputs have canonical SHA-256 `45c558b118e8813b7bad781f7e24538a395cff2ccffb8fd14b4f797f739f8c6e`. Later documentation and evidence commits do not change these inputs. [Input proof](native-inputs-contrast-final.json) and [final consistency verification](verification.json) preserve that distinction.

| Scope | Verified result | Evidence |
| --- | --- | --- |
| Starter library | 56 guides, seven topics, 224 steps | `Content/catalog.json`, `CONTENT-EDITORIAL.md`, `Content/source-review.json` |
| iPhone 17 Pro Max, iOS 26.5 | 10 model tests and two UI flows passed; 13 genuine captures | [Test summary](iphone-test-summary.json), [capture manifest](raw/iphone-contrast-final/manifest.json) |
| iPad Pro 13-inch M5, iOS 26.5 | 10 model tests and two UI flows passed; 13 genuine captures | [Test summary](ipad-test-summary.json), [capture manifest](raw/ipad-contrast-final/manifest.json) |
| Signed iOS and universal Mac packages | Archives and exports succeeded; signatures, icons, embedded catalog, privacy manifest, configuration and package hashes inspected | [Build receipt](release-verification-contrast-final.json), [package inspection](final-package-inspection-contrast-final.json) |
| iPhone and iPad marketing | Ten images per gallery; all 20 independently reviewed | [Gallery preview](marketing/composed-contrast-final/review-index.html), [review status](marketing/composed-contrast-final/review-status.json), [provenance](marketing/composed-contrast-final/marketing-provenance.json) |
| Publishing backend | 49 local tests passed, including actual SDK and provenance checks; CloudFormation lint and loopback HTTP checks passed | `backend/local-verification.json`, `BACKEND.md` |
| Privacy/support pages | Both pages previewed at phone and desktop sizes; unlisted and readable | [Local previews](website-preview/); website repository commit `416fd8fb62fa46c8e40b4634ffd6ac5c095c8615` |

The phone and iPad flows cover guide search, source links, US scope labels, saving, checked-step persistence after relaunch, reminder date and optional sound, removal, Settings, dark appearance and accessibility text. The review resolved authored secondary-text contrast. The native search placeholder retains the operating system's standard styling. No whole-app accessibility certification is claimed.

Packages remain outside Git in `~/Library/Application Support/CodexReleaseArtifacts/HowToAdult/Revision-ab95cedbe740-20261003T062155Z/`. The receipts record absolute paths and hashes. An export proves package preparation; it does not replace runtime testing or an Apple upload receipt.

## Remaining work and access

The [release checklist](release-checklist.json) is the authority for pending actions. The [finish review](design-finish-review.md) has disposition **recapture**, because the final Mac runtime, its 13 native captures and ten Mac marketing images remain missing. Earlier Mac captures are superseded.

macOS is waiting for a container-sharing consent decision before the original signed app initializes. The native automation tool rejected access to `UserNotificationCenter` for safety. The owner must handle this system decision; no alternate bundle, deleted container, changed permission or restarted security service was used to bypass it. The local debug app is preserved while it waits.

Actual notification delivery and tap routing, permission-denied recovery, and a runtime smoke check at the minimum supported OS versions remain pending. Current runtime evidence is from iOS 26.5, with deployment targets of iOS/iPadOS 17 and macOS 14.

AWS CLI authentication is expired; its [sanitized preflight](aws-auth-preflight.json) records the failed access check without credentials or account output. Confirmation was requested before `aws login`, as required by the AWS sign-in skill. App Store Connect also needs owner sign-in in the preserved handoff tab. The existing app record, previous build numbers, pricing, territory coverage and compliance answers are unverified.

The current native packages omit `AdultCatalogURL` and make no automatic catalog requests. The bundled build has no account, sync, purchases, ads, tracking SDK or daily publishing job. The backend can publish reviewed guides manually once deployed; no daily article loop was scheduled. Any future live catalog must pass provider privacy review and update the distributed app and label as needed.

## Resume without repeating completed work

1. Resolve Mac consent, then verify the original app's controls, persistence, reminder/Settings sheets and window resizing. Capture current Mac evidence and finish its gallery and independent review.
2. Finish the pending notification and minimum-OS checks. Preserve the frozen source proof; a native change requires new tests, captures and packages for that changed revision.
3. After AWS access is restored, deploy the backend with the repository's `backend/deploy.py parallel` workflow using a clean committed revision. Deploy the prepared website pages with its verified command: `npm exec --yes --package=node@22 -- python3 scripts/deploy-app-privacy.py`. Read the workspace deployment policy and current deployment records first. Verify AWS and Vercel from the same respective committed revision and record both URLs and checks; keep production routing on Vercel during parallel testing.
4. After App Store sign-in, inspect the original record, resolve any version/build-number conflicts, save the prepared listing, set free pricing in all eligible storefronts, upload and verify processing, complete compliance/privacy with required owner attestations, and submit for review. Record Apple's actual receipt.

The selected final source/output hashes were checked again in `verification.json`. Diagnostic runs and the superseded `e719475` captures, galleries and packages are preserved locally and excluded from this final evidence commit. The owned phone and iPad Simulators have been shut down and their shared GUI lease returned. No visionOS build or Simulator was used.
