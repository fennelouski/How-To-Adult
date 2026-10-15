# How to Adult

A native pocket guide for iPhone, iPad and Mac. The bundled public snapshot contains 273 guides across seven topics and matches the existing AWS/Vercel publication. Its exact-revision sidecar identifies 233 teaching illustrations. Search works locally; saved guides, checked steps, reminders, personal notes and ratings stay on the device.

The Fieldnotes interface uses warm paper, pine ink, clay actions and serif headings. It adapts from compact tabs to native guide-index/reader columns, retains search and selection while resizing, supports Dynamic Type and both appearances, and offers image descriptions and full-size zoom. Full guide bodies, cautions, jurisdiction, sources and stable guide/step identities are preserved.

## Assistant source

Assistant is a separate tab and the guide's “Help me do this” route prepares its real context. Plans retain reminder, calendar, research, shopping and checklist actions, stable IDs and durable execution receipts. Existing explicit execution/automation opt-ins, uncertain-write review and shared notification limits remain in force. Automation defaults to off and affects only new eligible plans; deleting a plan does not remove native items already created.

On-device planning requires the existing Apple Intelligence availability checks on supported 26+ systems. Other devices may use the existing optional user-supplied OpenAI API key. Keys remain in non-synced device Keychain storage. OpenAI requests use the user's API account and may incur its charges. Nothing is generated merely by opening a guide. Shopping prepares a list; there is no integrated checkout. Shortcuts invokes the existing “Make a life plan” intent. There is no always-on authoring service.

Skill-passport models and tests are retained. Its navigation is a DEBUG-only review session with explicit fixture gates; it is absent from ordinary navigation. No new passport content has been admitted.

## Build and verify locally

Run `python3 scripts/generate-native-project.py`, then open `HowToAdult.xcodeproj`. Active schemes are HowToAdult-iOS and HowToAdult-macOS; minimum systems remain iOS/iPadOS 17 and macOS 14. Existing visionOS source/assets are preserved, but the generator does not create or build a visionOS target under the owner's current restriction.

The native tests use blank hosts or private UUID sessions before ordinary library, preferences or Keychain initialization. Private UI sessions use their own data/defaults, show a QA marker and disable AI, scheduling and external actions. A separate art-read flag allows immutable public artwork without catalog refresh. Historical permission/device UI probes are retained under UITests/Legacy outside the active source glob.

The original Objective-C app and Core Data files remain in place. Modern targets never open or rewrite the old SQLite store. The modern UserLibrary-v1.json retains prior bookmarks/check fingerprints/reminders when optional notes and ratings are added. Notes keep explicit Save/Cancel, dirty-dismiss/discard protection and concurrent-edit checks.

## Content service

The verified reader origins are https://how-to-adult-guides.vercel.app and https://m0jxoitx8f.execute-api.us-west-2.amazonaws.com. This integration does not publish a catalog or deploy infrastructure. Content writes continue to use the existing editorial API contracts, ETags and version guards. No daily generation schedule is enabled. See BACKEND.md, EDITOR-API.md and CONTENT-EDITORIAL.md.

Public content and artwork must remain separate from recovery/review material. Only the 273-guide catalog, its exact manifest and the 233 referenced PNGs seed the reader backend. Artwork is bound to the exact catalog/service fingerprint and verifies PNG digest, byte and dimension limits before display/cache; an artwork failure leaves text/progress usable.

## Verification limits

Local build/test and native capture receipts belong to the integration handoff. A previous design verdict does not certify later code, live providers, native external-action delivery, minimum-OS runtime, App Store status or publication. Current Mac resizing is unobserved while the Studio is locked, and spoken VoiceOver traversal remains unobserved. This source has not been uploaded or submitted during this integration.
