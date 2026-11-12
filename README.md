# Enhanced Controller

A controller keyboard, macro creator and party/raid spell wheel for **WoW Forever**, interface 16001, with native gold artwork and Xbox prompts by default. The keyboard opens for a newly focused editable field in controller mode and edits that actual field immediately. Windows start closed at login.

## Install

Extract `dist/WoWEnhancedController-0.20.2-forever.zip` into the Forever client's `Interface/AddOns` folder. To create the ZIP from a checkout, follow the build instructions below. The resulting file is `Interface/AddOns/WoWEnhancedController/WoWEnhancedController.toc`. Use `/reload` after updating. Restart WoW when upgrading from the older keyboard-only releases to load the radial files. If CompactKeyboard is installed, disable one of the two keyboards before reloading; this addon detects the conflict without disabling other addons or changing saved bindings/CVars.

Version 0.15.0 routes keyboard controller buttons through temporary bindings, including trigger-modified combinations, to prevent the same press reaching gameplay while typing. Closing the keyboard, losing focus or entering combat releases its bindings; a held button is swallowed until release. Saved bindings are unchanged. All 175 automated checks pass, and UIForever verifies binding ownership and cleanup without Lua errors. The reported casting leak still needs a physical-controller retest in the current client. See the [binding audit](docs/plans/minimap-launcher/KEYBOARD-BINDING-OWNERSHIP.md).

Version 0.14.1 releases controller capture when windows close by mouse, Escape, native field dismissal or parent-window hide. Hidden settings pages and editors clear held input, combat-delayed cleanup finishes after combat, and the spell wheel clears temporary bindings even on direct hides. Native controller menus take input priority. This round passes 166 automated checks plus UIForever lifecycle checks; the reported current-client Blizzard focus-restoration error still needs an in-game retest. See the [lifecycle audit](docs/plans/minimap-launcher/UI-LIFECYCLE-AUDIT.md).

## Wheel return and navigation

After an action, the wheel returns to member selection by default: the party wheel or members of the current raid group. **Options → AddOns → Enhanced Controller → After wheel action** also offers **Reopen on selected member** (keeps the spell page) and **Close after selection**. This follows the action request; failed casts are not retried. Whisper closes the wheel to hand off to native chat.

D-pad **Down** goes back one level and closes at the root. In raids, **Left** opens raid groups and **Right** opens the currently selected group’s members. Party selection starts with you, followed by your party members. The built-in Target previous entry and its L3 shortcut were removed in0.14.3. **LT** holds the recipient in Hold & sweep and confirms in Classic. **D-pad Up** confirms and **LB / RB** change spell pages. Each action requires a fresh press/release. Physical controller and current-client combat/taint testing remain pending.

## Minimap launcher

Left-click the Enhanced Controller minimap icon (or use `/wec menu`) for the keyboard/chat, quick messages, party/raid wheel, macro creator and all configuration pages. Right-click the icon for Settings; drag it around the minimap to reposition it. Native Settings includes **Show minimap button** and a position reset. The native addon compartment also opens the launcher. Opening the menu from a macro immediately enables controller navigation. Press your configured WoW Focus button or click the Focus button at the bottom to keep the current row selected. Closing the launcher restores the usual controller bindings.

`/wec minimap` opens a list of visible native and addon minimap buttons, including LibDBIcon buttons moved by collectors. D-pad Up/Down follows the list and scrolls longer lists; Left/Right or the shoulders switch between Launcher and Minimap buttons. Confirm opens the selected target, X/right-click uses its secondary action, and Back closes. The on-screen prompts follow the controller artwork and Nintendo A-confirm preference; these menu controls are independent of keyboard action remaps. Mouse wheel and keyboard arrows also navigate. The selected button is highlighted on the actual minimap, and capture is released before its UI opens.

