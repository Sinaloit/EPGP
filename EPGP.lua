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
local MenuToolTipFont_Header = "CRB_Pixel_O"
local MenuToolTipFont = "CRB_Pixel" 
local MenuToolTipFont_Help = "CRB_InterfaceSmall_I"
local kStrStandings = "Standings"
local kStrSortDownSprite = "HologramSprites:HoloArrowDownBtnFlyby"
local kStrSortUpSprite = "HologramSprites:HoloArrowUpBtnFlyby"
local ktAwardReasons = {
	"Genetic Archives",
	"Datascape",
}

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
	self.EPGP_LogDB = {}
	self.EPGP_StandingsDB = {}
	self.EPGP_GroupsDB = {}
	self.Config = {}
	self.FilterList = false
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("EPGP.xml")
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "EPGPForm", nil, self)
	if self.wndMain == nil then
		Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
		return Apollo.AddonLoadStatus.LoadingError
	end
	
	self.wndGrid = self.wndMain:FindChild("grdStandings")
	self.nSortCol = 1
	self.bSortAsc = false

	self.wndMassAwardEP = Apollo.LoadForm(self.xmlDoc, "MassAwardEPForm", nil, self)
	if self.wndMassAwardEP == nil then
		Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
		return Apollo.AddonLoadStatus.LoadingError
	end
	
    self.wndMassAwardEP:Show(false, true)

    self.wndEPGPConfigForm = Apollo.LoadForm(self.xmlDoc, "EPGPConfigForm", nil, self)
	if self.wndEPGPConfigForm == nil then
		Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
		return Apollo.AddonLoadStatus.LoadingError
	end
	
    self.wndEPGPConfigForm:Show(false, true)

    self.wndEPGPMenu = Apollo.LoadForm(self.xmlDoc, "EPGPMenu", nil, self)
	if self.wndEPGPMenu == nil then
		Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
		return Apollo.AddonLoadStatus.LoadingError
	end
	
    self.wndEPGPMenu:Show(true, true)
    -- Register Slash Commands
	Apollo.RegisterSlashCommand("epgp", "OnEPGPOn", self)
	Apollo.RegisterSlashCommand("epgpreset", "OnEPGPReset", self)

	Apollo.RegisterTimerHandler("RecurringEPAwardTimer", "Timer_RecurringEPAward", self) 

	-- Register Events
	Apollo.RegisterEventHandler("GuildRoster", "OnGuildRoster", self)
	Apollo.RegisterEventHandler("ChatMessage", "WhisperCommand", self)
	Apollo.RegisterEventHandler("Group_Join", "OnGroupJoin", self) 
	
	--Apollo.RegisterTimerHandler("TimerCheckAuctionExpired","TimerCheckAuctionExpired", self)
	
	--self:SetSyncChannel()
	--self:ToggleButtonStatus()
	
	self.wndOldSort = self.wndMain:FindChild("Character")
	self:SetupAwards()
	-- Setup Hooks
	self:RegisterHooks()
end

function EPGP:SetupAwards()
	local wndContainer = self.wndMain:FindChild("AwardListBtns")
	local nCount = 1
	for i,k in pairs(ktAwardReasons) do
		local wndAwardBtn = Apollo.LoadForm(self.xmlDoc,"AwardReasonButton", wndContainer, self)
		wndAwardBtn:SetText(k)
		nCount = nCount + 1
	end
	local wndAwardBtn = Apollo.LoadForm(self.xmlDoc,"AwardReasonButton", wndContainer, self)
	wndAwardBtn:SetText("Other")
	wndContainer:ArrangeChildrenVert(2)
	local nLeft, nTop, nRight, nBottom = wndContainer:GetParent():GetAnchorOffsets()
	wndContainer:GetParent():SetAnchorOffsets(nLeft, nTop, nRight, nBottom + (nCount * 22))
end

