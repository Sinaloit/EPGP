-----------------------------------------------------------------------------------------------
-- Client Lua Script for EPGP
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
--[[
Structure Layout

self.EPGP_StandingsDB
	This is the entire current list of EVERYONE that is in the standings.
	It is ONLY guild members, and cannot be anyone else (for the time being)
	
self.EPGP_GroupDB
	This is the current group including all standby/attended/late people that sign up for a raid
	
self.EPGPTimer
	This is the Timer data for recurring EP Awards during raids.

self.Config
	Contains all configuration settings for onsave/restore
--]]
require "Window"

-- EPGP Module Definition
local EPGP = {}

EPGP.L = Apollo.GetPackage("GeminiLocale-1.0").tPackage:GetLocale("EPGP", false)
local L = EPGP.L

local MenuToolTipFont_Header = "CRB_Pixel_O"
local MenuToolTipFont = "CRB_Pixel" 
local MenuToolTipFont_Help = "CRB_InterfaceSmall_I"
local kStrStandings = "Standings"
local kStrSortDownSprite = "HologramSprites:HoloArrowDownBtnFlyby"
local kStrSortUpSprite = "HologramSprites:HoloArrowUpBtnFlyby"
local ktAwardReasons = {
	["Genetic Archives"] = {
		"Gene: Experiment X-89",
		"Gene: Kuralak the Defiler",
		"Gene: Phage Maw",
		"Gene: Phagetech Prototypes",
		"Gene: Phageborn Convergence",
		"Gene: Dreadphage Ohmna",
	},
	["Datascape"] = {
		"Data: System Daemons",
		"Data: Gloomclaw",
		"Data: Maelstrom Authority",
		"Data: Elementals",
		"Data: Avatus",
	},
	["SotS"] = true,
}

function strsplit(strDelimiter, strText)
	local tList = {}
	local nPos = 1
	if string.find("", strDelimiter, 1) then -- this would result in endless loops
		error("delimiter matches empty string!")
	end
	while 1 do
		local nFirst, nLast = string.find(strText, strDelimiter, nPos)
		if nFirst then -- found?
			table.insert(tList, string.sub(strText, nPos, nFirst-1))
			nPos = nLast+1
		else
			table.insert(tList, string.sub(strText, nPos))
			break
		end
	end
	return tList
end

function EPGP:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function EPGP:Init()
    Apollo.RegisterAddon(self, true, "EPGP", {"MasterLoot"})
end

-- EPGP OnLoad
function EPGP:OnLoad()
	self.EPGP_StandingsDB = {}
	self.Config = {}
	self.FilterList = false

    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("EPGP.xml")

	-- Main EPGP Form
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "EPGPForm", nil, self)
	if self.wndMain == nil then
		Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
		return Apollo.AddonLoadStatus.LoadingError
	end
	
	-- Standings Grid and associated variables
	self.wndGrid = self.wndMain:FindChild("grdStandings")
	-- PR is the initially selected sort method
	self.wndOldSort = self.wndMain:FindChild("PR")
	self.nSortCol = 4
	self.bSortAsc = false

	-- Configuration Form
    self.wndEPGPConfigForm = Apollo.LoadForm(self.xmlDoc, "EPGPConfigForm", nil, self)
	if self.wndEPGPConfigForm == nil then
		Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
		return Apollo.AddonLoadStatus.LoadingError
	end
	
	-- Status Button
    self.wndEPGPMenu = Apollo.LoadForm(self.xmlDoc, "EPGPMenu", nil, self)
	if self.wndEPGPMenu == nil then
		Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
		return Apollo.AddonLoadStatus.LoadingError
	end
	
    -- Register Slash Commands
	Apollo.RegisterSlashCommand("epgp", "OnEPGPOn", self)
	Apollo.RegisterSlashCommand("epgpreset", "OnEPGPReset", self)

	Apollo.RegisterTimerHandler("RecurringEPAwardTimer", "Timer_RecurringEPAward", self) 

	-- Register Events
	Apollo.RegisterEventHandler("GuildRoster", "OnGuildRoster", self)
	Apollo.RegisterEventHandler("ChatMessage", "WhisperCommand", self)
	Apollo.RegisterEventHandler("Group_Join", "OnGroupJoin", self)
	-- Used to obtain a reference to the characters Guild
	Apollo.RegisterEventHandler("UnitCreated", "OnUnitCreated", self)
	-- When the Guild Info is updated we need to import any changes
	Apollo.RegisterEventHandler("GuildInfoMessage", "OnGuildInfoMessage", self)
	-- Notification that a guild was added/removed
	Apollo.RegisterEventHandler("GuildChange", "OnGuildChange", self)
	
	--self:SetSyncChannel()
	self:SetupAwards()
	-- Setup Hooks
	self:RegisterHooks()
end

function EPGP:OnGuildInfoMessage(guildOwner)
	if self.tGuild == guildOwner then
		self:ImportGuildConfig()
	end
end

function EPGP:OnGuildChange()
	for key, tGuildItem in pairs(GuildLib.GetGuilds()) do
		if tGuildItem:GetType() == GuildLib.GuildType_Guild then
			-- We changed guilds...
			if tGuildItem ~= self.tGuild then
				return
			end
		end
	end
	-- No Guild Found
	self.tGuild = nil
end

function EPGP:OnUnitCreated()
	self.tGuild = nil
	for key, tGuildItem in pairs(GuildLib.GetGuilds()) do
		if tGuildItem:GetType() == GuildLib.GuildType_Guild then
			self.tGuild = tGuildItem
		end
	end
	if self.tGuild ~= nil then
		Apollo.RemoveEventHandler("UnitCreated", self)
		self:ImportGuildConfig()
	end
end

