---
name: How to Adult
description: Native pocket reference with readable guides and visible progress.
colors:
  action-light: "rgb(7.1% 23.5% 44.7%)"
  action-dark: "rgb(48.2% 69% 94.1%)"
  featured-guide: "rgb(7% 23% 45%)"
  secondary-text-light: "#59595F"
  secondary-text-dark: "#AEAEB8"
  white: "#FFFFFF"
  icon-ground-start: "#123C72"
  icon-ground-end: "#1D5393"
  icon-cover: "#BBD6EF"
  icon-bookmark: "#E55437"
rounded:
  featured-guide: "16pt"
  supporting-container: "12pt"
spacing:
  collection-inset: "20pt"
  reader-inset: "24pt"
  featured-inset: "22pt"
  collection-section: "28pt"
  reader-section: "30pt"
  supporting-gap: "12pt"
  instruction-inset-vertical: "20pt"
components:
  featured-guide:
    backgroundColor: "{colors.featured-guide}"
    textColor: "{colors.white}"
    rounded: "{rounded.featured-guide}"
    padding: "{spacing.featured-inset}"
  caution-container:
    rounded: "{rounded.supporting-container}"
    padding: "{spacing.collection-inset}"
  selected-guide:
    rounded: "{rounded.supporting-container}"
  guide-reader:
    padding: "{spacing.reader-inset}"
---

# How to Adult native design

## Overview

The working direction is a public-library reference desk. Topic symbols help someone scan the index, a guide title leads the reading page, and bookmarks and checked steps retain a place. This is the implementation's provisional design language, not a user-confirmed brand metaphor. The user requested a native pocket guide with minimal interface wording, clear color and hierarchy, and no clipped text.

The design uses native navigation around a quiet reading page. Marine blue marks actions; bold system serif titles separate a guide from its controls. Body text, menus, sheets and forms use system typography. Tools, discrete instructions, cautions, location labels and original-source links give each guide its structure.

The previous written decisions are merged here with the implemented values. Frontmatter records actual source values, using native points for dimensions. SwiftUI source and asset catalogs remain the native implementation authority. Semantic system colors and scalable text styles appear in prose and the sidecar because CSS token fields cannot represent their platform behavior faithfully.

### Direction record

The seven grounded candidates were a field manual, care-label decoding, community noticeboard, transport wayfinding, public-library reference index, cooking preparation and service worksheet. The reference index was candidate five, with direction seed `bdd43137`. Challenger ideas contributed visible resumable states, discrete steps, clear section separation, immediate choices with time estimates and one clear subject. The implemented app applies these lessons through its reading structure. No literal machinery, film rails, cloud scene, airport signage or landscape poster is part of the interface.

The answer-first opening and US-first location-specific content remain provisional assumptions from the 2026-10-03 optional questions. The user's preference for direct native implementation applies to this work; it is not a newly confirmed global workflow setting. The first-viewport contract and Read mode belong in [.impeccable/surfaces/app.md](.impeccable/surfaces/app.md).

### Evidence for this version

The native source freeze is `ab95cedbe7401da1f11f52e5befeafbc0b04848d`. Its 35 inputs have canonical SHA-256 `45c558b118e8813b7bad781f7e24538a395cff2ccffb8fd14b4f797f739f8c6e`, recorded in [native-inputs-contrast-final.json](app-store-audit/2026-10-03-how-to-adult/native-inputs-contrast-final.json). Both iPhone and iPad runs passed 10 model tests and two UI tests. Each produced 13 genuine native captures, including dark appearance with accessibility text size. Current manifests are [iPhone](app-store-audit/2026-10-03-how-to-adult/raw/iphone-contrast-final/manifest.json) and [iPad](app-store-audit/2026-10-03-how-to-adult/raw/ipad-contrast-final/manifest.json). Result bundles are `/tmp/howtoadult-phone-contrast-final-20261003.xcresult` and `/tmp/howtoadult-pad-contrast-final-20261003.xcresult`.