**Open Enhanced Controller launcher** and **Navigate minimap buttons** are unassigned entries in native Key Bindings. No existing binding is replaced. Navigation is available outside combat; hidden/disabled buttons are omitted and protected or rejected actions require the cursor. Custom button handlers can differ between addons; native dropdowns and ordinary OnClick/mouse handlers are supported, with target availability checked again before activation. Close an active editor before opening the launcher so its draft and input ownership remain intact.

## Macro creator

Version 0.12.0 adds one Save for all pending wheel edits, an optional Highest learned rank checkbox, and continuous native scrollbars in the macro editor. It also includes the v0.11.1 D-pad atlas crash fix. Wheel edits stay in memory across slots, pages and leaving Settings; Save applies the entire draft together. Unsaved edits are lost on `/reload`. Highest learned rank defaults off, preserving your selected spell rank; enabled uses the native localized-name casting path and follows newly learned ranks.

The combined 0.12.0 build passes 141 host tests and its 59-file package/install hashes match. UIForever verified draft batching, native checkbox activation and the 20-point layout with no Lua errors; actual-client rank casting and physical controller/combat checks remain pending.

The previous version 0.11.0 introduced the wider native macro editor. All 130 host checks pass, and its 59-file package is hash-validated. UIForever 1.60.1.70450 checks in Codex’s browser passed fixed-icon create/edit/duplicate/delete, reload with visual sequence metadata, and paired controller callbacks through the spell menu, keyboard and shared icon picker. The isolated run reported no Lua errors. The simulator does not implement `C_Macro.GetSelectedMacroIcon`, so automatic-icon save verification and physical controller delivery remain actual-client checks.

Open **Settings → AddOns → Enhanced Controller → Macro creator**, or `/wec macros`, outside combat. The 1280×760 window scales to fit the screen and uses at least 18pt body text, with smaller captions and command preview. Account and character macros have separate libraries. Save explicitly; switching macros or closing an edited draft offers Save, Discard or Keep editing. More includes duplication across scopes and confirmed deletion. Existing custom commands remain exact text, including when changing their name or icon.

The visual builder supports ordered conditional casts, cast sequences, trinket slots, utility commands and custom command blocks. Choose learned spells/ranks, targets, modifiers, combat/form conditions and sequence resets. The 28 templates cover nine classes and targeting, modifiers, sequences, gear, pets/forms and utility. Replace spells your character has not learned. Commands shows editable text; the live preview scrolls independently. The scenario preview only illustrates manual assumptions and never executes a command. A failed sequence cast stays on its step; separate action lines are attempted on the same press. The editor cannot insert delays or select spells by cooldown readiness.

D-pad navigates the whole editor, scrolling each list to reveal the selected row. Macro, template, action, sequence and option lists use native scrollbars instead of pages; mouse wheel and scrollbar dragging work too. Confirm selects; Back returns through the current dialog before offering to close the draft. Shoulder actions switch tabs using the current configured bindings. Name, commands and search use the shared controller keyboard; icon selection uses the shared native picker. Both suspend parent navigation and return focus. Search resets scrolling after text entry ends. Combat hides the editor while retaining its draft in memory. Drafts are not a reload-persistent backup.

Macro UI headings and common actions have translations in the nine existing locale packs; new advanced help/errors still use English fallback. Generated translations have not had fluent-speaker review. Native spell/rank/form names come from the client. Macro save checks read back name, text and icon and detect external edits/slot changes. UIForever does not correctly emulate selected-icon readback for automatic icons; actual-client automatic-icon persistence remains unverified.

## Party / raid wheel

**Hold & sweep** is the default under **Options → AddOns → Enhanced Controller → Healing wheel behavior**. Open with R3, point the right stick at an ally on the inner ring and hold LT. Aim at an outer spell and release LT to cast on the pinned ally. The left stick remains available for movement. With a mouse, drag from the inner member to an outer spell and release. Release over the center or an empty slot to cancel. In raids, choose the group first.

