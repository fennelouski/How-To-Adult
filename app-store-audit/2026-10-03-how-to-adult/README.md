# How to Adult release evidence

The current native app and live publishing backend are operational. Both signed platform builds uploaded successfully. Both 1.0 build 1 packages are processed and selected, both platform listings are saved, and all 20 ordered iPhone/iPad marketing images are accepted. **Neither platform has been submitted for review yet.** The completed privacy draft awaits owner confirmation at Apple's final Publish dialog.

Current native revision: `ca8edc4e786d25504b06fa177468f42adde376fd`. Its 35 native inputs have canonical SHA256 `cd9e1ee587f615268ee1157e9fb9693d3078762059a06dae11bcf48e06abb9df`. Documentation changes do not alter those inputs. Earlier offline captures/packages are historical evidence.

| Scope | Current verified result | Evidence |
| --- | --- | --- |
| Starter library | 56 original guides, seven topics, 224 steps | `Content/catalog.json`, `CONTENT-EDITORIAL.md` |
| iPhone iOS 18.6 | 11 model tests and two UI flows passed; 13 native captures | [Tests](live-iphone-test-summary.json), `raw/iphone-live-final/manifest.json` |
| iPad iOS 26.5 | 11 model tests and two UI flows passed; 13 native captures | [Tests](live-ipad-test-summary.json), `raw/ipad-live-final/manifest.json` |
| Signed packages and uploads | iOS and universal Mac export/signature inspection and actual Apple transport success | [Package inspection](final-package-inspection-live-privacy-final.json), [upload receipts](app-store-upload-live-privacy-final.json) |
| Marketing | Ten images per iPhone/iPad gallery; server order verified after reload | [Provenance](marketing/composed-live-privacy-final/marketing-provenance.json), [ASC observations](asc-publication-progress.json) |
| iOS and Mac builds | Apple processing complete and selected 1.0(1) on both platforms | `asc-publication-progress.json` |
| Store details | Categories, age rating and original-content declaration saved; free in all 175 offered storefronts, future storefronts enabled | `asc-publication-progress.json` |
| Public catalog | Both configured public readers returned matching bytes and all 56 guides | `backend/deployment-record.json`, shared workspace deployment audit |
| Privacy/support pages | Public HTTPS pages verified; unlisted and noindex; AWS/Vercel deployment recorded | [Live page checks](website-live-verification.json) |

The current package/configuration reads published guide updates and retains valid offline content. Personal bookmarks, progress, local reminders and search queries stay on the device. No daily article-generation loop is scheduled. Backend deployments use one AWS publishing owner with a Vercel reader relay; the shared deployment audit records a later remote-editor release separately from the native source.

[Release checklist](release-checklist.json) is the authority for remaining actions. The privacy draft is complete but unpublished. Submit iOS only after outstanding native checks, final validation and required owner confirmations; record Apple's actual submission status.

Dark/large-text rendered verification, notification delivery/tap and denial recovery remain pending. Mislabelled dark/large captures are excluded from marketing. iOS 17 is the deployment minimum; no installed iOS 17 runtime was available.

The Mac transport upload, processing, selection and listing are complete. Final native QA and ten marketing images remain pending. The original signed Mac app awaits owner container consent. Automatic approval review rejected automation access to that system prompt, so the owner must handle it. No alternate identity, container deletion or security bypass was used.

No visionOS build, Simulator or submission was used. No working production domain was cut over to AWS merely because of the policy date.
