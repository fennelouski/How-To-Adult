# How to Adult

A native pocket guide to everyday life for iPhone, iPad and Mac. The included library has 56 guides across seven topics, with 224 checkable steps. It covers Home, Food, Money, Work, Wellbeing, People and Everyday.

Open a guide, follow its steps and keep useful answers for later. Guides include supplies, cautions and source links where needed. United States-specific guidance carries a visible jurisdiction label.

## Current app

- Browse and search the included library offline.
- Save guides and track completed steps locally.
- Set a local reminder with a chosen date, time and sound preference. Notification permission is requested when saving a reminder.
- Share a guide through the system share menu.
- Use native layouts on iPhone, iPad and Mac. Minimum versions are iOS/iPadOS 17 and macOS 14.

There is no account, subscription, in-app purchase, advertising or tracking SDK. Bookmarks, progress and reminders remain on each device. Cross-device sync is not implemented.

The 56-guide content service was verified on AWS and Vercel. Its 49 backend checks passed; initial and repeat deployments served the same publication from both hosts. Both native app configurations use the verified catalog URL. The bundled library still works offline, and the last valid downloaded library remains available after a failed update. No daily publishing schedule is enabled. The pocket-guide iOS release is Waiting for Review; the new Assistant source described below has not been uploaded or submitted.

## Assistant in development

The working source adds a dedicated Assistant tab. Describe a task, or choose “Help me do this” from a guide, then review a saved plan with separate reminder, calendar, research, shopping and checklist cards. This feature is not in the submitted iOS 1.0 build 1.

On-device planning requires iOS/iPadOS 26 or macOS 26, Apple Intelligence enabled and Apple's model reporting that it is available. Other supported devices can use an optional user-supplied OpenAI API key. Keys stay in this device's non-synced Keychain and are never included in saved plans. API requests are billed to the user's OpenAI API account. The current source does not offer ChatGPT sign-in or use a ChatGPT subscription; OpenAI has received the portfolio access request, but has not approved it.

Plans keep stable action IDs and durable reminder/calendar receipts. Interrupted or uncertain native writes require review before retrying. Reminder actions currently schedule app notifications; calendar actions create real events after permission. Automatic reminders and calendar events are off by default, apply only to newly generated plans when enabled, and leave already-created items intact when disabled. Deleting a local plan also leaves those native items intact.

OpenAI web research saves the original answer and clickable sources from provider annotations. Each action retains its own research; initial research used to create a plan remains separate. Shopping prepares an item list and can research sourced options. There is no integrated merchant checkout or order service.

The “Make a life plan” Shortcuts action requests execution without opening the app, so users can configure their own personal automations. Scheduled notifications are managed by the OS while the app is closed. AI runs when requested or invoked by Shortcuts, subject to provider availability, permissions and protected credentials. There is no always-on AI agent. Closed-app execution and live provider behavior still need final release verification.

See [Assistant design decisions](app-store-audit/2026-10-04-ai-assistant/native-design-decisions.md) and [Assistant release readiness](app-store-audit/2026-10-04-ai-assistant/release-readiness.md). The new source remains unshipped, with no version bump or new submission. Privacy policy and App Store disclosures must be updated and verified before releasing it.

The final Assistant source compiles for iOS and macOS. Its offline unit run passed 76 tests with one intentionally skipped live-catalog test; private UUID UI flows passed on iPhone and iPad. A real Apple Intelligence service call on this Mac produced a useful three-step checklist. Live OpenAI, native action delivery, closed-app Shortcuts and Mac app UI remain separate release checks. [Actual verification and limits](app-store-audit/2026-10-04-ai-assistant/verification.md).

## Build locally

Open `HowToAdult.xcodeproj` or regenerate it using Python's standard library:

```sh
python3 scripts/generate-native-project.py
```

Build the two native schemes without starting Simulator:

