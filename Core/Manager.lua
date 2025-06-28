-- The addon namespace.
local addon, ns = ...

-- Create options menu
local smOptions = CreateFrame("Frame")
smOptions.name = addon
local category, layout = Settings.RegisterCanvasLayoutCategory(smOptions, addon)
Settings.RegisterAddOnCategory(category)

-- Define the manager class and put it in the addon namespace.
local Manager = {}
local ManagerMetatable = { __index = Manager }
ns.Manager = Manager

-- Upvalues.
local GetSpecialization = function(...)
	if _G.GetSpecialization then
		return _G.GetSpecialization(...)
	elseif C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
		return C_SpecializationInfo.GetSpecialization(...)
	end
end
local GetItemStats = function(...)
	if _G.GetItemStats then
		return _G.GetItemStats(...)
	elseif C_Item and C_Item.GetItemStats then
		return C_Item.GetItemStats(...)
	end
end
local IsEventValid = C_EventUtils.IsEventValid
local block_metas = {
	[35501] = true,
	[41396] = true,
	[52293] = true,
	[76896] = true,
}
-- Constructor.
function Manager:new(shieldBarrierIcon, shieldBlockIcon)
	local self = {}
	setmetatable(self, ManagerMetatable)
	
	-- Initialize variables.
	self.Initialized = false
	self.Active = false
	self.PlayerName = UnitName("player") 
	self.PlayerGUID = UnitGUID("player")
	self.CurrentRage = 0
	self.TotalBlocked = 0
	self.ShieldBlockActive = false
	self.ShieldBarrierActive = false
	self.BlockedAmounts = ns.LinkedList:new()
	self.ElapsedTime = 0.0
	self.ShieldBarrierIcon = shieldBarrierIcon
	self.ShieldBlockIcon = shieldBlockIcon
	self.ShieldBlockPct = 0.3
	self.ShieldBlockCritPct = 0.6
	self.weaponStats = {
		DPS = 0
	}

	-- Main frame (pun intended) for listening.
	self.Main =  CreateFrame("Frame", nil, UIParent)
	--[[
[06:21:23] shield block active
[06:21:24] spell a:3036,o:-1,s:1,r:nil,b:1364,bb:nil
[06:21:26] swing a:2735,o:-1,s:1,r:nil,b:1229,bb:nil
[06:21:28] SWING:DODGE
[06:21:29] shield block dropped
	]]
	-- Event handler stuff. handlers are not fired when the addon is inactive, 
	-- listeners are. This is just my personal terminology.
	self.Handlers = {}
	self.Listeners = {}
	local subEvents = {
		SPELL_AURA_APPLIED = true,
		SPELL_AURA_REMOVED = true,
		SWING_DAMAGE = true,
		SPELL_DAMAGE = true,
		SWING_MISSED = true,
		SPELL_MISSED = true,
	}
	function self.Handlers.COMBAT_LOG_EVENT_UNFILTERED(sender, ...)
		if not self.ShieldBlockIcon.Active then
			return
		end

		local timestamp, eventType, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21, arg22, arg23, arg24 = CombatLogGetCurrentEventInfo()
		
		if not subEvents[eventType] then return end
		if not (destGUID and (destGUID == self.PlayerGUID)) then return end

		local spellId = arg12
		if eventType == "SPELL_AURA_APPLIED" then
			if spellId == self.ShieldBlockIcon.SpellId then
				self.ShieldBlockActive = true
				self.TotalBlocked = 0
			end
		end 
		
		if eventType == "SPELL_AURA_REMOVED" then
			if spellId == self.ShieldBlockIcon.SpellId then
				if not AuraUtil.FindAuraByName(self.ShieldBlockIcon.SpellName, "player") then
					self.ShieldBlockActive = false
				elseif AuraUtil.FindAuraByName(self.ShieldBlockIcon.SpellName, "player") then
					self.TotalBlocked = 0
				end
			end
		end
		
		if eventType == "SWING_DAMAGE" then
			local amount,overkill,school,resisted,d_blocked,d_absorbed = arg12,arg13,arg14,arg15,arg16,arg17
			local damage = arg12 or 0
			local blocked = arg16 or 0
			local absorbed = arg17 or 0

			self.BlockedAmounts:Add(damage + blocked + absorbed)
			
			if blocked and blocked > 0 and self.ShieldBlockActive then
				self.TotalBlocked = self.TotalBlocked + blocked
			end
		end
		
		if eventType == "SPELL_DAMAGE" then
			local amount,overkill,school,resisted,d_blocked,d_absorbed = arg15,arg16,arg17,arg18,arg19,arg20
			local damage = arg15 or 0
			local blocked = arg19 or 0
			local absorbed = arg20 or 0

			if (blocked and blocked > 0) or ShieldMaidSpellDatabase[spellId] then
				self.BlockedAmounts:Add(damage + blocked + absorbed)
			end
			
			if blocked and blocked > 0 then
				ShieldMaidSpellDatabase[spellId] = true
				
				if self.ShieldBlockActive then
					self.TotalBlocked = self.TotalBlocked + blocked
				end
			end
		end
		
		if eventType == "SWING_MISSED" then
			local missType = arg12
			local absorbed = arg15 or 0
			if missType == "ABSORB" then
				self.BlockedAmounts:Add(absorbed)
			end
		end
		
		if eventType == "SPELL_MISSED" then
			local missType = arg15
			local absorbed = arg18 or 0
			if missType == "ABSORB" and ShieldMaidSpellDatabase[spellId] then
				self.BlockedAmounts:Add(absorbed)
			end
		end
	end

	function self.Handlers.PLAYER_EQUIPMENT_CHANGED(sender, ...)
		local slotID = ...
		if slotID == INVSLOT_HEAD then
			self.ShieldBlockPct, self.ShieldBlockCritPct = self:CalculateBlockPct()
		end
	end

	function self.Handlers.UNIT_POWER_UPDATE(sender, ...)
		local unitId = ...
		if unitId == "player" then
			self.CurrentRage = UnitPower("player", SPELL_POWER_RAGE)
		end
	end

	function self.Handlers.PLAYER_REGEN_ENABLED(...)
		if ShieldMaidConfig.hiddenOutOfCombat then
			self.ShieldBarrierIcon:Hide()
			self.ShieldBlockIcon:Hide()
		end
	end

	function self.Handlers.PLAYER_REGEN_DISABLED(...)
		if ShieldMaidConfig.hiddenOutOfCombat then
			self.ShieldBarrierIcon:Show()
			self.ShieldBlockIcon:Show()
		end
	end	

	function self.Listeners.ADDON_LOADED(sender, ...)
		local name = ...
		if name == addon then
			self:LoadDefaultConfig()
			self:LoadSpellDatabase()
			self:Options()
			self:CheckOptions()			
		end
	end
	
	function self.Listeners.PLAYER_LOGIN(...)
		self:Load()
		self:CheckOptions()
		self:CalculateBlockPct()
	end
	
	function self.Listeners.ACTIVE_TALENT_GROUP_CHANGED(...)
		self:Load()
	end

	function self.Listeners.PLAYER_SPECIALIZATION_CHANGED(...)
		self:Load()
	end
	
	function self.Listeners.SPELLS_CHANGED(...)
		self:Load()
	end
	
	return self
