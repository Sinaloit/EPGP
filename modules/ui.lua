local EPGP = Apollo.GetAddon("EPGP")
local UIMod = EPGP:NewModule("ui")
local L = EPGP.L
local glog, callbacks, DLG, GS

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

local tSortCols = {["Character"]=1,["EP"]=2,["GP"]=3,["PR"] = 4,}

function UIMod:OnInitialize()
	--self.db = EPGP.db:RegisterNamespace("ui") - Need defaults?
	glog = EPGP.glog
	DLG = EPGP.DLG
	GS = Apollo.GetPackage("LibGuildStorage-1.0").tPackage
	-- Register either way, we give an error if not enabled
	Apollo.RegisterEventHandler("ToggleEPGPWindow", "OnToggleEPGPWindow", self)
end

local function ShowStopRecurrence()
	UIMod.wndMain:FindChild("RecurringBtn"):SetCheck(false)
	UIMod.wndMain:FindChild("EnableRecurrenceContainer"):Show(false)
	UIMod.wndMain:FindChild("StopRecurrenceBtn"):Show(true)
end

local function HideStopRecurrence()
	UIMod.wndMain:FindChild("EnableRecurrenceContainer"):Show(true)
	UIMod.wndMain:FindChild("StopRecurrenceBtn"):Show(false)
end

function UIMod:OnEnable()
	-- Main EPGP Form
	self.wndMain = Apollo.LoadForm(EPGP.xmlDoc, "EPGPForm", nil, self)
	if self.wndMain == nil then
		return "Could not load the main window for some reason."
	end

	-- Standings Grid and associated variables
	self.wndGrid = self.wndMain:FindChild("grdStandings")
	self.wndMain:FindChild("DurationInput"):SetText(EPGP.db.profile.nRecurringEPPeriodMins)
	-- PR is the initially selected sort method
	self.wndOldSort = self.wndMain:FindChild(EPGP.db.profile.strSortOrder)

	EPGP.RegisterCallback(self, "Decay", "GenerateStandingsGrid")
	EPGP.RegisterCallback(self, "StandingsChanged", "GenerateStandingsGrid")
	EPGP.RegisterCallback(self, "ResumeRecurringAward", ShowStopRecurrence)
	EPGP.RegisterCallback(self, "StopRecurringAward", HideStopRecurrence)
	self:SetupAwards()
end

function UIMod:OnDisable()
	EPGP.UnregisterAllCallbacks(self)
	self.wndMain:Destroy()
end

function UIMod:EPGP_AwardEP( strCharName, amtEP, amtGP )
	local EP = self.EPGP_StandingsDB[strCharName][kStrStandings].EP or self.Config.nMinEP
	local GP = self.EPGP_StandingsDB[strCharName][kStrStandings].GP or self.Config.nBaseGP
	self.EPGP_StandingsDB[strCharName][kStrStandings].EP = EP + amtEP
	self.EPGP_StandingsDB[strCharName][kStrStandings].GP = GP + amtGP
	self:GenerateStandingsGrid()
end 

function UIMod:OnToggleEPGPWindow()
	if self:IsEnabled() then
		self.wndMain:Show(not self.wndMain:IsVisible())
	else
		Print("Sorry you are not in a Guild!")
	end
end

function UIMod:SetupAwards()
	local wndContainer = self.wndMain:FindChild("AwardListBtns")
	local nCount = 1
	for strLocation, value in pairs(ktAwardReasons) do
		if type(strLocation) == "string" then
			local wndAwardBtn = Apollo.LoadForm(EPGP.xmlDoc,"SubMenuButton", wndContainer, self)
			wndAwardBtn:FindChild("BtnText"):SetText(strLocation)
			if type(value) == "table" then
				wndAwardBtn:FindChild("BtnArrow"):Show(true)
				wndAwardBtn:SetData(value)
			end
			nCount = nCount + 1
		end
	end
	local wndAwardBtn = Apollo.LoadForm(EPGP.xmlDoc,"SubMenuButton", wndContainer, self)
	wndAwardBtn:FindChild("BtnText"):SetText("Other")
	wndContainer:ArrangeChildrenVert(0)
	local nLeft, nTop, nRight, nBottom = wndContainer:GetParent():GetAnchorOffsets()
	wndContainer:GetParent():SetAnchorOffsets(nLeft, nTop, nRight, nBottom + (nCount * 25) + 36)
	self:ToggleOtherReason(true)
