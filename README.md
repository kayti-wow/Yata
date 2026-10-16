# Yata — Yet Another Totem Addon

A World of Warcraft addon that replaces the Blizzard multicast totem bar for Shamans. It shows one pop-out column per element (Earth, Air, Water, Fire) plus columns for the multicast "Call of…" spells and weapon imbues, and adds totem timers, a generated totem-stomp macro, saved layouts ("totem sets") and per-spec settings.

- **Version:** 4.7.5 (November 2011)
- **Game client:** Cataclysm, interface `40200` (patch 4.2)
- **Authors:** Kaytikat (maintainer), originally by Tornhoof
- **Framework:** Ace3

The addon relies on the Cataclysm-era multicast totem bar APIs (`GetMultiCastTotemSpells`, `TOTEM_MULTI_CAST_SUMMON_SPELLS`, `MultiCastActionBarFrame`, action slots 133–144). It will not work on clients where those APIs no longer exist.

## Installation

Copy the repository folder into `World of Warcraft/Interface/AddOns/` and name the folder `Yata`, so that `Yata.toc` is at `Interface/AddOns/Yata/Yata.toc`. All the libraries it needs are bundled in `Libs/`.

Every source file starts with a class check and returns straight away for characters that aren't Shamans. The TOC also sets `X-LoadOn-Class: SHAMAN` for AddonLoader.

## Usage

| Action | Result |
|---|---|
| `/yata` | Opens the options dialog |
| `/yatacmd …` | Command-line access to the same options table (AceConfigCmd) |
| Hover over a column | Pops out every spell in that column |
| Left-click | Casts the spell and, if auto-swap is on, moves it to the front of its column |
| Left-click + *Swap* modifier (default Ctrl) | Moves the spell to the front without casting it |
| Left-click + *Cast Only* modifier (default Shift) | Casts the spell without changing the column order |
| Left-click + *Assign* modifier (default Alt) on a totem | Adds the totem to the active multicast spell, or removes it |
| Right-click on a totem | Destroys that element's active totem |
| Shift + right-click on a totem | Casts Totemic Call |
| Right-click + modifier (default Alt) on a Call spell | Moves that Call's totems to the front of each column |
| Alt-click on a weapon imbue | Removes the imbue (left: main hand, right: off hand) |
| LibDataBroker launcher | Left-click locks or unlocks the bar; right-click opens options |

To move the bar, unlock it (in options or with the broker launcher) and drag the dark-blue grip. Unlocking also shows anchors for the timer bars.

Key bindings use LibKeyBound. In keybinding mode every column shows a *proxy* button, and the key you bind to a proxy always fires whichever spell is at the front of that column.

## Features

- **Pop-out columns.** Choose how many buttons stay visible per column (1–10), the scale of the popped-out buttons, the gap between buttons, the opacity, and one of four orientations: horizontal opening up or down, or vertical opening right or left.
- **Multicast indicators.** Coloured pips on each totem show which of the three Call spells (Elements, Ancestors, Spirits) include it.
- **Timers.** Show LibBars duration and cooldown bars, cooldown spirals on the buttons, or both. Texture, font, size, spacing, growth direction and frame strata are configurable, and textures and fonts come from LibSharedMedia.
- **Totem stomp macro.** Creates and maintains a character macro called `YataTotemStomp`, a `/castsequence` of the front totem in each element column. The macro is rebuilt after clicks and when you leave combat.
- **Totem sets.** A layout editor (Options → Totem Sets) lets you drag icons to reorder spells inside a column, drag them across columns to reorder the columns, click to hide spells, and save, load or delete named sets.
- **Per-spec settings.** Each talent spec has its own copy of all settings. The first time you play your second spec, the primary spec's profile is copied for it.
- **Skins.** Buttons can be skinned with ButtonFacade (LibButtonFacade) when it is installed.
- **Advanced options.** Hide the bar but keep its bindings and timers, hide the multicast indicators, or keep the Blizzard totem bar visible.

## Project layout

Files load in the order listed in `Yata.toc`:

| File | Purpose |
|---|---|
| `Yata.toc` | Addon manifest: metadata, SavedVariables (`YataDB`) and load order |
| `embeds.xml` | Loads the bundled libraries |
| `Localization/*.lua` | AceLocale string tables. `enUS` is the default; also deDE, esES, esMX, frFR, koKR, ruRU, zhCN, zhTW |
| `Core.lua` | Creates the addon object (`Yata`), shared constants, defaults, the DB, slash commands, enable/disable/reload logic and the per-spec profile switch |
| `TotemBar.lua` | `TotemBar`: the secure parent frame (`YataBarGrip`). Builds the columns and buttons, positions, locking, skins, keybinding mode, multicast swap logic and the macro |
| `Options.lua` | AceConfig options table, the LibDataBroker launcher, and the add/delete-set popups |
| `TotemButton.lua` | `Yata.Button`: secure spell buttons and proxy buttons, click-attribute setup, swap snippets, tooltips, hotkeys and multicast indicators |
| `Header.lua` | `Header`: the secure frame for each column, which lays out its child buttons and pops them out when hovered |
| `TotemData.lua` | Collects the character's known totems, Call spells and weapon imbues into `Yata.TotemData` |
| `Timer.lua` | Duration and cooldown bars (LibBars), driven by `PLAYER_TOTEM_UPDATE` |
| `TotemSets.lua` | Creating, saving and validating totem sets |
| `TotemButtonLayoutEditor.lua` | The `Yata_TotemButtonLayoutEditor` AceGUI widget used to edit totem sets |
| `Libs/` | Bundled third-party libraries: LibStub, CallbackHandler, Ace3 (Addon, Config, Console, DB, Event, GUI, Locale), LibBars-1.0, LibKeyBound-1.0, LibSharedMedia-3.0, LibDataBroker-1.1 |
| `Changelog-Yata-4.7.5.txt` | Packager changelog from the original SVN repository |

