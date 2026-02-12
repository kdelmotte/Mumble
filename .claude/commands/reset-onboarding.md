---
description: Reset Mumble app to fresh-install state for onboarding testing
---

Reset Mumble to a fresh-install state so the onboarding flow can be tested from scratch.

Run ALL of the following steps in order:

1. **Quit Mumble** if it's running:
   ```
   osascript -e 'quit app "Mumble"' 2>/dev/null
   ```

2. **Clear all UserDefaults** for the app:
   ```
   defaults delete com.mumble.app 2>/dev/null
   ```
   This removes: `hasCompletedOnboarding`, `com.mumble.shortcutBinding`, `com.mumble.toneMappingConfig`, `com.mumble.llmFormattingEnabled`, `com.mumble.transcriptionCount`, `selectedMicrophoneUID`, and any other stored preferences.

3. **Keep the Keychain API key** — do NOT delete it. The onboarding API key step will detect the existing key and pre-fill it, so there's no need to re-enter it.

4. **Reset system permissions** (microphone and accessibility):
   ```
   tccutil reset Microphone com.mumble.app 2>/dev/null
   tccutil reset Accessibility com.mumble.app 2>/dev/null
   ```

5. **Confirm** the reset succeeded by verifying the onboarding flag is gone:
   ```
   defaults read com.mumble.app hasCompletedOnboarding 2>&1
   ```
   This should print an error like "does not exist" — that means it worked.

6. Report what was done and remind me to relaunch the app from Xcode to see the onboarding flow.
