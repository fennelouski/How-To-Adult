# How to Adult App Store draft

Originally prepared on 2026-10-03 for the offline package freeze `ab95cedbe7401da1f11f52e5befeafbc0b04848d`. Backend and website evidence below has been updated after live deployment. The new native catalog configuration at `00b817d` needs separate tests, packages and privacy assessment. Nothing in this document has been entered, saved or published in App Store Connect. Authentication is blocked and the existing app record is unknown. Local iPhone/iPad tests, signed package inspection and scoped phone/tablet gallery review are complete. The remaining verification and submission work is listed below.

## App identity

| Field | Draft or verified local value |
| --- | --- |
| Name | How to Adult |
| Subtitle | Your guide to everyday life |
| Listing language | English, United States |
| Version | 1.0 |
| Build | 1 |
| Bundle ID | `com.nathanfennel.How-To-Adult` |
| Development team | `EJLR2RPSV2` |
| Platforms | iOS/iPadOS 17 or later; native macOS 14 or later |
| Primary category | Lifestyle, proposed; matches the local Mac category |
| Secondary category | Reference, proposed if offered |
| Copyright | 2026 Nathan Fennel, proposed |
| App Store ID and SKU | Unknown; inspect the existing record before creating anything |
| Privacy policy URL | `https://nathanfennel.com/how-to-adult/privacy.html`, publicly verified from website revision `5c00d3f8ddbc48fa62f8504c527128a0ae8fa75b` |
| Support URL | `https://nathanfennel.com/how-to-adult/support.html`, publicly verified from website revision `5c00d3f8ddbc48fa62f8504c527128a0ae8fa75b` |

No visionOS build or submission is planned. The original Objective-C prototype remains preserved and excluded from the modern targets.

## Promotional text

Laundry, cooking, money, work and the everyday things that come up. Find clear steps, save useful guides and set a reminder for later.

## Description

Some things are easier once you have a starting point.

How to Adult is a pocket guide to everyday life, with 56 guides across Home, Food, Money, Work, Wellbeing, People and Everyday. Find a guide for the thing in front of you, then work through it one step at a time.

Wash a load of laundry. Cook a simple meal. Make a first budget. Understand your 401k. Check your car. Settle into a new room. Make plans with a friend.

Each guide breaks the task into clear steps, with practical supplies, cautions and links to sources where needed. Guides that depend on United States rules say so.

- Search the included library without an internet connection.
- Check off steps as you go.
- Save useful guides for another day.
- Pick a date, time and sound preference for a local reminder.
- Share a guide through your device's share menu.

Use the native app on iPhone, iPad or Mac. Your saved guides, progress and reminders stay on the device where you create them.

No account, ads, subscription or in-app purchases.

## Keywords

```text
adulting,laundry,cooking,budget,habits,home,maintenance,friendship,taxes,checklist,life skills
```

All fields above fit their App Store character limits. These are draft values, not evidence that Apple accepted the fields.

## Pricing and availability

Set the app to free in all eligible countries and regions. Include newly available storefronts if the live App Store Connect controls offer that setting. The same intent applies to both platforms. There are no in-app purchases, subscriptions or ads in this build. Store price, storefront coverage and any territory exceptions are unverified.

The library is in English. General household and everyday guides can be used internationally; guides about United States tax, retirement and other local rules identify their jurisdiction. Broad availability does not imply localized advice or translated content.

## App Review notes

No account or demo credentials are required. All 56 starter guides are bundled and can be read without an internet connection.

1. Open the app and choose a topic or search the library.
2. Open a guide, check a step and save the guide. Saved guides and progress persist locally.
3. Open the guide's reminder control, choose a future date and time, choose whether to play sound, then save. Notification permission is requested at that point. Declining permission does not block reading or saving guides.
4. Open the Sources section on a sourced guide to inspect references. United States-specific guides display their scope. Sharing uses the system share menu.

The iPhone, iPad and Mac versions use the same bundled content. Personal library data does not sync between devices. The editorial backend is live and its public readers were verified on both hosts. The new native configuration points to the verified Vercel catalog; native integration checks and replacement packages are still required. The earlier inspected packages remain offline-only. There are no remote push notifications, ads, purchases or subscriptions.

These notes describe the implemented reminder flow. Notification delivery, notification taps and permission-denial behavior still need runtime verification. Minimum-OS runtime checks also remain pending.

Reviewer contact details and the age-rating questionnaire still need the release owner's verified entries. Wellness and mental-health guidance should be checked against the actual age-rating questions. No age rating or submitted compliance declaration is asserted here.

## Encryption declaration recommendation

