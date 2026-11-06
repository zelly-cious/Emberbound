--!strict
--[[
	RateLimiter
	Location: ServerScriptService > RateLimiter (ModuleScript)

	Token bucket per key (usually a Player): a key may make `capacity` requests
	back to back, then `refillPerSecond` requests per second. Tokens refill
	lazily when a request arrives, so there are no loops or timers. The clock
	can be injected so tests are deterministic. Reusable by future remotes
	(summons, hero actions).
]]

type Bucket = {
	tokens: number,
	updatedAt: number,
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		capacity: number,
		refillPerSecond: number,
		clock: () -> number,
		buckets: { [any]: Bucket },
	},
	RateLimiter
))

function RateLimiter.new(capacity: number, refillPerSecond: number, clock: (() -> number)?): RateLimiter
	assert(capacity >= 1, "RateLimiter: capacity must be >= 1")
	assert(refillPerSecond > 0, "RateLimiter: refillPerSecond must be > 0")
	return setmetatable({
		capacity = capacity,
		refillPerSecond = refillPerSecond,
		clock = clock or os.clock,
		buckets = {},
	}, RateLimiter)
end

-- Consumes one token for this key. Returns false (consuming nothing) when the key is over its limit.
function RateLimiter.allow(self: RateLimiter, key: any): boolean
	local now = self.clock()
	local bucket = self.buckets[key]
	if bucket == nil then
		bucket = { tokens = self.capacity, updatedAt = now }
		self.buckets[key] = bucket
	else
		local elapsed = math.max(now - bucket.updatedAt, 0)
		bucket.tokens = math.min(self.capacity, bucket.tokens + elapsed * self.refillPerSecond)
		bucket.updatedAt = now
	end
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

-- Forgets a key (call when a player leaves) so the table never grows without bound.
function RateLimiter.remove(self: RateLimiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
