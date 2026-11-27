-- Luacheck settings: catch accidental globals, unknown API names, and unused variables
std = "lua51"
max_line_length = false
exclude_files = { "Libs/", ".release/" }
-- globals the addon writes; append its BINDING_* names
globals = {
  "SlashCmdList",
  "BINDING_NAME_WATERMOOCH_SCAN",
}
-- WoW API read by the shared components and template; append every global the addon reads
read_globals = {
  "AddonCompartmentFrame",
  "C_AddOns",
  "C_EventUtils",
  "C_KeyBindings",
  "CreateFrame",
  "CreateKeybindingEntryInitializer",
  "CreateSettingsListSectionHeaderInitializer",
  "GetLocale",
  "GetTime",
  "hooksecurefunc",
  "InCombatLockdown",
  "IsInGroup",
  "IsInInstance",
  "IsInRaid",
  "MinimalSliderWithSteppersMixin",
  "Settings",
  "SettingsDropdownControlMixin",
  "C_ChatInfo",
  "C_CVar",
  "C_NamePlate",
  "C_Timer",
  "format",
  "GetCVarBool",
  "GetGuildInfo",
  "GetMaxLevelForPlayerExpansion",
  "GetUnitName",
  "IsAltKeyDown",
  "RAID_CLASS_COLORS",
  "SendChatMessage",
  "strtrim",
  "UIParent",
  "UnitClass",
  "UnitExists",
  "UnitIsFriend",
  "UnitIsPlayer",
  "UnitIsUnit",
  "UnitIsVisible",
  "UnitLevel",
}
