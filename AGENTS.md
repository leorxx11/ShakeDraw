# Repository Guidelines

## Project Structure & Module Organization
- `ShakeDraw/`: SwiftUI app sources — `ContentView.swift`, `ShakeDrawApp.swift`, `RandomDrawManager.swift`, `FolderManager.swift`, `ImageLoader.swift`, `ShakeDetector.swift`, `Assets.xcassets`.
- `ShakeDrawTests/`: Unit tests (XCTest).
- `ShakeDrawUITests/`: UI tests (XCUITest).
- `ShakeDraw.xcodeproj/`: Xcode project file and workspace metadata.

## Build, Test, and Development Commands
- Open in Xcode: `open ShakeDraw.xcodeproj`
- Build (CLI, simulator): `xcodebuild -project ShakeDraw.xcodeproj -scheme ShakeDraw -destination 'platform=iOS Simulator,name=iPhone 15' build`
- Run tests with coverage: `xcodebuild -project ShakeDraw.xcodeproj -scheme ShakeDraw -enableCodeCoverage YES -destination 'platform=iOS Simulator,name=iPhone 15' test`
- Run locally: select a simulator/device in Xcode and press Run.

## Coding Style & Naming Conventions
- Swift 5+, SwiftUI; follow Swift API Design Guidelines.
- Indentation: 4 spaces; aim for ≤120 characters/line.
- Naming: Types `UpperCamelCase`; functions/properties `lowerCamelCase`; enum cases `lowerCamelCase`.
- Files: one primary type per file (e.g., `RandomDrawManager.swift`). Prefer `guard` early exits; avoid force unwraps; use `private`/`fileprivate` appropriately.

## Testing Guidelines
- Framework: XCTest/XCUITest. Place unit tests in `ShakeDrawTests/*Tests.swift`, UI in `ShakeDrawUITests/*UITests*.swift`.
- Method names: `test_What_Should_Happen()`; keep one behavior per test.
- Focus: randomness without immediate repeats (`RandomDrawManager`), bookmark persistence and permission loss (`FolderManager`), shake thresholds (`ShakeDetector`). Use fixtures/mocks where possible.

## Commit & Pull Request Guidelines
- Style: Conventional Commits (e.g., `fix:`, `feat:`, `UI:`). Imperative mood; emojis optional, consistent.
- PRs: concise description, linked issues, before/after screenshots for UI, notes on tests/coverage. Keep changes scoped.

## Security & Configuration Tips
- Respect security-scoped bookmarks; do not commit user data or cached images. Handle permission revocation by clearing persisted state (e.g., background/image caches).
