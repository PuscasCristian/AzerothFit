-- The workout card. Shows one set at a time: exercise, a looping picture of it, the
-- big rep count, how to do it, and Done / Later / Skip. Timed exercises get a countdown.
-- After the last set it asks how it felt and adjusts your numbers.
local _, AF = ...
local UI = AF.UI
local C = UI.C
local E = AF.Engine

local Popup = {}
AF.Popup = Popup

local W, H = 440, 330
local ART = "Interface\\AddOns\\AzerothFit\\Media\\Ex\\"
local FRAME_TIME = 0.55
local f
local req -- the request on screen: { kind, plan, reason, idx, cats, ... }
local phase -- "ready", "timing", "feedback", "suggest", "trial", "result"
local timer = { left = 0, total = 0 }
local suspended = false
local closingQuietly = false
-- Clicks right after the card changes are ignored, so a double-click on "Done" can't
-- finish the next set too, or land on "Too easy" (it sits where "Done" was).
Popup.CLICK_GUARD = 0.5
local guardUntil = 0
local function Guard()
	guardUntil = GetTime() + Popup.CLICK_GUARD
end
local function Guarded()
	return GetTime() < guardUntil
end

local HEADERS = {
	snack = "QUEST COMPLETE",
	levelup = "LEVEL UP WORKOUT",
	death = "SPIRIT HEALER'S ORDERS",
	trial = "TRIAL OF STRENGTH",
	manual = "WORKOUT",
	banked = "SAVED WORKOUT",
	campfire = "CAMPFIRE WORKOUT",
	move = "STAND UP AND MOVE",
	stretch = "STRETCH BREAK",
}

local function CatColor(cat)
	return (AF.CategoryInfo[cat] or {}).color or C.gold
end

local function UnitText(step)
	return step.unit == "seconds" and "SECONDS" or "REPS"
end

local function SpeakStep(step, lead)
	local what
	if step.unit == "seconds" then
		what = step.amount .. " seconds of " .. step.name
	else
		what = step.amount .. " " .. step.name
	end
	AF.Speak((lead and (lead .. " ") or "") .. what .. ".")
end

local function SavePosition()
	local point, _, rel, x, y = f:GetPoint(1)
	AF.db.settings.popup = { point = point, rel = rel, x = x, y = y }
end

