# Addon suite icon system

Original artwork made with the built-in `image_gen.imagegen` tool for this project. The suite has no fixed wordmark, so a future group name does not require replacing the artwork. This is original art; no Blizzard texture pixels or game logos are bundled.

The four beveled gold crest segments identify the suite. The central symbol identifies the module: the neutral suite mark uses a four-point spark; Enhanced Controller uses a generic controller. Future modules can replace the center with a bag, book, compass or another feature symbol while retaining the crest, square framing, gold/black palette and safe margins. Keep centers bold enough for the native 16–20px menu icons; avoid words, version numbers and branded controller letters.

## Assets

| File | Purpose |
|---|---|
| source/suite-mark-v1.png | Original suite artwork on charcoal |
| source/controller-icon-v1.png | Original controller artwork on charcoal |
| [source/suite-mark-transparent-v2.png](source/suite-mark-transparent-v2.png) | Transparent suite master |
| [source/controller-icon-transparent-v2.png](source/controller-icon-transparent-v2.png) | Transparent controller master |
| source/suite-frame-transparent-v1.png | 1254px RGBA frame layer, clear center for future modules |
| [exports/suite-mark-400.png](exports/suite-mark-400.png) | Transparent 400×400 suite avatar |
| exports/suite-frame-preview.png | Transparent frame composited on black for preview only |
| [exports/controller-400.png](exports/controller-400.png) | Transparent 400×400 PNG to upload as the Enhanced Controller project logo |
| exports/controller-128.png | In-game export preview |
| exports/controller-{20,32,64}.png | Small-size readability checks |
| ../WoWEnhancedController/Media/Icon.tga | 128×128 uncompressed 32-bit RGBA game texture |

