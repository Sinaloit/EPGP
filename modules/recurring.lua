local EPGP = Apollo.GetAddon("EPGP")
local mod = EPGP:NewModule("recurring")
local L = EPGP.L
local DLG, glog, GS

local nTimeout = 0
local nLastTime = 0
local tTimer

function mod:OnTimer()
	if not EPGP.db.profile then return end
	local tConfig = EPGP.db.profile
	local now = os.clock()
	local nElapsed = nLastTime - now
	nLastTime = now
	if now > tConfig.nNextAwardTime and GS:IsCurrentState() then
		EPGP:IncMassEPBy(tConfig.strNextAwardReason, tConfig.nNextAwardAmount)
		tConfig.nNextAwardTime =
			tConfig.nNextAwardTime + tConfig.nRecurringEPPeriodMins * 60
	end
	nTimeout = nTimeout + nElapsed
	if fTimeout > 0.5 then
		callbacks:Fire("RecurringAwardUpdate",
						tConfig.strNextAwardReason,
						tConfig.nNextAwardAmount,
						tConfig.nNextAwardTime - now)
		nTimeout = 0
	end
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
					EPGP:RecurringEPPeriodString())
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

function SecondsToTimeAbbrev(nTime)
    if nTime <= 0 then
        return ""
    elseif nTime < 3600  then
        return "%d:%02d", floor(nTime/60), nTime%60
    else
        return "%dh%2dm", floor(nTime/3600), nTime%3600/60
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
	DLG = EPGP.DLG
	glog = EPGP.glog
	DLG:Register("EPGP_RECURRING_RESUME", {
		buttons = {
			{
				text = Apollo.GetString("CRB_Yes"),
				OnClick = function(self, data, reason)
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
				OnClick = function(self, data, reason)
					mod:StopRecurringEP()
				end,
			},
		},
		OnShow = function(self, settings, data)
			settings:SetText(data.text)
			settings:SetTimeRemaining(data.timeout)
			settings:ShowCloseButton(false)
		end,
		OnCancel = function(self, data, reason)
			if reason ~= "override" then
				mod:StopRecurringEP()
			end
		end,
		OnHide = function(self, settings, data)
			settings:ShowCloseButton(true)
		end,
		hideOnEscape = true,
		showWhileDead = true,
	})
end