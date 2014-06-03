local EPGP = Apollo.GetAddon("EPGP")
local mod = EPGP:NewModule("whisper")

local tSenderMap = {}

function mod:OnChatMessage(channelCurrent, tMessage)
	if GameLib.GetPlayerUnit() == nil or tMessage.bSelf or not GroupLib.InRaid() then return end
	if tMessage.strSender == nil then return end
	local eChannel = channelCurrent:GetType()
	if not (eChannel == ChatSystemLib.ChatChannel_Whisper or eChannel == ChatSystemLib.ChatChannel_AccountWhisper) then return end

	if #tMessage.arMessageSegments == 0 or #tMessage.arMessageSegments > 1 then return end
	local strMessage = tMessage.arMessageSegments[1].strText
	if strMessage:sub(1,12):lower() ~= "epgp standby" then return end

	local strMember = msg:sub(13):match("[^ ]+")
	if strMember then
		-- http://lua-users.org/wiki/LuaUnicode
		local firstChar, offset = member:match("([%z\1-\127\194-\244][\128-\191]*)()")
		strMember = firstChar:upper()..member:sub(offset):lower()
	else
		strMember = tMessage.strSender
	end

	tSenderMap[strMember] = tMessage.strSender

	if not EPGP:GetEPGP(strMember) then
		ChatSystemLib.Command(string.format("/w %s %s", strSender,
			L["%s is not eligible for EP awards"]:format(strMember)))
	elseif EPGP:IsMemberInAwardList(strMember) then
		ChatSystemLib.Command(string.format("/w %s %s", strSender,
			L["%s is already in the award list"]:format(strMember)))
	else
		EPGP:SelectMember(strMember)
		ChatSystemLib.Command(string.format("/w %s %s", strSender,
			L["%s is added to the award list"]:format(strMember)))
	end
end

local function AnnounceMedium()
	local medium = mod.db.profile.medium
	if medium ~= "NONE" then
		return medium
	end
end

local function SendNotifiesAndClearExtras(
		strEventName, tNames, strReason, nAmount,
		tExtrasAwarded, strExtrasReason, nExtrasAmount)
	local medium = AnnounceMedium()
	if medium then
		EPGP:GetModule("Annouce"):AnnounceTo(
			medium,
			L["If you want to be on the award list but you are not in the raid, you need to whisper me: 'epgp standby' or 'epgp standby <name>' where <name> is the toon that should receive awards"])
	end

	if tExtrasAwarded then
		for strMember, _ in pairs(tExtrasAwarded) do
			local strSender = tSenderMap[strMember]
			if strSender then
				ChatSystemLib.Command(string.format("/w %s %s", strSender,
					L["%+d EP (%s) to %s"]:format(nExtrasAmount, strExtrasReason, strMember)))
				EPGP:DeSelectMember(strMember)
				ChatSystemLib.Command(string.format("/w %s %s", strSender,
					L["%s is now removed from the award list"]:format(strMember)))
			end
			tSenderMap[strMember] = nil
		end
	end
end

mod.dbDefaults = {
	profile = {
		enabled = false,
		medium = "GUILD"
	}
}

function mod:OnInitialize()
	self.db = EPGP.db:RegisterNamespace("whisper", mod.dbDefaults)
end

mod.optionsName = L["Whisper"]
mod.optionsDesc = L["Standby whipsers in raid"]
mod.optionsArgs = {
	help = {
		order = 1,
		type = "description",
		name = L["Automatic handling of the standby list through whispers when in raid. When this is enabled, the standby list is cleared after each reward."],
	},
	medium = {
		order = 10,
		type = "select",
		name = L["Announce medium"],
		desc = L["Sets the announce medium EPGP will use to announce EPGP actions."],
		values = {
			["GUILD"] = CHAT_MSG_GUILD,
			["CHANNEL"] = CUSTOM,
			["NONE"] = NONE,
		},
	}
}

function mod:OnEnable()
	Apollo.RegisterEventHandler("ChatMessage", "OnChatMessage", self)
	EPGP.RegisterCallback(self, "MassEPAward", SendNotifiesAndClearExtras)
	EPGP.RegisterCallback(self, "StartRecurringAward", SendNotifiesAndClearExtras)
end

function mod:OnDisable()
	Apollo.RemoveEventHandler("ChatMessage", self)
	EPGP.UnregisterAllCallbacks(self)
end