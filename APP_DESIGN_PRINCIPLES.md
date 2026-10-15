# App design principles

Standard ID: `100apps/app-design-principles` · Version: **1.0.1** · Issued: **2026-10-15**

Canonical repository: `https://github.com/fennelouski/100apps-ops`, path `design/APP_DESIGN_PRINCIPLES.md`; the version field identifies this revision. Local copies and distribution receipts can precede a reviewed integration commit. Do not claim a remote commit or publication until one exists.
Every app must receive a complete versioned copy of this file. `design/distribution-manifest.json` records intended destinations, per-destination status, and post-copy SHA-256 verification; its integration receipt records the eventual commit. Preserve divergent existing copies for reconciliation. Update the canonical source, review the change, then redistribute; do not silently fork individual copies. Project-specific decisions belong in the app's existing `DESIGN.md` or a short `APP_DESIGN.md` beside this file. Existing project instructions and Nathan's explicit decisions remain applicable.

## Start with the product

Design the experience before assembling screens. State the user's immediate job, the primary action, the information needed to take it, and the app's distinctive visual idea. Inspect the actual app, current source, existing artwork, and important states. Preserve functional fixes, user data, privacy boundaries, permission gates, and truthful content.

Create rendered references for the key screens and a small, coherent system before a broad visual rewrite. References govern identity, hierarchy, and intended composition. Product truth, safety, accessibility, and native behavior govern necessary adaptations; record those adaptations in review. A moodboard, token list, or prose description alone is insufficient. Reference screens illustrate product truth; they must not invent features, content, success states, or permissions.

Every app deserves its own identity. A music library, practical guide, clock, and playful display should not inherit the same layout or palette. Share these quality principles; define each app's color, type, spacing, shape, texture, illustration, iconography, and motion independently. Use native conventions where they improve understanding and operation. Default SwiftUI lists, repeated rounded cards, decorative gradients, and generic welcome dashboards are implementation conveniences, not a design direction.

## Show the work

Let the actual content, artwork, sound controls, board, or tool occupy the first useful screen. Make the primary action obvious through placement, size, contrast, and surrounding space. Use icons, short familiar labels, alignment, and color to reveal structure. Avoid paragraphs that explain an interface the interface could demonstrate.

Aim for roughly **90% less explanatory interface copy** when replacing a verbose flow. Treat this as a strong editing ambition, not a quota. Retain essential task content, safety instructions, legal meaning, costs, privacy consequences, errors, and destructive-action consequences. A tutorial may be shorter; a substantive guide must remain complete.

Use a clear hierarchy: one main task per surface, a small set of immediate supporting actions, and progressively disclosed advanced controls. Menus, inspectors, and edit modes should contain secondary actions without hiding frequent work. Give empty states a useful next step. Errors identify what happened, what was preserved, and a concrete recovery action.

An icon-only interactive control needs an accessible name and, on pointer platforms, a helpful tooltip. Hide decorative symbols and redundant icons within already named controls from accessibility traversal. Add a short visible label when the symbol or gesture is unfamiliar. Do not make color, animation, a tooltip, or a hidden gesture the sole way to discover an essential action. Gesture-led surfaces need accessible actions and keyboard equivalents where supported, with a brief discoverable introduction or help route.

## Build a visual system

Record semantic tokens with actual values and uses: background, raised surface, primary and secondary text, accent, separator, focus, selection, success, warning, and error. Include light and dark variants, including text placed over artwork. Restrained screens can still use rich color. Texture should reinforce the product's material character without lowering legibility or becoming visual noise.

Define a type scale, readable measures, baseline spacing rhythm, edge insets, control sizes, corner treatments, separators, and component states. Use typography and negative space to establish hierarchy before adding containers. Favor authored compositions and meaningful grouping over a homogeneous stack of cards. Use free/system fonts and owned or appropriately licensed assets; record provenance for outside assets.

Specify the actual components the product needs: navigation, search, selection, content rows, artwork, forms, menus, progress, status, empty/error/loading states, and destructive confirmations. Cover resting, focused, selected, disabled, loading, error, and success states when applicable. Preserve native selection, text entry, keyboard navigation, scrolling, and system permission behavior.

Use motion to explain a transition, direct attention, or acknowledge an action. Keep it brief, interruptible, and subordinate to the task. Avoid perpetual decoration and movement beneath reading text. Under Reduce Motion, replace movement with an immediate state change or restrained crossfade; preserve the same information and functionality.

## Launch honestly

Design the static launch surface and first interactive frame together: compatible background, mark, placement, and visual weight. The launch surface may be beautiful; it cannot pretend that content or controls are ready. Never add a delay to exhibit branding. Optional subtle motion belongs only during real loading and stops as soon as the app is ready.

Reserve space for asynchronously loaded artwork and status so the main action, reading position, and navigation do not jump. Distinguish loading, empty, offline, and failure. Keep useful cached or local content available when the product supports it. Never present simulated progress, frequency data, records, or success as live evidence.

## Adapt the composition

