# How to Adult app icon

Original code-native vector artwork created 2026-10-03 for this app.
The icon shows an open pocket guide and a checked vermilion bookmark on marine
blue. It has no text and uses no stock illustration, photograph or AI raster.

Reproduce all app-icon assets with:

```sh
swift scripts/make-app-icon.swift
```

iOS artwork fills the square canvas; the system supplies its outer mask. macOS
artwork uses a rounded shape inset into the transparent canvas and includes all
required 16–1024 pixel representations. The exact script is the artwork source.
