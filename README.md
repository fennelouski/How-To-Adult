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

The backend is implemented and has local verification, but it is not deployed. `AdultCatalogURL` is absent from both app configurations. This build uses its bundled library and does not claim live article updates, AI writing or a daily publishing schedule. Native QA and release preparation are underway; no build has been uploaded or submitted for App Review.

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

## Content and backend

`Content/catalog.json` contains the starter library. Validate edits before including or publishing them:

```sh
python3 scripts/content_validate.py --self-test
```

Keep article and step IDs stable. Review financial, tax, retirement, health, food and safety guidance against current primary sources, mark the jurisdiction and update the review date. Task duration estimates describe the task or first session, rather than reading time. See [editorial guidance](CONTENT-EDITORIAL.md), [product decisions](PRODUCT.md) and [native design decisions](DESIGN.md).

[BACKEND.md](BACKEND.md) describes the public catalog API, authenticated editorial publishing, validation, versioned storage, rollback and local checks. The native reader can fetch a verified HTTPS catalog once configured; its search, bookmarks, progress and reminders remain local. No daily authoring job is enabled.

Web/API releases must follow the workspace AWS migration policy, including verified AWS and Vercel deployments from the same committed revision during parallel operation. No live endpoint or deployment receipt exists yet. Refresh the owner's AWS CLI authentication before attempting deployment. Do not configure a guessed URL.

## Release state

Version 1.0, build 1 retains bundle identifier `com.nathanfennel.How-To-Adult` and development team `EJLR2RPSV2`. The intended price is free in every eligible App Store territory, but pricing and availability have not been saved or verified in App Store Connect. App Store authentication is blocked, and the existing app record is unknown.

The planned public privacy and support pages are `https://nathanfennel.com/how-to-adult/privacy.html` and `https://nathanfennel.com/how-to-adult/support.html`. They still need deployment and public URL verification. An unlisted privacy page must remain publicly accessible.

The [draft listing and privacy reasoning](app-store-audit/2026-10-03-how-to-adult/app-store-metadata.md) and [release checklist](app-store-audit/2026-10-03-how-to-adult/release-checklist.json) distinguish implemented work from final test, package, website and store evidence. The label proposal applies to the bundled build. Provider request retention must be reviewed before enabling a remote catalog.

Native release scripts prepare local archives and App Store packages only after a frozen committed revision passes QA. They do not upload or submit a release. There is no visionOS target, and visionOS build, Simulator, upload and submission work remains disabled at the user's request.
