---
name: GlabTouch
description: Mobile merge request triage for self-hosted GitLab
colors:
  indicator-blue: "#007AFF"
  verdict-green: "#34C759"
  alert-red: "#FF3B30"
  caution-amber: "#FF9500"
  manual-violet: "#AF52DE"
  schedule-teal: "#30B0C7"
  neutral-slate: "#8E8E93"
  ink: "#1C1C1E"
  caption-gray: "#8A8A8E"
  surface-grouped: "#F2F2F7"
  surface-card: "#FFFFFF"
  diff-addition: "#34C75920"
  diff-deletion: "#FF3B301F"
  diff-hunk: "#007AFF1A"
  diff-meta: "#8E8E9314"
typography:
  title:
    fontFamily: "SF Pro Text"
    fontSize: "17pt"
    fontWeight: 600
    lineHeight: 1.29
  body:
    fontFamily: "SF Pro Text"
    fontSize: "15pt"
    fontWeight: 400
    lineHeight: 1.33
  metadata:
    fontFamily: "SF Pro Text"
    fontSize: "12pt"
    fontWeight: 400
    lineHeight: 1.33
  tertiary:
    fontFamily: "SF Pro Text"
    fontSize: "11pt"
    fontWeight: 400
    lineHeight: 1.27
  mono:
    fontFamily: "SF Mono"
    fontSize: "12pt"
    fontWeight: 400
    lineHeight: 1.33
rounded:
  system: "10pt"
  badge: "6pt"
spacing:
  xs: "4pt"
  sm: "8pt"
  md: "12pt"
  lg: "16pt"
  xl: "24pt"
components:
  status-badge:
    backgroundColor: "{colors.indicator-blue}"
    textColor: "{colors.surface-card}"
    rounded: "{rounded.badge}"
    padding: "2pt 8pt"
  button-primary:
    backgroundColor: "{colors.indicator-blue}"
    textColor: "{colors.surface-card}"
    rounded: "{rounded.system}"
    padding: "8pt 16pt"
  button-destructive:
    backgroundColor: "{colors.alert-red}"
    textColor: "{colors.surface-card}"
    rounded: "{rounded.system}"
    padding: "8pt 16pt"
---

# Design System: GlabTouch

## 1. Overview

**Creative North Star: "The Field Notebook"**

GlabTouch is a pocket instrument for engineering review. The field notebook: carried everywhere, opened for a specific task, closed when the answer is found. Every screen serves one question: is this merge request safe to approve, is this pipeline healthy, what failed and why.

The interface defers to iOS platform conventions. SwiftUI system controls, semantic colors, and standard navigation patterns carry the interaction. Custom visual treatment is reserved for status communication, where the cost of misreading is real: pipeline health, approval state, diff severity. Everywhere else, the system font speaks, the system spacing breathes, and the tool disappears into the task.

GlabTouch rejects feature-client sprawl. It rejects marketing-page styling, decorative motion, playful status treatments, and custom controls that fight native iOS expectations. A reviewer glancing at their phone during a walk should get the answer in under three seconds.

**Key Characteristics:**
- Status legibility over visual flair
- One-handed triage optimized
- iOS-native hierarchy and spacing
- Destructive actions explicit and isolated
- Zero third-party visual dependencies

**Interaction Principles:**
- **Affordance clarity.** Interactive elements and static content must be instantly distinguishable. Tappable rows carry a disclosure chevron or navigation indicator; buttons use `.borderedProminent` or `.bordered` styling; static labels carry no tap affordance. If a user hesitates about whether something is tappable, the design has failed.
- **Navigate for depth, describe in place.** Content requiring more detail earns a navigation push (MR detail, pipeline detail, job trace). Content explainable in one line stays inline as a secondary description beneath the title, using Metadata or Tertiary typography. The threshold: if the supporting text exceeds two lines at the narrowest supported width, it belongs on a detail screen.
- **Attention through motion.** When server state demands the user's awareness (pipeline failure, approval required, new activity), a brief pulse or badge animation draws the eye. Motion is the attention channel; color and text are the comprehension channel. The two work together: motion says "look here," status color and label say "here is what happened."

## 2. Colors

A restrained palette where semantic color carries all the meaning. Neutrals are iOS system surfaces; accent colors appear exclusively as status indicators and primary actions.

### Primary

