local _, ns = ...

if select(2, UnitClass('player')) ~= "SHAMAN" then
	return
end

local Yata = ns.Yata
local TOTEM_SET_PRIMARY_DEFAULT = ns.TOTEM_SET_PRIMARY_DEFAULT

local AceGUI = LibStub("AceGUI-3.0")

-- Each icon's id encodes its place on the bar: tens = column (spell group
-- position + 1), units = position within the column
local ICON_SIZE = 36
local ICON_MARGIN = 50

local editor -- the open editor, if any
local icons = {}
local iconPool = {}
local startIcon, stopIcon

local function UpdateIcons()
	for m,n in ipairs(icons) do
		local header = Yata.Bar.Groups[n.Button.Totem.SpellGroup].Header
		local id = (header:GetAttribute("position") + 1) * 10 + n.Button:GetAttribute("position")
		n.id = id
		n:ClearAllPoints()
		n:SetPoint("BOTTOMLEFT",n:GetParent(),"BOTTOMLEFT",ICON_MARGIN+(math.floor(id/10)-1)*ICON_SIZE,ICON_MARGIN+math.fmod(id,10)*ICON_SIZE)
	end
end

local function IconDrag(self, start)
	if start then
		C_Spell.PickupSpell(self.Button.Totem.Name)
		startIcon = self
	else
		ClearCursor()
		stopIcon = self
		if startIcon and stopIcon then
			if math.floor(startIcon.id/10) == math.floor(stopIcon.id/10) then
				-- same column: swap the two spells
				local idbackup = stopIcon.id
				stopIcon.id = startIcon.id
				startIcon.id = idbackup
				startIcon.Button:SetAttribute("newposition",math.fmod(startIcon.id,10))
				stopIcon.Button:SetAttribute("newposition",math.fmod(stopIcon.id,10))
			elseif math.fmod(startIcon.id,10)  == math.fmod(stopIcon.id,10) then
				-- same row of different columns: swap the two columns
				local backup = stopIcon.Button.Totem.SpellGroup
				local oldindex = math.floor(startIcon.id/10)
				local newindex = math.floor(stopIcon.id/10)
				local startHeader = Yata.Bar.Groups[startIcon.Button.Totem.SpellGroup].Header
				local stopHeader = Yata.Bar.Groups[backup].Header
				startHeader:SetAttribute("position",newindex-1)
				stopHeader:SetAttribute("position",oldindex-1)
				for m,n in ipairs(icons) do
					local nid = math.floor(n.id/10)
					if nid == oldindex then
						nid = newindex
					elseif nid == newindex then
						nid = oldindex
					end
					n.id = nid * 10 + math.fmod(n.id,10)
				end
			end
			UpdateIcons()
		end
		startIcon = nil
		stopIcon = nil
	end
end

local function UpdateVisibility(icon)
	if icon.Button:GetAttribute("hidden") then
		icon.Visibility:SetText("Hide")
		icon.Visibility:SetVertexColor(1.0, 0.0, 0, 0.75)
	else
		icon.Visibility:SetText("Show")
		icon.Visibility:SetVertexColor(0.0, 1.0, 0, 0.75)
	end
end

local function TotemClick(self)
	self.Button:SetAttribute("hidden", not self.Button:GetAttribute("hidden"))
	UpdateVisibility(self)
end

local function AcquireIcon(button, parent)
	local icon = table.remove(iconPool)
	if not icon then
		icon = CreateFrame("Button", nil, parent)
		icon:RegisterForClicks("LeftButtonUp","RightButtonUp")
		icon:RegisterForDrag("LeftButton")
		icon:SetScript("OnClick", TotemClick)
		icon:SetScript("OnDragStart", function(self) IconDrag(self, true) end)
		icon:SetScript("OnReceiveDrag", function(self) IconDrag(self, nil) end)
		icon:SetSize(ICON_SIZE, ICON_SIZE)
		icon.Icon = icon:CreateTexture(nil, "ARTWORK")
		icon.Icon:SetAllPoints(icon)
		icon.Visibility = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		icon.Visibility:SetSize(ICON_SIZE, 10)
		icon.Visibility:SetPoint("CENTER",0,-10)
	end
	icon:SetParent(parent)
	icon:SetFrameLevel(parent:GetFrameLevel() + 2)
	icon.Button = button
	icon.Icon:SetTexture(button.Totem.Texture)
	UpdateVisibility(icon)
	icon:Show()
	return icon
