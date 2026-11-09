---
name: How to Adult — Fieldnotes
description: A practical editorial guide on warm paper with pine ink and authored teaching art, browsed by color-accented topics and read one step at a time.
colors:
  paper: "#F5F0E6"
  paper-raised: "#EAE4D6"
  pine: "#173E38"
  muted: "#5C6259"
  clay: "#9B412F"
  on-clay: "#FFF9EF"
  rule: "#D1C9B7"
  caution: "#EAE1BE"
  dark-paper: "#172A26"
  dark-raised: "#223C35"
  dark-ink: "#F4EFE5"
  dark-muted: "#BDCCBF"
  dark-action: "#E8BC80"
  dark-rule: "#476057"
  dark-caution: "#3C402C"
  topic-home: "#0F6E74"
  topic-home-dark: "#5FD4D9"
  topic-food: "#A9481A"
  topic-food-dark: "#FFA36B"
  topic-money: "#2C6E37"
  topic-money-dark: "#7FD68B"
  topic-work: "#1F4E99"
  topic-work-dark: "#86AEF5"
  topic-wellbeing: "#A8325A"
  topic-wellbeing-dark: "#FF8FB4"
  topic-people: "#6B3FA0"
  topic-people-dark: "#C6A2F2"
  topic-everyday: "#3D47A3"
  topic-everyday-dark: "#9AA3F5"
typography:
  display:
    fontFamily: "Georgia, serif"
    fontSize: "36px"
    fontWeight: 400
    lineHeight: 1.06
    letterSpacing: "-1.1px"
  heading:
    fontFamily: "Georgia, serif"
    fontSize: "25px"
    fontWeight: 400
    lineHeight: 1.15
  body:
    fontFamily: "system-ui, sans-serif"
    fontSize: "17px"
    lineHeight: 1.5
  metadata:
    fontFamily: "system-ui, sans-serif"
    fontSize: "12px"
    lineHeight: 1.5
rounded:
  control: "8px"
  search: "10px"
  card: "14px"
  tile: "16px"
  image: "3px"
spacing:
  unit: "4px"
  inline: "8px"
  component: "12px"
  row: "18px"
  inset: "20-24px"
  section: "28px"
  spread: "40px"
components:
  primary:
    backgroundColor: "{colors.clay} or the topic color"
    textColor: "{colors.on-clay}"
    rounded: "{rounded.control}"
    height: "48px"
  caution:
    backgroundColor: "{colors.caution}"
    textColor: "{colors.pine}"
    padding: "16px"
    rounded: "{rounded.control}"
---

# How to Adult: Fieldnotes with topics, steps and a passport

This file is the source of truth for the visual system. SwiftUI wins if they disagree; update this file in the same change.

The code is organised as follows:

| File | Contents |
| --- | --- |
| `Sources/AdultDesign.swift` | Fieldnotes tokens and components |
| `Sources/AdultTheme.swift` | Topic styles, shapes, cards and chips |
| `Sources/AdultHomeViews.swift` | Now, Explore, topic pages and Passport |
| `Sources/AdultGuideViews.swift` | Step carousel, "…" menu and Ask an AI |
| `Sources/AdultPresenter.swift` | Second screen |
| `Sources/AdultViews.swift` | Root, illustration pipeline, reminders, notes and settings |

## Overview

The visual world is a carefully typeset practical field guide: warm paper, dark pine type, clay actions, quiet rules, serif headings and the authored cream teaching plates.

The November 2026 redesign keeps that world and changes how people move through it:

- **Browse by topic, visually.** Seven topic tiles carry an accent color, an icon and a shape language on paper. Tag-derived sub-area chips and icon filter chips narrow a topic.
- **Read one step at a time.** A guide opens as a paged carousel: overview, one page per step, then finish. Glanceable cards show supplies, cautions and sources.
- **See what you're doing and what you've done.** **Now** shows guides in progress, upcoming reminders and favorites. **Passport** stamps finished guides.
- **Show, then tell.** Color, icons, shape, progress and art carry meaning first. Text stays where it carries meaning or safety: instructions, cautions, jurisdiction labels, sources, the advice notice, errors and permissions. Every icon has an accessibility label, and no meaning relies on color alone.

### Owner decisions that supersede earlier Fieldnotes rules (8–9 November 2026)

The owner asked for this redesign and chose the bento topic browser, the tabs Now · Explore · Passport (plus Assistant), passport stamps, and porting onto Fieldnotes with its palette as the base and topic colors as accents. These earlier Fieldnotes rules are therefore replaced:

| Earlier Fieldnotes rule | Now |
| --- | --- |
| "No badges, gamification … equal-size card wall"; "avoid seven competing pastel containers" | Seven topic tiles on paper: each has a light tint wash, a motif in its accent at 12% and one solid topic badge. Pine and clay still govern hierarchy; headings stay serif ink. Stamps record finished guides and never claim competence. |
| "Progress is a count plus segmented line, never a reward ring" | Step progress is still a segmented line. Rings appear only for topic completion (tiles) and passport totals. |
| "Keep completed text full contrast; no dimming" | Done steps stay full contrast. *Known* steps and guides render at 75% opacity, which measures at least 4.83:1 on every paper ground. |
| IA: Guides / Saved / Reminders / Assistant, with a featured guide and topic index | Now / Explore / Passport / Assistant. Saved becomes the ♥ favorites shelf and filter, and Reminders becomes the Upcoming shelf on Now. Teaching art appears on cards and inside the carousel instead of one featured spread. |
| Passport is DEBUG-only and absent from root navigation | The **review flow** stays DEBUG-only and its admission rules are unchanged. The root Passport tab shows automatic stamps, plus reviewed skills only when already earned on the device; production admission is still empty. |

Everything else in Fieldnotes still applies: the colors, typography roles, illustration handling, notes and ratings behavior, reminder and permission timing, storage and offline states, Settings, Assistant, and the accessibility order and target sizes.

## Colors

Fieldnotes semantic tokens drive the interface in both appearances: paper, raised paper, pine or dark ink, muted text, clay or dark action, rule, and caution.

**Topic accents.** Each topic has a deep **ground** (badge fill behind white symbols, at least 4.5:1) and an adaptive **tint** (accent strokes, progress and washes: the ground in light mode, the `-dark` value in dark mode).

| Topic | Ground | Shape | Motif |
| --- | --- | --- | --- |
| Home | teal `#0F6E74` | rounded square | rounded squares |
| Food | burnt orange `#A9481A` | circle | circles |
| Money | green `#2C6E37` | diamond | triangles |
| Work | blue `#1F4E99` | square (4pt) | horizontal bars |
| Wellbeing | rose `#A8325A` | capsule | waves |
| People | purple `#6B3FA0` | ellipse | rings |
| Everyday | indigo `#3D47A3` | rounded square (16pt) | dots |

Unknown future topics use clay and dots.

- **Tiles and cards:** raised paper, the topic tint at 8–10% as a wash, the motif at 8–12%, and a 1pt border (rule color, or the topic tint at 35%).
- **Selected chips:** clay with on-clay text. Unselected chips are raised paper with a rule border.
- **Prominent step actions** use the topic ground with white labels. Fieldnotes sets ink app-wide, so prominent buttons set their own label color.
- **Cautions** always use caution paper with pine text and an ink warning symbol.
- **Illustrations** keep their original colors in both appearances.
- **Second screen:** a black ground with the topic tint at 25% and its motif.

## Typography

Fieldnotes roles:

| Role | Style |
| --- | --- |
| Display (screen titles: Now, Explore, Passport, topic) | Serif 36 (`FieldnotesHeading`), Dynamic Type scaled |
| Section | Serif 25 |
| Guide title on the overview | Serif 34 |
| Step title | Serif 32 |
| Step body | `fieldnotesBody(size: 20)` |
| Card titles | Body semibold |
| Facts and chips | Caption or subheadline, semibold |

On the second screen, sizes are `base × PresenterLayout.scale`. The scale grows with the display's short side, clamped to 1–3×. The base is 2.2 for Current step, 1.6 for Step and context, and 1.35 for Whole guide.

## Layout

The Fieldnotes width thresholds are kept:
- Compact tabs below 680pt and at accessibility sizes.
- A sidebar plus detail from 680pt, on iPad regular width and on Mac.
- Assistant keeps its three columns (sidebar, plan index, workspace).
- The whole composition is capped at 1800pt.

The sidebar lists the four sections and the seven topics.

Screen and component sizes:
- **Content width:** browse content caps at 1100pt and the reader at 760pt.
- **Topic grid:** 2 columns on iPhone, 3 on iPad and Mac, 1 at accessibility sizes. An uneven last row stretches its tile.
- **Guide cards:** adaptive grid, 300pt minimum (600pt at accessibility sizes).
- **Card badge:** the guide's hero teaching art clipped into its topic shape, or the topic symbol while art loads or is unavailable.
- **Card contents:** title, ⏱ time, US flag fact, ♥, and step segments.
- **Guide carousel:**
  - Tappable page indicator: overview ⓘ, one segment per step, finish 🏁.
  - One page per step, with an action bar on paper above a rule.
  - Short pages center vertically; tall pages (large text) scroll inside the page.
  - At accessibility sizes the action bar becomes one row of icon-only buttons.
  - On Mac, one page with a push transition: the floating sidebar misaligns a paging scroll view.
- **Overview:** badge, facts, serif title, summary, advice notice, then the hero illustration (image description, full-size zoom, credits). After that, up to three glance cards (You need · Careful · Sources), side by side or stacked.
- **Step pages:** show their step illustration when one exists (8 steps currently have one), and the guide's caution on every step.

## Illustrations

Unchanged from Fieldnotes:
- Artwork is bound to the exact catalog revision.
- Every surface uses `VerifiedGuideImage` (PNG and digest checks, bounded size).
- Full-size zoom closes with Done or Escape.
- Image descriptions use the existing alt text.
- Unavailable art shows "Illustration unavailable" with its description and Retry.

Compact badges pass a placeholder, so they show the topic symbol instead of loading or retry states. The thumbnail is recognition only: no instruction depends on it, and the reader always offers the full image.

