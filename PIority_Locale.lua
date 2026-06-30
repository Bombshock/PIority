local _, ns = ...
local L = {}
ns.L = L

-- ============================================================
-- English (default)
-- ============================================================
-- NOTE: L.TITLE is intentionally NOT overridden in any locale block below.
-- The addon title must always be "PIority" in every language.
L.TITLE                 = "PIority"
L.BTN_OPTIONS           = "Options"
L.BTN_REINSPECT         = "Re-inspect"
L.BTN_ALERT_POS         = "Alert pos"
L.BTN_RESET             = "Reset"
L.BTN_PREVIEW           = "Preview notification"
L.CHK_AUTOPICK          = "Auto-pick"
L.STATUS_NONE           = "No target selected"
L.STATUS_TARGET         = "Target: "
L.STATUS_AUTO           = "Auto: "
L.NOTIF_REQUESTS        = "requests %s"
L.NOTIF_PREVIEW         = "(preview)"
L.OPT_TITLE             = "Settings"
L.OPT_SOUND_LABEL       = "PI Request Sound"
L.HELP_HEADER           = "PIority commands:"
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

-- Sound option labels
L.SOUND_RAID_WARNING    = "Raid Warning"
L.SOUND_PVP_QUEUE       = "PvP Queue Pop"
L.SOUND_READY_CHECK     = "Ready Check"
L.SOUND_WHISPER         = "Whisper"
L.SOUND_COIN            = "Coin Pling"
L.SOUND_ALARM           = "Alarm Clock"
L.SOUND_EPIC_LOOT       = "Epic Loot"
L.SOUND_QUEST_DONE      = "Quest Complete"
L.SOUND_BOSS_WARNING    = "Boss Warning"
L.SOUND_NONE            = "None"

-- Snapshot of English defaults, used by screenshot mode to override any locale.
ns.englishLocale = {}
for k, v in pairs(L) do ns.englishLocale[k] = v end

-- ============================================================
-- German
-- ============================================================
if GetLocale() == "deDE" then
    -- L.TITLE is deliberately omitted here; see the note above.
    L.BTN_OPTIONS           = "Optionen"
    L.BTN_REINSPECT         = "Neu prüfen"
    L.BTN_ALERT_POS         = "Alarm Pos."
    L.BTN_RESET             = "Zurücksetzen"
    L.BTN_PREVIEW           = "Benachrichtigung testen"
    L.CHK_AUTOPICK          = "Auto-Wahl"
    L.STATUS_NONE           = "Kein Ziel ausgewählt"
    L.STATUS_TARGET         = "Ziel: "
    L.STATUS_AUTO           = "Auto: "
    L.NOTIF_REQUESTS        = "bittet um %s"
    L.NOTIF_PREVIEW         = "(Vorschau)"
    L.OPT_TITLE             = "Einstellungen"
    L.OPT_SOUND_LABEL       = "PI-Anfrage-Sound"
    L.HELP_HEADER           = "PIority Befehle:"
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

    -- Sound option labels
    L.SOUND_RAID_WARNING    = "Schlachtzugswarnung"
    L.SOUND_PVP_QUEUE       = "PvP-Warteschlange"
    L.SOUND_READY_CHECK     = "Bereitschaftscheck"
    L.SOUND_WHISPER         = "Flüstern"
    L.SOUND_COIN            = "Münzkling"
    L.SOUND_ALARM           = "Wecker"
    L.SOUND_EPIC_LOOT       = "Epischer Fund"
    L.SOUND_QUEST_DONE      = "Quest abgeschlossen"
    L.SOUND_BOSS_WARNING    = "Bosswarnung"
    L.SOUND_NONE            = "Kein Sound"
end
