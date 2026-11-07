-- Game events -> workout requests. Handles the queue (combat, dungeons, snoozes),
-- the daily cap, banked level-ups and slash commands.
local ADDON, AF = ...
local E = AF.Engine
local C = AF.UI.C

local queue = {}
AF.queue = queue

local function Random(list)
	return list[math.random(1, #list)]
end

local function HasQueued(kinds)
	for _, r in ipairs(queue) do
		if kinds[r.kind] then return true end
	end
	return false
end

local function RemoveQueued(kinds)
	for i = #queue, 1, -1 do
		if kinds[queue[i].kind] then table.remove(queue, i) end
	end
end

local function Builders(kind, r)
	local day = AF.DayNumber()
	if kind == "levelup" or kind == "banked" or kind == "campfire" then
		return function(db) return E.LevelUpPlan(db, day) end
	end
	if kind == "stretch" then
		return function(db) return E.StretchPlan(db, r.count or 1) end
	end
	if kind == "move" or kind == "death" then
		return function(db) return E.SnackPlan(db, db.settings.cats.cardio and "cardio" or nil, day) end
	end
	if kind == "trial" then return E.TrialPlan end
	return function(db) return E.SnackPlan(db, nil, day) end
end

local retryAt = 0

function AF.TryShow()
	if AF.Popup.IsBusy() or #queue == 0 then return end
	if AF.InCombat() then return end
	local db = AF.db
	local now = time()
	local wait
	for i = 1, #queue do
		local r = queue[i]
		local blocked = (not r.manual) and db.settings.pauseInstances and AF.InPausedInstance()
		-- Keep a break after the last workout before an automatic one (snoozed ones already waited).
		if not blocked and not r.manual and not r.snoozed then
			local left = E.BreakLeft(db, now)
			if left > 0 then
				blocked = true
				wait = math.min(wait or left, left)
			end
		end
		if not blocked then
			table.remove(queue, i)
			if not r.plan then r.plan = Builders(r.kind, r)(db) end
			if not r.plan then return AF.TryShow() end
			if r.kind == "snack" or r.kind == "death" then db.lastPrompt = time() end
			AF.Popup.Show(r)
			return
		end
	end
	-- Something is waiting for the break to end: look again then.
	if wait and now + wait + 1 > retryAt then
		retryAt = now + wait + 1
		C_Timer.After(wait + 1, AF.TryShow)
	end
end

local function Enqueue(r, front, delay)
	if front then table.insert(queue, 1, r) else queue[#queue + 1] = r end
	if delay then
		C_Timer.After(delay, AF.TryShow)
	else
		AF.TryShow()
	end
end

function AF.Snooze(r)
	local minutes = AF.db.settings.snooze or 5
	r.snoozed = true
	C_Timer.After(minutes * 60, function()
		-- Paused in the meantime: an automatic one doesn't come back today.
		if not r.manual and E.Paused(AF.db, AF.DayNumber()) then return end
		Enqueue(r, true)
	end)
end

local function CapNotice(db)
	if db.today.capNoticed == db.today.day then return end
	db.today.capNoticed = db.today.day
	AF.Print(AF.Colorize("Daily training done!", C.good) .. " " .. db.today.sets ..
		" sets today. Rest is part of training; see you tomorrow.")
end

-- Weekly goal reached: a reward, and from now on the nudges only suggest stretches.
function AF.WeekGoalReached()
	local db = AF.db
	local xp, levels = E.AwardBonus(db, E.XP_WEEK_GOAL, AF.DayNumber())
	AF.Toast({
		title = "Weekly goal reached!",
		sub = E.WeekCount(db) .. " of " .. E.WeekGoal(db) .. " training days  |  +" .. xp .. " Fitness XP",
		icon = "Interface\\Icons\\INV_Misc_Trophy_03",
		color = C.good,
		big = true,
	})
	AF.PlaySound("ding")
	AF.Speak("Weekly goal reached. Great work.")
	AF.Print(AF.Colorize("Weekly goal reached!", C.good) .. " Anything more this week is a bonus.")
	if levels and levels > 0 then AF.ToastXP(0, 0, levels) end
end

local function Paused()
	return E.Paused(AF.db, AF.DayNumber())
end

function AF.SetPaused(on)
	AF.db.pauseDay = on and AF.DayNumber() or nil
	if on then
		for i = #queue, 1, -1 do
			if not queue[i].manual then table.remove(queue, i) end
		end
		AF.Print("Paused for today. Have a good session; see you tomorrow.")
	else
		AF.Print("Resumed.")
	end
	AF.Fire("SETTINGS_CHANGED")
end

function AF.SetQuiet(on)
	AF.db.settings.quiet = on and true or false
	AF.Print(on and "Quiet mode on: no jumping, cardio stays on the spot." or "Quiet mode off.")
	AF.Fire("SETTINGS_CHANGED")
end

function AF.CheckBank()
	local db = AF.db
	if db.settings.saveForCampfire then return end -- saved workouts wait for a campfire
	if #db.bank == 0 or E.CapReached(db) or HasQueued({ banked = true }) then return end
	local b = table.remove(db.bank, 1)
	Enqueue({
		kind = "banked",
		reason = "Your banked level " .. (b.level or "?") .. " workout is ready.",
		speakLead = "Banked workout.",
	}, false, 2)
end

local function DayCheck()
	local db = AF.db
	if E.Rollover(db, AF.DayNumber()) then
		AF.CheckBank()
	end
end

------------------------------------------------------------------------
-- Triggers
------------------------------------------------------------------------
local function OnQuestTurnedIn(questID)
	local db = AF.db
	db.stats.quests = db.stats.quests + 1
	local ch = E.CurrentChar(db)
	if ch then ch.quests = (ch.quests or 0) + 1 end
	if not db.onboarded or not db.settings.trig.quest then return end
	DayCheck()
	local ok, why = E.CanSnack(db, time(), AF.DayNumber())
	if not ok then
		if why == "cap" then CapNotice(db) end
		return
	end
	if AF.Popup.IsBusy() or HasQueued({ snack = true, death = true, levelup = true, trial = true }) then return end
	local title
	if questID and not AF.IsSecret(questID) then
		local getTitle = (C_QuestLog and C_QuestLog.GetTitleForQuestID) or GetTitleForQuestID
		if getTitle then title = AF.Safe(getTitle(questID)) end
	end
	Enqueue({
		kind = "snack",
		reason = title and ("Turned in: " .. title) or Random(AF.Quips.quest),
		speakLead = "Quest complete.",
	}, false, 1.5) -- short delay, so a level-up from the same quest can take over
end

local function OnLevelUp(level)
	local db = AF.db
	level = AF.Safe(level)
	if type(level) ~= "number" then level = (AF.Safe(UnitLevel("player")) or 0) + 1 end
	db.stats.levelUps = db.stats.levelUps + 1
	local ch = E.CurrentChar(db)
	if ch then ch.level = level end
	if not db.onboarded or not db.settings.trig.level then return end
	DayCheck()
	if Paused() then return end
	-- A level-up replaces a quest snack from the same turn-in.
	RemoveQueued({ snack = true })
	if AF.Popup.IsFreshSnack() then AF.Popup.Hide() end

	if level % 10 == 0 then
		Enqueue({
			kind = "trial",
			reason = "Level " .. level .. "! " .. Random(AF.Quips.trial),
		}, false, 1)
		return
	end
	if db.settings.saveForCampfire then
		if #db.bank >= 3 then return end -- three are already waiting
		db.bank[#db.bank + 1] = { level = level, day = AF.DayNumber() }
		AF.Nudge({
			title = "Level " .. level .. "! Workout saved",
			sub = #db.bank .. " saved for your next campfire",
			icon = "Interface\\Icons\\Spell_Fire_Fire",
			onAccept = function() AF.StartCampfireWorkout() end,
		})
		return
	end
	if E.CapReached(db) then
		if #db.bank < 3 then
			db.bank[#db.bank + 1] = { level = level, day = AF.DayNumber() }
			AF.Print("Level " .. level .. "! You've done your training for today, so this workout is banked for tomorrow.")
		end
		return
	end
	-- Two level-ups in a dungeon shouldn't mean two workouts back to back.
	if HasQueued({ levelup = true }) then
		if #db.bank < 3 then
			db.bank[#db.bank + 1] = { level = level, day = AF.DayNumber() }
			AF.Print("Level " .. level .. "! One workout is already waiting, so this one is saved for later.")
		end
		return
	end
	Enqueue({
		kind = "levelup",
		reason = "Level " .. level .. "! " .. Random(AF.Quips.levelup),
		speakLead = "Level " .. level .. "! Mini workout.",
	}, false, 1)
end

local function OnDeath()
	local db = AF.db
	db.stats.deaths = db.stats.deaths + 1
	if not db.onboarded or not db.settings.trig.death then return end
	DayCheck()
	-- Same spacing as quest snacks, so a wipe doesn't mean a set every minute.
	if not E.CanSnack(db, time(), AF.DayNumber()) then return end
	if AF.Popup.IsBusy() or HasQueued({ death = true, snack = true }) then return end
	Enqueue({ kind = "death", reason = Random(AF.Quips.death), speakLead = "You died." }, false, 2)
end

------------------------------------------------------------------------
-- Campfires and stand-up reminders (quiet nudges by the minimap)
------------------------------------------------------------------------
-- Forever's Welcoming Campfire resting auras.
local CAMPFIRE_AURAS = { 1229739, 1289723 }
local CAMPFIRE_COOLDOWN = 20 * 60
local wasCampfire = false
local lastCampfireNudge = 0
local lastMoveNudge = 0
local loginTime = 0

local function HasCampfire()
	if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return false end
	if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then return nil end
	for _, id in ipairs(CAMPFIRE_AURAS) do
		local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
		if ok and aura and not AF.IsSecret(aura) then return true end
	end
	return false
end

local function QuietTime()
	return AF.InCombat() or AF.Popup.IsBusy() or AF.InPausedInstance() or #queue > 0
end

function AF.StartCampfireWorkout()
	local db = AF.db
	if AF.InCombat() then AF.Print("Finish the fight first!") return end
	if AF.Popup.IsBusy() then return end
	DayCheck()
	if #db.bank > 0 then
		local b = table.remove(db.bank, 1)
		Enqueue({ kind = "banked", manual = true,
			reason = "Your saved level " .. (b.level or "?") .. " workout, by the fire.",
			speakLead = "Saved workout." }, true)
	else
		Enqueue({ kind = "campfire", manual = true, reason = "Warm up by the fire while you rest.",
			speakLead = "Campfire workout." }, true)
	end
end

-- A short stretch break, offered when you've done enough training already.
function AF.StretchBreak(count, reason)
	if AF.InCombat() then AF.Print("Finish the fight first!") return end
	if AF.Popup.IsBusy() or not AF.db.settings.cats.stretch then return end
	Enqueue({ kind = "stretch", manual = true, count = count or 2,
		reason = reason or Random(AF.Quips.stretch), speakLead = "Stretch break." }, true)
end

local function OfferCampfire(source)
	local db = AF.db
	if not db.onboarded or not db.settings.campfire or QuietTime() then return end
	local now = time()
	if now - lastCampfireNudge < CAMPFIRE_COOLDOWN or now - loginTime < 20 then return end
	DayCheck()
	if Paused() then return end
	local saved = #db.bank
	lastCampfireNudge = now
	if saved == 0 and E.DoneForNow(db) then
		-- Goal already reached: no workout, just a gentle stretch by the fire.
		if not db.settings.cats.stretch then return end
		AF.Nudge({
			title = "Campfire. A gentle stretch?",
			sub = "You've done your training. Just loosen up",
			icon = AF.CategoryInfo.stretch.icon,
			color = AF.CategoryInfo.stretch.color,
			onAccept = function() AF.StretchBreak(2, "Loosen up by the fire. No counting, no rush.") end,
		})
		return
	end
	AF.Nudge({
		title = source == "rest" and "Resting. Workout now?" or "Campfire! Workout now?",
		sub = saved > 0 and (saved .. " saved workout" .. (saved > 1 and "s" or "") .. " waiting")
			or "A mini workout while you rest",
		icon = "Interface\\Icons\\Spell_Fire_Fire",
		color = { 1.0, 0.55, 0.2 },
		onAccept = AF.StartCampfireWorkout,
	})
end

local function OnAura(unit)
	if AF.Safe(unit) ~= "player" then return end
	local has = HasCampfire()
	if has == nil then return end
	if has and not wasCampfire then OfferCampfire("campfire") end
	wasCampfire = has
end

local function MoveCheck()
	C_Timer.After(30, MoveCheck)
	local db = AF.db
	local every = db.settings.moveEvery or 0
	if every <= 0 or not db.onboarded or QuietTime() or AF.NudgeShown() then return end
	DayCheck()
	if Paused() then return end
	local now = time()
	if UnitIsAFK and AF.Safe(UnitIsAFK("player")) then
		lastMoveNudge = now -- away from the keyboard is away from the chair
		return
	end
	local last = math.max(db.lastWorkoutEnd or 0, db.lastPrompt or 0, loginTime, lastMoveNudge)
	if now - last < every * 60 then return end
	lastMoveNudge = now
	if E.DoneForNow(db) or not db.settings.cats.cardio then
		-- Training is done for today (or the week): only stand up, walk, maybe stretch.
		AF.Nudge({
			title = every .. " minutes of play. Stand up!",
			sub = "Walk around for a minute, or click to stretch",
			icon = AF.CategoryInfo.stretch.icon,
			color = AF.CategoryInfo.stretch.color,
			hold = 10,
			speak = "Time to stand up for a minute.",
			onAccept = function() AF.StretchBreak(1, "You've been sitting a while. A slow stretch.") end,
		})
		return
	end
	local set = E.MakeSet(db, "cardio", E.Tier(db).snackPct, AF.DayNumber())
	local unit = set.unit == "seconds" and "s of " or " "
	AF.Nudge({
		title = every .. " minutes of play. Stand up!",
		sub = set.amount .. unit .. set.name,
		icon = AF.CategoryInfo[set.cat].icon,
		color = AF.CategoryInfo[set.cat].color,
		hold = 10,
		speak = "Time to stand up and move.",
		onAccept = function()
			if AF.InCombat() or AF.Popup.IsBusy() then return end
			Enqueue({ kind = "move", manual = true, reason = "You've been sitting a while. Get the blood flowing.",
				speakLead = "Stand up." }, true)
		end,
	})
end

------------------------------------------------------------------------
-- Manual actions
------------------------------------------------------------------------
function AF.WorkoutNow()
	if not AF.db.onboarded then AF.Onboarding.Show() return end
	if AF.InCombat() then AF.Print("Finish the fight first!") return end
	if AF.Popup.IsBusy() then return end
	DayCheck()
	Enqueue({ kind = "manual", manual = true, reason = "A quick set, just because.", speakLead = "Quick set." }, true)
end

-- Right after setup: a first set, so the first win doesn't wait for a quest.
function AF.FirstSet()
	if AF.InCombat() or AF.Popup.IsBusy() then return end
	Enqueue({ kind = "manual", manual = true, reason = "Your first set. Let's see how it feels.",
		speakLead = "First set." }, true, 1)
end

function AF.StartTrial()
	if not AF.db.onboarded then AF.Onboarding.Show() return end
	if AF.InCombat() then AF.Print("Finish the fight first!") return end
	if AF.Popup.IsBusy() then return end
	Enqueue({ kind = "trial", manual = true, reason = Random(AF.Quips.trial) }, true)
end

function AF.Preview(kind)
	if AF.InCombat() or AF.Popup.IsBusy() then return end
	kind = kind or "levelup"
	local lvl = (AF.Safe(UnitLevel("player")) or 1)
	local reasons = {
		quest = { "snack", "Turned in: A Test of Strength" },
		levelup = { "levelup", "Level " .. lvl .. "! " .. Random(AF.Quips.levelup) },
		death = { "death", Random(AF.Quips.death) },
		trial = { "trial", Random(AF.Quips.trial) },
	}
	local r = reasons[kind] or reasons.levelup
	Enqueue({ kind = r[1], manual = true, preview = true, reason = r[2] }, true)
end

------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------
local function RegisterSettings()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local UI = AF.UI
	local panel = CreateFrame("Frame")
	local title = UI.Text(panel, 20, C.gold)
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Azeroth Fit")
	local text = UI.Text(panel, 12, C.text)
	text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	text:SetWidth(520)
	text:SetText("Level up in real life while you level in Azeroth. Everything lives in the Azeroth Fit window: " ..
		"your fitness level, exercises and settings.\n\n/af  open the window\n/af now  a quick set\n" ..
		"/af trial  Trial of Strength\n/flex  show your stats (/flex guild, party or say to post them)")
	local open = UI.Button(panel, "Open Azeroth Fit", 180, 28, "primary")
	open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -16)
	open:SetScript("OnClick", function()
		if SettingsPanel and SettingsPanel.Close then pcall(SettingsPanel.Close, SettingsPanel, true) end
		AF.MainWindow.Show("pacing")
	end)
	local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "Azeroth Fit")
	if ok and category then pcall(Settings.RegisterAddOnCategory, category) end
end

local function Help()
	AF.Print("commands:")
	local lines = {
		"/af  open or close the window",
		"/af now  a quick set right now",
		"/af trial  Trial of Strength (test your max)",
		"/flex  show your stats to yourself (change the default in Settings)",
		"/flex guild | party | say | me  post them somewhere else",
		"/af setup  run the first-time setup again",
		"/af preview [quest|levelup|death|trial]  see a popup without it counting toward triggers",
		"/af campfire  a campfire workout (or your saved ones) right now",
		"/af stretch  a short stretch break",
		"/af pause  pause for today   /af resume  start again",
		"/af quiet  quiet mode on or off (no jumping)",
	}
	for _, l in ipairs(lines) do DEFAULT_CHAT_FRAME:AddMessage("   " .. l) end
end

SLASH_AZEROTHFIT1 = "/af"
SLASH_AZEROTHFIT2 = "/azerothfit"
SlashCmdList.AZEROTHFIT = function(msg)
	if not AF.db then return end
	local cmd, rest = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	if cmd == "" then
		if AF.db.onboarded then AF.MainWindow.Toggle() else AF.Onboarding.Show() end
	elseif cmd == "now" or cmd == "go" then
		AF.WorkoutNow()
	elseif cmd == "trial" then
		AF.StartTrial()
	elseif cmd == "campfire" or cmd == "fire" then
		AF.StartCampfireWorkout()
	elseif cmd == "stretch" then
		AF.StretchBreak(2)
	elseif cmd == "pause" then
		AF.SetPaused(true)
	elseif cmd == "resume" or cmd == "unpause" then
		AF.SetPaused(false)
	elseif cmd == "quiet" then
		AF.SetQuiet(not AF.db.settings.quiet)
	elseif cmd == "flex" then
		AF.Flex(rest ~= "" and rest or nil)
	elseif cmd == "setup" then
		AF.Onboarding.Show()
	elseif cmd == "preview" or cmd == "test" then
		AF.Preview(rest ~= "" and rest or nil)
	elseif cmd == "stats" or cmd == "profile" then
		AF.MainWindow.Show("profile")
	elseif cmd == "options" or cmd == "settings" or cmd == "config" then
		AF.MainWindow.Show("pacing")
	else
		Help()
	end
end

SLASH_AZEROTHFITFLEX1 = "/flex"
SlashCmdList.AZEROTHFITFLEX = function(msg)
	if not AF.db then return end
	msg = (msg or ""):match("^%s*(.-)%s*$")
	AF.Flex(msg ~= "" and msg or nil)
end

AF.On("ADDON_LOADED", function(name)
	if name ~= ADDON then return end
	AF.LoadDB()
end)

local function RegisterCharacter()
	local db = AF.db
	local key = AF.Comm.MyKey()
	local name = AF.Safe(UnitName("player")) or key
	local _, classFile = AF.Safe(UnitClass("player"))
	local first = next(db.chars) == nil
	-- Older versions wrote the name differently ("Name-Surname", or the first name alone):
	-- move that record over. Two characters that only share a first name stay apart.
	local norm, firstOnly = AF.Comm.Norm(key), AF.Comm.Norm(name)
	local old = {}
	for oldKey in pairs(db.chars) do
		local n = AF.Comm.Norm(oldKey)
		if oldKey ~= key and (n == norm or n == firstOnly) then old[#old + 1] = oldKey end
	end
	for _, oldKey in ipairs(old) do
		local ch = db.chars[key] or {}
		for k, v in pairs(db.chars[oldKey]) do
			if type(v) == "number" and type(ch[k]) == "number" and k ~= "level" and k ~= "seen" then
				ch[k] = ch[k] + v
			elseif ch[k] == nil then
				ch[k] = v
			end
		end
		db.chars[key] = ch
		db.chars[oldKey] = nil
	end
	db.chars[key] = db.chars[key] or {}
	local ch = db.chars[key]
	-- Sets done before characters were tracked belong to the character you play now.
	if first and db.stats.sets > 0 and not ch.sets then
		ch.sets, ch.seconds, ch.quests = db.stats.sets, db.stats.seconds, db.stats.quests
		for k, v in pairs(db.stats.totals) do ch[k] = v end
	end
	ch.name = name
	ch.class = classFile or ch.class
	ch.level = AF.Safe(UnitLevel("player")) or ch.level
	ch.seen = time()
	db.currentChar = key
end

AF.On("PLAYER_LOGIN", function()
	if not AF.db then AF.LoadDB() end
	loginTime = time()
	wasCampfire = HasCampfire() and true or false
	C_Timer.After(30, MoveCheck)
	RegisterCharacter()
	DayCheck()
	AF.Comm.Init()
	AF.UpdateMinimap()
	RegisterSettings()
	local db = AF.db
	if not db.onboarded then
		C_Timer.After(6, function()
			if not AF.db.onboarded and not AF.InCombat() then AF.Onboarding.Show() end
		end)
	else
		AF.Print("Fitness level " .. db.stats.level .. ", " .. AF.Colorize(E.TitleFor(db.stats.level), C.gold) ..
			". Type /af to open.")
		C_Timer.After(20, AF.CheckBank)
	end
end)

AF.On("QUEST_TURNED_IN", OnQuestTurnedIn)
AF.On("PLAYER_LEVEL_UP", OnLevelUp)
AF.On("PLAYER_DEAD", OnDeath)
AF.On("UNIT_AURA", OnAura)
AF.On("PLAYER_UPDATE_RESTING", function()
	if AF.db.settings.restNudge and IsResting and AF.Safe(IsResting()) then OfferCampfire("rest") end
end)

AF.On("PLAYER_REGEN_DISABLED", function() AF.Popup.Suspend() end)
AF.On("PLAYER_REGEN_ENABLED", function()
	C_Timer.After(1.5, function()
		if AF.InCombat() then return end
		AF.Popup.Resume()
		AF.TryShow()
	end)
end)
AF.On("PLAYER_ENTERING_WORLD", function() C_Timer.After(3, AF.TryShow) end)
AF.On("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(3, AF.TryShow) end)
AF.Listen("POPUP_CLOSED", function(r)
	-- The break starts when a workout closes, whether it was done, skipped or put off.
	if r and not r.replaced and not r.preview then AF.db.lastWorkoutEnd = time() end
	C_Timer.After(1, AF.TryShow)
end)
