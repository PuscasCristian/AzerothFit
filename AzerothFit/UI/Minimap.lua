-- Minimap button: left-click opens the window, right-click starts a workout, drag to move.
local _, AF = ...
local UI = AF.UI
local C = UI.C

local btn

local function Place()
	local angle = math.rad(AF.db.settings.minimap.angle or 215)
	local r = (Minimap:GetWidth() / 2) + 6
	btn:ClearAllPoints()
	btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function OnDragUpdate()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	cx, cy = cx / scale, cy / scale
	AF.db.settings.minimap.angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
	Place()
end

local function Build()
	if not Minimap then return end
	btn = CreateFrame("Button", "AzerothFitMinimapButton", Minimap)
	btn:SetSize(31, 31)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel(8)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:RegisterForDrag("LeftButton")
	btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local icon = btn:CreateTexture(nil, "BACKGROUND")
	icon:SetTexture("Interface\\Icons\\Ability_Warrior_Revenge")
	icon:SetSize(20, 20)
	icon:SetPoint("TOPLEFT", 7, -5)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	btn:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			GameTooltip:Hide()
			local db = AF.db
			local paused = AF.Engine.Paused(db, AF.DayNumber())
			UI.ChoiceMenu(self, {
				{ key = "now", label = "Workout now" },
				{ key = "stretch", label = "Stretch break" },
				{ key = "pause", label = paused and "Resume today" or "Pause for today",
					tip = "No popups or reminders until tomorrow. Raid night, friends over, or just a rest day." },
				{ key = "quiet", label = db.settings.quiet and "Quiet mode: on" or "Quiet mode: off",
					tip = "No jumping: jumping jacks and burpees become on-the-spot moves." },
				{ key = "open", label = "Open Azeroth Fit" },
			}, function(key)
				if key == "now" then AF.WorkoutNow()
				elseif key == "stretch" then AF.StretchBreak(2)
				elseif key == "pause" then AF.SetPaused(not paused)
				elseif key == "quiet" then AF.SetQuiet(not db.settings.quiet)
				else AF.MainWindow.Show() end
			end)
		else
			AF.MainWindow.Toggle()
		end
	end)
	btn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
	btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	btn:SetScript("OnEnter", function(self)
		local db = AF.db
		local E = AF.Engine
		E.Rollover(db, AF.DayNumber())
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Azeroth Fit", C.gold[1], C.gold[2], C.gold[3])
		GameTooltip:AddLine("Fitness level " .. db.stats.level .. "  " .. E.TitleFor(db.stats.level), 1, 1, 1)
		GameTooltip:AddLine("Today: " .. db.today.sets .. " of " .. E.CapSets(db) .. " sets", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("This week: " .. E.WeekCount(db) .. " of " .. E.WeekGoal(db) .. " training days", 0.8, 0.8, 0.8)
		local wait = math.max(db.settings.gap * 60 - (time() - (db.lastPrompt or 0)), E.BreakLeft(db, time()))
		if E.Paused(db, AF.DayNumber()) then
			GameTooltip:AddLine("Paused for today", 1, 0.6, 0.3)
		elseif E.CapReached(db) then
			GameTooltip:AddLine("Daily training done. Rest is part of it.", 0.4, 0.85, 0.42)
		elseif wait > 0 then
			GameTooltip:AddLine("Next quest snack in " .. AF.FormatDuration(wait), 0.8, 0.8, 0.8)
		else
			GameTooltip:AddLine("Ready: your next quest turn-in brings a snack", 0.8, 0.8, 0.8)
		end
		GameTooltip:AddLine(" ")
		if db.settings.quiet then GameTooltip:AddLine("Quiet mode on", 0.6, 0.6, 0.6) end
		GameTooltip:AddLine("Left-click: open   Right-click: menu   Drag: move", 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function AF.UpdateMinimap()
	if not btn then Build() end
	if not btn then return end
	if AF.db.settings.minimap.hide then
		btn:Hide()
	else
		Place()
		btn:Show()
	end
end

AF.Listen("SETTINGS_CHANGED", function() AF.UpdateMinimap() end)
