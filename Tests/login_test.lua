-- Tests that the bar is rebuilt when the totem spells turn up after it was
-- built, as they do at first login, and that the saved totem order survives a
-- login where the client hasn't reported them yet.
-- From the repository root: lua5.1 Tests/login_test.lua
local helpers = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/helpers.lua")
local check = helpers.check

-- WoW globals Core.lua, TotemData.lua and TotemSets.lua use
function UnitClass() return "Shaman", "SHAMAN" end
function CreateFrame()
	return { Hide = function() end, SetScript = function() end,
		RegisterEvent = function() end, UnregisterEvent = function() end }
end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
FIRE_TOTEM_SLOT, EARTH_TOTEM_SLOT, WATER_TOTEM_SLOT, AIR_TOTEM_SLOT = 1, 2, 3, 4
MAX_TOTEMS = 4
NUM_ACTIONBAR_BUTTONS = 12
TOTEM_MULTI_CAST_SUMMON_SPELLS = { 66842 }

local inCombat = false
function InCombatLockdown() return inCombat end

-- What the client knows: spell ids by element slot, and spell names by id
local slotSpells = {}
local spellNames = {
	[8071] = "Stoneskin Totem", [2484] = "Earthbind Totem", [5730] = "Stoneclaw Totem",
	[66842] = "Call of the Elements",
}
local known = {}
function GetMultiCastTotemSpells(slot) return unpack(slotSpells[slot] or {}) end
C_ActionBar = { GetMultiCastBarIndex = function() return 12 end }
C_SpecializationInfo = { GetActiveSpecGroup = function() return 1 end }
C_Spell = {
	GetSpellName = function(id) return spellNames[id] end,
	GetSpellInfo = function(idOrName)
		for id, name in pairs(spellNames) do
			if known[id] and (idOrName == id or idOrName == name) then
				return { name = name, iconID = 136000 + id, spellID = id }
			end
		end
	end,
}

-- Just enough of Ace3: events are recorded so the test can fire them
local events = {}
local Yata
local libs = {
	["AceAddon-3.0"] = { NewAddon = function(_, name)
		Yata = { name = name }
		function Yata:Print() end
		function Yata:RegisterChatCommand() end
		function Yata:RegisterEvent(event, handler) events[event] = handler or event end
		function Yata:UnregisterEvent(event) events[event] = nil end
		function Yata:UnregisterAllEvents() for k in pairs(events) do events[k] = nil end end
		return Yata
	end },
	["LibKeyBound-1.0"] = { RegisterCallback = function() end },
	["AceConfigDialog-3.0"] = { AddToBlizOptions = function() end },
	["AceConfig-3.0"] = { RegisterOptionsTable = function() end },
	["AceDB-3.0"] = { New = function(_, _, defaults) return { profile = defaults.profile } end },
}
function LibStub(name) return assert(libs[name], name) end

local function fire(event, ...)
	local handler = events[event]
	if handler then
		Yata[handler](Yata, event, ...)
	end
end

-- Stands in for TotemBar.lua: records each build and the order it would use
local builds = {}
local ns = {}
ns.TotemBar = { Create = function()
	Yata:InitTotems()
	Yata:InitTotemSets()
	local set = Yata:FixTotemSet(Yata:deepcopy(Yata:GetTotemSet(nil)))
	table.insert(builds, set)
	return { UpdateCallIndicators = function() end, Destroy = function() end }
end }

for _, file in ipairs({ "Core.lua", "TotemData.lua", "TotemSets.lua" }) do
	helpers.compile(file)("Yata", ns)
end
function Yata:PopulateOptions() return {} end
function Yata:ResetTimers() end
function Yata:UpdateBlizzardBar() end

-- A saved order from an earlier session: Stoneclaw first
Yata:OnInitialize()
Yata.db.profile.Sets = {
	Default = {
		GroupOrder = { "Earth", "Air", "Water", "Fire", "CallSpell", "Imbue" },
		Earth = { "Stoneclaw Totem", "Stoneskin Totem", "Earthbind Totem" },
		Air = {}, Water = {}, Fire = {}, CallSpell = { "Call of the Elements" }, Imbue = {},
	},
}

-- First login: the client hasn't reported any totems yet
Yata:OnEnable()
check(#builds == 1 and #builds[1].Earth == 0, "the bar built at login has no totems")
check(#Yata.db.profile.Sets.Default.Earth == 3, "an empty login keeps the saved totem order")

-- A spells update that changes nothing doesn't rebuild the bar
fire("SPELLS_CHANGED")
check(#builds == 1, "an unrelated spells update doesn't rebuild the bar")

-- The spells arrive, but in combat: wait for it to end
inCombat = true
slotSpells[EARTH_TOTEM_SLOT] = { 8071, 2484, 5730 }
for id in pairs(spellNames) do known[id] = true end
fire("SPELLS_CHANGED")
check(#builds == 1, "the bar isn't rebuilt in combat")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
check(#builds == 2, "the bar is rebuilt once combat ends")

local earth = builds[2] and builds[2].Earth or {}
check(earth[1] == "Stoneclaw Totem" and earth[2] == "Stoneskin Totem" and earth[3] == "Earthbind Totem",
	"the rebuilt bar uses the saved totem order")
check(builds[2] and builds[2].CallSpell[1] == "Call of the Elements", "the rebuilt bar has the Call spell")

fire("PLAYER_ENTERING_WORLD")
check(#builds == 2, "entering the world with the same spells doesn't rebuild the bar")

helpers.finish()
