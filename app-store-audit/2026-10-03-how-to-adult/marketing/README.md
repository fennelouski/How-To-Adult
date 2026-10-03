# How to Adult marketing galleries

The current local set for uploaded native revision `ca8edc4e786d25504b06fa177468f42adde376fd` is [composed-live-privacy-final](composed-live-privacy-final/review-index.html): ten iPhone and ten iPad JPEGs made from fresh genuine native captures. Local technical checks and one author visual batch passed. Root independently approved both contact sheets and full-size phone 01/iPad 05, including the current feature claims. **Root uploaded all 20 images and verified the displayed order after reloading both Apple galleries.** See [live ASC proof](../asc-publication-progress.json). Mac remains pending owner container-sharing consent; this packet contains no Mac gallery. This marketing agent has uploaded no gallery assets.

## Current review packet

- [Apple asset handoff](composed-live-privacy-final/apple-asset-handoff.md): exact ordering, filenames, dimensions, file hashes and decoded pixel hashes.
- [Review index](composed-live-privacy-final/review-index.html): full-size outputs and original native source links.
- [iPhone contact sheet](composed-live-privacy-final/review/iphone-6.9-contact-sheet.png): ten 1320 × 2868 portrait JPEGs.
- [iPad contact sheet](composed-live-privacy-final/review/ipad-13-contact-sheet.png): ten 2752 × 2064 landscape JPEGs.
- [Native contact sheets](native-review-live-privacy-final/native-capture-inventory.json): 26 untouched current captures with original byte hashes and orientation.
- [Provenance](composed-live-privacy-final/marketing-provenance.json): original screenshot metadata and hashes, output hashes and transforms.
- [File verification](composed-live-privacy-final/file-verification.json): 20 opaque RGB/sRGB JPEGs, 250,177–748,200 bytes; full file and decoded RGB pixel hashes, geometry and 35 native inputs checked against the frozen commit and current bytes.
- [Feature evidence](feature-evidence-live-privacy-final.json): fresh exact screenshot hashes and bounded observations supporting each headline.
- [Author visual findings](composed-live-privacy-final/visual-review-live-privacy-final.md) and [review status](composed-live-privacy-final/review-status.json).

Source build reference: `ca8edc4-Release-1.0-build1-SDK26.5`. The exact 35 native input map has canonical SHA-256 `cd9e1ee587f615268ee1157e9fb9693d3078762059a06dae11bcf48e06abb9df`. The original input and executable/build/xctestrun/device-run proofs are preserved in the current output packet as `native-inputs-at-capture.json` and `native-builds-at-capture.json`. Parent QA recorded 11 model and two UI tests passing on each device, including the real configured catalog, retained progress and cold cache. The native screenshot host used testability for XCTest; the signed distribution packages use production testability disabled.

Selected sources 01–10 come only from `raw/iphone-live-final` and `raw/ipad-live-final`, retaining each original attachment manifest, timestamp and hash. Phone capture 09 shows the selected guide with Reminders active, so the actual reminder form 08 is the phone hero. iPad 09 shows a saved reminder row. Captures 11–13 contain “dark-large” in their test names but visually show light appearance and ordinary text size; they remain untouched and are excluded. Their names and passing test count are not a visual verification of those traits.

Current Settings visibly includes **Check for new guides**. Image 09 says **Starter guides work offline** to describe the bundled fallback without promising future content while disconnected. The feature evidence distinguishes visible controls from verified notification delivery or other unsupported claims.

## Preserved historical galleries

[composed-contrast-final](composed-contrast-final/review-index.html) records native revision `ab95cedbe7401da1f11f52e5befeafbc0b04848d`; its independent acceptance, exact sources, [feature evidence](feature-evidence.json) and output proof remain unchanged. That set predates the configured live catalog and final hosting privacy manifest. It is historical and is not the current upload set.

`composed-iphone-ipad` records revision `e719475e57f9d8cb7d54d9cce0034132402561b0` and predates the native contrast fix. Its existing superseded status and source/output proofs are preserved. Never relabel an older screenshot or gallery to a newer native freeze.

## Create or extend galleries

`capture-manifest.live-privacy-final.json` is the source/layout manifest for the current 20 outputs. Previous contrast manifests and generic templates are historical references or placeholders, not evidence for this freeze. Copy the chosen manifest and choose a new output directory before any revision. Existing images and provenance are protected from overwriting. Replace the capture records, native/build proof and revision together after a fresh capture.

```sh
swift scripts/make-marketing-images.swift --validate PATH_TO_NEW_MANIFEST.json
swift scripts/make-marketing-images.swift PATH_TO_NEW_MANIFEST.json
```

Every included platform requires exactly ten images. A partial export must list absent platforms in `pendingPlatforms`; the current value is `["mac"]`. A full three-platform export requires genuine Mac evidence and ten 2560 × 1600 Mac outputs, then removes that pending entry.

The compositor rejects changed screenshot or proof hashes, cross-platform/cross-device layers, incomplete galleries, malformed timestamps and missing native provenance. It honors standard EXIF orientation at native pixel dimensions without changing original bytes. iPad PNGs encode 2064 × 2752 with landscape orientation metadata; the native compositing size is 2752 × 2064.

Backgrounds alternate between marine guidebook spines, vermilion bookmarks, a white reference grid and navy wayfinding lines. Each image has an upright centered foreground hero and zero to two same-platform captures behind it. Supporting images turn counterclockwise on the left and clockwise on the right. Centered headlines fit completely. Portrait heroes may extend below the canvas. Native imagery uses uniform scaling and standard orientation normalization; no UI is redrawn or retouched.

Every JPEG is opaque sRGB and under 10,000,000 bytes. File inspection reads both EXIF sRGB metadata and the native macOS decoded profile; the record does not invent an explicit embedded ICC block. Exact hashes and pixel hashes are in file-verification.json. Root inspected the current iPhone/iPad galleries in App Store Connect and confirmed the intended ten-image order after reload; the Mac gallery remains pending.

## Compositor check

```sh
swift scripts/make-marketing-images.swift --self-test
```

The existing self-test uses temporary, explicitly marked solid fixtures that production validation rejects. It checks source preservation, EXIF orientation, platform/device rejection, pending declarations, gallery counts, hero placement, fan geometry, dimensions and sRGB encoding. The unchanged compositor was not broadly retested for this capture-only update; current manifest validation, composition and independent file/source checks passed.
