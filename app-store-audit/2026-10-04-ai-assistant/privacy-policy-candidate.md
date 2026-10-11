# Proposed How to Adult privacy policy

Unpublished draft prepared October 4, 2026 for the AI Assistant update. This file does not replace the public policy or the privacy answers for the earlier submitted iOS 1.0 build. It describes the current candidate implementation for iPhone, iPad and Mac. Release and publication remain separate steps.

Developer: Nathan Fennel.

## Your guides and saved plans

Saved guides, checked steps and guide reminder choices stay on your device. Guide searches run against the available library on your device. The app does not send those searches, bookmarks, checked steps or guide reminder dates to the guide content service.

Assistant plans also stay on your device. The app saves your task, generated actions, edits, checklists, shopping lists, research answers, source links, action status and scheduling receipts in its local plan library. A scheduling receipt identifies an item created through the operating system. It is not proof that you completed the task or made a purchase. Saved plans and guide progress have no app-managed cloud sync. Device backups may include local app files under your system backup settings.

## Choosing an AI

The Assistant offers on-device Apple Intelligence where available and an optional OpenAI API connection. You choose the connection in Assistant settings. A saved task is sent for AI processing when you ask the Assistant to make a plan or invoke the app's Make a life plan action in Shortcuts.

On-device generation uses Apple's on-device Foundation Models model. The app processes the task and selected guide context on your device for that generation. It requires iOS or macOS 26, supported hardware and an available Apple Intelligence model. The app does not silently switch an unavailable on-device request to OpenAI. Apple documents this model in [SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel).

OpenAI generation is optional. Connecting requires you to enter your own OpenAI API key. Requests go directly from the app to OpenAI, authenticated to your API account. When you ask for a plan using OpenAI, the request includes your task, the current time and time zone, excerpts of the selected guide if there is one, and researched source material used for that plan. The app does not attach your entire saved-plan library, guide-progress library, contacts or existing calendar events. OpenAI receives ordinary connection metadata needed to provide its service as well as the request content. API usage is billed to your API account; this connection does not use a ChatGPT subscription or provide ChatGPT sign-in.

The app saves the API key in this device's Keychain with synchronization disabled and access limited to when the device is unlocked. It does not put the key in a plan, share it with the guide content service or sync it between devices. The credential is sent to OpenAI to authorize requests. Test connection also makes an authenticated request to check access to the selected model.

Requests use `store: false`. This setting does not guarantee that OpenAI retains no data. OpenAI's current API policy says data is not used for model training unless the API customer opts in. Standard abuse-monitoring logs may include prompts and responses for up to 30 days, with stated legal and service-protection exceptions. Account controls and feature-specific policies can affect handling. The app does not establish Zero Data Retention approval for your account. See [OpenAI API data controls](https://developers.openai.com/api/docs/guides/your-data).

## Optional web research

Research before making a plan sends your task to OpenAI's web-search tool. Research with OpenAI sends an action's query. Find options with OpenAI sends the shopping query or title and its list items. These separate research actions use the saved API connection, including when your selected plan-generation connection is on device.

The app saves researched answers, cited source links and their check time locally. Source answers may be included in a subsequent requested plan. Research does not send your existing Calendar or Reminders contents and does not authorize a purchase or a native scheduling action. The provider's search service handles the query under its own applicable data practices.

## Permissions, reminders and calendar events

Guide reminders and the Assistant's default reminders use Apple's local notifications. The app asks for notification permission when you choose to schedule reminders or enable automatic reminder scheduling. Notification titles and details can appear on the lock screen under your system settings. Reminder sound is a separate choice. No remote push provider receives these reminder schedules.

Add to Calendar requests calendar permission to create an event in your system default calendar. The current interface uses write-only calendar access and does not read existing events, check for conflicts or offer a calendar or Apple Reminders list picker. It does not access your contacts. Calendar records may follow the sync and sharing settings of your chosen system calendar account.

Schedule reminders and Add calendar events are separate automatic-application settings, off by default. Enabling them first requests the applicable system permission. Only newly generated, dated actions are eligible for automatic application; enabling a setting does not run old plans. Turning automation off leaves previously scheduled items in place. You can change app notification and calendar access in system Settings.

Make a life plan can be invoked from Shortcuts using your configured AI connection and automation choices. You choose any personal automation schedule in Shortcuts. The app does not run an always-on AI service or install a hosted recurring-research job. Already scheduled local notifications can be delivered by the operating system while the app is closed.

## Guide updates and hosting

The bundled guide library works offline. Checking for updates requests a public catalog over HTTPS. The current catalog uses Vercel with an AWS content backend. Hosting providers process ordinary request metadata, including IP addresses, requested paths and operational identifiers, to serve requests and maintain security. This flow does not upload personal guide progress or Assistant plans.

The AWS content service has API request-access logging disabled. Its operational function logs can contain request identifiers, timing and generic failure types and have seven-day retention. Vercel also applies its hosting and security practices. The app does not promise that all provider records are anonymous or that every category of hosting record has the same retention period. The app includes no developer analytics or advertising SDK and does not use advertising identifiers, cross-app advertising tracking or data-broker sharing.

## External websites and sharing

Guide and research source links open the external websites you choose. Find items on the web opens Google with the shopping query; you may then visit merchant sites. Source links can also lead directly to a merchant. Those websites receive the requests you make and apply their own privacy practices. The app prepares shopping lists and research; you choose the seller and complete any purchase outside the app. It does not place orders, accept payment details or retrieve purchase receipts.

Sharing a guide, plan or shopping list uses the system share interface and sends its text to the destination you choose. Shared copies are governed by that destination. Contact messages you choose to send through the developer's contact page are handled by that contact service.

## Keeping and removing data

You can unsave guides, uncheck steps and remove guide reminders in the app. You can delete saved Assistant plans. Deleting a plan removes its local research and execution history, but leaves events and reminders already created through the operating system in place. You can delete created events in Calendar and manage app notification access in system Settings. Deleting an Assistant plan does not cancel its scheduled app alerts. Switching off automation also leaves those existing items in place.

Disconnect OpenAI removes the saved API key and resets the connection choice. It does not delete saved plans, native calendar items or scheduled notifications. Disconnecting cannot delete provider records retained under OpenAI's policy. You can manage or revoke the credential through your OpenAI account separately. Local app files remain until removed through the app or operating system. Device backups, system calendar records, provider records and copies you shared have separate retention and removal controls.

## Contact

For privacy questions, [contact Nathan Fennel](https://nathanfennel.com/contact). See [How to Adult support](https://nathanfennel.com/how-to-adult/support.html). The policy must be updated when the released app's data practices change.

## Draft review notes

This draft uses the current native source and the existing catalog privacy evidence. It does not report a fresh live OpenAI call, account-retention verification, website deployment or App Store privacy publication. The accompanying [privacy disclosure candidate](privacy-disclosure-candidate.json) records the proposed data-category choices and their limits. Calendar destination and Apple Reminders export support inside the executor are not exposed by the current interface and are not presented above as available integrations.
