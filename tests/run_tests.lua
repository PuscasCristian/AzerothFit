-- Run with: lua5.1 tests/run_tests.lua   (from the project root)
package.path = "./tests/?.lua;" .. package.path
local M = require("wowmock")
local AF = M.LoadAddon("AzerothFit", "AzerothFit")

local passed, failed = 0, 0
local function check(cond, label)
	if cond then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. label) end
end
local function popup() return _G.AzerothFitPopup end
local function popupShown() return popup() and popup():IsShown() end
local function lastLog() return M.log[#M.log] or "" end
-- Finish the current set, letting a timed set's countdown run out.
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

-- Login
M.Fire("ADDON_LOADED", "AzerothFit")
M.Fire("PLAYER_LOGIN")
M.Advance(7)
check(_G.AzerothFitOnboarding and _G.AzerothFitOnboarding:IsShown(), "onboarding shows on first login")

-- Onboarding: Soldier, push max typed as 12
AF.Onboarding.ShowPage(2)
AF.Onboarding.Finish()
check(AF.db.onboarded, "onboarded after finish")
check(AF.db.ex.push.variant == 3 and AF.db.ex.push.max == 12, "soldier push = knee push-ups, max 12")
check(AF.Engine.CapSets(AF.db) == 15 and AF.db.settings.gap == 15, "soldier pacing: 15 min gap, 15 sets a day")
-- First set right after setup, at the gentle-start level (70% of 50% of 12 = 4)
M.Advance(2)
check(popupShown() and popup().header:GetText():find("WORKOUT") and popup().amount:GetText() == "4",
	"first set right after setup, gentle start (got " .. tostring(popup() and popup().amount:GetText()) .. ")")
check(AF.db.rampStart == AF.DayNumber(), "gentle start begins at setup")
popup().skip:Click()
AF.db.rampStart = nil -- the rest of these tests use full-strength numbers
AF.db.settings.gap = 10 -- and the old 10 minute gap
AF.db.rot = 1 -- the skipped first set used the push slot
M.Advance(6 * 60)
M.Advance(20)

-- Quest snack
M.Fire("QUEST_TURNED_IN", 101, 500, 0)
check(not popupShown(), "snack waits 1.5s for a possible level-up")
M.Advance(2)
check(popupShown(), "snack popup shows")
local step = AF.Popup and popup() and AF.queue and nil
check(popup().name:GetText() == "Knee Push-ups", "first snack is push: Knee Push-ups")
check(popup().amount:GetText() == "6", "snack is 50% of 12 = 6")
popup().done:Click()
check(AF.db.stats.totals["push:reps"] == 6, "6 push-ups counted")
check(AF.db.stats.level == 1 and AF.db.stats.xp == 6 * 3 + 50, "xp = work seconds + 50")
check(popup().right:IsShown(), "feedback buttons after last set")
popup().right:Click()
check(not popupShown(), "popup closes after feedback")

-- Gap: a second quest right away gives nothing
M.Advance(5)
M.Fire("QUEST_TURNED_IN", 102, 500, 0)
M.Advance(3)
check(not popupShown(), "no snack inside the 10 minute gap")

-- Combat holds the popup
M.Advance(11 * 60)
M.combat = true
M.Fire("PLAYER_REGEN_DISABLED")
M.Fire("QUEST_TURNED_IN", 103, 500, 0)
M.Advance(3)
check(not popupShown(), "no popup in combat")
M.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
M.Advance(2)
check(popupShown(), "popup after combat ends")
check(popup().name:GetText() == "Squats", "rotation: legs next")
-- Combat in the middle hides it, then it comes back
M.combat = true
M.Fire("PLAYER_REGEN_DISABLED")
check(not popupShown(), "popup hides when combat starts")
M.combat = false
M.Fire("PLAYER_REGEN_ENABLED")
M.Advance(2)
check(popupShown(), "popup returns after combat")
popup().done:Click()
popup().easy:Click()
check(AF.db.ex.legs.max == 27, "too easy: 25 -> 27 (+8%, inside the 10% weekly limit)")
M.Advance(11 * 60)
M.Fire("QUEST_TURNED_IN", 104, 500, 0)
M.Advance(2)
finishSet()
popup().easy:Click()
check(AF.db.ex.core.max == 35, "core knee plank seconds: 30 -> 35")

-- Level-up workout replaces a quest snack from the same turn-in
M.Advance(11 * 60)
M.Fire("QUEST_TURNED_IN", 105, 500, 0)
M.Fire("PLAYER_LEVEL_UP", 11)
M.Advance(3)
check(popupShown() and popup().header:GetText():find("LEVEL UP"), "level-up workout shows instead of snack")
local steps = 0
local guard = 0
while popupShown() and popup().done:IsShown() and guard < 50 do
	guard = guard + 1
	finishSet()
	steps = steps + 1
end
check(steps == 7, "soldier level-up = 2 rounds x 3 + finisher = 7 sets (got " .. steps .. ")")
check(popup().right:IsShown(), "feedback after level-up workout")
popup().hard:Click()
check(AF.db.ex.push.max == 10, "too hard lowers push 12 -> 10 (got " .. AF.db.ex.push.max .. ")")
check(not popupShown(), "closed after feedback")
check(AF.db.stats.levelUps == 1, "level-up counted")

-- Break after a workout: a quest 2 minutes after the level-up workout gives nothing
M.Advance(2 * 60)
AF.db.lastPrompt = 0
M.Fire("QUEST_TURNED_IN", 150, 500, 0)
M.Advance(2)
check(not popupShown(), "no quest snack within 5 minutes of a level-up workout")
-- A level-up inside the break waits for it, it isn't dropped
M.Fire("PLAYER_LEVEL_UP", 20)
M.Advance(2)
check(not popupShown(), "level-up waits for the break to end")
M.Advance(3 * 60)
check(popupShown() and popup().header:GetText():find("TRIAL"), "trial at level 20 after the break")
popup().input:SetText("14")
popup().done:Click()
popup().input:SetText("30")
popup().done:Click()
check(AF.db.ex.push.max == 14 and AF.db.ex.legs.max == 30, "trial sets new max")
popup().yes:Click()
check(not popupShown(), "trial closes")

-- Quest snack after the break is fine again
M.Advance(6 * 60)
AF.db.lastPrompt = 0
M.Fire("QUEST_TURNED_IN", 151, 500, 0)
M.Advance(2)
check(popupShown(), "quest snack once the break is over")
popup().skip:Click()
-- Snack then an immediate level-up: the level-up waits 5 minutes
M.Advance(60)
M.Fire("PLAYER_LEVEL_UP", 22)
M.Advance(2)
check(not popupShown(), "level-up right after a snack waits")
M.Advance(4 * 60)
check(popupShown() and popup().header:GetText():find("LEVEL UP"), "level-up shows 5 minutes after the snack")
popup().skip:Click()
-- Settings: break can be turned off
AF.db.settings.rest = 0
AF.db.lastPrompt = 0
M.Advance(2)
M.Fire("QUEST_TURNED_IN", 152, 500, 0)
M.Advance(2)
check(popupShown(), "break set to 0 minutes allows back-to-back")
popup().skip:Click()
AF.db.settings.rest = 5
M.Advance(6 * 60)

-- Daily cap and banking
AF.db.today.sets = AF.Engine.CapSets(AF.db)
M.Advance(11 * 60)
M.Fire("QUEST_TURNED_IN", 106, 500, 0)
M.Advance(2)
check(not popupShown(), "no snack after daily cap")
check(lastLog():find("Daily training done"), "cap message printed")
M.Fire("PLAYER_LEVEL_UP", 21)
M.Advance(2)
check(#AF.db.bank == 1, "level-up banked when cap reached")

-- Next day, after two days off: rested XP and the banked workout
M.Advance(3 * 86400)
M.Fire("QUEST_TURNED_IN", 107, 500, 0)
M.Advance(4)
check(AF.db.stats.rested == 600, "two missed days = 600 rested (got " .. AF.db.stats.rested .. ")")
check(popupShown() and popup().header:GetText():find("SAVED"), "banked workout offered on a new day (" .. (popupShown() and popup().header:GetText() or "none") .. ")")
local xpBefore = AF.db.stats.xp + AF.Engine.XPToNext(AF.db.stats.level) * 0
popup().skip:Click()
check(#AF.db.bank == 0 and not popupShown(), "skip removes banked workout")

-- Escape = later, comes back after snooze
M.Advance(11 * 60)
M.Fire("QUEST_TURNED_IN", 108, 500, 0)
M.Advance(2)
check(popupShown(), "snack before escape")
popup():Hide()
check(not popupShown(), "escape hides")
M.Advance(5 * 60 + 2)
check(popupShown(), "snoozed snack returns after 5 minutes")
finishSet()
check(AF.db.stats.rested < 600, "rested pool used on comeback")
popup().right:Click()

-- Instances: wait until outside
M.instance = true
M.Advance(11 * 60)
M.Fire("QUEST_TURNED_IN", 109, 500, 0)
M.Advance(3)
check(not popupShown(), "no popup in dungeon")
M.instance = false
M.Fire("ZONE_CHANGED_NEW_AREA")
M.Advance(4)
check(popupShown(), "popup after leaving dungeon")
popup().skip:Click()

-- Death trigger is off by default
M.Advance(11 * 60)
M.Fire("PLAYER_DEAD")
M.Advance(3)
check(not popupShown(), "death trigger off by default")
AF.db.settings.trig.death = true
M.Fire("PLAYER_DEAD")
M.Advance(3)
check(popupShown() and popup().cat:GetText():find("Cardio"), "death gives a cardio set when turned on")
popup().skip:Click()

-- Social
M.Fire("CHAT_MSG_ADDON", "AzerothFit", "S:1:14:3:1240:2010:600:3000:20000:40", "GUILD", "Thrall-Stormrage")
check(AF.db.peers["Thrall-Stormrage"] and AF.db.peers["Thrall-Stormrage"].push == 1240, "peer stats stored")
M.unitNames.mouseover = { "Thrall", "Stormrage" }
M.tooltipLines = {}
M.tooltipHook(GameTooltip)
M.tooltipUnit = "mouseover"
M.tooltipHook(GameTooltip)
check(M.tooltipLines[1] and M.tooltipLines[1]:find("Fitness Lv 14"), "tooltip shows peer level")
check(M.tooltipLines[2] and M.tooltipLines[2]:find("1,240 push%-ups"), "tooltip shows peer push-ups")
local sentBefore = #M.sent
M.Fire("CHAT_MSG_ADDON", "AzerothFit", "Q", "WHISPER", "Jaina-Proudmoore")
check(#M.sent == sentBefore + 1 and M.sent[#M.sent][2]:match("^S:1:") and M.sent[#M.sent][4] == "Jaina-Proudmoore", "reply to stats request")
M.unitNames.mouseover = { "Anduin", "Wrynn" }
sentBefore = #M.sent
M.Fire("UPDATE_MOUSEOVER_UNIT")
check(#M.sent == sentBefore + 1 and M.sent[#M.sent][2] == "Q" and M.sent[#M.sent][4] == "Anduin Wrynn", "asks moused-over player, Forever name format")
M.Fire("CHAT_MSG_ADDON", "AzerothFit", "S:1:abc:::::", "WHISPER", "Bad-Data")
check(AF.db.peers["Bad-Data"].level == 1, "bad data is cleaned, not an error")
local chatBefore = #M.chat
SlashCmdList.AZEROTHFITFLEX("")
check(#M.chat == chatBefore and lastLog():find("Fitness level"), "plain /flex only prints locally by default")
SlashCmdList.AZEROTHFITFLEX("guild")
check(M.chat[#M.chat] and M.chat[#M.chat][2] == "GUILD" and M.chat[#M.chat][1]:find("Fitness level"), "/flex guild posts to guild")
chatBefore = #M.chat
SlashCmdList.AZEROTHFITFLEX("party")
check(#M.chat == chatBefore and lastLog():find("not in a group"), "/flex party when not grouped just explains")
SlashCmdList.AZEROTHFITFLEX("say")
check(M.chat[#M.chat][2] == "SAY", "/flex say")
AF.db.settings.flexTo = "GUILD"
chatBefore = #M.chat
SlashCmdList.AZEROTHFITFLEX("")
check(#M.chat == chatBefore + 1 and M.chat[#M.chat][2] == "GUILD", "default destination can be changed")
AF.db.settings.flexTo = "SELF"
SlashCmdList.AZEROTHFITFLEX("banana")
check(lastLog():find("Flex where"), "unknown destination explains the options")

-- Our own broadcast echoed back by guild chat is not another player
M.Fire("CHAT_MSG_ADDON", "AzerothFit", "S:1:2:3:47:96:0:0:600:1:" .. AF.db.profileId .. ":1", "GUILD", "Tamsin Oakhart")
check(AF.db.peers["Tamsin Oakhart"] == nil, "own echo not stored as a peer")
check(AF.Engine.CurrentChar(AF.db).sender == "Tamsin Oakhart", "learned how the game writes our name")
-- Echo from an old version (no account id) is recognised by name
M.Fire("CHAT_MSG_ADDON", "AzerothFit", "S:1:1:3:26:48:60:30:312:1", "GUILD", "Tamsin Oakhart")
check(AF.db.peers["Tamsin Oakhart"] == nil, "old-format own echo not stored")
-- A stale copy of ourselves saved by the old version is cleaned up
AF.db.peers["Tamsin Oakhart"] = { level = 1, push = 26, legs = 48, seconds = 312, seen = time() }
AF.Comm.ForgetSelf()
check(AF.db.peers["Tamsin Oakhart"] == nil, "stale self entry removed")
check(AF.db.peers["Thrall-Stormrage"] ~= nil, "other players kept")

-- Windows render without errors
for _, tab in ipairs({ "profile", "exercises", "pacing", "options", "buddies", "settings", "players" }) do
	AF.MainWindow.Show(tab)
end
check(_G.AzerothFitMain:IsShown(), "main window opens")
SlashCmdList.AZEROTHFIT("")
check(not _G.AzerothFitMain:IsShown(), "/af toggles window")
SlashCmdList.AZEROTHFIT("now")
check(popupShown(), "/af now shows a set")
popup().skip:Click()
SlashCmdList.AZEROTHFIT("preview levelup")
check(popupShown(), "/af preview shows a popup")
popup().skip:Click()
SlashCmdList.AZEROTHFIT("help")
AF.UpdateMinimap()
_G.AzerothFitMinimapButton:GetScript("OnEnter")(_G.AzerothFitMinimapButton)

-- Engine: weekly limit holds even with many "too easy" answers
local E = AF.Engine
local db = AF.db
E.ChangeVariant(db, "push", 1, 1000)
local start = db.ex.push.max
for _ = 1, 10 do E.Feedback(db, "push", "easy", 1001) end
check(db.ex.push.max <= math.max(start + 1, math.ceil(start * 1.1)), "max grows at most 10% in a week")
for _ = 1, 10 do E.Feedback(db, "push", "easy", 1008) end
check(db.ex.push.max > start, "growth continues next week")
-- Promotion suggestion
db.ex.legs = { variant = 1, max = 19, weekStart = 2000, weekBase = 19, rightStreak = 0 }
local _, _, sug = E.Feedback(db, "legs", "easy", 2000)
check(sug == "promote", "promote suggested at sit-to-stand 20+")

-- Campfire nudge
local nudge = function() return _G.AzerothFitNudge end
M.Advance(25 * 60)
AF.db.today.seconds = 0
M.auras[1229739] = true
M.Fire("UNIT_AURA", "player")
check(nudge() and nudge():IsShown() and nudge().title:GetText():find("Campfire"), "campfire nudge shows")
check(not popupShown(), "campfire nudge is not a popup")
nudge():Click("LeftButton")
M.Advance(1)
check(popupShown() and popup().header:GetText():find("CAMPFIRE"), "clicking the nudge starts a campfire workout")
popup().skip:Click()
M.Fire("UNIT_AURA", "player")
check(not nudge():IsShown(), "no second nudge while still at the same fire")
-- Nudge fades away by itself
M.auras[1229739] = nil
M.Fire("UNIT_AURA", "player")
M.Advance(21 * 60)
M.auras[1289723] = true
M.Fire("UNIT_AURA", "player")
check(nudge():IsShown(), "new campfire visit after cooldown nudges again")
local upd = nudge():GetScript("OnUpdate")
for _ = 1, 8 do upd(nudge(), 1) end
check(not nudge():IsShown(), "nudge disappears after a few seconds")
M.auras[1289723] = nil
M.Fire("UNIT_AURA", "player")

-- Save level-up workouts for campfires
AF.db.settings.saveForCampfire = true
M.Advance(6 * 60)
M.Fire("PLAYER_LEVEL_UP", 23)
M.Advance(400)
check(not popupShown() and #AF.db.bank == 1, "level-up saved instead of popping up")
check(nudge():IsShown() and nudge().title:GetText():find("saved"), "small notice that it was saved")
for _ = 1, 8 do upd(nudge(), 1) end
M.Advance(21 * 60)
M.auras[1229739] = true
M.Fire("UNIT_AURA", "player")
check(nudge():IsShown() and nudge().sub:GetText():find("1 saved"), "campfire nudge mentions saved workout")
nudge():Click("LeftButton")
M.Advance(1)
check(popupShown() and popup().header:GetText():find("SAVED"), "saved workout starts at the campfire")
popup().skip:Click()
check(#AF.db.bank == 0, "saved workout used")
M.auras[1229739] = nil
M.Fire("UNIT_AURA", "player")
AF.db.settings.saveForCampfire = false

-- Stand-up reminder after 45 minutes without a workout
for _ = 1, 8 do upd(nudge(), 1) end
M.Advance(46 * 60)
check(nudge():IsShown() and nudge().title:GetText():find("45 minutes"), "stand-up reminder after 45 minutes")
check(nudge().sub:GetText():find("Step Jacks") or nudge().sub:GetText():find("March"), "reminder suggests cardio (" .. nudge().sub:GetText() .. ")")
nudge():Click("LeftButton")
M.Advance(1)
check(popupShown() and popup().header:GetText():find("STAND UP"), "reminder click gives a cardio set")
popup().skip:Click()
for _ = 1, 12 do upd(nudge(), 1) end
M.Advance(20 * 60)
check(not nudge():IsShown(), "no reminder soon after a workout")
AF.db.settings.moveEvery = 0
M.Advance(120 * 60)
check(not nudge():IsShown(), "reminder off when set to 0")
AF.db.settings.moveEvery = 45

-- Whole account: switch to another character in a new session
local acct = AzerothFitDB
local mainPush = acct.stats.totals["push:reps"]
check(acct.chars["Tamsin Oakhart"] and acct.chars["Tamsin Oakhart"]["push:reps"] == mainPush,
	"sets are credited to the character who did them")
M.events, M.timers = {}, {}
M.unitNames.player = { "Gideon", "Oakhart" }
AF = M.LoadAddon("AzerothFit", "AzerothFit")
M.Fire("ADDON_LOADED", "AzerothFit")
M.Fire("PLAYER_LOGIN")
M.Advance(30)
check(AF.db.onboarded and not (_G.AzerothFitOnboarding and _G.AzerothFitOnboarding:IsShown() and false),
	"no setup again on another character")
check(AF.db.currentChar == "Gideon Oakhart", "new character registered")
local lvlBefore, pushBefore = AF.db.stats.level, AF.db.stats.totals["push:reps"]
AF.db.today.seconds = 0
AF.db.lastPrompt = 0
AF.db.rot = 1
M.Advance(6 * 60) -- past the break from the last workout
M.Fire("QUEST_TURNED_IN", 201, 500, 0)
M.Advance(2)
check(popupShown(), "snack on the alt")
finishSet()
popup().right:Click()
check(AF.db.stats.totals["push:reps"] > pushBefore and AF.db.stats.level >= lvlBefore, "account totals keep growing on the alt")
check(AF.db.chars["Gideon Oakhart"]["push:reps"] == AF.db.stats.totals["push:reps"] - pushBefore, "alt has its own share")
check(AF.db.chars["Tamsin Oakhart"]["push:reps"] == mainPush, "main's share unchanged")
check(AF.Engine.Summary(AF.db).chars == 2, "summary knows about two characters")
-- Our own other character's broadcast is not another player
M.Fire("CHAT_MSG_ADDON", "AzerothFit", "S:1:5:3:10:25:0:0:200:1:" .. AF.db.profileId .. ":2", "GUILD", "Tamsin Oakhart")
check(AF.db.peers["Tamsin Oakhart"] == nil, "own alt is not stored as a peer")
-- Another player's two characters show as one row
M.Fire("CHAT_MSG_ADDON", "AzerothFit", "S:1:20:3:500:900:0:0:9000:30:abc123:2", "GUILD", "Varian-Wrynn")
M.Advance(5)
M.Fire("CHAT_MSG_ADDON", "AzerothFit", "S:1:20:3:500:900:0:0:9000:30:abc123:2", "GUILD", "Tiffin-Wrynn")
AF.MainWindow.Show("buddies")
local rows = AF.MainWindow.pages.buddies.rows
local found, count = nil, 0
for i = 1, #rows do
	local t = rows[i][1]:GetText()
	if t:find("Varian") or t:find("Tiffin") then count = count + 1; found = t end
end
check(count == 1 and found:find("Tiffin") and found:find("+1"), "alts of one account = one row (" .. tostring(found) .. ")")
AF.MainWindow.Show("profile")
check(AF.MainWindow.pages.profile.lifetime:GetText():find("by character"), "profile shows per-character breakdown")
SlashCmdList.AZEROTHFITFLEX("")
check(lastLog():find("across 2 characters"), "flex mentions all characters")

print(string.format("\n%d passed, %d failed, %d runtime errors", passed, failed, #M.errors))
if failed > 0 or #M.errors > 0 then os.exit(1) end
