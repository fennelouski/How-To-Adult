# How To Adult assistant integration research

Researched 2026-10-04 against current official Apple and OpenAI documentation. This is a proposed design, not implemented or tested functionality. No source, build, account, credential, device or deployment changes were made.

Build one action executor shared by the native assistant, manual controls and App Intents. Models propose typed plans. App code validates dates, guide IDs, permissions and the user's automation rules, then records real outcomes. Start with guide-based plans, app reminders, optional Apple Reminders/calendar writes, cited research and shopping preparation. Keep the existing manual experience usable without AI.

## Existing native app

The project supports iOS 17 and macOS 14. `AdultStore.schedule` already requests notification permission, rejects dates less than 60 seconds away, limits upcoming guide reminders to 40, schedules a notification and reconciles persistence failures. Preserve this delivery and tap-route path. These reminders are app notifications, not records in Apple Reminders. The inspected Sources contain no FoundationModels, EventKit, App Intents or OpenAI integration. The Mac is sandboxed with network-client access but has no Calendar entitlement or EventKit usage descriptions.

Source snapshot: `Sources/AdultStore.swift` SHA256 `9b8966e17397f4b5d07666c6de8d18a27f767159e916e58ddf2eb07c0bf8a321`; project SHA256 `816f6d76f89ab479d1b9f48488696da86197672f9ea0dc1277ff419d7c9a82d4`.

## Apple Intelligence

Foundation Models' `SystemLanguageModel`, `LanguageModelSession` and `Tool` start at iOS/macOS 26. Compile-condition and availability-gate the implementation, then check actual model availability and locale support. Eligible hardware, enabled Apple Intelligence and downloaded models matter. Offer manual plans or a separately connected provider on older or unavailable systems. [SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)

Use `@Generable`/`@Guide` for an action plan with an enum action type, canonical guide ID, local date/time and time-zone identifier. Guided generation constrains structure; app validation must still reject invented guides, contradictory dates and unsupported actions. [Guided generation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation)

