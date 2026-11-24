-- WaterMooch: lists nearby mages out of combat; a click targets, marks, and whispers one

local _, ns = ...

-- raid target icon index of the blue square
local SQUARE = 6
-- seconds a mage stays listed after last being seen
local TIMEOUT = 60
-- seconds between full scans
local INTERVAL = 5
-- most rows the window shows
local ROWS = 10
-- row height in pixels
local ROW_HEIGHT = 20

-- last time each mage was seen, by unit name
local mages = {}
-- periodic scan while the feature is on
local ticker
-- window closed by the player until a new mage shows up
local dismissed = false

-- whether the feature should act now: on and out of combat
local function Active()
  return ns.db ~= nil and ns.Get("enabled") and not InCombatLockdown()
end

-- send the configured whisper to a player
local function Whisper(name)
  local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
  send(ns.Get("message"), "WHISPER", nil, name)
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
-- close button: keep the window hidden until a new mage appears
window.CloseButton:HookScript("OnClick", function()
  dismissed = true
end)

-- secure row buttons: the macro targets, PostClick marks and whispers
local rows = {}
for index = 1, ROWS do
  local row = CreateFrame("Button", nil, window, "SecureActionButtonTemplate")
  row:SetHeight(ROW_HEIGHT)
  row:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -28 - (index - 1) * ROW_HEIGHT)
  row:SetPoint("TOPRIGHT", window, "TOPRIGHT", -12, -28 - (index - 1) * ROW_HEIGHT)
  -- both phases so the click works with either ActionButtonUseKeyDown setting
  row:RegisterForClicks("AnyUp", "AnyDown")
  row:SetAttribute("type", "macro")
  row:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight", "ADD")
  local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("LEFT", row, "LEFT", 4, 0)
  row:SetFontString(label)
  -- after the secure target: blue square and whisper, once per click
  row:SetScript("PostClick", function(self, _, down)
    if down ~= GetCVarBool("ActionButtonUseKeyDown") or not self.name or InCombatLockdown() then
      return
    end
    if GetUnitName("target", true) == self.name and GetRaidTargetIndex("target") ~= SQUARE then
      SetRaidTarget("target", SQUARE)
    end
    Whisper(self.name)
  end)
  row:Hide()
  rows[index] = row
end

-- remember a unit if it is a visible, friendly mage other than the player
local function See(unit)
  if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player")
    or not UnitIsVisible(unit) or not UnitIsFriend("player", unit) then
    return
  end
  local _, class = UnitClass(unit)
  local name = GetUnitName(unit, true)
  if class == "MAGE" and name then
    if not mages[name] then
      dismissed = false
    end
    mages[name] = GetTime()
  end
end

-- fill the rows with the listed mages and show or hide the window; out of combat only
local function Render()
  if InCombatLockdown() then
    return
  end
  local names = {}
  for name in pairs(mages) do
    names[#names + 1] = name
  end
  table.sort(names)
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
  window:SetShown(Active() and shown > 0 and not dismissed)
end

-- scan nameplates, group, target, and mouseover; drop mages not seen for a while
local function Scan()
  if not Active() then
    return
  end
  for index = 1, 40 do
    See("nameplate" .. index)
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
  local now = GetTime()
  for name, seen in pairs(mages) do
    if now - seen > TIMEOUT then
      mages[name] = nil
    end
  end
  Render()
end

-- start or stop scanning to match the setting; only called out of combat
local function Apply()
  if ns.Get("enabled") then
    ticker = ticker or C_Timer.NewTicker(INTERVAL, Scan)
    Scan()
  else
    if ticker then
      ticker:Cancel()
      ticker = nil
    end
    wipe(mages)
    Render()
  end
end

-- apply now, or right after combat
local function Refresh()
  ns.AfterCombat(Apply)
end

-- current state, with hints when it does not take effect yet
local function Status()
  local hint = ""
  if ns.Get("enabled") and InCombatLockdown() then
    hint = ns.Color("warning", " (paused in combat)")
  end
  ns.Print(ns.OnOff(ns.Get("enabled")) .. hint)
  ns.Status("whisper", ns.Get("message"))
  ns.Status("per character", ns.OnOff(ns.char.perCharacter))
end

-- switch the feature and report the new state
local function Switch(enabled)
  ns.Set("enabled", enabled)
  Status()
end

-- switch per-character settings and report the new state
local function PerCharacter(enabled)
  ns.Set("perCharacter", enabled)
  Status()
end

-- save the whisper text in the active profile; the settings page has no text field
local function SetMessage(text)
  local profile = ns.char.perCharacter and ns.char or ns.db
  profile.message = text
  ns.Status("whisper", text)
end

-- event handlers by event name
local events = {}

-- combat starts: hide the window while that is still allowed
function events.PLAYER_REGEN_DISABLED()
  window:Hide()
end

-- combat ends: scan and show the list again
function events.PLAYER_REGEN_ENABLED()
  Scan()
end

-- a nameplate appeared: check it right away
function events.NAME_PLATE_UNIT_ADDED(unit)
  if Active() then
    See(unit)
    Render()
  end
end

-- mouse over a unit: check it right away
function events.UPDATE_MOUSEOVER_UNIT()
  if Active() then
    See("mouseover")
    Render()
  end
end

-- new target: check it right away
function events.PLAYER_TARGET_CHANGED()
  if Active() then
    See("target")
    Render()
  end
end

-- one frame dispatching all events above
local frame = CreateFrame("Frame")
for event in pairs(events) do
  frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, ...)
  events[event](...)
end)

-- saved state; settings page and first apply once loaded
ns.Store("WaterMoochDB", {
  enabled = false,
  message = "Hi! Could you spare some water, please? Thank you!",
}, function()
  ns.Settings()
  ns.Checkbox("enabled", "Enabled", "List nearby mages out of combat", Refresh)
  Refresh()
end)

-- chat commands
ns.Command({ name = "on", help = "start listing nearby mages", run = function() Switch(true) end })
ns.Command({ name = "off", help = "stop listing nearby mages", run = function() Switch(false) end })
ns.Command({
  name = "message",
  help = "set the whisper text (use quotes)",
  args = { { name = "text" } },
  run = function(args) SetMessage(args.text) end,
})
ns.Command({
  name = "show",
  help = "show the mage window again after closing it",
  run = function()
    dismissed = false
    Refresh()
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
