--[[
	This whole package is a lie ... the idea is that at some point Officer Notes will show up
	and this can be modified to use them... in the meantime save stuff out to file.

	Adapted to WildStar from LibGuildStorage-1.2 for WoW from the EPGP Project

	The API is as follows:
	--
	-- GetNote(name): Returns the officer note of member 'name'
	--
	-- SetNote(name, note): Sets the officer note of member 'name' to
	-- 'note'
	--
	-- GetClass(name): Returns the class of member 'name'
	--
	-- GetGuildInfo(): Returns the guild info text
	--
	-- IsCurrentState(): Return true if the state of the library is current.
	--
	-- Snapshot(table) -- DEPRECATED: Write out snapshot in the table
	-- provided. table.guild_info will contain the epgp clause in guild
	-- info and table.notes a table of {name, class, note}.
	--
	-- The library also fires the following messages, which you can
	-- register for through RegisterCallback and unregister through
	-- UnregisterCallback. You can also unregister all messages through
	-- UnregisterAllCallbacks.
	--
	-- GuildInfoChanged(info): Fired when guild info has changed since its
	--   previous state. The info is the new guild info.
	--
	-- GuildNoteChanged(name, note): Fired when a guild note changes. The
	--   name is the name of the member of which the note changed and the
	--   note is the new note.
	--
	-- StateChanged(): Fired when the state of the guild storage cache has
	-- changed.
	--
	-- GuildChanged(guild): Fired when your guild has changed.  The
	--   guild is the object for the new guild. Nil for when no-longer in
	--   a guild.

]]
-- Adapted to WildStar Packaging format by Sinaloit
local MAJOR, MINOR = "LibGuildStorage-1.0", 1
-- Get a reference to the package information if any
local APkg = Apollo.GetPackage(MAJOR)
-- If there was an older version loaded we need to see if this is newer
if APkg and (APkg.nVersion > 0) then
	return -- no upgrades
end
-- Set a reference to the actual package or create an empty table
local Lib = APkg and APkg.tPackage or {}

----------------------------------------------------------------------------------
--- Local Variables
local glog = nil
local bFirstFrame = true
local callbacks = nil
	
local CallbackHandler = Apollo.GetPackage("Gemini:CallbackHandler-1.0").tPackage
if not Lib.callbacks then
	Lib.callbacks = CallbackHandler:New(Lib)
end
callbacks = Lib.callbacks



local SetState

-- state of the tCache: UNINITIALIZED, STALE,
-- STALE_WAITING_FOR_ROSTER_UPDATE, CURRENT, FLUSHING, REMOTE_FLUSHING
--
local state = "STALE_WAITING_FOR_ROSTER_UPDATE"
local bInitialized
local nIndex

-- name -> {strNote=, bSeen=, eClass=}
local tCache = {}
-- pending notes to write out
local tPendingNote = {}
local strGuildInfo = ""
local tCurrentNotes = nil

function Lib:GetNote(strName)
	local e = tCache[strName]
	if e then return e.strNote end
end

function Lib:SetNote(strName, strNote)
	local e = tCache[strName]
	if e then
		if tPendingNote[strName] then
			Print(
				string.format("Ignoring attempt to set note before pending notes flushed "..
					  "note for %s! "..
					  "current=[%s] pending=[%s] new[%s]. "..
					  "Please report this bug along with the actions that "..
					  "lead to this on http://epgp.googlecode.com",
					tostring(strName),
					tostring(e.strNote),
					tostring(tPendingNote[strName]),
					tostring(strNote)))
		else
			tPendingNote[strName] = strNote
			SetState("FLUSHING")
		end
		return e.strNote
	end
end

function Lib:GetClass(strName)
	local e = tCache[strName]
	if e then return e.eClass end
end

function Lib:GetRank(strName)
	local e = tCache[strName]
	if e then return e.nRank end
end

function Lib:GetGuildInfo()
	return strGuildInfo
end

function Lib:GetGuild()
	return self.tGuild
end

function Lib:IsCurrentState()
	return state == "CURRENT"
end

-- This is kept for historical reasons. See:
-- http://code.google.com/p/epgp/issues/detail?id=350.
function Lib:Snapshot(t)
	assert(type(t) == "table")
	t.strGuildInfo = strGuildInfo:match("%-EPGP%-\n(.*)\n\%-EPGP%-")
	t.roster_info = {}
	for name,info in pairs(tCache) do
		table.insert(t.roster_info, {name, info.eClass, info.strNote})
	end
end

--
-- Event handlers
--

 -- Use ICCommLib here
	 ---- 3 Reasons not to yet:
	 	-- 1) ICCommLib does not yet support GUILD channels
	 	-- 2) Only local storage anyway
	 	-- 3) As of 5/01/14 ICCommLib events don't work when handled by packages.