function EPGP:ImportGuildConfig()
	local strGuildInfo = self.tGuild:GetInfoMessage()

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
		bOutsiders = {
			pattern = "@OUTSIDERS:(%d+)",
			parser = tonumber,
			validator = function(v) return v == 0 or v == 1  end,
			error = L["Outsiders should be 0 or 1"],
			default = 0,
			change_message = "OutsidersChanged",
		},
	}
	if not strGuildInfo then
		return
	end

	local strLines = strsplit("\n", strGuildInfo)
	local bInBlock = false
	local tNewConfig = {}

	for _,strLine in pairs(strLines) do
		if strLine == "-EPGP-" then
			bInBlock = not bInBlock
		elseif bInBlock then
			for var, tDef in pairs(tConfigDefs) do
				local var = strLine:match(tDef.pattern)
				if v then
					v = tDef.parser(var)
					if v == nil or not tDef.validator(v) then
						-- Log an Error
					else
						tNewConfig[var] = v
					end
				end
			end
		end
	end

	for var, tDef in pairs(tConfigDefs) do
		local nOldValue = self.Config[var]
		self.Config[var] = tNewConfig[var] or tDef.default
		if nOldValue ~= self.Config[var] then
			-- Ace Stuff, callbacks not implemented currently
			--EPGP.callbacks:Fire(tDef.change_message, EPGP.db.profile[var])
		end
	end
end

function EPGP:SetupAwards()
	local wndContainer = self.wndMain:FindChild("AwardListBtns")
	local nCount = 1
	for strLocation, value in pairs(ktAwardReasons) do
		if type(strLocation) == "string" then
			local wndAwardBtn = Apollo.LoadForm(self.xmlDoc,"AwardReasonButton", wndContainer, self)
			wndAwardBtn:FindChild("AwardBtnText"):SetText(strLocation)
			if type(value) == "table" then
				wndAwardBtn:FindChild("BtnArrow"):Show(true)
				wndAwardBtn:SetData(value)
			end
			nCount = nCount + 1
		end
	end
	local wndAwardBtn = Apollo.LoadForm(self.xmlDoc,"AwardReasonButton", wndContainer, self)
	wndAwardBtn:FindChild("AwardBtnText"):SetText("Other")
	wndContainer:ArrangeChildrenVert(0)
	local nLeft, nTop, nRight, nBottom = wndContainer:GetParent():GetAnchorOffsets()
	wndContainer:GetParent():SetAnchorOffsets(nLeft, nTop, nRight, nBottom + (nCount * 25) + 36)
	self:ToggleOtherReason(true)
end

local function SortByValue(a, b)
	local aPR = a:FindChild("Value"):GetText()
	local bPR = b:FindChild("Value"):GetText()

	return aPR > bPR
end

function EPGP:RegisterHooks()
	local tEPGP = self
	local tMasterLoot = Apollo.GetAddon("MasterLoot")
	-- Master Loot Assignment
	local fnOldOnAssignDown = tMasterLoot.OnAssignDown
	tMasterLoot.OnAssignDown = function(tMLoot, wndHandler, wndControl, eMouseButton)
		if tMLoot.tMasterLootSelectedItem ~= nil and tMLoot.tMasterLootSelectedLooter ~= nil then
			tEPGP:AwardItem(tMLoot.tMasterLootSelectedLooter, tMLoot.tMasterLootSelectedItem:GetData().itemDrop)
		end
		fnOldOnAssignDown(tMLoot, wndHandler, wndControl, eMouseButton)
	end
	-- Hook to add a PR display to all items in MasterLoot display
	local fnOldOnItemCheck = tMasterLoot.OnItemCheck
	tMasterLoot.OnItemCheck = function(tMLoot, wndHandler, wndControl, eMouseButton)
		fnOldOnItemCheck(tMLoot, wndHandler, wndControl, eMouseButton)
		if tMLoot.wndMasterLoot ~= nil then
			for idx, wndLooter in pairs(tMLoot.wndMasterLoot:FindChild("LooterList"):GetChildren()) do
				local wndOverlay = Apollo.LoadForm(tEPGP.xmlDoc, "EPGPOverlay", wndLooter, tEPGP)
				wndOverlay:FindChild("Label"):SetText("PR")
				wndOverlay:FindChild("Value"):SetText(string.format("%.2f",tEPGP:GetPR(wndLooter:FindChild("CharacterName"):GetText())))
			end
			tMLoot.wndMasterLoot:FindChild("LooterList"):ArrangeChildrenVert(0, SortByValue)
		end
	end
	-- Display GP Cost for Master Looter
	local fnOldMasterLootHelper = tMasterLoot.MasterLootHelper
	tMasterLoot.MasterLootHelper = function(tMLoot, tMasterLootItemList)
		fnOldMasterLootHelper(tMLoot, tMasterLootItemList)
		if tMLoot.wndMasterLoot ~= nil then
			for idx, wndLoot in pairs(tMLoot.wndMasterLoot:FindChild("ItemList"):GetChildren()) do
				local wndOverlay = Apollo.LoadForm(tEPGP.xmlDoc, "EPGPOverlay", wndLoot, tEPGP)
				wndOverlay:FindChild("Value"):SetText(tEPGP:CalculateItemGPValue(wndLoot:GetData().itemDrop))
			end
		end
	end
	-- Display GP Cost for Looter
	local fnOldLooterHelper = tMasterLoot.LooterHelper
	tMasterLoot.LooterHelper = function(tMLoot, tLooterItemList)
		fnOldLooterHelper(tMLoot, tLooterItemList)
		if tMLoot.wndLooter ~= nil then
			for idx, wndLoot in pairs(tMLoot.wndLooter:FindChild("ItemList"):GetChildren()) do
				local wndOverlay = Apollo.LoadForm(tEPGP.xmlDoc, "EPGPOverlay", wndLoot, tEPGP)
				wndOverlay:FindChild("Value"):SetText(tEPGP:CalculateItemGPValue(wndLoot:GetData().itemDrop))
			end
		end
	end
end