If the ally and spell are in the same direction, keep the right stick there and release LT. For example, point straight up at yourself, hold LT to highlight the top spell, then release LT to cast it. With the keyboard defaults, use Left/Right to choose a member, hold Space, use Left/Right to choose the spell and release Space. Page Up/Down or the shoulders change spell pages.

Choose **Classic** for the existing member-then-spell wheel, including LT / D-pad Up confirmation and optional native directional key-up selection. The normal R3 shortcut, `/wec wheel` outside combat, and `/click WoWEnhancedControllerWheelToggle` follow the saved mode. To put both modes on your action bars, create two separate one-line macros:

```text
/click WoWEnhancedControllerWheelSweep
```

```text
/click WoWEnhancedControllerWheelClassic
```

Each fixed-mode opener also has an independent native keybinding. Invoking the other opener switches wheels; invoking the same one closes it. An explicitly bound gamepad shortcut takes precedence over the optional default R3 shortcut.

- Party: member → spell, including yourself.
- Raid: group → member → spell. Each group has five tiny health bars in roster order. Highlight it for member names/health in the center; grey indicates offline/unknown and red indicates dead. Empty slots stay empty. Health never changes wedge order.
- Spells cast directly on the selected member and retain your current target. **Target** is an optional custom-action preset; it changes your target without casting.

Use Options → AddOns → Enhanced Controller → Wheel spells / macros (or `/wec spells`) to add, remove or reorder up to 72 actions across nine pages, with eight configurable slots per page. Profiles are separate per character/class/spec; learned healing spells seed a new profile. The live wheel preview shows the current spell page; select a numbered wedge to edit it. Choose a learned active spell (including known ranks) from the spellbook picker, choose an account or character macro, or use Custom to type a command/macro. Both pickers offer icons, optional search and a continuous list with a native scrollbar. Mouse wheel, dragging the scrollbar and D-pad edge scrolling reach every entry; changing search or source returns to the beginning. Recycled rows reject stale presses. Standard Settings actions use native UIPanelButtonTemplate red buttons; native tabs, radial preview artwork and the keyboard appearance sample retain their own roles. Save commits the selected entry. Add action commits a filled new entry before opening the next slot; an empty new entry opens its picker. Unsaved edits to existing entries stay in drafts until Save, and changing slots retains them until the editor closes. D-pad directions follow visible control positions, including the tabs, action arrows and picker. Spell IDs preserve chosen ranks; saved macros are resolved by name within their original account/character scope. Custom accepts `{unit}` for the selected member, but can also use its own targeting conditions. Existing recipient macros such as `/cast [@{unit},help,nodead] Renew` remain supported. Recipient templates substitute `{unit}` before combat and allow 255 bytes after substitution. Saved macros keep their own conditions: an explicit target can override the chosen member. The wheel cannot determine which unit an arbitrary saved macro actually affected.

Pages always open on Main. Add page creates Left1, Right1, Left2, Right2 and so on; LB/RB follows their spatial order without wrapping. Main stays centered in the dot row. Remove page only removes an empty non-default page. Existing actions migrate in order without losing labels, commands or icons. Select any of the eight preview slots to edit it; drafts survive page/slot changes until the editor closes.

Custom includes Target, Focus, Trade, Duel and Whisper presets plus typed commands. Trade explicitly targets the chosen member before opening trade; native range/combat restrictions still apply. Whisper opens an unsent native draft outside combat and refuses to overwrite an existing draft. Choose icon opens the full native icon catalog with All/Spell/Item filters, scrollbar and search by learned localized spell name, spell ID, or texture ID/filename. It is not a universal semantic search for every game image. D-pad navigates the grid/search/filter; A selects, Y confirms and B cancels with Xbox defaults. Only confirmation changes the action draft; Save commits it.

