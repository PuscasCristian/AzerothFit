-- Saved variables: defaults and loading. One account-wide table, because the
-- fitness belongs to the person, not to a character.
local _, AF = ...

AF.DEFAULTS = {
	version = 1,
	onboarded = false,
	settings = {
		tier = 3,
		gap = 15,
		-- capSets and rounds are nil = use the tier's numbers
		weekGoal = 3, -- training days a week
		quiet = false, -- no jumping
		scale = 1.0, -- text and window size
		trig = { quest = true, level = true, death = false },
		cats = { push = true, legs = true, core = true, cardio = true, stretch = true },
		voice = true,
		sound = true,
		pauseInstances = true,
		share = true,
		tooltip = true,
		snooze = 5,
		rest = 5,
		campfire = true, -- nudge at campfires
		restNudge = false, -- also nudge in inns and cities
		saveForCampfire = false, -- level-up workouts wait for a campfire
		moveEvery = 45, -- stand-up reminder, minutes of play (0 = off)
		flexTo = "SELF",
		minimap = { hide = false, angle = 215 },
		popup = {},
	},
	ex = {
		push = { variant = 3, max = 12, rightStreak = 0 },
		legs = { variant = 3, max = 25, rightStreak = 0 },
		core = { variant = 3, max = 30, rightStreak = 0 },
		cardio = { variant = 3, max = 60, rightStreak = 0 },
		stretch = { variant = 1, max = 30 },
	},
	stats = {
		level = 1, xp = 0, rested = 0,
		sets = 0, skips = 0, seconds = 0, quests = 0, levelUps = 0, deaths = 0,
		daysTrained = 0,
		totals = {}, variantTotals = {}, trials = {},
	},
	today = { day = 0, seconds = 0, sets = 0, stretches = 0 },
	week = { start = 0, days = {}, reached = false },
	rot = 1,
	lastPrompt = 0,
	bank = {},
	peers = {},
	chars = {},
}

local function Fill(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			Fill(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

function AF.LoadDB()
	if type(AzerothFitDB) ~= "table" then AzerothFitDB = {} end
	Fill(AzerothFitDB, AF.DEFAULTS)
	AF.db = AzerothFitDB
	-- One id for the whole account, so other players see all your characters as one person.
	if type(AF.db.profileId) ~= "string" then
		AF.db.profileId = string.format("%06x%06x", math.random(0, 0xFFFFFF), (time() % 0xFFFFFF))
	end
	-- The old daily limit was in minutes; it is now in sets (from the tier).
	AF.db.settings.cap = nil
	-- Gentle start for anyone who hasn't had one yet (from their first training day).
	if not AF.db.rampStart and AF.db.onboarded then
		AF.db.rampStart = AF.db.stats.firstDay or AF.DayNumber()
	end
	-- Forget players not seen for 60 days.
	local cutoff = time() - 60 * 86400
	for name, p in pairs(AF.db.peers) do
		if type(p) ~= "table" or (p.seen or 0) < cutoff then AF.db.peers[name] = nil end
	end
	return AF.db
end

function AF.ResetDB()
	local old = AF.db or {}
	AzerothFitDB = {}
	AF.LoadDB()
	if old.peers then AF.db.peers = old.peers end
	if old.profileId then AF.db.profileId = old.profileId end
	-- Keep the list of characters, but clear what they did.
	for key, ch in pairs(old.chars or {}) do
		AF.db.chars[key] = { name = ch.name, class = ch.class, level = ch.level, seen = ch.seen }
	end
	AF.db.currentChar = old.currentChar
end
