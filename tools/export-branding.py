"""Export the selected generated artwork without changing its composition."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
exports = root / "branding/exports"
media = root / "WoWEnhancedController/Media"
exports.mkdir(parents=True, exist_ok=True)
media.mkdir(parents=True, exist_ok=True)

for name, source in (("suite-mark", "suite-mark-transparent-v2.png"), ("controller", "controller-icon-transparent-v2.png")):
    with Image.open(root / "branding/source" / source) as original:
        assert original.width == original.height, "Artwork must be square"
        image = original.convert("RGBA")
        alpha = image.getchannel("A")
        assert alpha.getextrema() == (0, 255), f"{source} must contain transparent and opaque pixels"
        assert alpha.getpixel((0, 0)) == 0, f"{source} must have a clear background"
        image.resize((400, 400), Image.Resampling.LANCZOS).save(exports / (name + "-400.png"), optimize=True)
        if name == "controller":
            icon = image.resize((128, 128), Image.Resampling.LANCZOS)
            icon.save(media / "Icon.tga", format="TGA", compression=None)
            icon.save(exports / "controller-128.png", optimize=True)
            for size in (20, 32, 64):
                image.resize((size, size), Image.Resampling.LANCZOS).save(exports / (f"controller-{size}.png"))

print("Exported 400px suite/controller PNGs, 128px uncompressed RGBA TGA, and small previews.")
