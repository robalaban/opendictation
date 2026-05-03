<p align="center">
  <img src="web/opendictation_small.png" width="128" height="128" alt="OpenDictation icon">
</p>

<h1 align="center">OpenDictation</h1>

<p align="center">
  Fast, private and secure dictation for macOS — powered by Mistral's Voxtral model, running entirely on your Mac.
</p>

<p align="center">
  <a href="https://opendictation.org">Website</a> · <a href="https://opendictation.org/privacy">Privacy</a>
</p>

---

## What is OpenDictation?

OpenDictation is a macOS dictation utility that transcribes your speech and inserts text wherever your cursor is — in any app, any text field. It runs the [Mistral Voxtral](https://mistral.ai/) speech-to-text model locally on your Mac. No cloud. No subscriptions. No data leaves your device.

## How it works

1. Press **⌥ Space** (or your custom hotkey)
2. Speak naturally
3. Press again to stop
4. Text appears where you're typing

That's it. Works in iMessage, your terminal, Slack, VS Code, Notes — anywhere you can type.

## Features

- **100% local** — Runs Mistral's Voxtral model on-device. Your audio is never sent anywhere.
- **Any app, any field** — Uses macOS accessibility APIs to inject text at your cursor position.
- **Realtime transcription** — Words appear as you speak.
- **Menu bar + full app** — Lives quietly in your menu bar with a full app available when you need it.
- **Custom hotkey** — Remap the trigger to any keyboard shortcut.
- **7 languages** — English, Spanish, French, Portuguese, German, Dutch, and Italian.

## Privacy

OpenDictation is built with a strict no-data-collection policy:

- All speech processing happens on your Mac using the Voxtral model
- No audio or transcriptions are sent to any server
- No analytics, tracking, or cookies
- No account required
- Transcriptions are injected directly into your active app and never stored

Read the full [privacy policy](https://opendictation.org/privacy).

## Requirements

- macOS
- Microphone access permission
- Accessibility permission (to insert text at your cursor)

## Install

Two ways to get OpenDictation: download a pre-built DMG (easiest) or build it yourself from source.

### Option 1 — Install the DMG (recommended)

1. Download the latest `.dmg` from this repository's [GitHub Releases page](../../releases).
2. Open the DMG and drag **OpenDictation** into your `Applications` folder.
3. **First launch will be blocked.** macOS will say "OpenDictation can't be opened because Apple cannot check it for malicious software." This is expected — the DMG is unsigned. Bypass it one of three ways:
   - **Right-click** OpenDictation in `/Applications` → **Open** → click **Open Anyway** in the dialog.
   - Or: open **System Settings → Privacy & Security**, scroll to the message about OpenDictation being blocked, and click **Open Anyway**.
   - Or, from Terminal: `xattr -dr com.apple.quarantine /Applications/OpenDictation.app`
4. Grant **Microphone** and **Accessibility** permissions when prompted (Accessibility is what lets OpenDictation paste text into other apps).
5. The first-launch onboarding will walk you through downloading the Voxtral model from Hugging Face (~4 GB, one time). After that, no data ever leaves your Mac.

> Why isn't the DMG signed? Currently in the process of getting an Apple Developer account and notarizing the app, but in the meantime I wanted to make it available for early testers. The unsigned DMG is a temporary compromise — it just adds an extra click to bypass the security warning on first launch, but after that it behaves like a normal app. If you have any concerns or questions about this, please reach out!

### Option 2 — Build from source

Requires macOS (Apple Silicon strongly recommended), **Xcode 16+**, and a free Apple ID for local code signing.

1. Clone the repo:
   ```bash
   git clone https://github.com/<your-fork>/opendictation.git
   cd opendictation
   ```
2. Open `app/OpenDictation.xcodeproj` in Xcode.
3. In the **Signing & Capabilities** tab, change **Team** to your own Apple ID team. The repo ships with the maintainer's team ID; your local build won't sign until you swap in your own.
4. Press **⌘R**. Xcode will compile the Swift app *and* the bundled `voxtral` C helper (a Run Script phase invokes `make mps` automatically).
5. Grant **Microphone** and **Accessibility** permissions when prompted.
6. Onboarding will walk you through downloading the Voxtral model from Hugging Face (~4 GB).

**Troubleshooting:**

- **"voxtral binary not found in app bundle"** — the Run Script phase that builds the C helper failed. Run it manually to see the error: `cd app/Vendor/voxtral && make mps`.
- **Accessibility permission seems missing after a clean build** — macOS keys accessibility permission to a specific binary path. After a clean rebuild the path changes, so grant access again in **System Settings → Privacy & Security → Accessibility**.

For deeper architecture notes and engineering conventions, see [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Mac App Store

A paid version with auto-updates and extra polish will also be available on the Mac App Store. The source here is and will remain Apache-2.0 — the App Store build exists purely as a convenience option.

## A note on how this was built

OpenDictation was co-created with the help of AI coding assistants. Code, design decisions, and documentation in this repository were produced collaboratively between a human author and AI tools, then reviewed, tested, and committed by the human author. Mentioning it here so it's transparent — the project is open source and you can read every line yourself.

## License

OpenDictation is licensed under the [Apache License 2.0](LICENSE). It bundles a vendored copy of [`antirez/voxtral.c`](https://github.com/antirez/voxtral.c), which remains under its own MIT License — see [`NOTICE`](NOTICE) and [`app/Vendor/voxtral/LICENSE.upstream`](app/Vendor/voxtral/LICENSE.upstream).