local function SortByPR(a, b)
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
		for idx, wndLooter in pairs(tMLoot.wndMasterLoot:FindChild("LooterList"):GetChildren()) do
			local wndOverlay = Apollo.LoadForm(tEPGP.xmlDoc, "EPGPOverlay", wndLooter, tEPGP)
			wndOverlay:FindChild("Label"):SetText("PR")
			wndOverlay:FindChild("Value"):SetText(string.format("%.2f",tEPGP:GetPR(wndLooter:FindChild("CharacterName"):GetText())))
		end
		tMLoot.wndMasterLoot:FindChild("LooterList"):ArrangeChildrenVert(0, SortByPR)
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

function EPGP:MakeItRain( strPassword )
	local reversePassword = string.reverse(strPassword)
	local key = ""
	for i = 1, #strPassword do
    	local c = strPassword:sub(i,i)
		local d = reversePassword:sub(i,i)
		key = key .. c .. d
		--[[ Sample
			pass: manatarms
			reverse: smratanam
			key: msamnraattaarnmasm
		--]]
	end
	return key
end

-- EPGP Functions
function EPGP:Timer_RecurringEPAward()
	--self:EPGP_AwardEP( 15 )
	self:GroupAwardEP( tonumber(self.Config.RecurringEP), "Recurring EP" )
end 

function EPGP:GroupAwardEP( amt, reason )
	local tGroup = {}
	for idx = 1, GroupLib.GetMemberCount() do
		table.insert(tGroup,GroupLib.GetGroupMember(idx).strCharacterName)
	end 
	for k,v in pairs(tGroup) do
		self.EPGP_StandingsDB[v] = self.EPGP_StandingsDB[v] or {}
		self.EPGP_StandingsDB[v][kStrStandings] = self.EPGP_StandingsDB[v][kStrStandings] or { EP = self.Config.MinEP, GP = self.Config.BaseGP }
		self.EPGP_StandingsDB[v][kStrStandings].EP = tonumber(self.EPGP_StandingsDB[v][kStrStandings].EP) + tonumber(amt)
	end 

	ChatSystemLib.Command("/p [Mass Award] Awarded Mass Group EP ( "..amt.." ) [ "..reason.."]")
	self:generateStandingsGrid()
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
	local EP = self.EPGP_StandingsDB[strCharName][kStrStandings].EP or self.Config.MinEP
	local GP = self.EPGP_StandingsDB[strCharName][kStrStandings].GP or self.Config.BaseGP
	self.EPGP_StandingsDB[strCharName][kStrStandings].EP = EP + amtEP
	self.EPGP_StandingsDB[strCharName][kStrStandings].GP = GP + amtGP
	self:generateStandingsGrid()
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
	self:generateStandingsGrid()
	Print("[EPGP] DB Imported")
end

-- on SlashCommand "/epgp"
function EPGP:OnEPGPOn()
	self.wndMain:Show(true) -- show the window
	--self:Top10List() -- Generate Top 10 List
	--self:GetRanking( "Fuzzrig" ) -- Testing Top 10 List
	
end

-- EPGPForm Functions
function EPGP:OnCancel()
	self.wndMain:Show(false) -- hide the window
end

function EPGP:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then 
		return 
	end
	
	return { db = self.EPGP_StandingsDB, log = self.EPGP_LogDB, groups = self.EPGP_GroupsDB, config = self.Config }
end

function EPGP:OnRestore(eLevel, tSavedData)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	
	self.EPGP_LogDB = tSavedData.log or {}
	self.EPGP_StandingsDB = tSavedData.db or {}
	self.EPGP_GroupsDB = tSavedData.groups or {}
	self.Config = tSavedData.config or {}
end

function EPGP:OnMassAwardPress( wndHandler, wndControl, eMouseButton )
	if GroupLib.GetMemberCount() == 0 then Print("[EPGP] Error: You Are Not In A Group.") return end 
	if GameLib.GetPlayerUnit():GetGuildName() == nil then Print("[EPGP] Error: You Are Not In A Guild.") return end 
	self.wndMassAwardEP:Show(true)
	self.wndMassAwardEP:ToFront()
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
	self:generateStandingsGrid()
