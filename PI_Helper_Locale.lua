local _, ns = ...
local L = {}
ns.L = L

-- ============================================================
-- English (default)
-- ============================================================
L.TITLE                 = "PI Helper"
L.BTN_REINSPECT         = "Re-inspect"
L.BTN_ALERT_POS         = "Alert pos"
L.BTN_RESET             = "Reset"
L.CHK_AUTOPICK          = "Auto-pick"
L.STATUS_NONE           = "No target selected"
L.STATUS_TARGET         = "Target: "
L.STATUS_AUTO           = "Auto: "
L.NOTIF_REQUESTS        = "requests %s"
L.NOTIF_PREVIEW         = "(preview)"
L.HELP_HEADER           = "PI Helper commands:"
L.HELP_TOGGLE           = "  /pi            - toggle roster window"
L.HELP_TARGET           = "  /pi target N   - update macro target directly"
L.HELP_HELP             = "  /pi help       - this message"
L.MSG_LOADED            = "loaded. Type |cffffff00/pi|r to open."
L.MSG_MACRO_CREATED     = "Macro '%s' created."
L.MSG_MACRO_LIMIT       = "Could not create macro '%s' - you may be at the macro limit."
L.MSG_MACRO_UPDATED     = "Macro '%s' -> %s"
L.MSG_MACRO_NOT_FOUND   = "Could not find the /cast [@...] line in '%s'. Update manually."
L.MSG_MACRO_TARGETING   = "Created macro '%s' targeting %s"
L.MSG_RESET             = "Target reset to @focus."
L.MSG_REINSPECTING      = "Re-inspecting all members..."
L.MSG_PI_REQUESTED      = "PI requested."
L.MSG_NOT_IN_GROUP      = "You must be in a group to request PI."
L.MSG_USAGE_TARGET      = "Usage: /pi target <name>"

-- ============================================================
-- German
-- ============================================================
if GetLocale() == "deDE" then
    L.TITLE                 = "PI Helfer"
    L.BTN_REINSPECT         = "Neu prüfen"
    L.BTN_ALERT_POS         = "Alarm Pos."
    L.BTN_RESET             = "Zurücksetzen"
    L.CHK_AUTOPICK          = "Auto-Wahl"
    L.STATUS_NONE           = "Kein Ziel ausgewählt"
    L.STATUS_TARGET         = "Ziel: "
    L.STATUS_AUTO           = "Auto: "
    L.NOTIF_REQUESTS        = "bittet um %s"
    L.NOTIF_PREVIEW         = "(Vorschau)"
    L.HELP_HEADER           = "PI Helfer Befehle:"
    L.HELP_TOGGLE           = "  /pi            - Fenster ein-/ausblenden"
    L.HELP_TARGET           = "  /pi target N   - Makroziel direkt setzen"
    L.HELP_HELP             = "  /pi help       - diese Nachricht"
    L.MSG_LOADED            = "geladen. Tippe |cffffff00/pi|r zum Öffnen."
    L.MSG_MACRO_CREATED     = "Makro '%s' erstellt."
    L.MSG_MACRO_LIMIT       = "Makro '%s' konnte nicht erstellt werden - Makrolimit erreicht?"
    L.MSG_MACRO_UPDATED     = "Makro '%s' -> %s"
    L.MSG_MACRO_NOT_FOUND   = "Konnte die /cast [@...]-Zeile in '%s' nicht finden. Bitte manuell aktualisieren."
    L.MSG_MACRO_TARGETING   = "Makro '%s' erstellt mit Ziel %s"
    L.MSG_RESET             = "Ziel auf @focus zurückgesetzt."
    L.MSG_REINSPECTING      = "Alle Mitglieder werden neu geprüft..."
    L.MSG_PI_REQUESTED      = "PI angefragt."
    L.MSG_NOT_IN_GROUP      = "Du musst in einer Gruppe sein, um PI anzufragen."
    L.MSG_USAGE_TARGET      = "Verwendung: /pi target <Name>"
end