end

function Manager:CalculateBlockPct()
	local itemID = GetInventoryItemID("player",INVSLOT_HEAD)
	if itemID then
		local gemID = GetInventoryItemGems(INVSLOT_HEAD)
		if gemID and block_metas[gemID] then
			self.ShieldBlockPct = 0.31
			self.ShieldBlockCritPct = 0.61
		end
	end
	self.ShieldBlockPct = 0.3
	self.ShieldBlockCritPct = 0.6
	return self.ShieldBlockPct, self.ShieldBlockCritPct
end

local sb_mult = 2.0 -- pre 5.2 and MoP Clasic, was 1.8 for 5.3+
-- Returns an estimate of the maximum absorb value of Shield Barrier.
function Manager:CalculateMaxAbsorb()
	-- essentially limited by max vengeance
  local _, strength = UnitStat("player",LE_UNIT_STAT_STRENGTH)
  local _, stamina = UnitStat("player", LE_UNIT_STAT_STAMINA)
  local attackPowerSTR = GetAttackPowerForStat(LE_UNIT_STAT_STRENGTH,strength)
  local attackPowerVENG = UnitHealthMax("player")
  local attackPower = attackPowerSTR + attackPowerVENG
  local rageMultiplier = 1
  return max(sb_mult * (attackPower - 2 * strength), stamina * 2.5) * rageMultiplier