function EPGP:SetSyncChannel() -- Not Used, however, I am keeping this in here for future use
	--local strChannel = self:getLeader() or "EPGPGeneralChannel"
	--self.EPGPChannel = ICCommLib.JoinChannel( strChannel, "OnEPGPMessage", self) -- setting to the leader of the group for sync msgs
end

function EPGP:getLeader()
	for i=1, GroupLib.GetMemberCount() do 
		local tGroupMember = GroupLib.GetGroupMember(i)
		if tGroupMember.bIsLeader then
			Print(tGroupMember.strName)
			return tGroupMember.strName
		end 
	end 
end 

-- EPGP Functions
function EPGP:Timer_RecurringEPAward()
	self:GroupAwardEP(self.nRecurringAward, self.strRecurringReason)
end 

function EPGP:GroupAwardEP( amt, reason )
	local tGroup = {}
	for idx = 1, GroupLib.GetMemberCount() do
		table.insert(tGroup,GroupLib.GetGroupMember(idx).strCharacterName)
	end 
	for k,v in pairs(tGroup) do
		self.EPGP_StandingsDB[v] = self.EPGP_StandingsDB[v] or {}
		self.EPGP_StandingsDB[v][kStrStandings] = self.EPGP_StandingsDB[v][kStrStandings] or { EP = self.Config.nMinEP, GP = self.Config.nBaseGP }
		self.EPGP_StandingsDB[v][kStrStandings].EP = tonumber(self.EPGP_StandingsDB[v][kStrStandings].EP) + tonumber(amt)
	end 

	ChatSystemLib.Command("/p [Mass Award] ( "..amt.."EP ) [ "..reason.."]")
	self:GenerateStandingsGrid()
end 

function EPGP:IsInGroup( strPlayer )
	for idx = 1, GroupLib.GetMemberCount() do
		local tMemberInfo = GroupLib.GetGroupMember(idx)
		if tMemberInfo ~= nil then
			if string.lower(tMemberInfo.strCharacterName) == string.lower(strPlayer) then 
				return true 
			end
		end
	end
	return false
end

function EPGP:EPGP_AwardEP( strCharName, amtEP, amtGP )
	local EP = self.EPGP_StandingsDB[strCharName][kStrStandings].EP or self.Config.nMinEP
	local GP = self.EPGP_StandingsDB[strCharName][kStrStandings].GP or self.Config.nBaseGP
	self.EPGP_StandingsDB[strCharName][kStrStandings].EP = EP + amtEP
	self.EPGP_StandingsDB[strCharName][kStrStandings].GP = GP + amtGP
	self:GenerateStandingsGrid()
end 

function EPGP:AwardItem(tCharacter, tItem)
	local nGPCost = self:CalculateItemGPValue(tItem)
	ChatSystemLib.Command("/p ["..tCharacter:GetName().."] Received "..tItem:GetName().." "..nGPCost.."GP")
	self:EPGP_AwardEP(tCharacter:GetName(), 0, nGPCost)
end

function EPGP:OnEPGPReset()
	self.EPGP_StandingsDB = {}
	self:GroupAwardEP( 0, "Initialization..." )
end 

function EPGP:exportEPGP( iFormat )
	-- Spit out Data:
	--  Name_EP-GP
	-- Format:
	--  1 = Text
	--  2 = xml
	local iNum = 1
	local nEntries = 0
	local db = self.EPGP_StandingsDB
	for a,c in pairs(db) do
		nEntries = nEntries + 1
	end 
	local retVal = ""
	if iFormat == nil or iFormat == 1 then 
		for k,v in pairs(db) do
			retVal = retVal .. k .. "_" .. self.EPGP_StandingsDB[k][kStrStandings].EP .. "-" .. self.EPGP_StandingsDB[k][kStrStandings].GP
			if iNum < nEntries then retVal = retVal .. "," end -- not at the max, add a comma
			iNum = iNum + 1
		end 
	elseif iFormat == 2 then
		-- XML
		-- Format:
		--  <EPGP>
		--	<Entry>
		--    <Name></Name>
		--	  <EP>0</EP>
		--	  <GP>0</GP>
		--  </Entry>
		--	<Entry>
		--    <Name></Name>
		--	  <EP>0</EP>
		--	  <GP>0</GP>
		--  </Entry>
		--  </EPGP>
		retVal = "<EPGP>"
		for k, v in pairs(db) do
			retVal = retVal .. "<Entry>" .. "<Name>" .. v .. "</Name><EP>" .. self.EPGP_StandingsDB[v][kStrStandings].EP .. "</EP><GP>" .. self.EPGP_StandingsDB[v][kStrStandings].GP .. "</GP></Entry>"
		end
		retVal = retVal .. "</EPGP>"
		
	end 
	return retVal
end

