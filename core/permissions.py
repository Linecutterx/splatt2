"""
core/permissions.py

macOS camera and microphone permission helper.

On macOS, apps must obtain explicit user consent before accessing the camera
or microphone. The system dialog only appears the first time a process
attempts to access each device. By calling
``AVCaptureDevice.requestAccessForMediaType_`` at startup we surface those
prompts up front, before the user clicks "Start Camera" and gets a black
frame with no explanation.

On Windows and Linux this module is a no-op — those platforms do not gate
device access with a per-app authorisation prompt.
"""

from __future__ import annotations

import sys
import threading


def _is_macos() -> bool:
    return sys.platform == "darwin"


def request_av_permissions(timeout_s: float = 30.0) -> dict:
    """Request camera and microphone access on macOS.

    Returns a dict ``{"camera": bool|None, "microphone": bool|None}``.
    ``None`` means the request could not be made (non-macOS, PyObjC missing,
    or the call failed). On Windows/Linux this returns ``None`` for both.

    This call blocks until the user has answered both prompts, or the
    ``timeout_s`` elapses. Already-answered statuses return immediately.
    """
    result = {"camera": None, "microphone": None}

    if not _is_macos():
        return result

    try:
        # AVFoundation lives in PyObjC. Importing inside the function so the
        # module stays no-cost on other platforms even if it's installed.
        from AVFoundation import (
            AVCaptureDevice,
            AVMediaTypeVideo,
            AVMediaTypeAudio,
        )
    except ImportError:
        print(
            "[Permissions] PyObjC AVFoundation not available — "
            "permission prompts will appear on first device access instead. "
            "Install with: pip install pyobjc-framework-AVFoundation"
        )
        return result

    # Authorisation status constants (avoid importing them as some PyObjC
    # builds do not export them as module-level symbols).
    NOT_DETERMINED = 0
    RESTRICTED = 1
    DENIED = 2
    AUTHORIZED = 3

    def _request_for(media_type: str) -> bool | None:
        try:
            status = AVCaptureDevice.authorizationStatusForMediaType_(media_type)
        except Exception as e:
            print(f"[Permissions] status query failed for {media_type}: {e}")
            return None

        if status == AUTHORIZED:
            return True
        if status in (DENIED, RESTRICTED):
            return False
        if status != NOT_DETERMINED:
            return None

        # Not determined yet — trigger the system prompt.
        evt = threading.Event()
        outcome = {"granted": False}

        def handler(granted):
            outcome["granted"] = bool(granted)
            evt.set()

        try:
            AVCaptureDevice.requestAccessForMediaType_completionHandler_(
                media_type, handler
            )
        except Exception as e:
            print(f"[Permissions] request failed for {media_type}: {e}")
            return None

        if not evt.wait(timeout=timeout_s):
            print(f"[Permissions] timed out waiting for {media_type} response")
            return None
        return outcome["granted"]

    print("[Permissions] Requesting camera access...")
    result["camera"] = _request_for(AVMediaTypeVideo)
    print(f"[Permissions] Camera: {result['camera']}")

    print("[Permissions] Requesting microphone access...")
    result["microphone"] = _request_for(AVMediaTypeAudio)
    print(f"[Permissions] Microphone: {result['microphone']}")

    return result


def warn_if_denied(result: dict) -> str | None:
    """Return a user-facing message if any permission was denied, else None."""
    denied = [name for name, granted in result.items() if granted is False]
    if not denied:
        return None
    bits = ", ".join(denied)
    return (
        f"Splatt2 does not have permission to use the {bits}.\n\n"
        f"Open System Settings → Privacy & Security and grant access for "
        f"the terminal or Python application you used to launch Splatt2, "
        f"then restart the app."
    )


def list_video_devices() -> list[tuple[int, str]] | None:
    """List video capture devices on macOS via AVFoundation.

    Returns a list of ``(index, name)`` tuples, or ``None`` on platforms where
    we cannot enumerate (caller should fall back to probing).

    Using AVFoundation here avoids the noisy
    ``OpenCV: out device of bound (0-0): N`` warnings that appear when
    OpenCV probes non-existent indices.
    """
    if not _is_macos():
        return None
    try:
        from AVFoundation import AVCaptureDevice, AVMediaTypeVideo
    except ImportError:
        return None

    try:
        # devicesWithMediaType_ is deprecated since macOS 10.15 but still works
        # and is the simplest cross-version call. AVCaptureDeviceDiscoverySession
        # would be the modern replacement.
        devices = AVCaptureDevice.devicesWithMediaType_(AVMediaTypeVideo)
    except Exception as e:
        print(f"[Permissions] camera enumeration failed: {e}")
        return None

    out: list[tuple[int, str]] = []
    for i, dev in enumerate(devices or []):
        try:
            name = str(dev.localizedName())
        except Exception:
            name = f"Camera {i}"
        out.append((i, name))
    return out