end

-- Calculates the estimated absorb value.
function Manager:CalculateEstimatedAbsorb()
	local rage = UnitPower("player", Enum.PowerType.Rage)
	local baseAttackPower, positiveBuff, negativeBuff = UnitAttackPower("player")
	local attackPower = baseAttackPower + positiveBuff + negativeBuff
	local _, strength = UnitStat("player", LE_UNIT_STAT_STRENGTH)
	local _, stamina = UnitStat("player", LE_UNIT_STAT_STAMINA)
	local rageMultiplier = max(20, min(60, rage)) / 60.0
	return max(sb_mult * (attackPower - 2 * strength), stamina * 2.5) * rageMultiplier
end

-- Calculates the estimated block based on entries from the past 6 seconds in the linked list.
-- At the same time, entries more than 6 seconds old are removed.
function Manager:CalculateEstimatedBlock()
	local sum = self.BlockedAmounts:Sum(6)
	local criticalBlockChance = GetMastery() * 2.2/100
	local criticalBlock,normalBlock

	criticalBlock = sum * criticalBlockChance * self.ShieldBlockCritPct
	normalBlock = sum * (1 - criticalBlockChance) * self.ShieldBlockPct
	
	return criticalBlock + normalBlock
end

-- Tick function, called in updateInterval intervals.
function Manager:Tick()
	local estimatedMax,estimatedAbsorb,estimatedBlock,currentCharges
	if self.ShieldBarrierIcon.Active or self.ShieldBlockIcon.Active then
		estimatedMax = self:CalculateMaxAbsorb()
		estimatedAbsorb = math.min(self:CalculateEstimatedAbsorb(),estimatedMax)
		estimatedBlock = self:CalculateEstimatedBlock()
	end
	if self.ShieldBarrierIcon.Active then
		self.ShieldBarrierIcon:Update(self.CurrentRage, estimatedAbsorb, estimatedBlock, estimatedMax)
	end
	if self.ShieldBlockIcon.Active then
		currentCharges = C_Spell.GetSpellCharges(2565).currentCharges
		self.ShieldBlockIcon:Update(self.CurrentRage, self.TotalBlocked, estimatedAbsorb, estimatedBlock, currentCharges)
	end
end

-- Enables/disables the addon depending on class and spec. 
function Manager:Load()
	local class, _ = UnitClassBase("player")
	local spec = GetSpecialization()
	if class == "WARRIOR" and spec == 3 or (not ShieldMaidConfig.tankOnly and IsSpellKnown(112048)) then
		self.Active = true
		--C_Timer.After(3, function() self.Active = true end)
		if not self.ShieldBarrierIcon.Active and not self.ShieldBlockIcon.Active then
			self.ShieldBarrierIcon:Reload()
			self.ShieldBlockIcon:Reload()
			self.ShieldBarrierIcon:Show()
			self.ShieldBlockIcon:Show()
			self.ShieldBarrierIcon.Active = true
			self.ShieldBlockIcon.Active = true
	
			-- In case we reload or change spec in the middle of combat, we check for it here.
			if UnitAffectingCombat("player") or not ShieldMaidConfig.hiddenOutOfCombat then
				self.ShieldBarrierIcon:Show()
				self.ShieldBlockIcon:Show()
			else
				self.ShieldBarrierIcon:Hide()
				self.ShieldBlockIcon:Hide()
			end
			
			ns.Console.Write("|c0000FF00Loaded|r")
		end		
	elseif self.Active then
		self.Active = false
		self.ShieldBarrierIcon:Hide()
		self.ShieldBlockIcon:Hide()
		self.ShieldBlockIcon.Active = false
		self.ShieldBarrierIcon.Active = false
		ns.Console.Write("|c00FF0000Unloaded|r")
	end
end