## Architecture

### Startup

1. `Yata:OnInitialize` (`Core.lua`) creates `YataDB` through AceDB, registers the options table and the `/yata` and `/yatacmd` commands, and hooks the LibKeyBound callbacks.
2. `Yata:OnEnable` picks the settings for the active talent spec (`SetActiveTalentProfile`) and builds the bar with `TotemBar:Create()`.
3. `TotemBar:New` then:
   - calls `Yata:InitTotems()` to gather the spells the character knows,
   - calls `Yata:InitTotemSets()` to load the saved sets and fix any that are out of date,
   - creates one `Header` and one proxy button per spell group, plus a `Yata.Button` for every spell in the current set,
   - sets the modifier-key attributes, skins the buttons, lays out the bar, starts the timers and writes the macro.
4. Learning a new spell (`LEARNED_SPELL_IN_TAB`, except guild perks) or switching spec (`ACTIVE_TALENT_GROUP_CHANGED`) calls `Yata:Reload()`, which tears the bar down and builds it again.

### Spell groups and data

`SpellGroups` (`Core.lua`) lists six groups: `Earth`, `Air`, `Water`, `Fire`, `CallSpell` and `Imbue`. `ElementsMap` maps each element to its totem slot (Fire 1, Earth 2, Water 3, Air 4).

`Yata.TotemData` serves as both an ordered list and a map. The list part holds spell names in discovery order. Each name also maps to a list of records with the fields `GlobalId`, `Name`, `Texture`, `Mana` and `SpellGroup`, plus `ActionId` and `Slot` for totems, or `CallIndex` and `CallActionBase` for Call spells. Code always uses the last record in a name's list.

Totems are found by reading multicast action slots 133–136. The three Call spells take action ranges starting at 133, 137 and 141, with one slot per element in each range.

### Secure code and combat

The bar must keep working in combat, so everything that changes layout runs in restricted (secure) Lua:

- **Buttons** handle `_onattributechanged` for `newposition`. The handler re-anchors the button, shows or hides it, and moves the column's proxy keybinding to whichever button is at position 0.
- **Headers** handle the `show` attribute. They pop the column out on hover and collapse it on leave, scaling the extra buttons by `popoutscale`.
- **The bar** handles `autocall` and `manualcall`, which bring a Call spell's totems to the front of each column, and `updateindicators`, which rebuilds each totem's assign-to-call click attributes for the active Call spell.
- `Button:SetOnClickScript` wraps `OnClick` with pre- and post-handlers that check modifier keys through the `checkModifier` and `swapButton` snippets.

Options that rebuild frames are disabled while `InCombatLockdown()` is true.

### Saved variables

`YataDB` is an AceDB database, and all settings are stored in its profile. `Yata.CurrentDb` points at the settings for the active spec: `db.profile` for the spec the addon was first used in (`InitialSpec`), or `db.profile.alternativespec` for the other one. Use `Yata.CurrentDb` rather than `Yata.db.profile` everywhere. The default values are in `Core.lua` (`defaults`).

Each totem set is stored in `CurrentDb.Sets[name]` and has three parts:

- `GroupOrder`: the order of the spell groups
- `<SpellGroup>`: an ordered list of spell names for each group
- `HiddenSpells`: the names of hidden spells

The active set's name is in `CurrentDb.CurrentTotemSet`, and the default set is called `"Default"`.

## Localization

Add or update strings in `Localization/<locale>.lua`. Only `enUS.lua` is created with `isDefault = true`, so any key missing from another locale falls back to English. When you add a locale file, also add it to `Yata.toc`.

Some user-facing strings are still hard-coded in English and do not go through the locale tables, including the reset confirmation, the layout-editor labels and the element names in tooltips.

## Development notes

There is no build step or test suite. To test a change, copy the folder into the AddOns directory and run `/reload` in game. Lua errors are easiest to see with an error-display addon such as BugSack, or with `/console scriptErrors 1`.

Known issues found while reading the code:

- `Options.lua:107`: the *Cast Only* key setter calls the global `SetAttribute(...)` instead of `Yata.Bar:SetAttribute(...)`, so changing that option raises a Lua error. The new key takes effect after `/reload`.
- `Core.lua:165` checks for the guild perk "Fast Track" by its English name, so on other client languages that perk triggers a needless reload.
- Several files define globals (`TotemBar`, `Header`, `SpellGroups`, `ElementsMap`, `TOTEM_SET_*`, `SPELL_GROUP_*`) that another addon could overwrite.

## Credits

Originally written by Tornhoof and later maintained by Kaytikat. It was distributed on Curse as project `yata`. The bundled libraries are the work of their respective authors (Ace3 team, LibBars, LibKeyBound, LibSharedMedia and LibDataBroker contributors). The keybinding-mode and broker code is adapted from Nevcairiel's Bartender4.
