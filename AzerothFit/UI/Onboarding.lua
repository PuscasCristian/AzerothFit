-- First-run setup: pick a tier, then (optionally) tell us your current max.
local _, AF = ...
local UI = AF.UI
local C = UI.C
local E = AF.Engine

local Onboarding = {}
AF.Onboarding = Onboarding

local f
local chosen = 3
local cards = {}

local function RefreshCards()
	for i, card in ipairs(cards) do
		local on = (i == chosen)
		card:SetBackdropBorderColor(unpack(on and { 0.95, 0.74, 0.22, 1 } or C.borderSoft))
		card:SetBackdropColor(unpack(on and { 0.16, 0.13, 0.06, 1 } or C.panel))
		card.name:SetTextColor(unpack(on and C.gold or C.text))
	end
end

local function BuildPage1(page)
	local title = UI.Text(page, 20, C.gold)
	title:SetPoint("TOPLEFT", 20, -20)
	title:SetText("Welcome to Azeroth Fit")
	local intro = UI.Text(page, 12, C.text)
	intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	intro:SetPoint("RIGHT", -20, 0)
	intro:SetText("Level up in real life while you level in Azeroth. Turning in a quest gives you a short exercise " ..
		"snack, leveling up gives you a mini workout, and your own fitness level grows with every set.\n\n" ..
		"Where are you starting from? You can change this any time.")

	local y = -130
	for i, tier in ipairs(AF.Tiers) do
		local card = CreateFrame("Button", nil, page, "BackdropTemplate")
		card:SetSize(520, 54)
		card:SetPoint("TOPLEFT", 20, y)
		UI.Backdrop(card, C.panel, C.borderSoft)
		card.name = UI.Text(card, 14, C.text)
		card.name:SetPoint("TOPLEFT", 12, -9)
		card.name:SetText(i .. ". " .. tier.name)
		card.tag = UI.Text(card, 11, C.dim, nil, "RIGHT")
		card.tag:SetPoint("TOPRIGHT", -12, -10)
		card.tag:SetText(tier.tag .. "  |  up to " .. tier.capSets .. " sets a day")
		card.blurb = UI.Text(card, 11, C.dim)
		card.blurb:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -5)
		card.blurb:SetPoint("RIGHT", -12, 0)
		card.blurb:SetText(tier.blurb)
		card:SetScript("OnClick", function()
			chosen = i
			AF.PlaySound("tick")
			RefreshCards()
		end)
		card:SetScript("OnEnter", function(self)
			if i ~= chosen then self:SetBackdropColor(unpack(C.panelHover)) end
		end)
		card:SetScript("OnLeave", function() RefreshCards() end)
		cards[i] = card
		y = y - 60
	end

	local note = UI.Text(page, 10, C.faint)
	note:SetPoint("BOTTOMLEFT", 20, 52)
	note:SetPoint("RIGHT", -20, 0)
	note:SetText("Stop if anything hurts. If you have a heart, joint or other health condition, check with your doctor before starting.")

	local nextBtn = UI.Button(page, "Next", 160, 30, "primary")
	nextBtn:SetPoint("BOTTOMRIGHT", -20, 14)
	nextBtn:SetScript("OnClick", function() Onboarding.ShowPage(2) end)
	local later = UI.Button(page, "Not now", 110, 30)
	later:SetPoint("RIGHT", nextBtn, "LEFT", -8, 0)
	later:SetScript("OnClick", function()
		f:Hide()
		AF.Print("Type /af whenever you want to set up Azeroth Fit.")
	end)
end

local boxes = {}

