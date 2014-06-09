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

self.db.profile
  Contains all configuration settings for onsave/restore
--]]
require "Window"

local EPGP = Apollo.GetAddon("EPGP")
local L, glog = EPGP.L, nil
local callbacks = EPGP.callbacks

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

-------------------------------------------------------------------------------
--- Local Variables
local tEPData = {}
local tGPData = {}
local tMainData = {}
local tAltData = {}
local tIgnored = {}
local tStandings = {}
local tSelected = {}
tSelected._count = 0
local GS = Apollo.GetPackage("LibGuildStorage-1.0").tPackage
-------------------------------------------------------------------------------
--- Utility functions

local function wipe(tbl)
  if not tbl then return end
  for k,v in pairs(tbl) do
    tbl[k] = nil
  end
end

local function IsInGroup(strPlayer)
  for idx = 1, GroupLib.GetMemberCount() do
    local tMemberInfo = GroupLib.GetGroupMember(idx)
    if tMemberInfo ~= nil and tMemberInfo.strCharacterName:lower() == strPlayer:lower() then 
      return true 
    end
  end
  return false
end

function EPGP:DecodeNote(strNote)
  if strNote then
    if strNote == "" then
      return 0,0
    else
      local nEP, nGP = string.match(strNote, "^(%d+),(%d+)$")
      if nEP then
        return tonumber(nEP), tonumber(nGP)
      end
    end
  end
end

local function EncodeNote(nEP, nGP)
  return string.format("%d,%d",
              math.max(nEP, 0),
              math.max(nGP - EPGP.db.profile.nBaseGP, 0))
end

local function AddEPGP(strName, nEP, nGP)
  local nTotalEP = tEPData[strName]
  local nTotalGP = tGPData[strName]
  assert(nTotalEP ~= nil and nTotalGP ~= nil,
    string.format("%s is not a main!", tostring(name)))

  -- Compute the actual amounts we can add/subtract.
  if (nTotalEP + nEP) < 0 then
    nEP = -nTotalEP
  end
  if (nTotalGP + nGP) < 0 then
    nGP = -nTotalGP
  end
  GS:SetNote(strName, EncodeNote(nTotalEP + nEP,
                nTotalGP + nGP + EPGP.db.profile.nBaseGP))
  return nEP, nGP
end

-- A wrapper function to handle sort logic for selected
local function ComparatorWrapper(f)
  return function(a, b)
           local a_in_raid = not not IsInGroup(a)
           local b_in_raid = not not IsInGroup(b)
           if a_in_raid ~= b_in_raid then
             return not b_in_raid
           end

           local a_selected = selected[a]
           local b_selected = selected[b]

           if a_selected ~= b_selected then
             return not b_selected
           end

           return f(a, b)
         end
end

local comparators = {
  NAME = function(a, b)
           return a < b
         end,
  EP = function(a, b)
         local a_ep, a_gp = EPGP:GetEPGP(a)
         local b_ep, b_gp = EPGP:GetEPGP(b)

         return a_ep > b_ep
       end,
  GP = function(a, b)
         local a_ep, a_gp = EPGP:GetEPGP(a)
         local b_ep, b_gp = EPGP:GetEPGP(b)

         return a_gp > b_gp
       end,
  PR = function(a, b)
         local a_ep, a_gp = EPGP:GetEPGP(a)
         local b_ep, b_gp = EPGP:GetEPGP(b)

         local a_qualifies = a_ep >= EPGP.db.profile.nMinEP
         local b_qualifies = b_ep >= EPGP.db.profile.nMinEP

         if a_qualifies == b_qualifies then
           return a_ep/a_gp > b_ep/b_gp
         else
           return a_qualifies
         end
       end,
}
for k,f in pairs(comparators) do
  comparators[k] = ComparatorWrapper(f)
end

local function DestroyStandings()
  wipe(tStandings)
  callbacks:Fire("StandingsChanged")
end