local function Build()
	f = UI.Panel("AzerothFitPopup", UIParent, W, H)
	f:SetFrameStrata("DIALOG")
	f:Hide()
	f.OnMoved = SavePosition
	if UISpecialFrames then table.insert(UISpecialFrames, "AzerothFitPopup") end

	f.header = UI.Text(f, 10, C.dim)
	f.header:SetPoint("TOPLEFT", 16, -14)
	f.badge = UI.Text(f, 10, C.gold, nil, "RIGHT")
	f.badge:SetPoint("TOPRIGHT", -32, -14)
	f.close = UI.CloseButton(f, function() Popup.Later() end)

	f.quip = UI.Text(f, 13, C.text)
	f.quip:SetPoint("TOPLEFT", 16, -32)
	f.quip:SetPoint("RIGHT", -16, 0)
	if f.quip.SetWordWrap then f.quip:SetWordWrap(false) end -- one line; long quest names end in "..."

	local div = UI.Tex(f, "ARTWORK", C.borderSoft)
	div:SetHeight(1)
	div:SetPoint("TOPLEFT", 16, -56)
	div:SetPoint("TOPRIGHT", -16, -56)

	-- Looping picture of the exercise, on the right.
	f.art = CreateFrame("Frame", nil, f, "BackdropTemplate")
	f.art:SetSize(130, 130)
	f.art:SetPoint("TOPRIGHT", -16, -66)
	UI.Backdrop(f.art, { 0.035, 0.035, 0.045, 1 }, C.borderSoft)
	f.art.tex = f.art:CreateTexture(nil, "ARTWORK")
	f.art.tex:SetPoint("TOPLEFT", 1, -1)
	f.art.tex:SetPoint("BOTTOMRIGHT", -1, 1)
	f.art.frame, f.art.elapsed = 1, 0
	f.art:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = self.elapsed + elapsed
		if self.elapsed < FRAME_TIME then return end
		self.elapsed = 0
		self.frame = self.frame % 4 + 1
		self.tex:SetTexCoord((self.frame - 1) / 4, self.frame / 4, 0, 1)
	end)
	f.swap = UI.Button(f, "Swap", 72, 20)
	f.swap:SetPoint("TOP", f.art, "BOTTOM", 0, -4)
	f.swap.tip = "Something hurts, or you'd rather not? Swap it for a kinder exercise for the same muscles."
	f.swap:SetScript("OnClick", function() Popup.Swap() end)

	f.icon = UI.Icon(f, 34)
	f.icon:SetPoint("TOPLEFT", 16, -70)
	f.name = UI.Text(f, 18, C.text)
	f.name:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, -1)
	f.name:SetPoint("RIGHT", f.art, "LEFT", -10, 0)
	if f.name.SetWordWrap then f.name:SetWordWrap(false) end
	f.cat = UI.Text(f, 11, C.dim)
	f.cat:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -5)
	f.cat:SetPoint("RIGHT", f.art, "LEFT", -10, 0)
	if f.cat.SetWordWrap then f.cat:SetWordWrap(false) end
	f.step = UI.Text(f, 11, C.dim)
	f.step:SetPoint("TOPLEFT", 16, -114)

	f.amount = UI.Text(f, 56, C.gold, "OUTLINE")
	f.amount:SetPoint("TOPLEFT", 18, -136)
	f.unit = UI.Text(f, 13, C.dim)
	f.unit:SetPoint("BOTTOMLEFT", f.amount, "BOTTOMRIGHT", 8, 10)

	f.input = UI.NumberBox(f, 90)
	f.input:SetPoint("LEFT", f.amount, "RIGHT", 28, -4)
	f.input:Hide()
	f.inputLabel = UI.Text(f, 11, C.dim)
	f.inputLabel:SetPoint("BOTTOMLEFT", f.input, "TOPLEFT", 0, 4)
	f.inputLabel:SetText("Your number:")
	f.inputLabel:Hide()

	f.cue = UI.Text(f, 12, C.dim)
	f.cue:SetPoint("TOPLEFT", 16, -222)
	f.cue:SetWidth(W - 32)
	f.cue:SetSpacing(2)

	f.bar = UI.Bar(f, W - 32, 6, C.gold)
	f.bar:SetPoint("BOTTOMLEFT", 16, 52)
	f.bar.text:Hide()

	-- Main buttons
	f.done = UI.Button(f, "Done", 196, 30, "primary")
	f.done:SetPoint("BOTTOMLEFT", 16, 14)
	f.later = UI.Button(f, "Later", 100, 30)
	f.later:SetPoint("LEFT", f.done, "RIGHT", 8, 0)
	f.later.tip = "Ask again in a few minutes."
	f.skip = UI.Button(f, "Skip", 100, 30)
	f.skip:SetPoint("LEFT", f.later, "RIGHT", 8, 0)
	f.skip.tip = "Not this one. No penalty."

	-- Feedback buttons
	f.easy = UI.Button(f, "Too easy", 130, 30)
	f.right = UI.Button(f, "Just right", 130, 30, "primary")
	f.hard = UI.Button(f, "Too hard", 130, 30)
	f.easy:SetPoint("BOTTOMLEFT", 16, 14)
	f.right:SetPoint("LEFT", f.easy, "RIGHT", 7, 0)
	f.hard:SetPoint("LEFT", f.right, "RIGHT", 7, 0)

	-- Suggestion buttons (move up or down a rung, results)
	f.yes = UI.Button(f, "Yes", 196, 30, "primary")
	f.yes:SetPoint("BOTTOMLEFT", 16, 14)
	f.no = UI.Button(f, "Not yet", 208, 30)
	f.no:SetPoint("LEFT", f.yes, "RIGHT", 8, 0)

	f.done:SetScript("OnClick", function() if not Guarded() then Popup.Done() end end)
	f.later:SetScript("OnClick", function() Popup.Later() end)
	f.skip:SetScript("OnClick", function() if not Guarded() then Popup.Skip() end end)
	f.easy:SetScript("OnClick", function() if not Guarded() then Popup.Feedback("easy") end end)
	f.right:SetScript("OnClick", function() if not Guarded() then Popup.Feedback("right") end end)
	f.hard:SetScript("OnClick", function() if not Guarded() then Popup.Feedback("hard") end end)
	f.input:SetScript("OnEnterPressed", function() Popup.Done() end)

	f:SetScript("OnHide", function()
		if closingQuietly or suspended then return end
		-- Escape key or another addon hid us: treat as "Later".
		if req then Popup.Later(true) end
	end)

	f:SetScript("OnUpdate", function(_, elapsed)
		if phase ~= "timing" then return end
		timer.left = timer.left - elapsed
		if timer.left <= 0 then
			Popup.FinishStep()
			return
		end
		f.amount:SetText(tostring(math.ceil(timer.left)))
		f.bar:SetProgress(timer.total - timer.left, timer.total)
	end)
