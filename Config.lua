-- The addon namespace.
local addon, ns = ...

-- Define the config and put it in the addon namespace.
local cfg = {}
ns.Config = cfg

-- Slash command settings. These are defaults and will only be taken into account the first time the addon loads for each character.
cfg.Default = {}
cfg.Default.shieldBarrierAnchor		= "CENTER"				-- Shield Barrier frame anchor. Possible values are: "TOP", "RIGHT", "BOTTOM", "LEFT", "TOPRIGHT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "CENTER".
cfg.Default.shieldBlockAnchor		= "CENTER"              -- Shield Block frame anchor. Possible values are: See above.
cfg.Default.shieldBarrierX			= 34					-- x-offset for the Shield Barrier icon.
cfg.Default.shieldBarrierY			= -200					-- y-offset for the Shield Barrier icon.
cfg.Default.shieldBlockX			= -34					-- x-offset for the Shield Block icon.
cfg.Default.shieldBlockY			= -200					-- y-offset for the Shield Block icon.
cfg.Default.size					= 60					-- The icon width and height.
cfg.Default.scale					= 1						-- The scale.
cfg.Default.margin					= 2						-- The margin around icons.
cfg.Default.hiddenOutOfCombat		= false					-- Indicates whether frames are hidden when out of combat.
cfg.Default.showFrames				= false					-- Show the icon frames (rounded corners).
cfg.Default.showCharges				= false					-- Show text reflecting how many shield block charges are available.
cfg.Default.showGlowBar				= false					-- Show a glow over the Shield Barrier icon showing the % of maximum value that Shield Barrier is currently at. Adjustable via cfg.barColor and cfg.barAlpha.
cfg.Default.showCooldown			= true					-- Show the classic cooldown "clock" on icons.
cfg.Default.secondaryBarrier		= true					-- Display estimated value of Shield Barrier while the buff is currently active.
cfg.Default.truncatedNumbers		= true					-- Truncate numbers, ie. 12345 --> 12k.
cfg.Default.updateIntervalCombat	= 0.2					-- Time (in seconds) between updates while in combat.
cfg.Default.updateIntervalNoCombat	= 0.25					-- Time (in seconds) between updates while out of combat.
cfg.Default.locked					= false					-- Lock the frames when true.
cfg.Default.tankOnly				= true					-- Display icons only while protection specialization. Set to false to enable for all specializations.

-- General settings. Requires that you reload the addon before they take effect.
cfg.strata							= "MEDIUM"				-- Frame strata. Possible values are: "PARENT", "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP"
cfg.activeAlpha						= 1						-- Transparency when buffs are active. 0 = fully transparent, 1 = fully opaque.
cfg.inactiveAlpha					= 0.6					-- Transparency when buffs are inactive. 0 = fully transparent, 1 = fully opaque.
cfg.unavailableTint         	    = {0.4, 0.4, 1}			-- The rgb color-values of the tint used when abilities are unavailable due to low rage.
cfg.barColor						= {0, 1, 0}				-- The rgb color-value of the Shield Barrier bar.
cfg.barAlpha						= 0.5					-- Shield Barrier bar transparency. Set this to 0 in order to hide the  bar.
cfg.backgroundColor					= {0, 0, 0}				-- The rgb color-value of the background.
cfg.backgroundAlpha					= 1						-- Background transparency. Set this to 0 in order to hide the  bar.
--cfg.shieldBarrierFraction			= 0.25					-- The fraction of absorb left on your current shield barrier compared to the estimated absorb value before the addon suggests that you reapply the buff.
--cfg.shieldBarrierTimeout			= 3						-- The time left on the shield barrier when the addon starts suggesting that you reapply it.
--cfg.shieldBlockTimeout			= 1						-- The time left on the shield block when the addon starts suggesting that you reapply it.

-- Text settings. Requires that you reload the addon before they take effect.
cfg.font							= "Fonts\\FRIZQT__.TTF"	-- The font used for numbers on icons.
cfg.fontOutline						= "OUTLINE"				-- The font outline. Possible values are any comma-delimited combination of "OUTLINE", "THICKOUTLINE" and "MONOCHROME".
cfg.durationTextSize				= 30					-- The size of the text that displays remaining buff duration.
cfg.durationTextColor				= {1, 1, 1}				-- The rgb color-values for the duration text. Use values between 0 and 1. 
cfg.durationTextJustifyH			= "CENTER"				-- Horizontal justification of the duration text. Possible values are: "CENTER, "LEFT", "RIGHT".
cfg.durationTextAnchor				= "CENTER"				-- The anchor of the duration text. The anchor is relative to the icon.
cfg.durationTextX					= 0						-- x-offset for the duration text relative to the icon.
cfg.durationTextY					= 6						-- y-offset for the duration text relative to the icon.
cfg.infoTextSize					= 20					-- The size of the text that displays buff information.
cfg.infoTextColorActive				= {0, 1, 0}				-- The rgb color-values for the info text when buffs are active. Use values between 0 and 1.
cfg.infoTextColorInactive			= {1, 1, 1}				-- The rgb color-values for the info text when buffs are inactive. Use values between 0 and 1.
cfg.infoTextJustifyH				= "CENTER"				-- Horizontal justification of the info text. Possible values are: "CENTER, "LEFT", "RIGHT".
cfg.infoTextAnchor					= "BOTTOM"				-- The anchor of the info text. The anchor is relative to the icon.
cfg.infoTextX						= 2						-- x-offset for the info text relative to the icon.
cfg.infoTextY						= 2						-- y-offset for the info text relative to the icon.

-- Text settings used when secondary barrier is enabled.
cfg.infoTextTopColor				= {1, 1, 0}				-- The rgb color-values for the duration text. Use values between 0 and 1. 
cfg.infoTextTopSize					= 18					-- The size of the text that displays buff information.
cfg.infoTextTopX					= 2						-- x-offset for the info text relative to the icon.
cfg.infoTextTopY					= -1					-- y-offset for the info text relative to the icon.
cfg.infoTextTopAnchor				= "TOP"					-- The anchor of the info text. The anchor is relative to the icon.
cfg.infoTextTopJustifyH				= "CENTER"				-- Horizontal justification of the info text. Possible values are: "CENTER, "LEFT", "RIGHT".

cfg.durationText2Size				= 26					-- The size of the text that displays remaining buff duration.
cfg.durationText2X					= 0						-- x-offset for the duration text relative to the icon.
cfg.durationText2Y					= 0						-- y-offset for the duration text relative to the icon.

cfg.infoTextBottomSize				= 18					-- The size of the text that displays buff information.
cfg.infoTextBottomX					= 2						-- x-offset for the info text relative to the icon.
cfg.infoTextBottomY					= 1						-- y-offset for the info text relative to the icon.
cfg.infoTextBottomAnchor			= "BOTTOM"				-- The anchor of the info text. The anchor is relative to the icon.

-- Text settings when showing of shield block charges is enabled.
cfg.chargeTextAnchor				= "TOPLEFT"				-- The anchor of the charges text.
cfg.chargeTextJustifyH				= "CENTER"				-- Horizontal justification of the charges text.
cfg.chargeTextX						= 2 					-- x-offset for the info text relative to the icon.
cfg.chargeTextY						= -1					-- y-offset for the info text relative to the icon.
cfg.chargeTextSize					= 16					-- The size of the text that displays available shield block charges.
cfg.chargeTextColor					= {1, 1, 1}				-- The rgb color-values for the charges text. Use values between 0 and 1.
