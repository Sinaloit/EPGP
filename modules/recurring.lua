local EPGP = Apollo.GetAddon("EPGP")
local mod = EPGP:NewModule("recurring")
local L = EPGP.L
local DLG, glog, GS, callbacks

local ceil = math.ceil
local tTimer

function mod:OnTimer()
	if not EPGP.db.profile then return end
	local tConfig = EPGP.db.profile
	local now = os.clock()
	if now > tConfig.nNextAwardTime and GS:IsCurrentState() then
		EPGP:IncMassEPBy(tConfig.strNextAwardReason, tConfig.nNextAwardAmount)
		tConfig.nNextAwardTime =
			tConfig.nNextAwardTime + tConfig.nRecurringEPPeriodMins * 60
	end
	callbacks:Fire("RecurringAwardUpdate",
					tConfig.strNextAwardReason,
					tConfig.nNextAwardAmount,
					tConfig.nNextAwardTime - now)
end

function mod:StartRecurringEP(strReason, nAmount)
	local tConfig = EPGP.db.profile
	if tConfig.nNextAwardTime then
		return false
	end

	tConfig.strNextAwardReason = strReason
	tConfig.nNextAwardAmount = nAmount
	tConfig.nNextAwardTime = os.clock() + tConfig.nRecurringEPPeriodMins * 60

	callbacks:Fire("StartRecurringAward",
					strReason, nAmount,
					tConfig.nRecurringEPPeriodMins)

	if tTimer then
		tTimer:Start()
	else
		tTimer = ApolloTimer.Create(1.0, true, "OnTimer", self)
	end

	return true
end

function mod:ResumeRecurringEP()
	local tConfig = EPGP.db.profile
	local nPeriodSecs = tConfig.nRecurringEPPeriodMins * 60
	local nTimeout = tConfig.nNextAwardTime + nPeriodSecs - os.clock()

	local text = L["Do you want to resume recurring award (%s) %d EP/%s?"]:format(
					tConfig.strNextAwardReason,
					tConfig.nNextAwardAmount,
					mod:RecurringEPPeriodString())
	DLG:Spawn("EPGP_RECURRING_RESUME", {text = text, timeout = nTimeout})
end

function mod:CanResumeRecurringEP()
	local tConfig = EPGP.db.profile
	local now = os.clock()
	if not tConfig.nNextAwardTime then return false end

	local nPeriodSecs = tConfig.nRecurringEPPeriodMins * 60
	local nLastAwardTime = tConfig.nNextAwardTime - nPeriodSecs
	local nNextNextAward = tConfig.nNextAwardTime + nPeriodSecs
	if nLastAwardTime < now and now < nNextNextAward then
		return true
	end
	return false
end

function mod:CancelRecurringEP()
	DLG:Dismiss("EPGP_RECURRING_RESUME")
	local tConfig = EPGP.db.profile
	tConfig.strNextAwardReason = nil
	tConfig.nNextAwardAmount = nil
	tConfig.nNextAwardTime = nil
	if tTimer then
		tTimer:Stop()
	end
end

function mod:StopRecurringEP()
	self:CancelRecurringEP()

	callbacks:Fire("StopRecurringAward")
	return true
end

function mod:RunningRecurringEP()
	local tConfig = EPGP.db.profile
	return not not tConfig.nNextAwardTime
end

function mod:RecurringEPPeriodMinutes(nValue)
	local tConfig = EPGP.db.profile
	if nValue == nil then
		return tConfig.nRecurringEPPeriodMins
	end
	tConfig.nRecurringEPPeriodMins = nValue
end

local function SecondsToTimeAbbrev(nTime)
	local tempTime
	if nTime >= 86400 then
		tempTime = ceil(nTime / 86400)
		return "%dd", tempTime
    elseif nTime >= 3600 then
    	tempTime = ceil(nTime / 3600)
    	return "%dh", tempTime
    elseif nTime >= 60 then
    	tempTime = ceil(nTime / 60)
    	return "%dm", tempTime
    else
    	return "%ds", nTime
    end
end

function mod:RecurringEPPeriodString()
	local tConfig = EPGP.db.profile
	local fmt, tValue = SecondsToTimeAbbrev(tConfig.nRecurringEPPeriodMins * 60)
	return fmt:format(tValue)
end

function mod:OnEnable()
	if self:CanResumeRecurringEP() then
		self:ResumeRecurringEP()
	else
		self:CancelRecurringEP()
	end
end

function mod:OnDisable()
	EPGP.db.profile.strNextAwardReason = nil
	EPGP.db.profile.nNextAwardAmount = nil
	EPGP.db.profile.nNextAwardTime = nil
	if tTimer then
		tTimer:Stop()

		tTimer = nil
	end
end

function mod:OnInitialize()
	GS = Apollo.GetPackage("LibGuildStorage-1.0").tPackage
	DLG, glog, callbacks = EPGP.DLG, EPGP.glog, EPGP.callbacks
	DLG:Register("EPGP_RECURRING_RESUME", {
		buttons = {
			{
				text = Apollo.GetString("CRB_Yes"),
				OnClick = function(settings, data, reason)
					callbacks:Fire("ResumeRecurringAward",
								EPGP.db.profile.strNextAwardReason,
								EPGP.db.profile.nNextAwardAmount,
								EPGP.db.profile.nRecurringEPPeriodMins)
					if tTimer then
						tTimer:Start()
					else
						tTimer = ApolloTimer.Create(1.0, true, "OnTimer", self)
					end
				end,
			},
			{
				text = Apollo.GetString("CRB_No"),
				OnClick = function(settings, data, reason)
					mod:StopRecurringEP()
				end,
			},
		},
		OnShow = function(settings, data)
			settings:SetText(data.text)
			settings:SetTimeRemaining(data.timeout)
		end,
		OnCancel = function(settings, data, reason)
			if reason ~= "override" then
				mod:StopRecurringEP()
			end
		end,
		noCloseButton = true,
		hideOnEscape = true,
		showWhileDead = true,
	})
end