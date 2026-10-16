local _, ns = ...

if select(2, UnitClass('player')) ~= "SHAMAN" then
	return
end

local Yata = ns.Yata

-- Totem duration and cooldown timers.
--
-- In combat the client may hide totem and cooldown details from addons
-- ("secret values"): we can hand them to widgets but can't compare them or do
-- maths on them. So all timing goes through duration objects, which status
-- bars, cooldown spirals and text bindings consume directly, and we only
-- branch on values the API promises are never secret.

local LSM = LibStub("LibSharedMedia-3.0", true)

local TIMER_BARS, TIMER_BUTTONS, TIMER_BOTH = 1, 2, 3

local ElementColors = {
	Fire = { 1.0, 0.3, 0.3 },
	Earth = { 0.3, 0.8, 0.3 },
	Water = { 0.2, 0.8, 1.0 },
	Air = { 0.6, 0.6, 1.0 },
}
local CooldownColor = { 1.0, 0.65, 0.0 }

local durationFormatter = C_StringUtil.CreateSecondsFormatter()

local activeTotems = {}   -- totem slot -> button whose totem is down in that slot
local castTotems = {}     -- totem slot -> spell id we last saw the player cast for that slot
local coolingDown = {}    -- button -> true while its spell is on cooldown
local cooldownTicker

local function ShowsBars()
	return Yata.CurrentDb.TimerType == TIMER_BARS or Yata.CurrentDb.TimerType == TIMER_BOTH
end

local function ShowsButtons()
	return Yata.CurrentDb.TimerType == TIMER_BUTTONS or Yata.CurrentDb.TimerType == TIMER_BOTH
end

local function IsTotemSlotSecret(slot)
	return C_Secrets and C_Secrets.ShouldTotemSlotBeSecret and C_Secrets.ShouldTotemSlotBeSecret(slot)
end

--
-- Bar groups: a draggable anchor with a stack of timer bars
--

local BarGroup = {}
BarGroup.__index = BarGroup

local function CreateBarGroup(name, label, x, y)
	local anchor = CreateFrame("Frame", "Yata"..name.."Anchor", UIParent)
	anchor:SetSize(100, 12)
	anchor:SetMovable(true)
	anchor:SetClampedToScreen(true)
	anchor:RegisterForDrag("LeftButton")
	anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)

	anchor.Background = anchor:CreateTexture(nil, "BACKGROUND")
	anchor.Background:SetAllPoints()
	anchor.Background:SetColorTexture(0, 0, 0.5, 0.5)

	anchor.Label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	anchor.Label:SetPoint("CENTER")
	anchor.Label:SetText(label)

	anchor:SetScript("OnDragStart", anchor.StartMoving)
	anchor:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		Yata:SaveTimerConfig()
	end)

	local group = setmetatable({ Anchor = anchor, Bars = {}, Order = {}, Unused = {} }, BarGroup)
	group:HideAnchor()
	return group
end

function BarGroup:ShowAnchor()
	self.Anchor.Background:Show()
	self.Anchor.Label:Show()
	self.Anchor:EnableMouse(true)
end

function BarGroup:HideAnchor()
	self.Anchor.Background:Hide()
	self.Anchor.Label:Hide()
	self.Anchor:EnableMouse(false)
end

function BarGroup:SetPosition(x, y)
	self.Anchor:ClearAllPoints()
	self.Anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

function BarGroup:GetPosition()
	return self.Anchor:GetLeft(), self.Anchor:GetBottom()
end

function BarGroup:Configure(db)
	local orientation = db.TimerOrientation -- 1 left to right, 2 bottom to top, 3 right to left, 4 top to bottom
	self.Horizontal = orientation == 1 or orientation == 3
	self.Reverse = orientation == 3 or orientation == 4
	self.Thickness = db.TimerThickness
	self.Length = db.TimerLength
	self.Spacing = db.TimerSpacing
	self.GrowUp = db.TimerGrowUp
	self.Font = LSM and LSM:Fetch("font", db.TimerFont, true) or STANDARD_TEXT_FONT
	self.FontSize = db.TimerFontSize
	self.Texture = LSM and LSM:Fetch("statusbar", db.TimerBarSkin, true) or "Interface\\TargetingFrame\\UI-StatusBar"

	self.Anchor:SetScale(db.TimerScale)
	self.Anchor:SetFrameStrata(db.TimerStrata)
	if self.Horizontal then
		self.Anchor:SetSize(self.Length + self.Thickness, math.max(self.Thickness, 12))
	else
		self.Anchor:SetSize(math.max(self.Thickness, 12), self.Length + self.Thickness)
	end

	for key, bar in pairs(self.Bars) do
		self:StyleBar(bar)
	end
	for _, bar in ipairs(self.Unused) do
		self:StyleBar(bar)
	end
	self:Layout()
