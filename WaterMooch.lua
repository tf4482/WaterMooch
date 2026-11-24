-- WaterMooch: lists nearby mages on demand; a click targets, marks, and whispers one

local ADDON, ns = ...
-- texts in the client language
local L = ns.L

-- raid target icon index of the blue square
local SQUARE = 6
-- most rows the window shows
local ROWS = 10
-- row height in pixels
local ROW_HEIGHT = 20
-- seconds a mage seen in passing still counts as nearby
local RECENT = 60
-- nameplate time slider positions: 0.01 to 0.09, then 0.1 to 3.0
local TIME_STEPS = 39
-- former default of the Alt+right click whisper, replaced on load
local OLD_ALT_MESSAGE = "Hi! Could you spare some food, please? Thank you!"

-- seconds for a nameplate time slider position
local function StepTime(step)
  if step < 10 then
    return step / 100
  end
  return (step - 9) / 10
end

-- nearest nameplate time slider position for seconds
local function TimeStep(seconds)
  if seconds < 0.095 then
    return math.max(1, math.floor(seconds * 100 + 0.5))
  end
  return math.min(TIME_STEPS, math.floor(seconds * 10 + 0.5) + 9)
end

-- seconds with two decimals below 0.1, otherwise one
local function FormatTime(seconds)
  return format(seconds < 0.095 and "%.2f" or "%.1f", seconds)
end

-- last sighting of each mage by unit name: { time, level }
local seen = {}

-- label in Options > Keybindings > AddOns
_G["BINDING_NAME_WATERMOOCH_SCAN"] = L.BINDING

