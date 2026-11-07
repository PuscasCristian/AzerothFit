-- Sharing stats with other Azeroth Fit players, the tooltip line and /flex.
--
-- Messages (prefix "AzerothFit"):
--   "Q"                           please send me your stats
--   "S:1:lvl:tier:push:legs:coreSec:cardioSec:seconds:days:profileId:chars"   my stats
-- profileId is the same on every character of an account, so alts count as one person.
-- Stats go to GUILD and PARTY/RAID when they change (at most once a minute), and to
-- a single player by WHISPER when they mouse over us and ask.
local _, AF = ...
local E = AF.Engine
local C = AF.UI.C

local Comm = {}
AF.Comm = Comm

local PREFIX = "AzerothFit"
local PROTO = "1"
local BROADCAST_EVERY = 60
local REPLY_EVERY = 30
local ASK_EVERY = 120
local FRESH = 600

local lastBroadcast = 0
local broadcastPending = false
local lastReply = {}
local lastAsk = {}
local lastAnyAsk = 0
local shortIndex = {} -- first name -> stored sender
local normIndex = {} -- normalized full name -> stored sender
local myKey

local function Now() return GetTime and GetTime() or time() end

-- Forever names players "First Surname" (with a space); other clients use "Name-Realm".
local function IsForever()
	local v = AF.TocVersion()
	return v >= 16000 and v < 20000
end

-- Compare names without caring about spaces, dashes or case:
-- "Tamsin Oakhart" and "Tamsin-Oakhart" are the same player.
function Comm.Norm(s)
	if type(s) ~= "string" then return nil end
	return (s:lower():gsub("[%s%-']", ""))
end

local function FirstName(s)
	return type(s) == "string" and s:match("^([^%s%-]+)") or nil
end

-- Full name in the client's own format. second = surname on Forever, realm elsewhere.
function Comm.FullName(name, second)
	if not name then return nil end
	if not second or second == "" then
		if IsForever() then return name end
		second = AF.Safe(GetNormalizedRealmName and GetNormalizedRealmName())
	end
	if not second or second == "" then return name end
	return name .. (IsForever() and " " or "-") .. second
end

function Comm.MyKey()
	if myKey then return myKey end
	local name, second = AF.Safe(UnitName("player"))
	if not second or second == "" then
		local _, fullSecond = AF.Safe(UnitFullName("player"))
		if IsForever() then second = fullSecond end
	end
	myKey = Comm.FullName(name or "You", second)
	return myKey
end

-- Is this sender one of my own characters?
local function IsMe(sender)
	local n = Comm.Norm(sender)
	if not n then return false end
	if n == Comm.Norm(Comm.MyKey()) then return true end
	for _, ch in pairs(AF.db.chars or {}) do
		if ch.sender and Comm.Norm(ch.sender) == n then return true end
	end
	return false
end

local function Index(sender)
	local n = Comm.Norm(sender)
	if n then normIndex[n] = sender end
	local first = FirstName(sender)
	if first then shortIndex[first] = sender end
end

-- Key for a unit: the stored sender if we know them, otherwise their full name.
local function UnitKey(unit)
	local name, second = AF.Safe(UnitName(unit))
	if not name then return nil end
	local full = Comm.FullName(name, second)
	return normIndex[Comm.Norm(full)] or full, name
end

local function Locked()
	return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() or false
end

local function Send(msg, channel, target)
	if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) or Locked() then return false end
	return pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, channel, target)
end

local function Payload()
	local s = E.Summary(AF.db)
	return table.concat({ "S", PROTO, s.level, s.tier, s.push, s.legs, s.coreSec, s.cardioSec, s.seconds, s.days,
		AF.db.profileId, s.chars }, ":")
end

local function GroupChannel()
	if IsInRaid and IsInRaid() then return "RAID" end
	if IsInGroup and IsInGroup() then return "PARTY" end
end

function Comm.Broadcast(force)
	if not AF.db.settings.share then return end
	local now = Now()
	if not force and now - lastBroadcast < BROADCAST_EVERY then
		if not broadcastPending then
			broadcastPending = true
			C_Timer.After(BROADCAST_EVERY - (now - lastBroadcast) + 1, function()
				broadcastPending = false
				Comm.Broadcast()
			end)
		end
		return
	end
	lastBroadcast = now
	local msg = Payload()
	if IsInGuild and IsInGuild() then Send(msg, "GUILD") end
	local g = GroupChannel()
	if g then Send(msg, g) end
end

-- Ask guild and group for their stats (once at login, and from the Players tab).
function Comm.RequestAll(announce)
	local asked = false
	if IsInGuild and IsInGuild() then asked = Send("Q", "GUILD") or asked end
	local g = GroupChannel()
	if g then asked = Send("Q", g) or asked end
	if announce then
		AF.Print(asked and "Asked your guild and group for their stats." or "You're not in a guild or group right now.")
	end
end

