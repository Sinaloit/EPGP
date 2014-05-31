local VERSION = 0.8
local tDependencies = {
  "MasterLoot",
  "Gemini:Logging-1.2",
  "Gemini:CallbackHandler-1.0",
  "Gemini:LibDialog-1.0",
}
local EPGP = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon("EPGP", true, tDependencies)
EPGP.nVersion = VERSION

EPGP.L = Apollo.GetPackage("Gemini:Locale-1.0").tPackage:GetLocale("EPGP", false)
EPGP.callbacks = Apollo.GetPackage("Gemini:CallbackHandler-1.0").tPackage:New(EPGP)

function EPGP:WriteToChat(str, bExcludePrefix)
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, string.format("%s%s", bExcludePrefix and "" or "EPGP :: ", str))
end

function EPGP:OnDependencyError(strDep, strError)
	Print("EPGP could not load " .. strDep .. ". Error: " .. strError)
	return false
end

EPGP:SetDefaultModuleState(false)
local modulePrototype = {
  IsDisabled = function (self, i) return not self:IsEnabled() end,
  SetEnabled = function (self, i, v)
                 if v then
                   Debug("Enabling module: %s", self:GetName())
                   self:Enable()
                 else
                   Debug("Disabling module: %s", self:GetName())
                   self:Disable()
                 end
                 self.db.profile.enabled = v
               end,
  GetDBVar = function (self, i) return self.db.profile[i[#i]] end,
  SetDBVar = function (self, i, v) self.db.profile[i[#i]] = v end,
}
EPGP:SetDefaultModulePrototype(modulePrototype)