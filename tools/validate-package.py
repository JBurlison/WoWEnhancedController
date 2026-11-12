from pathlib import Path
import hashlib
import json
import zipfile
import struct
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
addon = root / "WoWEnhancedController"
package = root / "dist/WoWEnhancedController-0.1.0-forever.zip"
toc = addon / "WoWEnhancedController.toc"
loads = [line.strip() for line in toc.read_text().splitlines() if line.strip() and not line.startswith("#")]
expected = {"WoWEnhancedController.toc", "Bindings.xml", *loads}
expected.update(path.relative_to(addon).as_posix() for path in (addon / "Media").rglob("*") if path.is_file())
icon_line = next(line for line in toc.read_text().splitlines() if line.startswith("## IconTexture:"))
icon_ref = icon_line.split(":", 1)[1].strip()
icon_prefix = "Interface\\AddOns\\WoWEnhancedController\\"
assert icon_ref.startswith(icon_prefix), icon_ref
icon_path = icon_ref[len(icon_prefix):].replace("\\", "/")
assert icon_path in expected, icon_path
icon = (addon / icon_path).read_bytes()
width, height = struct.unpack_from("<HH", icon, 12)
assert icon[1:3] == bytes((0, 2)) and icon[16] == 32, "Icon must be uncompressed true-color RGBA TGA"
assert width == height == 128 and len(icon) >= 18 + width * height * 4, "Invalid icon dimensions/data"
bindings = ET.parse(addon / "Bindings.xml").getroot()
headers = [binding.attrib["header"] for binding in bindings if "header" in binding.attrib]
assert len(headers) == len(set(headers)), "Binding headers must be declared once per section"
hashes = {}
with zipfile.ZipFile(package) as archive:
    actual = {name for name in archive.namelist() if not name.endswith("/")}
    assert actual == {"WoWEnhancedController/" + name for name in expected}, actual
    for name in sorted(expected):
        source = (addon / name).read_bytes()
        assert source == archive.read("WoWEnhancedController/" + name), name
        hashes[name] = hashlib.sha256(source).hexdigest()
report = {"target": "forever", "version": "0.1.0", "sourcePin": "9dc84f0d3bbae1768ac3405b3716000bd93eda06",
          "packageSha256": hashlib.sha256(package.read_bytes()).hexdigest(), "files": hashes}
(root / "dist/manifest.json").write_text(json.dumps(report, indent=2) + "\n")
print(f"PASS: {len(expected)} packaged files match source; TOC and Bindings.xml valid; SHA-256 manifest saved.")