function Lib:OnStorageComm(channel, tMsg, strSender)
	glog:debug("OnStorageComm: %s, %d, %s, %s", tMsg.strMajor, tMsg.nVersion, tMsg.strMessage, strSender)
	-- Only Listen to messages from this major version
	if tMsg.strMajor ~= MAJOR then return end  -- Do you receive your own comms?
	if tMsg.strMessage == "CHANGES_PENDING" then
		SetState("REMOTE_FLUSHING")
	elseif tMsg.strMessage == "CHANGES_FLUSHED" then
		SetState("STALE_WAITING_FOR_ROSTER_UPDATE")
	end
end

local function SendState(strState, strChannel)
	if not Lib.channel then return end
	tMsg = {
		strMajor = MAJOR,
		nVersion = MINOR,
		strMessage = strState,
	}
	Lib.channel:SendMessage(tMsg)
end

local i = 1
function Lib:OnGuildLoaded(guildLoaded)
	glog:debug("GuildLoaded")
	i = i + 1
	self:OnGuildChange()

end

function Lib:OnGuildChange()
	glog:debug("GuildChange")
	for key, tGuildItem in pairs(GuildLib.GetGuilds()) do
		if tGuildItem:GetType() == GuildLib.GuildType_Guild then
			if tGuildItem ~= self.tGuild then
				self.tGuild = tGuildItem
				-- Temp Local Saved Data Structure
				self.tNotes[tGuildItem:GetName()] = self.tNotes[tGuildItem:GetName()] or {}
				tCurrentNotes = self.tNotes[tGuildItem:GetName()]
				SetState("STALE_WAITING_FOR_ROSTER_UPDATE")
				Apollo.RegisterEventHandler("VarChange_FrameCount", "OnUpdate", self)
				callbacks:Fire("GuildChanged", tGuildItem)
				return
			end
		end
	end
	-- No Guild Found, stop processing events
	self.tGuild = nil
	Apollo.RemoveEventHandler("VarChange_FrameCount", self)
	callbacks:Fire("GuildChanged", nil)
end

function Lib:OnGuildRoster(guildCurr, tRoster)
	-- Ignore information about Circles
	if self.tGuild ~= guildCurr then return end
	self.tRoster = tRoster
	SetState("STALE")
	nIndex = nil
--[[
	SetState("FLUSHING") -- SetState("STALE_WAITING_FOR_ROSTER_UPDATE")
		-- No way to know what the roster change is, could be someone logging out...
		---  assume its a change we might care about, new person?
	else
		SetState("STALE")
		nIndex = nil
	end
	]]
end

function Lib:OnGuildMemberChange(guildCurr)
	if self.tGuild ~= guildCurr then return end
	-- Someone joined/left need to poll for data
	SetState("FLUSHING")
end

--
-- Locally defined functions
--

local valid_transitions = {
	STALE = {
		CURRENT = true,
		REMOTE_FLUSHING = true,
		STALE_WAITING_FOR_ROSTER_UPDATE = true,
	},
	STALE_WAITING_FOR_ROSTER_UPDATE = {
		ROSTER_REQUEST_PENDING = true,
	},
	ROSTER_REQUEST_PENDING = {
		STALE = true,
		FLUSHING = true,
	},
	CURRENT = {
		FLUSHING = true,
		REMOTE_FLUSHING = true,
--		STALE = true,
	},
	FLUSHING = {
		STALE_WAITING_FOR_ROSTER_UPDATE = true,
--		CURRENT = true,	-- Added as there is no good note change event (since there are no notes ...)
	},
	REMOTE_FLUSHING = {
		STALE_WAITING_FOR_ROSTER_UPDATE = true,
	},
}

function SetState(new_state)
	if state == new_state then return end

	if not valid_transitions[state][new_state] then
		glog:debug("Ignoring state change %s -> %s", state, new_state)
		return
	else
		glog:debug("StateChanged: %s -> %s", state, new_state)
		state = new_state
		if new_state == FLUSHING then
			SendState("CHANGES_PENDING", "GUILD")
		end
		callbacks:Fire("StateChanged")
	end
end

