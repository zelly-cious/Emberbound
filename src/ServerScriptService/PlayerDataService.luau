--!strict
--[[
	PlayerDataService
	Location: ServerScriptService > PlayerDataService (ModuleScript)

	Loads, autosaves and releases each player's versioned profile (ProfileSchema)
	through ProfileStore's session lock. PlayerSessionService calls Load before the
	gameplay services add the player, and Release when the player leaves.

	  - Load failures never fall back to defaults: Load returns nil and a message,
	    and the player is asked to rejoin. Their stored record is left untouched.
	  - A session that loses its lock (another server took over a stale lock) stops
	    saving, so two servers never write the same profile.
	  - Autosave runs every AUTOSAVE_INTERVAL seconds, which also keeps the lock live.
	    Shutdown (BindToClose) releases every remaining session.
	  - Studio: an unpublished place, or one without Studio API access, uses an
	    in-memory store, so saves last only for that test session. Live servers
	    always use the DataStore.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileSchema = require(ServerScriptService:WaitForChild("ProfileSchema"))
local ProfileStore = require(ServerScriptService:WaitForChild("ProfileStore"))

type Profile = ProfileSchema.Profile

type Entry = {
	session: string,
	userId: number,
	profile: Profile,
	revision: number,
	savedRevision: number,
	activityUntil: number,
	lastCountedAt: number,
	saving: boolean,
	state: "Active" | "Releasing" | "Released" | "LockLost",
}

local STORE_NAME = "EmberboundProfiles" -- the schema version is inside each record, not in the store name
local AUTOSAVE_INTERVAL = 60
local ACTIVE_IDLE_WINDOW = 10 -- accepted taps and successful purchases extend this window
local LOCK_TIMEOUT = 300 -- five missed autosaves before another server may take over the lock
local LOAD_FAILED_MESSAGE = "Emberbound could not load your save. Your progress is safe; please rejoin."
local LOCKED_MESSAGE = "Your save is still open on another server. Please wait a moment and rejoin."
local NEWER_MESSAGE = "This server is out of date for your save. Please rejoin to join a newer server."
local LOCK_LOST_MESSAGE = "Your save was opened on another server. Please rejoin."
local SHUTDOWN_WAIT = 25 -- seconds BindToClose waits for releases (Roblox allows 30)

local entries: { [Player]: Entry } = {}
local releasing: { [number]: number } = {} -- userId -> releases in flight on this server
local options: ProfileStore.Options? = nil
local initializingOptions = false
local snapshotProvider: ((Player) -> Profile?)? = nil
local started = false

local PlayerDataService = {}

local function memoryStore(): ProfileStore.Store
	local records: { [string]: string } = {}
	return {
		update = function(key: string, transform: (unknown) -> unknown?, _userId: number)
			local stored = records[key]
			local old = if stored ~= nil then HttpService:JSONDecode(stored) else nil
			local new = transform(old)
			if new ~= nil then
				records[key] = HttpService:JSONEncode(new) -- the same JSON round trip a DataStore applies
			end
		end,
	}
end

local function dataStore(store: DataStore): ProfileStore.Store
	return {
		update = function(key: string, transform: (unknown) -> unknown?, userId: number)
			store:UpdateAsync(key, function(old: unknown): (unknown?, { number }?)
				local new = transform(old)
				if new == nil then
					return nil, nil -- cancels the write
				end
				return new, { userId } -- tags the key with the player for erasure requests
			end)
		end,
	}
end

local function chooseStore(): ProfileStore.Store
	if not RunService:IsStudio() then
		return dataStore(DataStoreService:GetDataStore(STORE_NAME))
	end
	if game.PlaceId ~= 0 then
		local ok = pcall(function()
			local store = DataStoreService:GetDataStore(STORE_NAME)
			store:GetAsync("studio_access_check")
		end)
		if ok then
			print("[PlayerDataService] Studio is using the place's DataStore: saves persist.")
			return dataStore(DataStoreService:GetDataStore(STORE_NAME))
		end
	end
	print("[PlayerDataService] Studio without DataStore access: saves are kept in memory for this test session only.")
	return memoryStore()
end

local function getOptions(): ProfileStore.Options
	while initializingOptions do
		task.wait(0.1)
	end
	if options == nil then
		initializingOptions = true
		local ok, selected = pcall(chooseStore)
		initializingOptions = false
		if not ok then
			error(selected)
		end
		options = {
			store = selected,
			job = game.JobId,
			now = function(): number
				return os.time()
			end,
			wait = function(seconds: number)
				task.wait(seconds)
			end,
			lockTimeout = LOCK_TIMEOUT,
			attempts = 4,
			lockedRetries = 6,
			lockedRetryDelay = 5,
		}
	end
	return options :: ProfileStore.Options
end

local function failureMessage(result: ProfileStore.LoadResult): string
	if result.status == "Locked" then
		return LOCKED_MESSAGE
	end
	if result.status == "Invalid" and result.detail ~= nil and string.find(result.detail, "newer", 1, true) then
		return NEWER_MESSAGE
	end
	return LOAD_FAILED_MESSAGE
end

local function save(player: Player, entry: Entry, profile: Profile?, release: boolean): ProfileStore.SaveStatus
	while entry.saving do
		task.wait(0.1) -- one write per player at a time; a release waits for an autosave in flight
	end
	if entry.state == "LockLost" or entry.state == "Released" then
		return if entry.state == "Released" then "Saved" else "LockLost"
	end
	entry.saving = true
	local revision = entry.revision
	local ok, status, detail = pcall(function()
		return ProfileStore.save(getOptions(), entry.userId, entry.session, profile, release)
	end)
	entry.saving = false
	if not ok then
		warn(`[PlayerDataService] Save for {player.Name} raised an error: {status}`)
		return "Error"
	end
	if status == "LockLost" then
		entry.state = "LockLost"
		warn(`[PlayerDataService] {player.Name}'s save was taken over by another server; this server stops saving it.`)
		if player.Parent == Players then
			player:Kick(LOCK_LOST_MESSAGE)
		end
	elseif status == "Error" then
		warn(`[PlayerDataService] Could not save {player.Name}: {detail}`)
	elseif release then
		entry.state = "Released"
	end
	if status == "Saved" then
		entry.savedRevision = revision
	end
	return status
end

--[[
	Loads and claims the player's profile. Yields. Returns the profile, or nil and the message
	to show when the player must rejoin. isWanted() lets the caller cancel (the player left).
]]
function PlayerDataService.Load(player: Player, isWanted: () -> boolean): (Profile?, string?)
	local userId = player.UserId
	local waited = 0
	while (releasing[userId] or 0) > 0 and waited < SHUTDOWN_WAIT and isWanted() do
		task.wait(0.25) -- the same player's previous session on this server is still saving
		waited += 0.25
	end
	if not isWanted() then
		return nil, LOAD_FAILED_MESSAGE
	end
	if (releasing[userId] or 0) > 0 then
		return nil, LOCKED_MESSAGE
	end
	local session = HttpService:GenerateGUID(false)
	local ok, result = pcall(function()
		return ProfileStore.load(getOptions(), userId, session, isWanted)
	end)
	if not ok then
		warn(`[PlayerDataService] Loading {player.Name}'s profile raised an error: {result}`)
		return nil, LOAD_FAILED_MESSAGE
	end
	local loaded = result :: ProfileStore.LoadResult
	if loaded.status ~= "Loaded" or loaded.profile == nil then
		if loaded.status ~= "Cancelled" then
			warn(`[PlayerDataService] Could not load {player.Name}'s profile ({loaded.status}): {loaded.detail or "no detail"}`)
		end
		return nil, failureMessage(loaded)
	end
	entries[player] = {
		session = session,
		userId = userId,
		profile = loaded.profile,
		revision = 0,
		savedRevision = 0,
		activityUntil = os.clock(),
		lastCountedAt = os.clock(),
		saving = false,
		state = "Active",
	}
	return loaded.profile, nil
end

-- Saves the final profile (nil keeps the stored one) and releases the lock. Does not yield.
function PlayerDataService.Release(player: Player, profile: Profile?)
	local entry = entries[player]
	if entry == nil then
		return
	end
	entries[player] = nil
	if entry.state ~= "Active" then
		return -- the lock was lost: nothing may be written
	end
	entry.state = "Releasing"
	releasing[entry.userId] = (releasing[entry.userId] or 0) + 1
	local function finishRelease()
		if save(player, entry, profile, true) == "Error" then
			task.delay(5, finishRelease)
			return
		end
		local remaining = (releasing[entry.userId] or 1) - 1
		releasing[entry.userId] = if remaining > 0 then remaining else nil
	end
	task.spawn(finishRelease)
end

function PlayerDataService.HasProfile(player: Player): boolean
	return entries[player] ~= nil
end

function PlayerDataService.MarkDirty(player: Player)
	local entry = entries[player]
	if entry ~= nil and entry.state == "Active" then
		entry.revision += 1
	end
end

function PlayerDataService.IsDirty(player: Player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.revision ~= entry.savedRevision
end

function PlayerDataService.CanMutate(player: Player): boolean
	local entry = entries[player]
	if entry == nil then
		return not started -- standalone service callers remain supported before sessions start
	end
	return entry.state == "Active" and entry.profile.pendingTransaction == nil
		and entry.profile.transactionId < ProfileSchema.MaxInteger
end

-- Complete in-memory operations are checkpointed with their balances/levels. The high-water
-- id survives history pruning; external retryable operations use ProfileTransactions.prepare.
function PlayerDataService.RecordTransaction(player: Player, raw: { [string]: any }): boolean
	local entry = entries[player]
	if entry == nil or not PlayerDataService.CanMutate(player) then
		return false
	end
	local payload = table.clone(raw)
	payload.id = entry.profile.transactionId + 1
	local transaction = ProfileSchema.readTransaction(payload)
	if transaction == nil then
		return false
	end
	entry.profile.transactionId = transaction.id
	table.insert(entry.profile.transactions, transaction)
	if #entry.profile.transactions > ProfileSchema.HistoryLimit then
		table.remove(entry.profile.transactions, 1)
	end
	PlayerDataService.MarkDirty(player)
	return true
end

local function countActiveTime(player: Player, entry: Entry, now: number)
	if now <= entry.lastCountedAt then
		return
	end
	local seconds = math.max(0, math.min(now, entry.activityUntil) - entry.lastCountedAt)
	entry.lastCountedAt = now
	if seconds > 0 then
		entry.profile.activeSeconds = math.min(ProfileSchema.MaxInteger, entry.profile.activeSeconds + seconds)
		PlayerDataService.MarkDirty(player)
	end
end

function PlayerDataService.RecordActivity(player: Player)
	local entry = entries[player]
	if entry == nil or entry.state ~= "Active" then
		return
	end
	local now = os.clock()
	countActiveTime(player, entry, now)
	entry.activityUntil = math.max(entry.activityUntil, now + ACTIVE_IDLE_WINDOW)
end

-- Saved metadata is retained when the session snapshots the live gameplay services.
function PlayerDataService.CopyMetadata(player: Player): Profile?
	local entry = entries[player]
	if entry == nil or entry.state ~= "Active" then
		return nil
	end
	countActiveTime(player, entry, os.clock())
	return ProfileSchema.copy(entry.profile)
end

function PlayerDataService.GetProfile(player: Player): Profile?
	local provider = snapshotProvider
	return if provider then provider(player) else PlayerDataService.CopyMetadata(player)
end

local function autosave()
	local provider = snapshotProvider
	if provider ~= nil then
		for player, entry in entries do
			if entry.state == "Active" and not entry.saving then
				local profile = provider(player)
				if profile ~= nil then
					task.spawn(save, player, entry, profile, false)
				end
			end
		end
	end
	task.delay(AUTOSAVE_INTERVAL, autosave)
end

--[[
	Starts autosave and the shutdown save. provider(player) returns the player's current
	profile, read from the gameplay services in one non-yielding step (nil if not ready).
]]
function PlayerDataService.Start(provider: (Player) -> Profile?)
	if started then
		warn("[PlayerDataService] Start() was called more than once; ignoring.")
		return
	end
	started = true
	snapshotProvider = provider
	task.delay(AUTOSAVE_INTERVAL, autosave)
	game:BindToClose(function()
		for player in entries do
			PlayerDataService.Release(player, provider(player))
		end
		local deadline = os.clock() + SHUTDOWN_WAIT
		while next(releasing) ~= nil and os.clock() < deadline do
			task.wait(0.25)
		end
	end)
end

return PlayerDataService
