local EPGP = Apollo.GetAddon("EPGP")
local mod = EPGP:NewModule("announce")
--local AC = LibStub("AceComm-3.0")

-- Assigned in OnEnable
local glog = nil
local L = EPGP.L
--local GP = LibStub("LibGearPoints-1.2")

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

function mod:AnnounceTo(medium, fmt, ...)
  if not medium then return end

  -- Override raid and party if we are not grouped
  if (medium == "RAID" or medium == "GUILD") and not GroupLib.InRaid() then
    medium = "GUILD"
  end

  local strPrefix = nil
  if medium == "GUILD" then
    strPrefix = "/g "
  elseif medium == "OFFICER" then
    strPrefix = "/go "
  else
    strPrefix = "/p "
  end

  local msg = string.format(fmt, ...)

  local str = "EPGP:"
  for _,s in pairs(strsplit(" ", msg)) do
    if #str + #s >= 250 then
      ChatSystemLib.Command(strPrefix .. str)
      str = "EPGP:"
    end
    str = str .. " " .. s
  end

  ChatSystemLib.Command(strPrefix .. str)
end

function mod:Announce(fmt, ...)
--  local medium = self.db.profile.medium
  local medium = "RAID"
  return mod:AnnounceTo(medium, fmt, ...)
end

function mod:EPAward(event_name, name, reason, amount, mass)
  if mass then return end
  mod:Announce(L["%+d EP (%s) to %s"], amount, reason, name)
end

function mod:GPAward(event_name, name, reason, amount, mass)
  if mass then return end
  mod:Announce(L["%+d GP (%s) to %s"], amount, reason, name)
end

function mod:BankedItem(event_name, name, reason, amount, mass)
  mod:Announce(L["%s to %s"], reason, name)
end

local function MakeCommaSeparated(t)
  local first = true
  local awarded = ""

  for name in pairs(t) do
    if first then
      awarded = name
      first = false
    else
      awarded = awarded..", "..name
    end
  end

  return awarded
end

function mod:MassEPAward(event_name, names, reason, amount,
                         extras_names, extras_reason, extras_amount)
  local normal = MakeCommaSeparated(names)
  mod:Announce(L["%+d EP (%s) to %s"], amount, reason, normal)

  if extras_names then
    local extras = MakeCommaSeparated(extras_names)
    mod:Announce(L["%+d EP (%s) to %s"], extras_amount, extras_reason, extras)
  end
end

function mod:Decay(event_name, decay_p)
  mod:Announce(L["Decay of EP/GP by %d%%"], decay_p)
end

function mod:StartRecurringAward(event_name, reason, amount, mins)
  local fmt, val = SecondsToTimeAbbrev(mins * 60)
  mod:Announce(L["Start recurring award (%s) %d EP/%s"], reason, amount, fmt:format(val))
end

function mod:ResumeRecurringAward(event_name, reason, amount, mins)
  local fmt, val = SecondsToTimeAbbrev(mins * 60)
  mod:Announce(L["Resume recurring award (%s) %d EP/%s"], reason, amount, fmt:format(val))
end

function mod:StopRecurringAward(event_name)
  mod:Announce(L["Stop recurring award"])
end

function mod:EPGPReset(event_name)
  mod:Announce(L["EP/GP are reset"])
end

function mod:GPReset(event_name)
  mod:Announce(L["GP (not EP) is reset"])
end

function mod:GPRescale(event_name)
  mod:Announce(L["GP is rescaled for the new tier"])
end

function mod:LootEpics(event_name, loot)
  for _, itemLink in ipairs(loot) do
    local _, _, itemRarity, ilvl = GetItemInfo(itemLink)
    local cost = GP:GetValue(itemLink)
    if itemRarity >= ITEM_QUALITY_EPIC and cost ~= nil then
      mod:AnnounceTo("RAID", "%s (ilvl %d)", itemLink, ilvl or 1)
      --AC:SendCommMessage("EPGPCORPSELOOT", tostring(itemLink), "RAID", nil, "ALERT")
    end
  end
