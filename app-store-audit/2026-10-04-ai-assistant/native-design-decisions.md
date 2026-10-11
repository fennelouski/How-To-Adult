# Assistant interface decisions

The user chose a dedicated Assistant tab on 2026-10-04. Guides retain the app's pocket-library identity and gain a prominent “Help me do this” action, which carries that guide's instructions, jurisdiction, cautions and sources into the task.

The assistant extends the existing marine accent, serif headings, native semantic surfaces and readable 760-point content column. It presents a task first, then a saved plan. Four short, illustrated examples give people something to try without onboarding prose. Phone controls wrap within safe areas; iPad and Mac keep native sidebar navigation and a separate plan list. Labels use their natural height, with padding between text and card edges.

Actions have explicit visual roles: a bell for reminders, a calendar for events, a magnifier for research, a basket for shopping and a checklist for steps. Each card names its action, shows its date/recurrence or items, and offers an edit pencil before execution. Native scheduling returns a real receipt. Local preparation uses distinct completion labels, so preparing a shopping list never appears as purchasing an order.

Routine automation is off initially. Enabling a category requests its OS permission before saving the preference, applies only to newly generated plans and leaves older plans for deliberate review. Nullable dates stay visibly unset until the person chooses a time. Interrupted or uncertain writes need review before retrying.

OpenAI is named on cloud research buttons and in connection settings. Model/API billing controls are behind the connection; keys use a secure entry field and are cleared from view state after saving or leaving the sheet. On-device planning is offered only when Apple reports its model available, with an explicit optional API connection for other supported devices. ChatGPT-plan access remains absent from shipping controls while approval and native callback support are pending.

Research keeps original sourced answers and visible clickable citations from actual API annotations. Each research action retains its own answer; initial research used to make a plan remains separate. Generated links outside verified annotation provenance lose their active-link styling. Shopping research finds source-backed options; purchases remain at the seller's checkout.

Saved plans can be shared and deleted. Deletion explicitly warns that items already written to Calendar or scheduled reminders remain in those services. Shortcuts exposes “Make a life plan” so people can choose when to invoke AI; notification delivery itself does not run AI. There is no app-owned always-on agent or autonomous merchant integration in this version.

Private QA uses a fresh UUID directory and preference suite, no normal library/Keychain, no remote catalog and no native scheduling. Its sample plan is labeled as a private preview. A blank unit-test host branches before ordinary app state is constructed. No visionOS work is included.
