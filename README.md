# Yata — Yet Another Totem Addon

A World of Warcraft addon that replaces the Blizzard multicast totem bar for Shamans. It shows one pop-out column per element (Earth, Air, Water, Fire) plus columns for the multicast "Call of…" spells and weapon imbues, and adds totem timers, a generated totem-stomp macro, saved layouts ("totem sets") and per-spec settings.

- **Version:** 5.0.0-forever, a port of 4.7.5 (November 2011)
- **Game client:** WoW Forever, interface `16001` (client 1.60.1). The original 4.7.5 targeted Cataclysm (`40200`).
- **Authors:** Kaytikat (maintainer), originally by Tornhoof
- **Framework:** Ace3

Forever keeps the Cataclysm multicast totem bar (`GetMultiCastTotemSpells`, `TOTEM_MULTI_CAST_SUMMON_SPELLS`, `MultiCastActionBarFrame`), so Yata's bar design carries over unchanged. Everything else was updated to the modern API: `C_Spell`, duration objects for timers, Edit Mode, and the current macro functions. The port was written against Blizzard's Forever UI source and has not yet been tested in game.

## AI usage

This README and the WoW Forever port (5.0.0-forever) were developed with Claude, Anthropic's AI model. That covers the code changes for Forever, the bug fixes since, and the offline tests in `Tests/`. The commits involved say so in their message or carry a `Co-Authored-By: Claude` trailer. The original addon, up to 4.7.5 (2011), is the work of Tornhoof and Kaytikat. The AI-assisted changes were checked against Blizzard's Forever UI source and with the offline tests, but haven't been tested in game yet.

## Installation

Copy the repository folder into `World of Warcraft/Interface/AddOns/` and name the folder `Yata`, so that `Yata.toc` is at `Interface/AddOns/Yata/Yata.toc`. All the libraries it needs are bundled in `Libs/`.

Every source file starts with a class check and returns straight away for characters that aren't Shamans. The TOC also sets `X-LoadOn-Class: SHAMAN` for AddonLoader.

## Usage

| Action | Result |
|---|---|
| `/yata` | Opens the options dialog |
| `/yata debug` | Prints what the client reports about the multicast bar, Call spells and their action slots. Run it out of combat |
| `/yatacmd …` | Command-line access to the same options table (AceConfigCmd) |
| Hover over a column | Pops out every spell in that column |
| Left-click | Casts the spell and, if auto-swap is on, moves it to the front of its column |
| Left-click + *Swap* modifier (default Ctrl) | Moves the spell to the front without casting it |
| Left-click + *Cast Only* modifier (default Shift) | Casts the spell without changing the column order |
| Left-click + *Assign* modifier (default Alt) on a totem | Adds the totem to the active multicast spell, or removes it |
| Right-click on a totem | Destroys that element's active totem |
| Shift + right-click on a totem | Casts Totemic Recall |
| Right-click on a Call spell | Casts Totemic Recall |
| Right-click + modifier (default Alt) on a Call spell | Moves that Call's totems to the front of each column |
| Alt-click on a weapon imbue | Removes the imbue (left: main hand, right: off hand) |
| LibDataBroker launcher | Left-click locks or unlocks the bar; right-click opens options |

To move the bar, unlock it (in options or with the broker launcher) and drag the dark-blue grip. Unlocking also shows anchors for the timer bars.

Key bindings use LibKeyBound. In keybinding mode every column shows a *proxy* button, and the key you bind to a proxy always fires whichever spell is at the front of that column.

## Features

