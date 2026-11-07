--!strict
--[[
	ProfileStoreTests
	Location: ServerScriptService > Tests > ProfileStoreTests (ModuleScript)

	Session-lock rules on an in-memory store (no DataStore is touched): claiming,
	overlapping servers, stale locks, lost locks, store errors and retries, and
	damaged records that must never be claimed or overwritten.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local ProgressionConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionConfig"))
local ProfileSchema = require(ServerScriptService:WaitForChild("ProfileSchema"))
local ProfileStore = require(ServerScriptService:WaitForChild("ProfileStore"))
local TestKit = require(script.Parent:WaitForChild("TestKit"))

local expectEqual = TestKit.expectEqual
local expectTrue = TestKit.expectTrue
local expectNil = TestKit.expectNil

local GOLD = ProgressionConfig.GoldCurrencyId
local USER = 42
local KEY = ProfileStore.keyFor(USER)
local LOCK_TIMEOUT = 300

type World = {
	records: { [string]: any },
	clock: number,
	waits: { number },
	failNext: number,
	calls: number,
	beforeTransform: (() -> ())?,
}

local function copy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value do
		result[key] = copy(item)
	end
	return result
end

local function newWorld(): World
	return { records = {}, clock = 1000, waits = {}, failNext = 0, calls = 0, beforeTransform = nil }
end

-- One server's view of the shared store: its own job id, the shared records and clock.
local function server(world: World, job: string): ProfileStore.Options
	return {
		store = {
			update = function(key: string, transform: (unknown) -> unknown?, _userId: number)
				world.calls += 1
				if world.failNext > 0 then
					world.failNext -= 1
					error("injected store failure", 0)
				end
				local hook = world.beforeTransform
				if hook then
					hook()
				end
				local new = transform(copy(world.records[key]))
				if new ~= nil then
					world.records[key] = copy(new)
				end
			end,
		},
		job = job,
		now = function(): number
			return world.clock
		end,
		wait = function(seconds: number)
			table.insert(world.waits, seconds)
			world.clock += seconds
		end,
		lockTimeout = LOCK_TIMEOUT,
		attempts = 4,
		lockedRetries = 2,
		lockedRetryDelay = 5,
	}
end

local function always(): boolean
	return true
end

local function withGold(amount: number): ProfileSchema.Profile
	local profile = ProfileSchema.new()
	profile.currencies[GOLD] = BigNum.fromNumber(amount)
	return profile
end

local function storedGold(world: World): string?
	local record = world.records[KEY]
	return record and record.profile and record.profile.currencies[GOLD]
end

local tests: { TestKit.TestCase } = {
	{
		name = "a first load creates a new profile and locks it",
		run = function()
			local world = newWorld()
			local result = ProfileStore.load(server(world, "A"), USER, "s1", always)
			expectEqual(result.status, "Loaded")
			expectEqual(BigNum.toString((result.profile :: ProfileSchema.Profile).currencies[GOLD]), "0")
			local record = world.records[KEY]
			expectEqual(record.lock.session, "s1")
			expectEqual(record.lock.job, "A")
			expectEqual(record.profile.v, ProfileSchema.Version)
		end,
	},
	{
		name = "save writes the profile and refreshes the lock; release clears it",
		run = function()
			local world = newWorld()
			local a = server(world, "A")
			ProfileStore.load(a, USER, "s1", always)
			world.clock += 60
			expectEqual(ProfileStore.save(a, USER, "s1", withGold(25), false), "Saved")
			expectEqual(storedGold(world), "25")
			expectEqual(world.records[KEY].lock.at, 1060)
			expectEqual(ProfileStore.save(a, USER, "s1", withGold(30), true), "Saved")
			expectEqual(storedGold(world), "30")
			expectNil(world.records[KEY].lock, "released")
			local again = ProfileStore.load(a, USER, "s2", always)
			expectEqual(again.status, "Loaded")
			expectEqual(BigNum.toString((again.profile :: ProfileSchema.Profile).currencies[GOLD]), "30")
		end,
	},
	{
		name = "another server cannot load a live profile and writes nothing",
		run = function()
			local world = newWorld()
			ProfileStore.load(server(world, "A"), USER, "s1", always)
			ProfileStore.save(server(world, "A"), USER, "s1", withGold(25), false)
			local before = copy(world.records[KEY])
			local result = ProfileStore.load(server(world, "B"), USER, "s2", always)
			expectEqual(result.status, "Locked")
			expectNil(result.profile, "no profile is handed out")
			expectEqual(#world.waits, 2, "two retry rounds")
			expectEqual(world.records[KEY].lock.session, before.lock.session)
			expectEqual(storedGold(world), "25")
		end,
	},
	{
		name = "a load waiting on another server succeeds once that server releases",
		run = function()
			local world = newWorld()
			local a = server(world, "A")
			ProfileStore.load(a, USER, "s1", always)
			local b = server(world, "B")
			local realWait = b.wait
			b.wait = function(seconds: number)
				realWait(seconds)
				ProfileStore.save(a, USER, "s1", withGold(77), true) -- server A finishes leaving
			end
			local result = ProfileStore.load(b, USER, "s2", always)
			expectEqual(result.status, "Loaded")
			expectEqual(BigNum.toString((result.profile :: ProfileSchema.Profile).currencies[GOLD]), "77")
			expectEqual(world.records[KEY].lock.session, "s2")
		end,
	},
	{
		name = "a stale lock is taken over, and the old session can no longer save",
		run = function()
			local world = newWorld()
			local a = server(world, "A")
			ProfileStore.load(a, USER, "s1", always)
			ProfileStore.save(a, USER, "s1", withGold(10), false)
			world.clock += LOCK_TIMEOUT
			local result = ProfileStore.load(server(world, "B"), USER, "s2", always)
			expectEqual(result.status, "Loaded")
			expectEqual(BigNum.toString((result.profile :: ProfileSchema.Profile).currencies[GOLD]), "10")
			ProfileStore.save(server(world, "B"), USER, "s2", withGold(500), false)
			expectEqual(ProfileStore.save(a, USER, "s1", withGold(999), false), "LockLost")
			expectEqual(ProfileStore.save(a, USER, "s1", withGold(999), true), "LockLost")
			expectEqual(storedGold(world), "500", "the old session wrote nothing")
			expectEqual(world.records[KEY].lock.session, "s2")
		end,
	},
	{
		name = "one second before the timeout the lock is still live",
		run = function()
			local world = newWorld()
			ProfileStore.load(server(world, "A"), USER, "s1", always)
			-- The two 5 s retry waits bring the lock's age to timeout - 1 on the last round.
			world.clock += LOCK_TIMEOUT - 1 - 10
			local options = server(world, "B")
			local result = ProfileStore.load(options, USER, "s2", always)
			expectEqual(result.status, "Locked")
		end,
	},
	{
		name = "this server's own unreleased session is reclaimed at once",
		run = function()
			local world = newWorld()
			ProfileStore.load(server(world, "A"), USER, "s1", always)
			local result = ProfileStore.load(server(world, "A"), USER, "s2", always)
			expectEqual(result.status, "Loaded")
			expectEqual(world.records[KEY].lock.session, "s2")
			expectEqual(#world.waits, 0)
			-- Studio's empty JobId never counts as the same server.
			local studio = newWorld()
			ProfileStore.load(server(studio, ""), USER, "s1", always)
			expectEqual(ProfileStore.load(server(studio, ""), USER, "s2", always).status, "Locked")
		end,
	},
	{
		name = "store errors are retried with doubling waits, then reported",
		run = function()
			local world = newWorld()
			world.failNext = 2
			local result = ProfileStore.load(server(world, "A"), USER, "s1", always)
			expectEqual(result.status, "Loaded")
			expectEqual(table.concat(world.waits, ","), "1,2")
			local failing = newWorld()
			failing.failNext = 10
			local failed = ProfileStore.load(server(failing, "A"), USER, "s1", always)
			expectEqual(failed.status, "Error")
			expectEqual(failing.calls, 4)
			expectTrue(string.find(failed.detail or "", "injected", 1, true) ~= nil, "the error is reported")
			expectNil(failing.records[KEY], "nothing was written")
			failing.failNext = 0
			expectEqual(ProfileStore.load(server(failing, "A"), USER, "s1", always).status, "Loaded")
			failing.failNext = 10
			local status = ProfileStore.save(server(failing, "A"), USER, "s1", withGold(5), false)
			expectEqual(status, "Error")
			expectEqual(storedGold(failing), "0")
		end,
	},
	{
		name = "a damaged or newer record is neither claimed nor overwritten",
		run = function()
			local damaged: { [string]: any } = {
				notTable = "garbage",
				badGold = { profile = { v = 1, currencies = { [GOLD] = "-1" }, stage = 1, upgrades = {} } },
				newer = { profile = { v = ProfileSchema.Version + 1, currencies = {}, stage = 1, upgrades = {} } },
				noProfile = {},
			}
			for label, record in damaged do
				local world = newWorld()
				world.records[KEY] = copy(record)
				local result = ProfileStore.load(server(world, "A"), USER, "s1", always)
				expectEqual(result.status, "Invalid", label)
				expectTrue(typeof(result.detail) == "string", `{label}: a reason is given`)
				local after = world.records[KEY]
				if typeof(record) == "table" then
					expectNil(after.lock, `{label}: not claimed`)
				else
					expectEqual(after, record, `{label}: unchanged`)
				end
				expectEqual(ProfileStore.save(server(world, "A"), USER, "s1", withGold(5), true), "LockLost", `{label}: cannot be overwritten`)
			end
		end,
	},
	{
		name = "a cancelled load claims nothing",
		run = function()
			local world = newWorld()
			local result = ProfileStore.load(server(world, "A"), USER, "s1", function(): boolean
				return false
			end)
			expectEqual(result.status, "Cancelled")
			expectEqual(world.calls, 0)
			-- Cancelled while waiting on another server's lock: no further store calls.
			ProfileStore.load(server(world, "A"), USER, "s1", always)
			local wanted = true
			local b = server(world, "B")
			b.wait = function(_seconds: number)
				wanted = false
			end
			local before = world.calls
			local waiting = ProfileStore.load(b, USER, "s2", function(): boolean
				return wanted
			end)
			expectEqual(waiting.status, "Cancelled")
			expectEqual(world.calls - before, 1)
		end,
	},
	{
		name = "release without a profile keeps the stored profile and clears the lock",
		run = function()
			local world = newWorld()
			local a = server(world, "A")
			ProfileStore.load(a, USER, "s1", always)
			ProfileStore.save(a, USER, "s1", withGold(40), false)
			expectEqual(ProfileStore.save(a, USER, "s1", nil, true), "Saved")
			expectEqual(storedGold(world), "40")
			expectNil(world.records[KEY].lock, "released")
		end,
	},
	{
		name = "a transform that runs twice (a store conflict retry) reports its last run",
		run = function()
			local world = newWorld()
			ProfileStore.load(server(world, "A"), USER, "s1", always)
			local b = server(world, "B")
			local realUpdate = b.store.update
			b.store = {
				update = function(key: string, transform: (unknown) -> unknown?, userId: number)
					transform(copy(world.records[key])) -- first run sees A's live lock
					world.records[key].lock = nil -- A releases before the store retries
					realUpdate(key, transform, userId)
				end,
			}
			local result = ProfileStore.load(b, USER, "s2", always)
			expectEqual(result.status, "Loaded")
			expectEqual(world.records[KEY].lock.session, "s2")
		end,
	},
	{
		name = "players' records are independent",
		run = function()
			local world = newWorld()
			local a = server(world, "A")
			ProfileStore.load(a, 1, "s1", always)
			ProfileStore.load(a, 2, "s2", always)
			ProfileStore.save(a, 1, "s1", withGold(11), true)
			expectEqual(world.records[ProfileStore.keyFor(1)].profile.currencies[GOLD], "11")
			expectEqual(world.records[ProfileStore.keyFor(2)].profile.currencies[GOLD], "0")
			expectEqual(world.records[ProfileStore.keyFor(2)].lock.session, "s2")
			expectEqual(ProfileStore.save(a, 2, "s1", withGold(99), false), "LockLost", "another player's session cannot write")
		end,
	},
}

return {
	name = "ProfileStoreTests",
	tests = tests,
}
