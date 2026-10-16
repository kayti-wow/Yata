local _, ns = ...

if select(2, UnitClass('player')) ~= "SHAMAN" then
	return
end

local Yata = ns.Yata
local SpellGroups = ns.SpellGroups
local SPELL_GROUP_CALL, SPELL_GROUP_IMBUE = ns.SPELL_GROUP_CALL, ns.SPELL_GROUP_IMBUE

local TotemBar = CreateFrame("Frame")
TotemBar.__index = TotemBar
ns.TotemBar = TotemBar

local Masque = LibStub("Masque", true)
	
function TotemBar.Create()
	local bar = CreateFrame("Frame", "YataBarGrip", UIParent, "SecureFrameTemplate, SecureHandlerAttributeTemplate")
	setmetatable(bar, TotemBar)
	
	bar:New()
	
	return bar
end

function TotemBar:New()
	self:Init()

	Yata:InitTotems()
	Yata:InitTotemSets()
	
	self.Set = Yata:GetTotemSet(nil) -- Retrieve the current set
	
	-- Need to get the group order then iterate through the other items
	for k, spellgroup in ipairs(self.Set["GroupOrder"]) do
		
		-- Create the header and proxy for the group
		local header = ns.Header:Create(spellgroup, self)
		header:Show()
		header:SetParent(self)
		self.Groups[spellgroup].Header = header
	
		local proxy = Yata.Button:CreateTotemProxy(spellgroup,self)
		
		if Yata.CurrentDb.BarOrientation == 1 then -- HU
			proxy:SetPoint("TOPLEFT",proxy.Parent,"TOPLEFT",(k-1)*36, #self.Set[spellgroup] * 36)
		elseif Yata.CurrentDb.BarOrientation == 2 then -- HD
			proxy:SetPoint("TOPLEFT",proxy.Parent,"TOPLEFT",(k-1)*36, #self.Set[spellgroup] * -36)
		elseif Yata.CurrentDb.BarOrientation == 3 then -- VR
			proxy:SetPoint("TOPLEFT",proxy.Parent,"TOPLEFT", #self.Set[spellgroup] * 36,(k-1)*-36)
		elseif Yata.CurrentDb.BarOrientation == 4 then -- VL
			proxy:SetPoint("TOPLEFT",proxy.Parent,"TOPLEFT",#self.Set[spellgroup] * -36,(k-1)*-36)
		end
	
		proxy:Hide();
		proxy:SetParent(self)
		self.Groups[spellgroup].Proxy = proxy
		
		self:AddMasqueButton(proxy)
		
		for l, totemname in ipairs(self.Set[spellgroup]) do

			-- Create the buttons for each spell
			local totem = Yata:GetTotem(totemname)	
			
			local button = Yata.Button:Create(totem.Name,self.Groups[totem.SpellGroup].Header, totem)
					
			self:AddMasqueButton(button)
			
			button:SetAttribute("position", l-1)
			
			button:SetOnClickScript()
			
			table.insert(self.Groups.All, button)
			table.insert(self.Groups[totem.SpellGroup].Buttons,button)
		end
	end
	
	self:SetAttribute("swapkey",Yata.CurrentDb.ButtonSwapKey)
	self:SetAttribute("noswapkey",Yata.CurrentDb.ButtonNoSwapKey)
	self:SetAttribute("setcallkey", Yata.CurrentDb.ButtonSetCallKey)
	self:SetAttribute("autoswap", Yata.CurrentDb.AutoButtonSwap)
	self:SetAttribute("autoswaptocall", Yata.CurrentDb.AutoSwapToCall)	
		
	self:SetProxyBinding()
	self:SetManualSwapToCallKey()
	self:ConfigureBarDisplay()
		
	self:PositionButtons()
	
	Yata:InitTimer()

	self:EditMacro(true,nil,nil)
end

function TotemBar:ApplyTotemSet(name)

	local set = Yata:GetTotemSet(name)

	for k, spellGroup in ipairs(set.GroupOrder) do -- Loop through the spellgroups and apply position to the headers
		self.Groups[spellGroup].Header:SetAttribute("position", k-1)
	
		for j, spellName in ipairs(set[spellGroup]) do -- Loop through each spellgroup and apply position to the buttons
			for l, button in ipairs(self.Groups[spellGroup].Buttons) do
				if button.Totem.Name == spellName then
					button:SetAttribute("newposition", j-1 )
				end
			end
		end
	end
	
	if (set["HiddenSpells"]) then
		for j, spellName in ipairs(set["HiddenSpells"]) do -- Loop through each button and set to hidden if hidden
			for l, button in ipairs(self.Groups.All) do
				if button.Totem.Name == spellName then
					button:SetAttribute("hidden", true)
				end
			end
		end
	end
end

function TotemBar:Destroy()
	self:SetParent(nil)
	self.Name = nil
	self:Hide()
	self:UnregisterAllEvents()
		
	for k,spellgroup in ipairs(SpellGroups) do
			
		if self.Groups[spellgroup].Header then		
			self.Groups[spellgroup].Header:SetParent(nil)
			self.Groups[spellgroup].Header:Hide()
		end			
	
		if(self.Groups[spellgroup].Proxy) then
			if self.MasqueGroup then
				self.MasqueGroup:RemoveButton(self.Groups[spellgroup].Proxy)
			end
			self.Groups[spellgroup].Proxy:SetParent(nil)
			self.Groups[spellgroup].Proxy:Hide()
		end
	end
	
	for m,button in ipairs(self.Groups.All) do
		if(button) then
			if self.MasqueGroup then
				self.MasqueGroup:RemoveButton(button)
			end
			button:SetParent(nil)
			button:Hide()
		end
	end
end

function TotemBar:Init()
	self.Name = "YataBarGrip"
	self.Parent = UIParent
	self:SetHeight(36)
	self:SetWidth(0)
	self.Texture = self:CreateTexture()
	self.Texture:SetColorTexture(0, 0, 0.5, 0.5)
	self.Texture:SetAllPoints(self)	
	self:RegisterForDrag( "LeftButton" )
	self:EnableMouse(true)
	self:SetMovable(true)
	
	self:SetAttribute("_onattributechanged", [[
		local headers = newtable(self:GetChildren())
		local buttons
			
		if (name == "autocall" and self:GetAttribute("autoswaptocall") == true) or (name == "manualcall") then
			local buttonToMove, buttonAtZero, buttonOldPos
			local globalID		
					
			-- we have a base actionid
			-- loop through each totem element in this call spell			
			-- get the headers of each spellgroup and loop through their children
			-- check the globalid of the action in the slot vs the globalid on the button
			-- if they match then swap the totem with the one currently in position 0
			for i = value, value + 3 do
				_, globalID, _ = GetActionInfo(i)
				
				if globalID then
					for j,header in ipairs(headers) do
						buttons = newtable(header:GetChildren())
						buttonToMove = nil
						buttonAtZero = nil
						buttonOldPos = nil			
												
						for k, button in ipairs(buttons) do
							if button and button:GetAttribute("globalid") then
								if button:GetAttribute("position") == 0 then 
									buttonAtZero = button
								end
								if globalID == button:GetAttribute("globalid") then
									buttonToMove = button
									buttonOldPos = button:GetAttribute("position")
								end
							end
						end
						
						if buttonToMove and buttonAtZero and buttonOldPos > 0 then
							buttonToMove:SetAttribute("newposition", 0)
							buttonAtZero:SetAttribute("newposition", buttonOldPos)
						end
					end
				end
			end
		elseif name == "updateindicators" then
			local key = self:GetAttribute("setcallkey")					
			
			for j,header in ipairs(headers) do
				if header:GetAttribute("istotemgroup") == true then
					buttons = newtable(header:GetChildren())
										
					for k, button in ipairs(buttons) do
						-- currentcallindex is only set once a Call spell is on the bar
						local currentaction = button:GetAttribute("actionid") + (self:GetAttribute("currentcallindex") or 0) * 4
						local _, globalId, _ = GetActionInfo(currentaction)
						
						if button:GetAttribute("globalid") == globalId then
							button:SetAttribute(key.."-spell1", nil)
						else
							button:SetAttribute(key.."-spell1", button:GetAttribute("globalid"))
						end
						
						button:SetAttribute("action", currentaction)
					end
				end
			end
		end
	]] )
	
	self:SetScript("OnDragStart", function()
		if(not Yata.CurrentDb.Locked) then
			self:StartMoving()
		end
	end)
	self:SetScript("OnDragStop", function()
		self:StopMovingOrSizing()
		self:SaveBarConfig()
	end)	
	
	self.Groups = {["All"] = {},
							["Earth"] = { ["Header"] = nil, ["Buttons"] = {}, ["Proxy"] = nil}, 
							["Fire"] = {["Header"] = nil, ["Buttons"] = {}, ["Proxy"] = nil }, 
							["Water"] = {["Header"] = nil, ["Buttons"] = {}, ["Proxy"] = nil }, 
							["Air"] = {["Header"] = nil, ["Buttons"] = {}, ["Proxy"] = nil }, 
							[SPELL_GROUP_CALL] = {["Header"] = nil, ["Buttons"] = {}, ["Proxy"] = nil }, 
							[SPELL_GROUP_IMBUE] = {["Header"] = nil, ["Buttons"] = {}, ["Proxy"] = nil }}
	
	if Masque then
		self.MasqueGroup = Masque:Group("Yata")
		-- Re-layout when the skin is changed or Masque is toggled for our group
		local onSkinChanged = function() self:SkinChanged() end
		if self.MasqueGroup.RegisterCallback then
			self.MasqueGroup:RegisterCallback(onSkinChanged)
		elseif self.MasqueGroup.SetCallback then
			self.MasqueGroup:SetCallback(onSkinChanged)
		end
	end
	
	self:RegisterEvent("UPDATE_MULTI_CAST_ACTIONBAR")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	
	self:SetScript("OnEvent", function(self, event, ...) self:OnEvent(event, ...) end)
	
	self:LoadPosition()
end

function TotemBar:PositionButtons()
	for j, spellgroup in ipairs(SpellGroups) do
		for k, button in ipairs(self.Groups[spellgroup].Buttons) do
			button:SetAttribute("newposition", k-1)
		end
	end
end

function TotemBar:SetPopOutScale(value)
	for i,spellgroup in ipairs(SpellGroups) do
		self.Groups[spellgroup].Header:SetAttribute("popoutscale", value)
	end
end

-- Masque keeps its own skin settings, so we only need to hand it our buttons
function TotemBar:AddMasqueButton(button)
	if self.MasqueGroup then
		self.MasqueGroup:AddButton(button, {Icon = button.Icon, HotKey = button.HotKey, Cooldown = button.Cooldown})
	end
end

-- Blizzard's default button art needs a little extra room between buttons
function TotemBar:UsesDefaultSkin()
	local group = self.MasqueGroup
	return group == nil or (group.db ~= nil and group.db.Disabled == true)
end

function TotemBar:SkinChanged()
	-- Laying out the bar sets attributes on secure headers
	if InCombatLockdown() then
		self.layoutPending = true
		return
	end
	self.layoutPending = nil
	self:ConfigureBarDisplay()
end

function TotemBar:SetManualSwapToCallKey(key)
	Yata.CurrentDb.ManualSwapToCallKey = key or Yata.CurrentDb.ManualSwapToCallKey
	for i,b in ipairs(self.Groups[SPELL_GROUP_CALL].Buttons) do
		local manualswaptocallkey = Yata.CurrentDb.ManualSwapToCallKey
		local prefix = ""
		if(manualswaptocallkey ~= "none") then
			prefix = manualswaptocallkey.."-"
		end
	
		b:SetAttribute(prefix.."type2", "attribute")
		b:SetAttribute(prefix.."attribute-name2", "manualcall")
		b:SetAttribute(prefix.."attribute-value2", b.Totem.CallActionBase)
		b:SetAttribute(prefix.."attribute-frame2", b:GetParent():GetParent())
	end
end

function TotemBar:LoadPosition()
	if Yata.CurrentDb.Locked then
		self.Texture:Hide()
	end	
	local x,y,scale
	if Yata.CurrentDb.BarPosition then
		x = Yata.CurrentDb.BarPosition.x
		y = Yata.CurrentDb.BarPosition.y
	else
		self:ClearAllPoints()
		self:SetPoint( "CENTER", WorldFrame, "CENTER", 0,0 )
		x = self:GetLeft()
		y = self:GetBottom()
	end	
	self:ClearAllPoints()
	self:SetPoint("BOTTOMLEFT", UIParent,"BOTTOMLEFT", x, y)
	self:SetScale(Yata.CurrentDb.BarScale)	
end

function TotemBar:SaveBarConfig()
	if not Yata.CurrentDb.BarPosition then 
		Yata.CurrentDb.BarPosition = {}
	end
	
	local x = self:GetLeft()
	local y = self:GetBottom()
	
	Yata.CurrentDb.BarPosition.x = x
	Yata.CurrentDb.BarPosition.y = y
end

function TotemBar:Unlock()
	Yata.CurrentDb.Locked = false
	self.Texture:Show()
	for k,v in ipairs(SpellGroups) do
		self.Groups[v].Header:Hide()
	end
	Yata:ShowTimerAnchors()
end

function TotemBar:Lock()
	Yata.CurrentDb.Locked = true
	self.Texture:Hide()
	self:SaveBarConfig()
	for k,v in ipairs(SpellGroups) do
		self.Groups[v].Header:Show()
	end
	Yata:HideTimerAnchors()	
end

function TotemBar:ConfigureBarDisplay(gapValue, orientationValue, visibleValue)
	gapValue = gapValue or Yata.CurrentDb.ButtonGap
	orientationValue = orientationValue or Yata.CurrentDb.BarOrientation
	visibleValue = visibleValue or Yata.CurrentDb.VisibleButtons
	
	Yata.CurrentDb.ButtonGap = gapValue
	Yata.CurrentDb.BarOrientation = orientationValue
	Yata.CurrentDb.VisibleButtons = visibleValue
	
	local defaultSkin = self:UsesDefaultSkin()
	if defaultSkin then
		gapValue = gapValue + 4
	end
	
	local buttonSize =  36 + gapValue
	
	for k, spellgroup in ipairs(SpellGroups) do
		local header = self.Groups[spellgroup].Header
		header:SetAttribute("buttongap",gapValue)
		header:SetWidth(36)
		header:SetHeight(36)
		header:SetAttribute("visiblebuttons", visibleValue)
		header:SetAttribute("orientation",orientationValue)
		header:SetAttribute("position",k-1)
		header:SetAttribute("show",false)
	end
	
	if orientationValue <= 2 then
		self:SetWidth(#SpellGroups * buttonSize)
		self:SetHeight(36)
	else
		self:SetHeight(#SpellGroups * buttonSize)
		self:SetWidth(36)
	end

	self:PositionButtons()

	for k,v in ipairs(self.Groups.All) do
		 if defaultSkin then
			v.Duration:SetPoint("TOP",v.Parent,"BOTTOM",0,-4)
		 else
			v.Duration:SetPoint("TOP",v.Parent,"BOTTOM",0,0)
		end
		v:LayoutCallFrame(defaultSkin)
	end
		
	self:ApplyTotemSet()
	
	if Yata.CurrentDb.AdvancedEnabled and Yata.CurrentDb.AdvHideBar then
		self:Hide()
	end
	
	self:SetAlpha(Yata.CurrentDb.Alpha or 1)
end

function TotemBar:UpdateAllButtons(spellgroup)
	for k, button in ipairs(self.Groups[spellgroup].Buttons) do
		button:SetCallIndicators()
	end
end

function TotemBar:UpdateCallIndicators()
	for k, button in ipairs(self.Groups.All) do
		button:SetCallIndicators()
	end
end

function Yata:LIBKEYBOUND_ENABLED()
	for i,b in ipairs(SpellGroups) do
		Yata.Bar.Groups[b].Header:SetAttribute("visiblebuttons",10)
		Yata.Bar.Groups[b].Header:SetAttribute("show",true)
		Yata.Bar.Groups[b].Proxy:Show()
	end
	Yata.keyBoundMode = true
end

function Yata:LIBKEYBOUND_DISABLED()
	self.Bar:SetProxyBinding()

	Yata.keyBoundMode = nil
	for i,b in ipairs(SpellGroups) do
		Yata.Bar.Groups[b].Header:SetAttribute("visiblebuttons",Yata.CurrentDb.VisibleButtons)
		Yata.Bar.Groups[b].Header:SetAttribute("show",false)
		Yata.Bar.Groups[b].Proxy:Hide()
		
		for j, button in ipairs(Yata.Bar.Groups[b].Buttons) do
			button:SetAttribute("newposition", button:GetAttribute("position"))
		end
	end
end

function Yata:LIBKEYBOUND_MODE_COLOR_CHANGED()
end

function TotemBar:SetProxyBinding()
	for i,b in ipairs(SpellGroups) do
		local key = GetBindingKey(format("CLICK %s:LeftButton", self.Groups[b].Proxy.Name))
		self.Groups[b].Header:SetAttribute("proxybinding",key)
	end
end

function TotemBar:UpdateKeyBinds()
	for i,b in ipairs(self.Groups.All) do
		b:UpdateHotkey()
	end
end

function TotemBar:OnEvent(event, ...)
	if event == "PLAYER_REGEN_ENABLED" then
		if self.layoutPending then
			self:SkinChanged()
		end
		Yata:RefreshTotemSlots()
		self:EditMacro(true, nil, nil)
	elseif event == "UPDATE_MULTI_CAST_ACTIONBAR" then
		self:UpdateCallIndicators()
	end
end

local MACRO_NAME = "YataTotemStomp"
local MACRO_ICON = 134400 -- INV_Misc_QuestionMark: lets #showtooltip pick the icon
local MAX_CHARACTER_MACRO_COUNT = MAX_CHARACTER_MACROS
	or (Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_CHARACTER_MACROS)
	or 18

function TotemBar:EditMacro(force, old, new)
	if Yata.CurrentDb.MacroEnabled == true and not InCombatLockdown() then
		local numGlobal, numLocal = GetNumMacros()
		local macroindex = GetMacroIndexByName(MACRO_NAME)
		local hasRoom = numLocal < MAX_CHARACTER_MACRO_COUNT
		if force or (macroindex == 0 and hasRoom) then
			local macro = "#showtooltip\n/castsequence reset=combat/"..Yata.CurrentDb.MacroResetKey.." "
			local totems = {}
			local set = Yata:GetTotemSet()
			for k,v in ipairs(set.GroupOrder) do
				if v ~= SPELL_GROUP_IMBUE and v~= SPELL_GROUP_CALL then
					for i,b in ipairs(self.Groups[v].Buttons) do
						if b:GetAttribute("position") == 0 then
							table.insert(totems,b.Totem.Name)
							break
						end
					end
				end
			end
			macro = macro..table.concat(totems, ", ")
			if macroindex > 0 then
				EditMacro(macroindex, MACRO_NAME, MACRO_ICON, macro)
			elseif hasRoom then
				CreateMacro(MACRO_NAME, MACRO_ICON, macro, true)
			end
		elseif macroindex > 0 and old and new then
			local name, texture, macro = GetMacroInfo(macroindex)
			macro = string.gsub(macro,old,new)
			EditMacro(macroindex, name, texture, macro)
		end	
	end
end
