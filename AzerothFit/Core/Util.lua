-- Shared helpers: printing, secret-value guards, dates, formatting, sound and voice.
local ADDON, AF = ...
AF.name = ADDON
AF.version = "0.2.0"

local floor = math.floor

function AF.Print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Azeroth Fit|r: " .. tostring(msg))
	end
end

-- The Forever client can hand addons "secret" values (names, units) that cannot be read.
function AF.IsSecret(v)
	local f = issecretvalue
	return f and f(v) and true or false
end

function AF.Safe(...)
	local n = select("#", ...)
	if n == 1 then
		local v = ...
		if AF.IsSecret(v) then return nil end
		return v
	end
	local t = { ... }
	for i = 1, n do
		if AF.IsSecret(t[i]) then t[i] = nil end
	end
	return unpack(t, 1, n)
end

function AF.TocVersion()
	return (GetBuildInfo and select(4, GetBuildInfo())) or 0
end

-- Calendar day as a whole number, so day gaps are easy to count.
function AF.DayNumber(t)
	local d = date("*t", t or time())
	return floor(time({ year = d.year, month = d.month, day = d.day, hour = 12 }) / 86400)
end

function AF.Round(x)
	return floor(x + 0.5)
end

function AF.FormatNumber(n)
	n = floor((n or 0) + 0.5)
	if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function AF.FormatDuration(sec)
	sec = floor(sec or 0)
	if sec < 60 then return sec .. "s" end
	local h = floor(sec / 3600)
	local m = floor((sec % 3600) / 60)
	if h > 0 then
		return m > 0 and (h .. "h " .. m .. "m") or (h .. "h")
	end
	return m .. "m"
end

function AF.Hex(c)
	return string.format("ff%02x%02x%02x", floor(c[1] * 255), floor(c[2] * 255), floor(c[3] * 255))
end

function AF.Colorize(text, c)
	return "|c" .. AF.Hex(c) .. text .. "|r"
end

local sounds = {
	popup = { "IG_QUEST_LIST_OPEN", 875 },
	done = { "IG_QUEST_LIST_COMPLETE", 878 },
	ding = { "LEVELUPSOUND", 888 },
	click = { "U_CHAT_SCROLL_BUTTON", 1115 },
	tick = { "IG_MAINMENU_OPTION_CHECKBOX_ON", 856 },
}

function AF.PlaySound(kind)
	local db = AF.db
	if db and not db.settings.sound then return end
	local s = sounds[kind]
	if not s or not PlaySound then return end
	local id = (SOUNDKIT and SOUNDKIT[s[1]]) or s[2]
	pcall(PlaySound, id)
end

function AF.Speak(text)
	local db = AF.db
	if not db or not db.settings.voice then return end
	if not (C_VoiceChat and C_VoiceChat.SpeakText) then return end
	local voice = 0
	if C_TTSSettings and C_TTSSettings.GetVoiceOptionID and Enum and Enum.TtsVoiceType then
		voice = C_TTSSettings.GetVoiceOptionID(Enum.TtsVoiceType.Standard) or 0
	end
	local rate, volume = 0, 100
	if C_TTSSettings then
		if C_TTSSettings.GetSpeechRate then rate = C_TTSSettings.GetSpeechRate() or rate end
		if C_TTSSettings.GetSpeechVolume then volume = C_TTSSettings.GetSpeechVolume() or volume end
	end
	if C_VoiceChat.StopSpeakingText then pcall(C_VoiceChat.StopSpeakingText) end
	if AF.TocVersion() >= 16000 then
		-- Forever and newer clients: (voice, text, rate, volume)
		pcall(C_VoiceChat.SpeakText, voice, text, rate, volume)
	else
		local dest = (Enum and Enum.VoiceTtsDestination and Enum.VoiceTtsDestination.LocalPlayback) or 1
		pcall(C_VoiceChat.SpeakText, voice, text, dest, rate, volume)
	end
end

function AF.InCombat()
	if InCombatLockdown and InCombatLockdown() then return true end
	return UnitAffectingCombat and AF.Safe(UnitAffectingCombat("player")) and true or false
end

-- True inside dungeons and raids (battlegrounds and the open world count as outside).
function AF.InPausedInstance()
	if not IsInInstance then return false end
	local inside, kind = IsInInstance()
	return inside and (kind == "party" or kind == "raid") or false
end

-- Tiny event bus so files can listen without each owning a frame.
local listeners = {}
AF.eventFrame = CreateFrame("Frame")
AF.eventFrame:SetScript("OnEvent", function(_, event, ...)
	local list = listeners[event]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end
end)

function AF.On(event, fn)
	if not listeners[event] then
		listeners[event] = {}
		AF.eventFrame:RegisterEvent(event)
	end
	table.insert(listeners[event], fn)
end

-- Internal messages between our own modules (not game events).
local internal = {}
function AF.Listen(msg, fn)
	internal[msg] = internal[msg] or {}
	table.insert(internal[msg], fn)
end

function AF.Fire(msg, ...)
	local list = internal[msg]
	if not list then return end
	for i = 1, #list do list[i](...) end
end
