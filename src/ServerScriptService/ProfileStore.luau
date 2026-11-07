--!strict
--[[
	ProfileStore
	Location: ServerScriptService > ProfileStore (ModuleScript)

	Session-locked load and save of one profile record per player. It runs on any
	store with UpdateAsync-style semantics, where a transform returning nil cancels
	the write. PlayerDataService passes in a DataStore, or an in-memory store for
	unpublished Studio places. No Roblox services are used here: the store, clock,
	wait and ids are passed in, so the rules are unit-tested offline.

	Record: { profile = ProfileSchema.Stored, lock = { session, job, at }? }
	  load    claims the lock unless another live session holds it. A lock is live
	          until LockTimeout seconds after its last save, so a crashed server's
	          lock expires. A record that fails ProfileSchema.decode is neither
	          claimed nor overwritten.
	  save    writes only while this session still holds the lock ("LockLost"
	          otherwise, and nothing is written); release also clears the lock.
	Store errors are retried with doubling waits. Every session keeps its own lock,
	including when a later session joins the same server.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local ProfileSchema = require(ServerScriptService:WaitForChild("ProfileSchema"))
local ProfileTransactions = require(ServerScriptService:WaitForChild("ProfileTransactions"))

type Profile = ProfileSchema.Profile

-- update(key, transform, userId) runs transform(oldValue) and writes its result unless it is nil.
export type Store = {
	update: (key: string, transform: (unknown) -> unknown?, userId: number) -> (),
}

export type Options = {
	store: Store,
	job: string, -- game.JobId ("" in Studio, where it is never used to claim a lock)
	now: () -> number, -- seconds, comparable across servers (os.time)
	wait: (seconds: number) -> (),
	lockTimeout: number,
	attempts: number, -- store calls per operation before giving up
	lockedRetries: number, -- extra load rounds while another server still holds the lock
	lockedRetryDelay: number,
}

export type LoadStatus = "Loaded" | "Locked" | "Invalid" | "Error" | "Cancelled"
export type SaveStatus = "Saved" | "LockLost" | "Error"

export type LoadResult = {
	status: LoadStatus,
	profile: Profile?,
	detail: string?,
}

local ProfileStore = {}

local function lockFor(options: Options, session: string): { [string]: unknown }
	return { session = session, job = options.job, at = options.now() }
end

local function canClaim(options: Options, lock: unknown, session: string): boolean
	if typeof(lock) ~= "table" then
		return true -- no lock (or an unreadable one): the profile itself is still validated
	end
	local fields = lock :: { [string]: unknown }
	if fields.session == session then
		return true
	end
	local at = fields.at
	if typeof(at) ~= "number" then
		return true
	end
	return options.now() - (at :: number) >= options.lockTimeout
end

-- Runs one update with retries. Returns false and the last error if every attempt failed.
local function update(options: Options, key: string, userId: number, transform: (unknown) -> unknown?): (boolean, string?)
	local delay = 1
	local lastProblem: string? = nil
	for attempt = 1, options.attempts do
		local ok, problem = pcall(options.store.update, key, transform, userId)
		if ok then
			return true, nil
		end
		lastProblem = tostring(problem)
		if attempt < options.attempts then
			options.wait(delay)
			delay *= 2
		end
	end
	return false, lastProblem
end

function ProfileStore.keyFor(userId: number): string
	return `player_{userId}`
end

--[[
	Loads and claims a player's profile. A missing record becomes a new profile.
	isWanted() is checked between rounds; when it returns false the load stops
	("Cancelled") without claiming anything new.
]]
function ProfileStore.load(options: Options, userId: number, session: string, isWanted: () -> boolean): LoadResult
	local key = ProfileStore.keyFor(userId)
	for round = 1, options.lockedRetries + 1 do
		if not isWanted() then
			return { status = "Cancelled" }
		end
		local status: LoadStatus = "Error"
		local profile: Profile? = nil
		local detail: string? = nil
		local ok, problem = update(options, key, userId, function(old: unknown): unknown?
			profile, detail = nil, nil -- the transform can run more than once
			if old == nil then
				local fresh = ProfileSchema.new()
				status, profile = "Loaded", fresh
				return { profile = ProfileSchema.encode(fresh), lock = lockFor(options, session) }
			end
			if typeof(old) ~= "table" then
				status, detail = "Invalid", "the record is not a table"
				return nil
			end
			local record = old :: { [string]: unknown }
			if not canClaim(options, record.lock, session) then
				status = "Locked"
				return nil
			end
			local decoded, reason = ProfileSchema.decode(record.profile)
			if decoded == nil then
				status, detail = "Invalid", reason
				return nil
			end
			local recovered, recoveryProblem = ProfileTransactions.recover(decoded)
			if recovered == nil then
				status, detail = "Invalid", recoveryProblem
				return nil
			end
			status, profile = "Loaded", recovered
			record.profile = ProfileSchema.encode(recovered)
			record.lock = lockFor(options, session)
			return record
		end)
		if not ok then
			return { status = "Error", detail = problem }
		end
		if status ~= "Locked" then
			return { status = status, profile = profile, detail = detail }
		end
		if round <= options.lockedRetries then
			options.wait(options.lockedRetryDelay)
		end
	end
	return { status = "Locked", detail = "another server still holds this profile" }
end

--[[
	Saves the profile while this session holds the lock. release = true also clears the
	lock. profile = nil keeps the stored profile as it is (used to release a session
	whose state could not be read).
]]
function ProfileStore.save(options: Options, userId: number, session: string, profile: Profile?, release: boolean): (SaveStatus, string?)
	local encoded = if profile then ProfileSchema.encode(profile) else nil
	if encoded ~= nil then
		local validated, reason = ProfileSchema.decode(encoded)
		if validated == nil then
			return "Error", reason
		end
	end
	local status: SaveStatus = "Error"
	local ok, problem = update(options, ProfileStore.keyFor(userId), userId, function(old: unknown): unknown?
		if typeof(old) ~= "table" then
			status = "LockLost"
			return nil
		end
		local record = old :: { [string]: unknown }
		local lock = record.lock
		if typeof(lock) ~= "table" or (lock :: { [string]: unknown }).session ~= session then
			status = "LockLost"
			return nil
		end
		if encoded ~= nil then
			record.profile = encoded
		end
		record.lock = if release then nil else lockFor(options, session)
		status = "Saved"
		return record
	end)
	if not ok then
		return "Error", problem
	end
	return status, nil
end

return ProfileStore