end

local function Restore()
	f:ClearAllPoints()
	f:SetScale(AF.db.settings.scale or 1)
	local p = AF.db.settings.popup
	if p and p.point then
		f:SetPoint(p.point, UIParent, p.rel or p.point, p.x or 0, p.y or 0)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
	end
end

-- Grow the card to fit the how-to text (longer texts and bigger text sizes never get cut off).
local function Fit()
	local ts = AF.db.settings.textScale or 1
	local top = 222 + math.max(0, ts - 1) * 70
	f.cue:ClearAllPoints()
	f.cue:SetPoint("TOPLEFT", 16, -top)
	local h = top + (f.cue:GetStringHeight() or 0) + 78
	f:SetHeight(math.max(H, math.floor(h + 0.5)))
end

-- The unit label sits beside the big number, or under it when the number box needs that space.
local function PlaceUnit(below)
	f.unit:ClearAllPoints()
	if below then
		f.unit:SetPoint("TOPLEFT", f.amount, "BOTTOMLEFT", 2, 0)
	else
		f.unit:SetPoint("BOTTOMLEFT", f.amount, "BOTTOMRIGHT", 8, 10)
	end
end

local function ShowButtons(which)
	local groups = {
		main = { f.done, f.later, f.skip },
		feedback = { f.easy, f.right, f.hard },
		suggest = { f.yes, f.no },
	}
	for name, list in pairs(groups) do
		for _, b in ipairs(list) do b:SetShown(name == which) end
	end
end

local function CurrentStep()
	return req and req.plan.steps[req.idx]
end

local function ShowArt(id)
	if id and AF.Art and AF.Art[id] then
		f.art.tex:SetTexture(ART .. id)
		f.art.frame, f.art.elapsed = 1, 0
		f.art.tex:SetTexCoord(0, 0.25, 0, 1)
		f.art:Show()
	else
		f.art:Hide()
	end
end

local function StepLabel()
	local plan = req.plan
	local step = CurrentStep()
	if plan.kind == "levelup" then
		if step.cooldown then return "Cooldown stretch" end
		if step.finisher then return "Finisher" end
		return "Round " .. step.round .. " of " .. plan.rounds .. "  |  set " .. req.idx .. " of " .. #plan.steps
	elseif #plan.steps > 1 then
		return req.idx .. " of " .. #plan.steps
	end
	return ""
end