`/wec wheel`, `/wec radial` and `/wecwheel` open outside combat. R3 and the native **Toggle party / raid spell wheel** CLICK binding are the combat entry paths. Stick highlighting arms above 0.5 magnitude and clears below 0.2; selection requires a genuine confirmation button. Centering when opening the wheel does nothing; held directions, tier changes and disconnects cannot carry a stale selection forward. Confirmation needs a matched down/up pair. Casting uses native secure action buttons; ordinary stick callbacks only draw/capture the camera stick. The left stick remains available for movement. Configuration waits until combat ends. A native roster/name refresh cancels the current selection and clears previous recipient; if this occurs in combat, rebuilding waits until combat ends to avoid casting at a reassigned raid slot.

Member wedges show class-colored health bars, including self; highlight a member for current/max HP and percentage in the center. The spell tier keeps the chosen recipient's current/max HP and percentage visible. Native `HARMFUL|RAID` aura filtering shows debuffs the player can dispel using the client's current spell/spec rules. Wedges show four icons, the center shows five, and overflow is counted. Native debuff borders identify type. Options can hide health bars or dispellable debuffs. Native StatusBar and FontString:SetFormattedText present restricted HP values directly. UnitHealthPercent with the native ScaleTo100 curve supplies percentage text; addon Lua never divides, rounds, concatenates or inspects those restricted values. Truly missing data remains Unknown and never means zero or proof of no debuffs.

Actual-client testing showed that an addon Camera stick callback cannot enter a restricted click closure, even when CheckAllowProtectedFunctions returns true. The unsupported axis-to-click path and its repeated warnings are removed. Return-to-center casting remains unavailable from insecure addon callbacks; native Blizzard flyout behavior does not grant addons the same trust. Genuine hardware-bound and mouse clicks retain the secure action path. No forced secure flags, fake button-down pair or polling casts are used. Earlier simulator stick-selection passes did not model this restriction.

The wheel defaults to screen center. Open **Edit Mode** or **Settings → AddOns → Enhanced Controller → Wheel position**. Move the preview with the left stick or drag it with the mouse. For finer adjustments, choose **Move with D-pad**. **Save position** is selected on entry. Press your confirm binding (RT by default), activate the selected button, or click Save position on the preview. Back cancels unsaved changes. Positions follow the active Edit Mode layout. The spell editor opens in Settings. Font size and overall scale remain shared. Wheel diameter is independently adjustable. Cooldown, range, usability and health appear when the client permits them. Native errors handle failed spell attempts.

## Controls

### Controller bindings

**Options → AddOns → Enhanced Controller → Controller bindings** has separate **Keyboard** and **Gamepad** columns. Expand a section and select a cell to assign it. General shortcuts use WoW’s current binding set. The healing wheel and controller keyboard have separate assignments that apply while each owns input. The same button can hold an ally in the wheel and open the phrase layer while typing. Existing controller keyboard assignments carry over. **Unbind** clears the selected cell. **Reset section** restores that section’s defaults.

Confirm on a section header expands or collapses it. D-pad Up/Down scrolls through the expanded assignments. Down from the last assignment reaches the footer. Left/Right chooses the device, and Right from the Gamepad column jumps to the footer. Back or Escape cancels an assignment in progress. In the Forever controller UI, Back from the page returns to the Settings sidebar. Use Up/Down to choose a category and Right to enter it. Keyboard number-pad keys belong in the Keyboard column.

### Bank and mail quick move

At an open bank or mailbox, highlight an item with the native controller navigation or hover it with the mouse. A small button beneath the service window shows **Move to bank**, **Move to bags**, or **Attach to mail**, with that item's icon. Click it to transfer the whole stack. Mail attachments can be taken from an open message or removed from a draft; attaching a bag item opens the Send Mail tab. Sending the message still uses the native Send button, and COD/refundable-bank confirmations remain native.

For a one-button controller shortcut, assign **Key Bindings → Enhanced Controller → Quick move bank / mail item** to your preferred button (for example, L3). It starts unassigned so existing controls are preserved; its current binding appears beside the action. Native item navigation and Back/close remain unchanged. **Options → AddOns → Enhanced Controller → Enable bank / mail quick move** turns the feature off independently. Transfers are unavailable during combat, text entry, another item/spell cursor operation, or mail sending. Item identity, stack size, bank type and mailbox state are checked again on release.

