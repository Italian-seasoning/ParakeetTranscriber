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

## Release status

Source builds are ad-hoc signed for local use. Public binary releases additionally require a Developer ID Application certificate and notarization credentials; `script/package_release.sh` refuses to publish without both.
