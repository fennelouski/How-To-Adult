---
name: How to Adult — Fieldnotes
description: An adult, practical editorial guide with warm paper, pine ink and authored teaching art.
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
  image: "3px"
spacing:
  unit: "4px"
  inline: "8px"
  component: "12px"
  row: "18px"
  inset: "24px"
  section: "28px"
  spread: "40px"
components:
  primary:
    backgroundColor: "{colors.clay}"
    textColor: "{colors.on-clay}"
    rounded: "{rounded.control}"
    height: "48px"
  caution:
    backgroundColor: "{colors.caution}"
    textColor: "{colors.pine}"
    padding: "16px"
    rounded: "{rounded.control}"
---

## Overview

**Design authority:** `screens/*.png` and their editable HTML are the platform-independent spatial references. These are design renderings, not native screenshots. Implement in the existing app through its single writer. Preserve guide bodies, cautions, scope, sources, revision-bound images, original IDs, bookmark/check fingerprints, reminders, storage handling and publication gates. All progress and counts in the reference screens are fixtures. Do not paste shortened presentation extracts over catalog content.

The product helps someone find an answer during a real everyday task, follow the steps, then keep the answer handy. Its visual world is a carefully typeset practical field guide: warm paper, dark pine type, clay links, quiet rules and generous editorial headings. It should feel capable and welcoming to adults. No badges, gamification, childish illustrations, motivational filler or equal-size card wall.

Discovery is **Operate**, the guide reader is **Read**. The first viewport must offer search, one useful illustrated guide and direct topic routes. The reading page leads with the actual question and the next useful action. The signature interaction is a checked step that fills quietly while the instruction remains readable. The hero never replaces discovery with a promotional landing page.

**IA:** Guides (search, topic and region facets; featured guide; optional resume row) / Saved (In progress, All saved) / Reminders. Settings is a toolbar destination, not another browse tab. Phone navigation stacks retain their independent paths. Wide layouts use a sidebar, guide index and reader. Every published category remains available, including Everyday; six visible examples are not a hardcoded reduced taxonomy. Search activates results immediately. Result order uses current search behavior, not the illustrative numbers in the comp. Scope filters must reflect actual jurisdiction data.

Safety and approval are content states, not a public authoring dashboard. Normal users see only published content. Do not reveal draft identities or sensitive review counts. A previously saved guide that is unavailable gets a concise “Unavailable” notice and preserved local progress, according to the actual policy; never silently republish a withdrawn guide. The availability screen is a state/style reference, not a mandatory new navigation destination. Reviewed does not mean certified or universally safe. Keep explicit local guidance and full cautions before relevant steps.

## Colors

Use semantic tokens, resolved by appearance. Light: paper/background, raised/search, pine/main ink, muted/supporting text, clay/action, rule/separators, caution/safety. Dark: dark-paper/background, dark-raised/search, dark-ink/main ink, dark-muted/supporting, dark-action/actions, dark-rule/separators, dark-caution/safety. Dark actions use dark-paper text. Accent never carries completion or caution without a symbol/label.

Category accents may appear in the 18–22pt topic symbol, but hierarchy is governed by pine/clay. Avoid seven competing pastel containers. The light paper field and the cream originals belong together. Preserve an illustration’s original colors in dark mode; give it a quiet paper matte. Never invert its pixels.

`../evidence/contrast.json` records measured sRGB contrast for actual foreground/background pairs. Dividers are decorative and do not substitute for labels or required control boundaries. Focus outline uses action color at 3px, with 4px separation; native focus rings may use the platform equivalent. High Contrast increases rules and circle strokes, not grain.

## Typography

The system is defined by **roles**, not an Apple font dependency: editorial serif for display/section titles, practical native sans for body and controls. The portable reference uses Georgia. Apple implementation may use system serif at the same optical scale and a normal system sans, maintaining the serif/sans contrast. Do not flatten every heading into system bold. No new font purchase, network load or redistributed system font.

Phone defaults: display 36/38, reader title 34/36, featured title 27/28, section 25/29, guide and step title 17/22 semibold, long reading body 17/25.5, supporting copy 15/22.5, metadata 12/18. Use Dynamic Type text styles and relative scaling, not fixed render sizes in runtime. The PNG is a reference at normal scale. Desktop display may rise to 40/43; body remains 17/26. Readable measure 56–72 characters, maximum reader column 720pt including padding. Long titles wrap without ellipsis. No decorative uppercase eyebrow; actual country/scope metadata may follow the title. Tab labels remain visible by default.

## Layout

4pt base; 8 inline, 12 component gap, 18 row vertical, 24 phone inset, 28 section separation, 40 large spread. Phone width reference 390 × 844 logical points; account for real status/safe areas rather than baking 44/83pt bars into SwiftUI. Search is 48pt high. Header controls have 44pt targets. Native tab/safe-area heights win.

The featured spread pairs a title-led left column and a complete teaching image on the right. On narrow phones or accessibility sizes, stack text and art vertically. No cropped instructional text inside the art. When artwork cannot be readable at thumbnail scale, treat the thumbnail as recognition only: keep an image-description/full-size action in the reader and no essential instruction solely in a thumbnail. Inline step art uses full aspect fit and may span the reader; hero and step associations remain bound to their original step IDs. Never move a teaching image to an unrelated guide because the palette matches.

