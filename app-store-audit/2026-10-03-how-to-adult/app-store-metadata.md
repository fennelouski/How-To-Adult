# How to Adult App Store release details

Current native source: `ca8edc4e786d25504b06fa177468f42adde376fd`. Both signed platform packages have uploaded successfully. App Store Connect has processed and selected both platform 1.0 build 1 packages; both listings and 20 iPhone/iPad marketing images are saved. Neither platform is submitted for review yet. The completed privacy draft is awaiting the owner's confirmation of Apple's final publishing agreement.

[Live browser observations](asc-publication-progress.json), [listing fields](asc-listing-content.json) and [release checklist](release-checklist.json) are the current authority. The earlier offline-only draft is preserved in [historical preparation](app-store-metadata-offline-preparation-history.md).

| Field | Saved or verified value |
| --- | --- |
| Name | How to Adult: Pocket Guide; the shorter name was already taken |
| App ID / SKU | 6818756061 / how-to-adult-2026 |
| Bundle / team | com.nathanfennel.How-To-Adult / EJLR2RPSV2 |
| Subtitle | Your guide to everyday life |
| Categories | Lifestyle; Reference |
| Version / build | 1.0 / 1 |
| Platforms | iPhone and iPad 17+; native macOS 14+ |
| Language | English (United States) |
| Age rating | 13+, with Apple's regional variations |
| Price / availability | Free in all 175 offered storefronts; future storefronts enabled |
| Privacy | https://nathanfennel.com/how-to-adult/privacy.html |
| Support | https://nathanfennel.com/how-to-adult/support.html |
| Content rights | Original guides; no embedded third-party reader or media |
| License | Apple's Standard License Agreement |

The current description, keywords, promotional text, copyright, reviewer notes and owner-provided reviewer contact are saved for both platform versions. The exact copy is retained in `asc-listing-content.json`; Mac screenshots and final review validation remain pending.

The app bundles 56 original guides across seven topics and 224 practical steps. It reads the live editorial catalog over HTTPS and keeps the last valid library for offline use. Bookmarks, checked steps, reminders and search queries remain local; there is no personal-device sync, account, ads, purchases, remote push service or daily content-generation job. Source references open in the system browser.

The saved privacy draft discloses Other Diagnostic Data for App Functionality, linked to the user and not used for tracking. This conservatively covers retained hosting request metadata while IP anonymization is unverified. It does not claim that bookmarks, progress, reminders or local searches are uploaded. The final Publish action is pending owner confirmation, so no published label is asserted.

Both exported bundles contain `ITSAppUsesNonExemptEncryption=false`. The native app uses system HTTPS and SHA256 text fingerprints; it includes no proprietary encryption or third-party runtime crypto library. Package inspection and transport receipts are separate evidence from Apple processing or review status.

The iPhone 18.6 and iPad 26.5 current-source runs each passed 11 model tests and two UI flows, including actual live catalog decoding. Dark/large-text capture labels did not match rendered traits, so those captures were excluded from marketing and those visual checks remain pending. Notification delivery/tap and permission-denied recovery also remain pending. No installed iOS 17 runtime was available for a minimum-runtime smoke check.

The original signed Mac app is waiting on an owner-handled container consent. Automatic approval review rejected native automation access to that system dialog; no bypass was used. Mac native capture, gallery and final review checks remain incomplete; its metadata and processed build selection are saved. No visionOS work is authorized.
