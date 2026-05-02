# Contributing to OpenDictation

Thanks for your interest in OpenDictation. This document covers how to build the app locally and the engineering conventions to follow when changing it.

## Building locally

**Requirements**

- macOS (Apple Silicon recommended; the Voxtral inference path uses Metal)
- Xcode 16 or later
- An Apple ID for local code signing

**Steps**

1. Clone the repo:
   ```
   git clone https://github.com/<your-fork>/opendictation.git
   cd opendictation
   ```
2. Open `app/OpenDictation.xcodeproj` in Xcode.
3. In the project's **Signing & Capabilities** tab, change **Team** to your own Apple ID team. The repo ships with the original maintainer's team ID and bundle identifier — your local build will fail to sign until you swap in your own.
4. Press **⌘R** to build and run.

The first launch will prompt for microphone and accessibility permissions. macOS grants accessibility permission per-binary path, so a fresh build after a clean may require re-granting access in System Settings → Privacy & Security → Accessibility.

**The voxtral helper binary**

The on-device transcription engine is a small C program in `app/Vendor/voxtral/`, built separately via its own `Makefile`. See `app/Vendor/voxtral/README.md` for build details and upstream attribution.

## Project conventions

The notes below capture lessons learned while building the dictation pipeline. They apply to any future voice/audio or subprocess-driven feature work. Architecture details and component responsibilities are documented in `app/CLAUDE.md`.

## Architecture

### Keep blocking I/O off @MainActor

`VoxtralEngine` being `@MainActor` caused the app to hang. Any class that manages subprocesses, pipes, or blocking I/O should be a dedicated `actor` or plain class with a background queue. Only publish final results back to `@MainActor`.

### Close pipe write ends immediately after process.run()

The parent process holds `Pipe.fileHandleForWriting` open after fork. Both `readDataToEndOfFile()` and `availableData` block until ALL write ends close. Always close the parent's copy right after launch:

```swift
try process.run()
try outputPipe.fileHandleForWriting.close()
try errorPipe.fileHandleForWriting.close()
```

### Pick one I/O strategy per process - never mix

Readability handlers for live streaming OR manual pipe reads for one-shot runs. Never both on the same file descriptor. Two readers on the same fd = race conditions and crashes.

### Use Process.terminationHandler instead of polling isRunning

Replace poll loops with the built-in callback wrapped in a `CheckedContinuation`. No sleep calls on any actor, no blocking `waitUntilExit()`.

### Design for toggle from the start

The hold-to-talk model leaked into the architecture (`onActivated`/`onDeactivated` split). A simple `onToggle` callback avoids multiple rewrites when the interaction model changes.

### Carbon hotkey events fire for repeats

`kEventHotKeyPressed` fires for both initial press and key repeats. Use an `isKeyDown` flag to distinguish initial press from repeats. Only fire the toggle on initial press, reset the flag on release.

## Debugging Process

### Ask "crash or hang?" immediately

A crash (EXC_BAD_ACCESS, app terminates) and a hang (beachball, unresponsive) have completely different causes. This one question changes the entire investigation direction.

### Use Xcode's debugger pause button

When an app hangs, hitting pause shows exactly where every thread is stuck. Would have revealed `main thread -> readDataToEndOfFile()` immediately instead of 4 fix attempts.

### Don't treat console noise as the bug

Core Audio HAL messages (`HALC_ProxyObjectMap`, `throwing -10877`, `IOWorkLoop: skipping cycle`) are framework noise. Ask "what actually happens to the app?" before investigating log messages.

### Instrument before fixing

Add diagnostic logging to narrow down WHERE the problem is before theorizing about WHY. A single log line before a blocking call shows exactly where execution stops.

### One change, one verify

Never bundle multiple fixes. When a combined change fails, you can't isolate which part was wrong. Change one thing, rebuild, confirm.

### Verify the binary is running

`xcodebuild build` builds to DerivedData but doesn't relaunch. Use build markers in launch logs to confirm the user is running the new binary before debugging further.

### Check actor isolation first

Read the class declaration before touching anything else. `@MainActor` on a class that does blocking I/O is the entire bug — 800 lines of pipe analysis are irrelevant if you miss the annotation on line 1.

### Rebuilds invalidate accessibility

macOS grants accessibility permission per-binary path. Rebuilding changes the binary, requiring the user to re-grant permission in System Settings.
