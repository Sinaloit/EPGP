-------------------------------------------------
--					LibDialog - V1.0
-------------------------------------------------

--[[
The MIT License (MIT)

Copyright (c) 2014

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]

local MAJOR,MINOR = "Gemini:LibDialog-1.0", 6
-- Get a reference to the package information if any
local APkg = Apollo.GetPackage(MAJOR)
-- If there was an older version loaded we need to see if this is newer
if APkg and (APkg.nVersion or 0) >= MINOR then
	return -- no upgrade needed
end
-- Set a reference to the actual package or create an empty table
local Lib = APkg and APkg.tPackage or {}

-- Color lookup table for Icon Quality setting, populated at load time.
local ktQualityLookup = {}

local tLibError = Apollo.GetPackage("Gemini:LibError-1.0")
local fnErrorHandler = tLibError and tLibError.tPackage and tLibError.tPackage.Error or Print

---------------------------------------------------------------------------------------------
--- Utility local functions
---------------------------------------------------------------------------------------------
-- xpcall safecall implementation
local function CreateDispatcher(argCount)
  local code = [[
    local xpcall, eh = ...
    local method, ARGS
    local function call() return method(ARGS) end
  
    local function dispatch(func, ...)
       method = func
       if not method then return end
       ARGS = ...
       return xpcall(call, eh)
    end
  
    return dispatch
  ]]
  
  local ARGS = {}
  for i = 1, argCount do ARGS[i] = "arg"..i end
  code = code:gsub("ARGS", table.concat(ARGS, ", "))
  return assert(loadstring(code, "safecall Dispatcher[" .. argCount .. "]"))(xpcall, fnErrorHandler)
end

local Dispatchers = setmetatable({}, {__index=function(self, argCount)
  local dispatcher = CreateDispatcher(argCount)
  rawset(self, argCount, dispatcher)
  return dispatcher
end})
Dispatchers[0] = function(func)
  return xpcall(func, fnErrorHandler)
end

local function safecall(func, ...)
  if type(func) == "function" then
    return Dispatchers[select('#', ...)](func, ...)
  end
end

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

---------------------------------------------------------------------------------------------
--- XML Definition
---------------------------------------------------------------------------------------------

local tXMLData = {
	__XmlNode = "Forms",
	{ -- Form
		__XmlNode="Form", Class="Window",
		LAnchorPoint=".5", LAnchorOffset="-230",
		TAnchorPoint="0", TAnchorOffset="0",
		RAnchorPoint=".5", RAnchorOffset="230",
		BAnchorPoint="0", BAnchorOffset="212",
		RelativeToClient="1", Template="Holo_Medium",
		Font="Default", Text="", TooltipType="OnCursor",
		BGColor="UI_WindowBGDefault", TextColor="UI_WindowTextDefault",
		Border="1", Picture="1", SwallowMouseClicks="1", Moveable="0", Escapable="0",
		Overlapped="1", TooltipColor="", Sprite="", UseTemplateBG="1", Tooltip="",
		Name="_Dialog",
		{ __XmlNode="Event", Function="OnWindowKeyEscape", Name="WindowKeyEscape", },
		{ -- Control
			__XmlNode="Control", Class="Window",
			LAnchorPoint="0", LAnchorOffset="0",
			TAnchorPoint="0", TAnchorOffset="0",
			RAnchorPoint="1", RAnchorOffset="0",
			BAnchorPoint="1", BAnchorOffset="-45",
			RelativeToClient="1", Template="Default",
			Font="Default", Text="", BGColor="UI_WindowBGDefault",
			TextColor="UI_WindowTextDefault",
			TooltipType="OnCursor", TooltipColor="",
			IgnoreMouse="1", NoClip="1",
			Name="ContentContainer",
			{ -- Container
				__XmlNode="Control", Class="Window",
				LAnchorPoint="0", LAnchorOffset="0",
				TAnchorPoint="0", TAnchorOffset="0",
				RAnchorPoint="1", RAnchorOffset="0",
				BAnchorPoint="0", BAnchorOffset="22",
				RelativeToClient="1", Template="Default",
				Font="CRB_Interface12_B", Text="",
				BGColor="UI_WindowBGDefault", TextColor="UI_WindowTextDefault",
				TooltipType="OnCursor", TooltipColor="",
				IgnoreMouse="1", NoClip="1", DT_CENTER="1", DT_WORDBREAK="1",
				Name="Text",
			},
		},
		{ -- Control
			__XmlNode="Control", Class="Window",
			LAnchorPoint="0", LAnchorOffset="-19",
			TAnchorPoint="1", TAnchorOffset="-45",
			RAnchorPoint="1", RAnchorOffset="15",
			BAnchorPoint="1", BAnchorOffset="15",
			RelativeToClient="1", Template="Default",
			Font="Default", Text="",
			BGColor="UI_WindowBGDefault", TextColor="UI_WindowTextDefault",
			TooltipType="OnCursor", TooltipColor="", IgnoreMouse="1", NoClip="1",
			Name="ButtonContainer",
		},
		{ -- Control
			__XmlNode="Control", Class="Window",
			LAnchorPoint="0", LAnchorOffset="-19",
			TAnchorPoint="0", TAnchorOffset="-19",
			RAnchorPoint="0", RAnchorOffset="55",
			BAnchorPoint="0", BAnchorOffset="55",
			RelativeToClient="1", Template="Default",
			Font="Default", Text="",
			BGColor="UI_WindowBGDefault", TextColor="UI_WindowTextDefault",
			TooltipType="OnCursor", TooltipColor="", Sprite="",
			Picture="1", IgnoreMouse="1", NoClip="1", Visible="0", HideInEditor="0",
			Name="IconContainer",
			{
				__XmlNode="Control", Class="Window",
				LAnchorPoint="0", LAnchorOffset="0",
				TAnchorPoint="0", TAnchorOffset="0",
				RAnchorPoint="1", RAnchorOffset="0",
				BAnchorPoint="1", BAnchorOffset="0",
				RelativeToClient="1", Template="Default",
				Font="Default", Text="",
				BGColor="ConTough", TextColor="UI_WindowTextDefault",
				TooltipType="OnCursor", TooltipColor="",
				Picture="1", IgnoreMouse="1", NewWindowDepth="1",
				Sprite="LibDialogSprites:IconFrame",
				Name="IconBorder",
				{ __XmlNode="Event", Function="OnGenerateTooltip", Name="GenerateTooltip", },
			},
			{ -- Control
				__XmlNode="Control", Class="Window",
				LAnchorPoint="0", LAnchorOffset="19",
				TAnchorPoint="0", TAnchorOffset="19",
				RAnchorPoint="1", RAnchorOffset="-19",
				BAnchorPoint="1", BAnchorOffset="-19",
				RelativeToClient="1", Template="Default",
				Font="Default", Text="",
				BGColor="UI_WindowBGDefault", TextColor="UI_WindowTextDefault",
				TooltipType="OnCursor", TooltipColor="",
				Picture="1", IgnoreMouse="1",
				Name="Icon",
			},
		},
		{
			__XmlNode="Control", Class="Button",
			Base="BK3:btnHolo_Close", Font="DefaultButton",
			ButtonType="PushButton", RadioGroup="",
			LAnchorPoint="1", LAnchorOffset="-65",
			TAnchorPoint="0", TAnchorOffset="27",
			RAnchorPoint="1", RAnchorOffset="-30",
			BAnchorPoint="0", BAnchorOffset="62",
			DT_VCENTER="1", DT_CENTER="1",
			BGColor="UI_BtnBGDefault", TextColor="UI_BtnTextDefault",
			NormalTextColor="UI_BtnTextDefault", PressedTextColor="UI_BtnTextDefault",
			FlybyTextColor="UI_BtnTextDefault", PressedFlybyTextColor="UI_BtnTextDefault",
			DisabledTextColor="UI_BtnTextDefault",
			TooltipType="OnCursor", Name="CloseButton", TooltipColor="", NoClip="1",
			{ __XmlNode="Event", Function="OnClose", Name="ButtonSignal", },
		},
	},
	{ -- Form
		__XmlNode="Form", Class="Button",
		Font="CRB_Button", Base="BK3:btnHolo_Red_Med",
		ButtonType="PushButton", RadioGroup="",
		LAnchorPoint="0", LAnchorOffset="0",
		TAnchorPoint="0", TAnchorOffset="0",
		RAnchorPoint="0", RAnchorOffset="128",
		BAnchorPoint="1", BAnchorOffset="0",
		DT_VCENTER="1", DT_CENTER="1",
		BGColor="UI_BtnBGDefault", TextColor="UI_BtnTextDefault",
		FlybyTextColor="UI_BtnTextDefault", PressedFlybyTextColor="UI_BtnTextDefault", DisabledTextColor="UI_BtnTextDefault",
		Text="", TooltipType="OnCursor", TooltipColor="",
		Name="_ButtonRed", Text ="",
		{ __XmlNode="Event", Function="OnButtonSignal", Name="ButtonSignal", },
	},
	{ -- Form
		__XmlNode="Form", Class="Button",
		Font="CRB_Button", Base="BK3:btnHolo_Blue_Med",
		ButtonType="PushButton", RadioGroup="",
		LAnchorPoint="0", LAnchorOffset="0",
		TAnchorPoint="0", TAnchorOffset="0",
		RAnchorPoint="0", RAnchorOffset="128",
		BAnchorPoint="1", BAnchorOffset="0",
		DT_VCENTER="1", DT_CENTER="1",
		BGColor="UI_BtnBGDefault", TextColor="UI_BtnTextDefault",
		FlybyTextColor="UI_BtnTextDefault", PressedFlybyTextColor="UI_BtnTextDefault", DisabledTextColor="UI_BtnTextDefault",
		Text="", TooltipType="OnCursor", TooltipColor="",
		Name="_ButtonBlue", Text ="",
		{ __XmlNode="Event", Function="OnButtonSignal", Name="ButtonSignal", },
	},
	{ -- Form
		__XmlNode="Form", Class="Button",
		Base="BK3:btnHolo_Radio_Small", Font="DefaultButton",
		ButtonType="Check", RadioGroup="",
		LAnchorPoint="0", LAnchorOffset="0",
		TAnchorPoint="0", TAnchorOffset="0",
		RAnchorPoint="1", RAnchorOffset="0",
		BAnchorPoint="0", BAnchorOffset="20",
		DT_VCENTER="1", DT_CENTER="0",
		BGColor="UI_BtnBGDefault", TextColor="UI_BtnTextDefault",
		NormalTextColor="UI_BtnTextDefault", PressedTextColor="UI_BtnTextDefault",
		FlybyTextColor="UI_BtnTextDefault", PressedFlybyTextColor="UI_BtnTextDefault",
		DisabledTextColor="UI_BtnTextDefault",
		TooltipType="OnCursor", TooltipColor="",
		Text="", DrawAsCheckbox="1", DT_WORDBREAK="1",
		Name="_CheckBox",
		{ __XmlNode="Event", Function="OnCheckToggle", Name="ButtonCheck", },
		{ __XmlNode="Event", Function="OnCheckToggle", Name="ButtonUncheck", },
	},
	{ -- Form
		__XmlNode="Form", Class="Window",
		LAnchorPoint="0", LAnchorOffset="0",
		TAnchorPoint="0", TAnchorOffset="0",
		RAnchorPoint="1", RAnchorOffset="0",
		BAnchorPoint="0", BAnchorOffset="24",
		Template="Default", RelativeToClient="1",
		Font="Default", Text="",
		BGColor="UI_WindowBGDefault", TextColor="UI_WindowTextDefault",
		TooltipType="OnCursor",TooltipColor="",
		Name="_EditGroup",
		{ -- Control
			__XmlNode="Control", Class="Window",
			LAnchorPoint="0", LAnchorOffset="0",
			TAnchorPoint="0", TAnchorOffset="2",
			RAnchorPoint="0", RAnchorOffset="40",
			BAnchorPoint="1", BAnchorOffset="-2",
			Template="Default", RelativeToClient="1",
			DT_VCENTER="1", DT_CENTER="0",
			Font="Default", Text="",
			BGColor="UI_WindowBGDefault", TextColor="UI_WindowTextDefault",
			TooltipType="OnCursor", TooltipColor="",
			Name="Label",
		},
		{ -- Control
			__XmlNode="Control", Class="Window",
			LAnchorPoint="0", LAnchorOffset="40",
			TAnchorPoint="0.5", TAnchorOffset="-10",
			RAnchorPoint="1", RAnchorOffset="0",
			BAnchorPoint="0.5", BAnchorOffset="10",
			Template="Default", RelativeToClient="1",
			Font="Default", Text="",
			BGColor="UI_WindowBGDefault", TextColor="UI_WindowTextDefault",
			TooltipType="OnCursor", TooltipColor="",
			Sprite="BK3:UI_BK3_Holo_InsetSimple", Picture="1", IgnoreMouse="1",
			Name="EditBoxFrame",
			{
				__XmlNode="Control", Class="EditBox",
				LAnchorPoint="0", LAnchorOffset="4",
				TAnchorPoint="0", TAnchorOffset="-1",
				RAnchorPoint="1", RAnchorOffset="-4",
				BAnchorPoint="1", BAnchorOffset="-1",
				Template="", RelativeToClient="1",
				Font="CRB_InterfaceMedium", Text="",
				BGColor="UI_WindowBGDefault", TextColor="UI_WindowTextDefault",
				TooltipType="OnCursor", TooltipColor="",
				DT_VCENTER="1", DT_CENTER="0", DT_WORDBREAK="1",
				Name="EditBox",
				{ __XmlNode="Event", Function="OnEditBoxChanged", Name="EditBoxChanged", },
				{ __XmlNode="Event", Function="OnEditBoxEscape", Name="EditBoxEscape", },
				{ __XmlNode="Event", Function="OnEditBoxReturn", Name="EditBoxReturn", },
			},
		},
	},
}

-----------------------------------------------------------------------
--- Upvalues
local error, pairs, tremove, tinsert = error, pairs, table.remove, table.insert


-----------------------------------------------------------------------
--- 
Lib.xmlDoc = XmlDoc.CreateFromTable(tXMLData)

Lib.tDelegates = Lib.tDelegates or {}
Lib.tQueuedDelegates = Lib.tQueuedDelegates or {}
Lib.tDelegateQueue = Lib.tDelegateQueue or {}

Lib.tActiveDialogs = Lib.tActiveDialogs or {}

-----------------------------------------------------------------------
--- Constants
local METHOD_USAGE_FORMAT = MAJOR .. ":%s() - %s"
local DEFAULT_DIALOG_WIDTH = 320
local DEFAULT_DIALOG_HEIGHT = 72

local DEFAULT_BUTTON_HEIGHT = 45
local DEFAULT_EDITBOX_HEIGHT = 24

local DEFAULT_CHECKBOX_HEIGHT = 20
local DEFAULT_ICON_SIZE = 36
local DEFAULT_ICON_PADDING = 50

local DEFAULT_DIALOG_TEXT_WIDTH = 360
local DIALOG_LINE_LENGTH = 44
local DIALOG_LINE_LENGTH_NOICON = DIALOG_LINE_LENGTH + 6
local DIALOG_LINE_HEIGHT = 22


local MAX_DIALOGS = 4
local MAX_BUTTONS = 3

-----------------------------------------------------------------------
--- Library Upvalues
local tDelegates = Lib.tDelegates
local tQueuedDelegates = Lib.tQueuedDelegates
local tDelegateQueue = Lib.tDelegateQueue

local tActiveDialogs = Lib.tActiveDialogs

-----------------------------------------------------------------------
--- Helper Functions.
local function _ProcessQueue()
	if #tActiveDialogs == MAX_DIALOGS then
		return
	end
	local tDelegate = tremove(tDelegateQueue)

	if not tDelegate then
		return
	end

	local tData = tQueuedDelegates[tDelegate]
	tQueuedDelegates[tDelegate] = nil

	if tData == "" then
		tData = nil
	end
	return Lib:Spawn(tDelegate, tData)
end

local function _ClearQueue(wndDialog)
	local nRemoveIndex
	for  nIndex = 1, #tActiveDialogs do
		if tActiveDialogs[nIndex] == wndDialog then
			nRemoveIndex = nIndex
		end
	end
	if not nRemoveIndex then
		return
	end
	tremove(tActiveDialogs, nRemoveIndex)
end

local function _CountLines(strFont, strText, nWidth)
	local nTextRows, nMaxSize, nLines = 0, 0, 0
	local tLines = strsplit("\n", strText)

	for _, strLine in pairs(tLines) do
		local nStrLength = Apollo.GetTextWidth(strFont, strLine)
		if nStrLength > nMaxSize then nMaxSize = nStrLength end
		nLines = nLines + 1
		nTextRows = nTextRows + math.ceil(nStrLength / nWidth)
	end

	return math.max(nTextRows,1), nMaxSize, nLines
end

local function _DestroyDialog(wndDialog)
	_ClearQueue(wndDialog)
	wndDialog:Destroy()
end

local function _Resort_Dialogs()
	if #tActiveDialogs < 1 then return end
	local nOldBottom = 0

	for nIndex = 1, #tActiveDialogs do
		wndDialog = tActiveDialogs[nIndex]

		local nLeft, nTop, nRight, nBottom = wndDialog:GetAnchorOffsets()
		nBottom = nBottom + nOldBottom - nTop
		wndDialog:SetAnchorOffsets(nLeft, nOldBottom, nRight, nBottom)
		nOldBottom = nBottom
	end
end

function Lib:OnWindowKeyEscape(wndHandler, wndControl)
	local tDelegate = wndControl:GetData().tDelegate
	if tDelegate.hideOnEscape then
		if tDelegate.OnCancel and not tDelegate.noCancelOnEscape then
			safecall(tDelegate.OnCancel, wndControl:GetData(), wndControl:GetData().tData)
		end
		_DialogOnHide(wndControl)
	end
end

function Lib:DialogOnShow(wndHandler, wndDialog)
	local tDelegate = wndDialog:GetData().tDelegate

	-- Function works but on 5/17/14 apparently the PlayUIWindowOpen sound is the sound of nothing
	Sound.Play(Sound.PlayUIWindowOpen)

	if tDelegate.OnShow then
		safecall(tDelegate.OnShow, wndDialog:GetData(), wndDialog:GetData().tData)
	end
end

local function _DialogOnHide(wndDialog)
	local tDelegate = wndDialog:GetData().tDelegate
	Sound.Play(Sound.PlayUIWindowClose)

	-- Remove VarChange_FrameCount event so it stops processing
	Apollo.RemoveEventHandler("VarChange_NextFrame",wndDialog:GetData())

	-- Required so Lib:ActiveDialog() will return false if called from code which is called from the delegate's OnHide
	_ClearQueue(wndDialog)

	if tDelegate.OnHide then
		safecall(tDelegate.OnHide, wndDialog:GetData(), wndDialog:GetData().tData)
	end
	_DestroyDialog(wndDialog)

	if #tDelegateQueue > 0 then
		local tDelegate
		repeat
			_Resort_Dialogs()
			tDelegate = _ProcessQueue()
		until not tDelegate
	else
		_Resort_Dialogs()
	end
end

function Lib:OnClose(wndHandler, wndControl, eMouseButton)
	local wndDialog = wndControl:GetParent()
	_DialogOnHide(wndDialog)
end

local function _Dialog_OnNextFrame(self)
	local tStoredData = self
	local wndDialog = self.wndDialog
	local tDelegate = tStoredData.tDelegate

	if tStoredData.nTimeRemaining and tStoredData.nTimeRemaining > 0 then
		local now = os.clock()
		local nElapsed = now - tStoredData.nLastTime
		tStoredData.nLastTime = now
	
		local nRemaining = tStoredData.nTimeRemaining - nElapsed

		if nRemaining <= 0 then
			tStoredData.nTimeRemaining = nil
			tStoredData.nLastTime = nil

			if tDelegate.OnCancel then
				safecall(tDelegate.OnCancel, tStoredData, tStoredData.tData, "timeout")
			end
			wndDialog:Show(false)
			_DialogOnHide(wndDialog)
			return
		end
		tStoredData.nTimeRemaining = nRemaining
	end

	if tDelegate.OnUpdate then
		safecall(tDelegate.OnUpdate, tStoredData, wndDialog:GetData(), nElapsed)
	end
end

local function CheckBox_GetValue(wndCheckBox)
	local wndDialog = wndCheckBox:GetParent():GetParent()
	local fnGetValue = wndCheckBox:GetData().GetValue

	if fnGetValue then
		local _, bChecked = safecall(fnGetValue, wndDialog:GetData(), wndDialog.tData)
		return bChecked
	end
end

function Lib:OnCheckToggle(wndHandler, wndCheckBox, eMouseButton)
	local wndDialog = wndCheckBox:GetParent():GetParent()
    local fnSetValue = wndCheckBox:GetData().SetValue

    if fnSetValue then
        safecall(fnSetValue, wndDialog:GetData(), CheckBox_GetValue(wndCheckBox), wndDialog.data)
    end
    wndCheckBox:SetChecked(CheckBox_GetValue(wndCheckBox))
end

local function _AddCheckBox(wndParent, nIndex)
	local tStoredData = wndParent:GetData()
	local wndCheckBox = Apollo.LoadForm(Lib.xmlDoc, "_CheckBox", wndParent:FindChild("ContentContainer"), Lib)
	wndCheckBox:SetName(("%sChk%d"):format(wndParent:GetName(),nIndex))
	-- Do additional Checkbox Setup here if any

	wndCheckBox:SetData(tStoredData.tDelegate.checkboxes[nIndex])
	wndCheckBox:SetText(wndCheckBox:GetData().label or "")
	wndCheckBox:SetCheck(CheckBox_GetValue(wndCheckBox))
	local nTextRows = _CountLines("DefaultButton", wndCheckBox:GetText(), wndParent:FindChild("ContentContainer"):GetWidth())
	local nTextLeft, nTextTop, nTextRight, nTextBottom = wndCheckBox:GetAnchorOffsets()
	wndCheckBox:SetAnchorOffsets(nTextLeft, nTextTop, nTextRight, nTextBottom + (DEFAULT_CHECKBOX_HEIGHT * (nTextRows - 1)))

	return wndCheckBox
end

--TestFunc( wndHandler, wndControl, strText )
function Lib:OnEditBoxReturn(wndHandler, wndEditBox, strText)
	-- Yes it really is 4 parents up to the dialog window...
	local wndDialog = wndEditBox:GetParent():GetParent():GetParent():GetParent()
	local fnOnReturn = wndEditBox:GetData().OnReturn

	if fnOnReturn then
		safecall(fnOnReturn, wndDialog:GetData(), wndDialog.tData, strText)
	end
end

function Lib:OnEditBoxEscape(wndHandler, wndEditBox, strText)
	-- Yes it really is 4 parents up to the dialog window...
	local wndDialog = wndEditBox:GetParent():GetParent():GetParent():GetParent()
	local fnOnEscape = wndEditBox:GetData().OnEscape

	if fnOnEscape then
		safecall(fnOnEscape, wndDialog:GetData(), wndDialog.tData, strText)
	end
end

function Lib:OnEditBoxChanged(wndHandler, wndEditBox, strText)
	-- Yes it really is 4 parents up to the dialog window...
	local wndDialog = wndEditBox:GetParent():GetParent():GetParent():GetParent()
	local fnOnTextChanged = wndEditBox:GetData().OnTextChanged

	if fnOnTextChanged then
		safecall(fnOnTextChanged, wndDialog:GetData(), wndDialog.tData, strText)
	end
end

local function _AddEditBox(wndParent, nIndex)
	local tStoredData = wndParent:GetData()
	local wndEditGroup = Apollo.LoadForm(Lib.xmlDoc, "_EditGroup", wndParent:FindChild("ContentContainer"), Lib)
	wndEditGroup:SetName(("%sEdit%d"):format(wndParent:GetName(),nIndex))
	-- Do additional Editbox Setup here

	local wndLabel = wndEditGroup:FindChild("Label")
	local wndEditBox = wndEditGroup:FindChild("EditBox")
	local wndEditBoxContainer = wndEditBox:GetParent()

	local tTemplate = tStoredData.tDelegate.editboxes[nIndex]
	wndEditGroup:SetData({order = tTemplate.order})
	wndEditBox:SetData(tTemplate)
	if tTemplate.label and tTemplate.label ~= "" then
		local nAvailableWidth = wndEditGroup:GetWidth() / 2

		local _, nMaxLength, nLines = _CountLines("Default", tTemplate.label, nAvailableWidth)
		local nLeftLabel, nTopLabel, nRightLabel, nBottomLabel = wndLabel:GetAnchorOffsets()
		nRightLabel = nLeftLabel + math.min(Apollo.GetTextWidth("Default", tTemplate.label), nMaxLength)
		wndLabel:SetAnchorOffsets(nLeftLabel, nTopLabel, nRightLabel, nBottomLabel)
		wndLabel:SetText(tTemplate.label or "")

		local nLeft, nTop, nRight, nBottom = wndEditBoxContainer:GetAnchorOffsets()
		wndEditBoxContainer:SetAnchorOffsets(nRightLabel + 4, nTop, nRight, nBottom)
		local nLeft, nTop, nRight, nBottom = wndEditGroup:GetAnchorOffsets()
		wndEditGroup:SetAnchorOffsets(nLeft, nTop, nRight, nBottom + (DEFAULT_EDITBOX_HEIGHT * (nLines - 1)))

		local nSizeDiff = 0
		if nMaxLength > nAvailableWidth then
			-- Extend the size of the group
			nSizeDiff = nMaxLength - nAvailableWidth
		end
		local nLeft, nTop, nRight, nBottom = wndParent:GetAnchorOffsets()
		wndParent:SetAnchorOffsets(nLeft - nSizeDiff, nTop, nRight + nSizeDiff, nBottom)
	else
		wndLabel:Show(false)
		local nLeft, nTop, nRight, nBottom = wndEditBoxContainer:GetAnchorOffsets()
		wndEditBoxContainer:SetAnchorOffsets(0,nTop,nRight,nBottom)
	end

	if tTemplate.autoFocus then
		wndEditBox:SetFocus()
	end

	return wndEditGroup
end

function Lib:OnButtonSignal(wndHandler, wndButton, eMouseButton)
	local wndDialog = wndButton:GetParent():GetParent()
	local bStayOpen = false
	local fnOnClick = wndButton:GetData().OnClick

	if fnOnClick then
		_, bStayOpen = safecall(fnOnClick, wndDialog:GetData(), wndDialog.tData, "clicked")
	end

	if not bStayOpen then
		wndDialog:Show(false)
		_DialogOnHide(wndDialog)
	end
end

local function _AddButton(wndParent, nIndex)
	local tStoredData = wndParent:GetData()
	local tButtonData = tStoredData.tDelegate.buttons[nIndex]
	local wndButton
	if tButtonData.color and tButtonData.color:lower() == "red" then
		wndButton = Apollo.LoadForm(Lib.xmlDoc, "_ButtonRed", wndParent:FindChild("ButtonContainer"), Lib)
	else -- Default - Blue
		wndButton = Apollo.LoadForm(Lib.xmlDoc, "_ButtonBlue", wndParent:FindChild("ButtonContainer"), Lib)
	end

	-- Do additional Button Setup here
	wndButton:SetName(("%sBtn%d"):format(wndParent:GetName(),nIndex))
	wndButton:SetData(tButtonData)
	wndButton:SetText(tButtonData.text or "?!?")
	return wndButton
end

local tAlignOpts = {
	["left"] = { ["DT_CENTER"] = false, ["DT_RIGHT"] = false, },
	["center"] = { ["DT_CENTER"] = true, ["DT_RIGHT"] = false, },
	["right"] = { ["DT_CENTER"] = false, ["DT_RIGHT"] = true, },
}

local function _SetText(wndDialog, strText)
	local wndText = wndDialog:FindChild("Text")
	wndText:SetText(strText or "")
	local tStoredData = wndDialog:GetData()
	local tAlignSettings = tStoredData.textAlign and tAlignOpts[tStoredData.textAlign:lower()] or nil
	if tAlignSettings then
		for strSetting, bValue in pairs(tAlignSettings) do
			wndText:SetTextFlags(strSetting, bValue)
		end
	end
	local nTextRows = _CountLines("CRB_Interface12_B", wndText:GetText(), wndDialog:FindChild("ContentContainer"):GetWidth())
	local nTextLeft, nTextTop, nTextRight, nTextBottom = wndText:GetAnchorOffsets()
	wndText:SetAnchorOffsets(nTextLeft, nTextTop, nTextRight, nTextBottom + (DIALOG_LINE_HEIGHT * (nTextRows - 1)))
end

function Lib:OnGenerateTooltip(wndHandler, wndControl, eToolTipType, x, y)
	if wndHandler ~= wndControl then return end
	local tItemData = wndHandler:GetData()
	if tItemData ~= nil and tItemData.itemInstance ~= nil then
		Tooltip.GetItemTooltipForm(self, wndControl, tItemData, { bPrimary = true, bSelling = false })
	end
end

local function _SetIcon(wndDialog, oIcon)
	local wndIContainer = wndDialog:FindChild("IconContainer")
	local wndIcon = wndDialog:FindChild("Icon")
	local nSizeChange = wndIContainer:IsVisible() and -DEFAULT_ICON_PADDING or DEFAULT_ICON_PADDING
	local bStateChange = false
	if oIcon == nil and (nSizeChange < 0) then
		wndIContainer:SetData(nil)
		wndDialog:FindChild("IconBorder"):SetBGColor("ConTough")
		wndIcon:SetSprite("")
		bStateChange = true
	elseif oIcon.GetIcon then
		wndIContainer:SetData(oIcon)
		wndDialog:FindChild("IconBorder"):SetBGColor(ktQualityLookup[oIcon:GetItemQuality()])
		wndIcon:SetSprite(oIcon:GetIcon())
		bStateChange = true
	elseif type(oIcon) == "string" then
		wndIContainer:SetData(nil)
		wndDialog:FindChild("IconBorder"):SetBGColor("ConTough")
		wndIcon:SetSprite(oIcon)
		bStateChange = true
	end
	if bStateChange then
		wndIContainer:Show(nSizeChange > 0)
		
		local nLeft, nTop, nRight, nBottom = wndDialog:FindChild("ContentContainer"):GetAnchorOffsets()
		wndDialog:FindChild("ContentContainer"):SetAnchorOffsets(nLeft + nSizeChange,nTop,nRight,nBottom)
	end
end

local function SortByOrder(a,b)
	return (a:GetData().order or 0) < (b:GetData().order or 0)
end

local function BuildStoredData()
	local tNewStoredData = setmetatable({}, { __index = function(tbl, key) return tbl.tDelegate[key] end })
	tNewStoredData.SetTimeRemaining = function(self, nTime)
		if not self.nTimeRemaining then
			Apollo.RemoveEventHandler("VarChange_FrameCount", self)
			self.OnNextFrame = _Dialog_OnNextFrame
			self.nLastTime = os.clock()
			Apollo.RegisterEventHandler("VarChange_FrameCount", "OnNextFrame", self)
		end
		self.nTimeRemaining = nTime
	end
	tNewStoredData.SetIcon = function(self, oIcon)
		_SetIcon(self.wndDialog, oIcon)
	end
	tNewStoredData.SetText = function(self, strText)
		_SetText(self.wndDialog, strText)
		Lib:Resize(self.wndDialog)
		_Resort_Dialogs()
	end
	tNewStoredData.ShowCloseButton = function(self, bShow)
		self.wndDialog:FindChild("CloseButton"):Show(bShow == true)
	end
	tNewStoredData.Resize = function(self)
		Lib:Resize(self.wndDialog)
	end
	return tNewStoredData
end

local function _BuildDialog(tDelegate, tData)
	if #tActiveDialogs == MAX_DIALOGS then
		if not tQueuedDelegates[tDelegate] then
			tDelegateQueue[#tDelegateQueue + 1] = tDelegate
			tQueuedDelegates[tDelegate] = tData or ""
		end
		return
	end

	local wndDialog = Apollo.LoadForm(Lib.xmlDoc, "_Dialog", nil, Lib)
	wndDialog:SetName(("Dlg%d"):format(#tActiveDialogs + 1))

	-- Generate Dialog
	local nRight, nTop = DEFAULT_DIALOG_WIDTH / 2, 0
	local nLeft, nBottom = -1 * nRight, nTop + DEFAULT_DIALOG_HEIGHT

	wndDialog:SetAnchorOffsets(nLeft, nTop, nRight, nBottom)

	local tStoredData = BuildStoredData()
	tStoredData.tDelegate = tDelegate
	tStoredData.tData = tData
	tStoredData.wndDialog = wndDialog
	wndDialog:SetData(tStoredData)

	wndDialog:AddEventHandler("WindowShow", "DialogOnShow", Lib)

	if tDelegate.noCloseButton then
		tStoredData:ShowCloseButton(false)
	end

	if tDelegate.duration then
		-- method handles setting up the timer
		tStoredData:SetTimeRemaining(tDelegate.duration)
	elseif tDelegate.OnNextFrame then
		-- Manual setup as there is no duration of the dialog
		tStoredData.OnNextFrame = _Dialog_OnNextFrame
		Apollo.RegisterEventHandler("VarChange_FrameCount", "OnNextFrame", tStoredData)
	end

	if tDelegate.icon then
		_SetIcon(wndDialog, tDelegate.icon)
	end

	_SetText(wndDialog, tDelegate.text)
	-- Text is always on the top
	wndDialog:FindChild("Text"):SetData({ order = -1 })
	
	if tDelegate.buttons and #tDelegate.buttons > 0 then
		tStoredData.tButtons = {}

		for nIndex = 1, MAX_BUTTONS do
			local tButton = tDelegate.buttons[nIndex]

			if not tButton then
				break
			end

			if tButton.text then
				tinsert(tStoredData.tButtons, _AddButton(wndDialog, nIndex))
			end
		end

		-- Arrange buttons Centered on Form
		wndDialog:FindChild("ButtonContainer"):ArrangeChildrenHorz(1, SortByOrder)
	end

	if tDelegate.editboxes and #tDelegate.editboxes > 0 then
		tStoredData.tEditBoxes = {}

		for nIndex = 1, #tDelegate.editboxes do
			tinsert(tStoredData.tEditBoxes, _AddEditBox(wndDialog, nIndex))
		end
	end

	if tDelegate.checkboxes and #tDelegate.checkboxes > 0 then
		tStoredData.tCheckBoxes = {}

		for nIndex = 1, #tDelegate.checkboxes do
			tinsert(tStoredData.tCheckBoxes, _AddCheckBox(wndDialog, nIndex))
		end
	end
	wndDialog:FindChild("ContentContainer"):ArrangeChildrenVert(1, SortByOrder)
	return wndDialog
end

-----------------------------------------------------------------------
--- Library Methods
-----------------------------------------------------------------------
--- Register a new dialog delegate.
-- @name LibDialog-1.0:Register
-- @class function
-- @paramsig strDelegateName, tDelegate
-- @param strDelegateName The name the delegate table will be registered under.
-- @param tDelegate The delegate table definition
function Lib:Register(strDelegateName, tDelegate)

	if type(strDelegateName) ~= "string" or strDelegateName == "" then
		error(METHOD_USAGE_FORMAT:format("Register", "strDelegateName must be a non-empty string"), 2)
	end

	if type(tDelegate) ~= "table" then
		error(METHOD_USAGE_FORMAT:format("Register", "delegate must be a table"), 2)
	end
	tDelegates[strDelegateName] = tDelegate
end

local function _FindDelegate(strMethodName, reference)
	local refType = type(reference)

	if reference == "" or (refType ~= "string" and refType ~= "table") then
		error(METHOD_USAGE_FORMAT:format(strMethodName, "reference must be a delegate table or a non-empty string"), 3)
	end

	local tDelegate
	if refType == "string" then
		if not tDelegates[reference] then
			error(METHOD_USAGE_FORMAT:format(strMethodName, ("\"%s\" does not match a registered delegate"):format(reference)),3)
		end
		tDelegate = tDelegates[reference]
	else
		tDelegate = reference
	end
	return tDelegate
end

--- Spawns a dialog from a delegate reference.
-- @name LibDialog-1.0:Spawn
-- @class function
-- @paramsig reference[, data]
-- @param reference The delegate to be used for the spawned dialog. Can be either a string, in which case the delegate must be registered, or a delegate definition table.
-- @param tData Additional data to be passed on to the resultant dialog.
function Lib:Spawn(reference, tData)
	local tDelegate = _FindDelegate("Spawn", reference)

	-- Check delegate conditionals before building.
	if GameLib.GetPlayerUnit():IsDead() and not tDelegate.showWhileDead then
		if tDelegate.OnCancel then
			tDelegate.OnCancel()
		end
	end

	-- Add Cinematic detection?

	if tDelegate.bIsExclusive then
		for nIndex = 1, #tActiveDialogs do
			local wndDialog = tActiveDialogs[nIndex]
			local tStoredData = wndDialog:GetData()

			if tStoredData.tDelegate.isExclusive then
				if tStoredData.tDelegate.OnCancel then
					safecall(tStoredData.tDelegate.OnCancel, tStoredData, tStoredData.tData, "override")
				end
				wndDialog:Show(false)
				_DialogOnHide(wndDialog)
			end
		end
	end
	local tCancelList = tDelegate.cancelsOnSpawn

	if tCancelList then
		for nIndex = 1, #tCancelList do
			local strDelegateName = tCancelList[nIndex]
			local tDelegateToCancel = tDelegates[strDelegateName]

			if tDelegateToCancel then
				for nIndex = 1, #tActiveDialogs do
					local wndDialog = tActiveDialogs[nIndex]
					local tStoredData = wndDialog:GetData()

					if tStoredData.tDelegateToCancel == tDelegateToCancel then
						if tStoredData.tDelegate.OnCancel then
							safecall(tStoredData.tDelegate.OnCancel, tStoredData, tStoredData.tData, "override")
						end
						wndDialog:Show(false)
						_DialogOnHide(wndDialog)
					end
				end
			else
				error(("\"%s\" does not match a registered delegate - unable to cancel"):format(strDelegateName), 2)
			end
		end
	end
	local wndDialog = self:ActiveDialog(reference, tData)

	if wndDialog then
		local tStoredData = wndDialog:GetData()
		local tDelegate = tStoredData.tDelegate

		if not tDelegate.noCancelOnReuse and tDelegate.OnCancel then
			safecall(tDelegate.OnCancel, tStoredData, tStoredData.tData, "override")
		end
		wndDialog:Show(false)
		_DialogOnHide(wndDialog)
	end

	-- Build new Dialog
	wndDialog = _BuildDialog(tDelegate, tData)

	if not wndDialog then
		return
	end

	local tStoredData = wndDialog:GetData()
	if tStoredData.sound then
		local nSound = tStoredData.sound
		if type(nSound) == "string" then
			nSound = Sound[nSound]
		end
		if type(nSound) ~= "number" then
			if type(tStoredData.sound) == "string" then
				error(("\"%s\" does not match a Sound enum"):format(tStoredData.sound), 2)
			end
		end
		Sound.Play(nSound)
	end

	if #tActiveDialogs > 0 then
		-- Position other Dialogs below other dialog then resize width/bottom edge
		local nPrevLeft, nPrevTop, nPrevRight, nPrevBottom = tActiveDialogs[#tActiveDialogs]:GetAnchorOffsets()
		local nLeft, nTop, nRight, nBottom = wndDialog:GetAnchorOffsets()
		wndDialog:SetAnchorOffsets(nLeft, nPrevBottom, nRight, nPrevBottom + nBottom - nTop)
	end
	tActiveDialogs[#tActiveDialogs + 1] = wndDialog
	wndDialog:Show(true)

	self:Resize(wndDialog)
	return wndDialog
end

--- Determines whether or not a specific dialog is currently active.
-- @name LibDialog-1.0:ActiveDialog
-- @class function
-- @paramsig reference[, data]
-- @param reference The delegate criteria for the dialog being targeted.  Can be either a string, in which case the delegate must be registered, or a delegate definition table.
-- @param data Additional data to be used as further criteria to determine if the target dialog is active - this would be the same data used to spawn the dialog.
function Lib:ActiveDialog(reference, tData)
	local tDelegate = _FindDelegate("ActiveDialog", reference)

	for nIndex = 1, #tActiveDialogs do
		local tStoredData = tActiveDialogs[nIndex]:GetData()

		if tStoredData.tDelegate == tDelegate and (not tData or tStoredData.tData == tData) then
			return tActiveDialogs[nIndex]
		end
	end
end

--- Dismisses a specific dialog.
-- @name LibDialog-1.0:Dismiss
-- @class function
-- @paramsig reference[, data]
-- @param reference The delegate criteria for the dialog being targeted.  Can be either a string, in which case the delegate must be registered, or a delegate definition table.
-- @param data Additional data to be used as further criteria to identify the target dialog - this would be the same data used to spawn the dialog.
function Lib:Dismiss(reference, tData)
	local tDelegate = _FindDelegate("Dismiss", reference)

	for nIndex = 1, #tActiveDialogs do
		local tStoredData = tActiveDialogs[nIndex]:GetData()

		if tStoredData.tDelegate == tDelegate and (not tData or tStoredData.tData == tData) then
			tActiveDialogs[nIndex]:Show(false)
			_DialogOnHide(tActiveDialogs[nIndex])
		end
	end
end

function Lib:Resize(wndDialog)
	local tStoredData = wndDialog:GetData()
	local tDelegate = tStoredData.tDelegate

	local nWidth = tDelegate.width or wndDialog:GetWidth()
	local nHeight = 100 + (tDelegate.height or 0)

	local nLeft, nTop, nRight, nBottom = wndDialog:GetAnchorOffsets()
	
	-- Static size ignores widgets for resizing purposes.
	if tDelegate.staticSize then
		if nWidth > 0 then
			local nDiff = nWidth/2
			nLeft = -1 * nDiff
			nRight = nDiff
		end

		wndDialog:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight)
		return
	end

	if tStoredData.tButtons and #tStoredData.tButtons > 0 then
		nHeight = nHeight + DEFAULT_BUTTON_HEIGHT

		if #tStoredData.tButtons == MAX_BUTTONS then
			nWidth = 460
		end
	end

	if tStoredData.tEditBoxes and #tStoredData.tEditBoxes > 0 then

		for nIndex = 1, #tStoredData.tEditBoxes do
			local wndEditGroup = tStoredData.tEditBoxes[nIndex]
			nHeight = nHeight + wndEditGroup:GetHeight()
		end
	end

	if tStoredData.tCheckBoxes and #tStoredData.tCheckBoxes then
		for nIndex = 1, #tStoredData.tCheckBoxes do
			local wndCheckBox = tStoredData.tCheckBoxes[nIndex]
			nHeight = nHeight + wndCheckBox:GetHeight()
		end
	end

	nHeight = nHeight + wndDialog:FindChild("Text"):GetHeight()

	nRight = nWidth/2
	nLeft = -1 * nRight
	nBottom = nTop + nHeight
	wndDialog:SetAnchorOffsets(nLeft, nTop, nRight, nBottom)
	wndDialog:FindChild("ButtonContainer"):ArrangeChildrenHorz(1, SortByOrder)
	wndDialog:FindChild("ContentContainer"):ArrangeChildrenVert(1, SortByOrder)
end

function Lib:OnLoad()
	local strPrefix = Apollo.GetAssetFolder()
	local tToc = XmlDoc.CreateFromFile("toc.xml"):ToTable()
	for k,v in ipairs(tToc) do
		local strPath = string.match(v.Name, "(.*)[\\/]LibDialog")
		if strPath ~= nil and strPath ~= "" then
			strPrefix = strPrefix .. "\\" .. strPath .. "\\"
			break
		end
	end
	local tSpritesXML = {
		__XmlNode = "Sprites",
		{ -- Form
			__XmlNode="Sprite", Name="IconFrame", Cycle="1",
			{
				__XmlNode="Frame", Texture= strPrefix .. "IconFrame.tga",
				x0="0", x1="0", x2="0", x3="32", x4="56", x5="88",
				y0="0", y1="0", y2="0", y3="32", y4="56", y5="88",
				HotspotX="0", HotspotY="0", Duration="1.000",
				StartColor="white", EndColor="white",
			},
		},
	}
	local xmlSprites = XmlDoc.CreateFromTable(tSpritesXML)
	Apollo.LoadSprites(xmlSprites)
	for k,v in pairs(Item.CodeEnumItemQuality) do
		ktQualityLookup[v] = "ItemQuality_" .. k
	end
end
function Lib:OnDependencyError(strDep, strError) return false end

Apollo.RegisterPackage(Lib, MAJOR, MINOR, {})