local function RefreshStandings(order, bShowEveryone)
  -- Debug("Resorting standings")
  if GroupLib.InRaid() then
    -- If we are in raid:
    ---  showEveryone = true: show all in raid (including alts) and
    ---  all leftover mains
    ---  showEveryone = false: show all in raid (including alts) and
    ---  all selected members
    for n in pairs(tEPData) do
      if bShowEveryone or IsInGroup(n) or selected[n] then
        table.insert(tStandings, n)
      end
    end
    for n in pairs(tMainData) do
      if IsInGroup(n) or selected[n] then
        table.insert(tStandings, n)
      end
    end
  else
    -- If we are not in raid, show all mains
    for n in pairs(tEPData) do
      table.insert(tStandings, n)
    end
  end

  -- Sort
  table.sort(tStandings, comparators[order])
end

local function DeleteState(strName)
  tIgnored[strName] = nil
  -- If this is was an alt we need to fix the alts state
  local strMain = tMainData[strName]
  if strMain then
    if tAltData[strMain] then
      for nIndex, strAlt in ipairs(tAltData[strMain]) do
        if strAlt == strName then
          table.remove(tAltData[strMain], nIndex)
          break
        end
      end
    end
    tMainData[strMain] = nil
  end
  -- Delete any existing cached values
  tEPData[strName] = nil
  tGPData[strName] = nil
end

local function HandleDeletedGuildNote(callback, strName)
  DeleteState(strName)
  DestroyStandings()
end

local function ParseGuildNote(callback, strName, strNote)
  --glog:debug("Parsing Guild Note for %s [%s]", name, note)
  -- Delete current state about this toon.
  DeleteState(strName)

  local nEP, nGP = EPGP:DecodeNote(strNote)
  if nEP then
    tEPData[strName] = nEP
    tGPData[strName] = nGP
  else
    local nMainEP = EPGP:DecodeNote(GS:GetNote(strNote))
    if not nMainEP then
      -- This member does not point to a valid main, ignore it.
      tIgnored[strName] = strNote
    else
      -- Otherwise setup the alts state
      tMainData[strName] = strNote
      if not tAltData[strNote] then
        tAltData[strNote] = {}
      end
      table.insert(tAltData[strNote], strName)
      tEPData[strName] = nil
      tGPData[strName] = nil
    end
  end
  DestroyStandings()
end

function EPGP:IsRLorML()
  if GroupLib.InRaid() then
    return GroupLib.AmILeader()
  end
  return false
end

function EPGP:ExportRoster()
  local nBaseGP = self.db.profile.nBaseGP
  local tRoster = {}
  for strName,_ in pairs(tEPData) do
    local nEP, nGP, strMain = self:GetEPGP(strName)
    if nEP ~= 0 or nGP ~= nBaseGP then
      table.insert(tRoster, {strName, nEP, nGP})
    end
  end
  return tRoster
end

function EPGP:ImportRoster(tRoster, nNewBaseGP)
  local nOldBaseGP = self.db.profile.nBaseGP
  self.db.profile.nBaseGP = nNewBaseGP

  local tNotes = {}
  for _, tEntry in pairs(tRoster) do
    local strName, nEP, nGP = unpack(tEntry)
    tNotes[strName] = EncodeNote(nEP, nGP)
  end

  local strZeroNote = EncodeNote(0, 0)
  for strName, _ in pairs(tEPData) do
    local strNote = tNotes[strName] or strZeroNote
    GS:SetNote(strName, strNote)
  end

  self.db.profile.nBaseGP = nOldBaseGP
end

function EPGP:StandingsSort(order)
  if not order then
    return self.db.profile.sortOrder
  end

  assert(comparators[order], "Unknown sort order")

  self.db.profile.sortOrder = order
  DestroyStandings()
end

function EPGP:StandingsShowEveryone(bVal)
  if bVal == nil then
    return self.db.profile.bShowEveryone
  end

  self.db.profile.bShowEveryone = not not val
  DestroyStandings()
end

