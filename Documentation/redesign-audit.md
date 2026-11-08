# Navigation and reading redesign: discovery audit

8 November 2026. Branch `claude/how-to-adult-redesign`, from `main` at `3f59cb1`. No versions, uploads, App Store metadata, privacy answers or backend files were changed.

## How this was checked

- Read README, PRODUCT, DESIGN, CONTENT-EDITORIAL, `Documentation/skill-passport-review.md`, the workspace `AGENTS.md` and `app-design-guidelines.md`, and all of `Sources/`.
- Built `HowToAdult-iOS` (Xcode 26.6, iOS 26.5 Simulator) on two new dedicated simulators, `HowToAdult Redesign iPhone` (iPhone 17 Pro) and `HowToAdult Redesign iPad` (iPad Pro 13-inch M5).
- Ran the existing `testGuidesSearchSaveProgressAndGallery` and `testDarkAppearanceAndAccessibilityText` UI tests on both. All four runs passed and produced 13 captures per device: guides, guide, steps, sources, saved, search, money guide, reminder sheet, reminders, settings, and dark/accessibility-3 guides, reader and sources.
- Mac was not run in this pass.

`HowToAdult.xcodeproj` is canonical: `scripts/generate-native-project.py` writes it and globs `Sources/`, `Tests/` and `UITests/`. `How To Adult.xcodeproj` is the original Objective-C prototype. Its last change was the early commit `4e52875`. Leave it untouched.

## What is weak

1. **The first screen is mostly preamble.** On iPhone, the title, a serif slogan, a tagline and one featured card fill the first viewport. About two guide rows show. At accessibility sizes, no guide is visible without scrolling.
2. **Topics are hidden.** The seven categories sit inside an "All topics" menu, so nothing on screen shows the shape of the library. Region is a second text menu.
3. **"One step at a time" is a list.** The reader is a single scroll: header, a full-width "Help me do this" button, tools, four steps, cautions, sources, rating, notes, review date and reminder. Cautions and sources come after every step, so you scroll past them while doing the task.
4. **Progress is weak.** Rows show "2 of 4 done" text only. The app has no "in progress" view, no progress bar and no sense of accomplishment after finishing.
5. **Text where visuals would do.** Several items are prose: "About 10 min · 4 steps", "Open guide", "Before you start", "Good to know", "Go to the source", "Make this yours", the slogan, and every empty state. Category color appears only on one small row icon.
6. **iPad and Mac compress the browser.** A three-column split leaves the guide list in a narrow 360-point middle column. The wide screen goes to a reader capped at 760 points.
7. **Tab sprawl.** Guides, Assistant (unshipped), Saved and Reminders are peers. Saved and Reminders are filtered copies of the same list.

## What is salvageable

- **The data and store discipline.** Atomic writes, validate-before-commit, preserved corrupt files and the last-good catalog cache are solid. Extend them, don't replace them.
- **Step fingerprints.** `checkedSteps[id] = fingerprint` already makes a step need re-checking after an edit. "Known" can reuse the same mechanism.
- **Category model.** The catalog already gives each of the seven categories a `symbol` and `colorKey`, and each guide has its own SF Symbol. That is enough to start a visual system.
- **Accessibility groundwork.** Text wraps everywhere, row elements are combined, and step buttons have labels, values and hints. The existing UI test identifiers can be kept where flows survive.
- **Passport engine.** `AdultPassportCore` and `AdultPassportStore` cover admission, one-to-one skill and badge mapping, undo that keeps a private record, confidence and hiding, with 17 tests. The views are DEBUG-only and the production manifest is empty.
- **Reminder, share, notes and rating flows** work and are tested. They can move into the overflow menu.

## Architecture constraints

- **Content shape.** 56 guides in 7 categories (6 to 10 per category). Every guide has exactly 4 steps. The longest step body is 225 characters, and the median is 136. Each guide has 1 to 6 tools, 0 or 1 caution, and 0 to 2 sources. That fits a carousel: one step per page rarely needs scrolling.
- **No sub-areas exist in the data.** Only free-form `tags` (`laundry`, `food safety`, `credit`, `taxes`, `401k`, `car`, `job search`, …). Adding a `subcategory` field would change the published catalog schema, the validator and the hosted backend. This work avoids that. Sub-areas would be derived in the app from tags, with an "Other" group for guides that match no sub-area.
- **Persistence.** `UserLibrary-v1.json` holds `[articleID: ArticleProgress]` with `schemaVersion == 1`, checked strictly. Synthesized `Codable` makes new non-optional fields fail on old files, so new fields must be optional (or need a custom decoder). Additive optional keys with `schemaVersion` still 1 keep files readable by the submitted 1.0 build, which ignores unknown keys. That is the safest migration.
- **"Saved" is the shipped bookmark** (`isSaved`). Favorites for guides should reuse it, not add a second flag. Step favorites are new.
- **Passport rule conflict.** The passport design states that reading and checking steps cannot award a skill. Awards need an admitted, reviewed manifest entry plus an explicit self-report on a bounded real-world task. Production admission is empty, so production users can earn nothing yet. A "degrees from completing guides" tab has to sit beside this rule, not overwrite it.
- **Navigation state.** `AdultRootView` owns a `TabView` (compact) or a 3-column `NavigationSplitView` (iPad regular, Mac, visionOS). It keeps one `[String]` path per tab and one `selectedID`. Notification taps and `howtoadult://guide/<id>` route through `store.requestedGuideID`. The redesign must keep both routes.
- **Scenes.** This is a SwiftUI `App` with a single `WindowGroup` on iOS and `UIApplicationSupportsMultipleScenes = true`. No scene delegate exists. A dedicated external display needs a `UIApplicationDelegateAdaptor` that returns a configuration for `windowExternalDisplayNonInteractive`, plus a small `UIWindowSceneDelegate` hosting SwiftUI. Shared "what is on screen" state must live outside any single view.
- **Platforms.** visionOS source and targets exist. Under `AGENTS.md`, use generic visionOS compile checks only and never boot its Simulator. Shared views must keep compiling there.
- **Unshipped Assistant.** The Assistant tab and the "Help me do this" button are in working source but not in the submitted build. The redesign keeps them reachable and treats them as unshipped.

