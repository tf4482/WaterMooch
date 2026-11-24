-- Localized strings: English keys with German overrides on German clients; loads first in the TOC

local _, ns = ...

-- English defaults: any key without an override shows as itself
ns.L = setmetatable({}, { __index = function(_, key) return key end })

-- German overrides; component keys are the T("...") strings in the component files
if GetLocale() == "deDE" then
  local L = ns.L
  -- shared components
  L["on"] = "an"
  L["off"] = "aus"
  L["Per character"] = "Pro Charakter"
  L["Save the settings below for this character only instead of the whole account"] =
    "Die Einstellungen unten nur für diesen Charakter statt für den ganzen Account speichern"
  L["commands"] = "Befehle"
  L["show this help"] = "diese Hilfe anzeigen"
  L["usage"] = "Aufruf"
  L["unknown command"] = "unbekannter Befehl"
  L["see"] = "siehe"
  L["missing"] = "es fehlt"
  L["must be a number"] = "muss eine Zahl sein"
  L["from"] = "von"
  L["to"] = "bis"
  L["must be one of"] = "muss eins sein von"
  L["unknown option"] = "unbekannte Option"
  L["too many arguments"] = "zu viele Argumente"
  -- addon texts
  L["Scan for mages"] = "Nach Magiern suchen"
  L["Dispenser nearby"] = "Wasserspender in der Nähe"
  L["no whisper text set - see %s"] = "kein Flüstertext gesetzt - siehe %s"
  L["no mages found nearby"] = "keine Magier in der Nähe gefunden"
  L["%s mage(s) found"] = "%s Magier gefunden"
  L["scanning is not available right now"] = "Suche gerade nicht möglich"
  L["whisper (right click)"] = "Flüstern (Rechtsklick)"
  L["alt whisper (Alt+right click)"] = "Alt-Flüstern (Alt+Rechtsklick)"
  L["nameplate time"] = "Namensplaketten-Zeit"
  L["minimum level"] = "Mindeststufe"
  L["per character"] = "pro Charakter"
  L["scan with %s or your key binding"] = "Suche mit %s oder deiner Taste"
  L["Nameplate time"] = "Namensplaketten-Zeit"
  L["Minimum level"] = "Mindeststufe"
  L["Only list mages of this level or higher"] = "Nur Magier ab dieser Stufe auflisten"
  L["Whisper (right click)"] = "Flüstern (Rechtsklick)"
  L["Whisper (Alt+right click)"] = "Flüstern (Alt+Rechtsklick)"
  L["One sentence per line, a random one is sent; saved when leaving the field."] =
    "Ein Satz pro Zeile, ein zufälliger wird gesendet; gespeichert beim Verlassen des Feldes."
  L["list the mages nearby"] = "Magier in der Nähe auflisten"
  L["seconds a scan shows friendly nameplates"] = "Sekunden, die eine Suche freundliche Namensplaketten zeigt"
  L["only list mages of this level or higher"] = "nur Magier ab dieser Stufe auflisten"
  L["add the sentence as one more random choice"] = "den Satz als weitere zufällige Auswahl hinzufügen"
  L["set the right click whisper (use quotes)"] = "Flüstertext für Rechtsklick setzen (in Anführungszeichen)"
  L["set the Alt+right click whisper (use quotes)"] =
    "Flüstertext für Alt+Rechtsklick setzen (in Anführungszeichen)"
  L["use settings for this character only, or the account's"] =
    "Einstellungen nur für diesen Charakter oder für den Account"
  L["open the settings page"] = "Einstellungsseite öffnen"
  L["reset the active profile's settings to defaults"] =
    "Einstellungen des aktiven Profils auf Standard zurücksetzen"
  L["show what the addon does in chat, until /reload"] = "im Chat zeigen, was das Addon tut, bis /reload"
  L["settings reset to defaults"] = "Einstellungen auf Standard zurückgesetzt"
  L["Hi! Could you spare some water, please? Thank you!"] =
    "Hallo! Könntest du mir bitte etwas Wasser geben? Danke!"
  L["Thank you so much for the water, have a great day!"] =
    "Vielen Dank für das Wasser, hab einen schönen Tag!"
end