end

function EPGP:OnRefreshList( wndHandler, wndControl, eMouseButton )
	self:generateStandingsGrid()
end

function EPGP:ToggleButtonStatus()
	local buttonArray = { "txtLate",
						  "txtOnTime",
						  "txtStandby",
						  "btnRecvLoot",
						  "btnDecay",
						  "btnMassAward"
						}
	if GroupLib.GetMemberCount() == 0 then 
		for idx = 1, #buttonArray do
			self.wndMain:FindChild( buttonArray[idx] ):Enable(false)
		end 
	else 
		for idx = 1, #buttonArray do
			self.wndMain:FindChild( buttonArray[idx] ):Enable(true)
		end 
	end 

end 

function EPGP:OnConfigure()
	if self.Config == nil then 
		self.Config.MinEP = "10"
		self.Config.BaseGP = "15"
		self.Config.EPGPDecay = "20"
		self.Config.RecurringEP = "15"
	end 
	self.wndEPGPConfigForm:FindChild("txtMinEP"):SetText(self.Config.MinEP or "10")
	self.wndEPGPConfigForm:FindChild("txtBaseGP"):SetText(self.Config.BaseGP or "15")
	self.wndEPGPConfigForm:FindChild("txtDecay"):SetText(self.Config.EPGPDecay or "20")
	self.wndEPGPConfigForm:FindChild("txtRecurringEP"):SetText(self.Config.RecurringEP or "15")
	-- Individual Awards
	if self.Config.tEPGPCosts == nil then 
		self.Config.tEPGPCosts = {}
		self.Config.tEPGPCosts["OnTime"] = {}
		self.Config.tEPGPCosts["OnTime"] = { EP = "5", GP = "0" }
		self.Config.tEPGPCosts["Late"] = {}
		self.Config.tEPGPCosts["Late"] = { EP = "0", GP = "5" }
		self.Config.tEPGPCosts["Standby"] = {}
		self.Config.tEPGPCosts["Standby"] = { EP = "15", GP = "0" }
	end
	self.wndEPGPConfigForm:FindChild("txtOnTimeEP"):SetText(self.Config.tEPGPCosts["OnTime"].EP)
	self.wndEPGPConfigForm:FindChild("txtOnTimeGP"):SetText(self.Config.tEPGPCosts["OnTime"].GP)
	self.wndEPGPConfigForm:FindChild("txtLateEP"):SetText(self.Config.tEPGPCosts["Late"].EP)
	self.wndEPGPConfigForm:FindChild("txtLateGP"):SetText(self.Config.tEPGPCosts["Late"].GP)
	self.wndEPGPConfigForm:FindChild("txtStandbyEP"):SetText(self.Config.tEPGPCosts["Standby"].EP)
	self.wndEPGPConfigForm:FindChild("txtStandbyGP"):SetText(self.Config.tEPGPCosts["Standby"].GP)

	self.wndEPGPConfigForm:Show(true)
	self.wndEPGPConfigForm:ToFront()
end

function EPGP:SetSortColumn( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation )
	-- Whatever you click, set the sort column
	local ColumnSortKey = { ["Character"] = 1, ["EP"] = 2, ["GP"] = 3, ["PR"] = 4 }
	local lblText = wndControl:GetText()
	--self:generateStandingsGrid()
	self.SortColumn = ColumnSortKey[lblText]
	--self.wndMain:FindChild("grdStandings"):SetSortColumn( ColumnSortKey[lblText] )
end

