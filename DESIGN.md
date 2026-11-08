---
name: How to Adult
description: Visual, step-at-a-time pocket guide with color-coded topics, visible progress and a passport of finished guides.
colors:
  action-light: "rgb(7.1% 23.5% 44.7%)"
  action-dark: "rgb(48.2% 69% 94.1%)"
  secondary-text-light: "#59595F"
  secondary-text-dark: "#AEAEB8"
  caution-text-light: "#9A4A00"
  white: "#FFFFFF"
  home-ground: "#0F6E74"
  home-tint-dark: "#5FD4D9"
  food-ground: "#A9481A"
  food-tint-dark: "#FFA36B"
  money-ground: "#2C6E37"
  money-tint-dark: "#7FD68B"
  work-ground: "#1F4E99"
  work-tint-dark: "#86AEF5"
  wellbeing-ground: "#A8325A"
  wellbeing-tint-dark: "#FF8FB4"
  people-ground: "#6B3FA0"
  people-tint-dark: "#C6A2F2"
  everyday-ground: "#3D47A3"
  everyday-tint-dark: "#9AA3F5"
  icon-ground-start: "#123C72"
  icon-ground-end: "#1D5393"
  icon-cover: "#BBD6EF"
  icon-bookmark: "#E55437"
rounded:
  tile: "24pt"
  card: "20pt"
  glance-card: "18pt"
  chip: "capsule"
  supporting-container: "12pt"
spacing:
  screen-inset: "20pt"
  reader-inset: "24pt"
  grid-gap: "12pt"
  tile-padding: "16pt"
  card-padding: "14pt"
  content-max-width: "1100pt"
  reader-max-width: "760pt"
motion:
  spring: "response 0.38, damping 0.82"
  auto-advance-delay: "350ms"
---

# How to Adult native design

Source of truth for the visual system. SwiftUI source wins if they ever disagree; update this file in the same change. Implementation lives in `Sources/AdultTheme.swift` (tokens, shapes, shared components), `AdultHomeViews.swift` (Now, Explore, topics, Passport), `AdultGuideViews.swift` (step carousel, overflow menu, Ask an AI) and `AdultPresenter.swift` (second screen).

## Principle: show, then tell

Color, icon, shape, progress and motion carry meaning first; words are the last resort. Text stays where it carries real meaning or safety: step instructions, cautions, jurisdiction labels, source links, the advice notice, errors and permissions. Every icon-only control keeps an accessibility label, and color never carries meaning alone (each color is paired with an icon, a shape or a label).

Audit of words replaced in the redesign:

| Before | Now |
| --- | --- |
| "Life comes with questions." slogan, tagline, featured card | Removed; Explore opens on the topic tiles |
| "All topics" menu, "All regions" menu | Topic tiles, sub-area chips, icon filter chips (♥, hide known, ⏱ ≤ 10 min, 🌐 region) |
| "About 10 min · 4 steps" | ⏱ 10 min fact and segmented step progress |
| "2 of 4 done" | Step segments: filled = done, half-tone = known, empty = open |
| "Before you start", "Good to know", "Go to the source" headings over long lists | Three glance cards: You need, Careful, Sources |
| "One step at a time" list | One page per step |
| "Make this yours" panel | Stars and notes on the finish page; everything else in the "…" menu |
| Saved and Reminders tabs | Favorites and Upcoming shelves on Now |

## Navigation

- **iPhone:** tabs **Now · Explore · Passport · Assistant**. Assistant is unshipped working source.
- **iPad (regular width) and Mac:** sidebar with the four sections plus the seven topics, and a detail stack. Assistant keeps its three-column plan layout.
- **Routes:** `AdultRoute.guide`, `.step(guide, step)` (opens a guide at a favorite step) and `.category`. Notification taps and `howtoadult://guide/<id>` open the guide on Now.
- **Favorites are a filter, not a tab.** The heart reuses the shipped `isSaved` flag for guides; steps can be hearted too. Favorites appear as a shelf on Now and as a ♥ chip in Explore and on each topic page.

## Color

Each topic has a deep **ground** (tile and badge background behind white text, at least 4.5:1 in both appearances) and an adaptive **tint** (icons, progress and headings on ordinary backgrounds: the ground in light mode, the lighter `-tint-dark` value in dark mode).

