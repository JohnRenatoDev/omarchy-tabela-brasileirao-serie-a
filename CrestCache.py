import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile


MAX_BYTES = 2 * 1024 * 1024
MAX_DIMENSION = 2048


def validate_png(path):
    if not 33 <= path.stat().st_size <= MAX_BYTES:
        raise ValueError("Invalid crest size")
    with path.open("rb") as source:
        header = source.read(33)
    if header[:16] != b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR":
        raise ValueError("Crest is not a PNG")
    width, height = struct.unpack(">II", header[16:24])
    if not (0 < width <= MAX_DIMENSION and 0 < height <= MAX_DIMENSION):
        raise ValueError("Invalid crest dimensions")


def fetch_crest(cache_dir, team_id):
    if re.fullmatch(r"[1-9][0-9]{0,9}", team_id, flags=re.ASCII) is None:
        raise ValueError("Invalid team ID")
    cache_dir = Path(cache_dir)
    cache_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    target = cache_dir / (team_id + ".png")
    descriptor, temporary_name = tempfile.mkstemp(prefix=".crest-", suffix=".png", dir=cache_dir)
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        result = subprocess.run(
            ["curl", "--disable", "--fail", "--silent", "--show-error",
             "--proto", "=https", "--proto-redir", "=https",
             "--connect-timeout", "5", "--max-time", "20",
             "--max-filesize", str(MAX_BYTES), "--output", str(temporary),
             "--write-out", "%{http_code}", "--",
             "https://a.espncdn.com/i/teamlogos/soccer/500/" + team_id + ".png"],
            check=True, capture_output=True, text=True, timeout=25,
        )
        if result.stdout != "200":
            raise ValueError("Unexpected crest HTTP status")
        validate_png(temporary)
        os.replace(temporary, target)
    finally:
        temporary.unlink(missing_ok=True)


def main():
    if len(sys.argv) != 3:
        return 2
    try:
        fetch_crest(sys.argv[1], sys.argv[2])
    except (OSError, ValueError, subprocess.SubprocessError):
        print("Crest download failed", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
