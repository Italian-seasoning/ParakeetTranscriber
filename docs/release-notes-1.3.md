# Parakeet Transcriber 1.3

## New

- **Parakeet v2 is the default.** English-only, the same ~465 MB download as v3. v3, Unified, Nemotron English and Whisper Turbo stay on the model slider, and each shows its download size. The first run of a model you have not used before downloads it, which takes about a minute with no progress shown.
- **Paste with ⌘V.** Copy audio or video files in Finder, click the Parakeet window and press ⌘V. ⇧⌘V still works.
- **Export transcripts** as plain text or WebVTT beside the SRT, and copy the text only.
- **New icon and refreshed UI:** one accent colour, monospace readouts, keycap hints, a live transcribing animation with a progress scan head, and a Copied confirmation. Motion respects Reduce Motion.

## Fixed

- Cancelling a transcription at the wrong moment could still start MacParakeet. A cancelled task now never launches the process, and cancelling while it launches waits for the launch and then stops it.
- If MacParakeet fails to launch, the app now cleans up its output and exit handlers.