end

function UIMod:AwardItem(tCharacter, tItem)
	local nGPCost = self:CalculateItemGPValue(tItem)
	ChatSystemLib.Command("/p ["..tCharacter:GetName().."] Received "..tItem:GetName().." "..nGPCost.."GP")
	self:EPGP_AwardEP(tCharacter:GetName(), 0, nGPCost)
end

function UIMod:exportEPGP( iFormat )
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
		--  <Entry>
		--    <Name></Name>
		--    <EP>0</EP>
		--    <GP>0</GP>
		--  </Entry>
		--  <Entry>
		--    <Name></Name>
		--    <EP>0</EP>
		--    <GP>0</GP>
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

function UIMod:importEPGP( tImportData )
--[[ Log will handle import/export
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
	glog:info("[EPGP] DB Imported")
	--]]
end

-- EPGPForm Functions
function UIMod:OnCancel()
	self.wndMain:Show(false) -- hide the window
end

function UIMod:OnSingleItemAward( wndHandler, wndControl, eMouseButton )
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

function UIMod:GenerateStandingsGrid(nSortCol, bShowAll)
	local grdList = self.wndGrid
	if not GS:GetGuild() then return end

	-- Clear out old list
	grdList:DeleteAll()

	-- Build new list
	for nIndex = 1, EPGP:GetNumMembers() do 
		local iCurrRow = grdList:AddRow("")
		local strName = EPGP:GetMember(nIndex)
		local nEP, nGP = EPGP:GetEPGP(strName)
		local nPR = string.format("%.2f", nEP / nGP)
		local PRSort = nEP >= EPGP.db.profile.nMinEP and string.format("_%.3f", nEP/nGP) or string.format("%.3f", nGP/nEP)

		grdList:SetCellText(iCurrRow, 1, strName)
		grdList:SetCellSortText(iCurrRow, 1, string.lower(strName))
		
		grdList:SetCellText(iCurrRow, 2, nEP)
		grdList:SetCellSortText(iCurrRow, 2,string.format("%.3f", nEP))
		
		grdList:SetCellText(iCurrRow, 3, nGP)
		grdList:SetCellSortText(iCurrRow, 3, string.format("%.3f", nGP))
		
		grdList:SetCellText(iCurrRow, 4, nPR)
		grdList:SetCellSortText(iCurrRow, 4, PRSort)
	end
	grdList:SetSortColumn(tSortCols[EPGP.db.profile.strSortOrder], EPGP.db.profile.bSortAsc)
end

---------------------------------------------------------------------------------------------------
-- MassAwardEPForm Functions
---------------------------------------------------------------------------------------------------

function UIMod:DecayEPGP(wndHandler, wndControl, eMouseButton)
	if EPGP:CanDecayEPGP() then
		DLG:Spawn("EPGP_DECAY_EPGP", EPGP:GetDecayPercent())
	end
end 

---------------------------------------------------------------------------------------------------
-- EPGPConfigForm Functions
---------------------------------------------------------------------------------------------------

