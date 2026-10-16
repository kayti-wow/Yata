local _, ns = ...

if select(2, UnitClass('player')) ~= "SHAMAN" then
	return
end

local Yata = ns.Yata
local SPELL_GROUP_CALL, SPELL_GROUP_IMBUE = ns.SPELL_GROUP_CALL, ns.SPELL_GROUP_IMBUE

local BlizzardCallSpells = TOTEM_MULTI_CAST_SUMMON_SPELLS

-- Totem slots in the order the multicast bar reports them
local TotemSlots = { FIRE_TOTEM_SLOT, EARTH_TOTEM_SLOT, WATER_TOTEM_SLOT, AIR_TOTEM_SLOT }
local SlotGroups = {
	[FIRE_TOTEM_SLOT] = "Fire",
	[EARTH_TOTEM_SLOT] = "Earth",
	[WATER_TOTEM_SLOT] = "Water",
	[AIR_TOTEM_SLOT] = "Air",
}

local WeaponImbues =
{
	8017,  --"Rockbiter Weapon"
	8024,  --"Flametongue Weapon"
	8033,  --"Frostbrand Weapon"
	8232,  -- "Windfury Weapon"
}
-- These are the rank 1 ids, checked against Wowhead's Forever database. All
-- ranks share a name, so GetKnownSpell resolves them to the highest rank known.

-- Where the multicast bar has always lived, for when the client can't tell us
-- (early in login, or before the player has the bar)
local DEFAULT_MULTICAST_ACTION_BASE = 132

-- First action slot of the multicast bar, minus one. Each Call spell owns a
-- page of four slots (one per element) starting here.
function Yata:GetMultiCastActionBase()
	local index = C_ActionBar.GetMultiCastBarIndex and C_ActionBar.GetMultiCastBarIndex()
	if not index or index < 1 then
		return DEFAULT_MULTICAST_ACTION_BASE
	end
	return (index - 1) * NUM_ACTIONBAR_BUTTONS
end

-- Returns the name, icon and spell id of the highest rank of a spell the
-- player knows, or nil if they don't know it
local function GetKnownSpell(spellId)
	local name = C_Spell.GetSpellName(spellId)
	if not name then
		return nil
	end

	-- Look up again by name: this only succeeds for spells in the spellbook
	local info = C_Spell.GetSpellInfo(name)
	if not info then
		return nil
	end
	return info.name, info.iconID, info.spellID
end

function Yata:InitTotems()
	self:GatherTotemData()
	if(#self.TotemData == 0) then
		self:Print("No totems found, level too low?")
		return false
	end
	return true
end

function Yata:GetTotem(name)
	local result = nil
	for k,v in ipairs(Yata.TotemData) do
		local totem = Yata.TotemData[v]
		totem = totem[#totem]
		if totem.Name == name then
			result = totem
			break
		end
	end
	return result
end

local function AddTotem(data, totem)
	if not data[totem.Name] then
		data[totem.Name] = {}
		table.insert(data, totem.Name)
	end
	table.insert(data[totem.Name], totem)
end

function Yata:GatherTotemData()
	if self.TotemData then
		table.wipe(self.TotemData)
	end

	self.TotemData = {}

	local actionBase = self:GetMultiCastActionBase()
	local count = 0

	for k, slot in ipairs(TotemSlots) do
		for l, globalId in ipairs({ GetMultiCastTotemSpells(slot) }) do
			local info = C_Spell.GetSpellInfo(globalId)
			if info then
				count = count + 1

				local totem = {}
				totem.GlobalId = globalId
				totem.Name = info.name
				totem.Texture = info.iconID
				totem.ActionId = actionBase + slot
				totem.SpellGroup = SlotGroups[slot]
				totem.Slot = slot

				AddTotem(self.TotemData, totem)
			end
		end
	end

	for k, spellId in ipairs(BlizzardCallSpells) do
		local name, icon = GetKnownSpell(spellId)

		if (name) then
			local totem = {}
			totem.GlobalId = spellId
			totem.Name = name
			totem.Texture = icon
			totem.SpellGroup = SPELL_GROUP_CALL
			totem.CallIndex = k
			totem.CallActionBase = actionBase + 1 + ((k - 1) * MAX_TOTEMS)

			AddTotem(self.TotemData, totem)
			count = count + 1
		end
	end

	for k, spellId in ipairs(WeaponImbues) do
		local name, icon, knownId = GetKnownSpell(spellId)

		if(name) then
			local totem = {}
			totem.GlobalId = knownId
			totem.Name = name
			totem.Texture = icon
			totem.SpellGroup = SPELL_GROUP_IMBUE

			AddTotem(self.TotemData, totem)
			count = count + 1
		end
	end

	self.TotemData.Count = count
end
