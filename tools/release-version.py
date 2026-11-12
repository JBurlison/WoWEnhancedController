"""Compare the addon version with the PR base or the previous main commit."""
import os
from pathlib import Path
import re
import subprocess
import sys

ADDON = Path("WoWEnhancedController")
TOC = ADDON / "WoWEnhancedController.toc"


def version(text):
    fields = re.findall(r"^## Version:[ \t]*(\S+)[ \t]*$", text, re.MULTILINE)
    if len(fields) != 1 or not re.fullmatch(r"(?:0|[1-9][0-9]*)(?:\.(?:0|[1-9][0-9]*)){2}", fields[0]):
        raise ValueError("Expected one TOC version in MAJOR.MINOR.PATCH format")
    return fields[0]


def main(base):
    if not re.fullmatch(r"[0-9a-f]{40}", base):
        raise ValueError("Expected a full base commit SHA")
    old_toc = subprocess.check_output(["git", "show", f"{base}:{TOC.as_posix()}"], encoding="utf-8")
    previous = version(old_toc)
    current = version(TOC.read_text(encoding="utf-8"))
    namespace = (ADDON / "Namespace.lua").read_text(encoding="utf-8")
    if re.findall(r'^W\.name, W\.version = addonName, "([^"]+)"$', namespace, re.MULTILINE) != [current]:
        raise ValueError("The TOC and Namespace.lua versions must match")
    if tuple(map(int, current.split("."))) < tuple(map(int, previous.split("."))):
        raise ValueError(f"Version decreased from {previous} to {current}")
    changed = current != previous
    print(f"{previous} -> {current} ({'release' if changed else 'unchanged'})")
    if output := os.environ.get("GITHUB_OUTPUT"):
        with open(output, "a", encoding="utf-8") as stream:
            print(f"changed={str(changed).lower()}", f"version={current}", sep="\n", file=stream)


if __name__ == "__main__":
    main(sys.argv[1])