## Motion and haptics

- One spring for interface changes (`Animation.adult`: response 0.38, damping 0.82). Under Reduce Motion it becomes no animation, and the Mac page push becomes a fade.
- Marking a step done or known plays a success haptic, waits 350ms so the mark registers, then advances. Page changes play a selection haptic. The finish stamp bounces once.
- No ambient or entrance motion while reading.

## Progress model

- **Step marks:**
  - A step is **done**, **known** (already knew it) or **open**. Done and known are exclusive.
  - Both are fingerprinted, so an edited step must be marked again.
  - Both count toward progress. Skip is not saved.
  - Every mark is undoable: tap the same action again, or use the "…" menu.
- **Guide states:**
  - A guide is **finished** when every step is done or known, and **known** when every step is known.
  - Marking a whole guide known marks each step that isn't already done.
  - Known guides recede to 75% opacity with an outlined seal, and the "Hide known" chip removes them.
- **Storage:** optional fields on `ArticleProgress` (`knownSteps`, `favoriteSteps`, `lastActivity`). `schemaVersion` stays 1, so files from the submitted 1.0 build and from Fieldnotes still decode.
- **Favorites:** ♥ reuses the existing `isSaved` flag for guides, and steps can be hearted too.

## Passport

- **Stamps (automatic):**
  - One page per topic, with one stamp slot per guide.
  - A finished guide gets a filled stamp in the topic shape; a known guide gets an outlined stamp with a check; an open guide is a dashed outline.
  - A completed topic gets a rotated seal.
  - Stamps record finishing a guide, never competence.
- **Skills (reviewed):** the existing `AdultPassportStore` rules are unchanged; reading or marking steps never awards a skill. The tab shows only skills already earned on the device.

## Sub-areas

Sub-areas are derived from guide tags in `GuideSubArea`; the catalog schema has no sub-area field. All 273 bundled guides fall into at least one sub-area, and a unit test enforces at least 90% coverage. When new content arrives, add tags to an area rather than adding a backend field.

## Overflow menu

- **Marks:** favorite guide or step, mark step or guide known.
- **Look further:**
  - **Ask an AI** renders an editable template (Settings ▸ Ask an AI ▸ Prompt template), copies it, and offers "Open [assistant] and paste". It opens the assistant's plain home page with nothing pre-filled or sent.
    - Notes are included only when the "Include my notes" setting is on.
    - Rendering is single pass, so placeholder-looking guide text stays literal.
  - **Search Google** opens a query that keeps only unreserved characters unescaped.
- **Share, remind, notes, Help me do this.**
- **Second-screen mode**, shown only while an external display is connected.

## Second screen

- An external display gets its own non-interactive scene (`UIWindowSceneSessionRoleExternalDisplayNonInteractive`, declared in `Configuration/iOS-Info.plist`), never a mirror.
- Three modes:
  - **Current step:** readable across a room.
  - **Step and context:** the step plus supplies, cautions, the next step and progress.
  - **Whole guide:** up to four columns, scrolling itself to the current step when everything doesn't fit.
- Layout follows the display's real size and shape. Text never truncates: each mode tries smaller scales (down to 46%) until it fits.
- **Mac:** a resizable Presenter window (⇧⌘P).

## Keyboard

- ← and → page through the guide, mirrored in right-to-left layouts. Space moves forward.
- Guide menu:

  | Command | Shortcut |
  | --- | --- |
  | Next step | ⌘→ |
  | Previous step | ⌘← |
  | Done | ⌘↩ |
  | I know this step | ⇧⌘K |
  | Favorite guide | ⌘D |
  | Presenter (Mac) | ⇧⌘P |

- Commands post through `PresenterState`. Don't pass closures through `focusedSceneValue`: it caused an update loop during accessibility snapshots.

## Accessibility

Fieldnotes' order is kept within the overview: title → scope → summary → safety → tools/art. Other rules:
- **Element structure:**
  - Tiles, cards and stamps are single elements with a label and value.
  - Page segments are buttons ("Step 2", "Done, current").
  - VoiceOver three-finger swipes page through the carousel.
  - The step caution is read as "Caution: …".
- **Targets:** at least 44pt.
- **Container identifiers:** scope them with `.accessibilityElement(children: .contain)` before setting the identifier. On a bare stack, an identifier overwrites every child's identifier.
- Dynamic Type, Reduce Motion, both appearances, Increase Contrast (Fieldnotes rules thicken) and right-to-left layouts are supported.

## Kept from Fieldnotes without change

- **Elevation:** paper tonality, rules and plates. No global shadows or blur.
- **Launch screen.**
- **Reminders:** explicit Save and Cancel; permission requested only on the first save.
- **Storage and offline notices.**
- **Settings:** a sidebar on wide screens, with appearance persisted. An "Ask an AI" section is added.
- **Notes:** the editor with discard confirmation and conflict checks. Notes now live on the finish page.
- **Assistant:** the composer, plans and execution-review rules.
- **Private QA isolation.**

The Fieldnotes spatial references (`screens/*.png`) predate this redesign: they describe the paper, ink, type and reader details, not the new navigation.
