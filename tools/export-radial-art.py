"""Deterministic wheel geometry, with native WoW labels/icons layered in-game."""
from pathlib import Path
import math
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / '.tools/pydeps'))
from PIL import Image, ImageDraw

out = Path(__file__).resolve().parents[1] / 'WoWEnhancedController/Media/Radial'
out.mkdir(parents=True, exist_ok=True)
size, factor = 512, 2
for count in range(1, 10):
    for selected in (False, True):
        image = Image.new('RGBA', (size * factor, size * factor))
        draw = ImageDraw.Draw(image)
        def point(radius, angle):
            return ((256 + math.sin(angle) * radius) * factor,
                    (256 - math.cos(angle) * radius) * factor)
        for slot in range(1 if selected else count):
            half = math.pi / count
            middle = slot * 2 * half
            # Thin gaps separate wedges; ring and hub retain a continuous rim.
            gap = .012 if count > 1 else 0
            start, stop = middle - half + gap, middle + half - gap
            arc = [start + (stop - start) * i / 96 for i in range(97)]
            polygon = [point(248, a) for a in arc] + [point(114, a) for a in reversed(arc)]
            draw.polygon(polygon, fill=(110, 78, 23, 230) if selected else (31, 28, 21, 246))
            draw.line(polygon + [polygon[0]], fill=(242, 206, 107, 255) if selected else (136, 113, 62, 255), width=(3 if selected else 1) * factor)
        if not selected:
            for radius, color, width in [(251,(211,179,96,255),3),(110,(199,165,85,255),2),(106,(99,80,40,255),1)]:
                r = radius * factor
                draw.ellipse((256*factor-r,256*factor-r,256*factor+r,256*factor+r), outline=color, width=width*factor)
        image = image.resize((size,size), Image.Resampling.LANCZOS)
        image.save(out / f'{"Highlight" if selected else "Wheel"}{count}.tga', compression=None)
print('Exported 18 radial textures.')