function EPGP:GetNumMembers()
  if #tStandings == 0 then
    RefreshStandings(self.db.profile.sortOrder, self.db.profile.bShowEveryone)
  end

  return #tStandings
end

function EPGP:GetMember(nIndex)
  if #tStandings == 0 then
    RefreshStandings(self.db.profile.sortOrder, self.db.profile.bShowEveryone)
  end

  return tStandings[nIndex]
end

function EPGP:GetNumAlts(strName)
  local tAlts = tAltData[strName]
  if not tAlts then
    return 0
  else
    return #tAlts
  end
end

function EPGP:GetAlt(strName, nIndex)
  return tAltData[strName][nIndex]
end

function EPGP:SelectMember(strName)
  if GroupLib.InRaid() then
    -- In same raid?
    if IsInGroup(strName) then
      return false
    end
  end
  tSelected[strName] = true
  tSelected._count = tSelected._count + 1
  DestroyStandings()
  return true
end

function EPGP:DeSelectMember(strName)
  if IsInGroup(strName) then
    if GroupLib.InRaid() then
      return false
    end
  end
  if not tSelected[strName] then
    return false
  end
  tSelected[strName] = nil
  tSelected._count = tSelected._count - 1

  DestroyStandings()
  return true
end

function EPGP:GetNumMembersInAwardList()
  if GroupLib.InRaid() then
    return GroupLib.GetMemberCount() + tSelected._count
  else
    if tSelected._count == 0 then
      return self:GetNumMembers()
    else
      return tSelected._count
    end
  end
end

function EPGP:IsMemberInAwardList(strName)
  if GroupLib.InRaid() then
    -- If we are raiding, people who are raiding or selected are eligible
    return IsInGroup[strName] or tSelected[strName]
  else
    -- Not in Raid: Everyone if no-one is selected otherwise those selected
    if tSelected._count == 0 then
      return true
    end
    return tSelected[strName]
  end
end

function EPGP:IsMemberInExtrasList(strName)
  return GroupLib.InRaid() and tSelected[strName]
end

function EPGP:IsAnyMemberInExtrasList()
  return tSelected._count ~= 0
end

function EPGP:CanResetEPGP()
  local guildOwner = GS:GetGuild()
  local eMyRank = guildOwner:GetMyRank()
  local tMyRankPermissions = guildOwner:GetRanks()[eMyRank]
  


  return true and GS:IsCurrentState()
end

function EPGP:ResetEPGP()
  assert(self:CanResetEPGP())

  local strZeroNote = EncodeNote(0, 0)
  for strName, _ in pairs(tEPData) do
    GS:SetNote(strName, strZeroNote)
    local nEP, nGP, strMain = self:GetEPGP(strName)
    assert(strMain == nil, "Corrupt alt data!")
    if nEP > 0 then
      callbacks:Fire("EPAward", name, "Reset", -nEP, true)
    end
    if nGP > 0 then
      callbacks:Fire("GPAward", name, "Reset", -nGP, true)
    end
  end
  callbacks:Fire("EPGPReset")
end

function EPGP:ResetGP()
  assert(self:CanResetEPGP())

  for nIndex = 1, EPGP:GetNumMembers() do
    local strMember = EPGP:GetMember(nIndex)
    local nEP, nGP, strMain = self:GetEPGP(strMember)
    local nActualGP = nGP - self:GetBaseGP()
    if strMain == nil and nActualGP > 0 then
      local nDelta = -nActualGP
      self:IncGPBy(strMember, "GP Reset", nDelta, true, false)
    end
  end
  callbacks:Fire("GPReset")
end

function EPGP:CanDecayEPGP()
--  if not CanEditOfficerNote() or self.db.profile.nDecayPerc == 0 or not GS:IsCurrentState() then
  if self.db.profile.nDecayPerc == 0 or not GS:IsCurrentState() then
    return false
  end
  return true
end