-- Handler that makes sure the Tick function is called every ns.Config.updateInterval seconds.
function Manager:OnUpdateHandler(sender, seconds)
	local test
	if UnitAffectingCombat("player") then
		test = ShieldMaidConfig.updateIntervalCombat
	else
		test = ShieldMaidConfig.updateIntervalNoCombat
	end
	
	self.ElapsedTime = self.ElapsedTime + seconds
	if self.Active and self.ElapsedTime > test then
		self:Tick()
		self.ElapsedTime = self.ElapsedTime - test
	end
end

-- OnEvent handler that delegates to the correct handler. If inactive, we only handle ACTIVE_TALENT_GROUP_CHANGED.
function Manager:OnEventHandler(sender, event, ...)
	if self.Active and self.Handlers[event] then
		self.Handlers[event](sender, ...)
	end
	if self.Listeners[event] then
		self.Listeners[event](sender, ...)
	end
end

-- Registers update and event handlers.
function Manager:RegisterHandlers()
	for k, v in pairs(self.Handlers) do
		if IsEventValid(k) then
			self.Main:RegisterEvent(k);
		end
	end
	
	for k, v in pairs(self.Listeners) do
		if IsEventValid(k) then
			self.Main:RegisterEvent(k);
		end
	end

	self.Main:SetScript("OnUpdate", function(...) self:OnUpdateHandler(...) end)
	self.Main:SetScript("OnEvent", function(...) self:OnEventHandler(...) end)
end

-- Set the default configuration if no previous configuration has been saved.
function Manager:LoadSpellDatabase()
	if not ShieldMaidSpellDatabase then
		ShieldMaidSpellDatabase = {}
	end
end

-- Set the default configuration if no previous configuration has been saved.
function Manager:LoadDefaultConfig()
	if not ShieldMaidConfig then
		ShieldMaidConfig = {}
	end

	for k, v in pairs(ns.Config.Default) do
		if ShieldMaidConfig[k] == nil then
			ShieldMaidConfig[k] = v
		end
	end
end

-- Set the default configuration if no previous configuration has been saved.
function Manager:Reset()
	ShieldMaidConfig = {}
	for k, v in pairs(ns.Config.Default) do
		ShieldMaidConfig[k] = v
	end
	
	self.ShieldBarrierIcon:Reload()
	self.ShieldBlockIcon:Reload()
end

-- Locks the icons.
function Manager:SetLock(value)
	ShieldMaidConfig.locked = value
	if (value) then
		self.ShieldBarrierIcon:Lock()
		self.ShieldBlockIcon:Lock()
	else
		self.ShieldBarrierIcon:Unlock()
		self.ShieldBlockIcon:Unlock()
	end	
end

-- Sets the icon sizes.
function Manager:SetIconSize(size)
	ShieldMaidConfig.size = size
	self.ShieldBarrierIcon:Reload()
	self.ShieldBlockIcon:Reload()
end

-- Sets the icon scale.
function Manager:SetScale(scale)
	ShieldMaidConfig.scale = scale
	self.ShieldBarrierIcon:Reload()
	self.ShieldBlockIcon:Reload()
end

-- Sets the icon margin.
function Manager:SetMargin(margin)
	ShieldMaidConfig.margin = margin
	self.ShieldBarrierIcon:Reload()
	self.ShieldBlockIcon:Reload()
end

-- Sets a value indicating whether to hide the icons when out of combat.
function Manager:SetHiddenOutOfCombat(value)
	ShieldMaidConfig.hiddenOutOfCombat = value
	if UnitAffectingCombat("player") or not ShieldMaidConfig.hiddenOutOfCombat then
		self.ShieldBarrierIcon:Show()
		self.ShieldBlockIcon:Show()
	else
		self.ShieldBarrierIcon:Hide()
		self.ShieldBlockIcon:Hide()
	end
end

function Manager:SetShowCharges(value)
	ShieldMaidConfig.showCharges = value
end

function Manager:SetUpdateIntervalCombat(value)
	if value < .01 then
		value = .01
	elseif value > .5 then
		value = .5
	end
	ShieldMaidConfig.updateIntervalCombat = value
end

function Manager:GetUpdateIntervalCombat()
	return ShieldMaidConfig.updateIntervalCombat
end

function Manager:SetSecondaryBarrier(value)
	ShieldMaidConfig.secondaryBarrier = value
end