local function Store(sender, parts)
	if parts[2] ~= PROTO then return end
	local n = function(i) return math.max(0, math.floor(tonumber(parts[i]) or 0)) end
	local peer = {
		level = math.min(E.MAX_LEVEL, math.max(1, n(3))),
		tier = n(4),
		push = n(5), legs = n(6), coreSec = n(7), cardioSec = n(8), seconds = n(9), days = n(10),
		chars = n(12),
		seen = time(),
	}
	local pid = parts[11]
	if type(pid) == "string" and pid:match("^%x+$") and #pid <= 16 then peer.pid = pid end
	-- Our own message echoed back (guild chat does that): learn how the game writes our
	-- name, and make sure we never list ourselves as another player.
	if peer.pid and peer.pid == AF.db.profileId then
		local ch = AF.Engine.CurrentChar(AF.db)
		if ch then ch.sender = sender end
		Comm.ForgetSelf()
		return
	end
	AF.db.peers[sender] = peer
	Index(sender)
	AF.Fire("PEERS_CHANGED", sender)
end

local function OnAddonMessage(prefix, text, channel, sender)
	if prefix ~= PREFIX then return end
	text, sender = AF.Safe(text), AF.Safe(sender)
	if type(text) ~= "string" or type(sender) ~= "string" then return end
	if text == "Q" then
		if IsMe(sender) then return end
		if not AF.db.settings.share then return end
		local now = Now()
		if channel == "WHISPER" then
			if now - (lastReply[sender] or 0) < REPLY_EVERY then return end
			lastReply[sender] = now
			Send(Payload(), "WHISPER", sender)
		else
			-- Someone asked the whole guild or group: answer there, with a little delay
			-- so a busy guild doesn't all answer at once.
			C_Timer.After(1 + math.random() * 5, function() Comm.Broadcast() end)
		end
		return
	end
	local parts = { strsplit(":", text) }
	if parts[1] == "S" then
		-- Old versions sent no account id, so check the name too.
		if not parts[11] and IsMe(sender) then return end
		Store(sender, parts)
		-- If their tooltip is open, refresh it with the new line.
		if GameTooltip and GameTooltip:IsShown() and Comm.Norm(Comm.hoverKey) == Comm.Norm(sender)
			and AF.Safe(UnitExists("mouseover")) then
			pcall(GameTooltip.SetUnit, GameTooltip, "mouseover")
		end
	end
end

function Comm.Lookup(key, short)
	local peers = AF.db.peers
	if key and peers[key] then return peers[key] end
	local n = Comm.Norm(key)
	if n and normIndex[n] and peers[normIndex[n]] then return peers[normIndex[n]] end
	if short and shortIndex[short] then return peers[shortIndex[short]] end
end

-- Remove any of my own characters from the list of other players.
function Comm.ForgetSelf()
	local peers = AF.db.peers
	local changed = false
	local myFirst = FirstName(Comm.MyKey())
	for name, peer in pairs(peers) do
		local legacySelf = not peer.pid and FirstName(name) == myFirst
		if IsMe(name) or (peer.pid and peer.pid == AF.db.profileId) or legacySelf then
			peers[name] = nil
			changed = true
		end
	end
	if changed then
		wipe(normIndex)
		wipe(shortIndex)
		for name in pairs(peers) do Index(name) end
		AF.Fire("PEERS_CHANGED")
	end
end

-- Ask a player we just moused over, if we have nothing fresh for them.
local function OnMouseover()
	if not AF.db.settings.tooltip or AF.InCombat() or Locked() then return end
	local unit = "mouseover"
	if not AF.Safe(UnitIsPlayer(unit)) or AF.Safe(UnitIsUnit(unit, "player")) then return end
	local mine, theirs = AF.Safe(UnitFactionGroup("player")), AF.Safe(UnitFactionGroup(unit))
	if not mine or mine ~= theirs then return end
	local key, short = UnitKey(unit)
	if not key then return end
	Comm.hoverKey = key
	local peer = Comm.Lookup(key, short)
	if peer and time() - (peer.seen or 0) < FRESH then return end
	local now = Now()
	if now - (lastAsk[key] or 0) < ASK_EVERY or now - lastAnyAsk < 2 then return end
	lastAsk[key] = now
	lastAnyAsk = now
	Send("Q", "WHISPER", key)
end

-- An addon whisper to someone who just logged off makes the game print
-- "No player named X is currently playing." Hide that line for players we just asked.
local function HideNotFound(_, _, msg)
	msg = AF.Safe(msg)
	if type(msg) ~= "string" or not ERR_CHAT_PLAYER_NOT_FOUND_S then return false end
	local pattern = "^" .. ERR_CHAT_PLAYER_NOT_FOUND_S:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
	local who = msg:match(pattern)
	if not who then return false end
	local now = Now()
	for name, at in pairs(lastAsk) do
		if now - at < 10 and Comm.Norm(name) == Comm.Norm(who) then return true end
	end
	return false
