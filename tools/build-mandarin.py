"""Build the offline, tone-free character indexes from Unicode 17 Unihan.zip.

Usage: python tools/build-mandarin.py path/to/Unihan.zip
Source: https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip
"""
import collections
import hashlib
from pathlib import Path
import re
import sys
import unicodedata
import zipfile

ROOT = Path(__file__).resolve().parents[1] / "WoWEnhancedController"
SHA256 = "f7a48b2b545acfaa77b2d607ae28747404ce02baefee16396c5d2d7a8ef34b5e"


def normalize(reading):
    # Preserve the distinction between lu and lü, while dropping tone marks.
    reading = unicodedata.normalize("NFD", reading).replace("u\u0308", "v")
    return "".join(c for c in reading if not unicodedata.combining(c))


INITIALS = dict(zip("b p m f d t n l g k h j q x zh ch sh r z c s".split(),
                    "ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙ"))
FINALS = dict(zip("a o e ai ei ao ou an en ang eng er i u v ie ve ia iao iu ian in iang ing iong ua uo uai ui uan un uang ong van vn".split(),
                  "ㄚ ㄛ ㄜ ㄞ ㄟ ㄠ ㄡ ㄢ ㄣ ㄤ ㄥ ㄦ ㄧ ㄨ ㄩ ㄧㄝ ㄩㄝ ㄧㄚ ㄧㄠ ㄧㄡ ㄧㄢ ㄧㄣ ㄧㄤ ㄧㄥ ㄩㄥ ㄨㄚ ㄨㄛ ㄨㄞ ㄨㄟ ㄨㄢ ㄨㄣ ㄨㄤ ㄨㄥ ㄩㄢ ㄩㄣ".split()))
ZERO_INITIAL = dict(zip("yi ya yo ye yao you yan yin yang ying yong wu wa wo wai wei wan wen wang weng yu yue yuan yun".split(),
                        "ㄧ ㄧㄚ ㄧㄛ ㄧㄝ ㄧㄠ ㄧㄡ ㄧㄢ ㄧㄣ ㄧㄤ ㄧㄥ ㄩㄥ ㄨ ㄨㄚ ㄨㄛ ㄨㄞ ㄨㄟ ㄨㄢ ㄨㄣ ㄨㄤ ㄨㄥ ㄩ ㄩㄝ ㄩㄢ ㄩㄣ".split()))


def zhuyin(syllable):
    if syllable in {"m", "n", "ng", "hm", "hng"}:
        return {"m": "ㄇ", "n": "ㄋ", "ng": "ㄫ", "hm": "ㄏㄇ", "hng": "ㄏㄫ"}[syllable]
    if syllable in ZERO_INITIAL:
        return ZERO_INITIAL[syllable]
    initial = next((i for i in ("zh", "ch", "sh", syllable[:1]) if syllable.startswith(i) and i in INITIALS), "")
    final = syllable[len(initial):]
    if final == "i" and initial in ("zh", "ch", "sh", "r", "z", "c", "s"):
        return INITIALS[initial]
    if initial in ("j", "q", "x") and final.startswith("u"):
        final = "v" + final[1:]
    if final in FINALS:
        return INITIALS.get(initial, "") + FINALS[final]
    return None


def generate(archive):
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
        raise ValueError("Expected the Unicode 17.0.0 Unihan archive")
    records = collections.defaultdict(dict)
    keep = {"kMandarin", "kHanyuPinyin", "kXHC1983", "kHanyuPinlu", "kSimplifiedVariant",
            "kTraditionalVariant", "kIICore", "kGradeLevel"}
    with zipfile.ZipFile(archive) as z:
        for name in z.namelist():
            for line in z.read(name).decode().splitlines():
                if not line.startswith("U+"):
                    continue
                cp, field, value = line.split("\t")
                if field in keep:
                    records[chr(int(cp[2:], 16))][field] = value
    indexes = {locale: collections.defaultdict(list) for locale in ("zhCN", "zhTW")}
    freq = {}
    for ch, row in records.items():
        freq[ch] = {normalize(r): int(n) for r, n in re.findall(r"([^ ()]+)\((\d+)\)", row.get("kHanyuPinlu", ""))}
    for ch, row in records.items():
        readings = set(freq[ch]) | {normalize(r) for r in row.get("kMandarin", "").split()}
        for field in ("kHanyuPinyin", "kXHC1983"):
            for group in row.get(field, "").split():
                readings.update(normalize(r) for r in group.partition(":")[2].split(","))
        for locale, index in indexes.items():
            # Keep both forms reachable. Put the locale's forms and common readings first.
            variant_field = "kSimplifiedVariant" if locale == "zhCN" else "kTraditionalVariant"
            variants = [chr(int(v, 16)) for v in re.findall(r"U\+([0-9A-F]+)", row.get(variant_field, ""))]
            other_form = bool(variants and ch not in variants)
            simple = [chr(int(v, 16)) for v in re.findall(r"U\+([0-9A-F]+)", row.get("kSimplifiedVariant", ""))]
            for r in readings:
                if not re.fullmatch("[a-zv]+", r):
                    continue
                frequency = max(freq.get(c, {}).get(r, 0) for c in [ch, *simple])
                core = ("G" if locale == "zhCN" else "T") in row.get("kIICore", "")
                index[r].append((other_form, not core, -frequency, int(row.get("kGradeLevel", 99)), ord(ch), ch))
    for locale, index in indexes.items():
        lines = ["-- Generated from Unicode 17.0.0 Unihan by tools/build-mandarin.py.",
                 "-- Distributed under the Unicode License v3 in Unicode-LICENSE.txt.", "local _, W = ...",
                 f'if W.Locale.code ~= "{locale}" then return end', "W.Mandarin = {"]
        for syllable, candidates in sorted(index.items()):
            chars = "".join(entry[-1] for entry in sorted(candidates))
            lines.append(f'    ["{syllable}"] = "{chars}",')
        lines.append("}")
        if locale == "zhTW":
            lines.append("W.Zhuyin = {")
            for syllable in sorted(index):
                spelling = zhuyin(syllable)
                if spelling:
                    lines.append(f'    ["{spelling}"] = "{syllable}",')
            lines.append("}")
        (ROOT / f"Mandarin-{locale}.lua").write_text("\n".join(lines) + "\n", encoding="utf8")
        print(locale, len(index), "readings")


if __name__ == "__main__":
    generate(Path(sys.argv[1]))
