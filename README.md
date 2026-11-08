# Enhanced Controller

A controller keyboard for **WoW Forever**, interface 16001, with native gold artwork and Xbox prompts by default. It opens for a newly focused editable field in controller mode and edits that actual field immediately. The normal keyboard has no duplicate text box. It starts closed at login; explicit Options and Edit Mode previews remain available.

## Install

Extract `dist/WoWEnhancedController-0.1.0-forever.zip` into the Forever client's `Interface/AddOns` folder. To create the ZIP from a checkout, follow the build instructions below. The resulting file is `Interface/AddOns/WoWEnhancedController/WoWEnhancedController.toc`. Restart WoW after this update to load the updated file list, including NativeField.lua. If CompactKeyboard is installed, disable one of the two keyboards before reloading; this addon detects the conflict without disabling other addons or changing global bindings/CVars.

## Controls

| Action | Xbox | PlayStation | Nintendo default |
|---|---|---|---|
| Select highlighted control | A | Cross | A (east) |
| Close keyboard, keep edits | B | Circle | B (south) |
| Delete | X | Square | Y |
| Shift | Y | Triangle | X |
| Space | Right stick click | R3 | RS |
| Move caret | LB / RB | L1 / R1 | L / R |
| Clear field | Left stick click | L3 | LS |
| Symbols | Select Symbols | Select Symbols | Select Symbols |
| Send / Done | RT | R2 | ZR |
| Focus | View | Left menu | Minus |
| Phrases & bindings | Menu | Options | Plus |
| Phrase layer | LT + assigned face button | L2 + assigned face button | ZL + assigned face button |

The icon-only Focus control sits on the center of the bottom border, outside navigation rows, like the native bag focus hint. Focus is reserved; View refocuses without submitting. Action remapping, optional Auto detection, PlayStation/Nintendo images and Nintendo confirm/back swap are available in Options. Remapping rejects conflicts; shoulders select an action, left-stick click unbinds, and Focus finishes. One-time schema migrations correct prior default mappings while retaining other custom assignments. Native open/focus bindings start unassigned.

## Text, commands and quantities

Keys, phrases, paste, clear, undo and numeric adjustments update the selected native EditBox immediately. Native selection replacement, caret changes and physical typing are reflected in the controller editor. Switching to another field changes the owner; stale, hidden, recycled, forbidden and password fields are rejected. Close keeps the edits already in the field. Copy/paste uses an addon-local buffer, not the operating system clipboard.

**Chat Send invokes the actual chat field's native Enter handler.** WoW handles slash/addon commands, localized channel prefixes, whispers, autocomplete, history and sticky channels. Typing `/p ` can immediately switch the destination and phrase context. No custom slash parser, raw chat-message fallback, private focus-manager mutation or synthetic keyboard/hardware event is used. Native secure-command restrictions still apply; protected-action behavior requires actual-client testing. Generic-field Done closes the keyboard without invoking purchase/craft/search Enter handlers.

Numeric amount mode uses D-pad up/down for one and left/right for ten, clamped to exposed limits. Delete's face button switches to digit mode; Shift's face button deletes. Numeric presets replace the quantity. Unknown maxima remain unknown. Use the original window's own purchase/craft action afterward.

## Phrases and layout

Each context has four slots and shortcut bindings, with specific context → all chat → global precedence. Party, Guild, whispers, numbered channels by name, AH search and quantities can have separate phrases. The former One moment starters are now **Group?**; custom text is retained. Phrases insert text and wait for explicit Send.

In Phrases & bindings, choose slot/scope, Edit phrase, then **Save**. Only this composition mode creates an addon-owned text field; composing does not change the original field. Insert phrase uses the saved text in the native field. Delete custom restores inherited text. Choose Unbound to resolve shortcut conflicts. Channel selection changes the native chat destination and restores that context's in-memory draft; drafts are not written to SavedVariables.

**Options → Text** changes font size independently of window Scale: 12–20 pt, default 14. Normal/hover/disabled fonts are addon-owned copies; native field/shared fonts are untouched. At 20 pt the keyboard stays the same size; long phrase cards can ellipsize, with their text available in the phrase library and native field after insertion. The normal keyboard is 708 × 364 UI units, about 42% shorter than its original 629-unit height. Shared 24-unit content gutters remain. App title, repeated headings and permanent footer instructions are removed; the repeated destination/channel caption is removed. Informative numeric bounds, phrase-edit details and brief action/error feedback allocate a caption only when needed.

The default position is above ChatFrame1. Native Edit Mode exposes addon-owned position controls: move/drag, reset above chat, Save and Cancel, stored per native layout. Positions affect this addon only. The original suite crest appears in the AddOns list and minimap addon menu; selecting its native menu entry opens Options. Shared artwork, game/store exports and prompts are in `branding/`.

## Commands and validation

- `/wec`: Options; `/wec open`: focused field or Options.
- `/wec focus`: explicitly reacquire the existing field/keyboard.
- `/wec layout`: position controls; `/wec on` and `/wec off`: activation.
- `/wec diag`: build/mode/capture and raw callback counts, without logging text.

All **26 Lua 5.1 host checks** pass. The 14-file package and installed copy are checked against the SHA-256 manifest. UIForever 1.60.1.70450/interface 16001 passed live native-field editing, real canvas key/tab clicks, refocus/undo, native slash and addon-command handling, quantities without Enter execution, isolated phrase composition, startup suppression and 20 pt layout checks at 1080p. Registered gamepad callbacks were invoked from Lua with explicit neutral fixtures; no physical controller was attached. Final isolated diagnostics were clean. The simulator predates source 1.60.1.70862 at 9dc84f0d3bbae1768ac3405b3716000bd93eda06; real-controller input priority, secure/combat behavior, native-field breadth and actual restart persistence remain pending.

## Build and test

Use Python 3 with `lupa` for the Lua 5.1 host checks, and PowerShell for packaging. Run these commands from the repository root:

```powershell
python -m pip install lupa
python tests/test_addon.py
./tools/package.ps1
python tools/validate-package.py
```

The validator checks the TOC, binding headers, artwork format and exact ZIP contents, then writes `dist/manifest.json` with SHA-256 hashes. Generated packages, local caches and private design evidence are excluded from Git.

The shipped branding assets are ready to use. Regenerating their size/format exports with `python tools/export-branding.py` additionally requires Pillow (`python -m pip install Pillow`).