| Action | Xbox | PlayStation | Nintendo default |
|---|---|---|---|
| Select highlighted control | A | Cross | A (east) |
| Close keyboard, keep edits | B | Circle | B (south) |
| Delete | X | Square | Y |
| Shift | Y | Triangle | X |
| Space | Right stick click | R3 | RS |
| Move caret | Select Left / Right | Select Left / Right | Select Left / Right |
| Clear field | Select Clear all | Select Clear all | Select Clear all |
| Symbols | Left stick click | L3 | LS |
| Send / Done | RT | R2 | ZR |
| Focus | View | Left menu | Minus |
| Toggle message assignment | Menu | Options | Plus |
| Message banks | LB / LT / RB + face button | L1 / L2 / R1 + face button | L / ZL / R + face button |

The icon-only Focus control sits on the center of the bottom border, outside navigation rows, like the native bag focus hint. View refocuses the keyboard without submitting. Native Settings includes optional Auto detection, PlayStation and Nintendo button images, and the Nintendo confirm/back swap. In **Controller bindings**, the D-pad reaches every action and footer button. Back cancels capture or returns the Forever Settings cursor to the sidebar. Conflicting buttons and the reserved Focus button are rejected. Existing custom assignments carry over. The bumpers default to message banks and L3 to Symbols. Caret and Clear all remain selectable controls. A custom binding already using a bumper takes precedence, so unbind it before assigning that bumper to messages. Native open/focus bindings start unassigned.

## Addon settings and languages

Open **Options → AddOns → Enhanced Controller**, the minimap addon menu, or `/wec settings` for native settings. Enable the keyboard/wheel, select controller artwork and activation, adjust font/scale/wheel diameter, toggle health bars, or open the phrase, spell/macro, binding and position editors. Native sliders show their current value. The keyboard has Keyboard and Edit tools tabs; addon preferences live in native Settings. All controls share the same SavedVariables; protected changes defer through combat. The wheel releases R3 while the native settings panel owns input.

The shared UI catalog has 478 translated entries for German, French, Spanish, Italian, Brazilian Portuguese, Russian, Korean, Simplified Chinese and Traditional Chinese. Spanish (Mexico) shares Spanish; English (US/GB) is the base/fallback. `GetLocale()` selects the table. Missing keys or future locales use English. Native spell/class/item data supplies its own localized names. Custom phrases, labels, macro bodies, player names and stable action/context/binding IDs remain unchanged. Automatically seeded spell labels refresh from their spell IDs; explicitly saved labels remain custom.

Localized Latin/Cyrillic keyboard layouts, accented-symbol rows and UTF-8 uppercase handling are included. Text insertion, selection, undo and canned text preserve Unicode. Korean/Chinese use the Latin key layout for direct typing; this addon does not implement a phonetic IME. Native IME composition and physical controller behavior still need client testing. Translations use compact labels where controls are narrow; focus in the spell editor shows the full selected label and native controller glyph.

Edit `localization/catalog.json`, then run `python tools/localization.py export` to regenerate the locale files and localized TOC descriptions. Tests check every exported translation, format arguments, recipient placeholders, locale aliases, English fallback and custom-content preservation.

Keyboard appearance has its own native Settings subcategory, also reachable through Customize on the main addon options page. The keyboard uses a transparent outer layout and individual controller-style keys with fixed corners; focus brightens the rim. Choose Controller, Gold, Classic or Minimal from a list showing actual letter, Space and Send samples for every skin. Controller is the new default. The old Minimal default migrates once; explicit Gold/Classic choices survive, and Minimal remains selectable afterward. Reset appearance restores Controller without resetting text size, scale, bindings or messages. Outer background/border settings are retired. Preferences persist and apply only to the keyboard and its views; radial and general Settings styling are independent. D-pad follows the visible key order, remembers the horizontal position through wide actions and stops at edges. The appearance list uses Up/Down for skins and Left/Right for Reset/Back, with standard A/B and Nintendo confirm-swap behavior. Changes wait until outside combat.

