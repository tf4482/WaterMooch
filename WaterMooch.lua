-- WaterMooch: lists nearby mages on demand; a click targets, marks, and whispers one

local ADDON, ns = ...

-- raid target icon index of the blue square
local SQUARE = 6
-- most rows the window shows
local ROWS = 10
-- row height in pixels
local ROW_HEIGHT = 20

-- label in Options > Keybindings > AddOns
_G["BINDING_NAME_WATERMOOCH_SCAN"] = "WaterMooch: Scan for mages"

-- send the whisper text saved under key to a player
local function Whisper(name, key)
  local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
  send(ns.Get(key), "WHISPER", nil, name)
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
  -- once per click: blue square after the left-click target, whisper on right click
  -- (Alt+right click: second text)
  row:SetScript("PostClick", function(self, button, down)
    if down ~= GetCVarBool("ActionButtonUseKeyDown") or not self.name or InCombatLockdown() then
      return
    end
    if button == "RightButton" then
      Whisper(self.name, IsAltKeyDown() and "altMessage" or "message")
    elseif button == "LeftButton" and GetUnitName("target", true) == self.name
      and GetRaidTargetIndex("target") ~= SQUARE then
      SetRaidTarget("target", SQUARE)
    end
  end)
  row:Hide()
  rows[index] = row
end

-- add a unit's name if it is a visible, friendly mage other than the player
local function See(unit, found)
  if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player")
    or not UnitIsVisible(unit) or not UnitIsFriend("player", unit) then
    return
  end
  local _, class = UnitClass(unit)
  local name = GetUnitName(unit, true)
  if class == "MAGE" and name then
    found[name] = true
  end
end

-- fill the rows with the names and show the window, or hide it when empty
local function Render(names)
  local color = RAID_CLASS_COLORS.MAGE
  for index, row in ipairs(rows) do
    local name = names[index]
    row.name = name
    if name then
      row:SetAttribute("macrotext", "/targetexact " .. name)
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
  local found = {}
  for index = 1, 40 do
    See("nameplate" .. index, found)
  end
  local group, size = "party", 4
  if IsInRaid() then
    group, size = "raid", 40
  end
  for index = 1, size do
    See(group .. index, found)
  end
  See("target", found)
  See("mouseover", found)
  local names = {}
  for name in pairs(found) do
    names[#names + 1] = name
  end
  table.sort(names)
  Render(names)
  if #names == 0 then
    ns.Warn("no mages found nearby")
  else
    ns.Print(ns.Color("value", #names) .. " mage(s) found")
  end
end

-- current state
local function Status()
  ns.Status("whisper", ns.Get("message"))
  ns.Status("alt whisper", ns.Get("altMessage"))
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

-- whisper page in Options > AddOns > WaterMooch, with one text field per whisper
local panel = CreateFrame("Frame")
local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
heading:SetText("Whisper")
-- text fields by setting key, refreshed when the page opens
local inputs = {}

-- labeled text field below anchor for the whisper saved under key; returns the field
local function TextField(anchor, key, text)
  local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", anchor == heading and 0 or -6, -16)
  hint:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
  hint:SetJustifyH("LEFT")
  hint:SetText(text)
  local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  input:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 6, -8)
  input:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
  input:SetHeight(24)
  input:SetAutoFocus(false)
  input:SetMaxLetters(255)
  -- save the typed text
  input:SetScript("OnEditFocusLost", function(self)
    SaveMessage(key, self:GetText())
  end)
  input:SetScript("OnEnterPressed", input.ClearFocus)
  -- discard the typing and show the saved text again
  input:SetScript("OnEscapePressed", function(self)
    self:SetText(ns.Get(key))
    self:ClearFocus()
  end)
  inputs[key] = input
  return input
end

local first = TextField(heading, "message",
  "Right click on a mage in the list sends this text; saved on Enter or when leaving the field.")
TextField(first, "altMessage", "Alt+right click sends this text instead.")

-- show the texts of the active profile whenever the page opens
panel:SetScript("OnShow", function()
  for key, input in pairs(inputs) do
    input:SetText(ns.Get(key))
    input:SetCursorPosition(0)
  end
end)

-- attach the whisper page below the addon's settings page
local function AddWhisperPage()
  local title = C_AddOns.GetAddOnMetadata(ADDON, "Title") or ADDON
  for _, category in ipairs(SettingsPanel:GetAllCategories()) do
    if category:GetName() == title then
      Settings.RegisterCanvasLayoutSubcategory(category, panel, "Whisper")
      return
    end
  end
end

-- event handlers by event name
local events = {}

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
  altMessage = "Hi! Could you spare some food, please? Thank you!",
}, function()
  ns.Settings()
  AddWhisperPage()
end)

-- chat commands
ns.Command({ name = "scan", help = "list the mages nearby", run = Scan })
ns.Command({
  name = "message",
  help = "set the whisper text (use quotes)",
  args = { { name = "text" } },
  run = function(args)
    SaveMessage("message", args.text)
    ns.Status("whisper", args.text)
  end,
})
ns.Command({
  name = "altmessage",
  help = "set the Alt+right click whisper text (use quotes)",
  args = { { name = "text" } },
  run = function(args)
    SaveMessage("altMessage", args.text)
    ns.Status("alt whisper", args.text)
  end,
})
ns.Command({
  name = "character",
  help = "use settings for this character only, or the account's",
  args = { { name = "state", choices = { "on", "off" } } },
  run = function(args) PerCharacter(args.state == "on") end,
})
ns.Command({ name = "config", help = "open the settings page", run = ns.OpenSettings })
ns.Slash({ "/wm", "/watermooch" }, Status)
