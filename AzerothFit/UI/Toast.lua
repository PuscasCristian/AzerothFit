-- Small reward banner near the top of the screen: fitness XP, and a bigger "DING" for fitness levels.
local _, AF = ...
local UI = AF.UI
local C = UI.C

local toast
local queue = {}
local showing = false

local function Build()
	toast = UI.Panel("AzerothFitToast", UIParent, 320, 64, C.xp)
	toast:SetPoint("TOP", UIParent, "TOP", 0, -140)
	toast:SetFrameStrata("DIALOG")
	toast:EnableMouse(false)
	toast:Hide()

	toast.icon = UI.Icon(toast, 40)
	toast.icon:SetPoint("LEFT", 12, -1)
	toast.title = UI.Text(toast, 15, C.gold, "OUTLINE")
	toast.title:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 10, -2)
	toast.title:SetPoint("RIGHT", -10, 0)
	toast.sub = UI.Text(toast, 11, C.text)
	toast.sub:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -4)
	toast.sub:SetPoint("RIGHT", -10, 0)
	toast.bar = UI.Bar(toast, 260, 5, C.xp)
	toast.bar:SetPoint("BOTTOMLEFT", toast.icon, "BOTTOMRIGHT", 10, 1)
	toast.bar:SetPoint("RIGHT", -12, 0)
	toast.bar.text:Hide()

	local ag = toast:CreateAnimationGroup()
	local fadeIn = ag:CreateAnimation("Alpha")
	fadeIn:SetFromAlpha(0)
	fadeIn:SetToAlpha(1)
	fadeIn:SetDuration(0.25)
	fadeIn:SetOrder(1)
	local hold = ag:CreateAnimation("Alpha")
	hold:SetFromAlpha(1)
	hold:SetToAlpha(1)
	hold:SetDuration(3)
	hold:SetOrder(2)
	local fadeOut = ag:CreateAnimation("Alpha")
	fadeOut:SetFromAlpha(1)
	fadeOut:SetToAlpha(0)
	fadeOut:SetDuration(0.6)
	fadeOut:SetOrder(3)
	ag:SetScript("OnFinished", function()
		toast:Hide()
		showing = false
		AF.ShowNextToast()
	end)
	toast.anim = ag
	toast.hold = hold
end

function AF.ShowNextToast()
	if showing or #queue == 0 then return end
	if not toast then Build() end
	local item = table.remove(queue, 1)
	showing = true
	toast.icon:SetIcon(item.icon)
	toast.title:SetText(item.title)
	toast.sub:SetText(item.sub or "")
	UI.SetAccent(toast, item.color or C.xp)
	local db = AF.db
	toast.bar:SetProgress(db.stats.xp, AF.Engine.XPToNext(db.stats.level), db.stats.rested)
	toast.hold:SetDuration(item.big and 4.5 or 2.5)
	toast:SetScale(db.settings.scale or 1)
	toast:SetHeight(item.big and 72 or 64)
	toast:SetAlpha(0)
	toast:Show()
	toast.anim:Stop()
	toast.anim:Play()
end