function Lib:OnUpdate()
	local startTime = os.clock()
	-- FirstFrame means setup time!
	if bFirstFrame then
		self:OnGuildChange()
		bFirstFrame = nil
		return
	end

	-- If we are up to date or waiting on a roster then we are done ... for now.
	if state == "CURRENT" or state == "ROSTER_REQUEST_PENDING" then
		return
	end

	if state == "STALE_WAITING_FOR_ROSTER_UPDATE" and self.tGuild then
		SetState("ROSTER_REQUEST_PENDING")
		self.tGuild:RequestMembers()
		return
	end

	local nNumGuildMembers = self.tRoster and #self.tRoster or 0

	if nNumGuildMembers == 0 then
		error("In a guild with no members?!?")
	end

	if not nIndex or nIndex >= nNumGuildMembers then
		nIndex = 1
	end

	-- Read up to 100 members at a time.
	local nLastIndex = math.min(nIndex + 100, nNumGuildMembers)
	if not bInitialized then nLastIndex = nNumGuildMembers end
	glog:debug("Processing from %d to %d members", nIndex, nLastIndex)

	for i = nIndex, nLastIndex do
		local tMember = self.tRoster[i]
		local strName, nRank, eClass = tMember.strName, tMember.nRank, tMember.eClass
		local strNote = tCurrentNotes[strName] or ""

		if strName then
			local tEntry = tCache[strName]
			local strPending = tPendingNote[strName]
			if not tEntry then
				tEntry = {}
				tCache[strName] = tEntry
			end

			tEntry.nRank = nRank
			tEntry.eClass = eClass

			-- Mark this note as seen
			tEntry.bSeen = true
			if tEntry.strNote ~= strNote then
				tEntry.strNote = strNote
				-- We want to delay all GuildNoteChanged calls until we have a
				-- complete view of the guild, otherwise alts might not be
				-- rejected (we read alts note before we even know about the
				-- main).
				if bInitialized then
					callbacks:Fire("GuildNoteChanged", strName, strNote)
				end
				if strPending then
					callbacks:Fire("InconsistentNote", strName, strNote, tEntry.strNote, strPending)
				end
			end

			if strPending then
				-- Officer Note setting mechanism goes here ... for now we just set a variable
				tCurrentNotes[strName] = strPending
				-- self.tGuild:SetOfficerNote(tMember, strPending)
				tPendingNote[strName] = nil
			end
		end
  	end
	nIndex = nLastIndex
	if nIndex >= nNumGuildMembers then
		-- We are done, we need to clear the seen marks and delete the
		-- unmarked entries. We also fire events for removed members now.
		for strName, t in pairs(tCache) do
			if t.bSeen then
				t.bSeen = nil
			else
				tCache[strName] = nil
				callbacks:Fire("GuildNoteDeleted", strName)
			end
		end

		if not bInitialized then
			-- Now make all GuildNoteChanged calls because we have a full
			-- state.
			for strName, t in pairs(tCache) do
				callbacks:Fire("GuildNoteChanged", strName, t.strNote)
			end
			bInitialized = true
			callbacks:Fire("StateChanged")
		end
		if state == "STALE" then
			SetState("CURRENT")
		elseif state == "FLUSHING" then
			if not next(tPendingNote) then
				--SetState("CURRENT")
				SetState("STALE_WAITING_FOR_ROSTER_UPDATE")
				SendState("CHANGES_FLUSHED", "GUILD")
			end
		end
	end
	glog:debug(tostring(os.clock() - startTime).."ms for LibGuildStorage:OnUpdate")
end

function Lib:OnGuildInfoMessage(guildOwner)
	if self.tGuild == guildOwner then
		local strNewGuildInfo = self.tGuild:GetInfoMessage() or ""
		if strNewGuildInfo ~= strGuildInfo then
			strGuildInfo = strNewGuildInfo
			callbacks:Fire("GuildInfoChanged", strGuildInfo)
		end
	end
end

-- Notes are currently saved out ...  not optimal
function Lib:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Realm then
		return
	end
	return self.tNotes
end

function Lib:OnRestore(eLevel, tSavedData)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Realm then
		return
	end
	self.tNotes = tSavedData
end

-- Init code
function Lib:OnLoad()
	local GeminiLogging = Apollo.GetPackage("Gemini:Logging-1.2").tPackage
	glog = glog or GeminiLogging:GetLogger({
		level = GeminiLogging.WARN,
		pattern = "%d %n %c %l - %m",
		appender = "GeminiConsole"
	})
	self.tNotes = {}

	Apollo.RegisterEventHandler("GuildRoster","OnGuildRoster",self)
	Apollo.RegisterEventHandler("GuildInfoMessage", "OnGuildInfoMessage", self)
	Apollo.RegisterEventHandler("GuildLoaded", "OnGuildLoaded", self)
	Apollo.RegisterEventHandler("GuildChange", "OnGuildChange", self)
	Apollo.RegisterEventHandler("GuildMemberChange", "OnGuildMemberChange", self)
--	TODO: ICCommLib setup, see notes above.  Disabled until ICCommLib works for packages and is private...
--	self.channel = ICCommLib.JoinChannel("LibGuildStorage","OnStorageComm",Lib)

	Apollo.RegisterEventHandler("VarChange_FrameCount","OnUpdate",self)
end

-- No required dependencies
function Lib:OnDependencyError(strDep, strError)
	if strDep == "Gemini:Logging-1.2" then
		glog = { debug = function() end }
		return true
	end
	return false
end

Apollo.RegisterPackage(Lib, MAJOR, MINOR, {"Gemini:Logging-1.2","Gemini:CallbackHandler-1.0"})