-- Clicking a specific element on the Grid
function UIMod:OnEPGPGridItemClick(wndControl, wndHandler, iRow, iCol, eClick)
	-- Not a right click, nothing interesting to do
	if eClick ~= GameLib.CodeEnumInputMouse.Right then return end

	-- If we already have a context menu, destroy it
	if self.wndContext ~= nil and self.wndContext:IsValid() then
		self.wndContext:Destroy()
	end

	-- Create a context menu and bring it to front
	self.wndContext = Apollo.LoadForm(EPGP.xmlDoc, "EPGPContextMenu", self.wndMain, self)
	self.wndContext:ToFront()

	-- Move context menu to the mouse
	local tCursor= self.wndMain:GetMouse()
	self.wndContext:Move(tCursor.x + 4, tCursor.y + 4, self.wndContext:GetWidth(), self.wndContext:GetHeight())

	-- Save the name so we can use it for whatever action we choose (Could save iRow and look up whatever instead)
	self.wndContext:SetData(wndHandler:GetCellText(iRow, 1))
end

-- EPGPContextMenu Functions
function UIMod:OnContextBtnClick( wndHandler, wndControl, eMouseButton )
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
function UIMod:OnAwardBtnClick( wndHandler, wndControl, eMouseButton )
	local strName = self.wndContext:GetData()
	if self.ItemGPCost == nil then self.wndContext:Destroy() return end -- no item was found, cannot award a loot deduction without it.
	ChatSystemLib.Command("/p ["..strName.."] Received Loot Item +"..self.ItemGPCost.."GP")
	self:EPGP_AwardEP(strName,0,self.ItemGPCost)
	self.ItemGPCost = nil
	self.wndContext:Destroy()
end

function UIMod:OnSortOrderChange(wndHandler, wndControl, eMouseButton)
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
	EPGP.db.profile.strSortOrder, EPGP.db.profile.bSortAsc = wndControl:GetName(), bAsc
	self.wndGrid:SetSortColumn(tSortCols[wndControl:GetName()], bAsc)
	-- Set appropriate sort sprite
	wndControl:FindChild("SortOrderIcon"):SetSprite(bAsc and kStrSortUpSprite or kStrSortDownSprite)
end

function UIMod:ResizeGrid(wndGrid)
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

---------------------------------------------------------------------------------------------------
-- EPGPForm Functions
---------------------------------------------------------------------------------------------------

function UIMod:OnImportExportButton( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation )
	if self.wndImportExport ~= nil then 
		self.wndImportExport:Destroy()
	end 
	
	self.wndImportExport = Apollo.LoadForm(EPGP.xmlDoc, "PortForm", self.wndMain, self) 
	self.wndImportExport:Show(true, true)
	self.wndImportExport:ToFront()  
end

function UIMod:OnFilterListCheck( wndHandler, wndControl, eMouseButton )
	self.FilterList = true
	self:GenerateStandingsGrid()
end

function UIMod:OnFilterListUnCheck( wndHandler, wndControl, eMouseButton )
	self.FilterList = false
	self:GenerateStandingsGrid()
end

function UIMod:OnEPGPSizeChanged( wndHandler, wndControl )
	if wndHandler ~= wndControl then
		return
	end
	-- Resize the Standings Grid
	self:ResizeGrid(self.wndGrid)
end

function UIMod:OnAwardReasonBtn( wndHandler, wndControl, eMouseButton )
	local strNewReason = wndControl:FindChild("BtnText"):GetText()
	local wndAwardReasonToggle = self.wndMain:FindChild("AwardReasonToggle")
	wndAwardReasonToggle:SetText(strNewReason)
	wndAwardReasonToggle:SetCheck(false)
	self:OnAwardReasonToggle(wndHandler, wndAwardReasonToggle, eMouseButton)
	if self.wndSubMenu then
		self.wndSubMenu:Destroy()
	end
	self:ToggleOtherReason(strNewReason == "Other")
end

function UIMod:ToggleOtherReason(bShowOther)
	local wndOC = self.wndMain:FindChild("OtherContainer")
	if bShowOther then
		wndOC:SetTextColor("UI_TextHoloBody")
	else
		wndOC:SetTextColor("UI_BtnTextHoloDisabled")
		wndOC:FindChild("OtherInput"):SetText("")
	end
	wndOC:FindChild("OtherInput"):Enable(bShowOther)