function EPGP:DecayEPGP()
  assert(self:CanDecayEPGP())

  local nDecay = self.db.profile.nDecayPerc * 0.01
  local strReason = string.format("Decay %d%%", self.db.profile.nDecayPerc)
  for strName,_ in pairs(tEPData) do
    local nEP, nGP, strMain = self:GetEPGP(strName)
    assert(strMain == nil, "Corrupt alt data!")
    local nDecayEP = math.ceil(nEP * nDecay)
    local nDecayGP = math.ceil(nGP * nDecay)
    nDecayEP, nDecayGP = AddEPGP(strName, -nDecayEP, -nDecayGP)
    if nDecayEP ~= 0 then
      callbacks:Fire("EPAward", strName, strReason, nDecayEP, true)
    end
    if nDecayGP ~= 0 then
      callbacks:Fire("GPAward", strName, strReason, nDecayGP, true)
    end
  end
  callbacks:Fire("Decay", self.db.profile.nDecayPerc)
end

function EPGP:GetEPGP(strName)
  local strMain = tMainData[strName]
  if strMain then
    strName = strMain
  end
  if tEPData[strName] then
    return tEPData[strName], tGPData[strName] + self.db.profile.nBaseGP, strMain
  end
end

function EPGP:GetClass(strName)
  return GS:GetClass(strName)
end

function EPGP:CanIncEPBy(reason, nAmount)
--if not CanEditOfficerNote() or not GS:IsCurrentState() then
  if not GS:IsCurrentState() then
    return false
  end
  if type(reason) ~= "string" or type(nAmount) ~= "number" or #reason == 0 then
    return false
  end
  if nAmount ~= math.floor(nAmount + 0.5) then
    return false
  end
  if nAmount < -99999 or nAmount > 99999 or nAmount == 0 then
    return false
  end
  return true
end

function EPGP:IncEPBy(strName, strReason, nAmount, bMass, bUndo)
  -- When we do mass EP or decay we know what we are doing even though
  -- CanIncEPBy returns false
  assert(self:CanIncEPBy(strReason, nAmount) or bMass or bUndo)
  assert(type(strName) == "string")

  local nEP, nGP, strMain = self:GetEPGP(strName)
  if not nEP then
    Print(L["Ignoring EP change for unknown member %s"]:format(strName))
    return
  end

  nAmount = AddEPGP(strMain or strName, nAmount, 0)
  if amount then
    callbacks:Fire("EPAward", strName, strReason, nAmount, bMass, bUndo)
  end
  self.db.profile.tLastAwards[strReason] = nAmount
  return strMain or strName
end

function EPGP:CanIncGPBy(reason, nAmount)
--  if not CanEditOfficerNote() or not GS:IsCurrentState() then
  if not GS:IsCurrentState() then
    return false
  end
  if type(strReason) ~= "string" or type(nAmount) ~= "number" or #reason == 0 then
    return false
  end
  if nAmount ~= math.floor(nAmount + 0.5) then
    return false
  end
  if nAmount < -99999 or nAmount > 99999 or nAmount == 0 then
    return false
  end
  return true
end

function EPGP:IncGPBy(strName, strReason, nAmount, bMass, bUndo)
  -- When we do mass EP or decay we know what we are doing even though
  -- CanIncGPBy returns false
  assert(self:CanIncGPBy(strReason, nAmount) or bMass or bUndo)
  assert(type(strName) == "string")

  local nEP, nGP, strMain = self:GetEPGP(strName)
  if not nEP then
    Print(L["Ignoring GP change for unknown member %s"]:format(strName))
    return
  end
  nAmount = AddEPGP(strMain or strName, 0, nAmount)
  if nAmount then
    callbacks:Fire("GPAward", strName, strReason, nAmount, bMass, bUndo)
  end

  return strMain or strName
end

function EPGP:BankItem(strReason, bUndo)
  callbacks:Fire("BankedItem", GUILD_BANK, strReason, 0, false, bUndo)
end

function EPGP:GetDecayPercent()
  return self.db.profile.nDecayPerc
end