-- non-empty, trimmed lines of a saved whisper set: one alternative per line
local function Lines(key)
  local lines = {}
  for line in ns.Get(key):gmatch("[^\n]+") do
    line = strtrim(line)
    if line ~= "" then
      lines[#lines + 1] = line
    end
  end
  return lines
end

-- send a random sentence of the whisper set saved under key to a player
local function Whisper(name, key)
  local lines = Lines(key)
  if #lines == 0 then
    return ns.Error(format(L.NO_TEXT, ns.slash .. " config"))
  end
  local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
  send(lines[math.random(#lines)], "WHISPER", nil, name)
end

-- list window, movable; position kept by the game's layout cache
local window = CreateFrame("Frame", "WaterMoochFrame", UIParent, "BasicFrameTemplateWithInset")
window:SetSize(200, 60)
window:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
window:SetClampedToScreen(true)
window:SetMovable(true)
window:EnableMouse(true)
window:RegisterForDrag("LeftButton")
window:SetScript("OnDragStart", window.StartMoving)
window:SetScript("OnDragStop", window.StopMovingOrSizing)
window:Hide()
window.TitleText:SetText(L.WINDOW_TITLE)

-- secure row buttons: left click targets and marks, right click whispers
local rows = {}
for index = 1, ROWS do
  local row = CreateFrame("Button", nil, window, "SecureActionButtonTemplate")
  row:SetHeight(ROW_HEIGHT)
  row:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -28 - (index - 1) * ROW_HEIGHT)
  row:SetPoint("TOPRIGHT", window, "TOPRIGHT", -12, -28 - (index - 1) * ROW_HEIGHT)
  -- both phases so the click works with either ActionButtonUseKeyDown setting
  row:RegisterForClicks("AnyUp", "AnyDown")
  -- only the left button runs the target macro
  row:SetAttribute("type1", "macro")
  row:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight", "ADD")
  local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("LEFT", row, "LEFT", 4, 0)
  row:SetFontString(label)
  -- once per right click: whisper (Alt+right click: second text)
  row:SetScript("PostClick", function(self, button, down)
    if button == "RightButton" and down == GetCVarBool("ActionButtonUseKeyDown") and self.name
      and not InCombatLockdown() then
      Whisper(self.name, IsAltKeyDown() and "altMessage" or "message")
    end
  end)
  row:Hide()
  rows[index] = row
end

-- remember a unit if it is a visible, friendly mage other than the player
local function See(unit)
  if not unit or InCombatLockdown() or not UnitExists(unit) or not UnitIsPlayer(unit)
    or UnitIsUnit(unit, "player") or not UnitIsVisible(unit) or not UnitIsFriend("player", unit) then
    return
  end
  local _, class = UnitClass(unit)
  local name = GetUnitName(unit, true)
  if class == "MAGE" and name then
    -- -1 means far above the player's level
    local level = UnitLevel(unit)
    seen[name] = { time = GetTime(), level = level < 0 and math.huge or level }
  end
end

-- fill the rows with the names and show the window, or hide it when empty
local function Render(names)
  local color = RAID_CLASS_COLORS.MAGE
  for index, row in ipairs(rows) do
    local name = names[index]
    row.name = name
    if name then
      -- SetRaidTarget is protected: mark in the secure macro, never toggle an existing
      -- square, and stop when the mage could not be targeted
      row:SetAttribute("macrotext", "/cleartarget\n/targetexact " .. name
        .. "\n/stopmacro [noexists]\n/tm !" .. SQUARE)
      row:SetText(color:WrapTextInColorCode(name))
      row:Show()
    else
      row:Hide()
    end
  end
  local shown = math.min(#names, ROWS)
  window:SetHeight(40 + shown * ROW_HEIGHT)
  window:SetShown(shown > 0)
end

-- nameplate settings switched on for a scan, with the player's values to restore
local switched = {}
-- a scan is waiting for nameplates to appear
local scanning = false

-- show friendly player nameplates for a moment; true when anything had to change
local function ShowPlates()
  -- 12.x name first, older clients second; nameplateShowAll shows plates out of combat
  local friendly = C_CVar.GetCVar("nameplateShowFriendlyPlayers") and "nameplateShowFriendlyPlayers"
    or "nameplateShowFriends"
  for _, cvar in ipairs({ "nameplateShowAll", friendly }) do
    local value = C_CVar.GetCVar(cvar)
    if value and value ~= "1" then
      switched[cvar] = value
      C_CVar.SetCVar(cvar, "1")
    end
  end
  return next(switched) ~= nil
end

-- put the player's nameplate settings back; only out of combat
local function RestorePlates()
  for cvar, value in pairs(switched) do
    C_CVar.SetCVar(cvar, value)
    switched[cvar] = nil
  end
end

-- read nameplates, group, target, and mouseover; show the result
local function Collect()
  scanning = false
  if InCombatLockdown() then
    return ns.AfterCombat(RestorePlates)
  end
  for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
    See(plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit))
  end
  RestorePlates()
  local group, size = "party", 4
  if IsInRaid() then
    group, size = "raid", 40
  end
  for index = 1, size do
    See(group .. index)
  end
  See("target")
  See("mouseover")
  -- everyone seen now or within the last RECENT seconds, from the minimum level up
  local names, now = {}, GetTime()
  for name, sighting in pairs(seen) do
    if now - sighting.time > RECENT then
      seen[name] = nil
    elseif sighting.level >= ns.Get("minLevel") then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  Render(names)
  if #names == 0 then
    ns.Warn(L.NONE_FOUND)
  else
    ns.Print(format(L.FOUND, ns.Color("value", #names)))
  end
end

-- one scan; switches friendly nameplates on briefly when they are off
local function Scan()
  if InCombatLockdown() then
    return ns.Error(L.NOT_NOW)
  elseif scanning then
    return
  end
  if ShowPlates() then
    -- nameplates appear over the next frames
    scanning = true
    C_Timer.After(ns.Get("plateTime"), Collect)
  else
    Collect()
  end
end

-- one whisper set as a numbered list
local function ShowSet(label, key)
  ns.Print(label .. ":")
  for index, line in ipairs(Lines(key)) do
    ns.Detail(ns.Color("muted", index .. ".") .. " " .. ns.Color("value", line))
  end
end

-- current state
local function Status()
  ShowSet(L.WHISPER, "message")
  ShowSet(L.ALT_WHISPER, "altMessage")
  ns.Status(L.PLATE_TIME, FormatTime(ns.Get("plateTime")) .. " s")
  ns.Status(L.MIN_LEVEL, ns.Get("minLevel"))
  ns.Status(L.PER_CHARACTER, ns.OnOff(ns.char.perCharacter))
  ns.Detail(format(L.SCAN_HINT, ns.Color("command", ns.slash .. " scan")))
end

-- switch per-character settings and report the new state
local function PerCharacter(enabled)
  ns.Set("perCharacter", enabled)
  Status()
end

-- save a setting in the active profile, for controls Settings.lua does not offer
local function SaveValue(key, value)
  local profile = ns.char.perCharacter and ns.char or ns.db
  profile[key] = value
end

-- text fields shown on the settings page, by setting key
local inputs = {}

-- show the texts of the active profile in the visible fields
local function RefreshInputs()
  for key, input in pairs(inputs) do
    if input:IsVisible() then
      input:SetText(ns.Get(key))
      input:SetCursorPosition(0)
    end
  end
end

-- multi-line field on the addon's settings page for the whisper set saved under key
local function AddTextArea(category, key, label, hint)
  local initializer = Settings.CreateElementInitializer("WaterMoochTextAreaTemplate", { name = label })
  -- fill a list frame from the template whenever the page shows it
  initializer.InitFrame = function(_, frame)
    frame.Label:SetText(label)
    frame.Hint:SetText(hint)
    local input = frame.Input.EditBox
    input:SetFontObject("ChatFontNormal")
    input:SetText(ns.Get(key))
    input:SetCursorPosition(0)
    -- save the typed lines
    input:SetScript("OnEditFocusLost", function(self)
      SaveValue(key, self:GetText())
    end)
    -- discard the typing and show the saved lines again
    input:SetScript("OnEscapePressed", function(self)
      self:SetText(ns.Get(key))
      self:ClearFocus()
    end)
    inputs[key] = input
  end
  Settings.RegisterInitializer(category, initializer)
end

-- the addon's settings category created by ns.Settings
local function FindCategory()
  local title = C_AddOns.GetAddOnMetadata(ADDON, "Title") or ADDON
  for _, category in ipairs(SettingsPanel:GetAllCategories()) do
    if category:GetName() == title then
      return category
    end
  end
end

-- nameplate time element currently shown on the settings page
local timeFrame

-- show the saved nameplate time in the visible element
local function ShowTime()
  if timeFrame and timeFrame:IsVisible() then
    local seconds = ns.Get("plateTime")
    timeFrame.Slider:SetValue(TimeStep(seconds))
    timeFrame.Input:SetText(FormatTime(seconds))
  end
end

-- save a nameplate time, snapped to the slider steps
local function SetTime(seconds)
  SaveValue("plateTime", StepTime(TimeStep(seconds)))
  ShowTime()
end

-- nameplate time slider with 0.01 steps below 0.1 and a number field to its right;
-- ns.Slider has neither uneven steps nor a number field
local function AddTimeSlider(category)
  local initializer = Settings.CreateElementInitializer("WaterMoochTimeTemplate", { name = L.PLATE_TIME_LABEL })
  -- fill a list frame from the template whenever the page shows it
  initializer.InitFrame = function(_, frame)
    timeFrame = frame
    frame.Label:SetText(L.PLATE_TIME_LABEL)
    frame.Slider:Init(TimeStep(ns.Get("plateTime")), 1, TIME_STEPS, TIME_STEPS - 1)
    -- slider moved: save and show the new time
    frame.Slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, step)
      local seconds = StepTime(math.floor(step + 0.5))
      SaveValue("plateTime", seconds)
      frame.Input:SetText(FormatTime(seconds))
    end, frame)
    local input = frame.Input
    input:SetText(FormatTime(ns.Get("plateTime")))
    input:SetScript("OnEnterPressed", input.ClearFocus)
    -- typed time: save it within 0.01 to 3, or show the saved one again
    input:SetScript("OnEditFocusLost", function(self)
      local seconds = tonumber((self:GetText():gsub(",", ".")))
      if seconds then
        SetTime(math.min(math.max(seconds, 0.01), 3))
      else
        ShowTime()
      end
    end)
    -- discard the typing
    input:SetScript("OnEscapePressed", function(self)
      self:SetText(FormatTime(ns.Get("plateTime")))
      self:ClearFocus()
    end)
  end
  Settings.RegisterInitializer(category, initializer)
  Settings.SetOnValueChangedCallback(ADDON .. "_perCharacter", ShowTime)
end

-- add the scan key binding and both whisper fields below the addon's settings controls
local function AddSettingsFields(category)
  local binding = C_KeyBindings.GetBindingIndex("WATERMOOCH_SCAN")
  if binding then
    Settings.RegisterInitializer(category, CreateKeybindingEntryInitializer(binding, true))
  end
  AddTextArea(category, "message", L.WHISPER_LABEL, L.TEXT_HINT)
  AddTextArea(category, "altMessage", L.ALT_WHISPER_LABEL, L.TEXT_HINT)
  Settings.SetOnValueChangedCallback(ADDON .. "_perCharacter", RefreshInputs)
end

-- event handlers by event name
local events = {}

-- mages seen in passing count for the next scan
function events.NAME_PLATE_UNIT_ADDED(unit)
  See(unit)
end

-- mouse over a unit: remember it if it is a mage
function events.UPDATE_MOUSEOVER_UNIT()
  See("mouseover")
end

-- new target: remember it if it is a mage
function events.PLAYER_TARGET_CHANGED()
  See("target")
end

-- logout or reload during a scan: keep the player's nameplate settings
function events.PLAYER_LOGOUT()
  RestorePlates()
end

-- secure rows cannot be hidden later: close the window now
function events.PLAYER_REGEN_DISABLED()
  window:Hide()
end

-- one frame dispatching all events above
local frame = CreateFrame("Frame")
for event in pairs(events) do
  frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, ...)
  events[event](...)
end)

-- saved state; settings page once loaded
ns.Store("WaterMoochDB", {
  message = L.DEFAULT_MESSAGE,
  altMessage = L.DEFAULT_ALT_MESSAGE,
  plateTime = 0.5,
  minLevel = 1,
}, function(db)
  -- replace the former default, keep texts the player wrote
  for _, profile in ipairs({ db, ns.char }) do
    if profile.altMessage == OLD_ALT_MESSAGE then
      profile.altMessage = ns.defaults.db.altMessage
    end
  end
  ns.Settings()
  local category = FindCategory()
  AddTimeSlider(category)
  local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 80
  ns.Slider("minLevel", L.MIN_LEVEL_LABEL, 1, math.max(maxLevel, 1), 1, L.MIN_LEVEL_TOOLTIP)
  AddSettingsFields(category)
end)

-- chat commands
ns.Command({ name = "scan", help = L.HELP_SCAN, run = Scan })
ns.Command({
  name = "time",
  help = L.HELP_TIME,
  args = { { name = "seconds", type = "number", min = 0.01, max = 3 } },
  run = function(args)
    SetTime(args.seconds)
    ns.Status(L.PLATE_TIME, FormatTime(ns.Get("plateTime")) .. " s")
  end,
})
ns.Command({
  name = "minlevel",
  help = L.HELP_MINLEVEL,
  args = { { name = "level", type = "number", min = 1 } },
  run = function(args)
    ns.Set("minLevel", math.floor(args.level))
    ns.Status(L.MIN_LEVEL, math.floor(args.level))
  end,
})
-- chat command that replaces a whisper set or adds a sentence to it
local function MessageCommand(name, key, label, help)
  ns.Command({
    name = name,
    help = help,
    args = { { name = "text" } },
    options = { { name = "add", help = L.HELP_ADD } },
    run = function(args, options)
      local text = args.text
      if options.add and #Lines(key) > 0 then
        text = ns.Get(key) .. "\n" .. text
      end
      SaveValue(key, text)
      ShowSet(label, key)
    end,
  })
end

MessageCommand("message", "message", L.WHISPER, L.HELP_MESSAGE)
MessageCommand("altmessage", "altMessage", L.ALT_WHISPER, L.HELP_ALTMESSAGE)
ns.Command({
  name = "character",
  help = L.HELP_CHARACTER,
  args = { { name = "state", choices = { "on", "off" } } },
  run = function(args) PerCharacter(args.state == "on") end,
})
ns.Command({ name = "config", help = L.HELP_CONFIG, run = ns.OpenSettings })
ns.Slash({ "/wm", "/watermooch" }, Status)
