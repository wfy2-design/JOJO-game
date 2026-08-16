"""Verify that imported character art is present in GPU-rendered Godot captures."""

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "tests" / "artifacts"
CHARACTERS = ROOT / "assets" / "characters"


def load_rgb(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.int16)


def match_texture(
    screenshot: np.ndarray,
    source: Path,
    max_size: float,
    center: tuple[float, float],
    search_radius: int = 16,
) -> tuple[float, tuple[int, int], tuple[int, int]]:
    image = Image.open(source).convert("RGBA")
    scale = max_size / max(image.size)
    size = (round(image.width * scale), round(image.height * scale))
    texture = np.asarray(image.resize(size, Image.Resampling.BILINEAR), dtype=np.int16)
    mask = texture[:, :, 3] >= 245
    ys, xs = np.where(mask)
    rng = np.random.default_rng(7)
    selection = rng.choice(len(xs), min(600, len(xs)), replace=False)
    xs, ys = xs[selection], ys[selection]
    values = texture[ys, xs, :3]
    expected = (round(center[0] - size[0] / 2), round(center[1] - size[1] / 2))
    best = (float("inf"), expected)
    for y in range(expected[1] - search_radius, expected[1] + search_radius + 1):
        for x in range(expected[0] - search_radius, expected[0] + search_radius + 1):
            observed = screenshot[y + ys, x + xs]
            score = float(np.mean(np.abs(observed - values)))
            if score < best[0]:
                best = (score, (x, y))
    return best[0], best[1], expected


def assert_watermarks_transparent() -> None:
    folders = {
        "portraits": lambda width, height: (width - 210, height - 70, width - 8, height - 8),
        "units": lambda width, height: (width - 105, height - 42, width - 5, height - 5),
        "critical": lambda _width, _height: (1498, 877, 1668, 932),
    }
    for folder, rect_for_size in folders.items():
        for path in sorted((CHARACTERS / folder).glob("*.png")):
            image = np.asarray(Image.open(path).convert("RGBA"))
            height, width = image.shape[:2]
            x0, y0, x1, y1 = rect_for_size(width, height)
            interior = image[y0 + 6 : y1 - 6, x0 + 6 : x1 - 6, 3]
            if interior.size == 0 or np.any(interior != 0):
                raise AssertionError(f"Watermark area is not transparent: {path}")
            print(f"PASS watermark cleared: {folder}/{path.name}")


def assert_targeting_feedback() -> None:
    targeting = load_rgb(ARTIFACTS / "battle_targeting.png")
    selected = load_rgb(ARTIFACTS / "battle_selected_target.png")

    # Capture setup places 100% and 60% targets at these cell centers.
    near_patch = targeting[306:317, 660:671].astype(np.float32)
    far_patch = targeting[404:415, 857:868].astype(np.float32)
    near_color = np.median(near_patch, axis=(0, 1))
    far_color = np.median(far_patch, axis=(0, 1))
    near_redness = near_color[0] - (near_color[1] + near_color[2]) * 0.5
    far_redness = far_color[0] - (far_color[1] + far_color[2]) * 0.5
    if near_redness <= far_redness + 35.0:
        raise AssertionError(
            f"Hit heatmap depth is unclear: near={near_color}, far={far_color}"
        )
    print(
        "PASS hit heatmap depth: "
        f"near={near_color.astype(int)}, far={far_color.astype(int)}"
    )

    changed = np.max(np.abs(selected - targeting), axis=2) > 8
    red = (
        (selected[:, :, 0] > 120)
        & (selected[:, :, 0] > selected[:, :, 1] * 1.8)
        & (selected[:, :, 0] > selected[:, :, 2] * 1.25)
        & changed
    )
    red_pixels = int(red[285:335, 650:750].sum())
    if red_pixels < 300:
        raise AssertionError(f"Selected-target red ring is missing: {red_pixels} pixels")
    print(f"PASS selected-target red ring: {red_pixels} pixels")


