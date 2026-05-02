# Vendored: voxtral.c

This directory is a vendored copy of [`antirez/voxtral.c`](https://github.com/antirez/voxtral.c) — a from-scratch C implementation of Mistral's Voxtral speech-to-text model.

OpenDictation uses voxtral.c as its on-device transcription engine.

## Upstream

- Source: https://github.com/antirez/voxtral.c
- Author: Salvatore Sanfilippo (antirez)
- License: MIT — see [`LICENSE.upstream`](./LICENSE.upstream)
- Tracked against upstream commit: `134d366c24d20c64b614a3dcc8bda2a6922d077d` (main, 2026-05-02)

## Local modifications

This vendored copy adds the following files for macOS integration:

- `voxtral_mic_macos.c` / `voxtral_mic.h` — Core Audio microphone capture for live streaming
- `voxtral_metal.m` / `voxtral_metal.h` — Metal kernel bindings for Apple Silicon acceleration
- `voxtral_kernels.c` / `voxtral_kernels.h` — kernel dispatch wrappers
- `voxtral_shaders.metal` / `voxtral_shaders_source.h` — Metal shader sources

The core inference code (`voxtral.c`, `voxtral_encoder.c`, `voxtral_decoder.c`,
`voxtral_audio.c`, `voxtral_safetensors.c`, `voxtral_tokenizer.c`) tracks
upstream and may have small local edits.

## Building

See `Makefile` in this directory.

## License

This vendored fork remains under the MIT License of the upstream project.
The local modifications listed above are also released under MIT to keep the
whole directory single-licensed. See [`LICENSE.upstream`](./LICENSE.upstream)
for the full text and copyright notice.
