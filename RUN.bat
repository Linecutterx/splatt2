@echo off
setlocal EnableDelayedExpansion

echo.
echo  ============================================
echo    SPLATT2 - Target Shooting Trainer
echo  ============================================
echo.

REM Bootstrap uv if missing. uv manages Python and dependencies for us;
REM users no longer need to install Python first.
where uv >nul 2>&1
if errorlevel 1 (
    echo  uv not found. Installing it now...
    powershell -ExecutionPolicy ByPass -NoProfile -Command ^
        "irm https://astral.sh/uv/install.ps1 | iex"
    if errorlevel 1 (
        echo.
        echo  [ERROR] Could not install uv automatically.
        echo  Install it manually from https://docs.astral.sh/uv/ and try again.
        echo.
        pause
        exit /b 1
    )
    REM PATH only updates in new shells, so use the installer's default location.
    set "PATH=%USERPROFILE%\.local\bin;%PATH%"
)

echo  Syncing dependencies (first run only takes a minute)...
uv sync --frozen
if errorlevel 1 (
    echo.
    echo  [ERROR] Could not install dependencies.
    echo  Check your internet connection and try again.
    echo.
    pause
    exit /b 1
)

echo  Starting Splatt2...
echo.
uv run python main.py
if errorlevel 1 (
    echo.
    echo  [ERROR] Splatt2 exited with an error.
    echo  Crash details, if any, are saved to the user data directory
    echo  printed in the console output above.
    echo.
    pause
)
