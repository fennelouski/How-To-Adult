# Shared app design guidelines

Apply these principles when designing or improving any app in this workspace. Keep each app's purpose and identity clear; shared quality does not require identical palettes or layouts.

## Layout and space

- Adapt the composition to the available window size. On iPad and large Mac windows, center or balance the main working area with sensible content widths instead of stretching controls or leaving everything against the leading edge.
- Use wider space for useful columns, previews or related controls when they help the task. Preserve readable line lengths and comfortable spacing. Center the composition, not every text label.
- Give each button or selectable row one visible container. Do not layer a custom rounded background inside a native selection highlight, or style a control so it looks like a button inside another button.
- Keep native sidebars, navigation and scrolling where they fit the platform. Check narrow windows, split views and large windows as well as phone layouts.

## Focus and language

- Make the main content and next action obvious through size, spacing, color and meaningful symbols. Keep secondary actions visibly secondary.
- Keep settings focused on the selected section. When there are several sections, use a section sidebar and detail pane on wide screens, with native navigation on compact screens. Show appearance and output changes through real previews where useful, and retain each app's identity.
- Use minimal words: concise labels and short explanations where the user needs them. Do not remove necessary permission, error or destructive-action information.
- Use color and symbols together with readable labels or accessibility names. Color alone must not carry meaning.

## Appearance and motion

- Use restrained depth and background motion to support focus. Decoration must not compete with content or controls.
- Respect Reduce Motion with a calm, usable alternative. Avoid motion that interferes with reading or interaction.
- Reuse the user's approved Fendoku icons and themes when they suit the app, rather than using emoji as interface artwork. Choose assets deliberately; each app can retain its own palette and character.

## Native behavior and accessibility

- Preserve familiar native navigation, keyboard behavior and platform conventions.
- Appearance changes must retain the active settings section and edited choices. Saved options must show their selected state after relaunch.
- Every actual app setting must persist until the user changes or explicitly resets it. Use the app's existing preference store or model. Settings must not reset when a view closes or the app relaunches. Preserve explicit Save and Cancel behavior for drafts and item editors.
- Support Dynamic Type with layouts that reflow and remain usable at accessibility sizes. Avoid clipping important text or hiding actions as text grows.
- Provide clear accessibility labels, logical focus order, sufficient contrast and comfortable interaction targets. Verify light and dark appearances and increased accessibility settings in the actual interface when runtime access is available.

## App Store presentation

- Use composed marketing images for every gallery image, with a stylized background and short, punchy marketing text centered at the top. Make the first three images communicate the app's main value at a glance.
- Fill Apple's allowed image count for every supported device gallery. Rotate three to four stylistically distinct backgrounds so adjacent images never use the same background, and vary the capture composition while preserving genuine app pixels and accurate feature claims.
- Place one to three real app captures in each image. Center the upright hero in front; in portrait, it may extend beyond the bottom edge. Angle supporting captures outward behind it: the left capture counterclockwise (negative angle) and the right capture clockwise (positive angle), so they fan out.
- Use each platform's actual native screenshots; never substitute another platform's UI. Verify every shown feature and claim against the submitted build and match Apple's required dimensions. Preserve accurate source-capture provenance rather than redrawing the app interface.
- Check the images actually uploaded in App Store Connect before submission. A matching filename or an accurate raw screenshot does not establish that the gallery presents the app well.
- For galleries showing geographic maps, use each supported App Store metadata language/locale as the owner's approved proxy for a representative country. Use recognizable public places in that country and translate the short marketing headline. Prepare regional captures for all available metadata locales; do not reuse the developer's current location across them.
- Keep the map center, nearby results, place details and distance units consistent with the chosen region. Owner-specified places override defaults: If This Then Lunch's English (U.S.) gallery centers on Azusa Pacific University, 901 E Alosta Ave, Azusa, California. Dutch uses the Netherlands, French France, Portuguese (Brazil) Brazil, Portuguese (Portugal) Portugal, English (Canada) Canada, German Germany, Italian Italy and Spanish (Mexico) Mexico.
- Capture the genuine native app in the chosen language/region when that interface is supported. If it is not supported, preserve the app's actual pixels and translate only the marketing headline; never paint translated controls over a capture or imply unsupported interface localization. Retain native map attribution and exact build/capture provenance.
- Record the metadata locale and intended country separately. Shared-language storefronts and device-language fallback mean localized galleries are a regional proxy, not a guarantee of distinct images for every country. Custom Product Pages are optional and are not required for this language-based approach.