Register tools with the session. Useful tools read a guide or return selected research results; write tools pass through the executor. Tools can run concurrently and repeatedly, so serialize mutations and deduplicate action IDs. Tools do not grant OS permission. [Tool calling](https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling), [Tool](https://developer.apple.com/documentation/foundationmodels/tool)

Do not copy the newest examples into the 26 baseline blindly. Apple's documentation metadata places `GenerationOptions.ToolCallingMode` at 27.0; gate it separately. The proposed first implementation does not depend on it. [ToolCallingMode](https://developer.apple.com/documentation/foundationmodels/generationoptions/toolcallingmode-swift.struct)

## Calendar and reminders permissions

| Action | Supported permission contract |
| --- | --- |
| Show an app guide reminder | Existing UserNotifications authorization; no EventKit access |
| Let an iOS user edit/save a calendar event | `EKEventEditViewController` on iOS 17+ can save through system UI without app calendar access |
| Create calendar events directly | `requestWriteOnlyAccessToEvents()` |
| Read existing events, find free time or maintain existing events | `requestFullAccessToEvents()` |
| Create/read/update Apple Reminders | `requestFullAccessToReminders()`; there is no write-only reminders permission |

Write-only calendar access cannot read any events, including app-created events, and does not expose the user's calendar list. It cannot support conflict detection. EventKitUI's permission-free editor applies to iOS/iPadOS/Mac Catalyst, not a native Mac editor. [Accessing the event store](https://developer.apple.com/documentation/eventkit/accessing-the-event-store)

Add only the applicable modern usage keys: `NSCalendarsWriteOnlyAccessUsageDescription`, `NSCalendarsFullAccessUsageDescription`, `NSRemindersFullAccessUsageDescription`. Use the new authorization statuses/methods on the app's 17/14 minimums. Sandboxed Mac Calendar access needs `com.apple.security.personal-information.calendars`. Ask in context, handle denial/revocation, and do not send someone's full calendar to a cloud model by default. [Apple migration guidance](https://developer.apple.com/documentation/technotes/tn3152-migrating-to-the-latest-calendar-access-levels), [Sandbox access requirement](https://developer.apple.com/documentation/eventkit/accessing-the-event-store)

Implementation decision: persist `prepared`, `committing`, `completed` and `uncertain` action states plus external record identifiers. An interrupted write-only save cannot be verified by rereading EventKit. Do not retry an uncertain calendar write silently and create duplicates. Show that uncertainty or request an appropriate verification path.

## Automatic execution

Schedule known reminders when the person creates a plan or opts into a bounded recurring rule. The system can deliver pre-scheduled local notifications while the app is closed. Delivery does not execute arbitrary AI research or ordering code. Handle foreground notifications and preserve cancellation/tap routes. [Local notifications](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)

iOS background refresh is opportunistic. `earliestBeginDate` is a lower bound, not an execution appointment; this API is not a native macOS scheduler. Fresh research while all clients are closed needs a separately operated backend job and push delivery, with one active owner and its own provider billing. A sleeping or closed Mac is not that backend. [Background scheduling limit](https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate)

Expose concise App Intents such as Plan my week, Add guide reminder and Open my next task. Intents are invocation contracts, not timers. Use the older foreground behavior for 17/14 and gate `supportedModes` at 26. User-created Shortcuts time-of-day automation can invoke these actions. Do not claim the app can install personal automations automatically; Apple's documented flow is user-managed and device-specific. [App Intent runtime](https://developer.apple.com/documentation/appintents/appintent/supportedmodes), [Older runtime flag](https://developer.apple.com/documentation/appintents/appintent/openappwhenrun), [Time triggers](https://support.apple.com/guide/shortcuts/event-triggers-apd932ff833f/ios), [Personal automation](https://support.apple.com/guide/shortcuts/intro-to-personal-automation-apd690170742/ios)

## OpenAI research and actions

BYOK can use the public Responses API with function tools. Accept complete arguments, validate them locally, execute the authorized action, and return `function_call_output` with the original `call_id`. Carry prior output/reasoning items into the next stateless tool round. Use `strict: true`, every property required and `additionalProperties: false`; nullable fields represent optional values. Never execute partial streamed arguments. Store the user's key in Keychain and keep it separate from OAuth credentials. [Function calling](https://developers.openai.com/api/docs/guides/function-calling)

Disclose personal-data transfers to the selected AI provider and obtain explicit permission before transmission. Reassess the privacy policy and App Store privacy responses for the new data flow before releasing it. [App Review 5.1.2](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing)

Use the current `web_search` tool with a compatible model. A research-required request must request search and verify a search call occurred. Keep the returned `url_citation` annotations, including URL/title/text ranges, and show clickable inline citations. Record retrieval time and jurisdiction. For taxes, finance or health, prefer relevant official sources and distinguish sourced facts from generated interpretation. Research and merchant pages are untrusted data; they cannot authorize tool writes. [Web search and citations](https://developers.openai.com/api/docs/guides/tools-web-search)

Sign in with ChatGPT is a separate integration. Commercial/private access remains selected, and free distribution is not approval. The portfolio request receipt establishes submission, not access for this product. Establish actual approval or applicable open-source eligibility before enabling the connection. [Eligibility](https://developers.openai.com/siwc/quickstart)

The documented native flow uses an HTTP `127.0.0.1` loopback callback, exact per-attempt redirect URI, PKCE S256, state and OIDC nonce. A Mac implementation must test sandbox listener access and ID-token validation. These docs do not establish an approved iOS custom-scheme/HTTPS callback for How To Adult. Do not invent a relay or reuse browser session cookies. [Registration and callback](https://developers.openai.com/siwc/token-sharing-open-source/sign-in)

ChatGPT plan inference requires `store: false`, `stream: true` and array input/history. Function/custom tools use namespaces or `additional_tools`; ordinary BYOK request shapes are not interchangeable. Web search depends on model/workspace policy. Background requests, hosted MCP/connectors, native computer use, hosted file search and image generation are unsupported on this route. [Preview contract](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations)

Load the selected account's current model catalog; show `display_name` and send its `slug`. Treat only `response.completed` as success, including after partial output, and handle quota failures without silently switching to a paid API key. A user's connection must not become the credential for a shared article-generation backend. [Models, streaming and completion](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference)

## Shopping preparation and implementation gates

Prepare a list, compare sourced products, keep prices/timestamps and open a merchant checkout for review. None of these Apple/OpenAI APIs supplies a universal purchase account, payment authorization or merchant order API. Autonomous purchase execution would require a supported merchant integration, scoped user authorization, a spending/quantity/address policy, fresh quote, idempotent submission and real receipt. No such integration is established here. Do not label a draft or opened URL as an order.

Start implementation with the shared typed plan and durable action executor, then local planning and existing notifications, followed by EventKit and cited provider research. Before release, test denied/revoked permissions, DST/time zones, canceled/incomplete generation, repeated tool calls, uncertain external writes and real notification delivery/tap routing. Add private fixtures without reading ordinary calendars or credentials. The submitted 1.0 app and its existing QA receipts remain unchanged by this research.

Apple JavaScript-only documentation was also read through its public documentation JSON to verify symbol availability, notably 26.0 versus 27.0. No inference API or authentication endpoint was called.
