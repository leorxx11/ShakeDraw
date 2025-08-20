# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ShakeDraw is an iOS app that allows users to randomly select images from a folder by shaking their device or tapping a button. Built with SwiftUI and targeting iOS 18.0+. The app includes a Share Extension that enables users to save images directly from Safari, Photos, and other iOS apps.

## Development Commands

### Building and Running
- **Open Project**: `open ShakeDraw.xcodeproj`
- **Build**: Use Xcode's build system (Cmd+B) or run on device/simulator
- **Test**: Run unit tests via Xcode Test Navigator or Cmd+U

### Key Files to Test Changes
- Run the app in Xcode simulator or on device to test UI changes
- Test shake detection requires physical device (not available in simulator)
- Image loading requires selecting a folder with actual images

## Architecture

### Core Components Structure
```
ShakeDraw/
├── ContentView.swift          # Main UI coordinator and state management
├── FolderManager.swift        # File access, security-scoped resources, bookmarks
├── ImageLoader.swift          # Image loading, caching, format support
├── RandomDrawManager.swift    # Draw logic, result persistence, state machine
├── ShakeDetector.swift        # CoreMotion accelerometer integration
├── ShakeDrawApp.swift         # App entry point
└── Share to ShakeDraw/        # Share Extension
    ├── ShareViewController.swift  # Share extension main controller
    ├── Info.plist                # Extension configuration
    └── MainInterface.storyboard  # Extension UI
```

### Component Responsibilities

**FolderManager**: 
- Handles UIDocumentPickerViewController for folder selection
- Manages security-scoped resource access with `startAccessingSecurityScopedResource()`
- Persists folder access using bookmark data in UserDefaults
- Key methods: `selectFolder()`, `setSelectedFolder()`, `clearFolder()`

**ImageLoader**:
- Scans folders recursively for supported image formats (jpg, png, heic, etc.)
- Provides random selection with duplicate prevention via `getRandomImage(excluding:)`
- Optimized loading: `loadThumbnail()` for previews, `loadUIImage()` for full resolution
- Pre-decoding with `predecode()` to prevent UI stuttering during first render

**RandomDrawManager**:
- State machine managing draw phases: idle → drawing → result display
- Anti-duplication logic using `currentImageURL` tracking
- Result persistence across app launches via relative paths in UserDefaults
- Background loading and caching for smooth animations
- Key states: `isDrawing`, `showResult`, `isRestoring`

**ShakeDetector**:
- CoreMotion integration with configurable sensitivity (threshold: 1.8, interval: 0.6s)
- Dual detection: total acceleration and vector magnitude
- Graceful degradation when accelerometer unavailable (simulator)

**ContentView**:
- SwiftUI coordinator integrating all components
- Layered UI: background blur, loading animations, result display
- Custom button styles with haptic feedback and visual press states
- Responsive image display optimized for portrait vs landscape images

**ShareViewController**:
- Share Extension main controller handling external app image sharing
- Intelligent content type detection (UTType.image, UTType.fileURL, UTType.url)
- Async preview loading with smart timeout management (8 seconds)
- Multi-format support: JPEG, PNG, WebP, HEIC, GIF, BMP, TIFF
- Network image processing with HTTP Content-Type detection
- Graceful fallback with placeholder preview when loading fails

### Key Technical Patterns

**Security-Scoped Resource Management**: Always pair `startAccessingSecurityScopedResource()` with proper cleanup in defer blocks or explicit calls to `stopAccessingSecurityScopedResource()`.

**Background Loading Strategy**: Heavy operations (image loading, decoding) happen on `DispatchQueue.global(qos: .userInitiated)` with results dispatched back to main queue for UI updates.

**State Synchronization**: Uses `@Published` properties with `@StateObject` and `@ObservedObject` for reactive UI updates. Critical state changes trigger UI animations via `withAnimation()`.

**Memory Management**: Uses `UIGraphicsImageRenderer` for image operations, pre-decodes images to prevent render stuttering, and implements thumbnail caching for performance.

**Persistence Strategy**: Stores relative paths instead of absolute URLs, with folder path validation to ensure bookmarks remain valid across app launches.

**Share Extension Async Pattern**: Uses DispatchGroup for coordinating multiple async operations, with proper timeout handling and status feedback. Always call completion handlers to avoid hanging UI.

**Smart Content Type Detection**: Employs HEAD requests to check HTTP Content-Type before downloading full content, optimizing network usage and processing time.

## UI Customization Points

**Background Blur**: Adjust `BlurredBackgroundView(blurRadius:)` parameter (default: 24)
**Button Feedback**: Modify `PressableTranslucentCapsuleStyle` opacity values (0.12 idle, 0.28 pressed) and scale (0.96 when pressed)
**Loading Animation**: Customize rotation speeds and visual elements in `LoadingAnimationView`
**Image Display**: Portrait image height ratio controlled in `ResultImageView.imageDisplaySize` (currently 65% of screen height)

## Important Development Notes

- **File Access**: All image operations require active security-scoped resource access
- **Threading**: UI updates must happen on main queue, file I/O on background queues
- **State Management**: Multiple @StateObject instances coordinate through delegation pattern
- **Performance**: Pre-decoding and thumbnail generation prevent UI stuttering during image display
- **Persistence**: App remembers last selected folder and result across launches using UserDefaults and file system bookmarks
- **Share Extension**: 
  - Always test with actual devices for Safari sharing (simulator limitations)
  - Use App Groups for shared container access between main app and extension
  - Handle async operations properly to avoid extension termination
  - Implement proper timeout mechanisms for network operations
  - Provide visual feedback even when preview loading fails