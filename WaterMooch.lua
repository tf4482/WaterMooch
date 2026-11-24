-- WaterMooch: lists nearby mages on demand; a click targets, marks, and whispers one

local ADDON, ns = ...

-- raid target icon index of the blue square
local SQUARE = 6
-- most rows the window shows
local ROWS = 10
-- row height in pixels
local ROW_HEIGHT = 20
-- seconds a mage seen in passing still counts as nearby
local RECENT = 60
-- former default of the Alt+right click whisper, replaced on load
local OLD_ALT_MESSAGE = "Hi! Could you spare some food, please? Thank you!"

-- last time each mage was seen, by unit name
local seen = {}

-- label in Options > Keybindings > AddOns
_G["BINDING_NAME_WATERMOOCH_SCAN"] = "WaterMooch: Scan for mages"

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
    return ns.Error("no whisper text set - see " .. ns.slash .. " config")
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
window.TitleText:SetText("Mages nearby")

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
    seen[name] = GetTime()
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

-- one scan of nameplates, group, target, and mouseover; shows the result
local function Scan()
  if InCombatLockdown() then
    return ns.Error("scanning is not available right now")
  end
  for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
    See(plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit))
  end
  local group, size = "party", 4
  if IsInRaid() then
    group, size = "raid", 40
  end
  for index = 1, size do
    See(group .. index)
  end
  See("target")
  See("mouseover")
  -- everyone seen now or within the last RECENT seconds
  local names, now = {}, GetTime()
  for name, time in pairs(seen) do
    if now - time > RECENT then
      seen[name] = nil
    else
      names[#names + 1] = name
    end
  end
  table.sort(names)
  Render(names)
  if #names == 0 then
    ns.Warn("no mages found nearby")
    if not GetCVarBool("nameplateShowFriendlyPlayers") and not GetCVarBool("nameplateShowFriends") then
      ns.Detail("turn on friendly player nameplates (" .. ns.Color("command", "Shift+V")
        .. ") so mages around you are found")
    end
  else
    ns.Print(ns.Color("value", #names) .. " mage(s) found")
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
  ShowSet("whisper (right click)", "message")
  ShowSet("alt whisper (Alt+right click)", "altMessage")
  ns.Status("per character", ns.OnOff(ns.char.perCharacter))
  ns.Detail("scan with " .. ns.Color("command", ns.slash .. " scan") .. " or your key binding")
end

-- switch per-character settings and report the new state
local function PerCharacter(enabled)
  ns.Set("perCharacter", enabled)
  Status()
end

-- save a whisper text in the active profile; Settings.lua has no text control
local function SaveMessage(key, text)
  local profile = ns.char.perCharacter and ns.char or ns.db
  profile[key] = text
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
      SaveMessage(key, self:GetText())
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

-- add the scan key binding and both whisper fields below the addon's settings controls
local function AddSettingsFields()
  local title = C_AddOns.GetAddOnMetadata(ADDON, "Title") or ADDON
  for _, category in ipairs(SettingsPanel:GetAllCategories()) do
    if category:GetName() == title then
      local binding = C_KeyBindings.GetBindingIndex("WATERMOOCH_SCAN")
      if binding then
        Settings.RegisterInitializer(category, CreateKeybindingEntryInitializer(binding, true))
      end
      AddTextArea(category, "message", "Whisper (right click)",
        "One sentence per line, a random one is sent; saved when leaving the field.")
      AddTextArea(category, "altMessage", "Whisper (Alt+right click)",
        "One sentence per line, a random one is sent; saved when leaving the field.")
      Settings.SetOnValueChangedCallback(ADDON .. "_perCharacter", RefreshInputs)
      return
    end
  end
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
  message = "Hi! Could you spare some water, please? Thank you!",
  altMessage = "Thank you so much for the water, have a great day!",
}, function(db)
  -- replace the former default, keep texts the player wrote
  for _, profile in ipairs({ db, ns.char }) do
    if profile.altMessage == OLD_ALT_MESSAGE then
      profile.altMessage = ns.defaults.db.altMessage
    end
  end
  ns.Settings()
  AddSettingsFields()
end)

-- chat commands
ns.Command({ name = "scan", help = "list the mages nearby", run = Scan })
-- chat command that replaces a whisper set or adds a sentence to it
local function MessageCommand(name, key, label, help)
  ns.Command({
    name = name,
    help = help,
    args = { { name = "text" } },
    options = { { name = "add", help = "add the sentence as one more random choice" } },
    run = function(args, options)
      local text = args.text
      if options.add and #Lines(key) > 0 then
        text = ns.Get(key) .. "\n" .. text
      end
      SaveMessage(key, text)
      ShowSet(label, key)
    end,
  })
end

MessageCommand("message", "message", "whisper (right click)",
  "set the right click whisper (use quotes)")
MessageCommand("altmessage", "altMessage", "alt whisper (Alt+right click)",
  "set the Alt+right click whisper (use quotes)")
ns.Command({
  name = "character",
  help = "use settings for this character only, or the account's",
  args = { { name = "state", choices = { "on", "off" } } },
  run = function(args) PerCharacter(args.state == "on") end,
})
ns.Command({ name = "config", help = "open the settings page", run = ns.OpenSettings })
ns.Slash({ "/wm", "/watermooch" }, Status)
