-- Small widget kit with one consistent look: dark panels, thin borders, a gold accent.
local _, AF = ...

local UI = {}
AF.UI = UI

local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
UI.FONT = FONT

UI.C = {
	bg = { 0.055, 0.055, 0.07, 0.96 },
	panel = { 0.10, 0.10, 0.12, 1 },
	panelHover = { 0.15, 0.15, 0.18, 1 },
	border = { 0.30, 0.26, 0.17, 1 },
	borderSoft = { 0.22, 0.22, 0.25, 1 },
	gold = { 1.00, 0.82, 0.20 },
	text = { 0.93, 0.93, 0.93 },
	dim = { 0.62, 0.62, 0.66 },
	faint = { 0.42, 0.42, 0.46 },
	xp = { 0.22, 0.78, 0.66 },
	rested = { 0.32, 0.55, 1.00 },
	good = { 0.40, 0.85, 0.42 },
	bad = { 1.00, 0.40, 0.35 },
}
local C = UI.C

function UI.Backdrop(f, bg, border)
	if not f.SetBackdrop and BackdropTemplateMixin and Mixin then Mixin(f, BackdropTemplateMixin) end
	if not f.SetBackdrop then return end
	f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
	f:SetBackdropColor(unpack(bg or C.bg))
	f:SetBackdropBorderColor(unpack(border or C.border))
end

function UI.Tex(parent, layer, color, sub)
	local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
	t:SetTexture(WHITE)
	if color then t:SetVertexColor(color[1], color[2], color[3], color[4] or 1) end
	return t
end

-- Every text we create is remembered, so the "Text size" setting can resize them all.
UI.fonts = setmetatable({}, { __mode = "k" })

local function TextScale()
	return (AF.db and AF.db.settings.textScale) or 1
end

local function ScaledSize(size)
	return math.max(7, math.floor(size * TextScale() + 0.5))
end

function UI.ApplyTextScale()
	for fs, info in pairs(UI.fonts) do
		fs:SetFont(FONT, ScaledSize(info.size), info.flags)
	end
end

function UI.Text(parent, size, color, flags, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	UI.fonts[fs] = { size = size or 12, flags = flags or "" }
	fs:SetFont(FONT, ScaledSize(size or 12), flags or "")
	local c = color or C.text
	fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
	fs:SetJustifyH(justify or "LEFT")
	if fs.SetWordWrap then fs:SetWordWrap(true) end
	return fs
end

-- A window: dark panel, soft shadow, gold accent line on top, drag to move.
function UI.Panel(name, parent, w, h, accent)
	local f = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
	f:SetSize(w, h)
	UI.Backdrop(f, C.bg, C.border)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)

	local shadow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	shadow:SetTexture(WHITE)
	shadow:SetVertexColor(0, 0, 0, 0.45)
	shadow:SetPoint("TOPLEFT", -5, 5)
	shadow:SetPoint("BOTTOMRIGHT", 5, -5)
	f.shadow = shadow

	local bar = UI.Tex(f, "ARTWORK", accent or C.gold)
	bar:SetPoint("TOPLEFT", 1, -1)
	bar:SetPoint("TOPRIGHT", -1, -1)
	bar:SetHeight(3)
	f.accent = bar

	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) self:StartMoving() end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		if self.OnMoved then self:OnMoved() end
	end)
	return f
end

function UI.SetAccent(f, color)
	if f.accent then f.accent:SetVertexColor(color[1], color[2], color[3], 1) end
end

-- Flat button. kind: "primary" (gold border), "ghost" (quiet) or "danger".
function UI.Button(parent, text, w, h, kind)
	local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
	b:SetSize(w or 100, h or 26)
	local bg, border, hover
	if kind == "primary" then
		bg, border, hover = { 0.24, 0.18, 0.05, 1 }, { 0.95, 0.74, 0.22, 1 }, { 0.34, 0.26, 0.08, 1 }
	elseif kind == "danger" then
		bg, border, hover = { 0.20, 0.07, 0.07, 1 }, { 0.70, 0.25, 0.22, 1 }, { 0.30, 0.10, 0.10, 1 }
	else
		bg, border, hover = C.panel, C.borderSoft, C.panelHover
	end
	UI.Backdrop(b, bg, border)
	b.label = UI.Text(b, 12, kind == "primary" and { 1, 0.9, 0.6 } or C.text, nil, "CENTER")
	b.label:SetPoint("CENTER", 0, 0)
	b.label:SetText(text or "")
	b.SetLabel = function(self, t) self.label:SetText(t) end
	b:SetScript("OnEnter", function(self)
		if self:IsEnabled() and self.SetBackdropColor then self:SetBackdropColor(unpack(hover)) end
		if self.tip and GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		if self.SetBackdropColor then self:SetBackdropColor(unpack(bg)) end
		if self.tip and GameTooltip then GameTooltip:Hide() end
	end)
	b:SetScript("OnDisable", function(self) self:SetAlpha(0.4) end)
	b:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
	b:HookScript("OnClick", function() AF.PlaySound("click") end)
	return b
