"""Build a FAT32 TF-card image reserved for the FPGA AVI recorder.

This program only creates a regular image file. It never opens a physical disk.
The image must be written to an SDHC/SDXC TF card by the operator.
"""

from __future__ import annotations

import argparse
import math
import struct
from pathlib import Path

SECTOR = 512
TOTAL_SECTORS = 131072  # 64 MiB
PARTITION_START = 2048
PARTITION_SECTORS = TOTAL_SECTORS - PARTITION_START
RESERVED_SECTORS = 32
FAT_COUNT = 2
WIDTH, HEIGHT, FPS = 128, 75, 10
FRAME_BYTES = WIDTH * HEIGHT * 3
FRAME_BLOCK_BYTES = 57 * SECTOR
MAX_FRAMES = 1800  # 3 minutes
FILE_BYTES = SECTOR + MAX_FRAMES * FRAME_BLOCK_BYTES
SIGNATURE = b"TFREC1\0\0"


def fat_sectors() -> int:
    sectors = 1024
    while True:
        clusters = (PARTITION_SECTORS - RESERVED_SECTORS - FAT_COUNT * sectors)
        needed = math.ceil((clusters + 2) * 4 / SECTOR)
        if needed == sectors:
            return sectors
        sectors = needed


FAT_SECTORS = fat_sectors()
DATA_START = PARTITION_START + RESERVED_SECTORS + FAT_COUNT * FAT_SECTORS
FILE_START = DATA_START + 1  # cluster 2 is the root directory
FILE_SECTORS = FILE_BYTES // SECTOR
assert FILE_SECTORS <= PARTITION_START + PARTITION_SECTORS - FILE_START
assert (PARTITION_SECTORS - RESERVED_SECTORS - 2 * FAT_SECTORS) >= 65525
JUNK_BYTES = FRAME_BLOCK_BYTES - FRAME_BYTES - 16
assert JUNK_BYTES == 368


def chunk(tag: bytes, body: bytes) -> bytes:
    return tag + struct.pack("<I", len(body)) + body + (b"\0" if len(body) & 1 else b"")


def avi_header(frames: int) -> tuple[bytes, dict[str, int]]:
    if not 0 <= frames <= MAX_FRAMES:
        raise ValueError("frame count outside reserved file")
    avih = struct.pack("<14I", 100000, FPS * FRAME_BLOCK_BYTES, 0, 0,
                       frames, 0, 1, FRAME_BYTES, WIDTH, HEIGHT, 0, 0, 0, 0)
    strh = struct.pack("<4s4sIHH8Ihhhh", b"vids", b"DIB ", 0, 0, 0,
                       0, 1, FPS, 0, frames, FRAME_BYTES, 0xFFFFFFFF, 0,
                       0, 0, WIDTH, HEIGHT)
    strf = struct.pack("<IiiHHIIiiII", 40, WIDTH, -HEIGHT, 1, 24, 0,
                       FRAME_BYTES, 0, 0, 0, 0)
    hdrl = chunk(b"LIST", b"hdrl" + chunk(b"avih", avih) +
                 chunk(b"LIST", b"strl" + chunk(b"strh", strh) + chunk(b"strf", strf)))
    # Keep every frame on a 512-byte boundary. A JUNK chunk between frames
    # carries the required padding without becoming part of the video stream.
    before_movi = b"RIFF" + b"\0" * 4 + b"AVI " + hdrl
    junk_size = SECTOR - len(before_movi) - 8 - 12
    if junk_size < 8 or junk_size & 1:
        raise AssertionError("AVI header cannot fit one sector")
    junk = chunk(b"JUNK", SIGNATURE + b"\0" * (junk_size - len(SIGNATURE)))
    movi = b"LIST" + struct.pack("<I", 4 + frames * FRAME_BLOCK_BYTES) + b"movi"
    header = bytearray(before_movi + junk + movi)
    assert len(header) == SECTOR
    struct.pack_into("<I", header, 4, SECTOR - 8 + frames * FRAME_BLOCK_BYTES)
    offsets = {
        "riff_size": 4,
        "avih_frames": header.find(b"avih") + 8 + 16,
        "strh_frames": header.find(b"strh") + 8 + 32,
        "movi_size": SECTOR - 8,
        "signature": header.find(SIGNATURE),
    }
    assert offsets["signature"] > 0
    assert struct.unpack_from("<I", header, offsets["avih_frames"])[0] == frames
    assert struct.unpack_from("<I", header, offsets["strh_frames"])[0] == frames
    return bytes(header), offsets


