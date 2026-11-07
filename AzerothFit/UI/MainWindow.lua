-- The /af window: Profile, Exercises, Pacing, Options and Buddies tabs.
local _, AF = ...
local UI = AF.UI
local C = UI.C
local E = AF.Engine

local MW = {}
AF.MainWindow = MW

local W, H = 600, 560
local f
local pages = {}
MW.pages = pages
local tabs = {}
local current = "profile"

local TABS = {
	{ "profile", "Profile" },
	{ "exercises", "Exercises" },
	{ "pacing", "Pacing" },
	{ "options", "Options" },
	{ "buddies", "Buddies" },
}
-- Old names still work (/af settings, older code).
local ALIASES = { settings = "pacing", players = "buddies" }

local GOLD_BORDER = { 0.95, 0.74, 0.22, 1 }

local function SectionLabel(parent, text, x, y)
	local l = UI.Text(parent, 10, C.faint)
	l:SetPoint("TOPLEFT", x, y)
	l:SetText(text)
	return l
end

------------------------------------------------------------------------
-- Profile
------------------------------------------------------------------------
local function BuildProfile(p)
	local badge = CreateFrame("Frame", nil, p, "BackdropTemplate")
	badge:SetSize(116, 116)
	badge:SetPoint("TOPLEFT", 16, -10)
	UI.Backdrop(badge, { 0.13, 0.10, 0.04, 1 }, GOLD_BORDER)
	local lvlLabel = UI.Text(badge, 10, C.dim, nil, "CENTER")
	lvlLabel:SetPoint("TOP", 0, -12)
	lvlLabel:SetText("FITNESS LEVEL")
	p.level = UI.Text(badge, 50, C.gold, "OUTLINE", "CENTER")
	p.level:SetPoint("CENTER", 0, -6)

	p.title = UI.Text(p, 18, C.gold)
	p.title:SetPoint("TOPLEFT", badge, "TOPRIGHT", 16, -4)
	p.tier = UI.Text(p, 11, C.dim, nil, "RIGHT")
	p.tier:SetPoint("TOPRIGHT", -16, -16)
	p.xpbar = UI.Bar(p, 430, 16, C.xp)
	p.xpbar:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -10)
	p.xpbar:SetPoint("RIGHT", -16, 0)
	p.rested = UI.Text(p, 11, C.rested)
	p.rested:SetPoint("TOPLEFT", p.xpbar, "BOTTOMLEFT", 0, -6)
	p.rested:SetPoint("RIGHT", -16, 0)
	p.nextTitle = UI.Text(p, 11, C.dim)
	p.nextTitle:SetPoint("TOPLEFT", p.rested, "BOTTOMLEFT", 0, -4)

	-- Today and this week, side by side.
	SectionLabel(p, "TODAY", 16, -140)
	p.todayBar = UI.Bar(p, 276, 14, C.gold)
	p.todayBar:SetPoint("TOPLEFT", 16, -154)
	SectionLabel(p, "THIS WEEK", 308, -140)
	p.weekBar = UI.Bar(p, 276, 14, C.good)
	p.weekBar:SetPoint("TOPLEFT", 308, -154)
	p.note = UI.Text(p, 11, C.dim)
	p.note:SetPoint("TOPLEFT", 16, -176)
	p.note:SetPoint("RIGHT", -16, 0)

	p.tiles = {}
	local x = 16
	for _, cat in ipairs(AF.Categories) do
		local tile = CreateFrame("Frame", nil, p, "BackdropTemplate")
		tile:SetSize(134, 74)
		tile:SetPoint("TOPLEFT", x, -200)
		UI.Backdrop(tile, C.panel, C.borderSoft)
		local accent = UI.Tex(tile, "ARTWORK", AF.CategoryInfo[cat].color)
		accent:SetPoint("TOPLEFT", 1, -1)
		accent:SetPoint("BOTTOMLEFT", 1, 1)
		accent:SetWidth(3)
		tile.label = UI.Text(tile, 10, C.dim)
		tile.label:SetPoint("TOPLEFT", 12, -9)
		tile.value = UI.Text(tile, 21, AF.CategoryInfo[cat].color, "OUTLINE")
		tile.value:SetPoint("TOPLEFT", tile.label, "BOTTOMLEFT", 0, -5)
		tile.sub = UI.Text(tile, 10, C.faint)
		tile.sub:SetPoint("TOPLEFT", tile.value, "BOTTOMLEFT", 0, -4)
		tile.sub:SetPoint("RIGHT", -6, 0)
		p.tiles[cat] = tile
		x = x + 142
	end

	p.lifetime = UI.Text(p, 12, C.text)
	p.lifetime:SetPoint("TOPLEFT", 16, -288)
	p.lifetime:SetPoint("RIGHT", -16, 0)
	p.lifetime:SetSpacing(4)

	local now = UI.Button(p, "Workout now", 136, 30, "primary")
	now:SetPoint("BOTTOMLEFT", 16, 14)
	now.tip = "A quick set right now, even between quests."
	now:SetScript("OnClick", function() AF.WorkoutNow() end)
	local stretch = UI.Button(p, "Stretch break", 136, 30)
	stretch:SetPoint("LEFT", now, "RIGHT", 8, 0)
	stretch.tip = "Two gentle stretches. Never counts toward your daily sets."
	stretch:SetScript("OnClick", function() AF.StretchBreak(2) end)
	local trial = UI.Button(p, "Trial of Strength", 136, 30)
	trial:SetPoint("LEFT", stretch, "RIGHT", 8, 0)
	trial.tip = "Test your max on push and legs. Your workouts update to match. You also get one every 10 character levels."
	trial:SetScript("OnClick", function() AF.StartTrial() end)
	local flex = UI.Button(p, "Flex...", 136, 30)
	flex:SetPoint("LEFT", trial, "RIGHT", 8, 0)
	flex.tip = "Show your fitness level and totals: just to you, or to your guild, group or people nearby."
	flex:SetScript("OnClick", function(self)
		UI.ChoiceMenu(self, AF.FlexTargets, function(key) AF.Flex(key) end, AF.db.settings.flexTo)
	end)