end

function UI.CloseButton(parent, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(20, 20)
	b:SetPoint("TOPRIGHT", -6, -8)
	local x = UI.Text(b, 14, C.dim, nil, "CENTER")
	x:SetPoint("CENTER")
	x:SetText("x")
	b:SetScript("OnEnter", function() x:SetTextColor(1, 1, 1) end)
	b:SetScript("OnLeave", function() x:SetTextColor(C.dim[1], C.dim[2], C.dim[3]) end)
	b:SetScript("OnClick", onClick)
	return b
end

-- Progress bar with an optional second (rested) segment.
function UI.Bar(parent, w, h, color)
	local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	f:SetSize(w, h)
	UI.Backdrop(f, { 0.03, 0.03, 0.04, 1 }, C.borderSoft)
	local fill = UI.Tex(f, "ARTWORK", color or C.xp)
	fill:SetPoint("TOPLEFT", 1, -1)
	fill:SetPoint("BOTTOMLEFT", 1, 1)
	fill:SetWidth(1)
	local extra = UI.Tex(f, "ARTWORK", C.rested, -1)
	extra:SetPoint("TOPLEFT", fill, "TOPRIGHT")
	extra:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
	extra:SetWidth(1)
	extra:SetAlpha(0.55)
	extra:Hide()
	f.fill, f.extra = fill, extra
	f.text = UI.Text(f, math.max(9, h - 4), C.text, "OUTLINE", "CENTER")
	f.text:SetPoint("CENTER", 0, 0)
	function f:SetProgress(v, maxV, extraV)
		local inner = math.max(1, self:GetWidth() - 2)
		local p = (maxV and maxV > 0) and math.min(1, math.max(0, v / maxV)) or 0
		self.fill:SetWidth(math.max(0.001, inner * p))
		self.fill:SetShown(p > 0)
		if extraV and extraV > 0 and maxV and maxV > 0 then
			local e = math.min(1 - p, extraV / maxV)
			self.extra:SetWidth(math.max(0.001, inner * e))
			self.extra:SetShown(e > 0)
		else
			self.extra:Hide()
		end
	end
	function f:SetColor(c) self.fill:SetVertexColor(c[1], c[2], c[3], 1) end
	return f
end

-- Checkbox drawn by hand, so it looks the same on every client.
function UI.Check(parent, label, get, set, tip)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(260, 20)
	local box = CreateFrame("Frame", nil, b, "BackdropTemplate")
	box:SetSize(16, 16)
	box:SetPoint("LEFT", 0, 0)
	UI.Backdrop(box, { 0.03, 0.03, 0.04, 1 }, C.borderSoft)
	local mark = UI.Tex(box, "OVERLAY", C.gold)
	mark:SetPoint("TOPLEFT", 4, -4)
	mark:SetPoint("BOTTOMRIGHT", -4, 4)
	local fs = UI.Text(b, 12, C.text)
	fs:SetPoint("LEFT", box, "RIGHT", 8, 0)
	fs:SetText(label)
	b.tip = tip
	function b:Refresh() mark:SetShown(get() and true or false) end
	b:SetScript("OnClick", function(self)
		set(not get())
		AF.PlaySound("tick")
		self:Refresh()
	end)
	b:SetScript("OnEnter", function(self)
		box:SetBackdropBorderColor(unpack(C.gold))
		if self.tip and GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function()
		box:SetBackdropBorderColor(unpack(C.borderSoft))
		if GameTooltip then GameTooltip:Hide() end
	end)
	b:Refresh()
	return b
end

-- Label  [-]  value  [+]
function UI.Stepper(parent, label, minV, maxV, step, get, set, fmt)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(300, 24)
	local fs = UI.Text(f, 12, C.text)
	fs:SetPoint("LEFT", 0, 0)
	fs:SetText(label)
	local plus = UI.Button(f, "+", 24, 22)
	plus:SetPoint("RIGHT", 0, 0)
	local val = UI.Text(f, 12, C.gold, nil, "CENTER")
	val:SetWidth(70)
	val:SetPoint("RIGHT", plus, "LEFT", -4, 0)
	local minus = UI.Button(f, "-", 24, 22)
	minus:SetPoint("RIGHT", val, "LEFT", -4, 0)
	function f:Refresh()
		local v = get()
		val:SetText(fmt and fmt(v) or tostring(v))
		minus:SetEnabled(v > minV)
		plus:SetEnabled(v < maxV)
	end
	minus:SetScript("OnClick", function() set(math.max(minV, get() - step)); f:Refresh() end)
	plus:SetScript("OnClick", function() set(math.min(maxV, get() + step)); f:Refresh() end)
	f:Refresh()
	return f
end

function UI.Icon(parent, size)
	local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	holder:SetSize(size + 2, size + 2)
	UI.Backdrop(holder, { 0, 0, 0, 1 }, C.border)
	local t = holder:CreateTexture(nil, "ARTWORK")
	t:SetPoint("TOPLEFT", 1, -1)
	t:SetPoint("BOTTOMRIGHT", -1, 1)
	t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	holder.tex = t
	function holder:SetIcon(path)
		self.tex:SetTexture(path or "Interface\\Icons\\INV_Misc_QuestionMark")
	end
	return holder
end

-- Small pop-up list of choices next to a button. options: { {key, label, tip}, ... }
local menu
function UI.ChoiceMenu(anchor, options, onPick, selected)
	if not menu then
		menu = CreateFrame("Frame", "AzerothFitChoiceMenu", UIParent, "BackdropTemplate")
		UI.Backdrop(menu, C.bg, C.border)
		menu:SetFrameStrata("FULLSCREEN_DIALOG")
		menu:SetClampedToScreen(true)
		menu:EnableMouse(true)
		menu.buttons = {}
		menu:Hide()
		if UISpecialFrames then table.insert(UISpecialFrames, "AzerothFitChoiceMenu") end
	end
	if menu:IsShown() and menu.anchor == anchor then menu:Hide() return end
	for _, b in ipairs(menu.buttons) do b:Hide() end
	local w = math.max(160, anchor:GetWidth())
	for i, opt in ipairs(options) do
		local b = menu.buttons[i]
		if not b then
			b = UI.Button(menu, "", w - 8, 24)
			menu.buttons[i] = b
		end
		b:SetWidth(w - 8)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 26)
		local mark = (opt.key == selected) and "  (default)" or ""
		b:SetLabel(opt.label .. mark)
		b.tip = opt.tip
		b:SetScript("OnClick", function()
			menu:Hide()
			onPick(opt.key)
		end)
		b:Show()
	end
	menu:SetSize(w, #options * 26 + 6)
	menu:SetScale(AF.db and AF.db.settings.scale or 1)
	menu:ClearAllPoints()
	-- Open downward from things near the top of the screen (like the minimap), upward otherwise.
	local _, y = anchor:GetCenter()
	local top = UIParent and UIParent:GetHeight() or 768
	if y and top and y > top / 2 then
		menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
	else
		menu:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
	end
	menu.anchor = anchor
	menu:Show()
end

function UI.HideMenu()
	if menu then menu:Hide() end
end

-- Number entry box.
function UI.NumberBox(parent, w)
	local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
	e:SetSize(w or 80, 30)
	UI.Backdrop(e, { 0.03, 0.03, 0.04, 1 }, C.gold)
	UI.fonts[e] = { size = 18, flags = "" }
	e:SetFont(FONT, ScaledSize(18), "")
	e:SetTextColor(1, 1, 1)
	e:SetJustifyH("CENTER")
	e:SetAutoFocus(false)
	e:SetNumeric(true)
	e:SetMaxLetters(4)
	e:SetTextInsets(4, 4, 0, 0)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return e
end
