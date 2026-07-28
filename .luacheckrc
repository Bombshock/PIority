-- Luacheck configuration for the PIority WoW addon.
-- WoW runs a modified Lua 5.1. Lint from the addon folder with:  luacheck .
-- (luacheck itself runs on its own bundled Lua; this only tells it how to read
-- the source — it does not need Lua 5.1 installed.)

std = "lua51"
max_line_length = false

-- The implicit `self` in WoW widget script handlers (OnEnter/OnClick/...) is
-- frequently unused; that's idiomatic, not a smell.
ignore = { "212/self" }

-- Globals the addon itself creates and owns (writable).
globals = {
    "PIorityDB",            -- SavedVariables table
    "ProcessInspectQueue",  -- forward-declared, cross-function helper
    "SlashCmdList",
    "SLASH_PIH1", "SLASH_PIH2", "SLASH_PIREQUEST1",
}

-- WoW API surface used by the addon (read-only). Anything NOT listed here that
-- looks like a global will still be flagged — so a typo in a new API name is
-- caught, while these known calls stay quiet.
read_globals = {
    "ActionButton_HideOverlayGlow", "ActionButton_ShowOverlayGlow", "Ambiguate",
    "C_ChatInfo", "C_SpecializationInfo", "C_Spell", "C_StableInfo", "C_Timer",
    "C_TTSSettings", "C_VoiceChat", "CanInspect", "CreateFrame", "CreateMacro",
    "EditMacro", "Enum", "GameTooltip", "GetAverageItemLevel", "GetCursorPosition",
    "GetInspectSpecialization", "GetInventoryItemLink", "GetItemInfo", "GetMacroBody",
    "GetMacroIndexByName", "GetNumGroupMembers", "GetRealmName", "GetSpecialization",
    "GetSpecializationInfo", "GetSpecializationRoleByID", "GetSpellInfo", "GetSpellTexture",
    "GetTime", "InCombatLockdown", "IsInGroup", "IsInRaid", "IsSpellKnown", "Minimap",
    "NotifyInspect", "PlaySound", "RAID_CLASS_COLORS", "ReloadUI", "SOUNDKIT",
    "UIParent", "UnitClass", "UnitExists", "UnitGroupRolesAssigned", "UnitGUID",
    "UnitIsConnected", "UnitLevel", "UnitName", "wipe",
}
