-- WaterMooch texts: English by default, German on German clients

local _, ns = ...

-- English texts by key
local L = {
  BINDING = "WaterMooch: Scan for mages",
  WINDOW_TITLE = "Dispenser nearby",
  NO_TEXT = "no whisper text set - see %s",
  NONE_FOUND = "no mages found nearby",
  FOUND = "%s mage(s) found",
  NOT_NOW = "scanning is not available right now",
  WHISPER = "whisper (right click)",
  ALT_WHISPER = "alt whisper (Alt+right click)",
  PLATE_TIME = "nameplate time",
  MIN_LEVEL = "minimum level",
  PER_CHARACTER = "per character",
  SCAN_HINT = "scan with %s or your key binding",
  PLATE_TIME_LABEL = "Nameplate time",
  MIN_LEVEL_LABEL = "Minimum level",
  MIN_LEVEL_TOOLTIP = "Only list mages of this level or higher",
  WHISPER_LABEL = "Whisper (right click)",
  ALT_WHISPER_LABEL = "Whisper (Alt+right click)",
  TEXT_HINT = "One sentence per line, a random one is sent; saved when leaving the field.",
  HELP_SCAN = "list the mages nearby",
  HELP_TIME = "seconds a scan shows friendly nameplates",
  HELP_MINLEVEL = "only list mages of this level or higher",
  HELP_ADD = "add the sentence as one more random choice",
  HELP_MESSAGE = "set the right click whisper (use quotes)",
  HELP_ALTMESSAGE = "set the Alt+right click whisper (use quotes)",
  HELP_CHARACTER = "use settings for this character only, or the account's",
  HELP_CONFIG = "open the settings page",
  DEFAULT_MESSAGE = "Hi! Could you spare some water, please? Thank you!",
  DEFAULT_ALT_MESSAGE = "Thank you so much for the water, have a great day!",
}

-- German texts replace the English ones on German clients
if GetLocale() == "deDE" then
  local de = {
    BINDING = "WaterMooch: Nach Magiern suchen",
    WINDOW_TITLE = "Spender in der Nähe",
    NO_TEXT = "kein Flüstertext gesetzt - siehe %s",
    NONE_FOUND = "keine Magier in der Nähe gefunden",
    FOUND = "%s Magier gefunden",
    NOT_NOW = "Suche gerade nicht möglich",
    WHISPER = "Flüstern (Rechtsklick)",
    ALT_WHISPER = "Alt-Flüstern (Alt+Rechtsklick)",
    PLATE_TIME = "Namensplaketten-Zeit",
    MIN_LEVEL = "Mindeststufe",
    PER_CHARACTER = "pro Charakter",
    SCAN_HINT = "Suche mit %s oder deiner Taste",
    PLATE_TIME_LABEL = "Namensplaketten-Zeit",
    MIN_LEVEL_LABEL = "Mindeststufe",
    MIN_LEVEL_TOOLTIP = "Nur Magier ab dieser Stufe auflisten",
    WHISPER_LABEL = "Flüstern (Rechtsklick)",
    ALT_WHISPER_LABEL = "Flüstern (Alt+Rechtsklick)",
    TEXT_HINT = "Ein Satz pro Zeile, ein zufälliger wird gesendet; gespeichert beim Verlassen des Feldes.",
    HELP_SCAN = "Magier in der Nähe auflisten",
    HELP_TIME = "Sekunden, die eine Suche freundliche Namensplaketten zeigt",
    HELP_MINLEVEL = "nur Magier ab dieser Stufe auflisten",
    HELP_ADD = "den Satz als weitere zufällige Auswahl hinzufügen",
    HELP_MESSAGE = "Flüstertext für Rechtsklick setzen (in Anführungszeichen)",
    HELP_ALTMESSAGE = "Flüstertext für Alt+Rechtsklick setzen (in Anführungszeichen)",
    HELP_CHARACTER = "Einstellungen nur für diesen Charakter oder für den Account",
    HELP_CONFIG = "Einstellungsseite öffnen",
    DEFAULT_MESSAGE = "Hallo! Könntest du mir bitte etwas Wasser geben? Danke!",
    DEFAULT_ALT_MESSAGE = "Vielen Dank für das Wasser, hab einen schönen Tag!",
  }
  for key, text in pairs(de) do
    L[key] = text
  end
end

ns.L = L