end

function BarGroup:CreateBar()
	local bar = CreateFrame("StatusBar", nil, self.Anchor)

	bar.Background = bar:CreateTexture(nil, "BACKGROUND")
	bar.Background:SetAllPoints()
	bar.Background:SetColorTexture(0, 0, 0, 0.5)

	bar.Icon = bar:CreateTexture(nil, "ARTWORK")
	bar.Label = bar:CreateFontString(nil, "OVERLAY")
	bar.Time = bar:CreateFontString(nil, "OVERLAY")

	bar.Binding = C_DurationUtil.CreateDurationTextBinding()
	bar.Binding:SetFontString(bar.Time)
	bar.Binding:SetFormatter(durationFormatter)

	self:StyleBar(bar)
	return bar
end

function BarGroup:StyleBar(bar)
	bar:SetStatusBarTexture(self.Texture)
	bar:SetOrientation(self.Horizontal and "HORIZONTAL" or "VERTICAL")
	bar:SetReverseFill(self.Reverse)

	for _, text in ipairs({ bar.Label, bar.Time }) do
		if not text:SetFont(self.Font, self.FontSize, "") then
			text:SetFont(STANDARD_TEXT_FONT, self.FontSize, "")
		end
		text:ClearAllPoints()
	end
	bar.Icon:ClearAllPoints()
	bar.Icon:SetSize(self.Thickness, self.Thickness)

	if self.Horizontal then
		bar:SetSize(self.Length, self.Thickness)
		bar.Icon:SetPoint("RIGHT", bar, "LEFT")
		bar.Label:SetPoint("LEFT", bar, "LEFT", 2, 0)
		bar.Label:SetPoint("RIGHT", bar.Time, "LEFT", -2, 0)
		bar.Label:SetJustifyH("LEFT")
		bar.Label:SetWordWrap(false)
		bar.Label:Show()
		bar.Time:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
	else
		bar:SetSize(self.Thickness, self.Length)
		bar.Icon:SetPoint("TOP", bar, "BOTTOM")
		bar.Label:Hide()
		bar.Time:SetPoint("BOTTOM", bar, "TOP", 0, 2)
	end
end

function BarGroup:Layout()
	local step = self.Thickness + self.Spacing
	for i, key in ipairs(self.Order) do
		local bar = self.Bars[key]
		local offset = (i - 1) * step + self.Spacing
		bar:ClearAllPoints()
		if self.Horizontal then
			if self.GrowUp then
				bar:SetPoint("BOTTOMLEFT", self.Anchor, "TOPLEFT", self.Thickness, offset)
			else
				bar:SetPoint("TOPLEFT", self.Anchor, "BOTTOMLEFT", self.Thickness, -offset)
			end
		else
			-- vertical bars sit side by side, each with its icon underneath
			if self.GrowUp then
				bar:SetPoint("BOTTOMLEFT", self.Anchor, "TOPLEFT", offset - self.Spacing, self.Thickness + self.Spacing)
			else
				bar:SetPoint("TOPLEFT", self.Anchor, "BOTTOMLEFT", offset - self.Spacing, -self.Spacing)
			end
		end
	end
end

function BarGroup:AcquireBar(key)
	local bar = self.Bars[key]
	if not bar then
		bar = table.remove(self.Unused) or self:CreateBar()
		self.Bars[key] = bar
		table.insert(self.Order, key)
		self:Layout()
	end
	bar:SetAlpha(1)
	bar:Show()
	return bar
end

function BarGroup:ReleaseBar(key)
	local bar = self.Bars[key]
	if not bar then
		return
	end
	bar.Binding:SetEnabled(false)
	bar:Hide()
	self.Bars[key] = nil
	tDeleteItem(self.Order, key)
	table.insert(self.Unused, bar)
	self:Layout()
end

function BarGroup:ReleaseAll()
	for _, key in ipairs(CopyTable(self.Order)) do
		self:ReleaseBar(key)
	end
end

function BarGroup:HasBars()
	return #self.Order > 0
end

