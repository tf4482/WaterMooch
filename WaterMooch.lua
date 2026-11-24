-- WaterMooch: lists nearby mages on demand; a click targets, marks, and whispers one

local _, ns = ...

-- raid target icon index of the blue square
local SQUARE = 6
-- most rows the window shows
local ROWS = 10
-- row height in pixels
local ROW_HEIGHT = 20

-- label in Options > Keybindings > AddOns
_G["BINDING_NAME_WATERMOOCH_SCAN"] = "WaterMooch: Scan for mages"

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
  ns.Status("per character", ns.OnOff(ns.char.perCharacter))
  ns.Detail("scan with " .. ns.Color("command", ns.slash .. " scan") .. " or your key binding")
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
}, function()
  ns.Settings()
end)

-- chat commands
ns.Command({ name = "scan", help = "list the mages nearby", run = Scan })
ns.Command({
  name = "message",
  help = "set the whisper text (use quotes)",
  args = { { name = "text" } },
  run = function(args) SetMessage(args.text) end,
})
ns.Command({
  name = "character",
  help = "use settings for this character only, or the account's",
  args = { { name = "state", choices = { "on", "off" } } },
  run = function(args) PerCharacter(args.state == "on") end,
})
ns.Command({ name = "config", help = "open the settings page", run = ns.OpenSettings })
ns.Slash({ "/wm", "/watermooch" }, Status)