def assert_status_avatars() -> None:
    battle = load_rgb(ARTIFACTS / "battle_main.png")
    names = [
        "night_chain",
        "mirror_tide",
        "sun_blade",
        "crimson_thorn",
        "molten_core",
        "frost_wing",
    ]
    expected_tops = [366, 411, 456, 515, 560, 605]

    for name, expected_y in zip(names, expected_tops):
        source = Image.open(CHARACTERS / "avatars" / f"{name}.png").convert("RGBA")
        avatar = np.asarray(source.resize((42, 42), Image.Resampling.BILINEAR), dtype=np.int16)
        transparent_ratio = float(np.mean(avatar[:, :, 3] <= 8))
        if transparent_ratio < 0.20:
            raise AssertionError(
                f"Status avatar still has an opaque background for {name}: "
                f"transparent={transparent_ratio:.1%}"
            )
        opaque = avatar[:, :, 3] >= 245
        expected_x = 24
        best = (float("inf"), (expected_x, expected_y))
        for y in range(expected_y - 5, expected_y + 6):
            for x in range(expected_x - 5, expected_x + 6):
                observed = battle[y : y + 42, x : x + 42]
                score = float(np.mean(np.abs(observed[opaque] - avatar[:, :, :3][opaque])))
                if score < best[0]:
                    best = (score, (x, y))
        if best[0] >= 45.0:
            raise AssertionError(f"Status avatar missing for {name}: mae={best[0]:.2f}")

        print(
            f"PASS transparent unobscured status avatar {name}: "
            f"mae={best[0]:.2f}, transparent={transparent_ratio:.1%}"
        )


def main() -> None:
    assert_watermarks_transparent()
    assert_targeting_feedback()
    assert_status_avatars()
    battle = load_rgb(ARTIFACTS / "battle_main.png")
    critical = load_rgb(ARTIFACTS / "battle_critical.png")
    if battle.shape[:2] != (720, 1280):
        raise AssertionError(f"Unexpected capture size: {battle.shape[:2]}")

    units = [
        ("night_chain", 46.4, (587.2, 140.8)),
        ("mirror_tide", 46.4, (644.8, 148.8)),
        ("sun_blade", 46.4, (702.4, 140.8)),
        ("crimson_thorn", 60.8, (587.2, 468.8)),
        ("molten_core", 46.4, (644.8, 476.8)),
        ("frost_wing", 46.4, (702.4, 468.8)),
    ]
    for name, max_size, center in units:
        score, position, expected = match_texture(
            battle, CHARACTERS / "units" / f"{name}.png", max_size, center
        )
        drift = max(abs(position[0] - expected[0]), abs(position[1] - expected[1]))
        if score >= 50.0 or drift > 4:
            raise AssertionError(
                f"{name} not rendered correctly: mae={score:.2f}, drift={drift}"
            )
        print(f"PASS unit {name}: mae={score:.2f}, drift={drift}px")

    overlay = (slice(126, 540), slice(277, 1013))
    changed = float(
        np.mean(np.max(np.abs(critical[overlay] - battle[overlay]), axis=2) > 20)
    )
    if changed < 0.90:
        raise AssertionError(f"Critical art coverage too low: {changed:.1%}")
    print(f"PASS critical art coverage: {changed:.1%}")

    archive = load_rgb(ARTIFACTS / "menu_archive.png")
    portrait = Image.open(CHARACTERS / "portraits" / "night_chain.png").convert("RGBA")
    rect = (round(314 * 0.8), round(174 * 0.8), round(360 * 0.8), round(600 * 0.8))
    scale = min(rect[2] / portrait.width, rect[3] / portrait.height)
    portrait_size = (round(portrait.width * scale), round(portrait.height * scale))
    portrait_center = (rect[0] + rect[2] / 2, rect[1] + rect[3] / 2)
    score, position, expected = match_texture(
        archive,
        CHARACTERS / "portraits" / "night_chain.png",
        max(portrait_size),
        portrait_center,
        search_radius=6,
    )
    if score >= 20.0:
        raise AssertionError(f"Archive portrait not rendered: mae={score:.2f}")
    print(f"PASS archive portrait: mae={score:.2f}, pos={position}, expected={expected}")

    menu = load_rgb(ARTIFACTS / "menu_main.png")
    primary = np.array([181, 43, 119], dtype=np.int16)
    primary_ratio = float(
        np.mean(np.max(np.abs(menu[:, 400:] - primary), axis=2) <= 8)
    )
    if primary_ratio < 0.15:
        raise AssertionError(f"Menu silhouette missing: {primary_ratio:.1%}")
    print(f"PASS menu silhouette coverage: {primary_ratio:.1%}")
    print("ALL RENDERED ART CHECKS PASSED")


if __name__ == "__main__":
    main()