```sh
xcodebuild -project HowToAdult.xcodeproj -scheme HowToAdult-iOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project HowToAdult.xcodeproj -scheme HowToAdult-macOS -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

The generator creates separate unit-test and UI-test targets for both platforms. The native project uses SwiftUI and system frameworks, without third-party runtime packages. `project.yml` documents the project; XcodeGen is not required.

Codex's Run action calls `./script/build_and_run.sh` for local macOS development. It builds into `build/macos`, stops only this checkout's matching app process with a normal termination signal, and opens the resulting debug app. Coordinate GUI access before using it on a shared Mac. It never launches visionOS. See [native project and packaging notes](Configuration/NATIVE-PROJECT.md).

## Storage and the original app

The original Objective-C project, storyboard, Core Data model and tests remain in their original locations. The modern targets exclude them and never open, rewrite or delete the old SQLite store.

The modern app stores its library at `Application Support/HowToAdult/UserLibrary-v1.json`. A configured reader can store its last valid downloaded catalog at `Application Support/HowToAdult/catalog-cache-v1.json`. These paths are inside the platform's app container. No cloud sync is attached to either file.

The Assistant uses a separate `Application Support/HowToAdult/AssistantLibrary-v1.json` for plans, per-action research, execution receipts and automation preferences. Writes are atomic. Corrupt or unsupported files are preserved rather than replaced with an empty library. Plans remain device-local, with limits of 100 plans, 12 actions per plan and 2 MB for the archive. API keys are kept outside this file in Keychain.

## Content and backend

`Content/catalog.json` contains the starter library. Validate edits before including or publishing them:

```sh
python3 scripts/content_validate.py --self-test
```

Keep article and step IDs stable. Review financial, tax, retirement, health, food and safety guidance against current primary sources, mark the jurisdiction and update the review date. Task duration estimates describe the task or first session, rather than reading time. See [editorial guidance](CONTENT-EDITORIAL.md), [product decisions](PRODUCT.md) and [native design decisions](DESIGN.md).

[BACKEND.md](BACKEND.md) describes the public catalog API, authenticated editorial publishing, validation, versioned storage, rollback and local checks. The native reader can fetch a verified HTTPS catalog once configured; its search, bookmarks, progress and reminders remain local. No daily authoring job is enabled.

Web/API releases must follow the workspace AWS migration policy, including verified AWS and Vercel deployments from the same committed revision during parallel operation. The verified production reader during parallel operation is `https://how-to-adult-guides.vercel.app/v1/catalog`. AWS owns the only private publication store, and Vercel provides GET-only forwarding. [The deployment receipt](backend/deployment-record.json) records both-host checks and the initial/repeat releases at `7b6a116dc1e10ce002d3293be68c347d0939e365`. Code rollback and sustained parallel observation remain pending.

## Release state

The saved [iOS submission receipt](app-store-audit/2026-10-04-release/ios-submission-receipt.json) records **iOS 1.0 build 1, Waiting for Review**, submitted October 4, 2026 at 2:44 PM Europe/Amsterdam. Apple ID is `6818756061`; the native release revision is `ca8edc4e786d25504b06fa177468f42adde376fd`. The build retains bundle identifier `com.nathanfennel.How-To-Adult` and development team `EJLR2RPSV2`. It is free in all 175 listed countries, available in those countries on release, with future regions enabled and automatic release after approval. Waiting for Review does not establish approval or public availability.

macOS 1.0 remains Prepare for Submission, held for original-bundle native runtime/window QA and gallery verification. It has not been submitted. The working Assistant source has not replaced either candidate, and the repository still has no new version bump, upload or Assistant review submission.

The planned public privacy and support pages are `https://nathanfennel.com/how-to-adult/privacy.html` and `https://nathanfennel.com/how-to-adult/support.html`. Both pages are publicly accessible and verified against identical committed bytes on AWS and Vercel. The privacy page is unlisted and uses noindex, nofollow and noarchive. [Website verification](app-store-audit/2026-10-03-how-to-adult/website-live-verification.json).

Earlier preparation receipts are retained as history. The offline package freeze was `ab95cedbe7401da1f11f52e5befeafbc0b04848d`, followed by catalog configuration at `00b817d`. Earlier signed iOS and Mac exports were inspected against 35 native inputs and canonical SHA-256 `45c558b118e8813b7bad781f7e24538a395cff2ccffb8fd14b4f797f739f8c6e`; the bundled catalog, icons, signatures and encryption key were verified. See [historical package inspection](app-store-audit/2026-10-03-how-to-adult/final-package-inspection-contrast-final.json). The authoritative submitted iOS source/package and QA proofs are now in the October 4 submission receipt, not those earlier freezes.

The [independent finish review](app-store-audit/2026-10-03-how-to-adult/design-finish-review.md) approved the scoped phone/tablet captures and galleries. The final submitted iOS receipt records approval of all 20 actual Apple-hosted marketing images, ten per iPhone/iPad. The [bounded iOS QA handoff](app-store-audit/2026-10-04-release/HOW-TO-ADULT-IOS-QA-HANDOFF.md) records genuine notification delivery and tap routing, denial/recovery, picker cancellation and dark/largest-text checks, with earlier failed rounds preserved. These are Simulator proofs with documented limits; they do not establish physical sound, every notification mode, minimum-OS runtime or Mac functionality. The Mac evidence gap remains open.

The privacy/support pages have saved dual-deployment history from website revision `5c00d3f8ddbc48fa62f8504c527128a0ae8fa75b`. The submitted-build receipt includes October 4 verification at website revision `9e2058d195bf3c8ef1e6630267e815a1346349d3`, and a published privacy label disclosing linked Other Diagnostic Data for App Functionality with no tracking. The full website AWS migration remains pending. The [draft listing and privacy reasoning](app-store-audit/2026-10-03-how-to-adult/app-store-metadata.md) and [historical release checklist](app-store-audit/2026-10-03-how-to-adult/release-checklist.json) are preserved. The old Data Not Collected proposal is superseded for the catalog-connected submitted build. [Provider privacy facts](backend/provider-privacy-verification.json) inform that disclosure. Existing public policy verification covers that earlier build; an Assistant policy/disclosure update has not been deployed or verified.

Native release scripts prepare local archives and App Store packages only after a frozen committed revision passes QA. Upload and submission are separately recorded in release receipts. There is no visionOS target, and visionOS build, Simulator, upload and submission work remains disabled at the user's request.
