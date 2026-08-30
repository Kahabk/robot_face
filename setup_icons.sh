#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

echo "=== Step 1: Generating launcher icons from image.png ==="
python3 - << 'PYEOF'
import struct, zlib, os, shutil

# Try to use Pillow for proper resizing
try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False
    print("  Pillow not found, will install...")

if not HAS_PIL:
    import subprocess
    subprocess.run(["pip3", "install", "Pillow", "--quiet"], check=True)
    from PIL import Image
    HAS_PIL = True

src = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'image.png')
base = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                    'android', 'app', 'src', 'main', 'res')

configs = {
    'mipmap-mdpi':    48,
    'mipmap-hdpi':    72,
    'mipmap-xhdpi':   96,
    'mipmap-xxhdpi':  144,
    'mipmap-xxxhdpi': 192,
}

img = Image.open(src).convert('RGBA')

for dname, size in configs.items():
    d = os.path.join(base, dname)
    os.makedirs(d, exist_ok=True)
    resized = img.resize((size, size), Image.LANCZOS)
    # Convert to RGB (PNG with no alpha for mipmap compatibility)
    bg = Image.new('RGB', (size, size), (0, 0, 0))
    bg.paste(resized, mask=resized.split()[3])
    out_path = os.path.join(d, 'ic_launcher.png')
    bg.save(out_path, 'PNG', optimize=True)
    # Round icon — same image
    shutil.copy(out_path, os.path.join(d, 'ic_launcher_round.png'))
    print(f'  {dname}: {size}x{size} OK  →  {out_path}')

print('Icons generated!')
PYEOF

echo ""
echo "=== Step 2: flutter pub get ==="
flutter pub get

echo ""
echo "=== Step 3: Build & install (flutter run) ==="
echo "Run:  flutter run -d emulator-5554"
echo "Or:   flutter install -d emulator-5554"
