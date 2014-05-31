local EPGP = Apollo.GetAddon("EPGP")
local mod = EPGP:NewModule("boss")
--local Debug = LibStub("LibDebug-1.0")
local DLG = { Spawn = function(self,a,b) Print(a) end, ActiveDialog = function() return false end }
local L = EPGP.L

local in_combat = false

function mod:ShowPopup(event_name, boss_name)
	while (GameLib.GetPlayerUnit().IsInCombat() or DLG:ActiveDialog("EPGP_BOSS_DEAD") or
			DLG:ActiveDialog("EPGP_BOSS_ATTEMPT")) do
			Apollo.CreateTimer("EPGP_BOSS_CHECK", .1, false)
	end

	local dialog
	if event_name == "kill" or event_name == "BossKilled" then
		DLG:Spawn("EPGP_BOSS_DEAD", boss_name)
	elseif event_name == "wipe" and mod.db.profile.wipedetection then
		DLG:Spawn("EPGP_BOSS_ATTEMPT", boss_name)
	end
end

local function BossAttempt(event_name, boss_name)
	Debug("Boss attempt: %s %s", event_name, boss_name)
	-- Temporary fix since we cannot unregister DBM callbacks
	if not mod:IsEnabled() then return end

	if CanEditOfficerNote() and EPGP:IsRLorML() then
		Apollo.CreateTimer("EPGP_BOSS_CHECK", .1, false)
	end
end

function mod:DebugTest()
	BossAttempt("BossKilled", "Sapphiron")
	BossAttempt("kill", "Bob")
	BossAttempt("wipe", "Spongebob")
end

mod.dbDefaults = {
	profile = {
		enabled = false,
		wipedetection = false,
	},
}

function mod:OnInitialize()
	--self.db = EPGP.db:RegisterNamespace("boss", mod.dbDefaults)
end

mod.optionsName = L["Boss"]
mod.optionsDesc = L["Automatic boss tracking"]
mod.optionsArgs = {
	help = {
		order = 1,
		type = "description",
		name = L["Automatic boss tracking by means of a popup to mass award EP to the raid and standby when a boss is killed."]
	},
	wipedetection = {
		type = "toggle",
		name = L["Wipe awards"],
		desc = L["Awards for wipes on bosses. Requires DBM, DXE, or BigWigs"],
		order = 2,
		disabled = function(v) return not DBM end,
	},
}

function mod:OnEnable()
	Apollo.RegisterTimerHandler("EPGP_BOSS_CHECK","ShowPopup", self)
end

function mod:OnDisable()
end