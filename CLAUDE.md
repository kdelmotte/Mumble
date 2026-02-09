# Mumble — Claude Code Project Guide

## What is this?

Mumble is a macOS menu bar app for push-to-talk speech-to-text. Hold a shortcut key (default: Fn) to record, release to transcribe via Groq's Whisper API, and the text is inserted at your cursor position. Tone (casual, professional, etc.) is automatically selected based on the active app.

## Build & Run

Requires macOS 14.0+, Xcode 15.0+, and XcodeGen.

```bash
cd /path/to/Mumble
xcodegen generate        # regenerate Mumble.xcodeproj from project.yml
open Mumble.xcodeproj    # then Cmd+R to build and run
```

Always regenerate the Xcode project after adding/removing source files — the `.xcodeproj` is derived from `project.yml` and should not be edited by hand.

## Run Tests

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test -project Mumble.xcodeproj -scheme Mumble -destination 'platform=macOS'
```

## Project Structure

```
Mumble/
├── App/                  # MumbleApp entry point, AppDelegate, MenuBarManager
├── Audio/                # AudioRecorder, SoundPlayer
├── Context/              # AppContextDetector (frontmost app + browser URL)
├── Dictation/            # DictationManager (orchestrator), DictationHUD, AudioWaveView
├── Infrastructure/       # KeychainManager, Logger, LoginItemManager, PermissionManager,
│                         #   ShortcutBinding, ShortcutMonitor, TextInserter
├── Onboarding/           # Step-by-step onboarding views and view model
├── Resources/            # Assets.xcassets (app icon, onboarding images)
├── Settings/             # Settings views and view model
├── Tone/                 # ToneProfile, ToneMappingConfig, ToneTransformer
├── Transcription/        # GroqTranscriptionService, TranscriptionModels
├── Info.plist
└── Mumble.entitlements
MumbleTests/              # Unit tests (XCTest)
project.yml               # XcodeGen spec (source of truth for the Xcode project)
```

## Architecture Notes

- **LSUIElement / accessory app by design.** After onboarding, the app switches to `NSApplication.ActivationPolicy.accessory` — no Dock icon, no app switcher entry. This is intentional. During onboarding it uses `.regular` so system permission dialogs behave correctly.
- **Menu bar only.** All UI (settings, about) is opened from the NSStatusItem menu. The SwiftUI `Settings` scene is kept as an empty placeholder because SwiftUI requires at least one scene.
- **About panel icon workaround.** Because accessory apps don't automatically resolve their icon in `orderFrontStandardAboutPanel`, the icon is passed explicitly via the `options:` overload.
- **Windows managed via NSWindow.** Both the onboarding and settings windows use `NSHostingController` + `NSWindow` rather than SwiftUI scenes, because SwiftUI window management is unreliable under `.accessory` activation policy.
- **DictationManager** is the central orchestrator: shortcut monitoring → audio recording → Groq API transcription → tone transformation → text insertion at cursor.
- **ToneMappingConfig** persists per-app-group tone preferences (Personal / Work / Other) in UserDefaults as JSON. The `toneForApp()` free function resolves the active app's bundle ID to an `AppGroup` then looks up the configured tone.
- **STTLogger** is used throughout for structured logging (wraps `os.Logger`).

## Key Conventions

- Swift 5.9, macOS 14.0 deployment target.
- `@MainActor` isolation on all UI-touching classes (PermissionManager, DictationManager, MenuBarManager, AppDelegate, AppState).
- Test classes that interact with `@MainActor`-isolated types must also be annotated `@MainActor`.
- Persistence uses UserDefaults (tone config, shortcut binding, onboarding flag, transcription count) and Keychain (API key).
- No third-party dependencies — the project uses only Apple frameworks.

## User Preferences

- **Do not add co-author lines to commits.** Omit `Co-Authored-By` trailers.
- **No Dock icon is intentional** — do not try to "fix" the missing Dock icon. The app is designed as a menu-bar-only accessory.
- The project lives at `/Users/kevind/Desktop/Slop Projects/Mumble/` (source code root and git repo). The sibling `SpeechToTextLite/` directory contains only an Xcode workspace reference.