function EPGP:GetExtrasPercent()
  return self.db.profile.nExtrasPerc
end

function EPGP:GetBaseGP()
  return self.db.profile.nBaseGP
end

function EPGP:GetMinEP()
  return self.db.profile.nMinEP
end

function CanEditInfoMessage()
  local guildOwner = GS:GetGuild()
  local eMyRank = guildOwner:GetMyRank()
  local tMyRankPermissions = guildOwner:GetRanks()[eMyRank]

  return tMyRankPermissions.bMessageOfTheDay
end

function EPGP:SetGlobalConfiguration(nDecayPerc, nExtrasPerc, nBaseGP, nMinEP)
  if not CanEditInfoMessage() then return end
  local strGuildInfo = GS:GetGuildInfo()
  local strEPGPStanza = string.format(
    "-EPGP-\n@DECAY_P:%d\n@EXTRAS_P:%s\n@MIN_EP:%d\n@BASE_GP:%d\n@OUTSIDERS:%d\n-EPGP-",
    nDecayPerc or DEFAULT_DECAY_P,
    nExtrasPerc or DEFAULT_EXTRAS_P,
    nMinEP or DEFAULT_MIN_EP,
    nBaseGP or DEFAULT_BASE_GP)

  glog:debug("Stanza:\n%s", strEPGPStanza)
  if strGuildInfo:match("%-EPGP%-.*%-EPGP%-") then
    strGuildInfo = strGuildInfo:gsub("%-EPGP%-.*%-EPGP%-", strEPGPStanza)
  else
    strGuildInfo = strGuildInfo .. "\n" .. strEPGPStanza
  end
  glog:debug("GuildInfo:\n%s", strGuildInfo)
  GS:GetGuild():SetInfoMessage(strGuildInfo)
end

function EPGP:GetMain(strName)
  return tMainData[strName] or strName
end

function EPGP:IncMassEPBy(strReason, nAmount)
  local tAwarded = {}
  local tExtrasAwarded = {}
  local nExtrasAmount = math.floor(self.db.profile.nExtrasPerc * 0.01 * nAmount)
  local strExtrasReason = strReason .. " - " .. L["Standby"]

  for nIndex=1, self:GetNumMembers() do
    local strName = self:GetMember(nIndex)

    if self:IsMemberInAwardList(strName) then
      -- EPGP:GetMain() will return the input name if it doesn't find a main,
      -- so we can't use it to validate that this actually is a character who
      -- can recieve EP.
      --
      -- EPGP:GetEPGP() returns nil for ep and gp, if it can't find a
      -- valid member based on the name however.
      local nEP, nGP, strMain = self:GetEPGP(strName)
      local strMain = strMain or strName

      if nEP and not tAwarded[strMain] and not tExtrasAwarded[strMain] then
        if self:IsMemberInExtrasList(strName) then
          self:IncEPBy(strName, strExtrasReason, nExtrasAmount, true)
          tExtrasAwarded[strName] = true
        else
          self:IncEPBy(strName, strReason, nAmount, true)
          tAwarded[strName] = true
        end
      end
    end
  end

  if next(tAwarded) then
    if next(tExtrasAwarded) then
      callbacks:Fire("MassEPAward", tAwarded, strReason, nAmount,
              tExtrasAwarded, strExtrasReason, nExtrasAmount)
    else
      callbacks:Fire("MassEPAward", tAwarded, strReason, nAmount)
    end
  end
end

function EPGP:ReportErrors(outputFunc)
  for strName, strNote in pairs(tIgnored) do
    outputFunc(L["Invalid officer note [%s] for %s (ignored)"]:format(
      strNote, strName))
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

