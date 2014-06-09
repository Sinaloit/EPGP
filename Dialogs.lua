local EPGP = Apollo.GetAddon("EPGP")
local L = EPGP.L

function EPGP:RegisterDialogs()
	local DLG = EPGP.DLG

	DLG:Register("EPGP_CONFIRM_GP_CREDIT", {
		text = "Unknown Item",
		icon = [[Interface\DialogFrame\UI-Dialog-Icon-AlertNew]],
		buttons = {
			{
				text = Apollo.GetString("CRB_Accept"),
				OnClick = function(settings, data, reason)
					local gp = tonumber(settings.editboxes[1]:GetText())
					EPGP:IncGPBy(data.name, data.item, gp)
				end,
			},
			{
				color = red,
				text = Apollo.GetString("CRB_Cancel"),
			},
			{
				text = Apollo.GetString("GuildBank_Title"),
				OnClick = function(settings, data, reason)
					EPGP:BankItem(data.item)
				end,
			},
		},
		editboxes = {
			{
				autoFocus = true,
			},
		},
		OnShow = function(settings, data)
			settings:SetText(string.format("\n"..L["Credit GP to %s"].."\n", data.item))
			settings:SetIcon(data.icon)
			local gp1, gp2 = GP:GetValue(data.icon)
			if not gp1 then
				settings.editboxes[1]:SetText("")
			elseif not gp2 then
				settings.editboxes[1]:SetText(tostring(gp1))
			else
				settings.editboxes[1]:SetText(L["%d or %d"]:format(gp1, gp2))
			end
		end,
		OnUpdate = function(settings, elapsed)
			local gp = tonumber(settings.editboxes[1]:GetText())
			if EPGP:CanIncGPBy(self.data.item, gp) then
				settings.buttons[1]:Enable()
			else
				settings.buttons[1]:Disable()
			end
		end,
		hideOnEscape = true,
		showWhileDead = true,
	})

	DLG:Register("EPGP_DECAY_EPGP", {
		buttons = {
			{
				text = Apollo.GetString("CRB_Accept"),
				OnClick = function(settings, data, reason)
					EPGP:DecayEPGP()
				end,
			},
			{
				color = red,
				text = Apollo.GetString("CRB_Cancel"),
			},
		},
		OnShow = function(settings, data)
			settings:SetText(L["Decay EP and GP by %d%%?"]:format(data))
		end,
		OnUpdate = function(settings, elapsed)
			if EPGP:CanDecayEPGP() then
				settings.buttons[1]:Enable()
			else
				settings.buttons[1]:Disable()
			end
		end,
		hideOnEscape = true,
		showWhileDead = true,
	})

	DLG:Register("EPGP_RESET_EPGP", {
		text = L["Reset all main toons' EP and GP to 0?"],
		buttons = {
			{
				text = Apollo.GetString("CRB_Accept"),
				OnClick = function(settings, data, reason)
					EPGP:ResetEPGP()
				end,
			},
			{			
				color = red,
				text = Apollo.GetString("CRB_Cancel"),
			},
		},
		OnUpdate = function(settings, elapsed)
			if EPGP:CanResetEPGP() then
				settings.buttons[1]:Enable()
			else
				settings.buttons[1]:Disable()
			end
		end,
		hideOnEscape = true,
		showWhileDead = true,
	})

	DLG:Register("EPGP_RESET_GP", {
		text = L["Reset all main toons' GP to 0?"],
		buttons = {
			{
				text = Apollo.GetString("CRB_Accept"),
				OnClick = function(settings, data, reason)
					EPGP:ResetGP()
				end,
			},
			{
				color = red,
				text = Apollo.GetString("CRB_Cancel"),
			},
		},
		OnUpdate = function(settings, elapsed)
			if EPGP:CanResetEPGP() then
				settings.buttons[1]:Enable()
			else
				settings.buttons[1]:Disable()
			end
		end,
		hideOnEscape = true,
		showWhileDead = true,
	})

	DLG:Register("EPGP_BOSS_DEAD", {
		buttons = {
			{
				text = Apollo.GetString("CRB_Accept"),
				OnClick = function(settings, data, reason)
					local ep = tonumber(settings.editboxes[1]:GetText())
					EPGP:IncMassEPBy(data, ep)
				end,
			},
			{
				color = red,
				text = Apollo.GetString("CRB_Cancel"),
			},
		},
		editboxes = {
			{
				autoFocus = true,
			},
		},
		OnShow = function(settings, data)
			settings:SetText(L["%s is dead. Award EP?"]:format(data))
			settings.editboxes[1]:SetText("")
		end,
		OnUpdate = function(settings, elapsed)
			local ep = tonumber(self.editboxes[1]:GetText())
			if EPGP:CanIncEPBy(self.data, ep) then
				settings.buttons[1]:Enable()
			else
				settings.buttons[1]:Disable()
			end
		end,
		showWhileDead = true,
	})

	DLG:Register("EPGP_BOSS_ATTEMPT", {
		buttons = {
			{
				text = Apollo.GetString("CRB_Accept"),
				OnClick = function(settings, data, reason)
					local ep = tonumber(settings.editboxes[1]:GetText())
					EPGP:IncMassEPBy(data .. " (attempt)", ep)
				end,
			},
			{
				color = red,
				text = Apollo.GetString("CRB_Cancel"),
			},
		},
		editboxes = {
			{
				--  OnEscape = function(tEditbox, tData, strText)
				--  end,
				--  OnTextChanged = function(tEditbox, tData, strText)
				--  end,
				--  OnReturn = function(tEditbox, tData, strText)
				--  end,
				autoFocus = true,
			},
		},
		OnShow = function(settings, data)
			settings:SetText(L["Wiped on %s. Award EP?"]:format(data))
			settings.editboxes[1]:SetText("")
		end,
		OnUpdate = function(settings, elapsed)
			local ep = tonumber(settings.editboxes[1]:GetText())
			if EPGP:CanIncEPBy(self.data, ep) then
				settings.buttons[1]:Enable()
			else
				settings.buttons[1]:Disable()
			end
  		end,
  		showWhileDead = true,
	})

	DLG:Register("EPGP_LOOTMASTER_ASK_TRACKING", {
		text = "You are the Loot Master, would you like to use EPGP Lootmaster to distribute loot?\r\n\r\n(You will be asked again next time. Use the configuration panel to change this behaviour)",
		icon = [[Interface\DialogFrame\UI-Dialog-Icon-AlertNew]],
		buttons = {
			{
				text = Apollo.GetString("CRB_Yes"),
				OnClick = function(settings)
					EPGP:GetModule("lootmaster"):EnableTracking()
					Print('You have enabled loot tracking for this raid')
				end,
			},
			{
				color = red,
				text = Apollo.GetString("CRB_No"),
				OnClick = function(settings)
					EPGP:GetModule("lootmaster"):DisableTracking()
					Print('You have disabled loot tracking for this raid')
				end,
			},
		},
		hideOnEscape = true,
		showWhileDead = true,
	})

	DLG:Register("EPGP_RECURRING_RESUME", {
		buttons = {
			{
				text = Apollo.GetString("CRB_Yes"),
				OnClick = function(settings, data, reason)
					callbacks:Fire("ResumeRecurringAward",
								EPGP.db.profile.strNextAwardReason,
								EPGP.db.profile.nNextAwardAmount,
								EPGP.db.profile.nRecurringEPPeriodMins)
					frame:Show()
				end,
			},
			{
				color = red,
				text = Apollo.GetString("CRB_No"),
				OnClick = function(settings, data, reason)
					EPGP:StopRecurringEP()
				end,
			},
		},
		OnShow = function(settings, data)
			settings:SetText(data.text)
			settings:SetTimeRemaining(data.timeout)
		end,
		OnCancel = function(settings, data, reason)
			if reason ~= "override" then
				EPGP:StopRecurringEP()
			end
		end,
		noCloseButton = true,
		hideOnEscape = true,
		showWhileDead = true,
	})
end