local EPGP = Apollo.GetAddon("EPGP")
local L = EPGP.L
local GS = Apollo.GetPackage("LibGuildStorage-1.0").tPackage

local function strsplit(delim, str, maxNb)
    -- Eliminate bad cases...
    if string.find(str, delim) == nil then
        return { str }
    end
    if maxNb == nil or maxNb < 1 then
        maxNb = 0    -- No limit
    end
    local result = {}
    local pat = "(.-)" .. delim .. "()"
    local nb = 0
    local lastPos
    for part, pos in string.gfind(str, pat) do
        nb = nb + 1
        result[nb] = part
        lastPos = pos
        if nb == maxNb then break end
    end
    -- Handle the last field
    if nb ~= maxNb then
        result[nb + 1] = string.sub(str, lastPos)
    end

    return result
end

local tConfigDefs = {
	nDecayPerc = {
		pattern = "@DECAY_P:(%d+)",
		parser = tonumber,
		validator = function(v) return v >= 0 and v <= 100 end,
		error = L["Decay Percent should be a number between 0 and 100"],
		default = 0,
		change_message = "DecayPercentChanged",
	},
	nExtrasPerc = {
		pattern = "@EXTRAS_P:(%d+)",
		parser = tonumber,
		validator = function(v) return v >= 0 and v <= 100 end,
		error = L["Extras Percent should be a number between 0 and 100"],
		default = 100,
		change_message = "ExtrasPercentChanged",
	},
	nMinEP = {
		pattern = "@MIN_EP:(%d+)",
		parser = tonumber,
		validator = function(v) return v >= 0 end,
		error = L["Min EP should be a positive number"],
		default = 0,
		change_message = "MinEPChanged",
	},
	nBaseGP = {
		pattern = "@BASE_GP:(%d+)",
		parser = tonumber,
		validator = function(v) return v >= 0 end,
		error = L["Base GP should be a positive number"],
		default = 1,
		change_message = "BaseGPChanged",
	},
}

local function ParseGuildInfo(strGuildInfo)
	if not strGuildInfo then
		return
	end

	local tLines = strsplit("\n", strGuildInfo)
	local bInBlock = false
	local tNewConfig = {}

	for _,strLine in pairs(tLines) do
		if strLine == "-EPGP-" then
			bInBlock = not bInBlock
		elseif bInBlock then
			for var, tDef in pairs(tConfigDefs) do
				local v = strLine:match(tDef.pattern)
				if v then
					v = tDef.parser(v)
					if v == nil or not tDef.validator(v) then
						EPGP.glog:debug(tDef.error)
					else
						tNewConfig[var] = v
					end
				end
			end
		end
	end

	for var, tDef in pairs(tConfigDefs) do
		local nOldValue = epgp.db.tConfig[var]
		EPGP.db.tConfig[var] = tNewConfig[var] or tDef.default
		if nOldValue ~= EPGP.db.tConfig[var] then
			EPGP.callbacks:Fire(tDef.change_message, EPGP.db.tConfig[var])
		end
	end
end

GS.RegisterCallback(EPGP, "GuildInfoChanged", ParseGuildInfo)