function Manager:SetUpdateIntervalNoCombat(value)
	if value < .1 then
		value = .1
	elseif value > 2 then
		value = 2
	end
	ShieldMaidConfig.updateIntervalNoCombat = value
end

function Manager:GetUpdateIntervalNoCombat()
	return ShieldMaidConfig.updateIntervalNoCombat
end

function Manager:SetSecondaryBarrier(value)
	ShieldMaidConfig.secondaryBarrier = value
end

-- Sets a value indicating whether to show the icon frames.
function Manager:SetShowFrames(value)
	ShieldMaidConfig.showFrames = value
	self.ShieldBarrierIcon:Reload()
	self.ShieldBlockIcon:Reload()
end

-- Sets a value indicating whether to show the glow bar for Shield Barrier.
function Manager:SetShowGlowBar(value)
	ShieldMaidConfig.showGlowBar = value
end

function Manager:SetTruncatedNumbers(value)
	ShieldMaidConfig.truncatedNumbers = value
end

function Manager:SetTankOnly(value)
	ShieldMaidConfig.tankOnly = value
	self:Load()
end

-- Sets a value indicating whether to show the cooldown "clock" on icons.
function Manager:SetShowCooldown(value)
	ShieldMaidConfig.showCooldown = value
end

--Interface options panel
function Manager:Options()
	local title = smOptions:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	title:SetTextColor(1, 1, .20)
	title:SetPoint("CENTER", 0, 280)
	title:SetText(smOptions.name)

	ShieldMaidBarrierButton = CreateFrame("CheckButton", "ShieldMaidBarrierButton_GlobalName", smOptions, "ChatConfigCheckButtonTemplate")
	ShieldMaidBarrierButton:SetPoint("TOPLEFT", 32, -50)
	ShieldMaidBarrierButton_GlobalNameText:SetText("Display Secondary Shield Barrier Estimates")
	ShieldMaidBarrierButton.tooltip = "Check to display the estimated value of hitting Shield Barrier while Shield Barrier is already active."
	ShieldMaidBarrierButton:SetScript("OnClick", 
		function()
			if ShieldMaidBarrierButton:GetChecked() then
				self:SetSecondaryBarrier(true)
				PlaySound(856) -- Check Click Sound
			else
				self:SetSecondaryBarrier(false)
				PlaySound(857) -- Check Unclick Sound
			end
		end)
		
	ShieldMaidOOCButton = CreateFrame("CheckButton", "ShieldMaidOOCButton_GlobalName", smOptions, "ChatConfigCheckButtonTemplate")
	ShieldMaidOOCButton:SetPoint("TOPLEFT", 32, -80)
	ShieldMaidOOCButton_GlobalNameText:SetText("Hide while out of combat")
	ShieldMaidOOCButton.tooltip = "Check to display the icons only while in combat."
	ShieldMaidOOCButton:SetScript("OnClick", 
		function()
			if ShieldMaidOOCButton:GetChecked() then
				self:SetHiddenOutOfCombat(true)
				PlaySound(856) -- Check Click Sound
			else
				self:SetHiddenOutOfCombat(false)
				PlaySound(857) -- Check Unclick Sound
			end
		end)
	
	ShieldMaidLockButton = CreateFrame("CheckButton", "ShieldMaidLockButton_GlobalName", smOptions, "ChatConfigCheckButtonTemplate")
	ShieldMaidLockButton:SetPoint("TOPLEFT", 32, -110)
	ShieldMaidLockButton_GlobalNameText:SetText("Lock Frames")
	ShieldMaidLockButton.tooltip = "Check to lock the icons, preventing them from being moved."
	ShieldMaidLockButton:SetScript("OnClick", 
		function()
			if ShieldMaidLockButton:GetChecked() then
				self:SetLock(true)
				PlaySound(856) -- Check Click Sound
			else
				self:SetLock(false)
				PlaySound(857) -- Check Unclick Sound
			end
		end)
	
	ShieldMaidGlowButton = CreateFrame("CheckButton", "ShieldMaidGlowButton_GlobalName", smOptions, "ChatConfigCheckButtonTemplate")
	ShieldMaidGlowButton:SetPoint("TOPLEFT", 32, -140)
	ShieldMaidGlowButton_GlobalNameText:SetText("Show Shield Barrier Icon Glow")
	ShieldMaidGlowButton.tooltip = "Check to display a green glow over the Shield Barrier icon showing the % of maximum value that Shield Barrier is currently at."
	ShieldMaidGlowButton:SetScript("OnClick", 
		function()
			if ShieldMaidGlowButton:GetChecked() then
				self:SetShowGlowBar(true)
				PlaySound(856) -- Check Click Sound
			else
				self:SetShowGlowBar(false)
				PlaySound(857) -- Check Unclick Sound
			end
		end)
		
	ShieldMaidFrameButton = CreateFrame("CheckButton", "ShieldMaidFrameButton_GlobalName", smOptions, "ChatConfigCheckButtonTemplate")
	ShieldMaidFrameButton:SetPoint("TOPLEFT", 32, -170)
	ShieldMaidFrameButton_GlobalNameText:SetText("Show Frame Border")
	ShieldMaidFrameButton.tooltip = "Check to display a border around each icon."
	ShieldMaidFrameButton:SetScript("OnClick", 
		function()
			if ShieldMaidFrameButton:GetChecked() then
				self:SetShowFrames(true)
				PlaySound(856) -- Check Click Sound
			else
				self:SetShowFrames(false)
				PlaySound(857) -- Check Unclick Sound
			end
		end)
		
	ShieldMaidTruncateButton = CreateFrame("CheckButton", "ShieldMaidTruncateButton_GlobalName", smOptions, "ChatConfigCheckButtonTemplate")
	ShieldMaidTruncateButton:SetPoint("TOPLEFT", 32, -200)
	ShieldMaidTruncateButton_GlobalNameText:SetText("Short Numbers")
	ShieldMaidTruncateButton.tooltip = "Check to abbreviate numbers down to 1 decimal place."
	ShieldMaidTruncateButton:SetScript("OnClick", 
		function()
			if ShieldMaidTruncateButton:GetChecked() then
				self:SetTruncatedNumbers(true)
				PlaySound(856) -- Check Click Sound
			else
				self:SetTruncatedNumbers(false)
				PlaySound(857) -- Check Unclick Sound
			end
		end)
		
	ShieldMaidCooldownButton = CreateFrame("CheckButton", "ShieldMaidCooldownButton_GlobalName", smOptions, "ChatConfigCheckButtonTemplate")
	ShieldMaidCooldownButton:SetPoint("TOPLEFT", 32, -230)
	ShieldMaidCooldownButton_GlobalNameText:SetText("Show Cooldown Clock")
	ShieldMaidCooldownButton.tooltip = "Check to show the cooldown clock on icons."
	ShieldMaidCooldownButton:SetScript("OnClick", 
		function()
			if ShieldMaidCooldownButton:GetChecked() then
				self:SetShowCooldown(true)
				PlaySound(856) -- Check Click Sound
			else
				self:SetShowCooldown(false)
				PlaySound(857) -- Check Unclick Sound
			end
		end)
	
	ShieldMaidTankButton = CreateFrame("CheckButton", "ShieldMaidTankButton_GlobalName", smOptions, "ChatConfigCheckButtonTemplate")
	ShieldMaidTankButton:SetPoint("TOPLEFT", 32, -260)
	ShieldMaidTankButton_GlobalNameText:SetText("Enable only for Protection")
	ShieldMaidTankButton.tooltip = "Check to only display icons while set as protection. Uncheck to show icons for all specializations."
	ShieldMaidTankButton:SetScript("OnClick", 
		function()
			if ShieldMaidTankButton:GetChecked() then
				self:SetTankOnly(true)
				self:Load()	
				PlaySound(856) -- Check Click Sound
			else
				self:SetTankOnly(false)
				self:Load()	
				PlaySound(857) -- Check Unclick Sound
			end
		end)
		
	ShieldMaidChargeButton = CreateFrame("CheckButton", "ShieldMaidChargeButton_GlobalName", smOptions, "ChatConfigCheckButtonTemplate")
	ShieldMaidChargeButton:SetPoint("TOPLEFT", 32, -290)
	ShieldMaidChargeButton_GlobalNameText:SetText("Show Shield Block Charges")
	ShieldMaidChargeButton.tooltip = "Check to display available shield block spell charges."
	ShieldMaidChargeButton:SetScript("OnClick", 
		function()
			if ShieldMaidChargeButton:GetChecked() then
				self:SetShowCharges(true)
				self:Load()	
				PlaySound(856) -- Check Click Sound
			else
				self:SetShowCharges(false)
				self:Load()	
				PlaySound(857) -- Check Unclick Sound
			end
		end)
	
	local title1 = smOptions:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetTextColor(1, 1, .20)
	title1:SetPoint("TOPLEFT", 32, -340)
	title1:SetText("Changes to the below options may only be visible after reloading UI")
	
	local titleSize = smOptions:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	titleSize:SetTextColor(1, 1, 1)
	titleSize:SetPoint("TOPLEFT", 35, -380)
	titleSize:SetText("Icon Size")	
	ShieldMaidSize = CreateFrame("EditBox", "Size", smOptions, "InputBoxTemplate")
	ShieldMaidSize:SetNumeric()
	ShieldMaidSize:ClearAllPoints()
	ShieldMaidSize:ClearFocus()
	ShieldMaidSize:SetSize(30, 30)
	ShieldMaidSize:SetPoint("TOPLEFT", 48, -390)
	ShieldMaidSize:SetText(tostring(ShieldMaidConfig.size))
	ShieldMaidSize:SetAutoFocus(false)
	ShieldMaidSize:SetCursorPosition(0)
	ShieldMaidSize:SetScript("OnEnterPressed", 
		function(number)
			local value = number:GetNumber()
			if value <= 10 then
				value = 10
			elseif value >= 100 then
				value = 100
			end
			self:SetIconSize(value)
			number:ClearFocus()			
		end)
		
	local titleScale = smOptions:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	titleScale:SetTextColor(1, 1, 1)
	titleScale:SetPoint("TOPLEFT", 124, -380)
	titleScale:SetText("Icon Scale %")	
	ShieldMaidScale = CreateFrame("EditBox", "Size", smOptions, "InputBoxTemplate")
	ShieldMaidScale:SetNumeric()
	ShieldMaidScale:ClearAllPoints()
	ShieldMaidScale:ClearFocus()
	ShieldMaidScale:SetSize(30, 30)
	ShieldMaidScale:SetPoint("TOPLEFT", 148, -390)
	ShieldMaidScale:SetText(tostring(ShieldMaidConfig.scale * 100))
	ShieldMaidScale:SetAutoFocus(false)
	ShieldMaidScale:SetCursorPosition(0)
	ShieldMaidScale:SetScript("OnEnterPressed", 
		function(number)
			local value = number:GetNumber()
			if (value <= 10) then
				value = .1
			elseif (value > 10 and value < 200) then
				value = (value / 100)
			elseif (value >= 200) then
				value = 2
			end
			self:SetScale(value)
			number:ClearFocus()
		end)
		
	local titleUpdate = smOptions:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	titleUpdate:SetTextColor(1, 1, 1)
	titleUpdate:SetPoint("TOPLEFT", 224, -380)
	titleUpdate:SetText("Updates/sec")	
	ShieldMaidUpdate = CreateFrame("EditBox", "Size", smOptions, "InputBoxTemplate")
	ShieldMaidUpdate:SetNumeric()
	ShieldMaidUpdate:ClearAllPoints()
	ShieldMaidUpdate:ClearFocus()
	ShieldMaidUpdate:SetSize(30, 30)
	ShieldMaidUpdate:SetPoint("TOPLEFT", 252, -390)
	ShieldMaidUpdate:SetText(tostring(1.00 / ShieldMaidConfig.updateIntervalCombat))
	ShieldMaidUpdate:SetAutoFocus(false)
	ShieldMaidUpdate:SetCursorPosition(0)
	ShieldMaidUpdate:SetScript("OnEnterPressed", 
		function(self)
			local value = self:GetNumber()
			if (value >= 2.00 and value <= 100.00) then
				ShieldMaidConfig.updateIntervalCombat = (1.00 / value)
			elseif value < 2.00 then
				ShieldMaidConfig.updateIntervalCombat = 0.5
			elseif value > 100.00 then
				ShieldMaidConfig.updateIntervalCombat = 0.05
			end
			self:ClearFocus()
		end)
	
	local titleUpdateOOC = smOptions:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	titleUpdateOOC:SetTextColor(1, 1, 1)
	titleUpdateOOC:SetPoint("TOPLEFT", 324, -380)
	titleUpdateOOC:SetText("Updates/sec OOC")	
	ShieldMaidUpdateOOC = CreateFrame("EditBox", "Size", smOptions, "InputBoxTemplate")
	ShieldMaidUpdateOOC:SetNumeric()
	ShieldMaidUpdateOOC:ClearAllPoints()
	ShieldMaidUpdateOOC:ClearFocus()
	ShieldMaidUpdateOOC:SetSize(30, 30)
	ShieldMaidUpdateOOC:SetPoint("TOPLEFT", 364, -390)
	ShieldMaidUpdateOOC:SetText(tostring(1.00 / ShieldMaidConfig.updateIntervalNoCombat))
	ShieldMaidUpdateOOC:SetAutoFocus(false)
	ShieldMaidUpdateOOC:SetCursorPosition(0)
	ShieldMaidUpdateOOC:SetScript("OnEnterPressed", 
		function(self)
			local value = self:GetNumber()
			if (value >= .5 and value <= 10.00) then
				ShieldMaidConfig.updateIntervalNoCombat = (1.00 / value)
			elseif value < 0.5 then
				ShieldMaidConfig.updateIntervalNoCombat = 2.00
			elseif value > 10.00 then
				ShieldMaidConfig.updateIntervalNoCombat = 0.1
			end
			self:ClearFocus()
		end)
	ShieldMaidBarrierButton:SetChecked(ShieldMaidConfig.secondaryBarrier)
	ShieldMaidOOCButton:SetChecked(ShieldMaidConfig.hiddenOutOfCombat)
	ShieldMaidLockButton:SetChecked(ShieldMaidConfig.locked)
	ShieldMaidGlowButton:SetChecked(ShieldMaidConfig.showGlowBar)	
	ShieldMaidFrameButton:SetChecked(ShieldMaidConfig.showFrames)
	ShieldMaidTruncateButton:SetChecked(ShieldMaidConfig.truncatedNumbers)
	ShieldMaidCooldownButton:SetChecked(ShieldMaidConfig.showCooldown)
	ShieldMaidTankButton:SetChecked(ShieldMaidConfig.tankOnly)
	ShieldMaidChargeButton:SetChecked(ShieldMaidConfig.showCharges)
	ShieldMaidSize:SetText(ShieldMaidConfig.size)
	ShieldMaidScale:SetText(ShieldMaidConfig.scale * 100)
	ShieldMaidUpdate:SetText(tostring(1.00 / ShieldMaidConfig.updateIntervalCombat))
	ShieldMaidUpdateOOC:SetText(tostring(1.00 / ShieldMaidConfig.updateIntervalNoCombat))	
