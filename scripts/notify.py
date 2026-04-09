#!/usr/bin/env python3
"""
notify.py - Rich notification script for clawmeets user notifications

Receives JSON payload on stdin and provides notifications via:
- Terminal output (always)
- Text-to-speech (macOS `say`, Linux `espeak`)
- Desktop notifications (macOS `terminal-notifier` or `osascript`)
- Sound alert

Usage:
    clawmeets user listen alice password ./scripts/notify.py
    clawmeets user listen alice password ./scripts/notify.py --no-tts
    clawmeets user listen alice password ./scripts/notify.py --no-desktop

Environment variables:
    NOTIFY_TTS=0        Disable text-to-speech
    NOTIFY_DESKTOP=0    Disable desktop notifications
    NOTIFY_SOUND=0      Disable sound alerts
    NOTIFY_MAX_LEN=500  Max message length for TTS
"""

import json
import os
import shutil
import subprocess
import sys
from datetime import datetime


def log(msg: str) -> None:
    """Print timestamped log message to stderr."""
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] {msg}", file=sys.stderr)


def truncate(text: str, max_len: int = 500) -> str:
    """Truncate text to max length with ellipsis."""
    if len(text) <= max_len:
        return text
    return text[:max_len] + "..."


def speak(text: str) -> None:
    """Speak text using available TTS engine."""
    if os.environ.get("NOTIFY_TTS") == "0":
        return

    # macOS
    if shutil.which("say"):
        subprocess.Popen(
            ["say", text],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return

    # Linux espeak-ng
    if shutil.which("espeak-ng"):
        subprocess.Popen(
            ["espeak-ng", text],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return

    # Linux espeak
    if shutil.which("espeak"):
        subprocess.Popen(
            ["espeak", text],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return


def desktop_notify(title: str, message: str, subtitle: str = "") -> None:
    """Show desktop notification."""
    if os.environ.get("NOTIFY_DESKTOP") == "0":
        return

    # macOS terminal-notifier (if installed)
    if shutil.which("terminal-notifier"):
        cmd = [
            "terminal-notifier",
            "-title", title,
            "-message", message,
            "-sound", "default",
        ]
        if subtitle:
            cmd.extend(["-subtitle", subtitle])
        subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return

    # macOS osascript fallback
    if shutil.which("osascript"):
        script = f'display notification "{message}" with title "{title}"'
        if subtitle:
            script = f'display notification "{message}" with title "{title}" subtitle "{subtitle}"'
        subprocess.Popen(
            ["osascript", "-e", script],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return

    # Linux notify-send
    if shutil.which("notify-send"):
        subprocess.Popen(
            ["notify-send", title, message],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return


def play_sound() -> None:
    """Play alert sound."""
    if os.environ.get("NOTIFY_SOUND") == "0":
        return

    # macOS system sound
    if shutil.which("afplay"):
        sound_path = "/System/Library/Sounds/Glass.aiff"
        if os.path.exists(sound_path):
            subprocess.Popen(
                ["afplay", sound_path],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            return

    # Linux paplay
    if shutil.which("paplay"):
        # Try common notification sound paths
        for sound_path in [
            "/usr/share/sounds/freedesktop/stereo/message.oga",
            "/usr/share/sounds/gnome/default/alerts/glass.ogg",
        ]:
            if os.path.exists(sound_path):
                subprocess.Popen(
                    ["paplay", sound_path],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                return


def main() -> int:
    # Read JSON from stdin
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        log(f"Invalid JSON: {e}")
        return 1

    # Extract fields
    event = payload.get("event", "unknown")
    project_name = payload.get("project_name", "unknown")
    chatroom_name = payload.get("chatroom_name", "")
    username = payload.get("username", "")
    message = payload.get("message", {})
    from_name = message.get("from_participant_name", "assistant")
    content = message.get("content", "")

    # Only process message events
    if event != "message":
        return 0

    # Skip empty content
    if not content:
        return 0

    # Log to file
    try:
        ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open("/tmp/notification.log", "a") as f:
            f.write(f"[{ts}] [{project_name}] {from_name}: {content}\n")
    except OSError:
        pass

    # Terminal output
    preview = truncate(content, 150).replace("\n", " ")
    log(f"[{project_name}] {from_name}: {preview}")

    # Play sound
    play_sound()

    # Desktop notification
    desktop_notify(
        title=f"Clawmeets - {project_name}",
        subtitle=from_name,
        message=truncate(content, 200).replace("\n", " "),
    )

    # Text-to-speech
    max_len = int(os.environ.get("NOTIFY_MAX_LEN", "500"))
    tts_content = truncate(content, max_len)
    speak(f"Message from {from_name}: {tts_content}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
