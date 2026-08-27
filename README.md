# Parakeet Transcriber

A compact native macOS front end for fully local transcription with MacParakeet. It supports multiple Parakeet, Nemotron, and Whisper models, live progress, batch input, copy-to-clipboard, and Sparkle updates.

## Requirements

- macOS 13 or newer on Apple silicon
- `macparakeet-cli` installed at `/opt/homebrew/bin/macparakeet-cli` or `/usr/local/bin/macparakeet-cli`
- Xcode command-line tools for source builds

## Build

```sh
./script/build_and_run.sh
```

The app and transcription models stay local. Sparkle checks the public `appcast.xml` in this repository for signed updates.

## Install with Homebrew

```sh
brew install --cask italian-seasoning/tap/parakeet-transcriber
```

The current public build is ad-hoc signed and not Apple-notarized. The cask verifies the pinned SHA-256, installs the app, then removes macOS quarantine. Sparkle verifies future updates with its EdDSA signature.

## Release status

`script/package_release.sh` uses Developer ID signing and notarization by default. `script/package_release.sh --adhoc` creates the explicitly unnotarized build used by the current Homebrew cask.