local function Render()
	local step = CurrentStep()
	if not step then return end
	local info = AF.CategoryInfo[step.cat]
	local color = CatColor(step.cat)
	local db = AF.db

	UI.SetAccent(f, color)
	f.header:SetText("AZEROTH FIT  |  " .. (HEADERS[req.kind] or "WORKOUT"))
	f.badge:SetText("Fitness Lv " .. db.stats.level)
	f.quip:SetText(req.reason or "")
	f.icon:SetIcon(info.icon)
	f.name:SetText(step.name)
	local detail
	if step.swapped then
		detail = "Swapped"
	elseif step.quiet then
		detail = "Quiet mode"
	elseif step.stretch then
		detail = "Hold gently, keep breathing"
	else
		detail = "rung " .. step.variant .. " of " .. #AF.Ladders[step.cat]
	end
	f.cat:SetText(AF.Colorize(info.name, color) .. "   " .. detail)
	f.step:SetText(StepLabel())
	f.amount:SetTextColor(color[1], color[2], color[3])
	f.bar:SetColor(color)
	ShowArt(step.id)

	if step.trial then
		phase = "trial"
		f.swap:Hide()
		f.amount:SetText(tostring(step.previous))
		PlaceUnit(true)
		f.unit:SetText(step.unit == "seconds" and "SECONDS LAST TIME" or "LAST TIME")
		f.cue:SetText("Do as many " .. step.name .. " as you can with good form, then type your number. " ..
			"Stop before your form breaks down.\n" .. step.cue)
		f.input:SetText("")
		f.input:Show()
		f.inputLabel:SetText("Your number:")
		f.inputLabel:Show()
		req.confirm = nil
		f.done:SetLabel("Save")
		ShowButtons("main")
		f.bar:SetProgress(req.idx - 1, #req.plan.steps)
		Fit()
		Guard()
		-- Only grab the keyboard when the player started the trial; an automatic one
		-- (at level 10, 20...) must not stop them moving or typing in chat.
		if req.manual and f.input.SetFocus then f.input:SetFocus() end
		return
	end

	f.input:Hide()
	f.inputLabel:Hide()
	phase = "ready"
	f.amount:SetText(tostring(step.amount))
	PlaceUnit(false)
	f.unit:SetText(UnitText(step))
	f.cue:SetText(step.swapped and step.why and (AF.Colorize(step.why .. ".", C.good) .. "  " .. step.cue) or step.cue)
	if step.unit == "seconds" then
		f.done:SetLabel("Start  (" .. step.amount .. "s)")
	else
		f.done:SetLabel("Done")
	end
	f.swap:SetShown(step.stretch or #E.SwapOptions(db, step) > 0)
	f.swap:SetLabel(step.stretch and "Another" or "Swap")
	ShowButtons("main")
	f.bar:SetProgress(req.idx - 1, #req.plan.steps)
	Fit()
	Guard()
end

function Popup.IsBusy()
	return req ~= nil
end

-- A quest snack that is on screen but not started yet (a level-up may replace it).
function Popup.IsFreshSnack()
	return req ~= nil and req.kind == "snack" and req.idx == 1 and phase == "ready" and not req.xp
end

function Popup.Show(request)
	if not f then Build() end
	req = request
	req.idx = req.idx or 1
	req.cats = req.cats or {}
	suspended = false
	Restore()
	Render()
	closingQuietly = false
	f:Show()
	AF.PlaySound("popup")
	local step = CurrentStep()
	if step and not step.trial then
		SpeakStep(step, req.speakLead)
	elseif step then
		AF.Speak("Trial of Strength. As many " .. step.name .. " as you can.")
	end
end

local function CloseQuietly()
	closingQuietly = true
	local closed = req
	req = nil
	phase = nil
	if f then f:Hide() end
	closingQuietly = false
	AF.Fire("POPUP_CLOSED", closed)
end

-- Hide during combat, keep our place.
function Popup.Suspend()
	if not f or not req or suspended then return end
	suspended = true
	f:Hide()
end

function Popup.Resume()
	if not f or not req or not suspended then return end
	suspended = false
	f:Show()
end

function Popup.IsSuspended()
	return suspended
end

-- Swap the set on screen for a kinder alternative (or, for stretches, another stretch).
function Popup.Swap()
	local step = CurrentStep()
	if not step or phase ~= "ready" then return end
	local db = AF.db
	local new
	if step.stretch then
		new = E.StretchSet(db)
	else
		local options = E.SwapOptions(db, step)
		if #options == 0 then return end
		req.swapIndex = ((req.swapIndex or 0) % #options) + 1
		local tier = E.Tier(db)
		local pct = (req.plan.kind == "levelup" and not step.finisher) and tier.levelPct or tier.snackPct
		new = E.AltSet(db, step.cat, options[req.swapIndex], pct, AF.DayNumber())
	end
	for _, k in ipairs({ "round", "finisher", "cooldown" }) do new[k] = step[k] end
	req.plan.steps[req.idx] = new
	Render()
	SpeakStep(new, "Swapped:")
end

local function Finish()
	-- Only exercises done as planned tune your numbers (not swaps or stretches).
	if next(req.cats) == nil then
		AF.Speak("Nicely done.")
		CloseQuietly()
		return
	end
	phase = "feedback"
	f.quip:SetText("How did that feel?")
	f.step:SetText("")
	f.swap:Hide()
	f.cue:SetText("Your answer tunes the next sets. Too easy adds a little, too hard takes some away. " ..
		"Every few \"just right\" answers add one rep, so you keep getting stronger.")
	f.bar:SetProgress(1, 1)
	ShowButtons("feedback")
	Fit()
	Guard()
	AF.Speak("Done! How did that feel?")
end

function Popup.FinishStep()
	local step = CurrentStep()
	if not step then return end
	local db = AF.db
	local day = AF.DayNumber()
	local xp, bonus, levels, weekGoal = E.CompleteSet(db, step, day)
	if not step.swapped and not step.stretch then req.cats[step.cat] = true end
	req.xp = (req.xp or 0) + xp
	AF.PlaySound("done")
	AF.ToastXP(xp, bonus, levels, AF.CategoryInfo[step.cat].icon)
	if weekGoal and AF.WeekGoalReached then AF.WeekGoalReached() end
	AF.Fire("STATS_CHANGED")
	if req.idx < #req.plan.steps then
		req.idx = req.idx + 1
		req.swapIndex = nil
		Render()
		SpeakStep(CurrentStep(), "Next:")
		return
	end
	-- Whole plan finished.
	if req.plan.kind == "levelup" then
		local bxp, blv = E.AwardBonus(db, E.XP_CIRCUIT_BONUS, day)
		AF.ToastXP(bxp, 0, blv, "Interface\\Icons\\Ability_Warrior_BattleShout")
	end
	Finish()
end

function Popup.Done()
	if not req then return end
	local step = CurrentStep()
	if phase == "trial" then
		local value = tonumber(f.input:GetText() or "")
		if not value or value <= 0 then
			f.inputLabel:SetText(AF.Colorize("Type a number first:", C.bad))
			return
		end
		value = math.floor(value)
		-- A typo (120 instead of 12) would make every set ten times harder: ask once.
		local prev = step.previous or 0
		if value > math.max(prev * 2, prev + 15) and req.confirm ~= value then
			req.confirm = value
			f.inputLabel:SetText(AF.Colorize("Much more than last time. Save again?", C.gold))
			if f.input.ClearFocus then f.input:ClearFocus() end
			return
		end
		req.confirm = nil
		f.inputLabel:SetText("Your number:")
		if f.input.ClearFocus then f.input:ClearFocus() end
		local day = AF.DayNumber()
		local old, new = E.SetTrialMax(AF.db, step.cat, value, day)
		req.results = req.results or {}
		req.results[#req.results + 1] = { name = step.name, old = old, new = new, unit = step.unit }
		local xp, levels = E.AwardBonus(AF.db, E.XP_TRIAL, day)
		AF.ToastXP(xp, 0, levels, AF.CategoryInfo[step.cat].icon)
		AF.Fire("STATS_CHANGED")
		if req.idx < #req.plan.steps then
			req.idx = req.idx + 1
			Render()
			return
		end
		Popup.ShowTrialResults()
		return
	end
	if phase == "ready" and step.unit == "seconds" then
		phase = "timing"
		timer.total = step.amount
		timer.left = step.amount
		f.done:SetLabel("Finish")
		Guard() -- a double-click on Start shouldn't end the timer at once
		f.later:Hide()
		f.skip:Hide()
		f.swap:Hide()
		return
	end
	if phase == "timing" or phase == "ready" then
		if phase == "timing" then
			-- Finished early: count the seconds actually done.
			local doneSec = math.max(5, math.floor(timer.total - timer.left + 0.5))
			step.amount = math.min(step.amount, doneSec)
			step.work = step.amount
		end
		Popup.FinishStep()
	end
end

function Popup.ShowTrialResults()
	phase = "result"
	local lines = {}
	for _, r in ipairs(req.results or {}) do
		local unit = r.unit == "seconds" and "s" or ""
		local diff = r.new - r.old
		local d = diff > 0 and AF.Colorize(" (+" .. diff .. ")", C.good) or (diff < 0 and AF.Colorize(" (" .. diff .. ")", C.bad) or "")
		lines[#lines + 1] = r.name .. ":  " .. r.old .. unit .. "  ->  " .. AF.Colorize(r.new .. unit, C.gold) .. d
	end
	f.input:Hide()
	f.inputLabel:Hide()
	f.art:Hide()
	f.swap:Hide()
	f.amount:SetText("")
	f.unit:SetText("")
	f.quip:SetText("Trial complete. Your workouts now use these numbers.")
	f.cue:SetText(table.concat(lines, "\n"))
	Fit()
	f.yes:SetLabel("Great")
	f.no:SetLabel("Open stats")
	f.yes:SetScript("OnClick", function() if not Guarded() then CloseQuietly() end end)
	f.no:SetScript("OnClick", function() if not Guarded() then CloseQuietly(); AF.MainWindow.Show("profile") end end)
	ShowButtons("suggest")
	Guard()
	AF.Speak("Trial complete. Well done.")
end

local function Suggest(cat, kind)
	local db = AF.db
	local st = db.ex[cat]
	local ladder = AF.Ladders[cat]
	local current = ladder[st.variant]
	local target = ladder[st.variant + (kind == "promote" and 1 or -1)]
	phase = "suggest"
	f.amount:SetText("")
	f.unit:SetText("")
	f.swap:Hide()
	ShowArt(target.id)
	if kind == "promote" then
		f.quip:SetText("You have outgrown " .. current.name .. "!")
		f.cue:SetText("Your max is now " .. st.max .. ". Ready to move up to " .. AF.Colorize(target.name, C.gold) ..
			"? You start a bit lower on the new exercise and build up again.")
		f.yes:SetLabel("Move up")
	else
		f.quip:SetText(current.name .. " feels too hard right now.")
		f.cue:SetText("That's completely fine. Want to switch to " .. AF.Colorize(target.name, C.gold) ..
			" for a while? You can move back up any time.")
		f.yes:SetLabel("Switch")
	end
	f.no:SetLabel(kind == "promote" and "Not yet" or "Keep this one")
	Fit()
	f.icon:SetIcon(AF.CategoryInfo[cat].icon)
	f.name:SetText(target.name)
	f.cat:SetText("")
	f.yes:SetScript("OnClick", function()
		if Guarded() then return end
		E.ChangeVariant(db, cat, kind == "promote" and 1 or -1, AF.DayNumber())
		AF.Print(AF.CategoryInfo[cat].name .. " exercise is now " .. AF.Colorize(target.name, C.gold) .. ".")
		AF.Fire("STATS_CHANGED")
		Popup.NextSuggestion()
	end)
	f.no:SetScript("OnClick", function() if not Guarded() then Popup.NextSuggestion() end end)
	ShowButtons("suggest")
	Guard()
end

function Popup.NextSuggestion()
	local s = req and req.suggestions and table.remove(req.suggestions, 1)
	if s then
		Suggest(s.cat, s.kind)
	else
		CloseQuietly()
	end
end

function Popup.Feedback(fb)
	if not req or phase ~= "feedback" then return end
	local db = AF.db
	local day = AF.DayNumber()
	req.suggestions = {}
	local changes = {}
	for _, cat in ipairs(AF.Categories) do
		if req.cats[cat] then
			local old, new, suggestion = E.Feedback(db, cat, fb, day)
			if new ~= old then
				changes[#changes + 1] = AF.CategoryInfo[cat].name .. " " .. old .. " -> " .. new
			end
			if suggestion then req.suggestions[#req.suggestions + 1] = { cat = cat, kind = suggestion } end
		end
	end
	if #changes > 0 then
		AF.Print("Max updated: " .. table.concat(changes, ", ") .. ".")
	end
	AF.Fire("STATS_CHANGED")
	Popup.NextSuggestion()
end

function Popup.Later(fromHide)
	if not req then return end
	local r = req
	if phase == "feedback" or phase == "suggest" or phase == "result" then
		-- The work is already done; closing here just skips the questions.
		if phase == "feedback" then Popup.Feedback("right") return end
		CloseQuietly()
		return
	end
	CloseQuietly()
	AF.Snooze(r)
	if not fromHide then
		AF.Print("Okay, I'll ask again in " .. AF.db.settings.snooze .. " minutes.")
	end
end

function Popup.Skip()
	if not req then return end
	AF.db.stats.skips = AF.db.stats.skips + 1
	CloseQuietly()
end

-- Close without it counting as a workout (a level-up is taking its place).
function Popup.Hide()
	if req then
		req.replaced = true
		CloseQuietly()
	end
end

function Popup.ApplyScale()
	if f then f:SetScale(AF.db.settings.scale or 1) end
end