end

local function RefreshProfile(p)
	local db = AF.db
	local day = AF.DayNumber()
	E.Rollover(db, day)
	local s = E.Summary(db)
	local st = db.stats
	p.level:SetText(st.level)
	p.title:SetText(s.title)
	p.tier:SetText("Tier: " .. E.Tier(db).name)
	local need = E.XPToNext(st.level)
	if st.level >= E.MAX_LEVEL then
		p.xpbar:SetProgress(1, 1)
		p.xpbar.text:SetText("Max fitness level. Legend.")
	else
		p.xpbar:SetProgress(st.xp, need, st.rested)
		p.xpbar.text:SetText(AF.FormatNumber(st.xp) .. " / " .. AF.FormatNumber(need) .. " XP")
	end
	if st.rested > 0 then
		p.rested:SetText("Rested: " .. AF.FormatNumber(st.rested) .. " XP. Your next sets give double XP.")
	else
		p.rested:SetText("Rested builds up on days off and doubles XP when you come back.")
	end
	local nl, nt = E.NextTitle(st.level)
	p.nextTitle:SetText(nl and ("Next title at level " .. nl .. ": " .. nt) or "You hold the highest title.")

	local cap = E.CapSets(db)
	p.todayBar:SetProgress(db.today.sets, cap)
	local stretches = db.today.stretches or 0
	p.todayBar.text:SetText(db.today.sets .. " of " .. cap .. " sets" ..
		(stretches > 0 and ("  +" .. stretches .. " stretches") or ""))
	local goal, count = E.WeekGoal(db), E.WeekCount(db)
	p.weekBar:SetProgress(count, goal)
	p.weekBar.text:SetText(count >= goal and ("Goal reached: " .. count .. " of " .. goal .. " days")
		or (count .. " of " .. goal .. " training days"))

	local notes = {}
	if E.Paused(db, day) then
		notes[#notes + 1] = AF.Colorize("Paused for today.", { 1, 0.6, 0.3 })
	end
	local ramp = E.Ramp(db, day)
	if ramp < 1 then
		notes[#notes + 1] = "Gentle start: day " .. (day - db.rampStart + 1) .. " of " .. E.RAMP_DAYS ..
			". Sets are " .. math.floor(ramp * 100 + 0.5) .. "% while you ease in."
	end
	if db.settings.quiet then notes[#notes + 1] = "Quiet mode is on." end
	p.note:SetText(#notes > 0 and table.concat(notes, "   ") or
		"A training day is a day with 3 or more sets. Stretches count too.")

	local t = p.tiles
	t.push.label:SetText("PUSH-UPS")
	t.push.value:SetText(AF.FormatNumber(s.push))
	t.push.sub:SetText("all push-up styles")
	t.legs.label:SetText("SQUATS & LEGS")
	t.legs.value:SetText(AF.FormatNumber(s.legs))
	t.legs.sub:SetText("squats, stands, lunges")
	t.core.label:SetText("CORE")
	t.core.value:SetText(AF.FormatDuration(s.coreSec))
	t.core.sub:SetText("plank time, + " .. AF.FormatNumber(s.coreReps) .. " reps")
	t.cardio.label:SetText("CARDIO")
	t.cardio.value:SetText(AF.FormatDuration(s.cardioSec))
	t.cardio.sub:SetText("stretching: " .. AF.FormatDuration(s.stretchSec))

	local since = st.firstDay and date("%d %b %Y", st.firstDay * 86400) or "today"
	local lines = {
		"Time exercising: " .. AF.Colorize(AF.FormatDuration(s.seconds), C.gold) ..
			"     Days trained: " .. AF.Colorize(s.days, C.gold) ..
			"     Sets: " .. AF.Colorize(AF.FormatNumber(s.sets), C.gold) ..
			"     Since " .. since,
	}
	local parts = {}
	for _, cat in ipairs(AF.Categories) do
		if db.settings.cats[cat] then
			local v, ex = E.Variant(db, cat)
			parts[#parts + 1] = AF.Colorize(v.name, AF.CategoryInfo[cat].color) .. " " .. ex.max ..
				(v.unit == "seconds" and "s" or "")
		end
	end
	lines[#lines + 1] = AF.Colorize("Your max now:  ", C.dim) .. table.concat(parts, "   ")

	-- Which of your characters did the work (the totals are for the whole account).
	local chars = E.CharList(db)
	if #chars > 0 then
		local bits = {}
		for i, c in ipairs(chars) do
			if i > 4 then
				bits[#bits + 1] = "+" .. (#chars - 4) .. " more"
				break
			end
			local col = c.ch.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.ch.class]
			local name = col and AF.Colorize(c.name, { col.r, col.g, col.b }) or c.name
			bits[#bits + 1] = name .. (c.ch.level and (" " .. c.ch.level) or "") .. ": " ..
				AF.FormatNumber(c.ch["push:reps"] or 0) .. " push, " .. AF.FormatNumber(c.ch["legs:reps"] or 0) .. " legs"
		end
		lines[#lines + 1] = AF.Colorize("Account-wide, by character:  ", C.dim) .. table.concat(bits, "   ")
	end
	p.lifetime:SetText(table.concat(lines, "\n"))
end

------------------------------------------------------------------------
-- Exercises
------------------------------------------------------------------------
local function BuildExercises(p)
	p.rows = {}
	local y = -8
	for _, cat in ipairs(AF.AllCategories) do
		local row = CreateFrame("Frame", nil, p, "BackdropTemplate")
		row:SetSize(W - 32, 74)
		row:SetPoint("TOPLEFT", 16, y)
		UI.Backdrop(row, C.panel, C.borderSoft)
		local info = AF.CategoryInfo[cat]
		row.icon = UI.Icon(row, 36)
		row.icon:SetPoint("TOPLEFT", 10, -10)
		row.icon:SetIcon(info.icon)
		row.cat = UI.Text(row, 10, info.color)
		row.cat:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, 0)
		row.cat:SetText(info.name:upper())
		row.name = UI.Text(row, 14, C.text)
		row.name:SetPoint("TOPLEFT", row.cat, "BOTTOMLEFT", 0, -3)
		row.preview = UI.Text(row, 11, C.dim)
		row.preview:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
		row.preview:SetPoint("RIGHT", -230, 0)

		row.use = UI.Check(row, "Use", function() return AF.db.settings.cats[cat] end,
			function(v) AF.db.settings.cats[cat] = v; AF.Fire("STATS_CHANGED") end,
			"Turn this category on or off.")
		row.use:SetSize(60, 20)

		if cat ~= "stretch" then
			row.down = UI.Button(row, "<", 24, 22)
			row.down.tip = "Easier exercise"
			row.up = UI.Button(row, ">", 24, 22)
			row.up.tip = "Harder exercise"
			row.up:SetPoint("TOPRIGHT", -10, -9)
			row.rung = UI.Text(row, 11, C.dim, nil, "CENTER")
			row.rung:SetWidth(70)
			row.rung:SetPoint("RIGHT", row.up, "LEFT", -4, 0)
			row.down:SetPoint("RIGHT", row.rung, "LEFT", -4, 0)
			row.down:SetScript("OnClick", function()
				E.ChangeVariant(AF.db, cat, -1, AF.DayNumber()); AF.Fire("STATS_CHANGED")
			end)
			row.up:SetScript("OnClick", function()
				E.ChangeVariant(AF.db, cat, 1, AF.DayNumber()); AF.Fire("STATS_CHANGED")
			end)
			row.max = UI.Stepper(row, "Your max", 1, 600, 1,
				function() return AF.db.ex[cat].max end,
				function(v)
					local variant = E.Variant(AF.db, cat)
					local st = AF.db.ex[cat]
					st.max = math.max(variant.minMax or 1, v)
					st.weekBase = st.max
					AF.Fire("STATS_CHANGED")
				end)
			row.max:SetSize(200, 24)
			row.max:SetPoint("BOTTOMRIGHT", -10, 9)
			row.use:SetPoint("BOTTOMRIGHT", row.max, "BOTTOMLEFT", -24, 2)
		else
			row.use:SetPoint("RIGHT", -20, 0)
		end
		p.rows[cat] = row
		y = y - 80
	end
	local tip = UI.Text(p, 11, C.faint)
	tip:SetPoint("BOTTOMLEFT", 16, 14)
	tip:SetPoint("RIGHT", -16, 0)
	tip:SetText("Your max is how many you can do in one go. Quest snacks ask about half of it, level-up sets a bit more. " ..
		"It grows when you answer \"Too easy\" or \"Just right\", never more than 10% a week.")
end

local function RefreshExercises(p)
	local db = AF.db
	local tier = E.Tier(db)
	local ramp = E.Ramp(db, AF.DayNumber())
	for _, cat in ipairs(AF.AllCategories) do
		local row = p.rows[cat]
		if cat == "stretch" then
			row.name:SetText("Gentle stretches")
			row.preview:SetText(#AF.Ladders.stretch .. " stretches take turns: neck, shoulders, chest, wrists, back, " ..
				"hips, hamstrings, calves. Never counts toward your daily sets.")
		else
			local v, st = E.Variant(db, cat)
			local ladder = AF.Ladders[cat]
			row.name:SetText(v.name)
			local unit = v.unit == "seconds" and "s" or ""
			row.preview:SetText("Snack: " .. E.Amount(st.max, tier.snackPct * ramp, v.unit) .. unit ..
				"    Level-up set: " .. E.Amount(st.max, tier.levelPct * ramp, v.unit) .. unit ..
				"    Done: " .. AF.FormatNumber(db.stats.variantTotals[cat .. "#" .. st.variant] or 0) .. unit)
			row.rung:SetText("rung " .. st.variant .. "/" .. #ladder)
			row.down:SetEnabled(st.variant > 1)
			row.up:SetEnabled(st.variant < #ladder)
			row.max:Refresh()
		end
		row.use:Refresh()
		row:SetAlpha(db.settings.cats[cat] and 1 or 0.5)
	end
end

------------------------------------------------------------------------
-- Pacing: tier and the numbers
------------------------------------------------------------------------
local function BuildPacing(p)
	local db = function() return AF.db end
	SectionLabel(p, "TIER", 16, -10)
	p.tierButtons = {}
	local x = 16
	for i, tier in ipairs(AF.Tiers) do
		local b = UI.Button(p, tier.name, 104, 26)
		b:SetPoint("TOPLEFT", x, -26)
		b:SetScript("OnClick", function()
			E.ApplyTier(db(), i, false, AF.DayNumber())
			AF.Fire("STATS_CHANGED")
		end)
		p.tierButtons[i] = b
		x = x + 110
	end
	p.tierInfo = UI.Text(p, 11, C.dim)
	p.tierInfo:SetPoint("TOPLEFT", 16, -60)
	p.tierInfo:SetPoint("RIGHT", -16, 0)
	local resetEx = UI.Button(p, "Use this tier's starting exercises", 250, 24)
	resetEx:SetPoint("TOPLEFT", 16, -96)
	resetEx.tip = "Switch every category to this tier's exercise and typical max. Your totals and level stay."
	resetEx:SetScript("OnClick", function()
		E.ApplyTier(db(), db().settings.tier, true, AF.DayNumber())
		AF.Print("Exercises reset to the " .. E.Tier(db()).name .. " starting point.")
		AF.Fire("STATS_CHANGED")
	end)

	local function min(v) return v .. " min" end
	SectionLabel(p, "HOW MUCH", 16, -140)
	SectionLabel(p, "HOW OFTEN", 308, -140)
	local s = {
		UI.Stepper(p, "Most sets per day", 2, 60, 1,
			function() return E.CapSets(db()) end, function(v) db().settings.capSets = v end),
		UI.Stepper(p, "Level-up workout rounds", 1, 4, 1,
			function() return E.Rounds(db()) end, function(v) db().settings.rounds = v end),
		UI.Stepper(p, "Weekly goal (training days)", 1, 7, 1,
			function() return E.WeekGoal(db()) end, function(v) db().settings.weekGoal = v end,
			function(v) return v .. (v == 1 and " day" or " days") end),
		UI.Stepper(p, "Between quest snacks", 3, 60, 1,
			function() return db().settings.gap end, function(v) db().settings.gap = v end, min),
		UI.Stepper(p, "Break after any workout", 0, 30, 1,
			function() return db().settings.rest end, function(v) db().settings.rest = v end, min),
		UI.Stepper(p, "Stand-up reminder", 0, 120, 15,
			function() return db().settings.moveEvery end, function(v) db().settings.moveEvery = v end,
			function(v) return v == 0 and "off" or ("every " .. v) end),
		UI.Stepper(p, "\"Later\" asks again after", 1, 30, 1,
			function() return db().settings.snooze end, function(v) db().settings.snooze = v end, min),
	}
	local pos = { { 16, -158 }, { 16, -190 }, { 16, -222 }, { 308, -158 }, { 308, -190 }, { 308, -222 }, { 308, -254 } }
	for i, st in ipairs(s) do
		st:SetSize(276, 24)
		st:SetPoint("TOPLEFT", pos[i][1], pos[i][2])
		local old = st.Refresh
		-- Every change refreshes the other numbers too (e.g. tier defaults).
		st.Refresh = function(self) old(self) end
	end
	p.steppers = s

	local explain = UI.Text(p, 11, C.faint)
	explain:SetPoint("TOPLEFT", 16, -300)
	explain:SetPoint("RIGHT", -16, 0)
	explain:SetSpacing(3)
	explain:SetText("A training day is a day with 3 or more sets. Stretches never use up your daily sets.\n" ..
		"When you've reached today's sets or this week's goal, reminders only suggest standing up or a stretch.\n" ..
		"The first two weeks start at 70% and build up, and so does coming back after 10 or more days off.")

	local health = UI.Text(p, 10, C.faint)
	health:SetPoint("BOTTOMLEFT", 16, 18)
	health:SetText("Stop if anything hurts. Rest days are part of training.")
end

local function RefreshPacing(p)
	local db = AF.db
	for i, b in ipairs(p.tierButtons) do
		local on = (i == db.settings.tier)
		b:SetBackdropBorderColor(unpack(on and GOLD_BORDER or C.borderSoft))
		b.label:SetTextColor(unpack(on and C.gold or C.text))
	end
	local tier = E.Tier(db)
	p.tierInfo:SetText(AF.Colorize(tier.name .. " (" .. tier.tag .. "): ", C.gold) .. tier.blurb ..
		"  Snacks use " .. math.floor(tier.snackPct * 100) .. "% of your max, level-up sets " ..
		math.floor(tier.levelPct * 100) .. "%.")
	for _, s in ipairs(p.steppers) do s:Refresh() end
end

------------------------------------------------------------------------
-- Options: switches
------------------------------------------------------------------------
local function PathCheck(parent, label, path, tip)
	local function get()
		local t = AF.db.settings
		for i = 1, #path - 1 do t = t[path[i]] end
		return t[path[#path]]
	end
	local function set(v)
		local t = AF.db.settings
		for i = 1, #path - 1 do t = t[path[i]] end
		t[path[#path]] = v
		AF.Fire("SETTINGS_CHANGED")
	end
	return UI.Check(parent, label, get, set, tip)
end

local function BuildOptions(p)
	p.checks = {}
	local function column(title, x, list)
		SectionLabel(p, title, x, -10)
		local y = -28
		for _, c in ipairs(list) do
			local cb = c.custom or PathCheck(p, c[1], c[2], c[3])
			cb:SetPoint("TOPLEFT", x, y)
			p.checks[#p.checks + 1] = cb
			y = y - 26
		end
	end
	column("WHEN", 16, {
		{ "Quest turn-in snacks", { "trig", "quest" } },
		{ "Level-up workouts", { "trig", "level" } },
		{ "Exercise when you die", { "trig", "death" }, "A short set every time you die. Off by default." },
		{ "Campfire nudges", { "campfire" }, "A small notice by the minimap when you rest at a campfire. Click it for a workout." },
		{ "Save level-ups for campfires", { "saveForCampfire" },
			"Level-ups don't pop up. They're saved (up to 3) and offered at your next campfire." },
		{ "Also nudge in inns and cities", { "restNudge" } },
		{ "Wait outside dungeons and raids", { "pauseInstances" } },
	})
	column("HOW", 308, {
		{ "Quiet mode (no jumping)", { "quiet" }, "Jumping jacks and burpees become on-the-spot moves. For late nights and neighbors." },
		{ "Read exercises aloud", { "voice" }, "Uses the game's text to speech voice." },
		{ "Sounds", { "sound" } },
		{ "Share my stats", { "share" }, "Lets other players with Azeroth Fit see your fitness level and totals." },
		{ "Stats in player tooltips", { "tooltip" } },
		{ custom = UI.Check(p, "Minimap button",
			function() return not AF.db.settings.minimap.hide end,
			function(v) AF.db.settings.minimap.hide = not v; AF.Fire("SETTINGS_CHANGED") end) },
	})

	SectionLabel(p, "LOOK", 308, -186)
	p.textScale = UI.Stepper(p, "Text size", 80, 130, 10,
		function() return math.floor((AF.db.settings.textScale or 1) * 100 + 0.5) end,
		function(v) AF.db.settings.textScale = v / 100; AF.ApplyScale() end,
		function(v) return v .. "%" end)
	p.textScale:SetSize(276, 24)
	p.textScale:SetPoint("TOPLEFT", 308, -204)
	p.textScale.tip = "Only the letters. Windows keep their size."
	p.scale = UI.Stepper(p, "Window size", 80, 150, 10,
		function() return math.floor((AF.db.settings.scale or 1) * 100 + 0.5) end,
		function(v) AF.db.settings.scale = v / 100; AF.ApplyScale() end,
		function(v) return v .. "%" end)
	p.scale:SetSize(276, 24)
	p.scale:SetPoint("TOPLEFT", 308, -234)

	local flexLabel = UI.Text(p, 12, C.text)
	flexLabel:SetPoint("TOPLEFT", 308, -276)
	flexLabel:SetText("/flex shows my stats to")
	p.flexBtn = UI.Button(p, "", 110, 22)
	p.flexBtn:SetPoint("TOPRIGHT", -16, -272)
	p.flexBtn.tip = "Where plain /flex goes. You can always pick another place: /flex me, /flex guild, /flex party, /flex say."
	p.flexBtn:SetScript("OnClick", function(self)
		UI.ChoiceMenu(self, AF.FlexTargets, function(key)
			AF.db.settings.flexTo = key
			AF.Fire("SETTINGS_CHANGED")
		end, AF.db.settings.flexTo)
	end)

	local reset = UI.Button(p, "Reset all progress", 160, 26, "danger")
	reset:SetPoint("BOTTOMRIGHT", -16, 14)
	reset:SetScript("OnClick", function()
		if StaticPopup_Show then StaticPopup_Show("AZEROTHFIT_RESET") end
	end)
	local setup = UI.Button(p, "Run setup again", 160, 26)
	setup:SetPoint("RIGHT", reset, "LEFT", -8, 0)
	setup:SetScript("OnClick", function() MW.Hide(); AF.Onboarding.Show() end)
end

local function RefreshOptions(p)
	for _, c in ipairs(p.checks) do c:Refresh() end
	p.scale:Refresh()
	p.textScale:Refresh()
	p.flexBtn:SetLabel(AF.FlexLabel(AF.db.settings.flexTo))
end

------------------------------------------------------------------------
-- Buddies: friends with the addon. Not a leaderboard; everyone has their own pace.
------------------------------------------------------------------------
local ROWS = 14
local function Ago(t)
	if not t then return "" end
	local d = time() - t
	if d < 3600 then return "now" end
	if d < 86400 then return math.floor(d / 3600) .. "h ago" end
	return math.floor(d / 86400) .. "d ago"
end

local function BuildBuddies(p)
	local note = UI.Text(p, 11, C.dim)
	note:SetPoint("TOPLEFT", 16, -8)
	note:SetPoint("RIGHT", -16, 0)
	note:SetText("Guildmates, group members and anyone you mouse over who use Azeroth Fit. " ..
		"Not a leaderboard: everyone trains at their own pace. Alts count as one person (+N).")
	local cols = { { "Name", 16 }, { "Fitness Lv", 216 }, { "Title", 292 }, { "Days trained", 452 }, { "Seen", 536 } }
	for _, c in ipairs(cols) do
		local h = UI.Text(p, 10, C.faint)
		h:SetPoint("TOPLEFT", c[2], -44)
		h:SetText(c[1]:upper())
	end
	p.rows = {}
	for i = 1, ROWS do
		local r = {}
		local yy = -60 - (i - 1) * 22
		local bg = UI.Tex(p, "BACKGROUND", { 1, 1, 1, i % 2 == 0 and 0.03 or 0 })
		bg:SetPoint("TOPLEFT", 12, yy + 3)
		bg:SetPoint("TOPRIGHT", -12, yy + 3)
		bg:SetHeight(22)
		for j, c in ipairs(cols) do
			local fs = UI.Text(p, 12, j == 1 and C.text or C.dim)
			fs:SetPoint("TOPLEFT", c[2], yy)
			if j == 1 then fs:SetWidth(194) elseif j == 3 then fs:SetWidth(156) end
			if fs.SetWordWrap then fs:SetWordWrap(false) end
			r[j] = fs
		end
		p.rows[i] = r
	end
	p.page = 1
	p.prev = UI.Button(p, "<", 28, 24)
	p.prev:SetPoint("BOTTOMRIGHT", -52, 14)
	p.next = UI.Button(p, ">", 28, 24)
	p.next:SetPoint("BOTTOMRIGHT", -16, 14)
	p.pageText = UI.Text(p, 11, C.dim, nil, "RIGHT")
	p.pageText:SetPoint("RIGHT", p.prev, "LEFT", -8, 0)
	p.prev:SetScript("OnClick", function() p.page = p.page - 1; MW.Refresh() end)
	p.next:SetScript("OnClick", function() p.page = p.page + 1; MW.Refresh() end)
	local ask = UI.Button(p, "Ask guild & group", 160, 24)
	ask:SetPoint("BOTTOMLEFT", 16, 14)
	ask.tip = "Ask guildmates and group members with Azeroth Fit to send their stats."
	ask:SetScript("OnClick", function() AF.Comm.RequestAll(true) end)
end

local function RefreshBuddies(p)
	local list = {}
	local ch = E.CurrentChar(AF.db)
	local me = (ch and ch.sender) or AF.Comm.MyKey()
	local s = E.Summary(AF.db)
	list[1] = { name = me, level = s.level, days = s.days, seen = time(), me = true, alts = math.max(0, s.chars - 1) }
	-- One row per person: characters that share an account id are grouped,
	-- showing the one seen most recently.
	local people = {}
	for name, peer in pairs(AF.db.peers) do
		if AF.Comm.Norm(name) ~= AF.Comm.Norm(me) and peer.pid ~= AF.db.profileId then
			local id = peer.pid or name
			local e = people[id]
			if not e then
				e = { names = {} }
				people[id] = e
			end
			e.names[#e.names + 1] = name
			if not e.peer or (peer.seen or 0) > (e.peer.seen or 0) then
				e.peer, e.name = peer, name
			end
		end
	end
	for _, e in pairs(people) do
		local peer = e.peer
		list[#list + 1] = { name = e.name, level = peer.level or 1, days = peer.days or 0, seen = peer.seen,
			alts = math.max(#e.names, peer.chars or 0) - 1 }
	end
	-- You first, then whoever was seen most recently. No ranking.
	table.sort(list, function(a, b)
		if a.me ~= b.me then return a.me and true or false end
		if (a.seen or 0) ~= (b.seen or 0) then return (a.seen or 0) > (b.seen or 0) end
		return a.name < b.name
	end)
	local pagesN = math.max(1, math.ceil(#list / ROWS))
	p.page = math.min(math.max(1, p.page), pagesN)
	local first = (p.page - 1) * ROWS
	for i = 1, ROWS do
		local r = p.rows[i]
		local e = list[first + i]
		if e then
			local short = e.name:match("^([^%-]+)") or e.name
			local alts = (e.alts and e.alts > 0) and AF.Colorize(" +" .. e.alts, C.faint) or ""
			r[1]:SetText((e.me and AF.Colorize(short .. " (you)", C.gold) or short) .. alts)
			r[2]:SetText(e.level)
			r[3]:SetText(E.TitleFor(e.level))
			r[4]:SetText(AF.FormatNumber(e.days))
			r[5]:SetText(e.me and "" or Ago(e.seen))
		else
			for j = 1, #r do r[j]:SetText("") end
		end
	end
	p.pageText:SetText("Page " .. p.page .. " of " .. pagesN)
	p.prev:SetEnabled(p.page > 1)
	p.next:SetEnabled(p.page < pagesN)
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
local builders = { profile = BuildProfile, exercises = BuildExercises, pacing = BuildPacing,
	options = BuildOptions, buddies = BuildBuddies }
local refreshers = { profile = RefreshProfile, exercises = RefreshExercises, pacing = RefreshPacing,
	options = RefreshOptions, buddies = RefreshBuddies }

local function SelectTab(key)
	key = ALIASES[key] or key
	if not builders[key] then key = "profile" end
	current = key
	for k, page in pairs(pages) do page:SetShown(k == key) end
	for k, b in pairs(tabs) do
		local on = (k == key)
		b:SetBackdropBorderColor(unpack(on and GOLD_BORDER or C.borderSoft))
		b.label:SetTextColor(unpack(on and C.gold or C.dim))
	end
	UI.HideMenu()
	MW.Refresh()
end

local function Build()
	f = UI.Panel("AzerothFitMain", UIParent, W, H)
	f:SetPoint("CENTER")
	f:Hide()
	f:SetScript("OnHide", function() UI.HideMenu() end)
	if UISpecialFrames then table.insert(UISpecialFrames, "AzerothFitMain") end
	UI.CloseButton(f, function() f:Hide() end)

	local title = UI.Text(f, 16, C.gold)
	title:SetPoint("TOPLEFT", 16, -14)
	title:SetText("Azeroth Fit")
	local ver = UI.Text(f, 10, C.faint)
	ver:SetPoint("LEFT", title, "RIGHT", 8, -1)
	ver:SetText("v" .. AF.version .. "  |  level up in real life")

	local x = 16
	for _, t in ipairs(TABS) do
		local key = t[1]
		local b = UI.Button(f, t[2], 106, 24)
		b:SetPoint("TOPLEFT", x, -40)
		b:SetScript("OnClick", function() SelectTab(key) end)
		tabs[key] = b
		x = x + 113
		local page = CreateFrame("Frame", nil, f)
		page:SetPoint("TOPLEFT", 0, -72)
		page:SetPoint("BOTTOMRIGHT", 0, 0)
		page:Hide()
		builders[key](page)
		pages[key] = page
	end
	local div = UI.Tex(f, "ARTWORK", C.borderSoft)
	div:SetHeight(1)
	div:SetPoint("TOPLEFT", 16, -70)
	div:SetPoint("TOPRIGHT", -16, -70)

	if StaticPopupDialogs then
		StaticPopupDialogs["AZEROTHFIT_RESET"] = {
			text = "Reset all Azeroth Fit progress? Your fitness level, totals and exercise numbers start over.",
			button1 = YES or "Yes",
			button2 = NO or "No",
			OnAccept = function()
				AF.ResetDB()
				AF.Print("Progress reset.")
				AF.Fire("STATS_CHANGED")
				MW.Hide()
				AF.Onboarding.Show()
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
		}
	end
end

function MW.Refresh()
	if not f or not f:IsShown() then return end
	local fn = refreshers[current]
	if fn then fn(pages[current]) end
end

function MW.Show(tab)
	if not f then Build() end
	f:SetScale(AF.db.settings.scale or 1)
	f:Show()
	SelectTab(tab or current)
end

function MW.Hide()
	if f then f:Hide() end
	UI.HideMenu()
end

function MW.Toggle(tab)
	if f and f:IsShown() and (not tab or (ALIASES[tab] or tab) == current) then
		f:Hide()
	else
		MW.Show(tab)
	end
end

function MW.ApplyScale()
	if f then f:SetScale(AF.db.settings.scale or 1) end
end

-- Text size and window size, for every Azeroth Fit frame.
function AF.ApplyScale()
	UI.ApplyTextScale()
	MW.ApplyScale()
	if AF.Popup.ApplyScale then AF.Popup.ApplyScale() end
	AF.Fire("SETTINGS_CHANGED")
end

AF.Listen("STATS_CHANGED", MW.Refresh)
AF.Listen("SETTINGS_CHANGED", MW.Refresh)
AF.Listen("PEERS_CHANGED", function() if current == "buddies" then MW.Refresh() end end)
