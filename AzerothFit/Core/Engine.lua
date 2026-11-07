-- The workout math. Pure functions over the saved-variables table, no UI and
-- no game events, so it can be tested outside the game.
--
-- Rules, in short:
--   * Every exercise has your "max": how many reps (or seconds) you can do in one go.
--   * A quest snack asks snackPct of your max, a level-up workout levelPct per set.
--   * For the first two weeks (and after 10+ days off) sets start at 70% and build up.
--   * Snacks are at least `gap` minutes apart, and a day stops at `capSets` sets.
--     Stretches never count toward that limit.
--   * A training day is a day with 3 or more sets; the weekly goal counts training days.
--   * "Too easy" raises your max 8%, "Too hard" lowers it 10%, and every fourth
--     "Just right" adds one rep (or 5 seconds). A max never rises more than 10%
--     in a week (5% from "Just right" alone), so progress stays safe.
--   * Fitness XP = seconds of work + 50 per set. Days off fill a rested pool
--     (300 per day, up to 1500) that doubles XP on your comeback.
local _, AF = ...

local E = {}
AF.Engine = E

local floor, max, min, ceil = math.floor, math.max, math.min, math.ceil

E.MAX_LEVEL = 60
E.XP_PER_SET = 50
E.XP_TRIAL = 250
E.XP_CIRCUIT_BONUS = 100
E.XP_WEEK_GOAL = 300
E.RESTED_PER_DAY = 300
E.RESTED_MAX = 1500
E.WEEKLY_GROWTH = 0.10 -- limit when you say "Too easy"
E.WEEKLY_GROWTH_STEADY = 0.05 -- limit from "Just right" answers alone
E.SET_OVERHEAD = 10 -- seconds to get into position
E.RIGHT_STREAK = 4
E.HARD_STREAK = 2 -- this many "Too hard" in a row offers an easier exercise
E.RAMP_DAYS = 14
E.RAMP_START = 0.70
E.RAMP_RESTART = 10 -- days off that restart the gentle start
E.TRAINING_DAY_SETS = 3

function E.XPToNext(level)
	return 1000 + 100 * (level - 1)
end

function E.Tier(db)
	return AF.Tiers[db.settings.tier] or AF.Tiers[3]
end

function E.Rounds(db)
	return db.settings.rounds or E.Tier(db).rounds
end

function E.CapSets(db)
	return db.settings.capSets or E.Tier(db).capSets
end

function E.Variant(db, cat)
	local st = db.ex[cat]
	local ladder = AF.Ladders[cat]
	return ladder[st.variant] or ladder[1], st
end

function E.TitleFor(level)
	local title = AF.Titles[1][2]
	for _, t in ipairs(AF.Titles) do
		if level >= t[1] then title = t[2] end
	end
	return title
end

function E.NextTitle(level)
	for _, t in ipairs(AF.Titles) do
		if t[1] > level then return t[1], t[2] end
	end
end

-- Gentle start: 70% on day one, full strength after two weeks.
function E.Ramp(db, day)
	local start = db.rampStart
	if not start or not day then return 1 end
	local d = day - start
	if d < 0 or d >= E.RAMP_DAYS then return 1 end
	return E.RAMP_START + (1 - E.RAMP_START) * d / E.RAMP_DAYS
end

-- How much to ask for, from a max and a share of it.
function E.Amount(maxValue, pct, unit)
	if unit == "seconds" then
		return max(10, floor(maxValue * pct / 5 + 0.5) * 5)
	end
	return max(2, floor(maxValue * pct + 0.5))
end

function E.WorkSeconds(amount, def)
	if def.unit == "seconds" then return amount end
	return amount * (def.sec or 3)
end

local function Build(cat, def, amount, extra)
	local work = E.WorkSeconds(amount, def)
	local set = {
		cat = cat, id = def.id, name = def.name, unit = def.unit, cue = def.cue,
		amount = amount, work = work, est = work + E.SET_OVERHEAD,
	}
	for k, v in pairs(extra or {}) do set[k] = v end
	return set