- **Pop-out columns.** Choose how many buttons stay visible per column (1–10), the scale of the popped-out buttons, the gap between buttons, the opacity, and one of four orientations: horizontal opening up or down, or vertical opening right or left.
- **Multicast indicators.** Coloured pips on each totem show which of the three Call spells (Elements, Ancestors, Spirits) include it.
- **Timers.** Show duration and cooldown bars, cooldown spirals on the buttons, or both. Texture, font, size, spacing, fill direction, growth direction and frame strata are configurable, and textures and fonts come from LibSharedMedia. Duration bars are coloured by element and cooldown bars are orange. (The old LibBars bars changed colour as they ran down; the new ones can't, because remaining time may be hidden from addons in combat.)
- **Totem stomp macro.** Creates and maintains a character macro called `YataTotemStomp`, a `/castsequence` of the front totem in each element column. The macro is rebuilt after clicks and when you leave combat.
- **Totem sets.** A layout editor (Options → Totem Sets) lets you drag icons to reorder spells inside a column, drag them across columns to reorder the columns, click to hide spells, and save, load or delete named sets.
- **Per-spec settings.** Each talent spec has its own copy of all settings. The first time you play your second spec, the primary spec's profile is copied for it.
- **Skins.** Buttons can be skinned with Masque when it is installed. Skins are chosen in Masque's own options.
- **Advanced options.** Hide the bar but keep its bindings and timers, hide the multicast indicators, or keep the Blizzard totem bar visible. Yata hides the Blizzard bar by moving it under a hidden parent frame, because Edit Mode manages that bar's visibility.

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
| `Timer.lua` | Duration and cooldown bars and button spirals, driven by duration objects (see "Secret values" below) |
| `TotemSets.lua` | Creating, saving and validating totem sets |
| `TotemButtonLayoutEditor.lua` | `Yata:OpenLayoutEditor()`, the AceGUI window used to edit totem sets |
| `Libs/` | Bundled third-party libraries: LibStub, CallbackHandler, Ace3 (Addon, Config, Console, DB, Event, GUI, Locale), LibKeyBound-1.0, LibSharedMedia-3.0, LibDataBroker-1.1. LibBars-1.0 is no longer used |
| `Tests/` | Offline tests that run under Lua 5.1 against mocked WoW APIs (see "Development notes"). The game doesn't load them |
| `Changelog-Yata-4.7.5.txt` | Packager changelog from the original SVN repository |

## Architecture

### Startup

1. `Yata:OnInitialize` (`Core.lua`) creates `YataDB` through AceDB, registers the options table and the `/yata` and `/yatacmd` commands, and hooks the LibKeyBound callbacks.
2. `Yata:OnEnable` picks the settings for the active talent spec (`SetActiveTalentProfile`), builds the bar with `TotemBar:Create()`, and hides or shows the Blizzard totem bar.
3. `TotemBar:New` then:
   - calls `Yata:InitTotems()` to gather the spells the character knows,
   - calls `Yata:InitTotemSets()` to load the saved sets and fix any that are out of date,
   - creates one `Header` and one proxy button per spell group, plus a `Yata.Button` for every spell in the current set,
   - sets the modifier-key attributes, skins the buttons, lays out the bar, starts the timers and writes the macro.
4. Learning a new spell (`LEARNED_SPELL_IN_SKILL_LINE`, except guild perks) or switching spec (`ACTIVE_TALENT_GROUP_CHANGED`) calls `Yata:Reload()`, which tears the bar down and builds it again. A reload requested in combat waits for `PLAYER_REGEN_ENABLED`.

### Spell groups and data

`SpellGroups` (`Core.lua`) lists six groups: `Earth`, `Air`, `Water`, `Fire`, `CallSpell` and `Imbue`. `ElementsMap` maps each element to its totem slot (Fire 1, Earth 2, Water 3, Air 4).

`Yata.TotemData` serves as both an ordered list and a map. The list part holds spell names in discovery order. Each name also maps to a list of records with the fields `GlobalId`, `Name`, `Texture`, `Mana` and `SpellGroup`, plus `ActionId` and `Slot` for totems, or `CallIndex` and `CallActionBase` for Call spells. Code always uses the last record in a name's list.

Totems are found with `GetMultiCastTotemSpells(slot)` for totem slots 1–4. The multicast action slots start after `Yata:GetMultiCastActionBase()`, which is `(C_ActionBar.GetMultiCastBarIndex() - 1) * 12` (132 on Cataclysm). Each of the three Call spells owns four consecutive slots, one per element, so Call *k* uses `base + (k-1)*4 + 1` to `base + (k-1)*4 + 4`.

### Secure code and combat

The bar must keep working in combat, so everything that changes layout runs in restricted (secure) Lua:

- **Buttons** handle `_onattributechanged` for `newposition`. The handler re-anchors the button, shows or hides it, and moves the column's proxy keybinding to whichever button is at position 0.
- **Headers** handle the `show` attribute. They pop the column out on hover and collapse it on leave, scaling the extra buttons by `popoutscale`.
- **The bar** handles `autocall` and `manualcall`, which bring a Call spell's totems to the front of each column, and `updateindicators`, which rebuilds each totem's assign-to-call click attributes for the active Call spell.
- `Button:SetOnClickScript` wraps `OnClick` with pre- and post-handlers that check modifier keys through the `checkModifier` and `swapButton` snippets.
- Buttons set `useOnKeyDown` to `false`, so the click wrappers run once per press even when the `ActionButtonUseKeyDown` setting is on. Key-bound presses therefore act on key release.

### Secret values

In combat, during encounters and in PvP, the client may return "secret" values from totem and cooldown APIs (`GetTotemInfo`, `GetTotemTimeLeft`, `C_Spell.GetSpellCooldown`). Addon code can pass a secret value to a widget, but can't compare it, do maths on it, or use it as a table key. `Timer.lua` is written around that rule:

- Timing comes from duration objects (`GetTotemDuration(slot)` and `C_Spell.GetSpellCooldownDuration`). These feed `StatusBar:SetTimerDuration`, `Cooldown:SetCooldownFromDurationObject` and a `C_DurationUtil` text binding directly.
- When `C_Secrets.ShouldTotemSlotBeSecret(slot)` is true, the totem in a slot is identified from the player's own `UNIT_SPELLCAST_SUCCEEDED` events, which aren't secret. For a Call spell, its action slots are read instead. The bar is shown or hidden with `SetAlphaFromBoolean(duration:IsZero(), 0, 1)`. `haveTotem` from `GetTotemInfo` is true for any usable slot, so only the duration shows whether a totem is down.
- Slots stay secret for as long as any addon restriction is active, and an encounter or PvP match can outlast combat. Every slot is re-read when `ADDON_RESTRICTION_STATE_CHANGED` reports that a restriction has lifted, and on `PLAYER_REGEN_ENABLED`.
- Cooldowns branch only on `isActive` and `isOnGCD`, which the API marks as never secret.

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

There is no build step. `Tests/` has offline tests that run under Lua 5.1 or LuaJIT (the game's Lua version) against mocked WoW APIs. Run them with `lua5.1 Tests/run.lua` from the repository root. They check the totem duration bars in and out of combat, compile every secure snippet, run the bar's call-indicator snippet, and load each locale as a client in that locale would. They can't replace the game client, so also test a change by copying the folder into the AddOns directory and running `/reload` in game. Lua errors are easiest to see with an error-display addon such as BugSack, or with `/console scriptErrors 1`. Blizzard's UI source for each client flavour is published on the `forever`, `live` and other branches of the wow-ui-source mirror, and `Blizzard_APIDocumentationGenerated` in that source is the best API reference.

Known issues:

- The Forever port hasn't been tested in game yet. `/yata debug` output from a real client is the quickest way to confirm that the multicast slots and Call spells match what the code expects.
- On the Forever beta (build 1.60.1.70425), Alt-clicking a weapon imbue to remove it raises a Lua error and removes nothing. Blizzard's `cancelaura` action in `SecureTemplates.lua` still reads a `CANCELABLE_ITEMS` table, but the Forever copy of that file no longer defines it. Yata can't work around this because `C_Spell.CancelItemTempEnchantment` is restricted, so it needs a Blizzard fix.

## Credits

Originally written by Tornhoof and later maintained by Kaytikat (kayti-wow on github). It was distributed on Curse as project `yata`. The bundled libraries are the work of their respective authors (Ace3 team, LibKeyBound, LibSharedMedia and LibDataBroker contributors). The keybinding-mode and broker code is adapted from Nevcairiel's Bartender4.