end

function Manager:CheckOptions()
	ShieldMaidBarrierButton:SetChecked(ShieldMaidConfig.secondaryBarrier)
	ShieldMaidOOCButton:SetChecked(ShieldMaidConfig.hiddenOutOfCombat)
	ShieldMaidLockButton:SetChecked(ShieldMaidConfig.locked)
	ShieldMaidGlowButton:SetChecked(ShieldMaidConfig.showGlowBar)	
	ShieldMaidFrameButton:SetChecked(ShieldMaidConfig.showFrames)
	ShieldMaidTruncateButton:SetChecked(ShieldMaidConfig.truncatedNumbers)
	ShieldMaidCooldownButton:SetChecked(ShieldMaidConfig.showCooldown)	
	ShieldMaidTankButton:SetChecked(ShieldMaidConfig.tankOnly)
	ShieldMaidChargeButton:SetChecked(ShieldMaidConfig.showCharges)
	ShieldMaidSize:SetText(ShieldMaidConfig.size)
	ShieldMaidScale:SetText(ShieldMaidConfig.scale * 100)
	ShieldMaidUpdate:SetText(tostring(1.00 / ShieldMaidConfig.updateIntervalCombat))
	ShieldMaidUpdateOOC:SetText(tostring(1.00 / ShieldMaidConfig.updateIntervalNoCombat))	
end

function Manager:OpenOptions()
	Settings.OpenToCategory(category.ID)
end