end

function mod:CoinLootGood(event_name, sender, rewardLink, numCoins)
  local _, _, diffculty = GetInstanceInfo()
  if not GroupLib.InRaid() or diffculty == 7 then return end

  local _, _, _, ilvl, _, _, _, _, _ = GetItemInfo(rewardLink)
  mod:Announce(format(L["Bonus roll for %s (%s left): got %s (ilvl %d)"], sender, numCoins, rewardLink, ilvl or 1))
end

function mod:CoinLootBad(event_name, sender, numCoins)
  local _, _, diffculty = GetInstanceInfo()
  if not GroupLib.InRaid() or diffculty == 7 then return end

  mod:Announce(format(L["Bonus roll for %s (%s left): got gold"], sender, numCoins))
end

mod.dbDefaults = {
  profile = {
    enabled = true,
    medium = "GUILD",
    events = {
      ['*'] = true,
    },
  }
}

function mod:OnInitialize()
  self.db = EPGP.db:RegisterNamespace("announce", mod.dbDefaults)
end

mod.optionsName = L["Announce"]
mod.optionsDesc = L["Announcement of EPGP actions"]
mod.optionsArgs = {
  help = {
    order = 1,
    type = "description",
    name = L["Announces EPGP actions to the specified medium."],
  },
  medium = {
    order = 10,
    type = "select",
    name = L["Announce medium"],
    desc = L["Sets the announce medium EPGP will use to announce EPGP actions."],
    values = {
      ["GUILD"] = CHAT_MSG_GUILD,
      ["OFFICER"] = CHAT_MSG_OFFICER,
      ["RAID"] = CHAT_MSG_RAID,
      ["PARTY"] = CHAT_MSG_PARTY,
      ["CHANNEL"] = CUSTOM,
    },
  },
  channel = {
    order = 11,
    type = "input",
    name = L["Custom announce channel name"],
    desc = L["Sets the custom announce channel name used to announce EPGP actions."],
    disabled = function(i) return mod.db.profile.medium ~= "CHANNEL" end,
  },
  events = {
    order = 12,
    type = "multiselect",
    name = L["Announce when:"],
    values = {
      EPAward = L["A member is awarded EP"],
      MassEPAward = L["Guild or Raid are awarded EP"],
      GPAward = L["A member is credited GP"],
      BankedItem = L["An item was disenchanted or deposited into the guild bank"],
      Decay = L["EPGP decay"],
      StartRecurringAward = L["Recurring awards start"],
      StopRecurringAward = L["Recurring awards stop"],
      ResumeRecurringAward = L["Recurring awards resume"],
      EPGPReset = L["EPGP reset"],
      GPReset = L["GP (not ep) reset"],
      GPRescale = L["GP rescale for new tier"],
      LootEpics = L["Announce epic loot from corpses"],
      CoinLootGood = L["Announce when someone in your raid wins something good with bonus roll"],
      CoinLootBad = L["Announce when someone in your raid derps a bonus roll"],
    },
    width = "full",
    get = "GetEvent",
    set = "SetEvent",
  },
}

function mod:GetEvent(i, e)
  return self.db.profile.events[e]
end

function mod:SetEvent(i, e, v)
  if v then
    glog:debug("Enabling announce of: %s", e)
    EPGP.RegisterCallback(self, e)
  else
    glog:debug("Disabling announce of: %s", e)
    EPGP.UnregisterCallback(self, e)
  end
  self.db.profile.events[e] = v
end

function mod:OnEnable()
  glog = EPGP.glog
  for e, _ in pairs(mod.optionsArgs.events.values) do
--    if self.db.profile.events[e] then
      glog:debug("Enabling announce of: %s (startup)", e)
      EPGP.RegisterCallback(self, e)
--    end
  end
end

function mod:OnDisable()
  EPGP.UnregisterAllCallbacks(self)
end
