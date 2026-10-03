# Native project

Open `HowToAdult.xcodeproj`. The shared schemes build iOS/iPadOS and native macOS,
with separate hosted XCTest and UI testing targets. Minimums are iOS 17 and macOS 14. There is
no visionOS target; compatibility support for visionOS is disabled.

Both app targets retain `com.nathanfennel.How-To-Adult`, development team
`EJLR2RPSV2`, version 1.0 and build 1. The two platforms share the `HowToAdult`
Swift module and `How to Adult.app` product name. The macOS target is a universal
native app with the App Sandbox and outgoing network access.

Regenerate the project after adding source files:

```sh
python3 scripts/generate-native-project.py
```

The generator requires only Python's standard library and writes stable object
identifiers. `project.yml` is a reference specification, not a dependency on
XcodeGen. The modern target compiles only `Sources/*.swift`, uses
`Content/catalog.json`, and includes the named asset and privacy resources.
Both unit-test bundles receive a copy of the catalog resource. UI test targets
compile `UITests/*.swift` and are excluded from ordinary running and archiving.

Build without starting Simulator:

```sh
xcodebuild -project HowToAdult.xcodeproj -scheme HowToAdult-iOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project HowToAdult.xcodeproj -scheme HowToAdult-macOS -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

The original Objective-C app, storyboard, Core Data model, tests and Xcode
project remain in their original locations and are excluded from these modern
targets. Its `How_To_Adult` Core Data model contains no entities. The modern app
does not open, rewrite or delete its SQLite store. Bookmarks, checked steps and
reminders use `Application Support/HowToAdult/UserLibrary-v1.json`; downloaded
article data uses `Application Support/HowToAdult/catalog-cache-v1.json`.

`AdultCatalogURL` is intentionally absent until an HTTPS catalog endpoint has
been deployed and verified. The native app can open its included library
without an account or network connection. Release deployment and App Store
verification records must report their actual state separately from this
project's ability to compile.

## Local Run action

Codex's Run action calls `./script/build_and_run.sh`, using a separate
`build/macos` directory. The script stops only a process whose executable path
matches this checkout's local app, builds, applies a local ad hoc debug signature
with the app's sandbox entitlements, and opens the new bundle. It supports
`--debug`, `--logs`, `--telemetry` and `--verify`. A process that does not exit
after a normal termination signal is preserved; the script never force-quits it.

## Native release packages

`scripts/release-native.py` archives and exports iOS and macOS locally. It
requires a supplied frozen commit matching HEAD and unchanged committed native
inputs. `--plan` validates these requirements and prints its commands without
building. `--platform iOS` or `--platform macOS` limits the work to one platform.

The export options use the App Store Connect method and `destination=export`.
The script does not upload, create an App Store Connect record, launch the app,
run tests or invoke Simulator. Xcode can use the user's signed-in developer
account for provisioning and managed distribution signing.

Archives, exported packages, source hashes, verification commands and logs go
to a new directory under `~/Library/Application Support/CodexReleaseArtifacts/HowToAdult/`
by default. `--output` can select another new directory outside the checkout.
Existing artifacts are never overwritten. The script validates signatures,
architectures, icons, matching bundled content and the privacy manifest; then
it verifies the IPA's app or the Mac installer and its embedded app. A successful
local export does not establish an upload or review submission.
