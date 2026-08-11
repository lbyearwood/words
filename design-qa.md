# Read-aloud option 2 design QA

## Evidence

- Source visual truth: `C:/Users/Max/Documents/Development/Word-app/artifacts/design-qa/selected-option-2.png`
- Source pixels: 1487 × 1058
- Browser-rendered implementation:
  - Desktop term card: `C:/Users/Max/Documents/Development/Word-app/artifacts/design-qa/read-aloud-card-desktop.png`
  - Desktop quiz and yellow hover prompt: `C:/Users/Max/Documents/Development/Word-app/artifacts/design-qa/read-aloud-tooltip-desktop.png`
  - Mobile term card: `C:/Users/Max/Documents/Development/Word-app/artifacts/design-qa/read-aloud-mobile-card.png`
  - Mobile quiz: `C:/Users/Max/Documents/Development/Word-app/artifacts/design-qa/read-aloud-mobile-quiz.png`
  - Tablet term card: `C:/Users/Max/Documents/Development/Word-app/artifacts/design-qa/read-aloud-tablet-card.png`
  - Tablet quiz: `C:/Users/Max/Documents/Development/Word-app/artifacts/design-qa/read-aloud-tablet-quiz.png`
  - Side-by-side comparison input: `C:/Users/Max/Documents/Development/Word-app/artifacts/design-qa/read-aloud-comparison.png`
- Browser viewport: 1280 × 720 CSS px at device pixel ratio 1.25; browser captures are 1265 × 712 output pixels.
- Responsive frames: 390 CSS px mobile iframe and 820 CSS px tablet iframe within the same browser viewport.
- Density normalization: the side-by-side comparison scales both source and browser captures proportionally in CSS. No pixel-density-only issues were treated as design differences.
- State: pronunciation visible; quiz read-aloud control hovered; multiple-choice option selected; term actions visible.

## Full-view comparison evidence

The combined comparison input shows the selected option 2 and the browser-rendered card and quiz in one image. The implementation retains Brain Express's existing compact three-column card density while matching the selected control's green outlined pill, speaker icon, recognisable pronunciation copy and yellow call-to-action tooltip.

## Focused-region comparison evidence

- The term header places the read-aloud pill immediately after the clean term title, before the meaning count.
- The quiz places the same pill with the prompt and keeps bookmark, favourite and dislike controls separate.
- At 390 px, the prompt wraps above the pill and all controls remain visible with touch-sized targets.
- At 820 px, answer options remain two columns and the pronunciation pill sits on its own readable line.

## Required fidelity surfaces

- Fonts and typography: existing Brain Express font stack and weights are preserved. The phonetic label uses a compact bold UI weight and remains legible at all three widths.
- Spacing and layout rhythm: pill padding, icon gap, 10 px radius and wrap behaviour match the chosen direction without disturbing the existing three-card desktop grid.
- Colors and visual tokens: the control uses the app's green/mint palette; hover uses the established yellow prompt and yellow-soft control state.
- Image quality and asset fidelity: no raster assets were required. The speaker is the existing Lucide icon library, consistent with the app's bookmark, heart and dislike icons.
- Copy and content: the visible label is the learner-friendly pronunciation, while the tooltip says `Read term aloud`. The clean term—not the phonetic spelling—is sent to speech synthesis.

## Interaction and console checks

- Clicking the quiz pill changed `aria-pressed` to `true` and the tooltip to `Stop reading aloud`.
- Clicking it again stopped speech and returned `aria-pressed` to `false`.
- Starting another term cancels and clears the earlier control.
- Fresh browser load produced no console errors.

## Findings

- No actionable P0, P1 or P2 differences remain.
- P3: the desktop term-card pill is deliberately more compact than the concept board because Brain Express must continue showing three cards per row.

## Comparison history

- Pass 1: no P0/P1/P2 issues found. Browser checks confirmed the desktop, tablet and mobile arrangements, yellow hover prompt, start state and stop state. No visual fixes were required after the comparison.

## Implementation checklist

- [x] Shared term-card control
- [x] Multiple-choice and true/false quiz control through the shared question screen
- [x] British English browser speech
- [x] Stop/restart and cross-control cancellation
- [x] Yellow desktop call-to-action prompt
- [x] Mobile, tablet and desktop responsive checks
- [x] Keyboard and screen-reader labels

final result: passed
