# Skill passport review slice

8 October 2026. Branch `codex/how-to-adult-skill-passport`. SOL 6.1 was used for agent work.

Baseline commit `ab5c9a849b8a5f99c315cb9d68fce55d5b363835` snapshots the existing native work before passport changes. Review the feature against that commit to keep the pre-existing Assistant, instructional-image reader, platform and configuration work separate. This snapshot does not establish release readiness.

## Implemented scope

An explicit DEBUG launch argument, `--adult-passport-review=<UUID>`, opens an isolated local review session. Explore provides a map diagram/list switch, search, saved guides, world cards and a pending-task link. The existing reader leads to one bounded attempt, explicit self-report, then My sash. Sash and collection share achievement details, confidence, hide and undo actions. The ordinary production reader remains available.

The reviewed fixture appears in Home Base and Workshop Woods as one canonical skill and badge. Reading and checked guide steps cannot award it. The task stops after finding one garment care instruction and consulting the maker's guide when a symbol is unclear. It does not involve washing, ironing or treatment. US applicability is explicit QA metadata, not a worldwide inference from the guide's General jurisdiction.

| Binding | Exact value |
| --- | --- |
| Guide | `read-a-care-label` |
| Catalog revision | `2026-10-03-starter-1` |
| Sorted-JSON article SHA-256 | `1495a2108198a77a90c76cd90f92e08d137184a0f3bdbcc0a1ff06fb101708e1` |
| Canonical skill / badge | `qa-read-care-instruction` / `qa-care-label-badge` |
| Manifest | `qa-passport-20261008-v1` |
| Neutral decorative asset | `qa-neutral-shape-v1`, native vector placeholder |
| Instructional assets in fixture | Empty binding |

These are review fixtures, not published content approvals. No candidate badge masters were integrated. The map is a diagram and the sash a ribbon with lazy achievement rows; miniature scenes, polished textile artwork and production catalog population remain outside this slice.

## Native design decisions

Semantic native colors separate world markers, primary actions and private state. Guide cards keep full authored titles and summaries. A serif display heading gives Explore and the world a different role from task instructions; short navigation titles avoid truncation while the full title wraps in the body. The existing reader stays the main instruction view. Decorative symbols are hidden from accessibility when nearby text already names the action.

The review map uses readable colored world blocks until verified miniature scenes are available. The sash uses a broad diagonal native ribbon above lazy achievement rows. Its minimum height expands with text rather than clipping it. Sash and plain collection share record actions; hiding removes the decorative mark while keeping an accessible private record. No authored unfurl, confetti or drag-only controls were added.

## Admission and local data

Production passport admission defaults to empty. Review UI and session setup are DEBUG-only; synthetic `.fixtureApproved` approval requires both explicit review flags and a low-risk placeholder. Release rejects it. Candidate artwork cannot pass production admission.

The manifest binds exact guide identity, catalog revision, body including sources/jurisdiction, instructional asset hashes, badge asset version, task, outcome, criterion, warnings and exact country codes. Review, publication, award, artwork and risk states remain separate. Higher-risk entries require prepared badges. Explicit canonical skill/badge mappings are one-to-one; world placements never create aliases. Discovery and direct award use the same admitted full-entry values. Admission inputs are immutable and cached at initialization; changed content requires a new store.

`SkillPassport-v1.json` is independent of `UserLibrary-v1.json`. Saved remains the existing bookmark; learning/trying, earned/removed, confidence and sash visibility remain independent. No legacy schema rewrite or inferred awards occur. Corrupt/unsupported passport bytes are preserved and its writes blocked. Mutations validate a copy, write atomically, then publish memory; failed writes leave prior state unchanged. iOS uses the existing file-protection option.

Repeated awards preserve one record ID and chosen date. Undo marks an accidental claim removed while retaining its private snapshot. Intentional restoration requires current admission and preserves the original history. Refresher and hiding do not remove an award. Withdrawn or changed content blocks new claims and leaves historical self-reports readable with a notice. Undo is not full private-data deletion. No backup rotation, cloud sync, account, photos, proof uploads, telemetry or sharing was added.

Review storage and preferences use a UUID-specific `HowToAdult-PassportReview` directory/suite. Remote updates and notifications are disabled; private-QA Assistant initialization avoids credential reads and blocks generation/actions. Normal personal library data is not opened by this launch path.

## Verification

- Native iOS test run: 29 tests passed, zero failures or skips.
- Independent copied-source core runs: 25 DEBUG and 25 Release tests passed, including 17 passport tests, six existing pure core tests and two adversarial tests.
- iOS DEBUG and Release, macOS DEBUG, and generic visionOS compiler checks succeeded. visionOS was compilation only; its Simulator frontend was not opened or run.
- Release inspection found the review fixture identity and review directory absent from the binary; Release tests reject fixture admission.
- A synthetic 2,000-entry microbenchmark reduced 25 article lookups from 462 ms to 0.013 ms, moving admission to roughly 77 ms initialization. This measures lookup work, not native scrolling FPS, device performance or memory pressure.