local function explode(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	local i = 1
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		t[i] = str
		i = i + 1
	end
	return t
end

function EPGP:importEPGP( tImportData )
	if tImportData == nil or tImportData == "" then return end
	-- reset db
	self.EPGP_StandingsDB = {}
	-- Example string: "Name_EP-GP,Name_EP-GP,Name_EP-GP,Name_EP-GP,Name_EP-GP"
	-- Ryles_503.2-700,Fuzzrig_503.2-700
	local tEntries = explode( tImportData, "," )
	local strName = ""
	local strEP = ""
	local strGP = ""
	for k, v in pairs( tEntries ) do
		local tFirstSplit = explode( v, "_" )
		strName = tFirstSplit[1]
		local tSecondSplit = explode( tFirstSplit[2], "-" )
		strEP = tSecondSplit[1]
		strGP = tSecondSplit[2]
		-- now we have all we need, lets insert it into the db
		self.EPGP_StandingsDB[strName] = {}
		self.EPGP_StandingsDB[strName][kStrStandings] = { EP = strEP, GP = strGP }
	end
	self:GenerateStandingsGrid()
	Print("[EPGP] DB Imported")
end

-- on SlashCommand "/epgp"
function EPGP:OnEPGPOn()
	self.wndMain:Show(true) -- show the window
end

-- EPGPForm Functions
function EPGP:OnCancel()
	self.wndMain:Show(false) -- hide the window
end

function EPGP:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then 
		return 
	end
	
	return { db = self.EPGP_StandingsDB, config = self.Config }
end

function EPGP:OnRestore(eLevel, tSavedData)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	
	self.EPGP_StandingsDB = tSavedData.db or {}
	self.Config = tSavedData.config or {}
end

function EPGP:OnSingleItemAward( wndHandler, wndControl, eMouseButton )
	local btnName = wndControl:GetName()
	if self.wndMain:FindChild("grdStandings"):GetCurrentRow() then 
		local iRow = self.wndMain:FindChild("grdStandings"):GetCurrentRow()
		local strName = self.wndMain:FindChild("grdStandings"):GetCellLuaData(self.wndMain:FindChild("grdStandings"):GetCurrentRow(),1)
		if btnName == "txtLate" then 
			ChatSystemLib.Command("/p ["..strName.."] Late Arrival +5GP")
			self:EPGP_AwardEP(strName,0,5)
		elseif btnName == "txtOnTime" then
			ChatSystemLib.Command("/p ["..strName.."] On-Time Arrival +10EP")
			self:EPGP_AwardEP(strName,10,0)
		elseif btnName == "txtStandby" then
			ChatSystemLib.Command("/p ["..strName.."] Standby Points +15EP")
			self:EPGP_AwardEP(strName,15,5)
		elseif btnName == "btnRecvLoot" then 
			ChatSystemLib.Command("/p ["..strName.."] Received Loot Item +10GP")
			self:EPGP_AwardEP(strName,0,10)
		end 
	end 
end

function EPGP:OnConfigure()
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

-- EPGPMenu Functions
function EPGP:OnMouseOverMenu( wndHandler, wndControl, eToolTipType, x, y )
	-- Set Tooltip for Main Menu Hover
	local strToolTip = string.format("<P Font=\""..MenuToolTipFont_Header.."\" TextColor=\"%s\">%s</P>", "white","EPGP")
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont.."\" TextColor=\"%s\">%s</P>", "yellow", "MinEP="..self.Config.nMinEP)
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont.."\" TextColor=\"%s\">%s</P>", "yellow", "BaseGP="..self.Config.nBaseGP)
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont.."\" TextColor=\"%s\">%s</P>", "yellow", "Decay="..string.format("%.0f %%", self.Config.nDecayPerc))
	strToolTip = strToolTip .. "\r\n\r\n"
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont_Help.."\" TextColor=\"%s\">%s</P>", "green", "(Right-Click To Open Standings)")
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont_Help.."\" TextColor=\"%s\">%s</P>", "green", "(ToeNail-Click To Open Config)")
	wndHandler:SetTooltip(strToolTip)
end

function EPGP:OnEPGPMenuMouseClick( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation )
	if eMouseButton == GameLib.CodeEnumInputMouse.Right then
		self.bGenerateStandingsGrid = true
		self:RefreshGuildRoster()
	end
end

function EPGP:OnGuildRoster(guildCurr, tRoster) -- Event from CPP
	self.tGuildRoster = {}
	for key, tCurr in pairs(tRoster) do
		table.insert(self.tGuildRoster,tCurr.strName)
	end
	
	if self.bGenerateStandingsGrid then
		self.bGenerateStandingsGrid = nil
		self:GenerateStandingsGrid()
		self.wndMain:Show( not self.wndMain:IsVisible() )
	end
end

function EPGP:RefreshGuildRoster()
	if self.tGuild == nil then
		for i, guildCurr in ipairs(GuildLib.GetGuilds()) do
			if guildCurr:GetType() == GuildLib.GuildType_Guild then
				self.tGuild = guildCurr
				break
			end
		end
	end
	if self.tGuild == nil then return end -- nothing we can do.  the player isn't in a guild shouldn't even get this far.
	self.tGuild:RequestMembers()
end 

function EPGP:GenerateStandingsGrid()
	local grdList = self.wndGrid
	local nGuildCount = 0 -- count of guild members
	
	-- Group Check [ Disabling Group and Guild Checks For Now :: April 5th, 2014 ]
	-- if GroupLib.GetMemberCount() == 0 then Print("[EPGP] Error: You Are Not In A Group.") return end 
	-- If you aren't in a guild, you shouldn't even be using this. derp.
	-- if GameLib.GetPlayerUnit():GetGuildName() == nil then Print("[EPGP] Error: You Are Not In A Guild.") return end 

	self.EPGP_StandingsDB = self.EPGP_StandingsDB or {}
	self:RefreshGuildRoster()
	if self.EPGP_StandingsDB == nil then -- Lets add the current group first.
		for i=1,GroupLib.GetMemberCount() do
			v = GroupLib.GetUnitForGroupMember(i):GetName()
			self.EPGP_StandingsDB[v] = self.EPGP_StandingsDB[v] or {}
			self.EPGP_StandingsDB[v][kStrStandings] = self.EPGP_StandingsDB[v][kStrStandings] or { EP = self.Config.nMinEP, GP = self.Config.nBaseGP }
		end
	end 

	local size = GroupLib.GetMemberCount()
	local listDB = {}
	grdList:DeleteAll()
	if self.FilterList == true and size > 0 then 
		-- Get Group List
		for i=1,size do 
			local strCName = GroupLib.GetGroupMember(i).strCharacterName
			if strCName ~= nil then
				if self.EPGP_StandingsDB[strCName] == nil then
					self.EPGP_StandingsDB[strCName] = {}
					self.EPGP_StandingsDB[strCName]["Standings"] = {}	
				end
				listDB[strCName] = self.EPGP_StandingsDB[strCName]
			end
		end 
	else
		listDB = self.EPGP_StandingsDB
	end
	for k, v in pairs( listDB ) do 
		local iCurrRow = grdList:AddRow("")
		grdList:SetCellLuaData(iCurrRow, 1, k)
		local EP = v[kStrStandings].EP
		local GP = v[kStrStandings].GP
		local PR = string.format("%.2f", EP / GP)

		grdList:SetCellText(iCurrRow, 1, k)
		grdList:SetCellSortText(iCurrRow, 1, string.lower(k))
		
		grdList:SetCellText(iCurrRow, 2, EP)
		grdList:SetCellSortText(iCurrRow, 2,string.format("%.3f", EP))

		
		grdList:SetCellText(iCurrRow, 3, GP)
		grdList:SetCellSortText(iCurrRow, 3, string.format("%.3f", GP))
		
		grdList:SetCellText(iCurrRow, 4, PR)
		grdList:SetCellSortText(iCurrRow, 4, tonumber(string.format("%.3f",PR)))
		
	end
	grdList:SetSortColumn(self.nSortCol or 4, self.bSortAsc)