Use the controller avatar in the CurseForge project’s **Logo** field. It is exactly 400×400, as specified in the [CurseForge moderation policy](https://support.curseforge.com/support/solutions/articles/9000197279-moderation-policies). The suite avatar is for the addon family. Only the game texture ships in the addon ZIP.

`tools/export-branding.py` performs uniform resampling and format conversion. It does not redraw the artwork. The transparent frame's alpha was checked over black and white; preserve alpha when reusing it. Some raw-image viewers show RGB values in nearly transparent edge pixels; normal alpha compositing renders the clean contour.

## Native integration

TOC `IconTexture` points to `Interface\AddOns\WoWEnhancedController\Media\Icon.tga`. `AddonCompartmentFunc` points to `WoWEnhancedController_OnAddonCompartmentClick`, which opens this addon's controller-accessible Options outside combat/blockers. No native menu is replaced and no new minimap frame is invented.

Forever source pin: `9dc84f0d3bbae1768ac3405b3716000bd93eda06` (1.60.1.70862). `Blizzard_AddOnList/AddonList.lua` reads IconTexture and creates a 20px inline image. `Blizzard_Minimap/Mainline/AddonCompartment.lua` reads IconTexture/AddonCompartmentFunc, renders a 16px menu image and invokes the named global with addon name/button name. The Minimap TOC loads this family implementation and Camelot overrides. Native controller menu navigation stays with Blizzard; the click handler hands off to the existing owned Options navigation and neutral gate. Physical menu activation remains real-client acceptance.

## Generation prompts

Built-in image generation was used, not the API/CLI fallback. Source originals remain in the Codex generated_images folder as well as these workspace copies.

### Transparent release masters (v2)

The built-in tool edited each v1 master with transparent output enabled:

- **Controller:** Use case: background-extraction. Edit target: the attached Enhanced Controller crest. Make a single square production icon by removing the black background from OUTSIDE AND INSIDE this four-piece gold crest and around the ivory controller. Keep the four gold angular metal pieces and controller (including its black D-pad, four black buttons and two sticks) as solid objects. Preserve the original silhouettes, spacing, centered placement, scale (~83% of canvas), gold bevels and ivory material. Remove background glow, colored fringe and cast shadows. Smooth antialiased contours on genuinely transparent alpha, including through all four open gaps and below the controller. No enclosing shape, checkerboard, lettering, new decorations or redesign.
- **Suite:** Use case: background-extraction. Edit target: the attached suite crest. Make a single square production icon by removing the black background from OUTSIDE AND INSIDE the gold crest and around the central four-point spark. Keep only the four existing beveled gold metal corner pieces and the solid gold/ivory four-point spark. Preserve their original silhouettes, spacing, centered placement, scale (~83% of canvas), lighting and gold material. Remove the diffuse outer glow around the spark as well as any background shadows/fringe. The star's sharp points should be clean on light as well as dark surfaces. Smooth antialiased contours on genuinely transparent alpha. No enclosing shape, checkerboard, lettering, new decorations or redesign.

### Suite master

Use case: logo-brand. Asset type: original square emblem for a family of World of Warcraft utility addons, also used as CurseForge project avatars. Create one finished icon, not a presentation sheet. The reusable family mark is a bold symmetrical gold angular crest: four substantial beveled corner segments form an open octagonal portal around a small luminous four-point diamond spark. The outer crest must be the primary recognizable silhouette so future addon modules can keep the crest and replace the center. Original design, not a Blizzard/WoW logo, not any existing addon logo. Fantasy MMORPG inventory-icon craftsmanship, restrained dimensional antique gold, bright warm gold edges and deep clean recesses. Near-black charcoal square background. Front-facing, centered, crest occupies about 80 percent of the square with comfortable safe margins. Very clear large shapes, minimal fine detail; must read at 32 pixels as well as at 400 pixels. Gold, black and pale warm highlights only. No text, letters, monograms, controller, keyboard, gear, border text, decorative filigree, scenes, mockups, watermark, extra icons, or external framing. Deliver a polished 1024 by 1024 square image.

### Controller variant (edit of suite master)

Use case: precise-object-edit / logo-brand. Create the controller-module variant of this reusable fantasy addon-suite emblem. Keep the four large gold beveled outer crest segments EXACTLY as they are, including their shape, placement, material, gold palette, lighting, margins and the near-black square background. Change only the central four-point spark: replace it with one clean, front-facing generic game controller icon in pale warm ivory metal with restrained antique-gold edging, centered within the opening. The controller is a strong compact recognizable silhouette, about 48 percent of the image width, with two rounded grips, one bold dark cross-shaped D-pad on its left and four dark circular buttons in a diamond on its right; a pair of small thumb sticks may sit below the center. It must be legible at 32 pixels, so keep all controls chunky and simple, no fine etching. The controller must not overlap the surrounding crest. No spark remaining, no text or letters on buttons, no branding, no Xbox/PlayStation/Nintendo logo, no extra objects, no framing changes, no new colors, no watermark. A single polished square production icon, not a mockup or a sheet.

### Transparent frame extraction

Use case: background-extraction. Asset type: reusable transparent frame layer for a suite of fantasy addon icons. Preserve ONLY the exact four gold beveled outer crest segments from the reference, in their current positions, at their current scale, with exactly the same outline, surfaces, gold colors and lighting. Remove the entire central four-point spark, all of its glow, and all black background. The center aperture, the four gaps, and all surrounding canvas must be genuinely transparent alpha, not black, white or a painted checkerboard. Keep the original square canvas and margins so this frame can be overlaid on other module icons without alignment changes. Do not add, redesign, thicken or move any part of the gold crest. No text, logos, center symbol, mockups or extra elements.

### Final transparent-frame cleanup

Precise cleanup of this transparent gold frame asset. Preserve the four gold crest pieces' design, geometry, placement, metallic shading and original square canvas. Remove ALL stray red or yellow pixel speckles, halos, glow residue and fringing around the outside and inside edges, including stray pixels floating above the top segments. The only nontransparent pixels must be the four clean gold metal pieces with smooth antialiased contours. Everywhere else, including the center and gaps, must be fully transparent. There must be no red outline, no colored noise, no sparks, no glow and no background. Do not add any central symbol. This is a clean isolated production UI layer, not a glowing effect.