-- EPGPMenu Functions
function EPGP:OnMouseOverMenu( wndHandler, wndControl, eToolTipType, x, y )
	self.Config.MinEP = self.Config.MinEP or "10"
	self.Config.BaseGP = self.Config.BaseGP or "15"
	self.Config.EPGPDecay = self.Config.EPGPDecay or "20"
	self.Config.RecurringEP = self.Config.RecurringEP or "15"
	-- Set Tooltip for Main Menu Hover
	local strToolTip = string.format("<P Font=\""..MenuToolTipFont_Header.."\" TextColor=\"%s\">%s</P>", "white","EPGP")
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont.."\" TextColor=\"%s\">%s</P>", "yellow", "MinEP="..self.Config.MinEP)
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont.."\" TextColor=\"%s\">%s</P>", "yellow", "BaseGP="..self.Config.BaseGP)
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont.."\" TextColor=\"%s\">%s</P>", "yellow", "Decay="..string.format("%.0f %%",self.Config.EPGPDecay))
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont.."\" TextColor=\"%s\">%s</P>", "yellow", "RecurringEP="..self.Config.RecurringEP)
	strToolTip = strToolTip .. "\r\n\r\n"
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont_Help.."\" TextColor=\"%s\">%s</P>", "green", "(Right-Click To Open Standings)")
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont_Help.."\" TextColor=\"%s\">%s</P>", "green", "(ToeNail-Click To Open Config)")
	wndHandler:SetTooltip(strToolTip)
end

function EPGP:OnEPGPMenuMouseClick( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation )
	if eMouseButton == 1 then
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
	  self:generateStandingsGrid()
	  self.wndMain:Show( not self.wndMain:IsVisible() )
	end
end

function EPGP:RefreshGuildRoster()
	if self.guildCurr == nil then
		for i, guildCurr in ipairs(GuildLib.GetGuilds()) do
			if guildCurr:GetType() == GuildLib.GuildType_Guild then
				self.guildCurr = guildCurr
				break
			end
		end
	end
	if self.guildCurr == nil then return end -- nothing we can do.  the player isn't in a guild shouldn't even get this far.
	self.guildCurr:RequestMembers()
end 

function EPGP:generateStandingsGrid()
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
			self.EPGP_StandingsDB[v][kStrStandings] = self.EPGP_StandingsDB[v][kStrStandings] or { EP = self.Config.MinEP, GP = self.Config.BaseGP }
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
	local EP = self.EPGP_StandingsDB[strName][kStrStandings].EP or self.Config.MinEP
	return EP
end

function EPGP:GetGP(strName)
	local GP = self.EPGP_StandingsDB[strName][kStrStandings].GP or self.Config.BaseGP
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
		stnd.EP = self.Config.MinEP
		end 
		if stnd.GP == nil then
		stnd.GP = self.Config.BaseGP
		end 
		if not stnd or stnd == nil then Print("[EPGP] stnd is nil or not there") end
		stnd.Sent = stnd.Sent or nil
		if (stnd.Sent == false or stnd.Sent == nil) then 
			local tmpID = GameLib.GetServerTime()
			stnd.TimeStamp = (tmpID.nMinute * 60) + tmpID.nSecond + 5
			stnd.Sent = true 
			local PR = string.format("%.2f",stnd.EP / stnd.GP)
			ChatSystemLib.Command("/w " .. strName .. " ( [ep] " .. stnd.EP .. " [gp] " .. stnd.GP .. " [pr] " .. PR .. " )")
			self:generateStandingsGrid()
		end 
		local newTime = GameLib.GetServerTime()
		if stnd.TimeStamp < ((newTime.nMinute * 60) + newTime.nSecond) then
			stnd.Sent = false
		end
	elseif string.find( strMessage,"\!bid" ) then
		if self.currentItemSelected == nil then return end
		if self:IsInGroup(tMessage.strSender) then -- they are in the group
			self:auctionEnterItemBid( tMessage.strSender )
		else 
			ChatSystemLib.Command("/w " .. tMessage.Sender .. " You are not in the group.")
		end
	end
