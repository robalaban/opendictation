# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This App Is

OpenDictation is a macOS menu-bar dictation app. The user presses a hotkey (Option+Space) to start recording, speaks, presses the hotkey again to stop, and the app transcribes the audio and injects the text into whatever input field is focused. A bubble-shaped ( morphing ) overlay shows recording status and live transcription preview.

The interaction model is **toggle** (press once to start, press again to stop), not hold-to-talk.

## Build & Run

```bash
xcodebuild build -scheme OpenDictation -configuration Debug
```

But **this only builds to DerivedData** — it does not relaunch the app. Always tell the user to press **Cmd+R in Xcode** to build and run. Use the build marker in `OpenDictationApp.swift` `applicationDidFinishLaunching` to confirm which binary is running.

Rebuilding changes the binary path. macOS accessibility permission is granted per-binary, so the user must re-authorize in System Settings after each rebuild.

No external package managers. All dependencies are system frameworks.

## Architecture Overview

```
Hotkey press (Carbon)
    ↓
HotkeyManager.onToggle
    ↓
DictationController (orchestrator, @MainActor)
    ├→ AudioRecorder        — AVAudioEngine capture + PCM16 streaming
    ├→ VoxtralEngine        — subprocess transcription (warm or cold)
    ├→ TextInjector          — AX API text insertion + keyboard fallback
    ├→ OverlayController     — NSPanel notch overlay
    ├→ DictationStore        — file persistence
    └→ DiagnosticsLogger     — categorized logging
```

### File Layout

- **`Controllers/`** — `DictationController` (state machine: idle → recording → transcribing → done), `OverlayController` (overlay panel + animations)
- **`Services/`** — One concern per file: audio capture, transcription engine, text injection, hotkey, permissions, logging, store
- **`Models/`** — `AppSettings`, `Dictation`, `DictationMeta`, `OverlayState`
- **`UI/`** — SwiftUI views: menu bar, settings, dictation history, overlay, hotkey recorder

### State Flow

`DictationController` is the central state machine. It transitions through:
1. **Idle** — waiting for hotkey
2. **Recording** — AudioRecorder captures, VoxtralEngine receives live PCM16 stream via warm session
3. **Transcribing** — warm session processes remaining audio, or cold subprocess runs on the WAV file
4. **Done** — transcript injected into focused app, saved to store, overlay dismissed

## Critical Concurrency Rules

### Never block @MainActor

`VoxtralEngine`, `DictationController`, `OverlayController`, `AppSettings`, and `DictationStore` are all `@MainActor`. Any synchronous blocking call in these classes freezes the UI.

**These calls block the main thread and must not appear in @MainActor code:**
- `Process.waitUntilExit()`
- `FileHandle.readDataToEndOfFile()`
- `FileHandle.availableData` (blocks until data OR EOF)
- `Thread.sleep()`
- `DispatchQueue.sync` on a busy queue

**If you need blocking I/O**, move it to a background `DispatchQueue.async` or a detached `Task`, then signal completion back to the main actor via continuation or callback.

### Pipe write-end lifecycle

Swift `Pipe` objects hold `fileHandleForWriting` open in the parent process even after the child exits. Both `readDataToEndOfFile()` and `availableData` block until ALL write ends close.

**Always close the parent's write end after launching the process:**
```swift
try process.run()
try outputPipe.fileHandleForWriting.close()
try errorPipe.fileHandleForWriting.close()
```

### One I/O strategy per pipe

Use readability handlers OR manual pipe reads. Never both on the same file descriptor. Two readers on the same fd causes EXC_BAD_ACCESS.

- **Warm sessions** — readability handlers capture data continuously. Do not call `readDataToEndOfFile()` or `availableData` on those handles.
- **Cold runs** — manual `readDataToEndOfFile()` after closing write ends. No readability handlers.

### Process lifecycle

Prefer `Process.terminationHandler` wrapped in `CheckedContinuation` over polling `isRunning` with `Task.sleep`. If you must poll, keep the poll loop in an `async` function so `Task.sleep` yields the actor.

## VoxtralEngine: Two Transcription Modes

### Warm session (preferred, live streaming)
Audio is streamed to the voxtral process via stdin while the user speaks. Readability handlers on stdout/stderr capture partial and final transcripts. When the user stops recording, stdin is closed and the process finishes.

### Cold run (fallback)
A WAV file is passed as a CLI argument to a fresh voxtral process. Output is read after the process exits.

The warm session is attempted first. If it fails (no audio streamed, config mismatch, process died), the cold path runs.

## Carbon Hotkey Behavior

`kEventHotKeyPressed` fires for both initial key press AND key repeats. Use an `isKeyDown` flag to suppress repeats:
- On `kEventHotKeyPressed`: if `isKeyDown` is true, ignore (repeat). If false, set `isKeyDown = true` and fire `onToggle`.
- On `kEventHotKeyReleased`: set `isKeyDown = false`. No callback.

## Text Injection Strategy

`TextInjector.insertLiveText` tries three strategies in order:
1. `AXUIElementSetAttributeValue` with `kAXSelectedTextAttribute` (fastest, replaces selection)
2. Read `kAXValueAttribute` + `kAXSelectedTextRangeAttribute`, splice text, write back
3. Synthesize keyboard events via `CGEvent.postToPid()` targeting the frontmost app

For final paste after transcription, `TextInjector.paste` uses clipboard + simulated Cmd+V.

## Debugging This App

### Hang vs crash vs console noise
- **Hang** (beachball, unresponsive) = main thread blocked. Check for blocking calls in @MainActor code.
- **Crash** (app terminates, EXC_BAD_ACCESS) = memory safety issue. Check FileHandle races, use-after-free.
- **Core Audio HAL messages** (`HALC_ProxyObjectMap`, `throwing -10877`, `IOWorkLoop: skipping cycle`) = framework noise. Ignore unless accompanied by actual crash/hang.

### Use Xcode debugger
When the app hangs, press Pause in Xcode to see exactly where each thread is blocked. This is faster than adding log statements.

### Build marker
The build marker string in `applicationDidFinishLaunching` confirms which binary is running. Update it when making changes so you can verify the user launched the new build.

### Instrument before fixing
Add a `logger.log()` call before and after suspicious operations to narrow down WHERE a problem occurs before theorizing about WHY.

## Data Storage

- Dictations: `~/Library/Application Support/OpenDictation/Dictations/{UUID}/` — `meta.json`, `dictation.md`, optional `audio.wav`
- Settings: UserDefaults
- Logs: `~/Library/Application Support/OpenDictation/Logs/OpenDictation.log`
- Helpers: `~/Library/Application Support/OpenDictation/Helpers/` — compiled voxtral_live_helper

## What Not To Do

- Do not add `@MainActor` to classes that do subprocess or pipe I/O
- Do not call `readDataToEndOfFile()` without closing the pipe's write end first
- Do not mix readability handlers with manual pipe reads on the same file handle
- Do not assume `availableData` is non-blocking — it blocks until data or EOF
- Do not use `Thread.sleep` or `DispatchQueue.sync` on the main actor
- Do not treat Core Audio console warnings as bugs
- Do not bundle multiple fixes — change one thing, verify, then proceed