| Topic | Ground | Shape | Motif |
| --- | --- | --- | --- |
| Home | teal `#0F6E74` | rounded square (10pt) | rounded squares (windows) |
| Food | burnt orange `#A9481A` | circle | circles (plates) |
| Money | green `#2C6E37` | diamond | triangles (growth) |
| Work | blue `#1F4E99` | square (4pt) | horizontal bars (documents) |
| Wellbeing | rose `#A8325A` | capsule | waves |
| People | purple `#6B3FA0` | ellipse | rings |
| Everyday | indigo `#3D47A3` | rounded square (16pt) | dots |

Unknown future topics fall back to the catalog `colorKey` mapped to a system color, with dots and a 12pt rounded square.

- `AccentColor` (marine) marks app-wide actions and selected filter chips.
- `SecondaryText` is used for facts and supporting text.
- `AdultPalette.caution` is dark amber `#9A4A00` on light grounds and system orange on dark. It colors caution headings (orange text on white fails contrast).
- Hearts are system pink.
- The second screen always uses a black ground with the topic ground at 25% and its motif.

## Iconography

- SF Symbols only.
- Topics use the catalog's `symbol` and guides their own `symbol`.
- Sub-areas use the symbols defined in `GuideSubArea`.
- State symbols:

  | Meaning | Symbol |
  | --- | --- |
  | Done | `checkmark.circle(.fill)` |
  | Known | `lightbulb(.fill)` |
  | Favorite | `heart(.fill)` |
  | Finished guide | `checkmark.seal(.fill)` |
  | Passport | `seal` |
  | Topic complete | `rosette` |
  | Supplies | `shippingbox` |
  | Caution | `exclamationmark.triangle.fill` |
  | Sources | `link` |
  | Skip | `forward.fill` (mirrored in right-to-left layouts) |

- Decorative icons next to text are hidden from accessibility.

## Typography

All text uses Dynamic Type styles. There are no fixed point sizes except on the second screen.

| Role | Style |
| --- | --- |
| Guide title (overview) | `.largeTitle`, serif, bold |
| Step title | `.largeTitle`, rounded, bold |
| Step body | `.title3` |
| Topic title on its page | `.largeTitle`, rounded, bold |
| Tile and shelf titles | `.title2.bold()` |
| Card titles | `.headline` |
| Facts, chips | `.caption` / `.subheadline`, semibold |

On the second screen, sizes are `base × PresenterLayout.scale`. The scale grows with the display's short side, clamped to 1–3×. The base is 2.2 for Current step, 1.6 for Step and context, and 1.35 for Whole guide.

## Layout

- **Content width:** browse content caps at 1100pt and the reader at 760pt, both centered. Screen inset is 20pt and the grid gap 12pt.
- **Topic grid (bento):** 2 columns on iPhone and 3 on iPad and Mac. An uneven last row stretches its tile across the row. At accessibility sizes the grid becomes one column.
- **Guide cards:** adaptive grid, 300pt minimum (600pt at accessibility sizes). Each card shows the badge in the topic shape, title, ⏱, US flag fact, heart, and step segments.
- **Guide carousel:**
  - Tappable page indicator: overview ⓘ, one segment per step, finish 🏁.
  - One page per step.
  - A bottom action bar on the bar material.
  - Short pages center vertically; tall pages (large text) scroll inside the page.
  - At accessibility sizes the action bar collapses to one row of icon-only buttons, so the step keeps the screen.
- **Overview:** badge, facts, serif title, summary, advice notice, then up to three glance cards side by side, or stacked when narrow.
- **Mac:** one page with a push transition. The floating macOS 26 sidebar misaligns a paging scroll view, and Mac navigation is keyboard-, segment- and menu-driven.

## Motion and haptics

- One spring for interface changes: response 0.38, damping 0.82 (`Animation.adult`).
- Under Reduce Motion it becomes no animation, the Mac page push becomes a fade, and the topic-complete seal is not rotated.
- Marking a step done or known plays a success haptic, waits 350ms so the mark registers, then advances. Page changes play a selection haptic. The finish stamp bounces once.
- No looping or decorative motion.

## Depth and shape

- Tiles have a 24pt continuous radius, cards 20pt, glance cards 18pt and chips are capsules. Each control has exactly one visible container.
- Depth comes from color grounds and system materials (action bar, sidebars). The app adds no custom shadows.
- iPad tiles lift on pointer hover.

## Progress model

- A step is **done** (did it now), **known** (already knew it) or **open**. Done and known are exclusive, and both are fingerprinted, so an edited step must be marked again.
- Done and known both count toward progress.
- A guide is **finished** when every step is done or known, and **known** when every step is known.
- Marking a whole guide known marks each step that isn't already done.
- Skip only moves on; it isn't saved.
- Every mark can be undone: tap the same action again, or use the "…" menu.
- Known guides appear dimmed with an outlined seal and can be hidden with the "Hide known" chip.

