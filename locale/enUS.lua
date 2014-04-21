--Localization.enUS.lua
local debug = false

local L = Apollo.GetPackage("GeminiLocale-1.0").tPackage:NewLocale("EPGP", "enUS", true, not debug)

if not L then
	return
end

L["EPGP"] = true
L["Decay Percent should be a number between 0 and 100"] = true
L["Extras Percent should be a number between 0 and 100"] = true
L["Min EP should be a positive number"] = true
L["Base GP should be a positive number"] = true
L["Outsiders should be 0 or 1"] = true
