<p align="center">
  <img src="web/opendictation_small.png" width="128" height="128" alt="OpenDictation icon">
</p>

<h1 align="center">OpenDictation</h1>

<p align="center">
  Fast, invisible dictation for macOS — powered by Mistral's Voxtral model, running entirely on your Mac.
</p>

<p align="center">
  <a href="https://opendictation.com">Website</a> · <a href="https://opendictation.com/privacy">Privacy</a>
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

Read the full [privacy policy](https://opendictation.com/privacy).

## Requirements

- macOS
- Microphone access permission
- Accessibility permission (to insert text at your cursor)

## Building from source

OpenDictation is open source. To build it yourself:

1. Clone the repo and open `app/OpenDictation.xcodeproj` in Xcode.
2. In **Signing & Capabilities**, set the **Team** to your own Apple ID.
3. Press **⌘R** to build and run.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for full build details, architecture notes, and engineering conventions.

## Releases

Pre-built, signed, notarized DMG releases will be published on this repository's GitHub Releases page once the project's Apple Developer account is set up. Until then, build from source.

A paid version with auto-updates and additional polish will also be available on the Mac App Store. The source here is and will remain Apache-2.0; the App Store version exists purely as a convenience option.

## License

OpenDictation is licensed under the [Apache License 2.0](LICENSE). It bundles a vendored copy of [`antirez/voxtral.c`](https://github.com/antirez/voxtral.c), which remains under its own MIT License — see [`NOTICE`](NOTICE) and [`app/Vendor/voxtral/LICENSE.upstream`](app/Vendor/voxtral/LICENSE.upstream).