end

-- One stretch from the rotation (they take turns, no progression).
function E.StretchSet(db)
	local st = db.ex.stretch
	local list = AF.Ladders.stretch
	local idx = ((st.variant or 1) - 1) % #list + 1
	st.variant = idx % #list + 1
	local def = list[idx]
	local hold = def.startMax
	if E.Tier(db).key == "peon" then hold = hold - 10 end
	return Build("stretch", def, hold, { variant = idx, vkey = "stretch#" .. def.id, stretch = true })
end

function E.MakeSet(db, cat, pct, day)
	if cat == "stretch" then return E.StretchSet(db) end
	local def, st = E.Variant(db, cat)
	local extra = { variant = st.variant, vkey = cat .. "#" .. st.variant }
	local amountDef = def
	if db.settings.quiet and def.loud and def.quiet then
		-- Quiet mode: same effort, no jumping.
		def = AF.Ladders[cat][def.quiet]
		extra.quiet = true
	end
	local amount = E.Amount(st.max, pct * E.Ramp(db, day), amountDef.unit)
	return Build(cat, def, amount, extra)
end

-- "Swap": the alternatives for a set, skipping the one on screen and noisy ones in quiet mode.
function E.SwapOptions(db, set)
	local out = {}
	for i, def in ipairs(AF.Alternates[set.cat] or {}) do
		if def.id ~= set.id and not (db.settings.quiet and def.loud) then out[#out + 1] = i end
	end
	return out
end

function E.AltSet(db, cat, index, pct, day)
	local def = AF.Alternates[cat][index]
	local tier = E.Tier(db)
	local amount = E.Amount(def.startMax * (tier.altScale or 1), pct * E.Ramp(db, day), def.unit)
	return Build(cat, def, amount, { variant = db.ex[cat].variant, vkey = "alt#" .. def.id, swapped = true, why = def.why })
end

function E.EnabledCats(db)
	local list = {}
	for _, cat in ipairs(AF.Categories) do
		if db.settings.cats[cat] then list[#list + 1] = cat end
	end
	return list
end

-- Next category in the tier's rotation (low tiers mix in stretches).
function E.NextCategory(db)
	local rot = E.Tier(db).rotation or AF.Categories
	local n = #rot
	for i = 0, n - 1 do
		local idx = ((db.rot - 1 + i) % n) + 1
		local cat = rot[idx]
		if db.settings.cats[cat] then
			db.rot = (idx % n) + 1
			return cat
		end
	end
end

function E.SnackPlan(db, cat, day)
	local tier = E.Tier(db)
	local steps = {}
	for i = 1, (cat and 1 or tier.snackSets or 1) do
		local c = cat or E.NextCategory(db)
		if not c then break end
		if i == 1 or c ~= steps[1].cat then
			steps[#steps + 1] = E.MakeSet(db, c, tier.snackPct, day)
		end
	end
	if #steps == 0 then return nil end
	return { kind = "snack", steps = steps }
end

-- Stretches only: for rest days, after a goal, and stand-up reminders.
function E.StretchPlan(db, count)
	local steps = {}
	for _ = 1, count or 1 do steps[#steps + 1] = E.StretchSet(db) end
	return { kind = "stretch", steps = steps }
end

-- Rounds of push, legs and core at levelPct, a cardio finisher, and for low tiers a cooldown stretch.
function E.LevelUpPlan(db, day)
	local tier = E.Tier(db)
	local rounds = E.Rounds(db)
	local steps = {}
	local strength = {}
	for _, cat in ipairs({ "push", "legs", "core" }) do
		if db.settings.cats[cat] then strength[#strength + 1] = cat end
	end
	for r = 1, rounds do
		for _, cat in ipairs(strength) do
			local set = E.MakeSet(db, cat, tier.levelPct, day)
			set.round = r
			steps[#steps + 1] = set
		end
	end
	if db.settings.cats.cardio then
		local set = E.MakeSet(db, "cardio", tier.snackPct, day)
		set.round = rounds
		set.finisher = true
		steps[#steps + 1] = set
	end
	if tier.cooldown and db.settings.cats.stretch then
		local set = E.StretchSet(db)
		set.round = rounds
		set.cooldown = true
		steps[#steps + 1] = set
	end
	if #steps == 0 then return nil end
	return { kind = "levelup", rounds = rounds, steps = steps }
end

-- Trial of Strength: test your max on push and legs.
function E.TrialPlan(db)
	local steps = {}
	for _, cat in ipairs({ "push", "legs" }) do
		if db.settings.cats[cat] then
			local def, st = E.Variant(db, cat)
			steps[#steps + 1] = {
				cat = cat, id = def.id, variant = st.variant, name = def.name, unit = def.unit,
				cue = def.cue, trial = true, previous = st.max, amount = st.max,
				work = 0, est = 60,
			}
		end
	end
	if #steps == 0 then return nil end
	return { kind = "trial", steps = steps }
end

function E.PlanSeconds(plan)
	local s = 0
	for _, step in ipairs(plan.steps) do s = s + step.est end
	return s
end

-- Weeks start on Monday. Day numbers count from 1970-01-01, a Thursday.
function E.WeekStart(day)
	return day - ((day + 3) % 7)
end

function E.WeekRollover(db, day)
	local ws = E.WeekStart(day)
	if db.week.start ~= ws then
		db.week.start = ws
		db.week.days = {}
		db.week.reached = false
	end
end

function E.WeekCount(db)
	local n = 0
	for _ in pairs(db.week.days) do n = n + 1 end
	return n
end

function E.WeekGoal(db)
	return db.settings.weekGoal or 3
end

function E.WeekGoalReached(db)
	return E.WeekCount(db) >= E.WeekGoal(db)
end

-- Day rollover: reset today's counters, fill the rested pool for missed days,
-- and restart the gentle start after a long break.
function E.Rollover(db, day)
	E.WeekRollover(db, day)
	local today = db.today
	if today.day == day then return false end
	local last = db.stats.lastActiveDay
	if last and day > last + 1 then
		local missedSinceCheck = day - max(last, db.stats.restedCheckedDay or last) - 1
		if missedSinceCheck > 0 then
			db.stats.rested = min(E.RESTED_MAX, db.stats.rested + E.RESTED_PER_DAY * missedSinceCheck)
		end
		db.stats.restedCheckedDay = day - 1
	end
	if last and day - last >= E.RAMP_RESTART then
		db.rampStart = day
	end
	today.day = day
	today.seconds = 0
	today.sets = 0
	today.stretches = 0
	return true
end

function E.CapReached(db)
	return db.today.sets >= E.CapSets(db)
end

-- Done for now: today's limit or this week's goal is reached. Nudges then only
-- suggest a stretch or a short walk, never another workout.
function E.DoneForNow(db)
	return E.CapReached(db) or E.WeekGoalReached(db)
end

function E.Paused(db, day)
	return db.pauseDay ~= nil and db.pauseDay == day
end

-- Can a quest snack be offered right now? Returns ok, reason.
function E.CanSnack(db, now, day)
	if day and E.Paused(db, day) then return false, "paused" end
	if E.CapReached(db) then return false, "cap" end
	if now - (db.lastPrompt or 0) < db.settings.gap * 60 then return false, "gap" end
	if E.BreakLeft(db, now) > 0 then return false, "break" end
	return true
end

-- Seconds left of the break after the last workout closed (level-up, snack, anything).
function E.BreakLeft(db, now)
	return math.max(0, (db.lastWorkoutEnd or 0) + (db.settings.rest or 5) * 60 - now)
end


function E.AddXP(db, amount)
	local st = db.stats
	local gained = 0
	local levels = 0
	if st.level >= E.MAX_LEVEL then
		st.xp = st.xp + amount
		return amount, 0
	end
	st.xp = st.xp + amount
	gained = amount
	while st.level < E.MAX_LEVEL and st.xp >= E.XPToNext(st.level) do
		st.xp = st.xp - E.XPToNext(st.level)
		st.level = st.level + 1
		levels = levels + 1
	end
	return gained, levels
end

local function MarkActive(db, day)
	local st = db.stats
	if st.lastActiveDay ~= day then
		st.daysTrained = st.daysTrained + 1
		st.lastActiveDay = day
		st.restedCheckedDay = day
		st.firstDay = st.firstDay or day
	end
end

-- Record a finished set. Returns xp, restedBonus, levelsGained, weekGoalJustReached.
function E.CompleteSet(db, set, day)
	-- A session that runs past midnight: start the new day's counters first.
	E.Rollover(db, day)
	local st = db.stats
	local key = set.cat .. ":" .. set.unit
	st.totals[key] = (st.totals[key] or 0) + set.amount
	local vkey = set.vkey or (set.cat .. "#" .. (set.variant or 1))
	st.variantTotals[vkey] = (st.variantTotals[vkey] or 0) + set.amount
	st.sets = st.sets + 1
	st.seconds = st.seconds + set.work
	db.today.seconds = db.today.seconds + set.work + E.SET_OVERHEAD
	if set.cat == "stretch" then
		db.today.stretches = (db.today.stretches or 0) + 1 -- stretches never use up the daily limit
	else
		db.today.sets = db.today.sets + 1
	end
	MarkActive(db, day)
	-- Weekly goal: a training day is a day with 3+ sets of anything.
	local goalNow = false
	E.WeekRollover(db, day)
	if not db.week.days[day] and db.today.sets + (db.today.stretches or 0) >= E.TRAINING_DAY_SETS then
		db.week.days[day] = true
		if not db.week.reached and E.WeekGoalReached(db) then
			db.week.reached = true
			goalNow = true
		end
	end
	local ch = E.CurrentChar(db)
	if ch then
		ch.sets = (ch.sets or 0) + 1
		ch.seconds = (ch.seconds or 0) + set.work
		ch[key] = (ch[key] or 0) + set.amount
	end
	local base = set.work + E.XP_PER_SET
	local bonus = min(st.rested, base)
	st.rested = st.rested - bonus
	local xp, levels = E.AddXP(db, base + bonus)
	return xp, bonus, levels, goalNow
end

function E.AwardBonus(db, amount, day)
	MarkActive(db, day)
	return E.AddXP(db, amount)
end

local function Step(unit)
	return unit == "seconds" and 5 or 1
end

local function WeeklyLimit(st, unit, day, growth)
	if not st.weekStart or day - st.weekStart >= 7 then
		st.weekStart = day
		st.weekBase = st.max
	end
	local base = st.weekBase or st.max
	return max(base + Step(unit), ceil(base * (1 + growth)))
end

-- Feedback after a set: "easy", "right" or "hard".
-- Returns oldMax, newMax and a suggestion: "promote", "demote" or nil.
function E.Feedback(db, cat, fb, day)
	if cat == "stretch" then return 0, 0 end
	local variant, st = E.Variant(db, cat)
	st.hardStreak = (fb == "hard") and ((st.hardStreak or 0) + 1) or 0
	local unit = variant.unit
	local step = Step(unit)
	local old = st.max
	local limit = WeeklyLimit(st, unit, day, fb == "easy" and E.WEEKLY_GROWTH or E.WEEKLY_GROWTH_STEADY)
	local new = old
	if fb == "easy" then
		new = max(old + step, ceil(old * 1.08))
		st.rightStreak = 0
	elseif fb == "right" then
		st.rightStreak = (st.rightStreak or 0) + 1
		if st.rightStreak >= E.RIGHT_STREAK then
			new = old + step
			st.rightStreak = 0
		end
	elseif fb == "hard" then
		new = min(old - step, floor(old * 0.9))
		st.rightStreak = 0
	end
	if new > old then new = min(new, limit) end
	if unit == "seconds" then new = floor(new / 5 + 0.5) * 5 end
	new = max(variant.minMax or 1, new)
	if new < old and fb ~= "hard" then new = old end
	st.max = new

	local suggestion
	local ladder = AF.Ladders[cat]
	if variant.promoteAt and new >= variant.promoteAt and ladder[st.variant + 1] then
		suggestion = "promote"
	elseif fb == "hard" and st.variant > 1 and (new <= (variant.minMax or 1) or st.hardStreak >= E.HARD_STREAK) then
		suggestion = "demote"
		st.hardStreak = 0
	end
	return old, new, suggestion
end

-- Move up (+1) or down (-1) a ladder. A new rung starts a little below its usual max.
function E.ChangeVariant(db, cat, delta, day)
	local st = db.ex[cat]
	local ladder = AF.Ladders[cat]
	local target = st.variant + delta
	if not ladder[target] then return false end
	local v = ladder[target]
	st.variant = target
	if delta > 0 then
		st.max = max(v.minMax or 1, floor(v.startMax * 0.7 + 0.5))
	else
		st.max = v.startMax
	end
	if v.unit == "seconds" then st.max = max(v.minMax or 10, floor(st.max / 5 + 0.5) * 5) end
	st.weekStart = day
	st.weekBase = st.max
	st.rightStreak = 0
	return true
end

-- A Trial of Strength result replaces the max directly (no weekly limit).
function E.SetTrialMax(db, cat, value, day)
	local variant, st = E.Variant(db, cat)
	value = floor(tonumber(value) or 0)
	if value <= 0 then return nil end
	local old = st.max
	st.max = max(variant.minMax or 1, value)
	st.weekStart = day
	st.weekBase = st.max
	st.rightStreak = 0
	db.stats.trials[#db.stats.trials + 1] = { day = day, cat = cat, variant = st.variant, value = st.max, previous = old }
	return old, st.max
end

function E.ApplyTier(db, idx, resetExercises, day)
	local tier = AF.Tiers[idx]
	if not tier then return end
	db.settings.tier = idx
	db.settings.gap = tier.gap
	db.settings.capSets = nil -- use the tier's daily limit
	db.settings.rounds = nil -- and its level-up rounds
	if resetExercises then
		for _, cat in ipairs(AF.Categories) do
			local vIdx = tier.variants[cat]
			local v = AF.Ladders[cat][vIdx]
			db.ex[cat] = { variant = vIdx, max = tier.max[cat] or v.startMax, weekStart = day, rightStreak = 0 }
			db.ex[cat].weekBase = db.ex[cat].max
		end
	end
end

-- The character you are playing right now (set at login), or nil.
function E.CurrentChar(db)
	return db.currentChar and db.chars[db.currentChar]
end

-- Your characters, most active first.
function E.CharList(db)
	local list = {}
	for key, ch in pairs(db.chars) do
		list[#list + 1] = { key = key, name = ch.name or key:match("^([^%-]+)") or key, ch = ch }
	end
	table.sort(list, function(a, b)
		local sa, sb = a.ch.seconds or 0, b.ch.seconds or 0
		if sa ~= sb then return sa > sb end
		return a.name < b.name
	end)
	return list
end

-- Lifetime numbers used for stats, tooltips and /flex.
function E.Summary(db)
	local t = db.stats.totals
	return {
		level = db.stats.level,
		title = E.TitleFor(db.stats.level),
		tier = db.settings.tier,
		push = t["push:reps"] or 0,
		legs = t["legs:reps"] or 0,
		coreReps = t["core:reps"] or 0,
		coreSec = t["core:seconds"] or 0,
		cardioSec = t["cardio:seconds"] or 0,
		stretchSec = t["stretch:seconds"] or 0,
		seconds = db.stats.seconds,
		days = db.stats.daysTrained,
		sets = db.stats.sets,
		chars = #E.CharList(db),
	}
end
