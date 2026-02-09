# Mumble

A lightweight macOS menu bar app for push-to-talk speech-to-text using Groq's Whisper API.

## Features

- **Push-to-talk dictation** -- hold the Fn key to record, release to transcribe and insert text
- **Menu bar app** -- lives in the menu bar, stays out of your way
- **Context-aware transcription** -- detects the active application and adjusts formatting
- **Tone transformation** -- automatically adjusts tone (casual, professional, etc.) based on context
- **Groq Whisper API** -- fast, accurate transcription powered by Groq's hosted Whisper model
- **Guided onboarding** -- step-by-step setup for API key, permissions, and preferences
- **Direct text insertion** -- transcribed text is inserted directly at your cursor position

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- A [Groq API key](https://console.groq.com/) (free tier available)

## Setup

1. **Install XcodeGen** (if not already installed):

   ```bash
   brew install xcodegen
   ```

2. **Generate the Xcode project**:

   ```bash
   cd /path/to/Mumble
   xcodegen generate
   ```

3. **Open the project**:

   ```bash
   open Mumble.xcodeproj
   ```

4. **Build and run** with Cmd+R.

5. **Follow the onboarding flow** to configure your Groq API key and grant the required permissions (Accessibility and Microphone).

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    MumbleApp                        │
│  ┌──────────┐  ┌────────────┐  ┌──────────────────┐ │
│  │Onboarding│  │ MenuBar    │  │   Settings       │ │
│  └────┬─────┘  └─────┬──────┘  └────────┬─────────┘ │
│       └──────────────┼───────────────────┘           │
│                      ▼                               │
│              DictationManager                        │
│       ┌──────┬───────┼───────┬──────┐               │
│       ▼      ▼       ▼       ▼      ▼               │
│  FnKey   Audio    Groq API  Context  Text           │
│  Monitor Recorder  Service  Detector Inserter       │
│                      │                               │
│                      ▼                               │
│              ToneTransformer                         │
└─────────────────────────────────────────────────────┘
```

- **MumbleApp** -- the SwiftUI app entry point, manages the menu bar presence
- **Onboarding** -- guides the user through initial setup (API key, permissions)
- **MenuBar** -- the menu bar icon and popover UI
- **Settings** -- preferences for API key, tone, and behavior
- **DictationManager** -- orchestrates the full dictation lifecycle
- **FnKey Monitor** -- listens for global Fn key press/release events
- **Audio Recorder** -- captures microphone audio into a buffer
- **Groq API Service** -- sends audio to Groq's Whisper endpoint for transcription
- **Context Detector** -- identifies the active app and text field context
- **Text Inserter** -- inserts transcribed text at the cursor via accessibility APIs
- **ToneTransformer** -- adjusts transcription tone based on context rules

## Troubleshooting

### Fn key not working

The Fn key behavior depends on your system keyboard settings. Open **System Settings > Keyboard** and check what "Press fn key to" is set to. If it is set to "Change Input Source" or another action, it may interfere with Mumble's key monitoring. Set it to "Do Nothing" for best results.

### Accessibility permission not granted

Mumble requires Accessibility permission to monitor the Fn key globally and to insert text into other applications. Go to **System Settings > Privacy & Security > Accessibility** and ensure Mumble is listed and enabled. If you moved or rebuilt the app, you may need to remove the old entry and re-add it.

### Microphone permission not granted

Mumble needs microphone access to record audio for transcription. Go to **System Settings > Privacy & Security > Microphone** and ensure Mumble is enabled. If you denied the permission on first launch, you will need to enable it manually here.

### Text not being inserted

Text insertion uses the macOS Accessibility API. Make sure:
1. Accessibility permission is granted (see above).
2. The target application supports text insertion via accessibility (most standard text fields do).
3. You have a focused text field in the target application before recording.

## Known Limitations

- **Fn key conflicts** -- On some keyboards or with certain system settings, the Fn key may be intercepted by macOS before Mumble can detect it.
- **Browser URL detection** -- Detecting the current URL in browsers requires Accessibility permission and may not work with all browsers or browser configurations.
- **No offline mode** -- Transcription requires an internet connection to reach the Groq API. There is no local fallback.
- **Fn key only** -- Currently only the Fn key is supported as the push-to-talk trigger. Custom hotkeys are not yet available.

## Future Enhancements

These features are planned but not yet implemented:

- **Custom hotkey support** -- allow users to choose their own push-to-talk key or key combination
- **Multiple language support** -- transcribe in languages other than English
- **Local Whisper model fallback** -- use a local Whisper model when offline or for privacy
- **Custom tone profiles** -- let users define their own tone transformation rules
- **Clipboard history integration** -- keep a history of recent transcriptions accessible from the menu bar

## License

This project is private and not yet licensed for distribution.