## Text, commands and quantities

Keys, paste, clear, undo and numeric adjustments update the selected native EditBox immediately. Native selection replacement, caret changes and physical typing are reflected in the controller editor. Switching to another field changes the owner; stale, hidden, recycled, forbidden and password fields are rejected. Close keeps the edits already in the field. Copy/paste uses an addon-local buffer, not the operating system clipboard.

**Chat Send invokes the actual chat field's native Enter handler.** WoW handles slash/addon commands, localized channel prefixes, whispers, autocomplete, history and sticky channels. Typing `/p ` can immediately switch the destination and phrase context. No custom slash parser, raw chat-message fallback, private focus-manager mutation or synthetic keyboard/hardware event is used. A completed Send closes the keyboard and releases retained native chat focus, including controller/IM chat. Autocomplete and errors that leave text to review retain the editing session. Native secure-command restrictions still apply; protected-action behavior requires actual-client testing. Generic-field Done closes the keyboard without invoking purchase/craft/search Enter handlers.

**Link in chat** opens the keyboard’s link picker. Cycle through Bags, Equipped, Professions, Recipes and Quests. Under Quests, choose the title to share a clickable link followed by each unfinished objective on its own chat line. Choose an individual objective to share just that objective’s progress after the link. Progress updates when you send. The active tracked quest appears first. Use the D-pad or mouse wheel to scroll, Confirm to insert at the chat selection, and Back to cancel. Recipes come from the currently open profession.

Auction House quantity/count fields stay under native control and do not activate this keyboard, including through its open/focus shortcuts. Auction House search and price inputs remain available.

Numeric amount mode uses D-pad up/down for one and left/right for ten, clamped to exposed limits. Delete's face button switches to digit mode; Shift's face button deletes. Numeric presets replace the quantity. Unknown maxima remain unknown. Use the original window's own purchase/craft action afterward.

## Phrases and layout

Hold LB, LT or RB and press the assigned face button to send a quick message. Each shortcut defaults to **Current chat**. A quick message containing only `/reload` reloads the UI immediately when activated in chat. In **Assign**, choose a highlighted slot, a message and a **Send to** destination. For example, set **Scope** to all chat and **Send to** to Party to use that shortcut while typing in Guild. Choose **Custom message** to open the letter keys, **Done** to return to the assignment, then **Save**. Presets, **Link in chat** and **Current tracked quest** can all use a pinned destination. A tracked quest shortcut resolves the quest and its unfinished objectives each time you use it. In search and other text fields, text shortcuts insert into the field.

Specific context → all chat → global precedence is preserved independently in each bank, including every existing LT message and shortcut binding. Party, Guild, whispers, numbered channels by stable name, AH search and quantities retain their separate contexts. Editing a message does not create a binding override unless its shortcut is changed explicitly. Use inherited restores the underlying phrase; duplicate shortcut choices are skipped until available or Unbound. The Settings Quick messages launcher opens standalone assignment, with a context selector for channels and AH search. During normal typing, the native field selects the context automatically.

The **Channel** button on the main keyboard changes where your typed message goes and restores the draft for the selected channel. Sending a pinned shortcut keeps the current draft and channel. Numbered shortcuts follow the joined channel by name when its number changes.

Native Settings → Font size changes addon text independently of Window scale: 12–20 pt, default14. Normal/hover/disabled fonts are addon-owned copies; native field/shared fonts are untouched. The keyboard grows wider for its side panel and fits the screen; text wraps to two lines on message cards, with the selected message shown below. Assignment mode hides the letter keys and focuses the shortcut choices. Shared24-unit content gutters remain, and the Focus badge stays centered on the bottom edge. Edit Mode moves the whole keyboard and its side panel together.

## Commands and validation