end

function EPGP:GetPR(strName)
	local PR = self:GetEP(strName) / self:GetGP(strName)
	return PR
end

function EPGP:GetEP(strName)
	local EP = self.EPGP_StandingsDB[strName][kStrStandings].EP or self.Config.nMinEP
	return EP
end

function EPGP:GetGP(strName)
	local GP = self.EPGP_StandingsDB[strName][kStrStandings].GP or self.Config.nBaseGP
	return GP
end 

function EPGP:OnGroupJoin( strName, nId)
	
end 

function EPGP:OnConfigMsg( channel, tMsg )
	ChatSystemLib.Command("/p [EPGP] Message Received on Config Channel")
end	

function EPGP:WhisperCommand(channelCurrent, tMessage)
	if GameLib.GetPlayerUnit() == nil then return end
	if tMessage.bSelf or not self:IsInGroup( tMessage.strSender ) then return end -- You are running it, look at the list silly head.
	--if strSender == nil or strSender == GameLib.GetPlayerUnit():GetName() then return end
	if tMessage.strSender == nil then return end
	local eChannel = channelCurrent:GetType()
	if not (eChannel == ChatSystemLib.ChatChannel_Whisper or eChannel == ChatSystemLib.ChatChannel_AccountWhisper) then return end
	if #tMessage.arMessageSegments == 0 or #tMessage.arMessageSegments > 1 then return end
	local strMessage = tMessage.arMessageSegments[1].strText:lower()
	if string.find( strMessage,"\!standing" ) then 
		local strName = tMessage.strSender
		Print("Looking for " .. strName)
		self.EPGP_StandingsDB[strName][kStrStandings] = self.EPGP_StandingsDB[strName][kStrStandings] or {}
		local stnd = self.EPGP_StandingsDB[strName][kStrStandings]
		if stnd.EP == nil then 
		stnd.EP = self.Config.nMinEP
		end 
		if stnd.GP == nil then
		stnd.GP = self.Config.nBaseGP
		end 
		if not stnd or stnd == nil then Print("[EPGP] stnd is nil or not there") end
		stnd.Sent = stnd.Sent or nil
		if (stnd.Sent == false or stnd.Sent == nil) then 
			local tmpID = GameLib.GetServerTime()
			stnd.TimeStamp = (tmpID.nMinute * 60) + tmpID.nSecond + 5
			stnd.Sent = true 
			local PR = string.format("%.2f",stnd.EP / stnd.GP)
			ChatSystemLib.Command("/w " .. strName .. " ( [ep] " .. stnd.EP .. " [gp] " .. stnd.GP .. " [pr] " .. PR .. " )")
			self:GenerateStandingsGrid()
		end 
		local newTime = GameLib.GetServerTime()
		if stnd.TimeStamp < ((newTime.nMinute * 60) + newTime.nSecond) then
			stnd.Sent = false
		end
	end
end

function EPGP:ReportStanding(channelCurrent, 
						bAutoResponse, 
						bGM, 
						bSelf, 
						strSender, 
						strRealmName, 
						nPresenceState, 
						arMessageSegments, 
						unitSource, 
						bShowChatBubble, 
						bCrossFaction
						)
	local strName = strSender
	Print("[EPGP] Msg for " .. strName)
	local stnd = self.EPGP_StandingsDB[strName][kStrStandings]
	if not stnd or stnd == nil then Print("[EPGP] stnd is nil or not there") end
	if (stnd.Sent == false or stnd.Sent == nil) and string.find( arMessageSegments[1].strText:lower(),"\!standing" ) then 
		local tmpID = GameLib.GetServerTime()
		stnd.TimeStamp = (tmpID.nMinute * 60) + tmpID.nSecond + 5
		stnd.Sent = true 
		local PR = string.format("%.2f",stnd.EP / stnd.GP)
		ChatSystemLib.Command("/w " .. idx .. " ( [ep] " .. stnd.EP .. " [gp] " .. stnd.GP .. " [pr] " .. PR .. " )")
		self:GenerateStandingsGrid()
	end 
	local newTime = GameLib.GetServerTime()
	if stnd.TimeStamp < ((newTime.nMinute * 60) + newTime.nSecond) then
		stnd.Sent = false
	end
end 


---------------------------------------------------------------------------------------------------
-- MassAwardEPForm Functions
---------------------------------------------------------------------------------------------------