- **Indicator Blue** (#007AFF / SwiftUI `.blue`): Running pipelines, primary action buttons (approve), current selection, active tab indicator. The single accent color in the system. Its rarity is functional: blue means "actionable" or "in progress."

### Neutral

- **Ink** (#1C1C1E / SwiftUI `.primary`): Primary text. Titles, headings, body content.
- **Caption Gray** (#8A8A8E / SwiftUI `.secondary`): Metadata text. Author names, timestamps, MR IDs, branch labels.
- **Neutral Slate** (#8E8E93 / SwiftUI `.gray`): Canceled/skipped states, disabled controls, dividers.
- **Surface Grouped** (#F2F2F7 / SwiftUI `.systemGroupedBackground`): Root background for List-based screens.
- **Surface Card** (#FFFFFF / SwiftUI `.systemBackground`): Card/row surfaces within grouped lists.

### Semantic Status

- **Verdict Green** (#34C759 / SwiftUI `.green`): Success pipeline, approved MR, diff additions.
- **Alert Red** (#FF3B30 / SwiftUI `.red`): Failed pipeline, diff deletions, revoke action, error states.
- **Caution Amber** (#FF9500 / SwiftUI `.orange`): Pending, waiting, preparing, canceling states.
- **Manual Violet** (#AF52DE / SwiftUI `.purple`): Manual pipeline jobs requiring explicit trigger.
- **Schedule Teal** (#30B0C7 / SwiftUI `.teal`): Scheduled pipeline jobs with future execution.

### Diff Surface

- **Addition Background** (#34C75920): Verdict Green at 12% opacity. Added lines.
- **Deletion Background** (#FF3B301F): Alert Red at 12% opacity. Removed lines.
- **Hunk Header** (#007AFF1A): Indicator Blue at 10% opacity. Section markers.
- **Meta Background** (#8E8E9314): Neutral Slate at 8% opacity. File headers, context.

### Named Rules

**The Status Monopoly Rule.** Saturated color appears only as status communication or primary action. Decoration, branding accents, and visual emphasis through color are prohibited. If a color draw the eye, it must answer a question about state.

**The SwiftUI-First Rule.** All colors reference SwiftUI semantic names (`.blue`, `.secondary`, `.systemGroupedBackground`). Hex values in this document are light-mode reference approximations for design tooling. The runtime source of truth is always the semantic API, which adapts to light/dark mode and accessibility settings automatically.

## 3. Typography

**System Font:** SF Pro Text (via SwiftUI system font stack)
**Monospace Font:** SF Mono (via `.monospaced` design)

**Character:** The system font is the only font. SF Pro's optical sizes and weight axis provide all the hierarchy GlabTouch needs. The typography is invisible by design: the reader should process merge request state, not notice the typeface.

### Hierarchy

- **Title** (Semibold, 17pt, line-height 1.29 / SwiftUI `.headline`): MR titles, pipeline titles, section headers. The heaviest text weight in the system.
- **Body** (Regular, 15pt, line-height 1.33 / SwiftUI `.subheadline`): MR descriptions, pipeline subtitles, job names. Secondary content that supports the title.
- **Metadata** (Regular, 12pt, line-height 1.33 / SwiftUI `.caption`): Author names, MR IDs, branch names, timestamps, commit SHAs. High density, low visual weight.
- **Tertiary** (Regular, 11pt, line-height 1.27 / SwiftUI `.caption2`): Branch refs, file paths in compact rows. The smallest readable size.
- **Mono** (Regular, 12pt, line-height 1.33 / SwiftUI `.system(.caption, design: .monospaced)`): Commit SHAs, diff lines, pipeline trace output. Fixed-width for alignment.

### Named Rules

**The No Custom Sizes Rule.** Font sizes come from SwiftUI's semantic text styles exclusively. Hardcoded point values (`Font.system(size: 14)`) are prohibited. Semantic styles respect Dynamic Type; hardcoded sizes break accessibility.

## 4. Elevation

Minimal lift. Surfaces are flat at rest. The iOS system provides elevation through `.sheet` presentation and `.shadow` on modal overlays; GlabTouch uses these system behaviors and adds nothing custom.

Depth is communicated through tonal layering: `Surface Grouped` (#F2F2F7) as the root, `Surface Card` (#FFFFFF) as the content layer. This two-tone system is the standard iOS grouped-list pattern. No custom shadows, no blur effects, no elevation tokens beyond what SwiftUI provides natively.

### Named Rules

**The System Shadow Only Rule.** Custom `shadow()` modifiers are prohibited. The only shadows in the app come from SwiftUI's built-in sheet/popover/menu presentations. If a surface needs to feel elevated, it earns a system presentation context (sheet, popover), not a hand-tuned shadow.

## 5. Components

### Interaction Affordance Rules

Every element on screen falls into exactly one of three categories. The visual treatment must make the category obvious at a glance.

| Category | Visual Signal | Examples |
|---|---|---|
| **Navigable** (pushes to detail) | Disclosure chevron (`chevron.right` SF Symbol) or `NavigationLink` system styling | MR row, pipeline row, job trace link |
| **Actionable** (triggers a mutation) | `.borderedProminent` or `.bordered` button styling, tinted text | Approve, Revoke, Retry, Cancel, Play |
| **Static** (read-only display) | No tap affordance, no chevron, no button chrome | Status badge, metadata labels, diff lines |

**The Quiet Surface Rule.** The number of actionable elements visible at any scroll position is kept to a minimum. A list screen shows zero buttons; actions live on detail screens where the user has committed attention. The exception: inline job actions (play/retry/cancel) in pipeline detail, where the action IS the purpose of the row.

**The Depth Threshold Rule.** Content that can be explained in one or two lines of Metadata typography stays inline as a secondary description. Content requiring more context earns a `NavigationLink` push to a dedicated detail screen. The test: if the supporting text exceeds two lines at 320pt width (iPhone SE), it belongs on its own screen.

### Attention Animations

Motion reserved for state changes that demand user awareness. Three tiers:

- **Pulse** (`.symbolEffect(.pulse)`, 600ms): Applied to status badges when the underlying state changes while the view is visible (e.g., pipeline transitions from running to failed). Draws the eye without interrupting reading flow.
- **Bounce** (`.symbolEffect(.bounce)`, single): Applied to tab bar badge icons when new activity arrives (new MR assigned, pipeline completed). Fires once on arrival, never loops.
- **Transition** (`.opacity` combined with `.move(edge:)`, 220ms, expo-out): Applied to content appearing after a state change (job list expanding, approval status updating). Respects `reduceMotion`: falls back to `.opacity` only.

All attention animations check `@Environment(\.accessibilityReduceMotion)`. When reduced motion is active: pulse becomes a static highlight flash (opacity 0.6 to 1.0, no scale), bounce is suppressed, transitions use opacity only.

### Status Badge (PipelineStatusBadge)

The signature component. A colored circle icon paired with a status label. Appears in MR rows, pipeline rows, pipeline detail headers, and job rows.

- **Shape:** Capsule-shaped when text is present; circular icon when standalone (system SF Symbols)
- **Color Assignment:** Maps directly from `Pipeline.Status` enum to semantic status colors. Green for success, red for failed, blue for running, amber for pending, violet for manual, teal for scheduled, slate for canceled/skipped.
- **States:** Static display; status badges reflect server state. When status changes while visible, a pulse animation draws attention.
- **Accessibility:** Must carry `.accessibilityLabel` describing the full status ("Pipeline succeeded", "Pipeline failed"). Color alone is insufficient.

### Action Buttons

Two tiers, mapped to SwiftUI button roles. Actions appear only where the user has navigated with intent; list screens stay read-only.

- **Primary Action (Approve, Play, Retry):** `.borderedProminent` style with Indicator Blue tint. Positioned for right-thumb reach. Visually prominent: the filled background is the strongest affordance signal on screen.
- **Destructive Action (Revoke, Cancel):** `.bordered` style with `.destructive` role. Alert Red tint. Visually recessive compared to primary actions; the color carries the warning, the reduced prominence carries the hesitation.
- **States:** Default, disabled (grayed, non-interactive, `.opacity(0.4)`), loading (replaced by ProgressView with label).
- **Spacing:** Minimum 44pt touch target per Apple HIG.

### List Rows

The primary content container. SwiftUI `List` with `.insetGrouped` style. Rows are navigable or expandable; rows never contain inline action buttons (exception: job rows in pipeline detail).

- **MR Row:** Title (headline) + secondary description (body, max 2 lines, optional) + author/branch metadata (caption) + trailing status badge. Disclosure chevron signals navigation to detail.
- **Pipeline Row:** Status badge + commit SHA (mono) + branch/MR metadata. Expandable stages via DisclosureGroup with chevron rotation animation.
- **Job Row:** Job name (subheadline) + duration + allowed-to-fail badge + action buttons (play/retry/cancel). The only row type with inline actions, because triggering a job IS the terminal intent.
- **Secondary Description:** When a MR has a description, the first line appears beneath the title in Body typography with `.secondary` foreground. Truncated with ellipsis; full content on the detail screen.
- **Internal Padding:** System-managed. Row content uses 8pt vertical, 4pt between inline elements.

### Empty States

`ContentUnavailableView` with system SF Symbol, title, and description. Used when: no MRs match filter, no pipelines exist, no diff available, no trace output, error loading.

### Loading States

`ProgressView` (system spinner) centered in the content area. Pull-to-refresh via `.refreshable` on List containers.

### Navigation

Standard `NavigationStack` with `NavigationLink`. Three-tab root (`TabView`): Merge Requests, Pipelines, Settings. Tab icons use SF Symbols. Detail views push onto the navigation stack.

Tab badge counts (SF Symbol badge overlay) use bounce animation on increment. Badge value clears on tab selection.

## 6. Do's and Don'ts

### Do:

- **Do** use SwiftUI semantic colors (`.blue`, `.secondary`, `.systemGroupedBackground`) for all color assignments. The semantic API adapts to dark mode, high contrast, and accessibility settings automatically.
- **Do** use SwiftUI semantic text styles (`.headline`, `.caption`) for all typography. Dynamic Type support comes free.
- **Do** keep status information readable through both color and icon/text. A colorblind user must still distinguish "success" from "failed" via the SF Symbol and label.
- **Do** maintain 44pt minimum touch targets on all interactive elements, per Apple HIG.
- **Do** use `ContentUnavailableView` for empty states. It is the system-standard pattern and provides VoiceOver support.
- **Do** respect `@Environment(\.accessibilityReduceMotion)` for all animations. If the user has reduced motion enabled, transitions use `.opacity` only.
- **Do** use `.refreshable` for pull-to-refresh instead of custom refresh indicators.
- **Do** give every tappable row a disclosure chevron or explicit button styling. The user must never guess whether an element responds to touch.
- **Do** keep action buttons on detail screens, where the user has navigated with intent. List screens are for reading and selecting, not for acting.
- **Do** add a one-line secondary description (Body typography, `.secondary` foreground, max 2 lines) beneath titles when the context is simple enough to explain inline.
- **Do** use `.symbolEffect(.pulse)` on status badges when server state changes while the view is visible. Motion is the attention channel; status color is the comprehension channel.

### Don't:

- **Don't** use marketing-page styling. No hero sections, gradient backgrounds, decorative illustrations, or promotional copy. (PRODUCT.md anti-reference)
- **Don't** add decorative motion. No page-load sequences, parallax, or choreographed entrances. Motion conveys state changes only. (PRODUCT.md anti-reference)
- **Don't** use playful status treatments. Pipeline state is engineering data; treat it with the gravity of an instrument reading, not a game achievement. (PRODUCT.md anti-reference)
- **Don't** build custom controls that fight native iOS expectations. No custom tab bars, navigation chrome, pull-to-refresh indicators, or scroll behaviors. SwiftUI provides these; use them. (PRODUCT.md anti-reference)
- **Don't** attempt full-feature GitLab client sprawl. Every screen answers one question about MR or pipeline state. Features that don't serve mobile triage are out of scope. (PRODUCT.md anti-reference)
- **Don't** use `border-left` or `border-right` as colored accent stripes on list items. Use background tints or leading SF Symbols instead.
- **Don't** use hardcoded font sizes (`Font.system(size: N)`). Semantic text styles only.
- **Don't** use hardcoded color values (`Color(red:green:blue:)`). Semantic color names only.
- **Don't** add custom shadows via `.shadow()` modifier. System presentations handle elevation.
- **Don't** use saturated color for decoration. Every instance of non-neutral color must map to a specific status meaning or primary action.
- **Don't** put action buttons on list screens. A scrollable list of rows with inline approve/cancel buttons creates accidental taps and visual noise. Actions belong on detail screens. (Exception: job rows where the action IS the row's purpose.)
- **Don't** make static content look tappable. Labels, badges, and metadata that don't respond to touch must carry zero tap affordance: no chevrons, no tint, no underline.
- **Don't** use looping or repeating animations. Attention animations fire once on state change, then stop. Persistent motion is distraction, and signals nothing.