end

function UIMod:OnAwardReasonToggle( wndHandler, wndControl, eMouseButton )
	local bShowWnd = wndControl:IsChecked()
	wndControl:FindChild("BtnArrow"):SetCheck(bShowWnd)
	self.wndMain:FindChild("AwardListContainer"):Show(bShowWnd)
	if self.wndSubMenu then
		self.wndSubMenu:Destroy()
	end
end

function UIMod:OnAwardEP( wndHandler, wndControl, eMouseButton )
	local nAward = self.wndMain:FindChild("ValueInput"):GetText()
	local strReason = self.wndMain:FindChild("AwardReasonToggle"):GetText()
	local strReason = strReason ~= "Other" and strReason or self.wndMain:FindChild("OtherInput"):GetText()
	if nAward == "" or strReason == "" then
		return
	end
	if self.wndMain:FindChild("RecurringBtn"):IsChecked() then
		ShowStopRecurrence()

		local nDelay = tonumber(self.wndMain:FindChild("DurationInput"):GetText())

		EPGP.db.profile.nRecurringEPPeriodMins = nDelay
		EPGP:GetModule("recurring"):StartRecurringEP(strReason, nAward)
	else
		EPGP:IncMassEPBy(strReason, nAward)
	end
	-- Force close any reason menus that may be open
	local wndART = self.wndMain:FindChild("AwardReasonToggle")
	wndART:SetCheck(false)
	self:OnAwardReasonToggle(wndHandler, wndART, eMouseButton)

	-- Fake a click on the close button to close the window
	self:OnMassAwardClose(wndHandler, wndContext, eMouseButton)
end

function UIMod:OnAwardReasonHover( wndHandler, wndControl, x, y )
	if wndHandler ~= wndControl then
		return
	end
	if self.wndSubMenu and self.wndSubMenu:GetParent() == wndControl or self.wndSubMenu == wndControl:GetParent():GetParent() then
		return
	end
	if self.wndSubMenu then
		self.wndSubMenu:Destroy()
	end
	if type(wndControl:GetData()) ~= "table" then
		return
	end
	self.wndSubMenu = Apollo.LoadForm(EPGP.xmlDoc, "SubMenu", wndControl, self)
	local wndContainer = self.wndSubMenu:FindChild("SubMenuBtns")
	local nCount = 0
	for nIdx, strLocation in pairs(wndControl:GetData()) do
		if type(strLocation) == "string" then
			local wndAwardBtn = Apollo.LoadForm(EPGP.xmlDoc,"SubMenuButton", wndContainer, self)
			wndAwardBtn:FindChild("BtnText"):SetText(strLocation)
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

function UIMod:OnMassBtnArrowToggle( wndHandler, wndControl, eMouseButton )
	local wndART = self.wndMain:FindChild("AwardReasonToggle")
	wndART:SetCheck(wndControl:IsChecked())
	self:OnAwardReasonToggle(wndHandler, wndART, eMouseButton)
end

function UIMod:OnMassAwardClose( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("MassAwardBtn"):SetCheck(false)
	self:OnMassAwardToggle()
end

function UIMod:OnStopRecurrenceBtn( wndHandler, wndControl, eMouseButton )
	-- Hide Stop Timer Button
	wndControl:Show(false)
	-- Show Recurrence Options
	self.wndMain:FindChild("EnableRecurrenceContainer"):Show(true)
	-- Stop Award Timer
	EPGP:GetModule("recurring"):StopRecurringEP()
end

function UIMod:OnMassAwardToggle( wndHandler, wndControl, eMouseButton )
	self.wndMain:FindChild("MassAwardContainer"):Show(self.wndMain:FindChild("MassAwardBtn"):IsChecked())
end



---------------------------------------------------------------------------------------------------
-- PortForm Functions
---------------------------------------------------------------------------------------------------
--[[
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
]]