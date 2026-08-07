# Design QA

## Comparison target

- Source visual truth: `C:/Users/Max/AppData/Local/Temp/codex-clipboard-56b2f16b-4db9-4932-afb3-64307a76fb41.png`
- Browser-rendered implementation: `C:/Users/Max/Documents/Development/Word-app/qa-practice-question-desktop-final.png`
- Combined comparison evidence: `C:/Users/Max/Documents/Development/Word-app/qa-practice-comparison-final.png` (source on the left, implementation on the right)
- State: authenticated multiple-choice question for “Attentive”, first option selected, answer not submitted.

## Viewport and normalization

- Source image: 842 × 412 pixels at its supplied density.
- Implementation screenshot: 1440 × 900 pixels at a 1440 × 900 CSS viewport and device scale factor 1.
- Comparable implementation card crop: 1044 × 475 pixels.
- Both component images are shown at native resolution in the combined evidence. The implementation is wider because it fills the available application content area; layout proportions and component rhythm were compared rather than forcing a distorted resize.

## Full-view comparison evidence

- The implementation reproduces the reference hierarchy: question type and word actions, prompt, helper copy, two-column answer grid, divider, and right-aligned Check answer action.
- The selected option uses the same pale yellow-green surface, strong double green edge, and solid green letter marker as the reference.
- The surrounding app navigation remains intact and the question card uses the available desktop width without overflow.

## Focused region comparison evidence

- The combined component comparison keeps all typography, option labels, icons, borders, and the primary action readable, so a second focused crop was not necessary.
- The supplied Lucide bookmark, heart, dislike, and arrow icons match the app’s established icon language and retain accessible button labels.
- No raster imagery, logos, illustrations, or decorative assets were required for this screen.

## Interaction and responsive checks

- Start New Practice and Continue Practice expose correct tab semantics and switch their tab panels.
- Continue Practice lists two existing unfinished attempts and resumes the selected attempt at its first unanswered question.
- Answer selection, Leave practice, and the existing save/favourite/dislike controls remain functional.
- Mobile at 430 CSS px, tablet at 820 CSS px, and desktop at 1440 CSS px have no horizontal overflow.
- The bottom navigation and desktop sidebar both display `Practice`.
- Browser console errors checked: none.

## Findings and comparison history

- Initial P2: the desktop Check answer button was 320 px wide, noticeably larger in proportion than the reference.
- Fix: reduced the desktop/tablet action width to 200 px while retaining a full-width mobile action.
- Post-fix evidence: `qa-practice-comparison-final.png` shows the action now matches the reference proportion. No actionable P0, P1, or P2 findings remain.

## Required fidelity surfaces

- Fonts and typography: existing app family retained; prompt weight, uppercase question label, helper text, and answer copy match the reference hierarchy and wrapping.
- Spacing and layout rhythm: card padding, two-column gaps, 74 px answer rows, divider, radii, and footer alignment match the reference.
- Colours and visual tokens: white card, soft neutral options, green borders, pale selected surface, and dark green primary action align with the visual target.
- Image quality and asset fidelity: no image assets are present in the target; established vector icons are used at crisp native resolution.
- Copy and content: the captured prompt and all four options exactly match the source reference. Navigation and page-heading wording match the requested `Practice` terminology.

## Follow-up polish

- The responsive implementation intentionally expands beyond the fixed-width source crop on large desktop screens while preserving the reference proportions.

final result: passed