- `/wec`: Options; `/wec open`: focused field or Options.
- `/wec focus`: explicitly reacquire the existing field/keyboard.
- `/wec layout`: position controls; `/wec on` and `/wec off`: activation.
- `/wec wheel` or `/wecwheel`: party / raid wheel (outside combat slash entry).
- `/wec spells`: wheel spell/macro settings (outside combat).
- `/wec macros`: controller macro creator (outside combat). Choose **Bind to toolbar** to open WoW's native controller-bar picker, or **Save & bind** to save a valid draft first. Back returns to the same macro.
- `/wec diag`: build/mode/capture and raw callback counts, without logging text.

The v0.10.0 milestone passed 118 Lua5.1 host checks. They cover keyboard/quick-move contracts plus radial input pairing, secure argument scrubbing, direct recipients, roster invalidation, secret-health transport, eight-slot migration, page ordering, optional friendly actions, draft retention and shared icon-picker search/cancel/scrolling. The security fixture is a contract model, not an emulator of the client's trust boundary. The53-file v0.10.0 package is validated against SHA-256 hashes.

The v0.10.0 UIForever70450 pass verified the native eight-sector wheel, clear pager/footer spacing at14pt/480diameter and20pt/380diameter, real mouse page selection and page creation, and native icon selection/Okay returning a texture to an unsaved draft. Paired controller callback checks covered icon-grid scrolling, search and cancel; a real macro-button click opened the wheel with its R3 override disabled. Final isolated Errors/Missing APIs were empty. The simulator's storage persistence warning prevents a restart-persistence claim. Actual controller delivery, combat casting/taint and current-client acceptance remain pending.

UIForever 1.60.1.70450/interface 16001 previously passed the keyboard's native-field, slash, quantity, composition, startup and font-size checks. Radial native mouse navigation reached raid → member → spell, retained the Hakkar target, recorded raid2 as recipient and closed. The v0.3 wheel-only layout and Settings canvas were checked at 20pt. A custom simulator scenario verified native self HP 7000/10000; it returned no dispel metadata for injected curse/poison spell IDs, so icon placement was reviewed separately with a render-only fixture that was removed by reload. Native dispel filtering still needs actual-client acceptance. In v0.3.1, invoking the registered stick callback through the Lua console advanced to self, requested the selected native spell on a second gesture, closed, and displayed HP1490/1490 and100% with no Lua errors or missing APIs. This exercised simulated callbacks, not physical hardware or real-client security. The simulator's independent AnyDown/AnyUp binding probe delivered down only, so native binding release and physical controller operation remain unverified; no production workaround weakens pairing. The simulator predates source 1.60.1.70862 at 9dc84f0d3bbae1768ac3405b3716000bd93eda06. Real-client combat/taint, input priority/release, disconnect recovery, roster timing and actual restart persistence remain pending.

The v0.6.0 simulator check exercised registered paired button callbacks for LB/RB message banks in both release orders and L3 Symbols on a native chat field. Xbox layouts at14pt and20pt, and all fourteen binding actions in native Settings at20pt, fit the accepted layout. The isolated addon reported no Lua errors or missing APIs. These callback checks do not verify physical-controller input.

The v0.7.0 simulator pass enumerated72bag links and10equipped links, showed native tooltips, inserted a full native item link through paired controller callbacks and real mouse selection, preserved the draft/caret on Back, and blocked Send during browsing. Both14pt and20pt layouts passed with no isolated Lua errors or missing APIs. Its profession overview returned no usable spellbook offsets or active recipe dataset, so profession/recipe insertion still needs in-game verification. The77hostchecks cover those contracts and stale-item/owner/mouse/controller cases.

The v0.7.1 pass replaced pagination with native scrolling. Actual thumb dragging and mouse wheel scrolled the simulator’s72bag items; paired D-pad callbacks moved beyond the fourth visible row and A inserted that item. The scrollbar view is36units shorter at both14pt and20pt. No isolated Lua errors or missing APIs;79hostchecks pass. Physical-controller and actual-client checks remain pending.