## Implementation and verification (8 November 2026)

You chose the bento tile browser, tabs named **Now · Explore · Passport** (Assistant kept), the passport-stamp metaphor, and two tiers: automatic stamps, with reviewed skills left unchanged. Favorites are a filter and shelf, not a tab. The visual system is in [DESIGN.md](../DESIGN.md).

### Live catalog finding

The app downloads the published catalog at launch. On 8 November it was revision `2026-10-05-owner-bulk-09-083436`, with **273 guides and 1,292 steps**. Most guides have 5 steps, a few 3 or 6. The bundled offline catalog is still 56 guides and 224 steps. Tag-derived sub-areas cover all 56 bundled guides and 229 of the 273 live guides. The other 44 still appear under their topic when no sub-area chip is selected.

### Checks run

- **Unit tests:** 112 tests on the iOS 26.5 Simulator, 1 skipped (the existing live-catalog test), 0 failures. The 14 new tests cover:
  - shipped-file migration, including that a 1.0-shaped decoder still reads the new file
  - done/known exclusivity, undo and fingerprinting
  - whole-guide known
  - favorite steps
  - sub-area coverage
  - filters
  - carousel paging and resume
  - prompt rendering (single pass, unknown placeholders, notes opt-in)
  - Google URL percent-encoding (`+ & # = % /`, non-ASCII)
  - stamps
  - presenter layout by display shape
- **UI flows, iPhone 17 Pro and iPad Pro 13-inch (iOS 26.5 Simulator, clean installs):** all pass on both devices.
  - The gallery flow covers Now, Explore, topic and sub-area, overview cards, step done/known/skip/heart, swipe back, resume from Now, finish stamp, Ask an AI, Passport, the favorites filter, search, marking a guide known, reminder, settings, and a cold relaunch that keeps the marks.
  - Dark mode with accessibility-3 text.
  - The existing Assistant flow.
- **Compile checks:**
  - macOS builds.
  - visionOS Swift type-checks against the visionOS 26.5 SDK. The full visionOS build fails in the asset catalog ("Failed to find device type … IBVisionIdiom"); unmodified `main` fails the same way on this Xcode 26.6 install. No visionOS Simulator was booted.
- **External display (iPhone Simulator, I/O ▸ External Displays):** an opt-in UI test (`TEST_RUNNER_ADULT_EXTERNAL_DISPLAY=1`) stepped through a guide, switched all three modes, and disconnected and reconnected the display mid-guide. Displays used: 1920×1080, 3840×2160, and a reconnect the scene reported as 720×480. The second screen followed every page change; the phone stayed usable; the process survived each disconnect. Logs recorded each connect and disconnect.
- **Right-to-left** (forced RTL launch arguments): tiles, chips, segments and step actions mirror; directional icons flip.
- **Mac:** an unsigned debug build in an isolated private-QA folder, driven by keystrokes. Your sandbox container was checked unchanged afterwards. Checked: overview layout, → to the next page, ⌘↩ to mark done and advance, and the Presenter window following live.

### Not verified

- **Real AirPlay or HDMI hardware.** Not checked: latency, overscan, TV safe areas, HDCP, and whether a given TV reports a size other than what the scene receives.
- **iPad with Stage Manager extended display.** iPadOS does not create the non-interactive scene there; the second screen then behaves like any other window.
- **External display already attached at launch.** The external scene appeared on two of three launches in Simulator. Attaching after launch always worked.
- **Mac UI tests.** XCUITest on macOS needs an interactive authorization ("Enable UI Automation") that an unattended run cannot give, so Mac flows were checked by driving the app with keystrokes instead.
- **Spoken VoiceOver order, Switch Control and Increase Contrast** were not checked on a device. Accessibility structure was checked through the XCUITest tree.
- **Haptics** only play on hardware.
