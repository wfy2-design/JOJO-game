"""Remove neutral white backgrounds from the six square status avatars."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
AVATARS = ROOT / "assets" / "characters" / "avatars"


def _background_mask(rgba: np.ndarray) -> np.ndarray:
    rgb = rgba[:, :, :3].astype(np.int16)
    original_alpha = rgba[:, :, 3]
    minimum = rgb.min(axis=2)
    spread = rgb.max(axis=2) - minimum
    hard_white = (minimum >= 235) & (spread <= 22) & (original_alpha > 0)
    height, width = hard_white.shape
    seen = np.zeros((height, width), dtype=bool)
    background = np.zeros((height, width), dtype=bool)

    for start_y, start_x in zip(*np.where(hard_white)):
        if seen[start_y, start_x]:
            continue
        queue = deque([(int(start_y), int(start_x))])
        seen[start_y, start_x] = True
        component: list[tuple[int, int]] = []
        touches_edge = False
        while queue:
            y, x = queue.popleft()
            component.append((y, x))
            touches_edge = touches_edge or y == 0 or x == 0 or y == height - 1 or x == width - 1
            for delta_y, delta_x in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                next_y, next_x = y + delta_y, x + delta_x
                if (
                    0 <= next_y < height
                    and 0 <= next_x < width
                    and hard_white[next_y, next_x]
                    and not seen[next_y, next_x]
                ):
                    seen[next_y, next_x] = True
                    queue.append((next_y, next_x))
        if touches_edge or len(component) >= 80:
            for y, x in component:
                background[y, x] = True

    # Grow through off-white antialiasing around selected background regions.
    loose_white = (minimum >= 215) & (spread <= 38) & (original_alpha > 0)
    queue = deque((int(y), int(x)) for y, x in zip(*np.where(background)))
    while queue:
        y, x = queue.popleft()
        for delta_y, delta_x in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            next_y, next_x = y + delta_y, x + delta_x
            if (
                0 <= next_y < height
                and 0 <= next_x < width
                and loose_white[next_y, next_x]
                and not background[next_y, next_x]
            ):
                background[next_y, next_x] = True
                queue.append((next_y, next_x))
    return background


def process_avatar(source: Path) -> Image.Image:
    rgba = np.asarray(Image.open(source).convert("RGBA"), dtype=np.uint8).copy()
    background = _background_mask(rgba)
    foreground = Image.fromarray((~background).astype(np.uint8) * 255, "L")
    foreground = foreground.filter(ImageFilter.GaussianBlur(0.55))
    rgba[:, :, 3] = np.minimum(rgba[:, :, 3], np.asarray(foreground))

    visible_y, visible_x = np.where(rgba[:, :, 3] > 10)
    if visible_x.size == 0:
        raise ValueError(f"No avatar content remained after background removal: {source}")
    bounds = (
        int(visible_x.min()),
        int(visible_y.min()),
        int(visible_x.max()) + 1,
        int(visible_y.max()) + 1,
    )
    content = Image.fromarray(rgba, "RGBA").crop(bounds)
    scale = min(240.0 / content.width, 240.0 / content.height)
    size = (round(content.width * scale), round(content.height * scale))
    content = content.resize(size, Image.Resampling.LANCZOS)
    output = Image.new("RGBA", (256, 256))
    output.alpha_composite(content, ((256 - size[0]) // 2, (256 - size[1]) // 2))
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--backup-dir",
        type=Path,
        default=ROOT.parent / "tmp" / "avatar-white-backup",
    )
    args = parser.parse_args()
    backup_dir = args.backup_dir.resolve()

    for source in sorted(AVATARS.glob("*.png")):
        backup = backup_dir / source.name
        backup.parent.mkdir(parents=True, exist_ok=True)
        if not backup.exists():
            shutil.copy2(source, backup)
        output = process_avatar(source)
        output.save(source, optimize=True)
        transparent = np.asarray(output)[:, :, 3] <= 8
        print(f"PREPARED {source.name}: transparent={transparent.mean():.1%}")


if __name__ == "__main__":
    main()
