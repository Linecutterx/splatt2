#!/usr/bin/env bash
# Splatt2 launcher for macOS and Linux.
# Mirrors RUN.bat: checks Python, installs dependencies into a local
# virtual environment, then launches main.py.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VENV_DIR="$SCRIPT_DIR/.venv"
INTERACTIVE=0
if [ -t 0 ] && [ -t 1 ]; then
    INTERACTIVE=1
fi

pause_if_double_clicked() {
    # If launched from a file manager (no controlling terminal), keep the
    # window open so the user can read any error output.
    if [ "$INTERACTIVE" -eq 0 ]; then
        echo
        read -r -p "Press Enter to close..." _ || true
    fi
}

fail() {
    echo
    echo "  [ERROR] $1"
    pause_if_double_clicked
    exit 1
}

echo
echo "  ============================================"
echo "    SPLATT2 - Target Shooting Trainer"
echo "  ============================================"
echo

# ---------------------------------------------------------------------------
# Locate a usable Python interpreter (>= 3.9)
# ---------------------------------------------------------------------------
find_python() {
    for candidate in python3 python; do
        if command -v "$candidate" >/dev/null 2>&1; then
            if "$candidate" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1; then
                echo "$candidate"
                return 0
            fi
        fi
    done
    return 1
}

PYTHON="$(find_python)" || {
    echo "  [ERROR] Python 3.9 or later not found."
    echo
    case "$(uname -s)" in
        Darwin)
            echo "  Install with Homebrew:    brew install python"
            echo "  or download from:         https://www.python.org/downloads/"
            ;;
        Linux)
            echo "  Install with your package manager, e.g.:"
            echo "    Debian/Ubuntu:  sudo apt install python3 python3-venv python3-pip"
            echo "    Fedora:         sudo dnf install python3 python3-pip"
            echo "    Arch:           sudo pacman -S python python-pip"
            ;;
        *)
            echo "  Download from: https://www.python.org/downloads/"
            ;;
    esac
    pause_if_double_clicked
    exit 1
}

PYVER="$("$PYTHON" -c 'import sys; print("{}.{}.{}".format(*sys.version_info[:3]))')"
echo "  Python $PYVER found ($PYTHON)."

# ---------------------------------------------------------------------------
# Verify tkinter is available (ships with Python but often split out on
# macOS Homebrew and Linux distros)
# ---------------------------------------------------------------------------
if ! "$PYTHON" -c 'import tkinter' >/dev/null 2>&1; then
    echo
    echo "  [ERROR] This Python does not include tkinter (the GUI toolkit)."
    echo
    case "$(uname -s)" in
        Darwin)
            if [[ "$PYTHON" == *"/homebrew/"* || "$PYTHON" == *"/usr/local/"* ]] \
                || command -v brew >/dev/null 2>&1; then
                echo "  Install it with Homebrew:"
                echo "    brew install python-tk"
                echo
                echo "  If you have multiple Python versions, match the minor version, e.g.:"
                echo "    brew install python-tk@3.12"
            else
                echo "  Reinstall Python from https://www.python.org/downloads/ — the official"
                echo "  python.org installer includes tkinter."
            fi
            ;;
        Linux)
            echo "  Install it with your package manager:"
            echo "    Debian/Ubuntu:  sudo apt install python3-tk"
            echo "    Fedora:         sudo dnf install python3-tkinter"
            echo "    Arch:           sudo pacman -S tk"
            ;;
        *)
            echo "  Reinstall Python with tkinter support from https://www.python.org/downloads/"
            ;;
    esac
    pause_if_double_clicked
    exit 1
fi

# ---------------------------------------------------------------------------
# Create / reuse virtual environment
# ---------------------------------------------------------------------------
if [ ! -x "$VENV_DIR/bin/python" ]; then
    echo "  Creating virtual environment in .venv ..."
    if ! "$PYTHON" -m venv "$VENV_DIR"; then
        echo
        echo "  [ERROR] Could not create virtual environment."
        echo "  On Debian/Ubuntu you may need:  sudo apt install python3-venv"
        pause_if_double_clicked
        exit 1
    fi
fi

VENV_PY="$VENV_DIR/bin/python"

# ---------------------------------------------------------------------------
# Install / update dependencies
# ---------------------------------------------------------------------------
echo "  Checking dependencies..."
"$VENV_PY" -m pip install --quiet --upgrade pip >/dev/null 2>&1 || true
if ! "$VENV_PY" -m pip install --quiet -r requirements.txt; then
    echo
    fail "Could not install dependencies. Check your internet connection and try again."
fi

# ---------------------------------------------------------------------------
# Launch
# ---------------------------------------------------------------------------
echo "  Starting Splatt2..."
echo
"$VENV_PY" main.py
RC=$?
if [ "$RC" -ne 0 ]; then
    echo
    echo "  [ERROR] Splatt2 exited with code $RC."
    if [ -f "$SCRIPT_DIR/splatt2_crash.log" ]; then
        echo "  Crash details saved to: $SCRIPT_DIR/splatt2_crash.log"
    fi
    pause_if_double_clicked
    exit "$RC"
fi