function AF.Toast(item)
	queue[#queue + 1] = item
	AF.ShowNextToast()
end

-- After a set: "+112 Fitness XP", and a level banner if you dinged.
function AF.ToastXP(xp, bonus, levels, icon)
	local db = AF.db
	local sub = "Fitness level " .. db.stats.level .. "  |  " .. AF.FormatNumber(db.stats.xp) ..
		" / " .. AF.FormatNumber(AF.Engine.XPToNext(db.stats.level))
	local title = "+" .. AF.FormatNumber(xp) .. " Fitness XP"
	if bonus and bonus > 0 then
		title = title .. AF.Colorize("  (rested +" .. AF.FormatNumber(bonus) .. ")", C.rested)
	end
	AF.Toast({ title = title, sub = sub, icon = icon, color = C.xp })
	if levels and levels > 0 then
		local lvl = db.stats.level
		local title2 = AF.Engine.TitleFor(lvl)
		AF.Toast({
			title = "FITNESS LEVEL " .. lvl .. "!",
			sub = "You are now: " .. title2,
			icon = "Interface\\Icons\\Spell_Holy_HolyNova",
			color = C.gold,
			big = true,
		})
		AF.PlaySound("ding")
		AF.Speak("Ding! Fitness level " .. lvl .. ". " .. title2 .. ".")
		AF.Print("You reached fitness level " .. lvl .. ": " .. AF.Colorize(title2, C.gold) .. "!")
		AF.Fire("STATS_CHANGED")
	end
end

------------------------------------------------------------------------
-- A small, quiet notice beside the minimap. It slides in for a few seconds and fades
-- away by itself. Left-click accepts, right-click dismisses. Never blocks the game.
local nudge
local current
local HOLD = 6

local function BuildNudge()
	nudge = CreateFrame("Button", "AzerothFitNudge", UIParent, "BackdropTemplate")
	nudge:SetSize(236, 50)
	UI.Backdrop(nudge, C.bg, C.border)
	nudge:SetFrameStrata("MEDIUM")
	nudge:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	nudge:Hide()
	local bar = UI.Tex(nudge, "ARTWORK", C.gold)
	bar:SetPoint("TOPLEFT", 1, -1)
	bar:SetPoint("BOTTOMLEFT", 1, 1)
	bar:SetWidth(3)
	nudge.bar = bar
	nudge.icon = UI.Icon(nudge, 32)
	nudge.icon:SetPoint("LEFT", 10, 0)
	nudge.title = UI.Text(nudge, 12, C.gold)
	nudge.title:SetPoint("TOPLEFT", nudge.icon, "TOPRIGHT", 8, -1)
	nudge.title:SetPoint("RIGHT", -8, 0)
	if nudge.title.SetWordWrap then nudge.title:SetWordWrap(false) end
	nudge.sub = UI.Text(nudge, 10, C.dim)
	nudge.sub:SetPoint("TOPLEFT", nudge.title, "BOTTOMLEFT", 0, -3)
	nudge.sub:SetPoint("RIGHT", -8, 0)
	if nudge.sub.SetWordWrap then nudge.sub:SetWordWrap(false) end
	nudge.timeLeft = 0

	nudge:SetScript("OnUpdate", function(self, elapsed)
		if self:IsMouseOver() then
			self:SetAlpha(1)
			return
		end
		self.timeLeft = self.timeLeft - elapsed
		if self.timeLeft <= 0 then
			self:Hide()
			current = nil
		elseif self.timeLeft < 1 then
			self:SetAlpha(self.timeLeft)
		elseif self.fadeIn < 1 then
			self.fadeIn = math.min(1, self.fadeIn + elapsed * 4)
			self:SetAlpha(self.fadeIn)
		end
	end)
	nudge:SetScript("OnClick", function(self, button)
		local n = current
		self:Hide()
		current = nil
		if n and button ~= "RightButton" and n.onAccept then n.onAccept() end
	end)
	nudge:SetScript("OnEnter", function(self)
		self:SetBackdropBorderColor(unpack(C.gold))
	end)
	nudge:SetScript("OnLeave", function(self)
		self:SetBackdropBorderColor(unpack(C.border))
	end)
end

local function Place()
	nudge:ClearAllPoints()
	if Minimap and Minimap:IsShown() then
		nudge:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -12, -4)
	else
		nudge:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -40)
	end
end

-- n = { title, sub, icon, color, onAccept, speak }
function AF.Nudge(n)
	if not nudge then BuildNudge() end
	current = n
	nudge.title:SetText(n.title)
	nudge.sub:SetText((n.sub or "") .. AF.Colorize("   click to start", C.faint))
	nudge.icon:SetIcon(n.icon)
	local c = n.color or C.gold
	nudge.bar:SetVertexColor(c[1], c[2], c[3], 1)
	nudge.timeLeft = n.hold or HOLD
	nudge.fadeIn = 0
	nudge:SetAlpha(0)
	nudge:SetScale(AF.db.settings.scale or 1)
	Place()
	nudge:Show()
	AF.PlaySound("tick")
	if n.speak then AF.Speak(n.speak) end
end

function AF.NudgeShown()
	return nudge and nudge:IsShown() or false
end