end

local function AddChatFilter()
	local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
	if add then pcall(add, "CHAT_MSG_SYSTEM", HideNotFound) end
end
Comm.HideNotFound = HideNotFound

local function AddTooltipLines(tt, unit)
	if not AF.db.settings.tooltip then return end
	if not unit or AF.IsSecret(unit) then return end
	if not AF.Safe(UnitIsPlayer(unit)) then return end
	local data
	if AF.Safe(UnitIsUnit(unit, "player")) then
		data = E.Summary(AF.db)
	else
		local key, short = UnitKey(unit)
		data = Comm.Lookup(key, short)
	end
	if not data then return end
	local c = C.gold
	tt:AddLine("Azeroth Fit: Fitness Lv " .. data.level .. "  " .. E.TitleFor(data.level), c[1], c[2], c[3])
	tt:AddLine(AF.FormatNumber(data.push) .. " push-ups   " .. AF.FormatNumber(data.legs) .. " squats   " ..
		AF.FormatDuration(data.seconds or 0) .. " active", 0.85, 0.85, 0.85)
	if (data.chars or 0) > 1 then
		tt:AddLine("Across " .. data.chars .. " characters", 0.6, 0.6, 0.6)
	end
end

local function HookTooltip()
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt)
			if tt ~= GameTooltip then return end
			local ok, _, unit = pcall(tt.GetUnit, tt)
			if ok then pcall(AddTooltipLines, tt, unit) end
		end)
	elseif GameTooltip then
		GameTooltip:HookScript("OnTooltipSetUnit", function(tt)
			local _, unit = tt:GetUnit()
			pcall(AddTooltipLines, tt, unit)
		end)
	end
end

-- Where /flex can go. "SELF" prints only in your own chat window.
AF.FlexTargets = {
	{ key = "SELF", label = "Just me", tip = "Shows your stats in your own chat window. Nobody else sees it." },
	{ key = "GUILD", label = "Guild" },
	{ key = "GROUP", label = "Party / Raid" },
	{ key = "SAY", label = "Say", tip = "Players standing near you." },
}

local FLEX_ALIASES = {
	SELF = "SELF", ME = "SELF", MINE = "SELF", LOCAL = "SELF",
	GUILD = "GUILD", G = "GUILD",
	GROUP = "GROUP", PARTY = "GROUP", P = "GROUP", RAID = "GROUP", RA = "GROUP",
	SAY = "SAY", S = "SAY",
}

function AF.FlexLabel(key)
	for _, t in ipairs(AF.FlexTargets) do
		if t.key == key then return t.label end
	end
	return key
end

-- /flex: show your numbers to yourself, or post them in chat.
function AF.Flex(where)
	local s = E.Summary(AF.db)
	local msg = string.format("[Azeroth Fit] Fitness level %d, %s. %s push-ups, %s squats, %s of planks, %s of cardio. %d days trained.",
		s.level, s.title, AF.FormatNumber(s.push), AF.FormatNumber(s.legs),
		AF.FormatDuration(s.coreSec), AF.FormatDuration(s.cardioSec), s.days)
	if s.chars > 1 then msg = msg .. " (across " .. s.chars .. " characters)" end
	local target = FLEX_ALIASES[(where or AF.db.settings.flexTo or "SELF"):upper()]
	if not target then
		AF.Print("Flex where? Use /flex me, /flex guild, /flex party or /flex say.")
		return
	end
	if target == "SELF" then
		AF.Print(AF.Colorize("Your stats (only you can see this):", C.dim))
		DEFAULT_CHAT_FRAME:AddMessage("   " .. msg:gsub("^%[Azeroth Fit%] ", ""))
		return
	end
	local channel = target
	if target == "GUILD" and not (IsInGuild and IsInGuild()) then
		AF.Print("You're not in a guild.")
		return
	end
	if target == "GROUP" then
		channel = GroupChannel()
		if not channel then
			AF.Print("You're not in a group.")
			return
		end
	end
	if Locked() then
		AF.Print("Chat is locked right now (boss fight or similar). Try again after.")
		return
	end
	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	local ok = pcall(send, msg, channel)
	if not ok then AF.Print(msg) end
end

function Comm.Init()
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
	end
	for name in pairs(AF.db.peers) do Index(name) end
	Comm.ForgetSelf()
	AF.On("CHAT_MSG_ADDON", OnAddonMessage)
	AF.On("UPDATE_MOUSEOVER_UNIT", OnMouseover)
	AF.On("GROUP_JOINED", function() C_Timer.After(3, function() Comm.Broadcast(); Comm.RequestAll() end) end)
	HookTooltip()
	AddChatFilter()
	AF.Listen("STATS_CHANGED", function() Comm.Broadcast() end)
	-- Say hello a little after login, once the guild roster is ready.
	C_Timer.After(12, function()
		Comm.Broadcast(true)
		Comm.RequestAll()
	end)
end
