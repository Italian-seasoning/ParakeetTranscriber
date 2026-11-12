# Parakeet Transcriber 1.2.1 (draft)

Draft only. Not packaged, tagged or published.

## Fixed

- Cancelling a transcription at the wrong moment could still start MacParakeet. A
  cancelled task now never launches the process, and cancelling while it launches
  waits for the launch and then stops it.
- If MacParakeet fails to launch, the app now cleans up its output and exit handlers.

## Under the hood

- Added tests for cancellation timing, unusual file paths (spaces, quotes,
  apostrophes, non-ASCII), a missing MacParakeet binary, repeated file names in a
  batch, and cancelling part-way through a batch.
