local EPGP = Apollo.GetAddon("EPGP")
local mod = EPGP:NewModule("masterloot", "Gemini:Hook-1.0")
local glog, DLG, tTimer

function mod:OnInitialize()
	glog = EPGP.glog
	DLG = EPGP.DLG
end

local function AssignLoot(tMLoot, wndHandler, wndControl, eMouseButton)
	if tMLoot.tMasterLootSelectedItem ~= nil and tMLoot.tMasterLootSelectedLooter ~= nil then
		-- Any Other checks before asking go here
		DLG:Spawn("EPGP_CONFIRM_GP_CREDIT", { name = tMLoot.tMasterLootSelectedLooter:GetName(), icon = tMLoot.tMasterLootSelectedItem })
	end
end

local function SortByValue(a, b)
	local aQualifies = a:FindChild("Value") ~= nil
	local bQualifies = b:FindChild("Value") ~= nil

	if aQualifies and bQualifies then
		local aPR = a:FindChild("Value"):GetText()
		local bPR = b:FindChild("Value"):GetText()

		return aPR > bPR
	else
		return aQualifies
	end
end

local function AddMasterLootDisplay(tMLoot, wndHandler, wndControl, eMouseButton)
	if tMLoot.wndMasterLoot ~= nil then
		for idx, wndLooter in pairs(tMLoot.wndMasterLoot:FindChild("LooterList"):GetChildren()) do
			local nEP, nGP = EPGP:GetEPGP(wndLooter:FindChild("CharacterName"):GetText())
			if nEP >= EPGP.db.profile.nMinEP then
				local wndOverlay = Apollo.LoadForm(EPGP.xmlDoc, "EPGPOverlay", wndLooter, mod)
				wndOverlay:FindChild("Label"):SetText("PR")
				wndOverlay:FindChild("Value"):SetText(string.format("%.2f",nEP/nGP))
			end
		end
		tMLoot.wndMasterLoot:FindChild("LooterList"):ArrangeChildrenVert(0, SortByValue)
	end
end

function AddMasterLootGPCost(tMLoot, tMasterLootItemList)
	if tMLoot.wndMasterLoot ~= nil then
		for idx, wndLoot in pairs(tMLoot.wndMasterLoot:FindChild("ItemList"):GetChildren()) do
			local wndOverlay = Apollo.LoadForm(EPGP.xmlDoc, "EPGPOverlay", wndLoot, mod)
			wndOverlay:FindChild("Value"):SetText(EPGP:CalculateItemGPValue(wndLoot:GetData().itemDrop))
		end	
	end
end

function AddLooterGPCost(tMLoot, tMasterLootItemList)
	if tMLoot.wndLooter ~= nil then
		for idx, wndLoot in pairs(tMLoot.wndLooter:FindChild("ItemList"):GetChildren()) do
			local wndOverlay = Apollo.LoadForm(EPGP.xmlDoc, "EPGPOverlay", wndLoot, mod)
			wndOverlay:FindChild("Value"):SetText(EPGP:CalculateItemGPValue(wndLoot:GetData().itemDrop))
		end
	end
end

function mod:OnEnable()
	-- Master Loot Overlays
	local tMasterLoot = Apollo.GetAddon("MasterLoot")

	-- Master Loot Assignment
	self:Hook(tMasterLoot, "OnAssignDown", AssignLoot)

	-- Hook to add a PR display to all items in MasterLoot display
	self:PostHook(tMasterLoot, "OnItemCheck", AddMasterLootDisplay)

	-- Display GP Cost for Master Looter
	self:PostHook(tMasterLoot, "RefreshMasterLootItemList", AddMasterLootGPCost)

	-- Display GP Cost for Looter
	self:PostHook(tMasterLoot, "RefreshMasterLootLooterList", AddLooterGPCost)
end

function mod:OnDisable()
	self:UnhookAll()
end