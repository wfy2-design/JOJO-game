"""Remove white fringing (halo) from the six portrait edges.

The portraits already have transparent backgrounds, but their semi-transparent
edge pixels still carry the original white backdrop color, producing a white
halo on dark UI. This script recolors those fringe pixels using the nearest
opaque foreground pixel while preserving alpha, so the character outline stays
intact and the body (opaque pixels) is never modified.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import shutil

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PORTRAITS = ROOT / "assets" / "characters" / "portraits"

# Seed points sit inside the large white backdrop remnants visible in the
# archive view. Flooding from explicit points keeps intentional whites (the
# Sun Blade weapon and armour, for example) out of the removal mask.
BACKGROUND_SEEDS: dict[str, tuple[tuple[int, int], ...]] = {
    "night_chain.png": ((650, 500), (490, 480)),
    "sun_blade.png": ((635, 500), (600, 1200), (300, 1500), (300, 850)),
    "molten_core.png": ((600, 800), (225, 625), (261, 585)),
}

# Additional low-saturation ground residue is spatially separated from the
# Sun Blade character. These zones deliberately exclude both armoured feet.
BACKGROUND_ERASE_ZONES: dict[str, tuple[tuple[int, int, int, int], ...]] = {
    "sun_blade.png": (
        (0, 1300, 280, 1536),
        (280, 1400, 430, 1536),
        (330, 1390, 430, 1400),
        (430, 1360, 740, 1536),
        (740, 1490, 840, 1536),
        (840, 1300, 930, 1536),
        (930, 1300, 1069, 1536),
    ),
}


def remove_known_white_backdrop(rgba: np.ndarray, name: str) -> np.ndarray:
    """Remove near-white backdrop regions connected to known safe seeds."""
    seeds = BACKGROUND_SEEDS.get(name, ())
    if not seeds:
        return rgba

    rgb = rgba[:, :, :3].astype(np.int16)
    alpha = rgba[:, :, 3]
    minimum = rgb.min(axis=2)
    spread = rgb.max(axis=2) - minimum
    allowed = (alpha > 0) & (minimum >= 180) & (spread <= 70)
    height, width = alpha.shape
    background = np.zeros_like(allowed)
    pending: list[tuple[int, int]] = []

    for x, y in seeds:
        if 0 <= x < width and 0 <= y < height and allowed[y, x]:
            background[y, x] = True
            pending.append((y, x))

    while pending:
        y, x = pending.pop()
        for neighbor_y in range(max(0, y - 1), min(height, y + 2)):
            for neighbor_x in range(max(0, x - 1), min(width, x + 2)):
                if allowed[neighbor_y, neighbor_x] and not background[neighbor_y, neighbor_x]:
                    background[neighbor_y, neighbor_x] = True
                    pending.append((neighbor_y, neighbor_x))

    result = rgba.copy()
    result[background, 3] = 0

    zone_candidate = (alpha > 0) & (minimum >= 100) & (spread <= 80)
    for x0, y0, x1, y1 in BACKGROUND_ERASE_ZONES.get(name, ()):
        zone_alpha = result[y0:y1, x0:x1, 3]
        zone_alpha[zone_candidate[y0:y1, x0:x1]] = 0
    return result


def defringe(rgba: np.ndarray) -> np.ndarray:
    """Recolor white fringe pixels with nearby opaque foreground color."""
    alpha = rgba[:, :, 3]
    rgb = rgba[:, :, :3].astype(np.int16)
    height, width = alpha.shape
    minimum = rgb.min(axis=2)
    spread = rgb.max(axis=2) - minimum
    # White fringe: semi-transparent, near-white, low saturation.
    fringe = (alpha > 0) & (alpha < 255) & (minimum >= 150) & (spread <= 70)
    opaque = alpha >= 250
    result = rgba.copy()
    ys, xs = np.where(fringe)
    for y, x in zip(ys, xs):
        for radius in range(1, 8):
            y0, y1 = max(0, y - radius), min(height, y + radius + 1)
            x0, x1 = max(0, x - radius), min(width, x + radius + 1)
            region = opaque[y0:y1, x0:x1]
            if region.any():
                values = rgba[y0:y1, x0:x1][region][:, :3]
                result[y, x, :3] = np.clip(values.mean(axis=0), 0, 255).astype(np.uint8)
                break
    return result


def tighten_low_alpha_fringe(rgba: np.ndarray) -> np.ndarray:
    """Halve the alpha of remaining low-alpha white fringe (outer halo).

    Only touches semi-transparent near-white pixels with alpha < 60, which sit
    at the outermost edge of the character outline. Opaque body pixels are
    untouched, so the character silhouette is preserved.
    """
    alpha = rgba[:, :, 3]
    rgb = rgba[:, :, :3].astype(np.int16)
    minimum = rgb.min(axis=2)
    spread = rgb.max(axis=2) - minimum
    fringe = (alpha > 0) & (alpha < 60) & (minimum >= 150) & (spread <= 70)
    result = rgba.copy()
    result[:, :, 3] = np.where(fringe, (alpha // 2).astype(np.uint8), alpha)
    return result


def process(source: Path) -> Image.Image:
    rgba = np.asarray(Image.open(source).convert("RGBA"), dtype=np.uint8).copy()
    rgba = remove_known_white_backdrop(rgba, source.name)
    rgba = defringe(rgba)
    rgba = tighten_low_alpha_fringe(rgba)
    return Image.fromarray(rgba, "RGBA")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--backup-dir",
        type=Path,
        default=ROOT.parent / "tmp" / "portrait-white-backup",
    )
    parser.add_argument(
        "portraits",
        nargs="*",
        help="Portrait filenames to process (defaults to every portrait PNG).",
    )
    args = parser.parse_args()
    backup_dir = args.backup_dir.resolve()

    sources = (
        [PORTRAITS / name for name in args.portraits]
        if args.portraits
        else sorted(PORTRAITS.glob("*.png"))
    )
    for source in sources:
        if not source.is_file() or source.suffix.lower() != ".png":
            parser.error(f"Portrait not found: {source}")
        backup = backup_dir / source.name
        backup.parent.mkdir(parents=True, exist_ok=True)
        if not backup.exists():
            shutil.copy2(source, backup)
        output = process(source)
        output.save(source, optimize=True)
        print(f"DEFRINGED {source.name}")


if __name__ == "__main__":
    main()
