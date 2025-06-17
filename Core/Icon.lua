-- The addon namespace.
local addon, ns = ...

-- Define the icon class and put it in the addon namespace.
local Icon = {}
local IconMetatable = { __index = Icon }
ns.Icon = Icon

-- Constructor.
function Icon:new(name)
	local self = {} 
	setmetatable(self, IconMetatable)
		
	local cfg = ns.Config
	
	-- Indicates whether this icon is active.
	self.Active = false
	
	-- The icon frame.
	self.Icon = CreateFrame("Frame", name, UIParent) 
    self.Icon:SetFrameStrata(cfg.strata)
	self.Icon:SetFrameLevel(1)
    self.Icon:SetAlpha(cfg.inactiveAlpha)

	-- The background (frame).
	self.Background = self.Icon:CreateTexture(nil, "BACKGROUND")
	self.Background:SetTexture(cfg.backgroundColor[1], cfg.backgroundColor[2], cfg.backgroundColor[3], cfg.backgroundAlpha)
	
	-- The ability texture.
	self.Texture = self.Icon:CreateTexture(nil, "BACKGROUND")
    self.Texture:SetAllPoints(self.Icon)
    self.Texture:SetVertexColor(cfg.unavailableTint[1], cfg.unavailableTint[2], cfg.unavailableTint[3])
	
	-- The cooldown "clock".
	self.Cooldown = CreateFrame("Cooldown", nil, self.Icon)
	self.Cooldown:SetSwipeColor(0, 0, 0, 0.6)
	self.Cooldown:SetSwipeTexture("", 0, 0, 0, 1)
	self.Cooldown:SetDrawSwipe(true)
	self.Cooldown:SetHideCountdownNumbers(true)
	self.Cooldown:SetAllPoints()

	-- A frame for the text to overlay it properly.
	local textFrame = CreateFrame("Frame", nil, self.Icon)
	textFrame:SetAllPoints()
	
	-- The duration text.
	self.DurationText = textFrame:CreateFontString(nil, "OVERLAY")
    self.DurationText:SetJustifyH(cfg.durationTextJustifyH)
    self.DurationText:SetPoint(cfg.durationTextAnchor, cfg.durationTextX, cfg.durationTextY)
    self.DurationText:SetFont(cfg.font, cfg.durationTextSize, cfg.fontOutline)	
    self.DurationText:SetTextColor(cfg.durationTextColor[1], cfg.durationTextColor[2], cfg.durationTextColor[3], 1)
    self.DurationText:SetText("")
	
	-- The information text.
	self.InfoText = textFrame:CreateFontString(nil, "OVERLAY")
    self.InfoText:SetJustifyH(cfg.infoTextJustifyH)
    self.InfoText:SetPoint(cfg.infoTextAnchor, cfg.infoTextX, cfg.infoTextY)
    self.InfoText:SetFont(cfg.font, cfg.infoTextSize, cfg.fontOutline)	
    self.InfoText:SetTextColor(cfg.infoTextColorInactive[1], cfg.infoTextColorInactive[2], cfg.infoTextColorInactive[3], 1)
    self.InfoText:SetText("") 

	-- The information text for Shield Barrier secondary estimates.
	self.InfoText2 = textFrame:CreateFontString(nil, "OVERLAY")
    self.InfoText2:SetJustifyH(cfg.infoTextTopJustifyH)
    self.InfoText2:SetPoint(cfg.infoTextTopAnchor, cfg.infoTextTopX, cfg.infoTextTopY)
    self.InfoText2:SetFont(cfg.font, cfg.infoTextTopSize, cfg.fontOutline)	
    self.InfoText2:SetTextColor(cfg.infoTextTopColor[1], cfg.infoTextTopColor[2], cfg.infoTextTopColor[3], 1)
    self.InfoText2:SetText("") 
	
	-- The shield block spell charge amount text. 
	self.ChargeText = textFrame:CreateFontString(nil, "OVERLAY")
    self.ChargeText:SetJustifyH(cfg.chargeTextJustifyH)
    self.ChargeText:SetPoint(cfg.chargeTextAnchor, cfg.chargeTextX, cfg.chargeTextY)
    self.ChargeText:SetFont(cfg.font, cfg.chargeTextSize, cfg.fontOutline)	
    self.ChargeText:SetTextColor(cfg.chargeTextColor[1], cfg.chargeTextColor[2], cfg.chargeTextColor[3], 1)
    self.ChargeText:SetText("")
	
	-- Dragging.
	self.Icon:RegisterForDrag("LeftButton")
	self.Icon:SetScript("OnDragStart", self.Icon.StartMoving)
	
	return self