def boot_sector() -> bytes:
    b = bytearray(SECTOR)
    b[:3] = b"\xEB\x58\x90"
    b[3:11] = b"TFREC001"
    struct.pack_into("<HBHBHHBHHHII", b, 11, SECTOR, 1, RESERVED_SECTORS,
                     FAT_COUNT, 0, 0, 0xF8, 0, 63, 255, PARTITION_START,
                     PARTITION_SECTORS)
    struct.pack_into("<IHHIHH", b, 36, FAT_SECTORS, 0, 0, 2, 1, 6)
    b[64] = 0x80
    b[66] = 0x29
    struct.pack_into("<I", b, 67, 0x52454331)
    b[71:82] = b"TF_RECORDER"
    b[82:90] = b"FAT32   "
    b[510:512] = b"\x55\xAA"
    return bytes(b)


def write_at(f, lba: int, data: bytes) -> None:
    f.seek(lba * SECTOR)
    f.write(data)


def create_image(path: Path) -> None:
    if path.exists():
        raise FileExistsError(f"refusing to overwrite {path}")
    header, offsets = avi_header(0)
    with path.open("xb") as f:
        f.truncate(TOTAL_SECTORS * SECTOR)
        mbr = bytearray(SECTOR)
        # One aligned FAT32 LBA partition.
        struct.pack_into("<B3sB3sII", mbr, 446, 0, b"\xFE\xFF\xFF", 0x0C,
                         b"\xFE\xFF\xFF", PARTITION_START, PARTITION_SECTORS)
        mbr[510:512] = b"\x55\xAA"
        write_at(f, 0, mbr)
        boot = boot_sector()
        write_at(f, PARTITION_START, boot)
        write_at(f, PARTITION_START + 6, boot)
        fsinfo = bytearray(SECTOR)
        struct.pack_into("<I", fsinfo, 0, 0x41615252)
        struct.pack_into("<I", fsinfo, 484, 0x61417272)
        struct.pack_into("<I", fsinfo, 488, 0xFFFFFFFF)
        struct.pack_into("<I", fsinfo, 492, 0xFFFFFFFF)
        fsinfo[510:512] = b"\x55\xAA"
        write_at(f, PARTITION_START + 1, fsinfo)
        write_at(f, PARTITION_START + 7, fsinfo)
        fat = bytearray(FAT_SECTORS * SECTOR)
        struct.pack_into("<III", fat, 0, 0x0FFFFFF8, 0x0FFFFFFF, 0x0FFFFFFF)
        for cluster in range(3, 3 + FILE_SECTORS):
            struct.pack_into("<I", fat, cluster * 4,
                             0x0FFFFFFF if cluster == 2 + FILE_SECTORS else cluster + 1)
        write_at(f, PARTITION_START + RESERVED_SECTORS, fat)
        write_at(f, PARTITION_START + RESERVED_SECTORS + FAT_SECTORS, fat)
        root = bytearray(SECTOR)
        root[:11] = b"RECORD  AVI"
        root[11] = 0x20
        struct.pack_into("<H", root, 20, 0)
        struct.pack_into("<H", root, 26, 3)
        struct.pack_into("<I", root, 28, FILE_BYTES)
        write_at(f, DATA_START, root)
        write_at(f, FILE_START, header)
    print(f"image: {path}\nfile: RECORD.AVI\nvideo LBA: {FILE_START}")
    print(f"maximum: {MAX_FRAMES} frames / {MAX_FRAMES // FPS} seconds")
    print(f"AVI dynamic offsets: {offsets}")


def write_header_hex(path: Path) -> None:
    header, offsets = avi_header(0)
    path.write_text("\n".join(f"{b:02x}" for b in header) + "\n", encoding="ascii")
    print(f"header ROM: {path}; layout: {offsets}; start LBA: {FILE_START}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path, help="new 64 MiB image file")
    parser.add_argument("--header-hex", type=Path)
    args = parser.parse_args()
    create_image(args.image)
    if args.header_hex:
        write_header_hex(args.header_hex)