local function BuildPage2(page)
	local title = UI.Text(page, 20, C.gold)
	title:SetPoint("TOPLEFT", 20, -20)
	title:SetText("Quick test (optional)")
	page.intro = UI.Text(page, 12, C.text)
	page.intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	page.intro:SetPoint("RIGHT", -20, 0)
	page.intro:SetText("Your workouts are worked out from how many you can do in one go. If you know your numbers, " ..
		"type them in. Not sure? Try a set now, or leave the box empty to use a typical starting number.")

	local y = -110
	for _, cat in ipairs({ "push", "legs" }) do
		local row = CreateFrame("Frame", nil, page, "BackdropTemplate")
		row:SetSize(520, 92)
		row:SetPoint("TOPLEFT", 20, y)
		UI.Backdrop(row, C.panel, C.borderSoft)
		row.icon = UI.Icon(row, 40)
		row.icon:SetPoint("TOPLEFT", 12, -12)
		row.icon:SetIcon(AF.CategoryInfo[cat].icon)
		row.name = UI.Text(row, 14, AF.CategoryInfo[cat].color)
		row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 12, -2)
		row.cue = UI.Text(row, 11, C.dim)
		row.cue:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -5)
		row.cue:SetPoint("RIGHT", -120, 0)
		row.box = UI.NumberBox(row, 80)
		row.box:SetPoint("RIGHT", -16, 0)
		row.hint = UI.Text(row, 10, C.faint, nil, "CENTER")
		row.hint:SetPoint("TOP", row.box, "BOTTOM", 0, -4)
		boxes[cat] = row
		y = y - 100
	end

	local start = UI.Button(page, "Start training", 180, 30, "primary")
	start:SetPoint("BOTTOMRIGHT", -20, 14)
	start:SetScript("OnClick", function() Onboarding.Finish() end)
	local back = UI.Button(page, "Back", 110, 30)
	back:SetPoint("RIGHT", start, "LEFT", -8, 0)
	back:SetScript("OnClick", function() Onboarding.ShowPage(1) end)
end

local function Build()
	f = UI.Panel("AzerothFitOnboarding", UIParent, 560, 520)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:Hide()
	if UISpecialFrames then table.insert(UISpecialFrames, "AzerothFitOnboarding") end
	UI.CloseButton(f, function() f:Hide() end)
	f.page1 = CreateFrame("Frame", nil, f)
	f.page1:SetAllPoints()
	f.page2 = CreateFrame("Frame", nil, f)
	f.page2:SetAllPoints()
	BuildPage1(f.page1)
	BuildPage2(f.page2)
end

function Onboarding.ShowPage(n)
	f.page1:SetShown(n == 1)
	f.page2:SetShown(n == 2)
	if n == 1 then
		RefreshCards()
	else
		local tier = AF.Tiers[chosen]
		for cat, row in pairs(boxes) do
			local v = AF.Ladders[cat][tier.variants[cat]]
			local def = tier.max[cat] or v.startMax
			row.name:SetText(v.name)
			row.cue:SetText("How many " .. v.name:lower() .. " can you do in one go, with good form?\n" .. v.cue)
			row.box:SetText("")
			row.hint:SetText("empty = " .. def)
		end
	end
end

function Onboarding.Show()
	if not f then Build() end
	f:SetScale(AF.db.settings.scale or 1)
	chosen = AF.db.settings.tier or 3
	Onboarding.ShowPage(1)
	f:Show()
end

function Onboarding.Finish()
	local db = AF.db
	local day = AF.DayNumber()
	E.ApplyTier(db, chosen, true, day)
	for cat, row in pairs(boxes) do
		local v = tonumber(row.box:GetText() or "")
		if v and v > 0 then
			local variant, st = E.Variant(db, cat)
			st.max = math.max(variant.minMax or 1, math.floor(v))
			st.weekBase = st.max
		end
	end
	db.onboarded = true
	db.rampStart = day -- gentle start: lighter sets for the first two weeks
	f:Hide()
	local tier = AF.Tiers[chosen]
	AF.Print("You're set up as " .. AF.Colorize(tier.name, C.gold) .. ". The first two weeks start lighter and build up. " ..
		"Type /af for your stats and settings.")
	AF.Speak("Welcome to Azeroth Fit. Let's get stronger together.")
	AF.Fire("STATS_CHANGED")
	AF.FirstSet()
end