Stored as optional fields on `ArticleProgress` (`knownSteps`, `favoriteSteps`, `lastActivity`). `schemaVersion` stays 1, so the submitted 1.0 build still reads the file.

## Passport

Two tiers on one screen:

1. **Stamps (automatic).**
   - Each topic has a passport page with one stamp slot per guide.
   - A finished guide gets a filled stamp in the topic shape; a known guide gets an outlined stamp with a check; an open guide is a dashed outline.
   - A completed topic gets a rotated seal ("visa").
   - Stamps record finishing a guide, never competence.
2. **Skills (reviewed).**
   - The existing `AdultPassportStore` records explicit self-reports against an admitted, reviewed manifest.
   - Its rules are unchanged: reading or marking steps never awards a skill.
   - Production admission is still empty, so this tier shows only skills already earned on the device.

## Overflow menu

- **Marks:** favorite guide or step, mark step or guide known.
- **Look further:**
  - **Ask an AI** builds a prompt from an editable template: Settings ▸ Ask an AI ▸ Prompt template, with placeholders `{guide} {summary} {step} {stepDetail} {progress} {region} {supplies} {cautions} {notes}`. Rendering is single pass, so placeholder-looking text inside a guide stays literal.
    - The prompt is copied to the clipboard and a sheet offers "Open [assistant] and paste".
    - The assistant's plain home page opens with nothing pre-filled or sent.
    - Personal notes are included only if the setting is on.
  - **Search Google** opens `https://www.google.com/search?q=…`, with the query percent-encoded so only unreserved characters stay literal.
- **Share, remind, notes, assistant.**
- **Second-screen mode**, shown only while an external display is connected.

## Second screen

- An external display gets its own non-interactive scene (`UIWindowSceneSessionRoleExternalDisplayNonInteractive`, declared in `Configuration/iOS-Info.plist`), never a mirror.
- Three modes:
  - **Current step:** big and readable across a room.
  - **Step and context:** the step plus supplies, cautions, the next step and progress; two columns on landscape screens.
  - **Whole guide:** every step in up to four columns sized to the display. The current step is outlined, and the screen scrolls itself to it when everything doesn't fit.
- Layout is computed from the real display size, so any aspect ratio, orientation or resize works.
- **Mac:** a resizable Presenter window (⇧⌘P) with a mode switcher, which can be dragged to another display.

## Keyboard

- ← and → move between pages, mirrored in right-to-left layouts. Space moves forward.
- Guide menu commands:

  | Command | Shortcut |
  | --- | --- |
  | Next step | ⌘→ |
  | Previous step | ⌘← |
  | Done | ⌘↩ |
  | I know this step | ⇧⌘K |
  | Favorite guide | ⌘D |
  | Show presenter window (Mac) | ⇧⌘P |

- Commands post through `PresenterState`. Don't pass closures through `focusedSceneValue`: that caused an update loop during accessibility snapshots.

## Accessibility checklist

- **Dynamic Type:** layouts reflow to one column, and the step stays primary at accessibility sizes. The carousel scrolls inside a page only as a last resort.
- **VoiceOver:**
  - Tiles, cards and stamps are single elements with a label and value.
  - Page segments are buttons ("Step 2", "Done, current").
  - Three-finger swipes page through the carousel.
  - Cautions are read as "Caution: …".
- **Reduce Motion, Dark Mode and right-to-left** layouts are supported.
- **Increase Contrast:** relies on system materials and the high-contrast grounds above.
- **Container identifiers:** scope them with `.accessibilityElement(children: .contain)` before setting the identifier. On a bare stack, an identifier overwrites every child's identifier.

## Do's and Don'ts

- Do let text wrap, and never truncate app-written labels. The navigation bar inside a guide shows the short topic name for this reason.
- Do keep cautions next to the task on every step page and keep jurisdiction labels and source links visible.
- Do derive new sub-areas from tags in `GuideSubArea`. The catalog schema has no sub-area field, and changing that is a backend change.
- Don't add a second "favorite" flag for guides; `isSaved` is the heart.
- Don't let automatic stamps award reviewed skills.
- Don't mirror the device UI onto a second screen.

## History

The 2026-10 "public-library reference desk" direction, its evidence and contrast records are preserved in git history (`3f59cb1` and earlier) and in `app-store-audit/`. The submitted iOS 1.0 build uses that earlier design. The redesign audit is in `Documentation/redesign-audit.md`. `.impeccable/` sidecar notes describe the earlier direction.
