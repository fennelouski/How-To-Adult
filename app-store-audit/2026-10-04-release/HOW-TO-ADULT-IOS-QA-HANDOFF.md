# How to Adult bounded iOS QA handoff

The original Release 1.0 (1) app passed the final real reminder delivery and tap-route method: **1 processed, 1 passed, 0 failed**. On October 4, the native DatePicker selected 2:35 PM in Europe/Amsterdam (12:35 UTC), sound was genuinely disabled through its native switch, and Save was tapped once with 250.87 seconds remaining. The app showed a saved future reminder, returned to Home, and entered the background. At 12:35 UTC, SpringBoard displayed its genuine laundry reminder banner. Tapping that observed banner opened the foreground app directly to “Wash a load of laundry.”

No shipping source changed. All 35 frozen native inputs and all 45 original Release app files match the held proofs; the executable remains `d7f1b727171bbc1cca494056ff608689cd9be26a8fa9bc39936f14fea59cc7db`. Only the isolated test driver changed. The owned Phone `1E5F4647-2BA3-4F26-8E75-9803F528D1BA` is finally Shutdown, restored to light/large. Host production preferences stayed unchanged. The serialized slot was released after shutdown and sequential xcresult exports.

## Receipts

- `ios-completion-final-handoff.json`: exact per-round counts and preserved failures.
- `ios-real-sound-r9-visual-observation.json`: all 15 individually inspected native PNG hashes, exact AX and metadata, source/app guards and bounded limitations.
- `ios-real-sound-r9-summary.json`: processed result, 1/1 pass.
- `ios-real-sound-r9-runtime-receipt.json`: actual commands, traits, final Shutdown and before/after guards.
- `ios-real-sound-r9-build-receipt.json`: matching runner with the original exact Release app.

## Actual native proof

- Banner PNG: `ios-real-sound-r9-attachments/9CC97C4B-2619-46DC-AFBA-A8CD1D4DF891.png`.
- Full SpringBoard AX: `ios-real-sound-r9-attachments/BED1F360-195B-4BF3-BBEF-776908AD9255.txt`.
- Observed own banner target: `ios-real-sound-r9-attachments/D8C2D20A-D3AD-464F-9C84-A077D76B96D0.txt`.
- Routed reader PNG: `ios-real-sound-r9-attachments/5C690FD6-61CB-420C-A2A3-36DB76A37583.png`.
- Full routed reader AX: `ios-real-sound-r9-attachments/1406FFD8-58A8-4EFE-AFC4-809B2F6509EA.txt`.

## Scope and retained failures

The original dark/largest method passed 1/1. Actual ShareLink chooser open/dismiss and real notification denial were observed in r3, whose final assertion remained failed; r4 separately passed denied-alert recovery 1/1. Phase B passed actual own-app Settings permission recovery and native picker expansion/Cancel 1/1 in r6. The final phase C passed scheduling/delivery/tap 1/1 in r9. Every initial and intermediate driver failure remains in its original summary and attachment directory, including Share versus Share…, close-button lookup, alert recovery, Settings routing, spoken minute selection, and the outer sound-row tap.

These are native Simulator checks. They do not establish physical-device sound/haptic feel, every notification display mode, new iPad notification behavior, or Mac functionality. The current dark/largest capture labelled “13-sources” actually shows lower guide steps; no Sources-viewport or link-tap claim comes from it. Earlier Phone13/13 and Pad13/13 remain separate historical proofs. The intermediate r9 minute-wheel PNG is transitional; stable selected-time and pre-Save screenshots establish the final value. After expiry, cleanup found no still-future native Remove control and cancelled the editor; expired/delivered private-QA evidence was preserved.

Root retains final visual acceptance, Apple review submission, web deployment and held Mac QA decisions. This agent performed no ASC, web, commit or provider actions.