-- text, icon and duration may be secret values: they are only passed to widgets
local function SetupBar(bar, text, icon, duration, color)
	bar.Label:SetText(text)
	bar.Icon:SetTexture(icon)
	bar:SetStatusBarColor(color[1], color[2], color[3])
	bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.RemainingTime)
	bar.Binding:SetDuration(duration)
	bar.Binding:SetEnabled(true)
end

--
-- Setup and configuration
--

function Yata:InitTimer()
	if not self.DurationGroup then
		self.DurationGroup = CreateBarGroup("Uptime", "Totem Uptime", 200, 200)
		self.CooldownGroup = CreateBarGroup("Cooldown", "Totem Cooldown", 300, 300)
	end

	self:RegisterEvent("PLAYER_DEAD")
	self:RegisterEvent("PLAYER_TOTEM_UPDATE")
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "UpdateCooldowns")

	self:LoadTimerConfig()
end

function Yata:SaveTimerConfig()
	if not self.DurationGroup then
		return
	end
	local x, y = self.DurationGroup:GetPosition()
	self.CurrentDb.DurationGroupPosition = { x = x, y = y }
	x, y = self.CooldownGroup:GetPosition()
	self.CurrentDb.CooldownGroupPosition = { x = x, y = y }
end

function Yata:SetTimerScale(scale)
	self.DurationGroup.Anchor:SetScale(scale)
	self.CooldownGroup.Anchor:SetScale(scale)
end

function Yata:LoadTimerConfig()
	local db = self.CurrentDb
	if db.DurationGroupPosition then
		self.DurationGroup:SetPosition(db.DurationGroupPosition.x, db.DurationGroupPosition.y)
	end
	if db.CooldownGroupPosition then
		self.CooldownGroup:SetPosition(db.CooldownGroupPosition.x, db.CooldownGroupPosition.y)
	end
	if db.Locked then
		self.DurationGroup:HideAnchor()
		self.CooldownGroup:HideAnchor()
	else
		self.DurationGroup:ShowAnchor()
		self.CooldownGroup:ShowAnchor()
	end
	self.DurationGroup:Configure(db)
	self.CooldownGroup:Configure(db)
end

function Yata:ShowTimerAnchors()
	self.DurationGroup:ShowAnchor()
	self.CooldownGroup:ShowAnchor()
end

function Yata:HideTimerAnchors()
	self.DurationGroup:HideAnchor()
	self.CooldownGroup:HideAnchor()
	self:SaveTimerConfig()
end

function Yata:ResetTimers()
	self:SaveTimerConfig()
	self:LoadTimerConfig()

	self:ClearTimers()

	self:RefreshTotemSlots()
	self:UpdateCooldowns()
end

function Yata:ClearTimers()
	self.DurationGroup:ReleaseAll()
	self.CooldownGroup:ReleaseAll()
	wipe(activeTotems)
	wipe(coolingDown)
	if self.Bar then
		for _, button in ipairs(self.Bar.Groups.All) do
			button.Cooldown:Clear()
		end
	end
end

--
-- Totem durations
--

-- Matches by spell id or exact name first, then falls back to a totem name
-- that only contains the spell name (e.g. a rank suffix). name must not be secret.
local function FindButton(spellId, name)
	if not spellId and not name then
		return nil
	end
	local buttons = Yata.Bar.Groups.All
	for _, button in ipairs(buttons) do
		local totem = button.Totem
		if totem.GlobalId == spellId or (name and totem.Name == name) then
			return button
		end
	end
	if name then
		name = name:lower()
		for _, button in ipairs(buttons) do
			if name:find(button.Totem.Name:lower(), 1, true) then
				return button
			end
		end
	end
end

function Yata:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellId)
	if unit ~= "player" or not self.Bar then
		return
	end

	local button = FindButton(spellId, C_Spell.GetSpellName(spellId))
	if not button then
		return
	end

	-- Remember spell ids rather than buttons: a Reload may replace the buttons
	local totem = button.Totem
	if totem.Slot then
		castTotems[totem.Slot] = totem.GlobalId
		self:UpdateTotemSlot(totem.Slot)
	elseif totem.CallActionBase then
		-- A Call spell drops the totems assigned to its page of the multicast bar
		for slot = 1, MAX_TOTEMS do
			local _, id = GetActionInfo(totem.CallActionBase + slot - 1)
			castTotems[slot] = id
			self:UpdateTotemSlot(slot)
		end
	end
end