function EPGP:DecayEPGP()
	for k, val in pairs(self.EPGP_StandingsDB) do
		if not self.EPGP_StandingsDB[k][kStrStandings] then
			self.EPGP_StandingsDB[k][kStrStandings] = { EP = self.Config.nMinEP, GP = self.Config.nBaseGP }
		end
		self.EPGP_StandingsDB[k][kStrStandings].EP = self.EPGP_StandingsDB[k][kStrStandings].EP * (1 - (self.Config.nDecayPerc / 100.0) 
		self.EPGP_StandingsDB[k][kStrStandings].GP = self.EPGP_StandingsDB[k][kStrStandings].GP * (1 - (self.Config.nDecayPerc / 100.0)
	end 
	self:GenerateStandingsGrid()
end 

---------------------------------------------------------------------------------------------------
-- EPGPConfigForm Functions
---------------------------------------------------------------------------------------------------

function EPGP:OnSaveConfig( wndHandler, wndControl, eMouseButton )
	--[[
	self.Config.tEPGPCosts = {}
	self.Config.tEPGPCosts["Late"] = { EP = self.wndEPGPConfigForm:FindChild("txtLateEP"):GetText(),  GP = self.wndEPGPConfigForm:FindChild("txtLateGP"):GetText(), strMsg = "/p [%s] Late Arrival%s%s" }
	self.Config.tEPGPCosts["OnTime"] = { EP = self.wndEPGPConfigForm:FindChild("txtOnTimeEP"):GetText(),  GP = self.wndEPGPConfigForm:FindChild("txtOnTimeGP"):GetText(), strMsg = "/p [%s] On-Time Arrival%s%s" }
	self.Config.tEPGPCosts["Standby"] = { EP = self.wndEPGPConfigForm:FindChild("txtStandbyEP"):GetText(),  GP = self.wndEPGPConfigForm:FindChild("txtStandbyGP"):GetText(), strMsg = "/p [%s] Standby Points%s%s" }
	--]]
	--[[
	self.Config.tEPGPCosts = {
		["Late"]    = { EP = self.wndEPGPConfigForm:FindChild("txtLateEP"):GetText(),  GP = self.wndEPGPConfigForm:FindChild("txtLateGP"):GetText() or 5, strMsg = "/p [%s] Late Arrival%s%s" },
		["OnTime"]  = { EP = self.wndEPGPConfigForm:FindChild("txtLateEP"):GetText(),  GP = self.wndEPGPConfigForm:FindChild("txtLateGP"):GetText() or 0, strMsg = "/p [%s] On-Time Arrival%s%s" },
		["Standby"] = { EP = self.wndEPGPConfigForm:FindChild("txtLateEP"):GetText(),  GP = self.wndEPGPConfigForm:FindChild("txtLateGP"):GetText() or 0, strMsg = "/p [%s] Standby Points%s%s" },
	}
	--]]
	self.wndEPGPConfigForm:Show(false)
	local strToolTip = string.format("<P Font=\""..MenuToolTipFont_Header.."\" TextColor=\"%s\">%s</P>", "white","EPGP")
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont.."\" TextColor=\"%s\">%s</P>", "yellow", "MinEP="..self.Config.nMinEP)
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont.."\" TextColor=\"%s\">%s</P>", "yellow", "BaseGP="..self.Config.nBaseGP)
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont.."\" TextColor=\"%s\">%s</P>", "yellow", "Decay="..string.format("%.0f %%", self.Config.nDecayPerc))
	strToolTip = strToolTip .. "\r\n\r\n"
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont_Help.."\" TextColor=\"%s\">%s</P>", "green", "(Right-Click To Open Standings)")
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont_Help.."\" TextColor=\"%s\">%s</P>", "green", "(ToeNail-Click To Open Config)")

	self.wndEPGPMenu:SetTooltip(strToolTip)
end

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

-- Clicking a specific element on the Grid
function EPGP:OnEPGPGridItemClick(wndControl, wndHandler, iRow, iCol, eClick)
    -- Not a right click, nothing interesting to do
    if eClick ~= GameLib.CodeEnumInputMouse.Right then return end

    -- If we already have a context menu, destroy it
    if self.wndContext ~= nil and self.wndContext:IsValid() then
        self.wndContext:Destroy()
    end

    -- Create a context menu and bring it to front
    self.wndContext = Apollo.LoadForm(self.xmlDoc, "EPGPContextMenu", self.wndMain, self)
    self.wndContext:ToFront()

    -- Move context menu to the mouse
    local tCursor= self.wndMain:GetMouse()
    self.wndContext:Move(tCursor.x + 4, tCursor.y + 4, self.wndContext:GetWidth(), self.wndContext:GetHeight())

    -- Save the name so we can use it for whatever action we choose (Could save iRow and look up whatever instead)
    self.wndContext:SetData(wndHandler:GetCellText(iRow, 1))
end

-- EPGPContextMenu Functions
function EPGP:OnContextBtnClick( wndHandler, wndControl, eMouseButton )
	local btnName, strName = wndControl:GetName(), self.wndContext:GetData()
	-- Lookup the Award Info based on the Name of the Button before the Btn part
	local tAwardInfo = self.Config.tEPGPCosts[string.match(btnName, "(.-)Btn")]

	-- Send out a message based on how much ep/gp we are awarding.
	ChatSystemLib.Command(
		string.format(tAwardInfo.strMsg, strName,
			tonumber(tAwardInfo.EP) ~= 0 and string.format(" +%dEP", tAwardInfo.EP) or "",
			tonumber(tAwardInfo.GP) ~= 0 and string.format(" +%dGP", tAwardInfo.GP) or "")
	)
	self:EPGP_AwardEP(strName,tAwardInfo.EP,tAwardInfo.GP)

	self.wndContext:Destroy()
end

--[[
	This is seperate as there will be alot more logic behind award, probably involving
	showing another form to select/enter the loot awarded as not all loot has the same
	cost typically.
--]]
function EPGP:OnAwardBtnClick( wndHandler, wndControl, eMouseButton )
	local strName = self.wndContext:GetData()
	if self.ItemGPCost == nil then self.wndContext:Destroy() return end -- no item was found, cannot award a loot deduction without it.
	ChatSystemLib.Command("/p ["..strName.."] Received Loot Item +"..self.ItemGPCost.."GP")
	self:EPGP_AwardEP(strName,0,self.ItemGPCost)
	self.ItemGPCost = nil
	self.wndContext:Destroy()
