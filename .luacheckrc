-- luacheck configuration (https://luacheck.readthedocs.io)
-- Run from the repository root: luacheck .
std = "lua51"
max_line_length = false
exclude_files = {
	"Libs/",
	".release/",
}

ignore = {
	"212", -- unused argument (Ace3 callbacks and option handlers take arguments they don't need)
	"213", -- unused loop variable
	"412", -- variable redefines an argument (method-style "self" in closures)
	"432", -- shadowing an upvalue argument
	"61.", -- whitespace warnings
}

-- WoW API and FrameXML globals the addon reads
local wowGlobals = {
	-- Libraries and UI helpers
	"LibStub",
	"CopyTable",
	"format",
	"gsub",
	"strtrim",
	"tDeleteItem",
	"wipe",
	table = { fields = { "wipe" } },

	-- Frames and UI
	"CreateFrame",
	"GameTooltip",
	"GameTooltip_SetDefaultAnchor",
	"MultiCastActionBarFrame",
	"StaticPopup_Show",
	"UIParent",
	"WorldFrame",

	-- API functions and namespaces
	"C_ActionBar",
	"C_DurationUtil",
	"C_Secrets",
	"C_SpecializationInfo",
	"C_Spell",
	"C_StringUtil",
	"C_Timer",
	"ClearCursor",
	"CreateMacro",
	"EditMacro",
	"GetActionInfo",
	"GetBindingKey",
	"GetBuildInfo",
	"GetCVar",
	"geterrorhandler",
	"GetLocale",
	"GetMacroIndexByName",
	"GetMacroInfo",
	"GetMultiCastTotemSpells",
	"GetNumMacros",
	"GetTotemDuration",
	"GetTotemInfo",
	"InCombatLockdown",
	"IsModifiedClick",
	"UnitClass",

	-- Constants
	"ACCEPT",
	"AIR_TOTEM_SLOT",
	"ATTRIBUTE_NOOP",
	"CANCEL",
	"Constants",
	"EARTH_TOTEM_SLOT",
	"Enum",
	"FIRE_TOTEM_SLOT",
	"INVSLOT_MAINHAND",
	"INVSLOT_OFFHAND",
	"MAX_CHARACTER_MACROS",
	"MAX_TOTEMS",
	"NUM_ACTIONBAR_BUTTONS",
	"STANDARD_TEXT_FONT",
	"TOTEM_MULTI_CAST_SUMMON_SPELLS",
	"WATER_TOTEM_SLOT",
}

read_globals = wowGlobals
-- The addon adds its popups to this table
globals = { "StaticPopupDialogs" }

-- The tests install mocks for the WoW API
files["Tests/"] = {
	globals = wowGlobals,
}
