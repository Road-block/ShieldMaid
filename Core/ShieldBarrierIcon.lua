-- The addon namespace.
local addon, ns = ...
local _
-- Define the shield barrier icon class and put it in the addon namespace.
local ShieldBarrierIcon = {}
local ShieldBarrierIconMetatable = { __index = ShieldBarrierIcon }
ns.ShieldBarrierIcon = ShieldBarrierIcon

-- Inherit methods from the Icon class.
setmetatable(ShieldBarrierIcon, { __index = ns.Icon })

-- Constructor.
function ShieldBarrierIcon:new(name)
	local self = ns.Icon:new(name)	
	setmetatable(self, ShieldBarrierIconMetatable)
	
	-- Set the Shield Barrier texture and the spell name.
	local spellId = 112048
	local spellTable = C_Spell.GetSpellInfo(spellId)
	local spellName = spellTable.name
	local texture = spellTable.iconID
  self.Texture:SetTexture(texture)
	self.SpellName = spellName
	self.SpellId = spellId
	
	-- Shield Barrier bar.
	self.Bar = self.Icon:CreateTexture(nil, "ARTWORK")
	self.Bar:SetColorTexture(ns.Config.barColor[1], ns.Config.barColor[2], ns.Config.barColor[3], ns.Config.barAlpha)
	self.Bar:SetPoint("BOTTOMLEFT", self.Icon, "BOTTOMLEFT")
	self.Bar:SetPoint("BOTTOMRIGHT", self.Icon, "BOTTOMRIGHT")
	self.Bar.Max = 0

	-- Dragging.
	self.Icon:SetScript("OnDragStop", self.OnDragStopHandler)
	
	return self
end

-- Handler that stops dragging and saves the position to the saved variables.
-- Note that self is the icon frame and not the icon class.
function ShieldBarrierIcon:OnDragStopHandler()
	self:StopMovingOrSizing()
	ShieldMaidConfig.shieldBarrierAnchor, _, _, ShieldMaidConfig.shieldBarrierX, ShieldMaidConfig.shieldBarrierY = self:GetPoint(1)
end

-- (Re)loads the icon with values from the saved variables config.
function ShieldBarrierIcon:Reload()
	self:ReloadBase()
	
	-- Set the position.
	self.Icon:SetPoint(ShieldMaidConfig.shieldBarrierAnchor, ShieldMaidConfig.shieldBarrierX, ShieldMaidConfig.shieldBarrierY)
end

-- Utility function for setting the height of the Shield Barrier Bar.
function ShieldBarrierIcon:UpdateBar(absorb,estimatedMax)
	self.Bar.Max = estimatedMax
	if absorb > 0 then
		self.Bar:Show()
		self.Bar:SetHeight(ShieldMaidConfig.size * (absorb / self.Bar.Max))        
	else
		self.Bar:Hide()
	end
end

-- Updates the icon.
function ShieldBarrierIcon:Update(currentRage, estimatedAbsorb, estimatedBlock, estimatedMax)
	local name, _, _, _, _, expires, _, _, _, _, _, _, _, _, _, _, absorb = AuraUtil.FindAuraByName(self.SpellName, "player")
	local systemTime = GetTime()
	local absorbNumber = absorb or 0
	if name then
		self:UpdateTint(currentRage, 0)
		if ShieldMaidConfig.showGlowBar then self:UpdateBar(absorbNumber,estimatedMax) end
		self.InfoText:SetTextColor(ns.Config.infoTextColorActive[1], ns.Config.infoTextColorActive[2], ns.Config.infoTextColorActive[3], 1)
		self.InfoText:SetText(self:FormatNumber(absorbNumber)) 
		self.InfoText2:SetTextColor(0, 1, 0)
		
		if (absorbNumber > estimatedMax) then
			estimatedAbsorb = 0
			self.InfoText2:SetTextColor(1, 0, 0)		
		elseif (absorbNumber + estimatedAbsorb > estimatedMax) then
			estimatedAbsorb = estimatedMax - absorbNumber
			if estimatedAbsorb < estimatedMax * 0.005 then
				estimatedAbsorb = 0
			end
			self.InfoText2:SetTextColor(1, 1, 0)
		else
			self.InfoText2:SetTextColor(0, 1, 0)
		end

		
		if (ShieldMaidConfig.secondaryBarrier) then
			self.InfoText2:SetText(self:FormatNumber(estimatedAbsorb)) 
    	self.InfoText:SetPoint(ns.Config.infoTextBottomAnchor, ns.Config.infoTextBottomX, ns.Config.infoTextBottomY)
    	self.InfoText:SetFont(ns.Config.font, ns.Config.infoTextBottomSize, ns.Config.fontOutline)
 			self.DurationText:SetPoint(ns.Config.durationTextAnchor, ns.Config.durationText2X, ns.Config.durationText2Y)
   		self.DurationText:SetFont(ns.Config.font, ns.Config.durationText2Size, ns.Config.fontOutline)
 		else
			self.InfoText2:SetText("")
    	self.InfoText:SetPoint(ns.Config.infoTextAnchor, ns.Config.infoTextX, ns.Config.infoTextY)
    	self.InfoText:SetFont(ns.Config.font, ns.Config.infoTextSize, ns.Config.fontOutline)
 			self.DurationText:SetPoint(ns.Config.durationTextAnchor, ns.Config.durationTextX, ns.Config.durationTextY)
   		self.DurationText:SetFont(ns.Config.font, ns.Config.durationTextSize, ns.Config.fontOutline)
		end  
		self.DurationText:SetText(self:RoundNumber(expires - systemTime))
		self.Icon:SetAlpha(ns.Config.activeAlpha)
	else
		self:UpdateTint(currentRage, 35)
		self.Icon:SetAlpha(ns.Config.inactiveAlpha)
		self:UpdateBar(0,estimatedMax)
		self.InfoText:SetTextColor(ns.Config.infoTextColorInactive[1], ns.Config.infoTextColorInactive[2], ns.Config.infoTextColorInactive[3], 1)
		self.InfoText:SetText(self:FormatNumber(estimatedAbsorb)) 
		self.InfoText2:SetText("")
		self.DurationText:SetText("") 
		if (ShieldMaidConfig.secondaryBarrier) then
			self.InfoText:SetFont(ns.Config.font, ns.Config.infoTextBottomSize, ns.Config.fontOutline)
			self.InfoText:SetPoint(ns.Config.infoTextBottomAnchor, ns.Config.infoTextBottomX, ns.Config.infoTextBottomY)
		else
			self.InfoText:SetFont(ns.Config.font, ns.Config.infoTextSize, ns.Config.fontOutline)
			self.InfoText:SetPoint(ns.Config.infoTextAnchor, ns.Config.infoTextX, ns.Config.infoTextY)
		end		
	end
	
	self:UpdateCooldown(112048)
end