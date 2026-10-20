import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile
import zlib


MAX_BYTES = 2 * 1024 * 1024
MAX_DIMENSION = 2048


def validate_png(path):
    if not 33 <= path.stat().st_size <= MAX_BYTES:
        raise ValueError("Invalid crest size")
    with path.open("rb") as source:
        data = source.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES or data[:16] != b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR":
        raise ValueError("Crest is not a PNG")
    width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", data[16:29])
    if not (0 < width <= MAX_DIMENSION and 0 < height <= MAX_DIMENSION):
        raise ValueError("Invalid crest dimensions")
    depths = {0: (1, 2, 4, 8, 16), 2: (8, 16), 3: (1, 2, 4, 8), 4: (8, 16), 6: (8, 16)}
    if depth not in depths.get(color, ()) or compression != 0 or filtering != 0 or interlace not in (0, 1):
        raise ValueError("Invalid crest header")
    output = bytearray(data[:8])
    offset = 8
    seen = set()
    palette_entries = 0
    idat_ended = False
    while offset < len(data):
        if len(data) - offset < 12:
            raise ValueError("Truncated PNG chunk")
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        end = offset + 12 + length
        if end > len(data) or re.fullmatch(rb"[A-Za-z]{2}[A-Z][A-Za-z]", kind) is None:
            raise ValueError("Invalid PNG chunk")
        payload = data[offset + 8:end - 4]
        checksum = struct.unpack(">I", data[end - 4:end])[0]
        if zlib.crc32(kind + payload) != checksum:
            raise ValueError("Invalid PNG checksum")
        if kind == b"IHDR":
            if offset != 8 or length != 13:
                raise ValueError("Invalid PNG header order")
        elif kind == b"PLTE":
            if kind in seen or b"IDAT" in seen or b"tRNS" in seen or color not in (2, 3, 6) or not 0 < length <= 768 or length % 3:
                raise ValueError("Invalid PNG palette")
            palette_entries = length // 3
            if color == 3 and palette_entries > 2 ** depth:
                raise ValueError("Invalid indexed PNG palette")
        elif kind == b"tRNS":
            if kind in seen or b"IDAT" in seen or not (
                (color == 0 and length == 2) or (color == 2 and length == 6)
                or (color == 3 and 0 < length <= palette_entries)
            ):
                raise ValueError("Invalid PNG transparency")
        elif kind == b"IDAT":
            if idat_ended or (color == 3 and b"PLTE" not in seen):
                raise ValueError("Invalid PNG image data order")
        elif kind == b"IEND":
            if length != 0 or end != len(data) or b"IDAT" not in seen:
                raise ValueError("Invalid PNG end")
        elif not kind[0] & 0x20:
            raise ValueError("Unknown critical PNG chunk")
        if kind != b"IDAT" and b"IDAT" in seen:
            idat_ended = True
        if kind in (b"IHDR", b"PLTE", b"tRNS", b"IDAT", b"IEND"):
            output.extend(data[offset:end])
            seen.add(kind)
        offset = end
    if b"IEND" not in seen:
        raise ValueError("Missing PNG end")
    return bytes(output)


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
        sanitized = validate_png(temporary)
        temporary.write_bytes(sanitized)
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
