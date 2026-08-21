#!/usr/bin/env python3
from pathlib import Path
from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT_ROOT / "assets" / "images" / "fuguang_app_icon.png"
RES_DIR = PROJECT_ROOT / "android" / "app" / "src" / "main" / "res"
DENSITIES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

if not SOURCE.exists():
    raise FileNotFoundError(f"Source icon not found: {SOURCE}")

with Image.open(SOURCE) as raw:
    icon = raw.convert("RGBA")
    for density_dir, size in DENSITIES.items():
        target_dir = RES_DIR / density_dir
        target_dir.mkdir(parents=True, exist_ok=True)
        rendered = icon.resize((size, size), Image.Resampling.LANCZOS)
        for icon_name in ("ic_launcher.png", "ic_launcher_round.png"):
            rendered.save(target_dir / icon_name, "PNG", optimize=True)

print("Generated Android launcher icons from full-bleed source image.")
