-- Tests the totem duration bars in Timer.lua against mocked WoW APIs, in and
-- out of combat. From the repository root: lua5.1 Tests/timer_test.lua
local helpers = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/helpers.lua")
local check = helpers.check

-- Widget mock: tracks alpha and shown state, every other method is a no-op
local Widget = {}
Widget.__index = function(self, key)
	return rawget(Widget, key) or function() end
end
function Widget.new(kind)
	return setmetatable({ kind = kind, alpha = 1, shown = true }, Widget)
end
function Widget:SetAlpha(alpha) self.alpha = alpha end
function Widget:SetAlphaFromBoolean(value, alphaIfTrue, alphaIfFalse)
	assert(type(value) == "boolean", "SetAlphaFromBoolean needs a boolean, got " .. type(value))
	self.alpha = value and alphaIfTrue or alphaIfFalse
end
function Widget:Show() self.shown = true end
function Widget:Hide() self.shown = false end
function Widget:CreateTexture() return Widget.new("Texture") end
function Widget:CreateFontString() return Widget.new("FontString") end
function Widget:SetFont() return true end
function Widget:GetLeft() return 0 end
function Widget:GetBottom() return 0 end

-- WoW globals Timer.lua uses
function UnitClass() return "Shaman", "SHAMAN" end
function LibStub(name, silent)
	if silent then return nil end
	error("unexpected LibStub(" .. name .. ")")
end
function CreateFrame(kind) return Widget.new(kind) end
UIParent = Widget.new("Frame")
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
MAX_TOTEMS = 4
Enum = {
	StatusBarInterpolation = { Immediate = 0 },
	StatusBarTimerDirection = { RemainingTime = 1 },
	AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 },
}
function wipe(t)
	for k in pairs(t) do t[k] = nil end
	return t
end
function tDeleteItem(t, item)
	for i = #t, 1, -1 do
		if t[i] == item then table.remove(t, i) end
	end
end
function CopyTable(t)
	local copy = {}
	for k, v in pairs(t) do copy[k] = v end
	return copy
end
C_StringUtil = { CreateSecondsFormatter = function() return {} end }
C_DurationUtil = { CreateDurationTextBinding = function() return Widget.new("Binding") end }
C_Timer = { NewTicker = function() return { Cancel = function() end } end }
function GetActionInfo() return nil end

-- What the client reports for each totem slot
local slots, secretSlots = {}, false
local function setSlot(slot, name, duration, spellId)
	slots[slot] = { name = name or "", duration = duration or 0, spellId = spellId or 0 }
end
for slot = 1, 4 do setSlot(slot) end

C_Secrets = { ShouldTotemSlotBeSecret = function() return secretSlots end }
function GetTotemInfo(slot)
	local s = slots[slot]
	-- As Blizzard's own totem UI expects, haveTotem is true for every usable
	-- slot, whether or not a totem is down
	return true, s.name, 0, s.duration, 136000 + slot, 1, s.spellId
end
function GetTotemDuration(slot)
	local s = slots[slot]
	return { IsZero = function() return s.duration == 0 end }
end
local spellNames = { [3599] = "Searing Totem", [8071] = "Stoneskin Totem" }
C_Spell = {
	GetSpellName = function(id) return spellNames[id] end,
	GetSpellCooldown = function() return nil end,
	GetSpellCooldownDuration = function() return nil end,
}

-- A stand-in for the addon object and its bar
local events = {}
local Yata = {
	CurrentDb = {
		TimerEnabled = true, TimerType = 1, TimerOrientation = 1, TimerThickness = 10,
		TimerLength = 100, TimerSpacing = 0, TimerGrowUp = true, TimerFont = "Friz Quadrata TT",
		TimerFontSize = 8, TimerBarSkin = "Blizzard", TimerScale = 1, TimerStrata = "LOW", Locked = true,
	},
}
function Yata:RegisterEvent(event, method) events[event] = method or event end
local function TotemButton(name, id, slot, group)
	return {
		Totem = { Name = name, GlobalId = id, Slot = slot, SpellGroup = group, Texture = 1 },
		Cooldown = Widget.new("Cooldown"),
	}
end
Yata.Bar = { Groups = { All = {
	TotemButton("Searing Totem", 3599, 1, "Fire"),
	TotemButton("Stoneskin Totem", 8071, 2, "Earth"),
} } }

helpers.compile("Timer.lua")("Yata", { Yata = Yata })
Yata:InitTimer()

local function fire(event, ...)
	local handler = assert(events[event], event .. " is not registered")
	Yata[handler](Yata, event, ...)
end
local function durationBar(slot) return Yata.DurationGroup.Bars[slot] end
local function visible(bar) return bar ~= nil and bar.shown and bar.alpha > 0 end

-- Out of combat, totem details are readable
setSlot(1, "Searing Totem", 60, 3599)
fire("PLAYER_TOTEM_UPDATE", 1)
check(visible(durationBar(1)), "out of combat: a totem that is down has a visible bar")
fire("PLAYER_TOTEM_UPDATE", 2)
check(not visible(durationBar(2)), "out of combat: an empty slot has no bar")

-- In combat, totem slots are secret
secretSlots = true
setSlot(2, "Stoneskin Totem", 120, 8071)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-guid", 8071)
check(visible(durationBar(2)), "in combat: a newly cast totem has a visible bar")
setSlot(1)
fire("PLAYER_TOTEM_UPDATE", 1)
check(not visible(durationBar(1)), "in combat: an expired totem's bar is hidden")
fire("PLAYER_TOTEM_UPDATE", 3)
check(not visible(durationBar(3)), "in combat: an empty slot's bar is hidden")

-- Restrictions such as a PvP match can outlast combat
check(events.ADDON_RESTRICTION_STATE_CHANGED ~= nil, "ADDON_RESTRICTION_STATE_CHANGED is registered")
if events.ADDON_RESTRICTION_STATE_CHANGED then
	fire("ADDON_RESTRICTION_STATE_CHANGED", 0, Enum.AddOnRestrictionState.Activating)
	check(durationBar(2) ~= nil, "a restriction activating keeps the bars")
	secretSlots = false
	fire("ADDON_RESTRICTION_STATE_CHANGED", 3, Enum.AddOnRestrictionState.Inactive)
	check(durationBar(1) == nil and durationBar(3) == nil, "a restriction lifting releases empty slots' bars")
	check(visible(durationBar(2)), "a restriction lifting keeps the bar of a totem that is down")
end

helpers.finish()
