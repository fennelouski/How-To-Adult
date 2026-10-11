# How to Adult AI candidate: bounded source review

Reviewed 2026-10-04. This review read native source and existing attachment manifests. It made no production/test edits, builds, device launches, Keychain requests, permission requests, provider calls, deployments or Apple metadata changes. The only written artifact is this report. The candidate remains separate from the submitted iOS 1.0 (1) guide app.

No unresolved serious source issue was found in the reviewed corrections. This is a source verdict, not approval of a final compiled package or proof of live cloud/OS integrations.

## Resolved findings

- **Shared notification limit:** the budget now acquires its FIFO lock before the first asynchronous pending-request read and releases it after the entire read/add operation. A second writer cannot use a stale snapshot after the first writer finishes. Cancellation is checked before a queued writer reads and again before it writes. Stable-ID replacement remains allowed at the 60-request cap. Three injected concurrency tests were prepared separately; this reviewer did not execute them.
- **Private host isolation:** App checks for the private argument before selecting the blank automatic host. A valid UUID overrides the blank-host environment; malformed private arguments fail closed rather than initializing normal stores or Keychain. The AppIntent now rejects the same broad private-argument prefix before accessing the normal shared controller. The private marker includes the UUID and an accessibility identifier inside the Assistant scroll view, Settings Form and guide collection. It no longer reserves an external bottom safe-area strip.
- **Compact sheets:** the new Assistant Settings and action editor minimum window dimensions are scoped to macOS. iOS uses its offered sheet bounds and native Form scrolling. Source inspection alone does not establish all accessibility or landscape layouts.
- **Cold-start routing:** the normal App installs the single notification delegate during initialization, before the later view task. Guide, assistant-action and requested-presentation handlers use `initial: true`, allowing a value already received before view construction to be consumed. The private path does not install normal notification routing. Actual killed-app notification delivery/tap routing still needs its own runtime proof.
- **Locked credentials:** the key reader distinguishes a missing key from inaccessible credentials and shows an unlock-and-rerun message. Generation reaches the actual key read for OpenAI rather than masking that failure as unavailable Apple Intelligence. Device-only, when-unlocked Keychain protection remains intact.
- **Credential disclosure:** Settings now states that keys are not synced or included in plans and that they authenticate requests directly to OpenAI. It no longer makes the broad claim that credentials are never shared. OpenAI, task/guide transfer, optional search and separate API charges are named in the connection flow. No hidden paid-provider fallback or dependency on pending ChatGPT approval was found.

## Verified candidate privacy declarations

`Configuration/PrivacyInfo.xcprivacy` preserves the existing Other Diagnostic Data entry and adds Other User Content, Search History and User ID. All four entries are linked, used for App Functionality and not used for tracking. Tracking remains false with no tracking domains. The UserDefaults required-reason entry is `NSPrivacyAccessedAPICategoryUserDefaults` with `CA92.1`, consistent with this app's own provider/model/research preferences. These are the [documented Apple values](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype) and [app-only defaults reason](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons).

The data-flow interpretation is precise: freeform tasks and selected context go to the optional connected provider; explicit research/shopping queries represent in-app search; the API credential identifies the provider account, rather than a How to Adult account. Existing calendar contents, the entire guide-progress library and the entire saved-plan library are not sent by the reviewed generation context. Native writes and local storage do not themselves establish cloud collection of those entire libraries.

The candidate's public policy and App Store disclosures still need to reflect those optional transfers and saved research before a new AI release. This manifest change does not publish the policy or replace the submitted version's historical privacy record. `store: false` is not Zero Data Retention approval or a guarantee that all provider data disappears after 30 days. OpenAI's documented default abuse-monitoring retention and exceptions remain applicable to the connected account. [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data)

## Runtime and release limits

Root reports that private Phone and iPad UI flows passed. Their actual attachment manifests are retained at [phone-r5](phone-r5/manifest.json) and [ipad-r5](ipad-r5/manifest.json). This reviewer read those manifests, did not perform another visual/runtime audit, and does not claim that private fixtures prove live provider, calendar or reminder behavior. Root owns the final matching rebuild, source freeze, test outcomes and association of each runtime result with its compiled source.

On-device AI requires available Apple Intelligence on supported iOS/macOS 26 hardware. Actual connected OpenAI generation, current model compatibility, live web-search citations, locked/background Shortcut execution and live EventKit writes remain separate validation areas. Private QA deliberately disables scheduling and AI. Write-only calendar access cannot inspect conflicts or resolve an interrupted save by rereading events; uncertain outcomes require review. Optional chosen-calendar/Apple Reminders destinations exist in the executor but have no current Settings picker. User-run Shortcuts are invocation paths, not an always-on hosted AI scheduler.

Shopping can research sourced options, prepare/share lists and open external search. It has no autonomous merchant checkout, order placement, payment authority or purchase-receipt integration. ChatGPT sign-in access is requested but not approved or implemented here. Neither limitation should prevent the optional on-device/BYOK Assistant UI from functioning. No visionOS work was performed.

## Observed source hashes

These identify the files inspected in this review, not a substitute for root's complete native freeze.

| Path | SHA256 |
| --- | --- |
| `Sources/App.swift` | `cb4507e313542707171cc4efddc45350b62618270a221ce2225e38af005e43a3` |
| `Sources/AdultViews.swift` | `80853fd71f57d907fcce9121cdab4a41770ad32288e27ced446d1928e6979049` |
| `Sources/AdultStore.swift` | `008f7c0209f3da7419a9ce6223977f05831eb03770bea8fbc6c5157822b77045` |
| `Sources/AdultAIConnection.swift` | `e579da8868bc57ef0a0a5ef8e1ae6ddf41e6e05f3eeb5f0b9286d4ef510e0b71` |
| `Sources/AdultAssistantIntents.swift` | `aad2e1d0be3aee2e8c887529bb6c44d615590a71c1494d8dba761fa84170ac98` |
| `Sources/AdultAssistantViews.swift` | `9d6224946af4760df4ffe6d90b920f2badc952f5e6a179ab543611c929dbd2a2` |
| `Sources/AdultAssistantSettingsView.swift` | `ad30dc697702ad3ff78fb5b42026d308073cca808206d880bd4109b7baf172d3` |
| `Sources/AdultNotificationBudget.swift` | `c77bee42dcd1c5e372faa8f98c6469a1ceb820e783950e98c76a9b3ff56c296a` |
| `Configuration/PrivacyInfo.xcprivacy` | `64407d8a0815b81500ae4a24f62bf4659a2d4348838a29f958eeb560a3ca13e9` |