function Yata:PLAYER_TOTEM_UPDATE(event, slot)
	self:UpdateTotemSlot(slot)
end

function Yata:PLAYER_DEAD()
	wipe(castTotems)
	self:ClearTimers()
end

-- In combat we can't tell when a totem expires, so the slot keeps pointing at
-- the last cast button. Re-read every slot once the details are visible again.
function Yata:RefreshTotemSlots()
	for slot = 1, MAX_TOTEMS do
		self:UpdateTotemSlot(slot)
	end
end

function Yata:UpdateTotemSlot(slot)
	if not self.CurrentDb.TimerEnabled or not self.Bar then
		return
	end

	local secret = IsTotemSlotSecret(slot)
	local haveTotem, name, icon, button

	if secret then
		-- We can't read which totem this is, so trust the last one we saw cast
		haveTotem, name, _, _, icon = GetTotemInfo(slot)
		button = FindButton(castTotems[slot])
	else
		local spellId
		haveTotem, name, _, _, icon, _, spellId = GetTotemInfo(slot)
		haveTotem = haveTotem and name ~= nil and name ~= ""
		if haveTotem then
			button = FindButton(spellId, name) or FindButton(castTotems[slot])
		else
			castTotems[slot] = nil
		end
	end

	local previous = activeTotems[slot]
	activeTotems[slot] = button
	if previous and previous ~= button then
		previous.Cooldown:Clear()
		self:UpdateButtonCooldown(previous)
	end

	local duration = GetTotemDuration(slot)

	if ShowsBars() then
		if secret or haveTotem then
			local bar = self.DurationGroup:AcquireBar(slot)
			local color = ElementColors[button and button.Totem.SpellGroup] or ElementColors.Earth
			SetupBar(bar, name, icon, duration, color)
			if secret then
				bar:SetAlphaFromBoolean(haveTotem, 1, 0)
			end
		else
			self.DurationGroup:ReleaseBar(slot)
		end
	end

	if ShowsButtons() and button then
		button.Cooldown:SetCooldownFromDurationObject(duration, true)
	end
end

--
-- Spell cooldowns
--

local function IsTotemActive(button)
	for _, active in pairs(activeTotems) do
		if active == button then
			return true
		end
	end
	return false
end

-- Returns true while the spell is on a real cooldown (not just the GCD).
-- isActive and isOnGCD are never secret.
local function IsOnCooldown(spell)
	local info = C_Spell.GetSpellCooldown(spell)
	return info ~= nil and info.isActive and not info.isOnGCD
end

function Yata:UpdateButtonCooldown(button)
	local totem = button.Totem
	local onCooldown = IsOnCooldown(totem.Name)
	local duration = onCooldown and C_Spell.GetSpellCooldownDuration(totem.Name, true)
	coolingDown[button] = onCooldown or nil

	if ShowsBars() then
		if duration then
			local bar = self.CooldownGroup:AcquireBar(totem.Name)
			SetupBar(bar, totem.Name, totem.Texture, duration, CooldownColor)
		else
			self.CooldownGroup:ReleaseBar(totem.Name)
		end
	end

	-- The spiral shows the totem's duration while it is down
	if ShowsButtons() and not IsTotemActive(button) then
		if duration then
			button.Cooldown:SetCooldownFromDurationObject(duration, true)
		else
			button.Cooldown:Clear()
		end
	end

	return onCooldown
end

local function StopCooldownTicker()
	if cooldownTicker then
		cooldownTicker:Cancel()
		cooldownTicker = nil
	end
end

-- SPELL_UPDATE_COOLDOWN doesn't reliably fire when a cooldown ends, so poll
-- the running ones and only update those that have finished
local function CheckCooldownsEnded()
	for button in pairs(coolingDown) do
		if not IsOnCooldown(button.Totem.Name) then
			Yata:UpdateButtonCooldown(button)
		end
	end
	if not next(coolingDown) then
		StopCooldownTicker()
	end
end

function Yata:UpdateCooldowns()
	if not self.CurrentDb.TimerEnabled or not self.Bar then
		wipe(coolingDown)
		StopCooldownTicker()
		return
	end

	for _, button in ipairs(self.Bar.Groups.All) do
		self:UpdateButtonCooldown(button)
	end

	if next(coolingDown) and not cooldownTicker then
		cooldownTicker = C_Timer.NewTicker(1, CheckCooldownsEnded)
	elseif not next(coolingDown) then
		StopCooldownTicker()
	end
end
