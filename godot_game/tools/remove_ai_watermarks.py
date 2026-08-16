"""Remove the fixed AI-generator watermark areas from the mecha PNG assets.

The source files are copied to the requested backup directory before the
project assets are changed. Re-running the script is safe because backups are
never overwritten.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import shutil

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
CHARACTERS = ROOT / "assets" / "characters"


def feather_alpha(image: Image.Image, rect: tuple[int, int, int, int], feather: int = 6) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    x0, y0, x1, y1 = rect
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(rgba.shape[1], x1), min(rgba.shape[0], y1)
    if x0 >= x1 or y0 >= y1:
        return Image.fromarray(rgba, "RGBA")

    yy, xx = np.mgrid[y0:y1, x0:x1]
    edge_distance = np.minimum.reduce((xx - x0, x1 - 1 - xx, yy - y0, y1 - 1 - yy))
    opacity = np.clip(1.0 - edge_distance / max(1, feather), 0.0, 1.0)
    rgba[y0:y1, x0:x1, 3] = np.rint(
        rgba[y0:y1, x0:x1, 3].astype(np.float32) * opacity
    ).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def watermark_rect(folder: str, size: tuple[int, int]) -> tuple[int, int, int, int]:
    width, height = size
    if folder == "portraits":
        return width - 210, height - 70, width - 8, height - 8
    if folder == "units":
        return width - 105, height - 42, width - 5, height - 5
    if folder == "critical":
        return 1498, 877, 1668, 932
    raise ValueError(f"Unsupported asset folder: {folder}")


def process(backup_root: Path) -> None:
    for folder in ("portraits", "units", "critical"):
        for source in sorted((CHARACTERS / folder).glob("*.png")):
            relative = source.relative_to(CHARACTERS)
            backup = backup_root / relative
            backup.parent.mkdir(parents=True, exist_ok=True)
            if not backup.exists():
                shutil.copy2(source, backup)

            image = Image.open(source)
            cleaned = feather_alpha(image, watermark_rect(folder, image.size))
            cleaned.save(source, optimize=True)
            print(f"CLEANED {relative.as_posix()}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--backup-dir",
        type=Path,
        default=ROOT.parent / "tmp" / "watermark-backup",
    )
    args = parser.parse_args()
    process(args.backup_dir.resolve())


if __name__ == "__main__":
    main()