Base layout on available geometry, content size, and task, rather than a device name. Compact screens may stack; large screens should gain useful structure and sensible text measures, not enlarged phone cards. Support rotation, split windows, narrow desktop windows, safe areas, keyboard appearance, and long or localized content where supported.

Preserve selection, query, filter, edits, playback, and reading position when resizing, rotating, changing theme, or entering accessibility layouts. Keep important controls stable during state changes. Offer a clear exit from edit mode and an understandable Save/Cancel policy. Confirm a destructive action when recovery is difficult; prefer undo for reversible actions. Never discard unsaved work silently.

## Make access part of the composition

Meet at least **4.5:1** contrast for normal text and **3:1** for large text and essential non-text control boundaries/indicators. Check actual rendered foreground/background pairs in every theme, including placeholders, muted labels, artwork overlays, disabled-state meaning, and scrolled toolbars. Do not use color alone for state.

Honor Dynamic Type or platform text scaling. At the largest supported accessibility size, primary content and actions must remain reachable without clipped labels, overlapping controls, or fixed-height text containers. Reflow or scroll deliberately. Target at least **44 × 44 pt** interactive areas on Apple touch interfaces and the relevant platform minimum elsewhere (for Android, **48 × 48 dp**). Compact visual marks can have larger hit areas; expanded hit regions must not overlap adjacent actions.

VoiceOver/screen-reader labels describe the action or content; values expose current state; hints add only useful information. Order follows the task and reading hierarchy. Group related information and avoid duplicated decorative announcements. Provide meaningful descriptions for instructional imagery, keyboard focus visibility, logical traversal, and equivalents for gesture-only actions. Verify these at runtime; source inspection alone cannot establish spoken traversal or focus behavior.

## Teach through doing

Keep onboarding short and experiential. Demonstrate one real interaction at a time using the app's actual visual language. Allow back, forward, skip, and an obvious exit; make it resumable or replayable where useful. The preview must fit the current geometry and text size. Do not trap people behind a carousel or ask for permissions before their benefit is clear.

Explain platform limits, external display behavior, sync, subscriptions, and permission effects truthfully at the moment they matter. A compact interface may use progressive disclosure, but it cannot conceal a critical limitation or consequence. System permission requests follow a deliberate user action; onboarding is not blanket consent.

## Acceptance evidence

Before calling a design change complete, record the source commit or file hashes, build/configuration, capture dimensions, theme, text size, and data provenance. Use actual running-app screenshots for implementation review. Label rendered design references and synthetic fixtures explicitly. Do not substitute references, storyboards, simulator configuration, or build success for runtime evidence.

Inspect a bounded matrix appropriate to the shipped product:

| Surface or behavior | Minimum evidence |
| --- | --- |
| Primary task and discovery | Actual first useful frame, primary action, representative populated and empty state |
| Secondary work | Relevant search, detail, edit/exit, settings, failure and recovery states |
| Launch | Actual static launch and subsequent interactive frame; no artificial delay |
| Adaptation | Compact and large layout, light and dark, large accessibility text; resizing/rotation retains meaningful state |
| Accessibility | Measured contrast, screen-reader traversal, keyboard operation where supported, Reduce Motion behavior |
| Content and data | Long labels/content, real artwork fit, loading/offline behavior, persistence and destructive consequences where relevant |

Use existing evidence when its exact source and freshness are established. Where a device, session, permission, or environment is unavailable, mark the check **unobserved** and state the specific gap. Do not broaden a scoped visual pass into release approval. Screenshots cannot prove interaction, persistence, live data, audio correctness, or accessibility traversal by themselves.

Review the full change in one batched pass, fix the ranked issues together, then perform a bounded confirmation pass. Stop cosmetic iteration when the agreed acceptance criteria pass. Use additional passes only for material new findings or changed scope.

## Before/after review record

Save each app's review in its established evidence location, with this structure:

1. **Identity:** app, source pin, owner, reviewer, date, standard version, app-specific design reference, and submission eligibility evidence. A historical submission counts as submitted; absence of a receipt means unknown, not never submitted.
2. **Scope and truth:** routes/states inspected, actual screenshot paths and dimensions, synthetic fixture labels, platforms observed, and explicit exclusions.
3. **Before:** the user's job and concrete friction, tied to a capture or source location. Record visible explanatory-copy count if copy reduction is a goal.
4. **Ranked fixes:** P0 blocks safe/correct use; P1 blocks core use or access; P2 materially weakens hierarchy, clarity, or coherence; P3 is optional polish. Each finding states trigger, observed result, intended result, evidence, and owner. Avoid taste-only blockers.
5. **After:** source/capture evidence for each resolved finding, what changed and why, and the relevant runtime checks. Keep unresolved findings visible.
6. **Verdict:** pass, pass with stated limits, or changes required for the inspected scope. Separate design acceptance, functional verification, App Review status, external publication, and release authorization.

The implementation owner remains the sole writer of app features. Reviewers inspect source and evidence independently, send precise corrections, and verify the result. Follow existing project instructions; do not overwrite user changes, erase earlier design records, or silently expand permissions, publication, or review scope.
