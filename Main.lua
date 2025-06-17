-- The addon namespace.
local addon, ns = ...

local shieldBarrierIcon = ns.ShieldBarrierIcon:new("ShieldMaidShieldBarrierIcon")
local shieldBlockIcon = ns.ShieldBlockIcon:new("ShieldMaidShieldBlockIcon")
local manager = ns.Manager:new(shieldBarrierIcon, shieldBlockIcon);
local console = ns.Console:new(manager)

console:RegisterSlashCommands()
manager:RegisterHandlers()