end

-- Initializes the icon with values from the saved variables config.
function Icon:ReloadBase()
	-- Size, strata and alpha.
    self.Icon:SetWidth(ShieldMaidConfig.size)
    self.Icon:SetHeight(ShieldMaidConfig.size)
    self.Icon:SetScale(ShieldMaidConfig.scale)
	
	-- The background (frame).
	self.Background:SetWidth(ShieldMaidConfig.size + 2 * ShieldMaidConfig.margin)
    self.Background:SetHeight(ShieldMaidConfig.size + 2 * ShieldMaidConfig.margin)
    self.Background:SetPoint("TOPLEFT", self.Icon, "TOPLEFT", -ShieldMaidConfig.margin, ShieldMaidConfig.margin)
	self.Background:SetPoint("BOTTOMRIGHT", self.Icon, "BOTTOMRIGHT", ShieldMaidConfig.margin, -ShieldMaidConfig.margin)
	
	-- The ability texture.
    if ShieldMaidConfig.showFrames then
        self.Texture:SetTexCoord(0, 1, 0, 1)
	else
		self.Texture:SetTexCoord(0.1, 0.8, 0.1, 0.8)
    end  
	
	-- Dragging
	if ShieldMaidConfig.locked then
		self.Icon:EnableMouse(false)
		self.Icon:SetMovable(false)
	else
		self.Icon:EnableMouse(true)
		self.Icon:SetMovable(true)
	end
end

-- Number format function.
function Icon:FormatNumber(number)
	if not ShieldMaidConfig.truncatedNumbers then
		number = floor(number)
		local left, middle, right = string.match(number,"^([^%d]*%d)(%d*)(.-)$")
		return left..(middle:reverse():gsub("(%d%d%d)","%1,"):reverse())..right
	elseif number > 1E10 then
		return floor(number / 1E9).."b"
	elseif number > 1E9 then
		return (floor((number / 1E9) * 10) / 10).."b"
	elseif number > 1E7 then
		return floor(number / 1E6).."m"
	elseif number > 1E6 then
		return (floor((number / 1E6) * 10) / 10).."m"
	elseif number > 1E4 then
		return (floor((number / 1E3) * 10) / 10).."k"
	elseif number > 1E3 then
		return (floor((number / 1E3) * 100) / 100).."k"
	else
		return floor(number)
	end
end

-- Rounds numbers to the nearest integer.
function Icon:RoundNumber(number)
	return math.floor(number + 0.5)
end

-- Updates icon tint.
function Icon:UpdateTint(currentRage, requiredRage)
	if currentRage < requiredRage then
		self.Texture:SetVertexColor(ns.Config.unavailableTint[1], ns.Config.unavailableTint[2], ns.Config.unavailableTint[3])
	else
		self.Texture:SetVertexColor(1, 1, 1)  
	end
end

-- Updates the cooldown "clock" for shield block
function Icon:UpdateCooldownBlock(spellID)
	if ShieldMaidConfig.showCooldown then
		local start = C_Spell.GetSpellCharges(spellID).cooldownStartTime or 0
		local duration = C_Spell.GetSpellCharges(spellID).cooldownDuration or 0
		if start and duration then
			self.Cooldown:SetCooldown(start, duration)
		end
	end
end

-- Updates the cooldown "clock" for Shield Barrier
function Icon:UpdateCooldown(spellID)
	if ShieldMaidConfig.showCooldown then
		local start = C_Spell.GetSpellCooldown(spellID).startTime or 0
		local duration = C_Spell.GetSpellCooldown(spellID).duration or 0
		--local enabled = C_Spell.GetSpellCooldown(spellID).isEnabled or 0
		if start and duration then
			self.Cooldown:SetCooldown(start, duration)
		end
	end
end

-- Shows the icon.
function Icon:Show()
	if self.Active then
		self.Icon:Show()
	end
end

-- Hides the icon.
function Icon:Hide()
	if not self.Active then
		self.Icon:Hide()
	end
end

-- Locks the icon.
function Icon:Lock()
	self.Icon:SetMovable(false)
	self.Icon:EnableMouse(false)
end

-- Unlocks the icon for dragging.
function Icon:Unlock()
	self.Icon:SetMovable(true)
	self.Icon:EnableMouse(true)
end