[Signed package inspection](app-store-audit/2026-10-03-how-to-adult/final-package-inspection-contrast-final.json) confirms the same freeze in the iOS and Mac exports. Original-bundle Mac runtime checks, resized-window captures and the Mac gallery remain pending the existing-container sharing consent. The [fresh 20-image iPhone/iPad gallery](app-store-audit/2026-10-03-how-to-adult/marketing/composed-contrast-final/review-status.json) passed independent review with no material finding. Mac marketing remains pending, and no assets were uploaded. The [independent finish review](app-store-audit/2026-10-03-how-to-adult/design-finish-review.md) approved all 26 final phone/tablet captures, with no remaining material clipping finding. Its overall disposition is `recapture` because original-bundle Mac runtime verification, 13 Mac captures and ten Mac marketing images are missing. This is an evidence gap; the review does not infer a Mac product defect or runtime pass. Earlier `raw/iphone-final`, `raw/ipad-final` and Mac captures are historical evidence, not evidence for this freeze. No release or submission claim follows from this document.

## Colors

### Primary

`action-light` and `action-dark` are the two appearances of the `AccentColor` asset. They drive native tint, completion symbols, progress labels and source links. `featured-guide` is a separate, fixed marine ground with white text. Its literal SwiftUI RGB differs slightly from the action tint; preserve that distinction.

The icon has a marine gradient, a pale-blue book cover, white pages and a coral checked bookmark. The `icon-*` tokens describe the existing original vector artwork. Coral remains an icon detail.

### Secondary

Topic symbols use SwiftUI's adaptive `.teal`, `.orange`, `.green`, `.pink`, `.purple` and `.indigo` colors. The default topic color is the action tint. Colors support topic recognition alongside titles and SF Symbols. Do not replace them with invented fixed hex values or make topic meaning depend on hue alone.

### Neutral

Reading text uses `.primary`. Authored summaries, time estimates, review dates and explanatory settings text use the adaptive `SecondaryText` asset. The bounded contrast fix replaced its former light value after independent review measured 3.44:1 on white. Current authored light text measures 6.96:1 on white; the dark appearance measures 9.55:1 on black.

The native search field's OS-managed placeholder measured about 3.23:1 in the reviewed capture. Applying a foreground color to its prompt did not establish an effective override. Keep this limitation visible in review records. The authored-text result does not establish that every system-rendered label passes the same check.

iOS uses `systemBackground` for the reading page and `secondarySystemBackground` for supporting containers. Mac uses `windowBackgroundColor` and `controlBackgroundColor`. Dividers and navigation materials are system-owned. Selection uses the action tint at 9% opacity inside one supporting container.

## Typography

Typography uses SwiftUI text styles. Frontmatter omits fixed font sizes, line heights and tracking because the source does not define those tokens. The system chooses metrics for the platform and Dynamic Type setting.

| Role | Native style | Use |
| --- | --- | --- |
| Guide and introductory title | `.system(.largeTitle, design: .serif, weight: .bold)` | Main guide title and library introduction |
| Section title | `.title2.bold()` | Tools, steps, cautions and sources |
| Guide and step title | `.headline` | Index and instruction rows |
| Instruction prose | `.body` | Tools, steps, cautions and source links |
| Reader summary | `.title3` | Summary below a guide title |
| Index summary and supporting text | `.subheadline` | Row descriptions, time estimates and settings notes |
| Metadata | `.caption` | Review dates, row timing, jurisdiction and progress |

The serif is the system's serif design, commonly New York on Apple platforms. Preserve the native style rather than hard-coding that family. Controls and body prose use the default system design.

Multiline titles, summaries, tools, cautions and instructions allow vertical growth. Guide rows and instruction text stacks use `.fixedSize(horizontal: false, vertical: true)`. No authored `lineLimit` truncates these reading elements. Accessibility sizes also widen the library sidebar. Preserve wrapping when adding content; font scaling alone does not prove every future string fits.

## Layout

Compact iOS layouts use Guides, Saved and Reminders tabs, each with its own navigation stack. Regular-width iPad layouts and Mac use `NavigationSplitView` with a library sidebar, guide collection and reader. iPad chooses this structure using `horizontalSizeClass`. Mac always uses the split view. Selection survives the switch back to compact navigation.

Collection and reader content cap at 760 native points and center in the available space. Collection content uses 20-point horizontal and 22-point vertical insets; the reader uses 24-point insets. Collections separate major sections by 28 points; readers use 30 points. Text remains leading-aligned.

The sidebar requests a 180-point minimum width and 220-point ideal width. Accessibility text raises these to 300 and 340 points. The collection column requests a 300-point minimum, 410-point ideal and 520-point maximum. The platform resolves the actual split-view layout.

Topic and region menus use `ViewThatFits` to change from a horizontal row to a vertical stack. Guide rows have an icon column, wrapping text and trailing chevron, with 18-point vertical padding. Instruction rows have a completion column and wrapping title/body stack, with 20-point vertical padding. The entire instruction row is the target.

