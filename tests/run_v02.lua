-- v0.2 features: pictures, swap, quiet mode, stretches, pause, weekly goal,
-- gentle start, daily set limit, goal-aware nudges, text size.
-- Run with: lua5.1 tests/run_v02.lua   (from the project root)
package.path = "./tests/?.lua;" .. package.path
local M = require("wowmock")
local AF = M.LoadAddon("AzerothFit", "AzerothFit")
local E = AF.Engine

local passed, failed = 0, 0
local function check(cond, label)
	if cond then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. label) end
end
local function popup() return _G.AzerothFitPopup end
local function popupShown() return popup() and popup():IsShown() end
local function nudge() return _G.AzerothFitNudge end
local function lastLog() return M.log[#M.log] or "" end
local function finishSet()
	local timed = popup().done.label:GetText():find("Start")
	popup().done:Click()
	if timed then
		local onUpdate = popup():GetScript("OnUpdate")
		for _ = 1, 400 do
			onUpdate(popup(), 1)
			if not popup().done.label:GetText():find("Finish") then break end
		end
	end
end
local function clearNudge()
	if nudge() and nudge():IsShown() then
		local upd = nudge():GetScript("OnUpdate")
		for _ = 1, 15 do upd(nudge(), 1) end
	end
end

M.Fire("ADDON_LOADED", "AzerothFit")
M.Fire("PLAYER_LOGIN")
M.Advance(7)
AF.Onboarding.ShowPage(2)
AF.Onboarding.Finish()
M.Advance(2)
local db = AF.db
local today = AF.DayNumber()

-- Gentle start
check(math.abs(E.Ramp(db, today) - 0.70) < 0.001, "gentle start: 70% on day one")
check(math.abs(E.Ramp(db, today + 7) - 0.85) < 0.001, "gentle start: 85% after a week")
check(E.Ramp(db, today + 14) == 1, "gentle start: full strength after two weeks")

-- Pictures in the first-set popup
check(popupShown(), "first set after setup")
check(popup().art:IsShown(), "exercise picture shown")
check(AF.Art.knee_pushup and AF.Art.plank and AF.Art.neck_tilt, "art list has ladder, core and stretch exercises")
local missing = {}
for _, cat in ipairs(AF.AllCategories) do
	for _, def in ipairs(AF.Ladders[cat]) do if not AF.Art[def.id] then missing[#missing + 1] = def.id end end
	for _, def in ipairs(AF.Alternates[cat] or {}) do if not AF.Art[def.id] then missing[#missing + 1] = def.id end end
end
check(#missing == 0, "every exercise has a picture (missing: " .. table.concat(missing, ", ") .. ")")

-- Swap
local before = popup().name:GetText()
popup().swap:Click()
check(popup().name:GetText() ~= before, "swap changes the exercise (" .. before .. " -> " .. popup().name:GetText() .. ")")
check(popup().cat:GetText():find("wrist") or popup().cat:GetText():find("shoulder"), "swap says why it is kinder")
finishSet()
check(not popupShown(), "a swapped set doesn't ask how it felt (doesn't change your max)")
check(db.ex.push.max == 12, "push max unchanged by a swap")
check(db.today.sets == 1, "swapped set counts toward today")
M.Advance(6 * 60)

-- Quiet mode
db.ex.cardio.variant = 4 -- jumping jacks
db.settings.quiet = true
local set = E.MakeSet(db, "cardio", 0.5, today)
check(set.name == "Step Jacks" and set.quiet, "quiet mode swaps jumping jacks for step jacks")
db.settings.quiet = false
check(E.MakeSet(db, "cardio", 0.5, today).name == "Jumping Jacks", "quiet mode off: jumping jacks again")
db.ex.cardio.variant = 3

-- Stretch: low tiers get stretches in the rotation; stretches don't use up daily sets
E.ApplyTier(db, 1, true, today)
db.rot = 2
local plan = E.SnackPlan(db, nil, today)
check(plan.steps[1].cat == "stretch" and plan.steps[1].stretch, "Peon rotation includes a stretch")
local setsBefore = db.today.sets
E.CompleteSet(db, plan.steps[1], today)
check(db.today.sets == setsBefore and db.today.stretches == 1, "stretches don't count toward daily sets")
local lp = E.LevelUpPlan(db, today)
check(lp.steps[#lp.steps].cooldown, "Peon level-up ends with a cooldown stretch")
E.ApplyTier(db, 3, true, today)
lp = E.LevelUpPlan(db, today)
check(not lp.steps[#lp.steps].cooldown, "Soldier level-up has no cooldown stretch")
AF.StretchBreak(2)
M.Advance(1)
check(popupShown() and popup().header:GetText():find("STRETCH"), "stretch break popup")
check(popup().swap.label:GetText() == "Another", "stretch offers another stretch instead of swap")
local s1 = popup().name:GetText()
popup().swap:Click()
check(popup().name:GetText() ~= s1, "another stretch")
finishSet()
finishSet()
check(not popupShown(), "stretch break closes without asking how it felt")
M.Advance(6 * 60)

-- Daily limit is in sets
db.lastPrompt, db.lastWorkoutEnd = 0, 0
db.today.sets = E.CapSets(db)
M.Fire("QUEST_TURNED_IN", 1, 0, 0)
M.Advance(2)
check(not popupShown(), "no quest snack once today's sets are done")
db.today.sets = 0

-- Two "Too hard" in a row offers an easier exercise
db.ex.push = { variant = 3, max = 12, rightStreak = 0 }
E.Feedback(db, "push", "hard", today)
local _, _, sug = E.Feedback(db, "push", "hard", today)
check(sug == "demote", "two Too hard answers in a row suggest an easier exercise")

-- Pause for today
AF.SetPaused(true)
db.lastPrompt, db.lastWorkoutEnd = 0, 0
M.Fire("QUEST_TURNED_IN", 2, 0, 0)
M.Fire("PLAYER_LEVEL_UP", 12)
M.Advance(3)
check(not popupShown(), "paused: no quest snack or level-up workout")
M.Advance(50 * 60)
check(not (nudge() and nudge():IsShown()), "paused: no stand-up reminder")
M.Advance(86400)
M.Fire("QUEST_TURNED_IN", 3, 0, 0)
M.Advance(3)
check(popupShown(), "pause ends the next day")
popup().skip:Click()
M.Advance(6 * 60)

-- Weekly goal: three training days
db.settings.weekGoal = 3
db.week = { start = E.WeekStart(AF.DayNumber()), days = {}, reached = false }
local wd = AF.DayNumber()
db.week.days[wd - 1] = true
db.week.days[wd - 2] = true
db.today.sets = 2
db.today.stretches = 0
local fake = { cat = "legs", unit = "reps", amount = 10, work = 30, variant = 3, id = "squat" }
local logsBefore = #M.log
local xpBefore = db.stats.xp + db.stats.level * 100000
local _, _, _, goalNow = E.CompleteSet(db, fake, wd)
check(goalNow and db.week.reached, "third training day reaches the weekly goal")
AF.WeekGoalReached()
check(lastLog():find("Weekly goal reached"), "weekly goal message")
check(E.DoneForNow(db), "done for now after the weekly goal")
local _, _, _, again = E.CompleteSet(db, fake, wd)
check(not again, "goal reward only once a week")

-- Once done: the stand-up reminder only suggests standing up or stretching
clearNudge()
db.lastPrompt, db.lastWorkoutEnd = 0, 0
M.Advance(46 * 60)
check(nudge():IsShown() and nudge().sub:GetText():find("Walk around"), "after the goal, reminder says walk or stretch")
nudge():Click("LeftButton")
M.Advance(1)
check(popupShown() and popup().header:GetText():find("STRETCH"), "clicking it gives a stretch, not a workout")
popup().skip:Click()
clearNudge()
-- ...and the campfire offers a gentle stretch
M.Advance(25 * 60)
M.auras[1229739] = true
M.Fire("UNIT_AURA", "player")
check(nudge():IsShown() and nudge().title:GetText():find("gentle stretch"), "campfire after the goal: gentle stretch")
M.auras[1229739] = nil
M.Fire("UNIT_AURA", "player")
clearNudge()

-- New week: goal resets
M.Advance(8 * 86400)
E.Rollover(db, AF.DayNumber())
check(E.WeekCount(db) == 0 and not db.week.reached, "new week starts fresh")

-- Coming back after 10+ days off restarts the gentle start
db.stats.lastActiveDay = AF.DayNumber() - 12
db.today.day = 0
E.Rollover(db, AF.DayNumber())
check(db.rampStart == AF.DayNumber(), "gentle start again after a long break")

-- Minimap menu
AF.UpdateMinimap()
local mm = _G.AzerothFitMinimapButton
mm:GetScript("OnClick")(mm, "RightButton")
local menu = _G.AzerothFitChoiceMenu
check(menu and menu:IsShown(), "right-click opens the minimap menu")
menu.buttons[4]:Click() -- quiet mode
check(db.settings.quiet == true, "menu toggles quiet mode")
mm:GetScript("OnClick")(mm, "RightButton")
menu.buttons[3]:Click() -- pause
check(E.Paused(db, AF.DayNumber()), "menu pauses for today")
AF.SetPaused(false)

-- Text size and every tab renders
db.settings.scale = 1.3
AF.ApplyScale()
for _, tab in ipairs({ "profile", "exercises", "pacing", "options", "buddies" }) do AF.MainWindow.Show(tab) end
check(AF.MainWindow.pages.profile.note:GetText() ~= nil, "profile renders")
AF.MainWindow.Show("pacing")
local stepper = AF.MainWindow.pages.pacing.steppers[1]
check(stepper ~= nil, "pacing steppers exist")

-- Separate text size and window size
db.settings.scale = 1.0
db.settings.textScale = 1.2
AF.ApplyScale()
check(popup().cue.__fontSize == 14, "text size 120% makes 12pt text 14pt (got " .. tostring(popup().cue.__fontSize) .. ")")
check(popup().amount.__fontSize == 67, "big number scales too")
db.settings.textScale = 1.0
AF.ApplyScale()
check(popup().cue.__fontSize == 12, "back to normal text size")

-- The card grows to fit long how-to text (the Trial text was cut off)
AF.StartTrial()
M.Advance(1)
check(popupShown() and popup().header:GetText():find("TRIAL"), "trial shown")
check(popup():GetHeight() > 330, "trial card is taller than the default to fit its text (" .. popup():GetHeight() .. ")")
popup().skip:Click()
AF.WorkoutNow()
M.Advance(1)
check(popup():GetHeight() >= 330, "normal card keeps at least its normal height")
popup().skip:Click()

print(string.format("\n%d passed, %d failed, %d runtime errors", passed, failed, #M.errors))
if failed > 0 or #M.errors > 0 then os.exit(1) end