The v0.8.0 appearance page was checked in UIForever at 14pt and 20pt. Native mouse selection and paired controller callbacks changed the preview; transparent, borderless, Classic and Minimal styles rendered correctly. Reset restored only appearance, reload retained the chosen styles, and R3 still inserted a space into the native chat field. No isolated Lua errors or missing APIs were reported. All 49 installed files match the validated package. Physical-controller testing remains pending.

## Build and test

Use Python 3 with `lupa` for the Lua 5.1 host checks, and PowerShell for packaging. Run these commands from the repository root:

```powershell
python -m pip install lupa
python -m unittest discover -s tests -v
./tools/package.ps1
python tools/validate-package.py
```

The validator checks the TOC, binding headers, artwork format and exact ZIP contents, then writes `dist/manifest.json` with SHA-256 hashes. Generated packages, local caches and private design evidence are excluded from Git.

The shipped branding assets are ready to use. Regenerating their size/format exports with `python tools/export-branding.py` additionally requires Pillow (`python -m pip install Pillow`).
The radial geometry exports are reproducible with `python tools/export-radial-art.py` using Pillow; labels, hit regions, spell/class art and controller prompts are separate native widgets.

Version 0.4.0 adds the Settings wheel preview and spell/macro pickers. Picker/draft tests cover active learned spells, known flyouts, rank IDs, macro scope and slot shifts, search/paging, controller callbacks, UTF-8 labels, explicit saves and legacy/custom macros. UIForever checks and installation evidence are recorded in the task matrix.

The v0.4.0 editor was reviewed in UIForever at 20pt with native spell icons/ranks, account macro selection and custom text entry. The isolated build reported no Lua errors or missing APIs. A simulated controller callback selected an unsaved draft; physical controller operation remains an actual-client check. The latest 47-file package was installed and hash-verified in the Forever AddOns folder.

Version 0.5.0 implements the approved quick-message combo panel and inline assignment, removes keyboard Options / numbered-slot views, and puts controller remapping in native Settings. The64 host checks include composer mouse-focus recovery, navigation reachability, assignment cancellation, inherited bindings and stable channel keys.

The v0.5.0 keyboard was compared with the approved combo mock-up at14/20pt in UIForever. Mouse assignment and native-field insertion, per-channel paired callbacks, standalone Settings configuration and native Settings remapping passed with no Lua errors or missing APIs in the isolated run. Physical controller acceptance remains pending. All47 installed files match the package hashes; use /reload to load the update from v0.4.0.

Version 0.9.0 replaces spell/macro picker pages with a native scrolling list and uses the standard red game buttons for Settings actions. UIForever checks covered native scrollbar dragging, mouse wheel and item selection, paired D-pad edge scrolling, search, empty macros and 14/20pt layouts. The real-client keyboard-close warning still needs its caller trace; `/wec diag` now records a bounded native stack and shutdown stage, and blocked-event cleanup avoids recursion and duplicate warnings. These diagnostics do not resolve the client's taint restriction or the separate radial stick-centering limitation.

Version 0.9.1 fixes Add action from an empty wheel, uses directional D-pad navigation based on the visible editor layout, and keeps Settings open when its shortcuts select another category. UIForever checks covered an actual Add click committing the pending spell and opening the next slot, paired directional callbacks, and an actual Customize click opening Keyboard appearance. Physical controller acceptance remains pending.

Version 0.9.2 adds LT and D-pad Up as independent secure confirmation bindings, records the direction at button-down, rejects mismatched overlapping releases, and removes the unsupported axis-to-click path and repeated warnings. Native device glyphs show both alternatives. 97 host checks pass; real-client physical trigger/modifier delivery and combat acceptance remain pending. R3 can be disabled independently in Settings, with a dedicated secure `/click WoWEnhancedControllerWheelToggle` macro entry that only toggles the menu. Version0.10.0 implements the subsequently approved native eight-slot skin, pages, optional friendly actions and shared native icon picker.
