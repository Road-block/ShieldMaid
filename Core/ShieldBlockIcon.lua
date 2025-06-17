-- The addon namespace.
local addon, ns = ...
local _

-- Define the shield block icon class and put it in the addon namespace.
local ShieldBlockIcon = {}
local ShieldBlockIconMetatable = { __index = ShieldBlockIcon }
ns.ShieldBlockIcon = ShieldBlockIcon

-- Inherit methods from the Icon class.
setmetatable(ShieldBlockIcon, { __index = ns.Icon })

-- Constructor.
function ShieldBlockIcon:new(name)
	local self = ns.Icon:new(name)
	setmetatable(self, ShieldBlockIconMetatable)
	
	-- Set the Shield Block texture and spell name.
	local spellId = 132404
	local spellTable = C_Spell.GetSpellInfo(spellId)
	local spellName = spellTable.name
	local texture = spellTable.iconID
  self.Texture:SetTexture(texture)
	self.SpellName = spellName
	self.SpellId = spellId
	
	-- Dragging.
	self.Icon:SetScript("OnDragStop", self.OnDragStopHandler)
	
	return self
end

-- Handler that stops dragging and saves the position to the saved variables.
-- Note that self is the icon frame and not the icon class.
function ShieldBlockIcon:OnDragStopHandler()
	self:StopMovingOrSizing()
	ShieldMaidConfig.shieldBlockAnchor, _, _, ShieldMaidConfig.shieldBlockX, ShieldMaidConfig.shieldBlockY = self:GetPoint(1)
end

-- (Re)loads the icon with values from the saved variables config.
function ShieldBlockIcon:Reload()
	self:ReloadBase()
	
	-- Set the position.
	self.Icon:SetPoint(ShieldMaidConfig.shieldBlockAnchor, ShieldMaidConfig.shieldBlockX, ShieldMaidConfig.shieldBlockY)
end

-- Updates the icon.
function ShieldBlockIcon:Update(CurrentRage, totalBlocked, estimatedAbsorb, estimatedBlock, currentCharges)
	local name, _, _, _, _, expires = AuraUtil.FindAuraByName(self.SpellName, "player")
	local systemTime = GetTime()
	
	if (ShieldMaidConfig.showCharges) then
		self.ChargeText:SetText(currentCharges)
 	else
		self.ChargeText:SetText("")
	end 
	
	if name then
		self:UpdateTint(CurrentRage, 0)
		self.InfoText:SetText(self:FormatNumber(totalBlocked))
		self.InfoText:SetTextColor(ns.Config.infoTextColorActive[1], ns.Config.infoTextColorActive[2], ns.Config.infoTextColorActive[3], 1)
		self.DurationText:SetText(self:RoundNumber(expires - systemTime))
		self.Icon:SetAlpha(ns.Config.activeAlpha)
	else
		self.Icon:SetAlpha(ns.Config.inactiveAlpha)
		self:UpdateTint(CurrentRage, 30)
		self.InfoText:SetText(self:FormatNumber(estimatedBlock))
		self.InfoText:SetTextColor(ns.Config.infoTextColorInactive[1], ns.Config.infoTextColorInactive[2], ns.Config.infoTextColorInactive[3], 1)
		self.DurationText:SetText("")     
	end
		
	if (expires == 0) then
		local texture = C_Spell.GetSpellInfo(2565)["iconID"]
		self.Texture:SetTexture(texture)
	end
		
	self:UpdateCooldownBlock(2565)
end	