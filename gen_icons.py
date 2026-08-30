#!/usr/bin/env python3
"""
Generates Android launcher icons from image.png for all mipmap densities.
Usage: python3 gen_icons.py
Requires: pip install Pillow
"""
import os, subprocess, sys

# Auto-install Pillow if needed
try:
    from PIL import Image
except ImportError:
    print("Installing Pillow...")
    subprocess.run([sys.executable, "-m", "pip", "install", "Pillow", "--quiet"], check=True)
    from PIL import Image

import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'image.png')
RES = os.path.join(HERE, 'android', 'app', 'src', 'main', 'res')

DENSITIES = {
    'mipmap-mdpi':    48,
    'mipmap-hdpi':    72,
    'mipmap-xhdpi':   96,
    'mipmap-xxhdpi':  144,
    'mipmap-xxxhdpi': 192,
}

print(f"Source: {SRC}")
img = Image.open(SRC).convert('RGBA')

for dname, size in DENSITIES.items():
    d = os.path.join(RES, dname)
    os.makedirs(d, exist_ok=True)

    # --- FIT (contain) mode: preserve aspect ratio, center on black bg ---
    padding = max(4, size // 8)          # leave some breathing room
    inner = size - padding * 2           # usable area inside padding

    # Scale image to fit within inner×inner, preserving aspect ratio
    resized = img.copy()
    resized.thumbnail((inner, inner), Image.LANCZOS)

    # Center on a black background canvas of the full icon size
    bg = Image.new('RGB', (size, size), (0, 0, 0))
    x = (size - resized.width) // 2
    y = (size - resized.height) // 2
    bg.paste(resized, (x, y), mask=resized.split()[3])

    out = os.path.join(d, 'ic_launcher.png')
    bg.save(out, 'PNG')
    shutil.copy(out, os.path.join(d, 'ic_launcher_round.png'))
    print(f"  ✓ {dname}/ic_launcher.png  ({size}x{size}, inner={inner}px)")

print("\nAll icons generated!")
print("Next: flutter run -d emulator-5554")
