# Parakeet app icon

Hand-drawn vector, replacing the earlier generated 3D icon. Source: `AppIcon.svg`. Render with `script/render_icon.sh` (needs `brew install librsvg`), which writes the 1024 px `AppIcon.png`. The build script packages all macOS icon sizes from that PNG and keeps its alpha channel.

Design: flat graphite tile with a faint dot grid, a golden parakeet in profile, and three long tail feathers drawn as waveform bars. One accent colour, matching the app UI. The tile is a flat fill on purpose: dark gradients band visibly at 8-bit.
