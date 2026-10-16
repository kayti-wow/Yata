if select(2, UnitClass('player')) ~= "SHAMAN" then
	return
end

Yata = LibStub("AceAddon-3.0"):NewAddon("Yata", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Yata")
local LibKeyBound = LibStub("LibKeyBound-1.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

TOTEM_SET_PRIMARY_DEFAULT = "Default"
TOTEM_SET_SECONDARY_DEFAULT = "Secondary Default"
SPELL_GROUP_CALL = "CallSpell"
SPELL_GROUP_IMBUE = "Imbue"

SpellGroups = {"Earth", "Air", "Water", "Fire", SPELL_GROUP_CALL, SPELL_GROUP_IMBUE}
ElementsMap = {["Fire"] = FIRE_TOTEM_SLOT, ["Earth"] = EARTH_TOTEM_SLOT, ["Water"] = WATER_TOTEM_SLOT, ["Air"] = AIR_TOTEM_SLOT}

local defaults = {
	profile = {
		AdvancedEnabled = false,
		AdvHideBar = false,
		AdvHideIndicators = false,
		AdvShowBlizzBar = false,
		Alpha = 1,
		ShowKeybinds = true,
		BarScale = 1.0,
		PopOutScale = 0.85,
		BarOrientation = 1,
		ButtonGap = 0,
		VisibleButtons = 1,
		AutoButtonSwap = true,
		Locked = true,
		ShowTooltip = true,
		Tooltip = 3,
		TimerEnabled = true,
		TimerType = 1,
		TimerScale = 1.0,
		TimerOrientation = 1,
		TimerThickness = 10,
		TimerLength = 100,
		TimerFontSize = 8,
		TimerFont = "Friz Quadrata TT",
		TimerSpacing = 0,
		TimerGrowUp = true,
		TimerStrata = "LOW",
		TimerBarSkin = "Blizzard",
		MacroResetKey = "none",
		ButtonSetCallKey = "alt",
		ButtonSwapKey = "ctrl",
		ButtonNoSwapKey = "shift",
		ManualSwapToCallKey = "alt",
		AutoSwapToCall = false,
		MultiTooltip = true,
		CurrentTotemSet = TOTEM_SET_PRIMARY_DEFAULT,
		InitialSpec = nil,
		MacroEnabled = true,
		BarPosition = {
			x = 110,
			y = 115
		},
		alternativespec = {
			AdvancedEnabled = false,
			AdvHideBar = false,
			AdvHideIndicators = false,
			AdvShowBlizzBar = false,
			Alpha = 1,
			ShowKeybinds = true,
			BarScale = 1.0,
			PopOutScale = 0.85,
			BarOrientation = 1,
			ButtonGap = 0,
			VisibleButtons = 1,
			AutoButtonSwap = true,
			Locked = true,
			ShowTooltip = true,
			MacroEnabled = true,
			Tooltip = 3,
			TimerEnabled = true,
			TimerType = 1,
			TimerScale = 1.0,
			TimerOrientation = 1,
			TimerThickness = 10,
			TimerLength = 100,
			TimerFontSize = 8,
			TimerFont = "Friz Quadrata TT",
			TimerSpacing = 0,
			TimerGrowUp = true,
			TimerStrata = "LOW",
			MultiTooltip = true,
			TimerBarSkin = "Blizzard",
			MacroResetKey = "none",
			ButtonSetCallKey = "alt",
			ButtonSwapKey = "ctrl",
			ButtonNoSwapKey = "shift",
			ManualSwapToCallKey = "alt",
			AutoSwapToCall = false,
			CurrentTotemSet = TOTEM_SET_PRIMARY_DEFAULT,
			BarPosition = {
				x = 110,
				y = 115
			},
			FirstUse = true
		}
	},
};

function Yata:OnInitialize()
    -- Called when the addon is loaded
	self.db = LibStub("AceDB-3.0"):New("YataDB", defaults)

	LibStub("AceConfig-3.0"):RegisterOptionsTable("Yata", self:PopulateOptions(), {"yatacmd"})

	self:RegisterChatCommand("yata", "ChatCommand")
	self.optionsFrame = AceConfigDialog:AddToBlizOptions("Yata", nil, nil)

	self:Print("Loaded")

	LibKeyBound.RegisterCallback(self, "LIBKEYBOUND_ENABLED")
	LibKeyBound.RegisterCallback(self, "LIBKEYBOUND_DISABLED")
	LibKeyBound.RegisterCallback(self, "LIBKEYBOUND_MODE_COLOR_CHANGED")
end

function Yata:ChatCommand(input)
	if input and strtrim(input):lower() == "debug" then
		self:PrintDebugInfo()
	else
		AceConfigDialog:Open("Yata")
	end
end

function Yata:OnEnable()

	if self.Bar then
		self.Bar:Destroy()
	end

	local firstUse = self:SetActiveTalentProfile()

	self.Bar = TotemBar:Create()
	self.Bar:UpdateCallIndicators()

	self:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE", "SpellLearned")
	self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", "Reload") -- just to be sure

	self:UpdateBlizzardBar()

	if firstUse == true then
		self:Print ("First time in this spec: copying yata profile and reloading")
		self:Reload()
	end

	self:ResetTimers()
end

function Yata:OnDisable()
	if self.Bar then
		self.Bar:Destroy()
	end
end

-- The Blizzard totem bar is managed by Edit Mode, so rather than driving its
-- visibility we hide it by moving it under a hidden parent.
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

function Yata:UpdateBlizzardBar()
	local frame = MultiCastActionBarFrame
	if not frame or InCombatLockdown() then
		return
	end

	if self.CurrentDb.AdvancedEnabled and self.CurrentDb.AdvShowBlizzBar then
		frame:SetParent(UIParent)
	else
		frame:SetParent(hiddenParent)
	end
end

function Yata:SpellLearned(event, spellId, skillLineIndex, isGuildPerkSpell)
	if not isGuildPerkSpell then -- Don't reload when we get new guild spells (these won't affect the totem bar)
		local name = C_Spell.GetSpellName(spellId)
		Yata:Print("Detected new spell: "..(name or spellId))
		Yata:Reload()
	end
end

function Yata:Reload()
	-- Rebuilding the bar touches secure frames, so wait until combat ends
	if InCombatLockdown() then
		if not self.reloadPending then
			self.reloadPending = true
			self:RegisterEvent("PLAYER_REGEN_ENABLED", "Reload")
		end
		return
	end
	self.reloadPending = nil

	self:Print("Reloading")

	self:UnregisterAllEvents()

	self:OnDisable()

	self:OnEnable()
end

function Yata:Reset()
	self.db:ResetProfile()
	self:Reload()
end

function Yata:SetActiveTalentProfile()
	local specIndex = C_SpecializationInfo.GetActiveSpecGroup(false, false)
	local firstUse = false

	if self.db.profile.InitialSpec == nil then
		self.db.profile.InitialSpec = specIndex
	end

	if specIndex == self.db.profile.InitialSpec then
		self.CurrentDb = self.db.profile
	else
		self.CurrentDb = self.db.profile.alternativespec
		if self.db.profile.alternativespec.FirstUse == true then
			self.db.profile.alternativespec = Yata:deepcopy(self.db.profile)

			self.db.profile.alternativespec.alternativespec = nil

			self.db.profile.alternativespec.FirstUse = false

			firstUse = true
		end
	end

	return firstUse
end

function Yata:deepcopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

-- Prints what the client reports about the multicast bar, so problems can be
-- diagnosed without a debugger. Run out of combat: some values are hidden from
-- addons during combat.
function Yata:PrintDebugInfo()
	local version, build, _, interface = GetBuildInfo()
	self:Print(format("Client %s (%s), interface %s", version, build, interface))
	self:Print(format("Multicast bar index %d, action base %d",
		C_ActionBar.GetMultiCastBarIndex(), self:GetMultiCastActionBase()))

	for element, slot in pairs(ElementsMap) do
		local names = {}
		for _, spellId in ipairs({ GetMultiCastTotemSpells(slot) }) do
			table.insert(names, format("%s (%d)", C_Spell.GetSpellName(spellId) or "?", spellId))
		end
		self:Print(format("Slot %d %s: %s", slot, element, #names > 0 and table.concat(names, ", ") or "none"))
	end

	local base = self:GetMultiCastActionBase()
	for index, spellId in ipairs(TOTEM_MULTI_CAST_SUMMON_SPELLS) do
		local known = C_Spell.GetSpellInfo(C_Spell.GetSpellName(spellId) or "") ~= nil
		local actions = {}
		for slot = 1, MAX_TOTEMS do
			local action = base + (index - 1) * MAX_TOTEMS + slot
			local actionType, id = GetActionInfo(action)
			table.insert(actions, format("%d=%s", action, id and (C_Spell.GetSpellName(id) or id) or (actionType or "empty")))
		end
		self:Print(format("Call %d %s%s: %s", index, C_Spell.GetSpellName(spellId) or spellId,
			known and "" or " (not known)", table.concat(actions, ", ")))
	end

	self:Print(format("Spells on bar: %d", self.TotemData and self.TotemData.Count or 0))
end