Below ~680pt: a single stack and native tabs. At ~680–999pt: optional index plus reader, collapsible sidebar. At ≥1000pt: 220–240pt sidebar, 320–410pt index, flexible 560–760pt reader. Collapse columns when available width or text size demands it. Center the full composition on very wide windows; do not stretch body text. See `09-wide.png` at 1440 × 960. Native minimum windows may be smaller and must reflow.

Scroll content has bottom inset equal to the floating action or tab height plus 16pt. Reference frames show the initial viewport; controls must never cover content at the end of a scroll. Onboarding is optional and must not block the bundled library.

## Elevation & Depth

Texture comes from paper tonality, fine book-like horizontal rules, the cream teaching plates and original diagrams. Do not add noisy filters, fake parchment, bevels or a background grain layer behind text. The reference is intentionally tactile through material contrast. A neutral 1pt inner paper edge is permitted on a print-style image plate. No global shadows, gradients or material blur. Native sheets and bars keep their platform depth.

Launch uses the same paper/pine values, book mark and wordmark positioning family as the first interactive frame (`10-launch.png` → `01-discovery.png`). Use original app-icon artwork where appropriate; the line book in the reference is the UI symbol role. Static launch is attractive by itself. No timer, forced splash or artificial delay. If real local loading persists, show a small progress indicator next to its task label; the page and cached text remain visible. Content refresh never clears the screen.

Motion: step check fill 120–160ms; pressed opacity 100ms; content/navigation follows native 180–240ms ease out. No page-wide entrance. Reduce Motion removes custom transforms and step movement; state changes remain immediate and perceivable. No continuous ambient movement while reading.

## Shapes

8pt controls/notices, 10pt search, 3pt image plates. The reference check circle reserves a44pt visual and hit region; native implementation may use a28–30pt circle inside a44pt target. Rounded shape is a control language, not a container around every paragraph. Section rules are 1pt. Use a consistent outline icon family at 1.7–2pt, 18pt in topic rows, 22pt in toolbar/tab roles. Apple uses semantic SF Symbols; other platforms use equivalent outline icons. Never replace teaching art with enlarged stock symbols or emoji. Authored illustrations are sourced from the existing verified manifest, without modifications or paid assets.

## Components

- **Search:** visible on discovery, direct question placeholder, semantic label “Search guides.” Results replace featured content and expose active topic/scope facets. Clear query and clear facets are separate controls. Empty: “No guides found” + active filters + “Clear filters.” A spelling suggestion is optional only if the search supports it.
- **Featured spread:** one title, time/step metadata, complete art thumbnail, one “Open guide” action. Match the reference’s asymmetric editorial hierarchy. Selection is one container/underline, never nested button backgrounds.
- **Topic index:** compact two-column text/icon routes, fine bottom rules, no descriptive blurb per topic. At large text it becomes one column. Include all real categories.
- **Guide row:** wrapping title, useful short summary, time/steps and jurisdiction if specific. Chevron optional on native platform. Entire row target ≥44pt. No artificial numbered search ranking; the reference numbering can be omitted in real results.
- **Reader:** actual title and scope, full summary, meaningful time, tools, full cautions at the relevant moment, full-aspect art, step list, source links and exact review date. Full-size art is zoomable and dismissible with keyboard/Escape; labels/descriptions remain accessible. Save, reminder, share remain native toolbar actions; primary next-step dock is optional only when its anchor scrolls directly to the next unchecked step. It is never an extra copy of a persistent Save button.
- **Steps:** check circle + title/body; index only where sequence matters. Keep completed text full contrast; no strike-through/dimming. Progress is a count plus segmented line, never a reward ring. Autosave immediately with the existing store. Reset requires the app’s existing undo/confirmation policy and must not erase bookmark/reminder state.
- **Saved:** resume section first, then remaining bookmarks. Do not infer completed from saved. Empty screen uses one book mark, “Keep a useful guide handy” and “Browse guides.” No fake empty-state progress.
- **Reminders/permission:** show the selected guide and explicit Save/Cancel. Request notification permission only after saving the first actual reminder. Denied: retain reminder intent and provide Settings recovery. Never launch a system request on discovery.
- **Storage/offline:** cached text remains usable; unavailable art gets “Illustration unavailable” plus accessible description and Retry. Data-storage failure gets a persistent concise notice + Retry, without false “saved” copy. Background refresh uses inline status only while real work runs. Do not represent reachability as successful publication.
- **Settings:** themed native grouped sections; appearance, accessibility/sound, content status, privacy, about. Retain settings section on wide layout and persist all options.
- **Accessibility:** VoiceOver order title → scope → summary → safety → tools/art → steps → sources. Step announces title, completion and position; the whole paragraph need not be a repeated button label. Decorative symbols hidden. Described images use existing alt text, not repeated captions. At AX sizes stack image/title, use one-column topics, no floating dock over body. Provide 44pt iOS / 48dp Android targets and keyboard focus/activation on desktop. High contrast and differentiation without color remain meaningful.

## Do's and Don'ts

Do preserve the current guide catalog and every functional recovery fix. Do implement the real list, reader and saved flows through the owner. Do compare light/dark, compact/large and accessibility captures against the references. Do leave approvals/push with the parent. Do not add backend fields, publish drafts, rename source identifiers, claim new content safety, use paid compute or touch a physical phone from this design task.
