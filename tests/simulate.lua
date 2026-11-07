-- Simulate leveling 1-60 on every tier to sanity-check the math.
-- Assumptions: 2 hour sessions, 5 days a week, 8 quests an hour,
-- leveling pace 1h/level (1-19), 2.5h/level (20-39), 4h/level (40-59) = about 150h /played.
-- Every set is done and answered "Just right".
package.path = "./tests/?.lua;" .. package.path
local M = require("wowmock")
local AF = M.LoadAddon("AzerothFit", "AzerothFit")
local E = AF.Engine

local function hoursFor(level)
	if level < 20 then return 1 elseif level < 40 then return 2.5 end
	return 4
end

print(string.format("%-9s %6s %8s %9s %9s %8s %8s %10s %12s", "Tier", "Weeks", "Min/day*",
	"Push/day", "Legs/day", "Push60", "FitLv", "PushMax", "Snacks/hr"))
for tierIdx = 1, #AF.Tiers do
	AzerothFitDB = nil
	AF.LoadDB()
	local db = AF.db
	local day = 20000
	E.ApplyTier(db, tierIdx, true, day)
	db.onboarded = true
	db.rampStart = day
	local startPush = AF.Ladders.push[db.ex.push.variant].name .. " " .. db.ex.push.max
	local level, levelHoursLeft = 1, hoursFor(1)
	local clock = 0
	local playDays, totalSec, snacks, sessionHours = 0, 0, 0, 0
	local dayOfWeek = 0
	while level < 60 do
		dayOfWeek = dayOfWeek + 1
		day = day + 1
		E.Rollover(db, day)
		if dayOfWeek % 7 ~= 6 and dayOfWeek % 7 ~= 0 then
			playDays = playDays + 1
			db.lastPrompt = -1e9
			-- 2 hours in 7.5 minute steps (one quest each)
			for minute = 0, 119, 7.5 do
				clock = day * 86400 + minute * 60
				sessionHours = sessionHours + 7.5 / 60
				if E.CanSnack(db, clock) then
					db.lastPrompt = clock
					local plan = E.SnackPlan(db, nil, day)
					for _, s in ipairs(plan.steps) do E.CompleteSet(db, s, day) end
					for _, st in ipairs(plan.steps) do
						local _, _, sug = E.Feedback(db, st.cat, "right", day)
						if sug == "promote" then E.ChangeVariant(db, st.cat, 1, day) end
					end
					snacks = snacks + 1
				end
				levelHoursLeft = levelHoursLeft - 7.5 / 60
				if levelHoursLeft <= 0 and level < 60 then
					level = level + 1
					levelHoursLeft = hoursFor(level)
					if level % 10 ~= 0 and not E.CapReached(db) then
						local plan = E.LevelUpPlan(db, day)
						local cats = {}
						for _, s in ipairs(plan.steps) do E.CompleteSet(db, s, day); cats[s.cat] = true end
						for cat in pairs(cats) do
							local _, _, sug = E.Feedback(db, cat, "right", day)
							if sug == "promote" then E.ChangeVariant(db, cat, 1, day) end
						end
					end
				end
			end
			totalSec = totalSec + db.today.seconds
		end
	end
	local s = E.Summary(db)
	local endPush = AF.Ladders.push[db.ex.push.variant].name .. " " .. db.ex.push.max
	print(string.format("%-9s %6.1f %8.1f %9.1f %9.1f %8d %8d %10s %12.1f",
		AF.Tiers[tierIdx].name, dayOfWeek / 7, totalSec / 60 / playDays, s.push / playDays, s.legs / playDays,
		s.push, s.level, db.ex.push.max .. " (" .. db.ex.push.variant .. ")", snacks / sessionHours))
	print("          push: " .. startPush .. "  ->  " .. endPush)
end
