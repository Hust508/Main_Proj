"""Check the recorder's AVI layout with an independent video decoder."""
from __future__ import annotations

import struct
import tempfile
from pathlib import Path

import cv2

from tf_prepare import (DATA_START, FAT_SECTORS, FILE_BYTES, FILE_SECTORS,
                        FILE_START, FRAME_BLOCK_BYTES, FRAME_BYTES, FPS,
                        HEIGHT, PARTITION_START, RESERVED_SECTORS, SECTOR,
                        WIDTH, avi_header, create_image)


def sample_frame(index: int) -> bytes:
    # BGR24 top-down frame with a distinct first row and changing frame color.
    bgr = bytes((index * 60, 40, 230 - index * 50))
    frame = bgr * (WIDTH * HEIGHT)
    return b"00db" + struct.pack("<I", FRAME_BYTES) + frame + \
           b"JUNK" + struct.pack("<I", 368) + bytes(368)


def main() -> None:
    project_dir = Path(__file__).resolve().parents[1]
    assert project_dir.name == "project" and project_dir.parent.name == "Main_Proj"
    rom = project_dir / "user_source/hdl_source/recording/avi_header.hex"
    assert bytes.fromhex(rom.read_text(encoding="ascii")) == avi_header(0)[0]
    rtl = (project_dir / "user_source/hdl_source/recording/tf_avi_recorder.v").read_text()
    assert f"FILE_LBA=32'd{FILE_START}" in rtl
    with tempfile.TemporaryDirectory(dir=project_dir) as tmp:
        image_path = Path(tmp) / "prepared.img"
        create_image(image_path)
        with image_path.open("rb") as disk:
            disk.seek(446)
            partition = disk.read(16)
            assert partition[4] == 0x0C
            assert struct.unpack_from("<I", partition, 8)[0] == PARTITION_START
            disk.seek(DATA_START * SECTOR)
            root = disk.read(SECTOR)
            assert root[:11] == b"RECORD  AVI"
            assert struct.unpack_from("<H", root, 26)[0] == 3
            assert struct.unpack_from("<I", root, 28)[0] == FILE_BYTES
            fat_lba = PARTITION_START + RESERVED_SECTORS
            for cluster, expected in ((3, 4), (3 + FILE_SECTORS - 1, 0x0FFFFFFF)):
                disk.seek(fat_lba * SECTOR + cluster * 4)
                assert struct.unpack("<I", disk.read(4))[0] == expected
                disk.seek((fat_lba + FAT_SECTORS) * SECTOR + cluster * 4)
                assert struct.unpack("<I", disk.read(4))[0] == expected
            disk.seek(FILE_START * SECTOR)
            assert disk.read(SECTOR) == avi_header(0)[0]
        path = Path(tmp) / "sample.avi"
        with path.open("wb") as f:
            f.write(avi_header(3)[0])
            for i in range(3):
                block = sample_frame(i)
                assert len(block) == FRAME_BLOCK_BYTES
                f.write(block)
            # The real FAT32 file stays preallocated beyond the RIFF size.
            f.write(bytes(4096))
        video = cv2.VideoCapture(str(path))
        assert video.isOpened(), "decoder rejected AVI"
        assert int(video.get(cv2.CAP_PROP_FRAME_COUNT)) == 3
        assert int(video.get(cv2.CAP_PROP_FPS)) == FPS
        for i in range(3):
            success, image = video.read()
            assert success and image.shape == (HEIGHT, WIDTH, 3)
            assert abs(int(image[0, 0, 0]) - i * 60) <= 2
        assert not video.read()[0]
        video.release()
    print("FAT32 layout and AVI decoded: 128x75, 10 fps, three distinct frames")


if __name__ == "__main__":
    main()
