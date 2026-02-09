<p align="center">
  <img src="Mumble/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="Mumble icon" />
</p>

<h1 align="center">Mumble</h1>

<p align="center">
  <strong>Talk to your Mac. It types back.</strong><br/>
  A tiny menu bar app that turns your voice into text — instantly.
</p>

<p align="center">
  Hold <kbd>Fn</kbd> &rarr; speak &rarr; release &rarr; text appears at your cursor.
  <br/>That's it. That's the app.
</p>

---

## Why Mumble?

Because typing is overrated. Mumble sits quietly in your menu bar and lets you dictate into **any** text field on macOS. It figures out where you are — Slack, email, iMessage, a Google Doc — and adjusts the tone to match.

Casual message to a friend? Mumble keeps it chill. Work email? Mumble cleans it up. You just talk.

## What You Get

- **Push-to-talk with Fn** — hold to record, release to transcribe. No clicking, no waiting.
- **Instant text insertion** — transcribed text drops right into whatever app you're using.
- **Context-aware tone** — Mumble detects the active app and adjusts formatting automatically.
- **Blazing fast transcription** — powered by Groq's Whisper API (seriously, it's fast).
- **Zero clutter** — lives in the menu bar, no Dock icon, no windows in your way.
- **Guided setup** — onboarding walks you through API key, permissions, and preferences.

## Getting Started

**You'll need:** macOS 14+ (Sonoma), Xcode 15+, and a free [Groq API key](https://console.groq.com/).

```bash
brew install xcodegen          # one-time setup
cd /path/to/Mumble
xcodegen generate              # generate the Xcode project
open Mumble.xcodeproj          # Cmd+R to build and run
```

The app will walk you through the rest.

## How It Works

```
    You speak        Mumble listens       Groq transcribes       Text appears
  ┌──────────┐      ┌─────────────┐      ┌────────────────┐     ┌───────────┐
  │ Hold Fn  │ ──▶  │  Record mic │ ──▶  │  Whisper API   │ ──▶ │ At cursor │
  └──────────┘      └─────────────┘      └────────────────┘     └───────────┘
                                                │
                                                ▼
                                      ┌──────────────────┐
                                      │ Tone Transformer  │
                                      │ (casual? formal?) │
                                      └──────────────────┘
```

Under the hood: **DictationManager** orchestrates everything — shortcut monitoring, audio recording, Groq API transcription, tone transformation, and text insertion via Accessibility APIs.

## Troubleshooting

| Problem | Fix |
|---|---|
| **Fn key not working** | System Settings > Keyboard > set "Press fn key to" → **Do Nothing** |
| **No accessibility permission** | System Settings > Privacy & Security > Accessibility > enable Mumble |
| **No microphone permission** | System Settings > Privacy & Security > Microphone > enable Mumble |
| **Text not inserting** | Make sure a text field is focused in the target app before recording |

> Rebuilt or moved the app? You may need to remove the old Accessibility entry and re-add it.

## Known Limitations

- Fn key can conflict with certain macOS keyboard settings
- Browser URL detection doesn't work with all browsers
- Requires an internet connection (no offline fallback yet)
- Only Fn key is supported for now (custom hotkeys coming soon)

## On the Roadmap

- Custom hotkey support
- Multi-language transcription
- Local Whisper model for offline use
- User-defined tone profiles
- Clipboard history for recent transcriptions

## License

See [LICENSE](LICENSE) for details.