The separate macOS SwiftPM attempt at native AdultStore tests aborted during `UNUserNotificationCenter.current()` because it lacked an app host; it is not counted as passing. Native iOS results above provide the host-based verification. Filesystem blockers exercise failed writes; actual disk exhaustion or power-loss interruption was not simulated.

Native iPhone 26.5 QA covered map/list discovery, the unchanged reader, save, task boundary, Still practicing without an award, explicit self-report, sash/collection, confidence, hiding, cancellation and confirmed undo. Cold relaunch retained the achievement ID, chosen date and refresher state. Undo retained that same private record as removed, including confidence and visibility; the existing guide-library bytes stayed unchanged through award and undo. Largest accessibility text in dark mode wrapped the Explore labels and allowed scrolling to the world controls. Full task/detail large-text coverage is still pending.

Native iPad 26.5 QA showed the world and unchanged guide reader in light mode without clipped titles or controls. With simulator VoiceOver and Reduce Motion enabled, the reader opened the bounded task and self-report sheet, the explicit claim persisted exactly one record, and See my sash reached that record. This is a limited activation smoke check, not spoken-order or rotor signoff. The native accessibility tree exposes full guide text, named step/rating controls, Try this and Save guide. Native macOS QA opened the review session and map/list, and exposed named search/selection controls. Tab/arrow input under the current Mac keyboard settings did not establish navigation between controls. Full VoiceOver traversal, keyboard/switch navigation, measured contrast, physical-device data protection and large-collection scrolling remain unverified.

The existing local catalog validator and its 16 rejection self-checks passed on the unchanged 56-guide bundle. That older schema validation is separate from exact-review approval and country release. The original working-tree preservation audit checked 839 files: 836 were byte-identical and none missing. Only the intended App.swift, AdultViews.swift and project.pbxproj integration files changed. All tested new source hashes still matched the final files.

Reports and screenshots are under `/Users/nathan/Library/Application Support/CodexReleaseArtifacts/HowToAdultPassport/20261008`.

## Missing source inputs and publication gates

Library retrieval was unavailable. These exact requested inputs were not recovered or inspected locally:

| Input | Library ID |
| --- | --- |
| How-to-Adult-Product-Design-Brief.docx | `libfile_646c83b25278819181b03b38e896abf8` |
| how-to-adult-continuing-repairs-20261008.zip, v8 | `libfile_635312ade53c81919c1d3aa7b8ea5919` |
| how-to-adult-following-repairs-20261008.zip, v10 | `libfile_ce612e39f0d4819183817a4f0ed5ad55` |
| how-to-adult-reviewed-repairs-20261008.zip, v13 | `libfile_bca5431177dc8191af8d9617534289bb` |
| How-to-Adult-Badge-Review-Book.pdf | `libfile_0ad565624cb481918d090e836ad3aa7a` |
| How-to-Adult-Badge-Accessibility-Companion.zip | `libfile_fd18344745508191884fac3e08e8620d` |
| How-to-Adult-Download-22-QA-and-Reference.zip | `libfile_ed213e6bcda081919461d44aeb81a69d` |
| How-to-Adult-Complete-141-Badge-Candidates.zip | `libfile_cb9f87d68ad48191bfd99636a143af60` |

The v8 recovery is not standalone; its exact seven historical dependency layers were not reconstructed. The checkout lacks the requested `authoring/continuation` source and `CURRENT-AUTHORING-STATE.json`, `reviewed-corrections-registry.json`, `reviewed-candidate-queue.json`, `verify_reviewed_corrections.py` and `verify_attribution_hold_state.py`. Those exact-review/hold validators were not run. Collection/per-pack manifests, SHA256SUMS, provenance, accessibility companions and image pixels also remain uninspected. No alternate route was used for the blocked next-repairs transfer.

The user's external checkpoint remains 500 tracked offline identities and 20 receipt-backed registered additive exact replacement bodies, comprising 11 held-original alternatives and nine historically active-original alternatives. They add zero identities; all 11 original holds remain. Historical assessment coverage is separate, including the older 472 unassessed identities. This work did not independently verify those recovery bytes. Public counts and release readiness remain unknown; unregistered broccoli and spreadsheet packets gain no publication credit.

The supplied external artwork checkpoint is 141 decorative candidates, 132 exact guide bindings and nine unbound proposals, with 111 skill hexagons and 30 prepared pennants. Zero masters pass strict clean alpha; 140 need collection-wide padding normalization and rights/trademark review remains open. These supplied counts are not inspected production approvals or native artwork QA.

Production worlds and earning require genuine release-approved exact manifests, country/content admission and verified assets. Proposed release quotas, additional worlds, polished sash/scenes, pinning, media, export, narration and AI coaching remain follow-ons. No deployments, app uploads, release submissions, paid resources or third-party contact occurred for this slice.
