-- Minimal fake WoW client: enough of the API for Azeroth Fit to load and run its logic.
local M = {}
M.log, M.sent, M.chat, M.spoken, M.errors = {}, {}, {}, {}, {}
M.now = os.time({ year = 2026, month = 11, day = 7, hour = 18 })
M.combat = false
M.instance = false
M.timers = {}
M.events = {}
M.tooltipLines = {}
M.unitNames = { player = { "Tamsin", "Oakhart" } }

local Methods = {}
local function NewObject(kind, name, parent)
	local o = { __kind = kind, __scripts = {}, __shown = true, __text = "", __w = 100, __h = 20, __enabled = true, __parent = parent }
	if kind == "Texture" or kind == "FontString" then o.__shown = true end
	setmetatable(o, { __index = function(_, k)
		local m = Methods[k]
		if m then return m end
		return function() end
	end })
	if name then _G[name] = o end
	return o
end
M.NewObject = NewObject

function Methods:SetScript(s, fn) self.__scripts[s] = fn end
function Methods:GetScript(s) return self.__scripts[s] end
function Methods:HookScript(s, fn)
	local old = self.__scripts[s]
	self.__scripts[s] = function(...) if old then old(...) end fn(...) end
end
function Methods:Show()
	local was = self.__shown
	self.__shown = true
	if not was and self.__scripts.OnShow then self.__scripts.OnShow(self) end
end
function Methods:Hide()
	local was = self.__shown
	self.__shown = false
	if was and self.__scripts.OnHide then self.__scripts.OnHide(self) end
end
function Methods:SetShown(v) if v then self:Show() else self:Hide() end end
function Methods:IsShown() return self.__shown end
function Methods:IsVisible() return self.__shown end
function Methods:SetText(t) self.__text = t == nil and "" or tostring(t) end
function Methods:GetText() return self.__text end
function Methods:SetSize(w, h) self.__w, self.__h = w, h end
function Methods:SetWidth(w) self.__w = w end
function Methods:SetHeight(h) self.__h = h end
function Methods:GetWidth() return self.__w end
function Methods:GetHeight() return self.__h end
function Methods:IsEnabled() return self.__enabled end
function Methods:SetEnabled(v)
	self.__enabled = v and true or false
	local s = self.__scripts[v and "OnEnable" or "OnDisable"]
	if s then s(self) end
end
function Methods:Enable() self:SetEnabled(true) end
function Methods:Disable() self:SetEnabled(false) end
function Methods:GetPoint() return "CENTER", UIParent, "CENTER", 0, 0 end
function Methods:GetCenter() return 0, 0 end
function Methods:GetEffectiveScale() return 1 end
function Methods:GetParent() return self.__parent end
function Methods:CreateFontString() return NewObject("FontString", nil, self) end
function Methods:CreateTexture() return NewObject("Texture", nil, self) end
function Methods:CreateAnimationGroup()
	local g = NewObject("AnimationGroup", nil, self)
	g.CreateAnimation = function() return NewObject("Animation") end
	return g
end
function Methods:RegisterEvent(e)
	M.events[e] = M.events[e] or {}
	M.events[e][self] = true
end
function Methods:UnregisterEvent(e) if M.events[e] then M.events[e][self] = nil end end
function Methods:Click(button)
	if not self.__enabled then return end
	local s = self.__scripts.OnClick
	if s then s(self, button or "LeftButton") end