Reminder and settings sheets use native forms. Reminder requests a 320-point minimum width, 480-point ideal width and 360-point minimum height. Settings requests a 320-point minimum width, 500-point ideal width and 420-point minimum height. Confirm Mac resizing when runtime access is available; these source requests are not captured-window evidence.

## Elevation & Depth

The app defines no custom shadows. Native bars, split-view columns, sheets and menus supply platform depth. The featured guide uses a solid ground; cautions and storage notices use semantic supporting backgrounds. Dividers separate index and instruction rows. The icon gradient belongs to the artwork and is not an interface tonal ramp.

Navigation and sheets use native transitions. The source adds no decorative entrance animation, easing curve or timed motion token. Preserve platform motion behavior, including Reduce Motion, when extending this interface.

## Shapes

The featured guide uses a 16-point rounded rectangle. Caution, storage-attention and selected-guide containers use 12-point rounded rectangles. Keep one visible container for selection.

Completion uses an outlined or filled check circle. Bookmark and reminder states use native SF Symbol variants. Text and symbols together communicate state. The icon is an open pocket guide with a checked bookmark; iOS uses full-bleed artwork and Mac uses the existing rounded, inset silhouette from the icon generator.

## Components

### Navigation, search and filters

`AdultRootView` owns the tabs, split view, navigation stacks and sheets. Each compact tab retains a separate path. Wide layouts keep the selected guide in a dedicated reader. Preserve platform navigation, keyboard behavior and focus.

`GuideCollectionView` attaches `.searchable` to the native navigation container and filters the local index. Topic and location filters are `Menu` controls containing `Picker` selections. Preserve their native selected, keyboard and accessibility behavior. The source defines no custom search border, hover animation or focus ring.

### Featured guide and guide rows

The featured guide is one plain-styled `NavigationLink` on compact layouts or `Button` on wide layouts. White title, summary and an "Open guide" label sit on its marine ground with a topic symbol. It points to the first-load laundry guide in the current catalog. Its 22-point padding and wrapping text give the index a clear first action.

`GuideRow` shows a topic symbol, headline, summary, time and step count. Location-specific guides show jurisdiction. Reminder rows show scheduled time; progress adds a check symbol and count. The selected wide-layout row uses one tinted rounded container. Rows combine accessibility content and keep full text visible.

### Reader and checkable instruction

`GuideReaderView` presents title and summary, jurisdiction where needed, tools, steps, cautions and original-source links. A reviewed date follows the sources. Save, remind and share remain toolbar actions; bookmark shape changes when saved.

`GuideStepRow` is a plain native button spanning the row. It changes the completion circle and accessible value without dimming or striking through the instructions. Local completion survives reopening. An edited instruction changes its fingerprint and requires a fresh check. The sidecar contains native source excerpts, not browser substitutes or screenshots.

### Supporting containers and empty states

Cautions use a titled semantic-background container. Storage issues show a message and retry action. Save failures preserve the prior state and show a native alert. Search, Saved, Reminders and unselected-reader empty states use `ContentUnavailableView`, with instructions pointing to the relevant action.

### Reminder and settings forms

The reminder form has a native date/time picker, sound toggle, shortcuts and explicit Save/Cancel. It restores an existing future reminder and sound choice when opened. Save shows "Saving…" while scheduling; failure retains the form and visible error. Notification permission is requested while saving a reminder.

Settings shows library counts, offline availability, location guidance and support destinations. The new-guide action appears only when a catalog endpoint is configured. The frozen package has no endpoint, so dynamic publication is not a live capability claim.

## Do's and Don'ts

- Do use native text styles and allow titles, summaries and instructions to wrap.
- Do keep the reader leading-aligned inside its centered, bounded column.
- Do pair topic colors and completion state with symbols and readable labels.
- Do retain one visible selection container and the native navigation structures.
- Do put location-specific labels near the affected guide and retain its source links.
- Do keep Save and Cancel explicit for reminder drafts, with visible failure and disabled states.
- Don't invent fixed values for semantic platform colors, typography metrics or native control focus treatments.
- Don't hide checked instructions, shorten important content with ellipses or add decorative motion around reading.
- Don't claim the system search-placeholder styling override works or treat authored-text contrast as a whole-app accessibility verdict.
- Don't use browser mockups, another platform's UI or historical captures as native evidence for the frozen build.
- Don't claim Mac runtime verification, a live catalog, completed galleries or an App Store submission while those records remain pending.
