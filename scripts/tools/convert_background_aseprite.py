"""Convert the one-layer 128x128 Aseprite background tiles to PNG."""
from pathlib import Path
import struct
import zlib
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "scenes" / "animation" / "background"


def read_first_frame(path: Path) -> Image.Image:
    data = path.read_bytes()
    width, height = struct.unpack_from("<HH", data, 8)
    frame_count = struct.unpack_from("<H", data, 6)[0]
    if frame_count < 1:
        raise ValueError(f"No frames in {path}")

    frame_offset = 128
    frame_size = struct.unpack_from("<I", data, frame_offset)[0]
    old_chunks = struct.unpack_from("<H", data, frame_offset + 6)[0]
    new_chunks = struct.unpack_from("<I", data, frame_offset + 12)[0]
    chunk_count = new_chunks or old_chunks
    cursor = frame_offset + 16
    frame_end = frame_offset + frame_size
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))

    for _ in range(chunk_count):
        chunk_size, chunk_type = struct.unpack_from("<IH", data, cursor)
        chunk = data[cursor + 6:cursor + chunk_size]
        cursor += chunk_size
        if chunk_type != 0x2005:
            continue

        layer, x, y, opacity, cel_type, _z = struct.unpack_from("<HhhBHH", chunk, 0)
        del layer
        if cel_type != 2:
            raise ValueError(f"Unsupported cel type {cel_type} in {path}")
        cel_width, cel_height = struct.unpack_from("<HH", chunk, 16)
        pixels = zlib.decompress(chunk[20:])
        cel = Image.frombytes("RGBA", (cel_width, cel_height), pixels)
        canvas.alpha_composite(cel, (x, y))

    if cursor != frame_end:
        raise ValueError(f"Unexpected frame layout in {path}")
    return canvas


def main() -> None:
    for source in SOURCE.glob("*.aseprite"):
        output = source.with_suffix(".png")
        read_first_frame(source).save(output)
        print(f"converted {source.name} -> {output.name}")


if __name__ == "__main__":
    main()
