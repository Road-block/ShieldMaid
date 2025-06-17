-- The addon namespace.
local addon, ns = ...

-- Define the console class and put it in the addon namespace.
local Console = {}
local ConsoleMetatable = { __index = Console }
ns.Console = Console

-- Constructor.
function Console:new(manager)
	local self = {}
	setmetatable(self, ConsoleMetatable)
	
	self.Manager = manager
	
	-- Slash command handler
	function self.SlashCommandHandler(msg, editbox)
		local command, rest = msg:match("^(%S*)%s*(.-)$");
		command = strlower(command)
		rest = strlower(rest)
		if command == "" or command == "help" then
			Console.Write("Usage: /shieldmaid <command> or /sm <command>")
			Console.Write("Commands:")
			--Console.Write("help")
			Console.Write("options")
			Console.Write("reset")
			Console.Write("lock")
			Console.Write("unlock")
			--Console.Write("updateInterval")
			--Console.Write("secondaryBarrier true/false")
			Console.Write("size <pixels>")
			Console.Write("scale <number>")
			Console.Write("margin <pixels>")
			--Console.Write("hiddenOutOfCombat true/false")
			--Console.Write("showFrames true/false")
			--Console.Write("showGlow true/false")
			--Console.Write("showCooldown true/false")
			--Console.Write("truncatedNumbers true/false")
			--Console.Write("tankOnly true/false")
		elseif command == "reset" then
			self.Manager:Reset()	
			Console.Write("Configuration reset")
		elseif command == "options" then
			self.Manager:OpenOptions()
		elseif command == "lock" then
			self.Manager:SetLock(true)
			Console.Write("Frames locked")
			self.Manager:CheckOptions()
		elseif command == "unlock" then
			self.Manager:SetLock(false)
			Console.Write("Frames unlocked")
			self.Manager:CheckOptions()
		elseif (command == "secondarybarrier") or (command == "secondary") or (command == "barrier") or (command == "sb") or (command == "sbarrier") or (command == "secondaryb") then
			if rest == "true" then
				self.Manager:SetSecondaryBarrier(true)
				Console.Write("Estimated Shield Barrier value will be displayed while the buff is active.")
				self.Manager:CheckOptions()
			elseif rest == "false" then
				self.Manager:SetSecondaryBarrier(false)
				Console.Write("Estimated Shield Barrier value will no longer be displayed while the buff is active.")
				self.Manager:CheckOptions()
			else	
				if (ShieldMaidConfig.secondaryBarrier) then
					Console.Write("Estimated value of Shield Barrier is currently shown on the icon while Shield Barrier is active. (true)")
				else
					Console.Write("Estimated value of Shield Barrier is currently hidden on the icon while Shield Barrier is active. (false)")
				end
			end
		elseif command == "size" then
			local size = tonumber(rest)
			if size then
				self.Manager:SetIconSize(size)
				Console.Write("Size set to "..size)
				self.Manager:CheckOptions()
			else
				Console.Write("Size is currently set to: "..ShieldMaidConfig.size)
			end	
		elseif command == "scale" then
			local scale = tonumber(rest)
			if scale then
				self.Manager:SetScale(scale)
				self.Manager:CheckOptions()
				Console.Write("Scale set to "..scale)
			else
				Console.Write("Scale is currently set to: "..ShieldMaidConfig.scale)
			end
		elseif command == "margin" then
			local margin = tonumber(rest)
			if margin then
				self.Manager:SetMargin(margin)
				self.Manager:CheckOptions()
				Console.Write("Margin set to "..margin)
			else
				Console.Write("Margin is currently set to: "..ShieldMaidConfig.margin)
			end	
		elseif (command == "updateinterval") or (command == "update") or (command == "interval") or (command == "ui") or (command == "updatei") or (command == "uinterval")  then
			local updateInterval = tonumber(rest)
			if updateInterval then
				if updateInterval < .01 then
					updateInterval = .01
				elseif updateInterval > .5 then
					updateInterval = .5
				end				
				self.Manager:SetUpdateIntervalCombat(updateInterval)
				self.Manager:CheckOptions()
				Console.Write("Update interval set to "..updateInterval)
			else
				Console.Write("Update interval is currently set to: "..ShieldMaidConfig.updateIntervalCombat)
			end	
		elseif (command == "hiddenoutofcombat") or (command == "hiddenooc") or (command == "hidden") or (command == "combat") or (command == "hooc") or (command == "ooc") then
			if rest == "true" then
				self.Manager:SetHiddenOutOfCombat(true)
				Console.Write("Icons will be hidden out of combat.")
				self.Manager:CheckOptions()
			elseif rest == "false" then
				self.Manager:SetHiddenOutOfCombat(false)
				Console.Write("Icons will be visible out of combat.")
				self.Manager:CheckOptions()
			else
				if (ShieldMaidConfig.hiddenOutOfCombat) then
					Console.Write("Icons are currently hidden while not in combat. (true)")
				else
					Console.Write("Icons are currently visible while not in combat. (false)")
				end
			end	
		elseif (command == "showframes") or (command == "sf") or (command == "frames") or (command == "sframes") or (command == "showf") then
			if rest == "true" then
				self.Manager:SetShowFrames(true)
				Console.Write("Frames will be visible.")
				self.Manager:CheckOptions()
			elseif rest == "false" then
				self.Manager:SetShowFrames(false)
				Console.Write("Frames will be hidden.")
				self.Manager:CheckOptions()
			else
				if (ShieldMaidConfig.showFrames) then
					Console.Write("Icon frames are currently visible. (true)")
				else
					Console.Write("Icon frames are currently hidden. (false)")
				end
			end
		elseif (command == "showglow") or (command == "glow") or (command == "sg") or (command == "sglow") or (command == "showg") then
			if rest == "true" then
				self.Manager:SetShowGlowBar(true)
				Console.Write("Glow bar will be visible.")
				self.Manager:CheckOptions()
			elseif rest == "false" then
				self.Manager:SetShowGlowBar(false)
				Console.Write("Glow bar will be hidden.")
				self.Manager:CheckOptions()
			else
				if (ShieldMaidConfig.showGlowBar) then
					Console.Write("Shield Barrier glow is currently visible. (true)")
				else
					Console.Write("Shield Barrier glow is currently hidden. (false)")
				end
			end
		elseif (command == "showcooldown") or (command == "cooldown") or (command == "sc") or (command == "showc") or (command == "scooldown") then
			if rest == "true" then
				self.Manager:SetShowCooldown(true)
				Console.Write("The cooldown 'clock' will be visible.")
				self.Manager:CheckOptions()
			elseif rest == "false" then
				self.Manager:SetShowCooldown(false)
				Console.Write("The cooldown 'clock' will be hidden.")
				self.Manager:CheckOptions()
			else
				if (ShieldMaidConfig.showCooldown) then
					Console.Write("Icon cooldowns are currently visible. (true)")
				else
					Console.Write("Icon cooldowns are currently hidden. (false)")
				end
			end
		elseif (command == "truncatednumbers") or (command == "truncate") or (command == "numbers") or (command == "tn") or (command == "truncated") then
			if rest == "true" then
				self.Manager:SetTruncatedNumbers(true)
				Console.Write("Numbers will now be truncated.")
				self.Manager:CheckOptions()
			elseif rest == "false" then
				self.Manager:SetTruncatedNumbers(false)
				Console.Write("Numbers will no longer be truncated.")
				self.Manager:CheckOptions()
			else
				if (ShieldMaidConfig.truncatedNumbers) then
					Console.Write("Numbers are currently truncated. (true)")
				else
					Console.Write("Numbers are not currently truncated. (false)")
				end
			end	
		elseif (command == "tankonly") or (command == "tank") or (command == "protonly") or (command == "protectiononly") then
			if rest =="true" then
				self.Manager:SetTankOnly(true)
				Console.Write("Icons will now display only while set as protection.")
				self.Manager:CheckOptions()		
			elseif rest == "false" then
				self.Manager:SetTankOnly(false)
				Console.Write("Icons will now display for all specializations with Shield Barrier.")
				self.Manager:CheckOptions()
			else
				if (ShieldMaidConfig.tankOnly) then
					Console.Write("Icons will only display while set as protection.")
				else
					Console.Write("Icons will display for all specializations.")
				end
			end
		elseif (command == "charges") or (command == "showcharges") then
			if rest =="true" then
				self.Manager:SetShowCharges(true)
				Console.Write("Text displaying available shield block charges will now be displayed.")
				self.Manager:CheckOptions()		
			elseif rest == "false" then
				self.Manager:SetShowCharges(false)
				Console.Write("Text displaying available shield block charges will now be hidden.")
				self.Manager:CheckOptions()
			else
				if (ShieldMaidConfig.showCharges) then
					Console.Write("Text displaying shield block charges is currently displayed.")
				else
					Console.Write("Text displaying shield block charges is currently hidden.")
				end
			end
		else
			Console.Write("Unknown command: "..command)
		end
	end
	
	return self
end

-- Utility function for writing to the chat window.
function Console.Write(text)
	print("|c00C79C6EShield Maid:|r "..text)
end

-- Register slash command handler.
function Console:RegisterSlashCommands()
	SLASH_SHIELDMAID1, SLASH_SHIELDMAID2 = "/shieldmaid", "/sm"
	SlashCmdList["SHIELDMAID"] = self.SlashCommandHandler
end