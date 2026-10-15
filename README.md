# How to Adult

A native pocket guide for iPhone, iPad and Mac. The bundled public snapshot contains 273 guides across seven topics and matches the existing AWS/Vercel publication. Its exact-revision sidecar identifies 233 teaching illustrations. Search works locally; saved guides, checked steps, reminders, personal notes and ratings stay on the device.

The Fieldnotes interface uses warm paper, pine ink, clay actions and serif headings. It adapts from compact tabs to native guide-index/reader columns, retains search and selection while resizing, supports Dynamic Type and both appearances, and offers image descriptions and full-size zoom. Full guide bodies, cautions, jurisdiction, sources and stable guide/step identities are preserved.

## Assistant source

Assistant is a separate tab and the guide's “Help me do this” route prepares its real context. Plans retain reminder, calendar, research, shopping and checklist actions, stable IDs and durable execution receipts. Existing explicit execution/automation opt-ins, uncertain-write review and shared notification limits remain in force. Automation defaults to off and affects only new eligible plans; deleting a plan does not remove native items already created.

On-device planning requires the existing Apple Intelligence availability checks on supported 26+ systems. Other devices may use the existing optional user-supplied OpenAI API key. Keys remain in non-synced device Keychain storage. OpenAI requests use the user's API account and may incur its charges. Nothing is generated merely by opening a guide. Shopping prepares a list; there is no integrated checkout. Shortcuts invokes the existing “Make a life plan” intent. There is no always-on authoring service.

Skill-passport models and tests are retained. Its navigation is a DEBUG-only review session with explicit fixture gates; it is absent from ordinary navigation. No new passport content has been admitted.

## Build and verify locally

Run `python3 scripts/generate-native-project.py`, then open `HowToAdult.xcodeproj`. Active schemes are HowToAdult-iOS and HowToAdult-macOS; minimum systems remain iOS/iPadOS 17 and macOS 14. Existing visionOS source/assets are preserved, but the generator does not create or build a visionOS target under the owner's current restriction.

The native tests use blank hosts or private UUID sessions before ordinary library, preferences or Keychain initialization. Private UI sessions use their own data/defaults, show a QA marker and disable AI, scheduling and external actions. A separate art-read flag allows immutable public artwork without catalog refresh. Historical permission/device UI probes are retained under UITests/Legacy outside the active source glob.

The original Objective-C app and Core Data files remain in place. Modern targets never open or rewrite the old SQLite store. The modern UserLibrary-v1.json retains prior bookmarks/check fingerprints/reminders when optional notes and ratings are added. Notes keep explicit Save/Cancel, dirty-dismiss/discard protection and concurrent-edit checks.

## Content service

The verified reader origins are https://how-to-adult-guides.vercel.app and https://m0jxoitx8f.execute-api.us-west-2.amazonaws.com. This integration does not publish a catalog or deploy infrastructure. Content writes continue to use the existing editorial API contracts, ETags and version guards. No daily generation schedule is enabled. See BACKEND.md, EDITOR-API.md and CONTENT-EDITORIAL.md.

Public content and artwork must remain separate from recovery/review material. Only the 273-guide catalog, its exact manifest and the 233 referenced PNGs seed the reader backend. Artwork is bound to the exact catalog/service fingerprint and verifies PNG digest, byte and dimension limits before display/cache; an artwork failure leaves text/progress usable.

## Verification limits

Local build/test and native capture receipts belong to the integration handoff. A previous design verdict does not certify later code, live providers, native external-action delivery, minimum-OS runtime, App Store status or publication. Current Mac resizing is unobserved while the Studio is locked, and spoken VoiceOver traversal remains unobserved. This source has not been uploaded or submitted during this integration.

## Release state

The saved [iOS submission receipt](app-store-audit/2026-10-04-release/ios-submission-receipt.json) records **iOS 1.0 build 1, Waiting for Review**, submitted October 4, 2026 at 2:44 PM Europe/Amsterdam. Apple ID is `6818756061`; the native release revision is `ca8edc4e786d25504b06fa177468f42adde376fd`. The build retains bundle identifier `com.nathanfennel.How-To-Adult` and development team `EJLR2RPSV2`. It is free in all 175 listed countries, available in those countries on release, with future regions enabled and automatic release after approval. Waiting for Review does not establish approval or public availability.

macOS 1.0 remains Prepare for Submission, held for original-bundle native runtime/window QA and gallery verification. It has not been submitted. The working Assistant source has not replaced either candidate, and the repository still has no new version bump, upload or Assistant review submission.

The planned public privacy and support pages are `https://nathanfennel.com/how-to-adult/privacy.html` and `https://nathanfennel.com/how-to-adult/support.html`. Both pages are publicly accessible and verified against identical committed bytes on AWS and Vercel. The privacy page is unlisted and uses noindex, nofollow and noarchive. [Website verification](app-store-audit/2026-10-03-how-to-adult/website-live-verification.json).

Earlier preparation receipts are retained as history. The offline package freeze was `ab95cedbe7401da1f11f52e5befeafbc0b04848d`, followed by catalog configuration at `00b817d`. Earlier signed iOS and Mac exports were inspected against 35 native inputs and canonical SHA-256 `45c558b118e8813b7bad781f7e24538a395cff2ccffb8fd14b4f797f739f8c6e`; the bundled catalog, icons, signatures and encryption key were verified. See [historical package inspection](app-store-audit/2026-10-03-how-to-adult/final-package-inspection-contrast-final.json). The authoritative submitted iOS source/package and QA proofs are now in the October 4 submission receipt, not those earlier freezes.

The [independent finish review](app-store-audit/2026-10-03-how-to-adult/design-finish-review.md) approved the scoped phone/tablet captures and galleries. The final submitted iOS receipt records approval of all 20 actual Apple-hosted marketing images, ten per iPhone/iPad. The [bounded iOS QA handoff](app-store-audit/2026-10-04-release/HOW-TO-ADULT-IOS-QA-HANDOFF.md) records genuine notification delivery and tap routing, denial/recovery, picker cancellation and dark/largest-text checks, with earlier failed rounds preserved. These are Simulator proofs with documented limits; they do not establish physical sound, every notification mode, minimum-OS runtime or Mac functionality. The Mac evidence gap remains open.

The privacy/support pages have saved dual-deployment history from website revision `5c00d3f8ddbc48fa62f8504c527128a0ae8fa75b`. The submitted-build receipt includes October 4 verification at website revision `9e2058d195bf3c8ef1e6630267e815a1346349d3`, and a published privacy label disclosing linked Other Diagnostic Data for App Functionality with no tracking. The full website AWS migration remains pending. The [draft listing and privacy reasoning](app-store-audit/2026-10-03-how-to-adult/app-store-metadata.md) and [historical release checklist](app-store-audit/2026-10-03-how-to-adult/release-checklist.json) are preserved. The old Data Not Collected proposal is superseded for the catalog-connected submitted build. [Provider privacy facts](backend/provider-privacy-verification.json) inform that disclosure. Existing public policy verification covers that earlier build; an Assistant policy/disclosure update has not been deployed or verified.

Native release scripts prepare local archives and App Store packages only after a frozen committed revision passes QA. Upload and submission are separately recorded in release receipts. There is no visionOS target, and visionOS build, Simulator, upload and submission work remains disabled at the user's request.
