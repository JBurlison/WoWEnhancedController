# Contributing to Enhanced Controller

## Build and test

From the repository root, run the addon tests, build the installable ZIP, and validate its contents:

```powershell
python -m pip install lupa==2.8
python -m unittest discover -s tests
./tools/package.ps1
python tools/validate-package.py
```

The ZIP and SHA-256 manifest are written to `dist/`. The validator checks the TOC, binding headers, icon format, and packaged files against the addon source.

## Prepare a release

1. Set `## Version` in `WoWEnhancedController/WoWEnhancedController.toc` and `W.version` in `WoWEnhancedController/Namespace.lua` to the same, higher `MAJOR.MINOR.PATCH`.
2. Open a PR to `main`. The **Addon release** check runs the tests. For a version bump, it also uploads the validated Forever ZIP and its SHA-256 checksum as a workflow artifact.
3. Merge the release PR. A version increase on `main` triggers a fresh build, a `v<version>` tag on the merged commit, and a GitHub Release. The tag push triggers packaging for [CurseForge project 1800162](https://authors.curseforge.com/#/projects/1800162/files).

## Update translations or artwork

- Edit `localization/catalog.json` and run `python tools/localization.py export` to regenerate the locale files and localized TOC descriptions.
- The [branding guide](../branding/README.md) lists the CurseForge avatar, transparent masters, and in-game icon. Install Pillow to regenerate the branding and radial exports with `python tools/export-branding.py` and `python tools/export-radial-art.py`.