end

local function ReleaseIcons()
	for _, icon in ipairs(icons) do
		icon:Hide()
		icon:SetParent(nil)
		icon.Button = nil
		table.insert(iconPool, icon)
	end
	table.wipe(icons)
end

local function RefreshSetList(self)
	local list = {}
	for name in pairs(Yata.CurrentDb.Sets) do
		list[name] = name
	end
	self.loadsetdropdown:SetList(list)
	self.loadsetdropdown:SetValue(Yata.CurrentDb.CurrentTotemSet)
end

local methods = {}

function methods:AddSet(name)
	if name and name ~= "" then
		Yata:SetTotemSet(name,nil)
		Yata.CurrentDb.CurrentTotemSet = name
		RefreshSetList(self)
	end
end

function methods:DelSet(name)
	if name and name ~= TOTEM_SET_PRIMARY_DEFAULT then
		if name == Yata.CurrentDb.CurrentTotemSet then
			Yata.CurrentDb.CurrentTotemSet = TOTEM_SET_PRIMARY_DEFAULT
			Yata.Bar:ApplyTotemSet()
		end
		if Yata.CurrentDb.Sets[name] then
			Yata.CurrentDb.Sets[name] = nil
		end
		RefreshSetList(self)
		UpdateIcons()
	end
end

function Yata:OpenLayoutEditor()
	if editor then
		return
	end

	local self = setmetatable({}, { __index = methods })
	editor = self

	self.main = AceGUI:Create("Frame")
	self.main:SetTitle("Layout Editor")
	self.main:SetLayout("Flow")
	self.main:SetWidth(400)
	self.main:SetHeight(560)
	self.main:EnableResize(false)
	self.main:SetCallback("OnClose", function(widget)
		ClearCursor()
		ReleaseIcons()
		AceGUI:Release(widget)
		editor = nil
	end)

	self.loadsetdropdown = AceGUI:Create("Dropdown")
	self.loadsetdropdown:SetLabel("Totemset")
	self.loadsetdropdown:SetFullWidth(true)
	self.loadsetdropdown:SetCallback("OnValueChanged", function(widget, event, value)
		Yata.Bar:ApplyTotemSet(value)
		Yata.CurrentDb.CurrentTotemSet = value
		UpdateIcons()
	end)
	self.main:AddChild(self.loadsetdropdown)

	self.addsetbutton = AceGUI:Create("Button")
	self.addsetbutton:SetText("Add Set")
	self.addsetbutton:SetWidth(110)
	self.addsetbutton:SetCallback("OnClick", function() StaticPopup_Show("Yata_AddSet", nil, nil, self) end)
	self.main:AddChild(self.addsetbutton)

	self.delsetbutton = AceGUI:Create("Button")
	self.delsetbutton:SetText("Delete Set")
	self.delsetbutton:SetWidth(110)
	self.delsetbutton:SetCallback("OnClick", function() StaticPopup_Show("Yata_DelSet", nil, nil, self) end)
	self.main:AddChild(self.delsetbutton)

	self.savebutton = AceGUI:Create("Button")
	self.savebutton:SetText("Save")
	self.savebutton:SetWidth(110)
	self.savebutton:SetCallback("OnClick", function() Yata:SetTotemSet(nil, nil) end)
	self.main:AddChild(self.savebutton)

	RefreshSetList(self)

	for m,n in ipairs(Yata.Bar.Groups.All) do
		table.insert(icons, AcquireIcon(n, self.main.frame))
	end
	UpdateIcons()
end
