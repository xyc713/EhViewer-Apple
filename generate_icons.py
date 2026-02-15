#!/usr/bin/env python3
"""Generate iOS/macOS app icons from Android adaptive icon layers."""
from PIL import Image
import os

# Paths
android_res = "/Users/felix/program/Stellatrix/ehviewer/app/src/main/res/mipmap-xxxhdpi"
output_dir = "/Users/felix/program/Stellatrix/ehviewer apple/ehviewer apple/ehviewer apple/Assets.xcassets/AppIcon.appiconset"

fg_path = os.path.join(android_res, "ic_launcher_foreground.png")
bg_path = os.path.join(android_res, "ic_launcher_background.png")

fg = Image.open(fg_path).convert("RGBA")
bg = Image.open(bg_path).convert("RGBA")
print(f"Foreground: {fg.size}, Background: {bg.size}")

# Composite foreground over background
composite = bg.copy()
composite.paste(fg, (0, 0), fg)

# Android adaptive icons have ~25% safe zone padding
# Crop center portion for iOS (remove padding, keep some for corner rounding)
size = composite.width  # 432
crop_ratio = 0.20
crop_px = int(size * crop_ratio)
cropped = composite.crop((crop_px, crop_px, size - crop_px, size - crop_px))
print(f"Cropped to: {cropped.size}")

# iOS 1024x1024
ios_icon = cropped.resize((1024, 1024), Image.LANCZOS)
ios_icon.save(os.path.join(output_dir, "AppIcon.png"), "PNG")
print("Generated: AppIcon.png (1024x1024)")

# macOS icon sizes
mac_sizes = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png"),
]

for base_size, scale, filename in mac_sizes:
    px = base_size * scale
    icon = cropped.resize((px, px), Image.LANCZOS)
    icon.save(os.path.join(output_dir, filename), "PNG")
    print(f"Generated: {filename} ({px}x{px})")

print("\nAll icons generated!")
