# Assistant release readiness

Recorded October 4, 2026 from saved release receipts and current native source. This document does not record a new build, device run, live API request, deployment, upload or submission.

Root subsequently completed final iOS/macOS builds, 76 passing unit tests with one intentional live-catalog skip, one private UI flow on each of iPhone/iPad, and a real on-device service inference. Those results and their precise limits are recorded in [verification.md](verification.md); they do not establish live OpenAI, native delivery, closed-app Shortcuts, Mac GUI, a public policy update or a new review submission.

## Submitted release and new source

The saved [iOS submission receipt](../2026-10-04-release/ios-submission-receipt.json) is authoritative for the existing pocket-guide release. It records iOS **1.0 build 1, Waiting for Review**, Apple ID `6818756061`, submission `69e6815f-801c-49b8-bb0f-41be9dd97694`, submitted October 4 at 2:44 PM Europe/Amsterdam. Its native release revision is `ca8edc4e786d25504b06fa177468f42adde376fd`. Free pricing and availability were saved for all 175 listed countries, future regions enabled, with automatic release after approval. This status is neither Apple approval nor public availability.

The older macOS 1.0 candidate remains Prepare for Submission and is held for original-bundle runtime/window QA and native gallery verification. No Mac submission is recorded.

The current Assistant is new working source. It is not in the submitted iOS build, has no version bump, and has not been archived, uploaded or submitted as a new release. Earlier guide tests, package inspections, marketing approval and the published privacy label do not qualify the new Assistant.

## What the source implements

| Area | Current implementation | Release qualification |
| --- | --- | --- |
| Entry and editing | Dedicated Assistant tab, guide-to-task entry, example tasks, editable typed action cards and saved plans. | Final native layout, accessibility and navigation evidence must cover iPhone, iPad and Mac. |
| On-device AI | Apple Foundation Models planning, gated on iOS/iPadOS 26 or macOS 26 and the model's actual availability. | Apple Intelligence must be enabled on a supported device. No live model behavior is established by mock or private preview tests. Older supported OS versions retain guides and can use the optional API connection. |
| OpenAI API | Optional user API key, editable model and connection check, structured plans and separately requested web research. | Keychain is non-syncing and device-only, accessible when unlocked. API usage belongs to the user's API account. Live model access, billing, refusal, network and citation behavior still need provider verification. |
| Native actions | Reminder/calendar actions persist `.running` before a write, then retain the service's actual identifier. Interrupted or uncertain outcomes require review before another attempt. | Current reminder controls schedule app notifications; calendar controls create real events after permission. Final permission, execution, recurrence and receipt/relaunch checks must be tied to the new frozen source. |
| Automation | Reminder and calendar automation are independently off by default. Enabling a category requests permission, then applies only to new plans with complete future schedules. | Turning automation off preserves existing native items. There is no cancellation claim or automatic replay of old plans. |
| Shortcuts | “Make a life plan” App Intent sets `openAppWhenRun = false` and shares the controller/library contract. Personal automation scheduling is configured in Apple's Shortcuts app. | Closed-app invocation remains to be verified on actual supported platforms. AI needs its provider, permissions and available protected credentials; the app does not run an always-on background agent. Scheduled OS notifications can be delivered without the app running. |
| Research | Original sourced answers are retained with citations from guide sources or actual provider web annotations. Initial plan research and each action's research are stored separately. | HTTPS/provenance validation is not live source verification. Annotation range behavior, actual readable linked answers and cloud integration need final evidence. |
| Shopping | Item lists, read-only source-backed option research and a separate list-prepared completion state. | No integrated merchant checkout, order service, payment, guaranteed stock, prices or purchase receipt. The user completes any purchase at the seller. |
| Storage and removal | Separate atomic `AssistantLibrary-v1.json`, stable IDs, bounded archive, corruption preservation, action receipts and per-action answers. Local deletion rejects running actions. | Plans and keys are device-local. Explicit deletion confirmation warns that already-created reminders/events remain. Deleting review receipts does not cancel native items. |

Source boundaries are [Assistant views](../../Sources/AdultAssistantViews.swift), [settings](../../Sources/AdultAssistantSettingsView.swift), [controller](../../Sources/AdultAssistantController.swift), [AI connection](../../Sources/AdultAIConnection.swift), [AI service](../../Sources/AdultAIService.swift), [action executor](../../Sources/AdultActionExecutor.swift), [models](../../Sources/AdultAssistantModels.swift), [library](../../Sources/AdultAssistantLibrary.swift) and [Shortcuts](../../Sources/AdultAssistantIntents.swift). [Native design decisions](native-design-decisions.md) describe the interface contract.

## ChatGPT access remains pending

The portfolio [access request receipt](../../../app-release-audit/chatgpt-sign-in-2026-10-04/openai-access-request-submission-receipt.json) records that OpenAI received the request on October 4 at 15:26 UTC. It explicitly records approval pending, no API client issued and zero live AI requests. Receipt is not permission to launch the integration.

How to Adult has no ChatGPT OAuth integration, connected ChatGPT account or verified subscription-backed inference. ChatGPT is absent from the native provider choices. A future connection requires product approval, supported native callbacks, protected session handling, explicit usage consent and its own test/privacy evidence. Existing OpenAI API-key support must not silently become ChatGPT-plan use.

## Evidence required before the next release

1. Freeze the final Assistant source and test inputs, resolve actual compiler/test failures, and retain precise test counts and original failure evidence. Private UUID fixtures must continue to avoid ordinary data, Keychain, catalog requests and native scheduling. Private preview screenshots prove preview UI only.
2. Record final normal native UI and accessibility evidence on each intended shipping platform, including complete action labels, evidence links, editing, saved preferences, deletion confirmation and readable plan sharing. Record Apple Intelligence and live API limitations separately from fixture coverage.
3. Verify real permission denial/recovery, schedules, recurrence, native receipts and interrupted-write review on the final candidate. Verify Shortcuts execution without opening the app, including protected-key/locked-device failure behavior. Existing pocket-guide notification QA is retained history, not Assistant execution proof.
4. Update the privacy policy, support guidance, listing, App Privacy answers and review notes for optional task/guide transmission to OpenAI, local research/receipts, Keychain credentials, Calendar/notification access and opt-in Shortcuts. The existing public policy and label describe the earlier submitted build. No Assistant policy deployment or publication is claimed here. Web changes must follow the workspace's verified dual-deployment policy.
5. After the release owner accepts the source, QA and disclosures, create a new version/build as appropriate, inspect the signed package, upload and verify processing, prepare genuine current marketing images, and record the actual review submission. Keep the earlier iOS submission receipt intact and the Mac candidate held until its own evidence is complete.

There is no visionOS work. This documentation update performs no native or external actions and does not establish a new release.
