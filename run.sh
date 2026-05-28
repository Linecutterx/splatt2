#!/usr/bin/env bash
# Splatt2 launcher for macOS and Linux.
#
# Mirrors RUN.bat: bootstraps uv if absent, syncs the locked environment,
# then runs the app. Intended for development and shooters on non-Windows
# systems.

set -euo pipefail

if ! command -v uv >/dev/null 2>&1; then
    echo "uv not found. Installing it now..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # The installer drops uv in ~/.local/bin; export it for this shell.
    export PATH="$HOME/.local/bin:$PATH"
fi

echo "Syncing dependencies..."
uv sync --frozen

echo "Starting Splatt2..."
exec uv run python main.py
