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

-- last sighting of each mage by unit name: { time, level, guild }
local seen = {}

-- label in the addon's own section of Options > Keybindings
BINDING_NAME_WATERMOOCH_SCAN = L["Scan for mages"]

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
    return ns.Error(format(L["no whisper text set - see %s"], ns.slash .. " config"))
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
window.TitleText:SetText(L["Dispenser nearby"])

-- secure row buttons: left click targets and marks, right click whispers
local rows = {}
for index = 1, ROWS do
  local row = CreateFrame("Button", nil, window, "SecureActionButtonTemplate")
  row:SetHeight(ROW_HEIGHT)
  row:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -28 - (index - 1) * ROW_HEIGHT)
  row:SetPoint("TOPRIGHT", window, "TOPRIGHT", -12, -28 - (index - 1) * ROW_HEIGHT)
  -- both phases so the click works with either ActionButtonUseKeyDown setting
  row:RegisterForClicks("AnyUp", "AnyDown")
  -- only the left button runs a macro, with or without modifier keys
  row:SetAttribute("*type1", "macro")
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
    seen[name] = { time = GetTime(), level = level < 0 and math.huge or level, guild = GetGuildInfo(unit) }
    ns.Debug("seen " .. name .. " (" .. unit .. ")")
  end
end

-- fill the rows with the names and show the window, or hide it when empty
local function Render(names)
  local color = RAID_CLASS_COLORS.MAGE
  -- centered title clear of the close button on both sides
  local width = window.TitleText:GetStringWidth() + 64
  for index, row in ipairs(rows) do
    local name = names[index]
    row.name = name
    if name then
      -- SetRaidTarget is protected: mark in the secure macro, never toggle an existing
      -- square, and stop when the mage could not be targeted
      row:SetAttribute("macrotext", "/cleartarget\n/targetexact " .. name
        .. "\n/stopmacro [noexists]\n/tm !" .. SQUARE)
      -- Alt+left click: target the same way, then open a trade
      row:SetAttribute("alt-macrotext1", "/cleartarget\n/targetexact " .. name
        .. "\n/stopmacro [noexists]\n/trade")
      -- name, level ("??" far above the player), and <guild> when there is one
      local sighting = seen[name]
      local level = sighting.level == math.huge and "??" or sighting.level
      local guild = sighting.guild and " " .. ns.Color("success", "<" .. sighting.guild .. ">") or ""
      row:SetText(color:WrapTextInColorCode(name) .. " " .. ns.Color("value", level) .. guild)
      row:Show()
      -- row insets and label padding around the name
      width = math.max(width, row:GetFontString():GetStringWidth() + 40)
    else
      row:Hide()
    end
  end
  local shown = math.min(#names, ROWS)
  window:SetSize(math.ceil(width), 40 + shown * ROW_HEIGHT)
  window:SetShown(shown > 0)
end

-- nameplate settings switched on for a scan, with the player's values to restore;
-- saved per character so a disconnect or crash still restores them on the next login
ns.Store("WaterMoochCharDB", { switched = {} }, nil, "char")
-- a scan is waiting for nameplates to appear
local scanning = false

-- show friendly player nameplates for a moment; true when anything had to change
local function ShowPlates()
  -- 12.x name first, older clients second; nameplateShowAll shows plates out of combat
  local friendly = C_CVar.GetCVar("nameplateShowFriendlyPlayers") and "nameplateShowFriendlyPlayers"
    or "nameplateShowFriends"
  local switched = ns.char.switched
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
  local switched = ns.char.switched
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
    ns.Warn(L["no mages found nearby"])
  else
    ns.Print(format(L["%s mage(s) found"], ns.Color("value", #names)))
  end
end

-- one scan; switches friendly nameplates on briefly when they are off
local function Scan()
  if InCombatLockdown() then
    return ns.Error(L["scanning is not available right now"])
  elseif scanning then
    return
  end
  if ShowPlates() then
    -- nameplates appear over the next frames
    ns.Debug("nameplates switched on for " .. ns.Get("plateTime") .. " s")
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
  ShowSet(L["whisper (right click)"], "message")
  ShowSet(L["alt whisper (Alt+right click)"], "altMessage")
  ns.Status(L["nameplate time"], FormatTime(ns.Get("plateTime")) .. " s")
  ns.Status(L["minimum level"], ns.Get("minLevel"))
  ns.Status(L["per character"], ns.OnOff(ns.char.perCharacter))
  ns.Detail(format(L["scan with %s or your key binding"], ns.Color("command", ns.slash .. " scan")))
end

-- switch per-character settings and report the new state
local function PerCharacter(enabled)
  ns.Set("perCharacter", enabled)
  Status()
end

-- settings with an own page element; registered so ns.Set, reset, and the page reach them
local OWN_SETTINGS = { "plateTime", "message", "altMessage" }

-- register a proxy setting for a key of the active profile; onChange runs after each change
local function Register(key, label, onChange)
  local default = ns.defaults.db[key]
  local setting = Settings.RegisterProxySetting(ns.Category, ADDON .. "_" .. key, type(default),
    label, default,
    function() return ns.Get(key) end,
    function(value) (ns.char.perCharacter and ns.char or ns.db)[key] = value end)
  setting:SetValueChangedCallback(onChange)
end

-- text fields shown on the settings page, by setting key
local inputs = {}

-- show the texts of the active profile in the visible fields
local function RefreshInputs()
  for key, input in pairs(inputs) do
    if input:IsVisible() and not input:HasFocus() then
      input:SetText(ns.Get(key))
      input:SetCursorPosition(0)
    end
  end
end

-- multi-line field on the addon's settings page for the whisper set saved under key
local function AddTextArea(key, label, hint)
  Register(key, label, RefreshInputs)
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
      ns.Set(key, self:GetText())
    end)
    -- discard the typing and show the saved lines again
    input:SetScript("OnEscapePressed", function(self)
      self:SetText(ns.Get(key))
      self:ClearFocus()
    end)
    inputs[key] = input
  end
  Settings.RegisterInitializer(ns.Category, initializer)
end

-- nameplate time element currently shown on the settings page
local timeFrame
-- guard against slider callbacks caused by ShowTime itself
local showing = false

-- show the saved nameplate time in the visible element
local function ShowTime()
  if timeFrame and timeFrame:IsVisible() then
    local seconds = ns.Get("plateTime")
    showing = true
    timeFrame.Slider:SetValue(TimeStep(seconds))
    showing = false
    timeFrame.Input:SetText(FormatTime(seconds))
  end
end

-- save a nameplate time, snapped to the slider steps
local function SetTime(seconds)
  ns.Set("plateTime", StepTime(TimeStep(seconds)))
end

-- nameplate time slider with 0.01 steps below 0.1 and a number field to its right;
-- ns.Slider has neither uneven steps nor a number field
local function AddTimeSlider()
  Register("plateTime", L["Nameplate time"], ShowTime)
  local initializer = Settings.CreateElementInitializer("WaterMoochTimeTemplate", { name = L["Nameplate time"] })
  -- fill a list frame from the template whenever the page shows it
  initializer.InitFrame = function(_, frame)
    timeFrame = frame
    frame.Label:SetText(L["Nameplate time"])
    frame.Slider:Init(TimeStep(ns.Get("plateTime")), 1, TIME_STEPS, TIME_STEPS - 1)
    -- slider moved by the player: save and show the new time
    frame.Slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, step)
      if not showing then
        ns.Set("plateTime", StepTime(math.floor(step + 0.5)))
      end
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
  Settings.RegisterInitializer(ns.Category, initializer)
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

-- nameplate settings still switched from a lost session: restore them out of combat
function events.PLAYER_LOGIN()
  if next(ns.char.switched) then
    ns.Debug("restoring nameplate settings from the last session")
    ns.AfterCombat(RestorePlates)
  end
end

-- logout or reload during a scan: keep the player's nameplate settings; in combat they
-- stay saved for the next login
function events.PLAYER_LOGOUT()
  ns.AfterCombat(RestorePlates)
end

-- secure rows cannot be hidden later: close the window now
function events.PLAYER_REGEN_DISABLED()
  window:Hide()
end

-- one frame dispatching all events above
local frame = CreateFrame("Frame")
for event in pairs(events) do
  -- skip events this client does not know
  if C_EventUtils.IsEventValid(event) then frame:RegisterEvent(event) end
end
frame:SetScript("OnEvent", function(_, event, ...)
  events[event](...)
end)

-- saved state; settings page once loaded
ns.Store("WaterMoochDB", {
  message = L["Hi! Could you spare some water, please? Thank you!"],
  altMessage = L["Thank you so much for the water, have a great day!"],
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
  AddTimeSlider()
  local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 80
  ns.Slider("minLevel", L["Minimum level"], 1, math.max(maxLevel, 1), 1, L["Only list mages of this level or higher"])
  ns.Keybinding("WATERMOOCH_SCAN", L["Scan for mages"])
  local hint = L["One sentence per line, a random one is sent; saved when leaving the field."]
  AddTextArea("message", L["Whisper (right click)"], hint)
  AddTextArea("altMessage", L["Whisper (Alt+right click)"], hint)
  -- own elements show the values of the new profile after a switch
  Settings.SetOnValueChangedCallback(ADDON .. "_perCharacter", function()
    ShowTime()
    RefreshInputs()
  end)
end)

-- chat commands
ns.Command({ name = "scan", help = L["list the mages nearby"], run = Scan })
ns.Command({
  name = "time",
  help = L["seconds a scan shows friendly nameplates"],
  args = { { name = "seconds", type = "number", min = 0.01, max = 3 } },
  run = function(args)
    SetTime(args.seconds)
    ns.Status(L["nameplate time"], FormatTime(ns.Get("plateTime")) .. " s")
  end,
})
ns.Command({
  name = "minlevel",
  help = L["only list mages of this level or higher"],
  args = { { name = "level", type = "number", min = 1 } },
  run = function(args)
    ns.Set("minLevel", math.floor(args.level))
    ns.Status(L["minimum level"], math.floor(args.level))
  end,
})
-- chat command that replaces a whisper set or adds a sentence to it
local function MessageCommand(name, key, label, help)
  ns.Command({
    name = name,
    help = help,
    args = { { name = "text" } },
    options = { { name = "add", help = L["add the sentence as one more random choice"] } },
    run = function(args, options)
      local text = args.text
      if options.add and #Lines(key) > 0 then
        text = ns.Get(key) .. "\n" .. text
      end
      ns.Set(key, text)
      ShowSet(label, key)
    end,
  })
end

MessageCommand("message", "message", L["whisper (right click)"], L["set the right click whisper (use quotes)"])
MessageCommand("altmessage", "altMessage", L["alt whisper (Alt+right click)"],
  L["set the Alt+right click whisper (use quotes)"])
ns.Command({
  name = "character",
  help = L["use settings for this character only, or the account's"],
  args = { { name = "state", choices = { "on", "off" } } },
  run = function(args) PerCharacter(args.state == "on") end,
})
ns.Command({
  name = "reset",
  help = L["reset the active profile's settings to defaults"],
  run = function()
    ns.ResetSettings()
    for _, key in ipairs(OWN_SETTINGS) do
      ns.Set(key, ns.defaults.db[key])
    end
    ns.Success(L["settings reset to defaults"])
    Status()
  end,
})
ns.Command({
  name = "debug",
  help = L["show what the addon does in chat, until /reload"],
  args = { { name = "state", choices = { "on", "off" } } },
  run = function(args)
    ns.debug = args.state == "on"
    ns.Status("debug", ns.OnOff(ns.debug))
  end,
})
ns.Command({ name = "config", help = L["open the settings page"], run = ns.OpenSettings })
ns.Slash({ "/wmooch", "/watermooch" }, Status)