local bInitialized = false
local function OnGuildChange(callback, guildCurr)
  glog:debug("OnGuildChange Received")
  if guildCurr == nil then
    glog:debug("Not in guild, disabling modules")
    for strName, oModule in EPGP:IterateModules() do
      oModule:Disable()
    end
  else
    if EPGP.db:GetCurrentProfile() ~= guildCurr:GetName() then
      glog:debug("Setting DB Profile to: %s", guildCurr:GetName())
      EPGP.db:SetProfile(guildCurr:GetName())
    end
    if not bInitialized then
      bInitialized = true
      for strName, oModule in EPGP:IterateModules() do
        glog:debug("Enabling Module (startup): %s", strName)
        oModule:Enable()
      end
    end
  end
end

-- EPGP OnLoad
function EPGP:OnInitialize()
  local dbDefaults = {
    profile = {
      tLastAwards = {},
      bShowEveryone = false,
      strSortOrder = "PR",
      bSortAsc = true,
      nRecurringEPPeriodMins = 15,
      nDecayPerc = 0,
      nExtrasPerc = 100,
      nMinEP = 0,
      nBaseGP = 1,
    }
  }
  self.db = Apollo.GetPackage("Gemini:DB-1.0").tPackage:New(self, dbDefaults)

  local GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2").tPackage
  EPGP.glog = GeminiLogging:GetLogger({
        level = GeminiLogging.WARN,
        pattern = "%d %n %c %l - %m",
        appender = "GeminiConsole"
  })
  glog = EPGP.glog
  EPGP.DLG = Apollo.GetPackage("Gemini:LibDialog-1.0").tPackage
  EPGP:RegisterDialogs()

  GS.RegisterCallback(self, "GuildChanged", OnGuildChange)
  -- Load our form file
  self.xmlDoc = XmlDoc.CreateFromFile("EPGP.xml")
  Apollo.LoadSprites("EPGPSprites.xml")
end

function EPGP:OnEnable()
  self.FilterList = false

  -- Configuration Form
  self:SetupConfig()

  -- Register Events
  Apollo.RegisterEventHandler("GroupChange", "OnGroupChange", self)

  -- Interface Menu Shortcut Events
  Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)

  GS.RegisterCallback(self, "GuildNoteChanged", ParseGuildNote)
  GS.RegisterCallback(self, "GuildNoteDeleted", HandleDeletedGuildNote)

  EPGP.RegisterCallback(self, "BaseGPChanged", DestroyStandings)
--[[
  local function UpdateFrameOnUpdate(self, elapsed)
    self:SetScript("OnUpdate", nil)
    if self.GroupRosterUpdated then EPGP:GROUP_ROSTER_UPDATE() end
    self.GroupRosterUpdated = nil
    if self.GuildRosterUpdated then EPGP:GUILD_ROSTER_UPDATE() end
    self.GuildRosterUpdated = nil
  end

  self:RegisterEvent("GROUP_ROSTER_UPDATE",
    function()
      UpdateFrame.GroupRosterUpdated = true
      UpdateFrame:SetScript("OnUpdate", UpdateFrameOnUpdate)
    end)
  self:RegisterEvent("GUILD_ROSTER_UPDATE",
    function()
      UpdateFrame.GuildRosterUpdated = true
      UpdateFrame:SetScript("OnUpdate", UpdateFrameOnUpdate)
    end)

  GuildRoster()
  ]]
end

function EPGP:OnGroupChange()
  if GroupLib.InRaid() then
    -- If we are in a raid, make sure no member of the raid is
    -- selected
    for strName,_ in pairs(tSelected) do
      if IsInGroup(strName) then
        tSelected[strName] = nil
        tSelected._count = selected._count - 1
      end
    end
  else
    -- If we are not in a raid, this means we just left so remove
    -- everyone from the selected list.
    wipe(tSelected)
    tSelected._count = 0
    -- We also need to stop any recurring EP since they should stop
    -- once a raid stops.
    if self:RunningRecurringEP() then
      self:StopRecurringEP()
    end
  end
  DestroyStandings()
end

function EPGP:OnInterfaceMenuListHasLoaded()
  Event_FireGenericEvent("InterfaceMenuList_NewAddOn","EPGP", {"ToggleEPGPWindow", "", "EPGPSprites:EPGP_Icon"})
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