Recommend `ITSAppUsesNonExemptEncryption = false` for both native platforms. The current source uses Apple's `URLSession` for HTTPS and `CryptoKit.SHA256.hash` to fingerprint step text. It includes no custom encrypted storage, proprietary encryption or third-party runtime crypto library. SHA256 is a hashing operation, not encrypted storage. This assessment is based on the inspected native code, not the backend's editorial signing client. [Apple's SHA256 API](https://developer.apple.com/documentation/cryptokit/sha256).

Apple says the false value covers no encryption or only exempt encryption and identifies system HTTPS through `URLSession` as ordinarily exempt. The key is now present with value `false` in both final exported app bundles and was verified in [final package inspection](final-package-inspection-contrast-final.json) for the frozen revision. No encryption documentation or compliance code has been submitted. [Apple's encryption export guidance](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations), [the plist key definition](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption).

## Proposed app privacy label

Historical proposal for the earlier offline packages: **Data Not Collected**. This does not apply automatically to the new remote-catalog configuration and was never published.

Bookmarks, checked steps and reminders stay in the app container. Search operates on the local catalog. Local notifications use Apple's system framework. `AdultCatalogURL` is absent, so the app makes no automatic catalog requests. There is no account, device-token registration, private-content upload or third-party analytics/ad SDK. User-chosen source links open in the system browser; the app does not embed a web reader or record browsing activity.

Apple excludes on-device processing from collection. Its definition concerns off-device data accessible beyond servicing a real-time request. This supported the earlier offline package proposal. Inspection of both final exports confirmed `AdultCatalogURL` is absent; the account owner's publishing attestation and the App Store privacy responses remain pending. [Apple's app privacy definitions](https://developer.apple.com/app-store/app-privacy-details/).

### Newly configured remote catalog

The API only serves public editorial content; it does not receive bookmarks, steps, reminders or local search queries. Its template disables API Gateway access logs. Lambda CloudWatch operational logs have a seven-day retention setting and may include request IDs, runtime and memory use. Handler failure logs contain a generic message and exception class. The seven-day value is **not a verified IP-retention promise**.

AWS and Vercel process IP addresses and requested paths for ordinary hosting and security. The actual Vercel account uses Pro, its authenticated API reports Observability Plus is disabled, and current official runtime-log documentation specifies one day for normal Pro logs. No configured drains were found. This does not prove all provider security retention or IP anonymization; IP hiding settings were absent and a zero-row log query is not evidence of no collection. See [the implemented backend logging policy](../../BACKEND.md). Check actual provider settings and retention before configuring `AdultCatalogURL`, then update the public policy and label to match the live app.

Retained request metadata can require disclosure even without analytics. A user option alone does not satisfy Apple's optional-disclosure criteria. Classify retained IP data by its actual use; Apple names location, device ID and diagnostics as possible categories. Check identity linkage rather than assuming data is unlinked. Metadata immediately discarded after servicing the request falls outside Apple's collection definition. [Apple's app privacy definitions](https://developer.apple.com/app-store/app-privacy-details/).

The App Store label must describe the distributed version. The privacy policy must be publicly accessible for both platforms. Publishing requires the account owner's accuracy and compliance agreement; no Publish action has been performed or authorized for this app's label. [Manage app privacy in App Store Connect](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/).

## Completed local evidence

The native freeze is `ab95cedbe7401da1f11f52e5befeafbc0b04848d`, with 35 inputs and canonical SHA-256 `45c558b118e8813b7bad781f7e24538a395cff2ccffb8fd14b4f797f739f8c6e`. [Native input record](native-inputs-contrast-final.json).

- iPhone and iPad each passed 10 model and two UI tests. Each produced 13 genuine native captures, including dark appearance and accessibility text size. [iPhone manifest](raw/iphone-contrast-final/manifest.json), [iPad manifest](raw/ipad-contrast-final/manifest.json).
- Signed iOS and Mac archives and exports were inspected against this exact freeze. Bundled content, icons, signatures, artifact hashes and `ITSAppUsesNonExemptEncryption = false` were verified. No package was uploaded. [Release record](release-verification-contrast-final.json), [package inspection](final-package-inspection-contrast-final.json).
- All 26 phone/tablet captures and the scoped 20-image gallery passed independent visual review. There are ten images per device, using genuine native captures with centered headlines, upright heroes and outward supporting fans. No assets were uploaded. [Finish review](design-finish-review.md), [gallery review](marketing/composed-contrast-final/review-status.json), [provenance](marketing/composed-contrast-final/marketing-provenance.json).
- The backend passed 49 checks and initial/repeat live dual deployment at source `7b6a116dc1e10ce002d3293be68c347d0939e365`. AWS and Vercel serve the same 56-guide publication. The new native source configures the verified catalog, with integration/package checks pending. [Deployment receipt](../../backend/deployment-record.json).
- The privacy/support pages are live and byte-verified on AWS and the production Vercel domain from website source `5c00d3f8ddbc48fa62f8504c527128a0ae8fa75b`. The privacy page remains unlisted and publicly accessible. [Website receipt](website-live-verification.json).

## Release evidence still required

- Original signed Mac bundle runtime verification, 13 Mac captures and ten Mac marketing images after the owner handles the existing-container sharing consent. The overall finish verdict is `recapture` for missing Mac evidence; no Mac runtime pass or product defect is inferred.
- Runtime checks for notification delivery, notification taps, permission denial and the declared minimum OS versions.
- Native refresh/last-good-cache checks and replacement signed packages for the newly configured live catalog. Hosting metadata must be included in the reassessed privacy responses; the earlier offline Data Not Collected proposal is historical. [Provider privacy evidence](../../backend/provider-privacy-verification.json).
- Authenticated inspection of the existing App Store record, saved metadata, zero pricing and eligible storefront availability.
- Build upload and processing, final privacy/age/compliance answers, build selection and actual App Review submission.

Record completed work in `release-checklist.json`. A local build, prepared listing or Git push is not evidence of an upload, website deployment or review submission.