end
function EPGP:calculateAuctionWinner()
	local winner = ""
	local tieList = {}
	local winnerPR = 0
	--SendVarToRover("Bidders", self.Auction["Bidders"])
	
	for idx = 1, #self.Auction["Bidders"] do
		--local playerPR = GetStandings(strPlayerName)
		local tStnd = self.EPGP_StandingsDB
		if tStnd == nil then return winner end 
		for k, tSamplePlayer in pairs(tStnd) do
			local tPlayerStandings = tSamplePlayer[kStrStandings]
			if string.lower(k) == string.lower(self.Auction["Bidders"][idx]) then  -- Matching Name
				EP = tPlayerStandings.EP
				GP = tPlayerStandings.GP
				PR = ( tPlayerStandings.EP / tPlayerStandings.GP)
				if winnerPR == PR then 
					table.insert(tieList,winner)
					table.insert(tieList,k)
					winner = ""
					winnerPR = PR
				elseif winnerPR < PR then 
					winner = k 
					winnerPR = PR 
				end
			end
		end
	end
	-- end of bidders
	if #tieList == 0 then return winner end
	-- there is a tie, randomize lulz
	self.Auction = nil
	return tieList[ math.random(1,#tieList) ]
end

function EPGP:TimerCheckAuctionExpired() 
	local tAucItem = self.currentItemSelected
	local tAucItemChatLink = tAucItem:GetChatLinkString()
	local tAucName = tAucItem:GetName()
	local auctionBlock = self.Auction
	local winnerName = self:calculateAuctionWinner()
	if self.Auction["Expires"] == 0 then 
		-- Expired
		--self.Auction = nil
		ChatSystemLib.Command("/party [ Auction Timer ] {" .. tAucItemChatLink.."} [ Bidding Has Ended ]")
		Apollo.StopTimer("TimerCheckAuctionExpired")
		ChatSystemLib.Command("/party [ {" ..tAucItemChatLink.."} ] :: Winner " .. winnerName .. "! Conglaturations!")
		self.Auction = nil 
		self.currentItemSelected = nil
		-- Request: Auto-Select name in grid list :)
		local grdList = self.wndMain:FindChild("grdStandings")
		grdList:SelectCellByData(winnerName)
	elseif self.Auction["Expires"] == 10 then 
		self.Auction["Expires"] = 0
		Apollo.CreateTimer("TimerCheckAuctionExpired", 10, false)
		Apollo.StartTimer("TimerCheckAuctionExpired")	
		ChatSystemLib.Command("/party [ Auction Timer ] {" .. tAucItemChatLink.."} [ ~10 seconds remaining ]")
	elseif self.Auction["Expires"] == 15 then 
		self.Auction["Expires"] = 10
		Apollo.CreateTimer("TimerCheckAuctionExpired", 15, false)
		Apollo.StartTimer("TimerCheckAuctionExpired")	
		ChatSystemLib.Command("/party [ Auction Timer ] {" .. tAucItemChatLink.."} [ ~15 seconds remaining ]")
	elseif self.Auction["Expires"] == 30 then	
		self.Auction["Expires"] = 15
		ChatSystemLib.Command("/party [ Auction Timer ] {" .. tAucItemChatLink.."} [ ~30 seconds remaining ]")
		Apollo.CreateTimer("TimerCheckAuctionExpired", 30, false)
		Apollo.StartTimer("TimerCheckAuctionExpired")	
	end

end

function EPGP:auctionEnterItemBid( strPlayerName )
	if self.Auction["Bidders"] == nil or self.Auction["Bidders"] == "" then
		self.Auction["Bidders"] = {}
		table.insert(self.Auction["Bidders"], strPlayerName)
		ChatSystemLib.Command("/w " .. strPlayerName .. " Bid Accepted for {" .. self.currentItemSelected:GetChatLinkString() .. "}")
	end
	local bidderList = self.Auction["Bidders"]
	
	for _, v in pairs(bidderList) do
		if v == strPlayerName then
			return 
		end
	end
	table.insert(self.Auction["Bidders"], strPlayerName)
	ChatSystemLib.Command("/w " .. strPlayerName .. " Bid Accepted for {" .. self.currentItemSelected:GetChatLinkString() .. "}")
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
		self:generateStandingsGrid()
	end 
	local newTime = GameLib.GetServerTime()
	if stnd.TimeStamp < ((newTime.nMinute * 60) + newTime.nSecond) then
		stnd.Sent = false
	end
end 


---------------------------------------------------------------------------------------------------
-- MassAwardEPForm Functions
---------------------------------------------------------------------------------------------------

function EPGP:OnRecurringCheck( wndHandler, wndControl, eMouseButton )
		local nDelay = tonumber(wndHandler:GetParent():FindChild("txtDelay"):GetText())
		ChatSystemLib.Command("/p [Mass EP] Recurring Timer ( ".. self.Config.RecurringEP.." EP every " .. nDelay .. " minutes )")
		Apollo.CreateTimer("RecurringEPAwardTimer", nDelay*60, true)
		Apollo.StartTimer("RecurringEPAwardTimer")
		self.wndEPGPMenu:SetText("EPGP: " .. self.wndMassAwardEP:FindChild("txtDelay"):GetText() .. " Min.")
		self.wndEPGPMenu:SetTextColor("xkcdBrightYellowGreen")
end

function EPGP:DecayEPGP()
	for k, val in pairs( self.EPGP_StandingsDB) do 
		local EP = self.EPGP_StandingsDB[k][kStrStandings].EP / 1.20
		local GP = self.EPGP_StandingsDB[k][kStrStandings].GP / 1.20		
		self.EPGP_StandingsDB[k] = self.EPGP_StandingsDB[k] or {}
		self.EPGP_StandingsDB[k][kStrStandings].EP = string.format("%.2f",self.EPGP_StandingsDB[k][kStrStandings].EP / 1.20) 
		self.EPGP_StandingsDB[k][kStrStandings].GP = string.format("%.2f",self.EPGP_StandingsDB[k][kStrStandings].GP / 1.20)
	end 
	self:generateStandingsGrid()
end 

function EPGP:OnRecurringUnCheck( wndHandler, wndControl, eMouseButton )
		ChatSystemLib.Command("/p [Mass EP] Raid EP Timer Halted")
		Apollo.StopTimer("RecurringEPAwardTimer")
		self.wndEPGPMenu:SetText("EPGP: Idle.")
		self.wndEPGPMenu:SetTextColor("gray")
end

function EPGP:OnAwardButton( wndHandler, wndControl, eMouseButton )
	local amt = tonumber(wndControl:GetParent():FindChild("txtValue"):GetText())
	local reason = wndControl:GetParent():FindChild("txtReason"):GetText()
	self:GroupAwardEP( amt, reason )
end

function EPGP:OnEPGPGridItemClick(wndControl, wndHandler, iRow, iCol, eClick)
	-- local strCharName = wndHandler:GetCellLuaData(iRow,1)
end

---------------------------------------------------------------------------------------------------
-- EPGPConfigForm Functions
---------------------------------------------------------------------------------------------------

function EPGP:OnSaveConfig( wndHandler, wndControl, eMouseButton )
	self.Config.MinEP = self.wndEPGPConfigForm:FindChild("txtMinEP"):GetText()
	self.Config.BaseGP = self.wndEPGPConfigForm:FindChild("txtBaseGP"):GetText()
	self.Config.EPGPDecay = self.wndEPGPConfigForm:FindChild("txtDecay"):GetText()
	self.Config.RecurringEP = self.wndEPGPConfigForm:FindChild("txtRecurringEP"):GetText()
	self.Config.tEPGPCosts = {}
	self.Config.tEPGPCosts["Late"] = { EP = self.wndEPGPConfigForm:FindChild("txtLateEP"):GetText(),  GP = self.wndEPGPConfigForm:FindChild("txtLateGP"):GetText(), strMsg = "/p [%s] Late Arrival%s%s" }
	self.Config.tEPGPCosts["OnTime"] = { EP = self.wndEPGPConfigForm:FindChild("txtOnTimeEP"):GetText(),  GP = self.wndEPGPConfigForm:FindChild("txtOnTimeGP"):GetText(), strMsg = "/p [%s] On-Time Arrival%s%s" }
	self.Config.tEPGPCosts["Standby"] = { EP = self.wndEPGPConfigForm:FindChild("txtStandbyEP"):GetText(),  GP = self.wndEPGPConfigForm:FindChild("txtStandbyGP"):GetText(), strMsg = "/p [%s] Standby Points%s%s" }

	--[[
	self.Config.tEPGPCosts = {
		["Late"]    = { EP = self.wndEPGPConfigForm:FindChild("txtLateEP"):GetText(),  GP = self.wndEPGPConfigForm:FindChild("txtLateGP"):GetText() or 5, strMsg = "/p [%s] Late Arrival%s%s" },
		["OnTime"]  = { EP = self.wndEPGPConfigForm:FindChild("txtLateEP"):GetText(),  GP = self.wndEPGPConfigForm:FindChild("txtLateGP"):GetText() or 0, strMsg = "/p [%s] On-Time Arrival%s%s" },
		["Standby"] = { EP = self.wndEPGPConfigForm:FindChild("txtLateEP"):GetText(),  GP = self.wndEPGPConfigForm:FindChild("txtLateGP"):GetText() or 0, strMsg = "/p [%s] Standby Points%s%s" },
	}
	--]]
	self.wndEPGPConfigForm:Show(false)
	local strToolTip = string.format("<P Font=\""..MenuToolTipFont_Header.."\" TextColor=\"%s\">%s</P>", "white","EPGP")
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont.."\" TextColor=\"%s\">%s</P>", "yellow", "MinEP="..self.Config.MinEP or "10")
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont.."\" TextColor=\"%s\">%s</P>", "yellow", "BaseGP="..self.Config.BaseGP or "15")
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont.."\" TextColor=\"%s\">%s</P>", "yellow", "Decay="..string.format("%.0f %%",self.Config.EPGPDecay or "20"))
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont.."\" TextColor=\"%s\">%s</P>", "yellow", "RecurringEP="..self.Config.RecurringEP or "15")
	strToolTip = strToolTip .. "\r\n\r\n"
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont_Help.."\" TextColor=\"%s\">%s</P>", "green", "(Right-Click To Open Standings)")
	strToolTip = strToolTip .. string.format("<P Font=\""..MenuToolTipFont_Help.."\" TextColor=\"%s\">%s</P>", "green", "(ToeNail-Click To Open Config)")

	self.wndEPGPMenu:SetTooltip(strToolTip)
