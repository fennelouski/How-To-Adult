# How to Adult marketing galleries

The independently reviewed current local set is [composed-contrast-final](composed-contrast-final/review-index.html): ten iPhone and ten iPad marketing JPEGs made only from genuine native captures. Mac remains pending because the native owner still needs macOS container-sharing consent before capture. No marketing assets have been uploaded.

## Current review packet

- [Review index](composed-contrast-final/review-index.html), with full-size outputs and original native source links.
- [iPhone contact sheet](composed-contrast-final/review/iphone-6.9-contact-sheet.png): ten 1320 × 2868 JPEGs.
- [iPad contact sheet](composed-contrast-final/review/ipad-13-contact-sheet.png): ten 2752 × 2064 landscape JPEGs.
- [Provenance](composed-contrast-final/marketing-provenance.json): original source hashes, native capture metadata, output hashes and layout transforms.
- [File verification](composed-contrast-final/file-verification.json): all 20 opaque sRGB JPEGs passed local file inspection; 258,070–745,524 bytes each.
- [Feature evidence](feature-evidence.json): exact capture hashes and observations supporting each headline.
- [Review status](composed-contrast-final/review-status.json): local checks and independent review state.

Independent reviewer `/root/adult_finish_reviewer` opened all 20 final JPEGs individually and both contact sheets, with no material finding. The scoped iPhone/iPad gallery passed; the full three-platform gallery remains pending Mac evidence.

Native revision: `ab95cedbe7401da1f11f52e5befeafbc0b04848d`. All 35 native input files match that commit and current bytes at verification. The canonical sorted files-map SHA-256 is `45c558b118e8813b7bad781f7e24538a395cff2ccffb8fd14b4f797f739f8c6e`. The original input proof is preserved as `composed-contrast-final/native-inputs-at-capture.json`; its file-byte SHA-256 is `559de9be82de4be8572574c2d999ae09e5e7b91d5cf6e23d022cca1fa9d2d578`.

The selected sources are 01–10 from `raw/iphone-contrast-final` and `raw/ipad-contrast-final`. All 20 original captures were visually inspected before composition. The phone reminder capture 09 shows the selected guide with Reminders active, so the actual reminder form 08 is the phone hero. iPad 09 shows the genuine saved reminder row and its populated detail. Accessibility/dark captures 11–13 are excluded from marketing.

The previous `composed-iphone-ipad/` set accurately records native revision `e719475e57f9d8cb7d54d9cce0034132402561b0`, but it is superseded after native secondary-text contrast review. **Do not upload that historical set.** Its review index and status explicitly mark it superseded. Its original source/output proof is preserved. `capture-manifest.iphone-ipad.json` and `capture-manifest.pending.json` describe that historical build.

## Create or extend galleries

`capture-manifest.contrast-final.json` is the explicit source/layout manifest for the current 20 outputs. `capture-manifest.contrast.pending.json` preserves those current source records plus ten Mac placeholders. The generic `capture-manifest.template.json` contains placeholders for all platforms. A template cannot pass validation until genuine source paths, hashes and native metadata are supplied.

Copy the chosen manifest and choose a new output directory before reproducing or revising a set. Existing images and provenance are protected from overwriting. Replace screenshot records, native input proof and revision together after any new native freeze; never rebind an older screenshot to a newer revision.

```sh
swift scripts/make-marketing-images.swift --validate PATH_TO_NEW_MANIFEST.json
swift scripts/make-marketing-images.swift PATH_TO_NEW_MANIFEST.json
```

Every included platform requires exactly ten images. A partial export must list every absent platform in `pendingPlatforms`, for example `["mac"]` with two complete iPhone/iPad galleries. Include only those platforms’ actual capture records. Provenance lists included and pending platforms, and the review index labels absent platforms pending. A complete three-platform export omits `pendingPlatforms` or supplies an empty array. Mac outputs will be 2560 × 1600 when genuine sources become available.

The compositor rejects changed source and proof hashes, cross-platform or cross-device layers, incomplete galleries, malformed timestamps and missing native provenance. It honors standard EXIF orientation at full native pixel dimensions without modifying original source bytes. The iPad originals encode portrait pixels with landscape orientation metadata.

Backgrounds alternate between marine guidebook spines, vermilion bookmarks, a white reference grid and navy wayfinding lines. Each composition has an upright centered hero and zero to two same-platform captures behind it. Supporting images turn counterclockwise on the left and clockwise on the right. Every headline must fit completely. A portrait hero may extend below the canvas. Native app imagery uses uniform scaling and standard orientation normalization, followed by completed-canvas JPEG encoding; no UI is redrawn or retouched.

Every JPEG is opaque sRGB and below 10,000,000 bytes. Accepted local galleries still require App Store Connect review after upload to establish Apple’s actual display and order.

## Compositor check

```sh
swift scripts/make-marketing-images.swift --self-test
```

The self-test uses temporary, explicitly marked solid fixtures. Production validation rejects them as native captures. It checks source preservation, orientation metadata, platform/device rejection, partial-platform declarations, complete gallery counts, upright hero placement, outward fan geometry, dimensions and sRGB encoding. Temporary fixtures are removed.
