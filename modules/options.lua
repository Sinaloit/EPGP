local EPGP = Apollo.GetAddon("EPGP")
local L = EPGP.L
local mod = EPGP:NewModule("options")

--local Debug = LibStub("LibDebug-1.0")
--local DLG = LibStub("LibDialog-1.0")
--local LLN = LibStub("LibLootNotify-1.0")

local function spairs(t, order)
	-- collect the keys
	local keys = {}
	for k in pairs(t) do keys[#keys+1] = k end

	-- if order function given, sort by it by passing the table and keys a, b,
	-- otherwise just sort the keys 
	if order then
		table.sort(keys, function(a,b) return order(t, a, b) end)
	else
		table.sort(keys)
	end

	-- return the iterator function
	local i = 0
	return function()
		i = i + 1
		if keys[i] then
			return keys[i], t[keys[i]]
		end
	end
end

function EPGP:SetupOptions()
--[[
	local options = {
	name = "EPGP",
	type = "group",
	childGroups = "tab",
	handler = self,
	args = {
		help = {
		order = 1,
		type = "description",
		name = L["EPGP is an in game, relational loot distribution system"],
		},
		hint = {
		order = 2,
		type = "description",1
		name = L["Hint: You can open these options by typing /epgp config"],
		},
		list_errors = {
		order = 1000,
		type = "execute",
		name = L["List errors"],
		desc = L["Lists errors during officer note parsing to the default chat frame. Examples are members with an invalid officer note."],
		func = function()
				 outputFunc = function(s) DEFAULT_CHAT_FRAME:AddMessage(s) end
				 EPGP:ReportErrors(outputFunc)
				 end,
		},
		reset = {
		order = 1001,
		type = "execute",
		name = L["Reset EPGP"],
		desc = L["Resets EP and GP of all members of the guild. This will set all main toons' EP and GP to 0. Use with care!"],
		func = function() DLG:Spawn("EPGP_RESET_EPGP") end,
		},
		reset_gp = {
		order = 1002,
		type = "execute",
		name = L["Reset only GP"],
		desc = L["Resets GP (not EP!) of all members of the guild. This will set all main toons' GP to 0. Use with care!"],
		func = function() DLG:Spawn("EPGP_RESET_GP") end,
		},
		rescale = {
		order = 1003,
		type = "execute",
		name = L["Rescale GP"],
		desc = L["Rescale GP of all members of the guild. This will reduce all main toons' GP by a tier worth of value. Use with care!"],
		func = function() DLG:Spawn("EPGP_RESCALE_GP") end,
		},
	},
	}
	local registry = LibStub("AceConfigRegistry-3.0")
	registry:RegisterOptionsTable("EPGP Options", options)

	local dialog = LibStub("AceConfigDialog-3.0")
	dialog:AddToBlizOptions("EPGP Options", "EPGP")
--]]

	-- Setup options for each module that defines them.
	for name, m in self:IterateModules() do
		if m.optionsArgs then
			-- Set all options under this module as disabled when the module
			-- is disabled.
			for n, o in pairs(m.optionsArgs) do
				if o.disabled then
					local old_disabled = o.disabled
					o.disabled = function(i)
									return old_disabled(i) or m:IsDisabled()
							 	 end
				else
					o.disabled = "IsDisabled"
				end
			end
			-- Add the enable/disable option.
			m.optionsArgs.enabled = {
				order = 0,
				type = "toggle",
				width = "full",
				name = ENABLE,
				get = "IsEnabled",
				set = "SetEnabled",
			}
		end
		if m.optionsName then
			--[[
			registry:RegisterOptionsTable("EPGP " .. name, {
										handler = m,
										order = 100,
										type = "group",
										name = m.optionsName,
										desc = m.optionsDesc,
										args = m.optionsArgs,
										get = "GetDBVar",
										set = "SetDBVar",
									})
									]]
			self:AddToConfig("EPGP " .. name, m)
		end
	end
	self.wndEPGPConfigForm:FindChild("OptionsList"):ArrangeChildrenVert(0)
	Apollo.RegisterSlashCommand("epgp", "ProcessCommand", self)
	--EPGP.RegisterCallback(self, "DecayPercentChanged", "OnDecayPercentChanged")
	--EPGP.RegisterCallback(self, "MinEPChanged", "OnMinEPChanged")
end

function EPGP:OnDecayPercentChanged(nNewDecay)
	self.wndEPGPConfigForm:FindChild("DecayValue"):SetText(nNewDecay)
end
function EPGP:OnMinEPChanged(nNewMinEP)
	self.wndEPGPConfigForm:FindChild("MinEPValue"):SetText(nNewMinEP)
end

function EPGP:AddToConfig(strOptName, tOptions)
	if self.wndEPGPConfigForm:FindChild(strOptName) then
		return
	end
	local wndBtn = Apollo.LoadForm(self.xmlDoc, "SectionBtn", self.wndEPGPConfigForm:FindChild("OptionSections"), self)
	self.wndEPGPConfigForm:FindChild("OptionSections"):ArrangeChildrenVert(0)
	wndBtn:SetText(tOptions.optionsName)
	local wndOpts = Apollo.LoadForm(self.xmlDoc, "OptionSection1", self.wndEPGPConfigForm:FindChild("OptionsList"), self)
	wndBtn:SetData(wndOpts)
	wndOpts:SetName(strOptName)
	wndOpts:FindChild("OptionsLabel"):SetText(tOptions.optionsName)
	wndOpts:FindChild("OptionsLabel"):SetTooltip(tOptions.optionsDesc)
	local wndOptContainer = wndOpts:FindChild("Options")
	local nSize = 0
	for name, opt in spairs(tOptions.optionsArgs, function(t,a,b) return t[a].order < t[b].order end) do
		if opt.name then
			local wndOption = nil
			if opt.type == "toggle" then
				wndOption = Apollo.LoadForm(self.xmlDoc, "BooleanOption", wndOptContainer, self)
			elseif opt.type == "input" then
				wndOption = Apollo.LoadForm(self.xmlDoc, "InputOption", wndOptContainer, self)
			elseif opt.type == "select" then
				wndOption = Apollo.LoadForm(self.xmlDoc, "DropdownOption", wndOptContainer, self)
				wndOption:SetData(opt.values)
			elseif opt.type == "multiselect" then
			elseif opt.type == "description" then
				wndOpts:FindChild("OptionsLabel"):SetTooltip(opt.name)
			end
			if wndOption then
				nSize = nSize + wndOption:GetHeight()
				wndOption:FindChild("Label"):SetText(opt.name)
				if opt.desc then
					wndOption:FindChild("Label"):SetTooltip(opt.desc)
				end
			end
		end
	end
	wndOptContainer:ArrangeChildrenVert(0)
	local nLeft, nTop, nRight, nBottom = wndOpts:GetAnchorOffsets()
	wndOpts:SetAnchorOffsets(nLeft, nTop, nRight, nBottom + nSize)
end

function EPGP:ProcessCommand(str)
	str = str:gsub("%%t", GameLib.GetTargetUnit() and GameLib.GetTarget():IsACharacter() and GameLib.GetTargetUnit():GetName() or "notarget")
	local command, nextpos = self:GetArgs(str, 1)
	if command == "config" then
		InterfaceOptionsFrame_OpenToCategory("EPGP")
	elseif command == "debug" then
		Debug:Toggle()
	elseif command == "massep" then
		local reason, amount = self:GetArgs(str, 2, nextpos)
		amount = tonumber(amount)
		if self:CanIncEPBy(reason, amount) then
			self:IncMassEPBy(reason, amount)
		end
	elseif command == "ep" then
		local member, reason, amount = self:GetArgs(str, 3, nextpos)
		amount = tonumber(amount)
		if self:CanIncEPBy(reason, amount) then
			self:IncEPBy(member, reason, amount)
		end
	elseif command == "gp" then
		local member, itemlink, amount = self:GetArgs(str, 3, nextpos)
		self:Print(member, itemlink, amount)
		if amount then
			amount = tonumber(amount)
		else
			local gp1, gp2 = GP:GetValue(itemlink)
			self:Print(gp1, gp2)
			-- Only automatically fill amount if we have a single GP value.
			if gp1 and not gp2 then
				amount = gp1
			end
		end

		if self:CanIncGPBy(itemlink, amount) then
			self:IncGPBy(member, itemlink, amount)
		end
	elseif command == "decay" then
		if EPGP:CanDecayEPGP() then
			DLG:Spawn("EPGP_DECAY_EPGP", EPGP:GetDecayPercent())
		end
	elseif command == "coins" or command == "coin" then
		local num, show_gold = self:GetArgs(str, 2, nextpos)
		if num then
			num = tonumber(num)
		else
			num = 10
		end

		EPGP:PrintCoinLog(num, show_gold)
	elseif command == "fakecoin" then
		local item = self:GetArgs(str, 1, nextpos)
		EPGP:FakeCoinEvent(item)
	elseif command == "help" then
		local help = {
			self.version,
			"   config - "..L["Open the configuration options"],
			"   debug - "..L["Open the debug window"],
			"   massep <reason> <amount> - "..L["Mass EP Award"],
			"   ep <name> <reason> <amount> - "..L["Award EP"],
			"   gp <name> <itemlink> [<amount>] - "..L["Credit GP"],
			"   decay - "..L["Decay of EP/GP by %d%%"]:format(EPGP:GetDecayPercent()),
		}
		EPGP:Print(table.concat(help, "\n"))
	else
		self:ToggleUI()
	end
end

function EPGP:FakeCoinEvent(item)
	LLN.BonusMessageReceiver(nil, string.format("BONUS_LOOT_RESULT^%s^%s^%s", "item", item, 32),
							 nil, UnitName("player"))
end

function EPGP:ToggleUI()
	if self.wndMain and self.tGuild then
		self.wndMain:Show(self.wndMain:IsShown())
	end
end

local wndShown = nil
function EPGP:SetupConfig()
	self.wndEPGPConfigForm = Apollo.LoadForm(self.xmlDoc, "ConfigureForm", nil, self)
	wndShown = self.wndEPGPConfigForm:FindChild("GuildOptions")
	self.wndEPGPConfigForm:FindChild("GuildOptionsBtn"):SetData(wndShown)
	self.wndEPGPConfigForm:FindChild("GuildOptionsBtn"):SetCheck(true)
end

function EPGP:OnSectionCheck( wndHandler, wndControl, eMouseButton )
	if wndControl:GetData() == wndShown then return end
	wndShown:Show(false, false)
	wndShown = wndControl:GetData()
	if wndShown then 
		wndShown:Show(true, false)
	end
end
function EPGP:OnSectionUncheck( wndHandler, wndControl, eMouseButton )
	if wndControl:GetData() == wndShown then
		wndControl:SetCheck(true)
	end
end


function EPGP:OnConfigure()
	-- Read only values
	self.wndEPGPConfigForm:FindChild("MinEPValue"):SetText(self.Config.nMinEP)
	self.wndEPGPConfigForm:FindChild("BaseGPValue"):SetText(self.Config.nBaseGP)
	self.wndEPGPConfigForm:FindChild("DecayValue"):SetText(self.Config.nDecayPerc)
	self.wndEPGPConfigForm:FindChild("ExtrasValue"):SetText(self.Config.nExtrasPerc)
	self.wndEPGPConfigForm:FindChild("OutsidersCheck"):SetCheck(self.Config.bOutsiders == 1)
	self.wndEPGPConfigForm:FindChild("OutsidersCheck"):Enable(false)
	-- Individual Awards
	--[[
	if self.Config.tEPGPCosts == nil then 
		self.Config.tEPGPCosts = {}
		self.Config.tEPGPCosts["OnTime"] = { EP = "5", GP = "0" }
		self.Config.tEPGPCosts["Late"] = { EP = "0", GP = "5" }
		self.Config.tEPGPCosts["Standby"] = { EP = "15", GP = "0" }
	end
	self.wndEPGPConfigForm:FindChild("txtOnTimeEP"):SetText(self.Config.tEPGPCosts["OnTime"].EP)
	self.wndEPGPConfigForm:FindChild("txtOnTimeGP"):SetText(self.Config.tEPGPCosts["OnTime"].GP)
	self.wndEPGPConfigForm:FindChild("txtLateEP"):SetText(self.Config.tEPGPCosts["Late"].EP)
	self.wndEPGPConfigForm:FindChild("txtLateGP"):SetText(self.Config.tEPGPCosts["Late"].GP)
	self.wndEPGPConfigForm:FindChild("txtStandbyEP"):SetText(self.Config.tEPGPCosts["Standby"].EP)
	self.wndEPGPConfigForm:FindChild("txtStandbyGP"):SetText(self.Config.tEPGPCosts["Standby"].GP)
	--]]
	self.wndEPGPConfigForm:Show(true)
	self.wndEPGPConfigForm:ToFront()
end