end

function EPGP:CalculateItemGPValue( tItemInfo )
	--[[ Threeks Formula:
		B = Base Item Level
		Q = Quality lvl (Green being 1, blue 2, purple 3, orange 4, pink 5) Right now it's grey = 1
		T = Elder Tier Level
		M = Slot Modifier
	--]]
	--[[
		local eItem = Item.GetDataFromId(itemCode)
		local powerLevel = eItem:GetPowerLevel()
		local effectiveLevel = eItem:GetEffectiveLevel()
		local itemQuality = eItem:GetItemQuality()
		local slotName = eItem:GetSlotName()
	--]]

	local tItem = tItemInfo.itemDrop or tItemInfo
	local nBaseLevel = tItem:GetPowerLevel()
	-- Factor in GetItemPower()?
	local nQualityLevel = tItem:GetItemQuality()
	local tSlotModifiers = {
		[0]  = 1, -- Chest
		[1]  = 1, -- Legs
		[2]  = 1, -- Head
		[3]  = 0.75, -- Shoulder
		[4]  = 0.75, -- Feet
		[5]  = 0.75, -- Hands
		[6]  = 0.5, -- Tool
		[7]  = 0.5, -- Weapon Attachment
		[8]  = 0.5, -- Support System
		[9]  = 1, -- Not sure, Key I guess?
		[10] = 0.5, -- Augments & Implants
		[11] = 1.25, -- Gadget
		[12] = 0.75, -- Unknown
		[13] = 0.75, -- Unknown
		[14] = 0.75, -- Unknown
		[15] = 1.5, -- Shields
		[16] = 1.5, -- Primary Weapon
		[17] = 0.9, -- Container
	}

	local nModifier = .1
	if tItem.GetSlot() ~= nil then 
		nModifier = tSlotModifiers[tItem.GetSlot()]
	end

	nModifier = nModifier or .1

	local nItemGPCost = ((nBaseLevel + ((nQualityLevel - 1) * 2))  * 100) * nModifier
	self.ItemGPCost = nItemGPCost
	return nItemGPCost
end 

function EPGP:OnSortOrderChange(wndHandler, wndControl, eMouseButton)
	-- Name to Index table
	local ktSortIDX = {  ["Character"] = 1, ["EP"] = 2, ["GP"] = 3, ["PR"] = 4 }
	-- Default sort is Ascending
	local bAsc = true

	-- If we are already sorting on this column, we are changing sort order
	if self.wndOldSort == wndControl then
		bAsc = not self.wndGrid:IsSortAscending()
	else
		-- Clear old sort sprite
		if self.wndOldSort then
			self.wndOldSort:FindChild("SortOrderIcon"):SetSprite("")
		end
		-- Set reference to current sort button
		self.wndOldSort = wndControl
	end
	-- Set sort column to this button with the order as determined
	self.nSortCol, self.bSortAsc = ktSortIDX[wndControl:GetName()], bAsc
	self.wndGrid:SetSortColumn(self.nSortCol, bAsc)
	-- Set appropriate sort sprite
	wndControl:FindChild("SortOrderIcon"):SetSprite(bAsc and kStrSortUpSprite or kStrSortDownSprite)
end

function EPGP:ResizeGrid(wndGrid)
    -- Get current width of the Grid
    local nGridWidth = wndGrid:GetWidth()
    -- Number of columns in grid
    local nGCols = 4

    -- Each column should have equal size
    local nSize = math.floor(nGridWidth / nGCols)
    -- But it may not divide by the number of columns equally, in which case we have a remainder
    local nRemainder = nGridWidth - (nSize * nGCols)
    -- Set the column size for all but the last one to our computed equal size
    for iCol=1,(nGCols - 1) do
	    wndGrid:SetColumnWidth(iCol, nSize)
    end
    -- Last column gets the same size plus any leftover
    wndGrid:SetColumnWidth(nGCols, nSize + nRemainder)
end

function EPGP:OnCancelConfig( wndHandler, wndControl, eMouseButton )
	self.wndEPGPConfigForm:Show(false)
end

function EPGP:OnResetConfigDefaults( wndHandler, wndControl, eMouseButton )
end

---------------------------------------------------------------------------------------------------
-- EPGPForm Functions
---------------------------------------------------------------------------------------------------

function EPGP:OnImportExportButton( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation )
	if self.wndImportExport ~= nil then 
		self.wndImportExport:Destroy()
	end 
	
	self.wndImportExport = Apollo.LoadForm(self.xmlDoc, "PortForm", self.wndMain, self) 
	self.wndImportExport:Show(true, true)
	self.wndImportExport:ToFront()	
end

function EPGP:OnFilterListCheck( wndHandler, wndControl, eMouseButton )
	self.FilterList = true
	self:GenerateStandingsGrid()
end

function EPGP:OnFilterListUnCheck( wndHandler, wndControl, eMouseButton )
	self.FilterList = false
	self:GenerateStandingsGrid()
end

function EPGP:OnEPGPSizeChanged( wndHandler, wndControl )
	if wndHandler ~= wndControl then
        return
    end
    -- Resize the Standings Grid
    self:ResizeGrid(self.wndGrid)
end

function EPGP:OnAwardReasonBtn( wndHandler, wndControl, eMouseButton )
	local strNewReason = wndControl:FindChild("AwardBtnText"):GetText()
	local wndAwardReasonToggle = self.wndMain:FindChild("AwardReasonToggle")
	wndAwardReasonToggle:SetText(strNewReason)
	wndAwardReasonToggle:SetCheck(false)
	self:OnAwardReasonToggle(wndHandler, wndAwardReasonToggle, eMouseButton)
	if self.wndSubMenu then
		self.wndSubMenu:Destroy()
	end
	self:ToggleOtherReason(strNewReason == "Other")
end

