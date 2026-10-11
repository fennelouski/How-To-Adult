# Assistant implementation and verification

The new source puts the assistant in a dedicated **Assistant** tab on iPhone and an Assistant sidebar destination on iPad and Mac. Guides can hand off their context through “Help me do this.” Saved plans contain separate, editable reminder, calendar, research, shopping and checklist cards with distinct colors and icons.

On supported devices, Apple Intelligence makes plans locally. Optional OpenAI API-key support implements structured plans and cited web research; keys stay outside saved files in the device's Keychain and authenticate direct requests to OpenAI. ChatGPT access approval is pending, so there is no ChatGPT sign-in control or subscription-backed inference in this candidate. Shopping prepares lists and researches options; it does not place orders.

Reminder/calendar automation is off initially. New plans can apply complete future schedules after the user opts in and grants permission. Writes save a running state before execution and retain a real service receipt afterward; uncertain writes need review. “Make a life plan” is available as an App Intent for user-configured Shortcuts. This is not a hosted background agent.

## Actual verification on October 4, 2026

| Check | Result | Evidence |
| --- | --- | --- |
| Final iOS build for testing | Exit 0 | [Build log](verification/ios-build-r6.log) |
| Final iPhone unit tests | 76 passed, 1 intentionally skipped live-catalog test, 0 failures | [Actual summary](verification/phone-final-test-summary.json) |
| Final iPhone private UI flow | 1 passed | [Screenshots, native trees and bounds](phone-final/manifest.json) |
| Final iPad private UI flow | 1 passed | [Screenshots, native trees and bounds](ipad-final/manifest.json) |
| Final macOS Release compile | Exit 0; unsigned build, app not launched | [Build log](verification/mac-release-final.log) |
| Real on-device planning | Apple model available; returned one pending checklist with three concrete desk-tidying steps | [Actual output](verification/local-probe-r2.log) |
| Source inventory | All 57 recorded inputs still match | [Input hashes](candidate-native-inputs.json) |
| Owned device cleanup | Both private test devices shut down | [Cleanup record](verification/owned-device-cleanup.json) |

Private UI tests checked the exact session UUID before interaction. They exercised the task composer, selecting a saved plan, the disabled scheduling control, opening/closing settings and returning to a new task. They used fresh devices, UUID-only storage and preferences, with AI, remote catalog updates, ordinary Keychain and scheduling disabled. Root inspected the captured layouts. These captures qualify the private preview flow; they are not App Store marketing images or proof of live native writes.

The actual model probe called the current AI service in a standalone executable. It did not initialize the normal app store or shared runtime, read credentials, save a plan or write Calendar/notifications. The initial model answer described making a checklist rather than tidying; its output is preserved alongside the improved prompt's useful result. Mocked provider/action tests prove request shapes and state transitions, not live provider access or OS delivery. Earlier malformed-key and private-marker test failures remain recorded, with their fixes and successful reruns.

## Release state and remaining verification

This candidate is **unshipped working source**. There was no new version bump, archive, upload, submission, commit, website deployment or privacy publication. The existing iOS **1.0 (1)** guide app is Waiting for Review according to its [saved Apple submission receipt](../2026-10-04-release/ios-submission-receipt.json). The older Mac candidate remains unsubmitted. That earlier build does not contain the Assistant.

Live OpenAI model access and web-search citation offsets, actual assistant Calendar/notification receipts, cold-start taps, closed-app Shortcuts, Mac app UI, and broader accessibility/minimum-OS coverage still need release verification. The new privacy manifest is updated; the [policy draft](privacy-policy-candidate.md) and [disclosure draft](privacy-disclosure-candidate.json) have not been published. A new release must finish those checks and disclosures, prepare genuine current marketing images and record the signed package and actual Apple submission. See [release readiness](release-readiness.md).

No visionOS work was performed. Simulator.app was not opened, and other tasks' devices and app data were left alone. The full machine-readable record is [implementation-verification.json](implementation-verification.json).
