# Build

Cross-platform PyInstaller build of Splatt2 for the host OS.

## Prerequisites

```sh
uv sync --frozen --group build
```

This installs both the runtime dependencies and the `build` group (PyInstaller and its hooks). uv is bootstrapped automatically by `RUN.bat` / `run.sh` if you don't already have it; otherwise install from <https://docs.astral.sh/uv/>.

Platform notes:

- **Linux** — install system tk and PortAudio runtime libs:
  `sudo apt-get install python3-tk libportaudio2`
- **macOS** — Xcode Command Line Tools (for codesigning).
- **Windows** — no extras; PyInstaller wheels include the bootloader.

## Build

```sh
uv run python build/build.py             # build for the current OS
uv run python build/build.py --clean     # delete dist/ and build cache first
```

Output:

```
dist/splatt2-<os>-<arch>/
```

On macOS the directory contains `Splatt2.app` (the launchable bundle)
plus the underlying onedir layout used by the bootloader. On Windows
and Linux the binary is `splatt2(.exe)` alongside `_internal/`.

## Files

- `build/splatt2.spec` — PyInstaller spec, single source of truth for
  what gets bundled (data files, hidden imports, per-OS branches).
- `build/build.py` — wrapper around `pyinstaller` that handles cleanup
  and renames the output to a stable per-platform directory name.

## Icons

Drop platform icons into `build/icons/`:

```
build/icons/splatt2.ico    Windows
build/icons/splatt2.icns   macOS
build/icons/splatt2.png    Linux
```

If absent the build still succeeds with PyInstaller's defaults.