function EPGP:ToggleOtherReason(bShowOther)
	local wndOC = self.wndMain:FindChild("OtherContainer")
	if bShowOther then
		wndOC:SetTextColor("UI_TextHoloBody")
	else
		wndOC:SetTextColor("UI_BtnTextHoloDisabled")
		wndOC:FindChild("OtherInput"):SetText("")
	end
	wndOC:FindChild("OtherInput"):Enable(bShowOther)
end

function EPGP:OnAwardReasonToggle( wndHandler, wndControl, eMouseButton )
	local bShowWnd = wndControl:IsChecked()
	wndControl:FindChild("BtnArrow"):SetCheck(bShowWnd)
	self.wndMain:FindChild("AwardListContainer"):Show(bShowWnd)
	if self.wndSubMenu then
		self.wndSubMenu:Destroy()
	end
end

function EPGP:OnAwardEP( wndHandler, wndControl, eMouseButton )
	local nAward = self.wndMain:FindChild("ValueInput"):GetText()
	local strReason = self.wndMain:FindChild("AwardReasonToggle"):GetText()
	local strReason = strReason ~= "Other" and strReason or self.wndMain:FindChild("OtherInput"):GetText()
	if nAward == "" or strReason == "" then
		return
	end
	if self.wndMain:FindChild("RecurringBtn"):IsChecked() then
		self.wndMain:FindChild("RecurringBtn"):SetCheck(false)
		self.wndMain:FindChild("EnableRecurrenceContainer"):Show(false)
		self.wndMain:FindChild("StopRecurrenceBtn"):Show(true)

		local nDelay = tonumber(self.wndMain:FindChild("DurationInput"):GetText())
		self.nRecurringAward = nAward
		self.strRecurringReason = string.format("%s - %dm Repeat", strReason, nDelay)
		strReason = self.strRecurringReason
		Apollo.CreateTimer("RecurringEPAwardTimer", nDelay*60, true)
		Apollo.StartTimer("RecurringEPAwardTimer")
	end
	
	self:GroupAwardEP(nAward, strReason)
	
	-- Force close any reason menus that may be open
	local wndART = self.wndMain:FindChild("AwardReasonToggle")
	wndART:SetCheck(false)
	self:OnAwardReasonToggle(wndHandler, wndART, eMouseButton)

	-- Fake a click on the close button to close the window
	self:OnMassAwardClose(wndHandler, wndContext, eMouseButton)
end

function EPGP:OnAwardReasonHover( wndHandler, wndControl, x, y )
	if wndHandler ~= wndControl then
		return
	end
	if self.wndSubMenu and self.wndSubMenu:GetParent() == wndControl  or self.wndSubMenu == wndControl:GetParent():GetParent() then
		return
	end
	if self.wndSubMenu then
		self.wndSubMenu:Destroy()
	end
	if type(wndControl:GetData()) ~= "table" then
		return
	end
	self.wndSubMenu = Apollo.LoadForm(self.xmlDoc, "AwardSubMenu", wndControl, self)
	local wndContainer = self.wndSubMenu:FindChild("AwardSubMenuBtns")
	local nCount = 0
	for nIdx, strLocation in pairs(wndControl:GetData()) do
		if type(strLocation) == "string" then
			local wndAwardBtn = Apollo.LoadForm(self.xmlDoc,"AwardReasonButton", wndContainer, self)
			wndAwardBtn:FindChild("AwardBtnText"):SetText(strLocation)
			if type(value) == "table" then
				wndAwardBtn:FindChild("BtnArrow"):Show(true)
				wndAwardBtn:SetData(value)
			end
			nCount = nCount + 1
		end
	end
	wndContainer:ArrangeChildrenVert(0)
	local nLeft, nTop, nRight, nBottom = wndContainer:GetParent():GetAnchorOffsets()
	wndContainer:GetParent():SetAnchorOffsets(nLeft, nTop, nRight, nBottom + (nCount * 25) + 40)
end

function EPGP:OnMassBtnArrowToggle( wndHandler, wndControl, eMouseButton )
	local wndART = self.wndMain:FindChild("AwardReasonToggle")
	wndART:SetCheck(wndControl:IsChecked())
	self:OnAwardReasonToggle(wndHandler, wndART, eMouseButton)
end

function EPGP:OnMassAwardClose( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("MassAwardBtn"):SetCheck(false)
	self:OnMassAwardToggle()
end

function EPGP:OnStopRecurrenceBtn( wndHandler, wndControl, eMouseButton )
	-- Hide Stop Timer Button
	wndControl:Show(false)
	-- Show Recurrence Options
	self.wndMain:FindChild("EnableRecurrenceContainer"):Show(true)
	-- Stop Award Timer
	Apollo.StopTimer("RecurringEPAwardTimer")
	-- Clear out award data
	self.nRecurringAward = 0
	self.strRecurringReason = nil

	ChatSystemLib.Command("/p [Mass EP] Raid EP Timer Halted")
	self.wndEPGPMenu:SetText("EPGP: Idle.")
	self.wndEPGPMenu:SetTextColor("gray")
end

function EPGP:OnMassAwardToggle( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("MassAwardContainer"):Show(self.wndMain:FindChild("MassAwardBtn"):IsChecked())
end

---------------------------------------------------------------------------------------------------
-- PortForm Functions
---------------------------------------------------------------------------------------------------

function EPGP:OnExportDBClick( wndHandler, wndControl, eMouseButton )
	self.wndImportExport:FindChild("txtData"):SetText( self:exportEPGP( 1 ) )
end

function EPGP:OnImportDBClick( wndHandler, wndControl, eMouseButton )
	self:importEPGP( self.wndImportExport:FindChild("txtData"):GetText() )
	self.wndImportExport:Destroy()
end

function EPGP:OnPortCloseBtn( wndHandler, wndControl, eMouseButton )
	self.wndImportExport:Destroy()
end

-- EPGP Instance
local EPGPInst = EPGP:new()
EPGPInst:Init()
