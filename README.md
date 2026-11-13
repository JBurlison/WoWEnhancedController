# Enhanced Controller

Enhanced Controller adds an on-screen keyboard, quick chat messages, and a party and raid spell wheel to **WoW Forever**. You can heal a party member while keeping the boss targeted, link a quest in chat, or build a macro with your gamepad.

## Install and get started

1. Install [Enhanced Controller on CurseForge](https://www.curseforge.com/wow/addons/enhanced-controller) for WoW Forever. For a manual install, download the Forever addon ZIP from [GitHub Releases](https://github.com/JBurlison/WoWEnhancedController/releases) and extract the `WoWEnhancedController` folder into `World of Warcraft/_forever_/Interface/AddOns/`.
2. At character select, open **AddOns** and enable **Enhanced Controller**. If you also use CompactKeyboard, enable just one of the two keyboards.
3. In game, click the controller icon on the minimap or type `/wec menu` to open the launcher. Open **Settings → AddOns → Enhanced Controller** to change bindings, choose Xbox, PlayStation, or Nintendo button prompts, or adjust the text size.

## Type and chat

Outside combat, select a chat or search field with your gamepad to open the keyboard. Use the D-pad to highlight a key. The on-screen prompts show your current bindings.

The keyboard opens with the game world visible between the keys. In **Settings → AddOns → Enhanced Controller → Keyboard appearance**, turn on **Background** for a dark panel behind the keyboard and Quick messages, **Border** for a gold outline, or both.

| Default keyboard action | Xbox | PlayStation | Nintendo |
| --- | --- | --- | --- |
| Select a key | A | Cross | A |
| Delete a character | X | Square | Y |
| Insert a space | Click right stick | R3 | Click right stick |
| Send chat or finish editing | RT | R2 | ZR |
| Close and keep your edits | B | Circle | B |

Choose **Quick messages** in the launcher to assign phrases to shortcuts. For example, save “Ready for the next pull” with **Send to** set to **Party**. With chat open, hold the assigned bumper or trigger and press its face button to send the phrase. Your current draft stays in place when you send to a pinned channel.

Choose **Link in chat** to share an item, recipe, or quest. Selecting a quest title includes its unfinished objectives. Select a single objective to share only that progress.

## Use the party and raid wheel

With either healing mode, playing solo opens the wheel directly on your spells. Point at a spell and confirm to cast it on yourself. Back closes the wheel.

In a party or raid, use the default **Hold & sweep** controls:

1. Click the right stick to open the wheel. In a raid, choose a group first.
2. Point the right stick at an ally and hold the left trigger to select them. The wheel shows health and debuffs you can dispel.
3. While holding the trigger, point at a spell. Release to cast on that ally, or release over the center to cancel.

You can keep moving with the left stick while any wheel is open. The right stick aims the wheel and controls the camera again when it closes.

Use the shoulder buttons to switch spell pages. If you prefer to confirm the ally and spell separately, choose **Classic** under **Healing wheel behavior** in settings. Open **Wheel spells / macros** to add learned spells or saved macros, arrange their slots, and save your layout.

Choose **Target only** under **Healing wheel behavior** to use the wheel for quick targeting. Press the wheel shortcut while solo to target yourself immediately. In a party, point at a member and let the stick return to center. In a raid, choose a group first, then a member. The wheel closes as soon as you select your target.

To keep a healing mode on your usual shortcut, bind **Open targeting wheel** to a second button or use `/click WoWEnhancedControllerWheelTarget` in a macro. If you open Target only from the launcher or `/wecwheel` while solo, press confirm once to select yourself.

## Macros, minimap buttons, and inventory

- **Create a macro.** Open **Macro creator** in the launcher. Choose a template or start from scratch, select your spells and conditions, and review the commands. **Save & bind** lets you place the macro on your controller bar.
- **Browse minimap buttons.** Type `/wec minimap` outside combat, then use the D-pad to highlight a button and confirm to open it. You can assign a shortcut to **Navigate minimap buttons** in WoW’s key bindings.
- **Move a stack at the bank or mailbox.** Highlight the item and choose **Move to bank**, **Move to bags**, or **Attach to mail**. To use a single button, assign **Quick move bank / mail item** in key bindings. Review the mail draft and press **Send** when you’re ready.

## Help

If the keyboard doesn’t appear, try selecting a chat field with the controller outside combat. Auction House quantity fields use WoW’s own controls. If the minimap icon is hidden, `/wec menu` still opens the launcher and `/wec settings` opens settings.

[Report a problem](https://github.com/JBurlison/WoWEnhancedController/issues) with your addon version, controller type, and the steps that reproduce it.