end
function Methods:IsUnit() return false end
function Methods:SetOwner() end
function Methods:AddLine(t) M.tooltipLines[#M.tooltipLines + 1] = t end
function Methods:GetUnit() return M.tooltipUnitName, M.tooltipUnit end
function Methods:AddMessage(t) M.log[#M.log + 1] = (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- Globals
_G.CreateFrame = function(kind, name, parent) return NewObject(kind, name, parent) end
_G.UIParent = NewObject("Frame", "UIParent")
_G.Minimap = NewObject("Frame", "Minimap")
_G.GameTooltip = NewObject("GameTooltip", "GameTooltip")
_G.DEFAULT_CHAT_FRAME = NewObject("Frame", "DEFAULT_CHAT_FRAME")
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.UISpecialFrames = {}
_G.SlashCmdList = {}
_G.StaticPopupDialogs = {}
_G.StaticPopup_Show = function(name) M.staticShown = name end
_G.SOUNDKIT = {}
_G.PlaySound = function() end
_G.geterrorhandler = function() return function(e) M.errors[#M.errors + 1] = e; print("ERROR: " .. tostring(e)) end end
_G.GetBuildInfo = function() return "1.60.1", "1", "", 16001 end
_G.time = function(t) if t then return os.time(t) end return M.now end
_G.date = function(fmt, t) return os.date(fmt, t or M.now) end
_G.GetTime = function() return M.now end
_G.InCombatLockdown = function() return M.combat end
_G.UnitAffectingCombat = function() return M.combat end
_G.IsInInstance = function() if M.instance then return true, "party" end return false, "none" end
_G.IsInGuild = function() return true end
_G.IsInGroup = function() return false end
_G.IsInRaid = function() return false end
_G.UnitName = function(u) local n = M.unitNames[u]; if n then return n[1], n[2] end end
_G.UnitFullName = _G.UnitName
_G.GetNormalizedRealmName = function() return nil end
_G.UnitLevel = function() return M.level or 10 end
_G.UnitClass = function() return "Rogue", "ROGUE" end
_G.RAID_CLASS_COLORS = { ROGUE = { r = 1, g = 0.96, b = 0.41 } }
_G.UnitIsPlayer = function(u) return M.unitNames[u] ~= nil end
_G.UnitIsUnit = function(a, b) return a == b or (M.unitNames[a] and M.unitNames[b] and M.unitNames[a][1] == M.unitNames[b][1]) or false end
_G.UnitExists = function(u) return M.unitNames[u] ~= nil end
_G.UnitFactionGroup = function() return "Alliance" end
_G.GetCursorPosition = function() return 0, 0 end
M.auras = {}
M.resting = false
_G.C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return M.auras[id] and { spellId = id } or nil end }
_G.IsResting = function() return M.resting end
_G.C_QuestLog = { GetTitleForQuestID = function(id) return "Quest #" .. id end }
_G.C_ChatInfo = {
	RegisterAddonMessagePrefix = function() return true end,
	SendAddonMessage = function(p, msg, ch, target) M.sent[#M.sent + 1] = { p, msg, ch, target } return 0 end,
	InChatMessagingLockdown = function() return false end,
	SendChatMessage = function(msg, ch) M.chat[#M.chat + 1] = { msg, ch } end,
}
_G.C_VoiceChat = { SpeakText = function(v, text) M.spoken[#M.spoken + 1] = text end, StopSpeakingText = function() end }
_G.Enum = { TooltipDataType = { Unit = 2, Item = 0 } }
_G.TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) M.tooltipHook = fn end }
_G.Settings = {
	RegisterCanvasLayoutCategory = function() return {} end,
	RegisterAddOnCategory = function() end,
}
_G.C_Timer = { After = function(sec, fn) M.timers[#M.timers + 1] = { at = M.now + sec, fn = fn } end }
_G.strsplit = function(sep, s)
	local out = {}
	for piece in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = piece end
	return unpack(out)
end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

function M.Fire(event, ...)
	local regs = M.events[event]
	if not regs then return end
	for frame in pairs(regs) do
		local s = frame.__scripts.OnEvent
		if s then s(frame, event, ...) end
	end
end

-- Move the clock forward, running due timers in order.
function M.Advance(sec)
	local target = M.now + sec
	while true do
		table.sort(M.timers, function(a, b) return a.at < b.at end)
		local t = M.timers[1]
		if not t or t.at > target then break end
		table.remove(M.timers, 1)
		M.now = math.max(M.now, t.at)
		t.fn()
	end
	M.now = target
end

function M.LoadAddon(dir, name)
	local ns = {}
	local toc = io.open(dir .. "/" .. name .. ".toc"):read("*a")
	for line in toc:gmatch("[^\r\n]+") do
		if line:match("%.lua$") then
			local path = dir .. "/" .. line:gsub("\\", "/")
			local chunk = assert(loadfile(path))
			chunk(name, ns)
		end
	end
	return ns
end

return M
