# Apple Sharing Rules

`PersonalAffairsCore` is the shared source for Apple-side business state. macOS and iOS may differ in layout, density, navigation, and gestures, but they must not carry separate copies of product rules.

## Required Sharing

- Fetch/query mapping belongs in Core helpers or repositories, not inside individual SwiftUI screens.
- Filtering, grouping, sorting, and review state belong in `PersonalAffairsCore/ViewState`.
- Agent command drafts and confirmation prompts must use shared Core state; UI must not expose backend confirmation tokens to users.
- Personal tasks must never include project query fields.
- Company tasks must use the shared `CompanyTaskScope` mapping for all/no-project/with-project/project views.

## PR Rejection Rules

Reject a change if it:

- Duplicates the same fetch, filter, convert, or validate logic in both macOS and iOS views.
- Adds a new platform-specific business rule without a matching Core helper or test.
- Shows raw Agent confirmation tokens or asks the user to paste one.
- Routes macOS back to legacy `NavigationSplitView` product shells instead of `MacWorkbenchShellView`.

## Verification

Every shared rule change should add or update `PersonalAffairsCoreTests`. Platform screens should stay as layout shells over shared state.