end

function EPGP:Top10List()
	self.top10 = {}
	for k, val in pairs( self.EPGP_StandingsDB) do 
		local EP = self.EPGP_StandingsDB[k][kStrStandings].EP
		local GP = self.EPGP_StandingsDB[k][kStrStandings].GP
		local PR = EP / GP
		PR = string.format("%.3f",PR)
		-- Use the PR as a key in string form, and add the name [k] as a entry so we can count entries later
		self.top10[PR] = self.top10[PR] or {}
		table.insert( self.top10[PR], k )
	end 
	--[[
	local sortedlist = {}
	for k,v in spairs(HighScore, function(t,a,b) return t[b] < t[a] end) do
		table.insert( sortedlist, { k = v } )
	end 
	self.top10 = sortedlist
	--]]
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

function EPGP:GetRanking( strName )
	-- we have the entry, so we just have to find the # in the list that it is.
	for i=1,10 do 
		Print("Rank ".. i .. ": " .. #self.top10(i) .. " Entries")
	end 
end 

-- Clicking a specific element on the Grid
function EPGP:OnEPGPGridItemClick(wndControl, wndHandler, iRow, iCol, eClick)
    -- Not a right click, nothing interesting to do
    if eClick ~= 1 then return end

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
	self:generateStandingsGrid()

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
	self:generateStandingsGrid()
	self.ItemGPCost = nil
	self.wndContext:Destroy()
end

function EPGP:CalculateLootItemCost()
	return self.ItemGPCost -- Calculations on GP Cost are always done when you click the bid button
end

function EPGP:CalculateItemGPValue( tItem )
	--[[ Threeks Formula:
		( (B+( (Q-1)*2) ) * (100) ) * M
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
	--local tItem = tItemInfo.itemDrop
	local B = tItem:GetPowerLevel()
	local Q = tItem:GetItemQuality()
	local convSlotNumberToName =
	{
		["Chest"] = 1, -- slot 0 conver
		["Legs"] = 1,
		["Head"] = 1,
		["Shoulder"] = 1,
		["Feet"] = 1,
		["Hands"] = 1,
		["Tool"] = 0.5,
		[""] = 0.75, -- (THIS HAS NO NAME) WeaponAttachmentSlot
		[""] = 0.75, -- (THIS HAS NO NAME) SupportSystemSlot
		[""] = 1, -- (THIS HAS NO NAME) Key
		["Agument"] = 0.75,
		["Gadget"] = 0.75,
		[""] = 1,
		[""] = 1,
		[""] = 1,
		["Shields"] = 1.25,
		["Primary Weapon"] = 1.5, -- Missing From List: Implant Slot
	}
	local sNum = 1
	if tItem.GetSlot() ~= nil then 
		sNum = tItem.GetSlot() + 1
	end 
	local M = convSlotNumberToName[ sNum ]
	if M == nil then 
		M = 1.5
	end
	local ItemGPCost = ( (B+( (Q-1)*2) ) * (100) ) * M
	self.ItemGPCost = ItemGPCost
	return ItemGPCost

end 

function EPGP:addItemToAuctionBlock(tItemInfo)
	local strName = tItemInfo.itemDrop:GetName()
	if not self.Auction then
		self.Auction = {}
		self.Auction.strName = { eItemInfo = tItemInfo }
	end
	Print("Debug: created auction")
	--SendVarToRover("auction", self.Auction) 
	self.Auction["Expires"] = 30
	Apollo.CreateTimer("TimerCheckAuctionExpired", 30, false)
	Apollo.StartTimer("TimerCheckAuctionExpired")	
	ChatSystemLib.Command("/party [ Auction Timer ] {" .. tItemInfo.itemDrop:GetChatLinkString().."} [ ~60 seconds remaining ]")

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
	self:generateStandingsGrid()
end

function EPGP:OnFilterListUnCheck( wndHandler, wndControl, eMouseButton )
	self.FilterList = false
	self:generateStandingsGrid()
end

function EPGP:OnEPGPSizeChanged( wndHandler, wndControl )
	if wndHandler ~= wndControl then
        return
    end
    -- Resize the Standings Grid
    self:ResizeGrid(self.wndGrid)
end

function EPGP:OnConfigToggle( wndHandler, wndControl, eMouseButton )
	local bShowWnd = self.wndMain:FindChild("ConfigButton"):IsChecked()
	self.wndMain:FindChild("ConfigContainer"):Show(bShowWnd)
end

function EPGP:OnAwardReasonBtn( wndHandler, wndControl, eMouseButton )
	local strNewReason = wndControl:GetText()
	self.wndMain:FindChild("AwardReasonToggle"):SetText(strNewReason)
	self.wndMain:FindChild("AwardListContainer"):Show(false)
	self.wndMain:FindChild("OtherContainer"):Show(strNewReason == "Other")
	self.wndMain:FindChild("AwardReasonToggle"):SetCheck(false)
end

function EPGP:OnAwardReasonToggle( wndHandler, wndControl, eMouseButton )
	local bShowWnd = wndControl:IsChecked()
	self.wndMain:FindChild("AwardListContainer"):Show(bShowWnd)
end

function EPGP:OnAwardEP( wndHandler, wndControl, eMouseButton )
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
