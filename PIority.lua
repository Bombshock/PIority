-- PIority: assign a Power Infusion macro target from a group/raid list.
-- Sorts players by spec priority; click a row to update the PI_H macro.

local _, ns = ...
local L = ns.L

local ADDON_NAME    = "PIority"
local MACRO_NAME    = "PI_H"
local PI_SPELL_ID   = 10060
local MD_SPELL_ID   = 34477  -- Misdirection
local MSG_PREFIX    = "PIority"
local MSG_REQUEST   = "REQUEST"
local MSG_ANNOUNCE  = "ANNOUNCE"

-- Returns the client-localized name of a spell.
-- Prefers the newer C_Spell API (11.0+) with a fallback to GetSpellInfo.
local function GetSpellNameByID(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    end
    return (GetSpellInfo(spellID))  -- extra () drops extra return values
end

-- Per-class macro configuration: which macro/spell each supported class manages,
-- and the default unit the macro returns to on reset / when leaving a group.
local CLASS_CONFIG = {
    PRIEST = {
        macroName   = MACRO_NAME,
        spellID     = PI_SPELL_ID,
        defaultName = "Power Infusion",
        resetTarget = "player",
        resetLabel  = "@player",
    },
    HUNTER = {
        macroName   = "MD_H",
        spellID     = MD_SPELL_ID,
        defaultName = "Misdirection",
        resetTarget = "pet",
        resetLabel  = "@pet",
    },
}

-- Returns this character's macro profile (nil if PIority doesn't manage a macro for their class).
local function GetActiveProfile()
    local _, playerClass = UnitClass("player")
    return CLASS_CONFIG[playerClass]
end

-- Class-flavored slash command shown in chat messages (/pi for priests,
-- /md for hunters). Both commands are registered and work for every class.
local function PrimarySlash()
    local _, playerClass = UnitClass("player")
    return playerClass == "HUNTER" and "/md" or "/pi"
end

local function BuildMacroBody(profile, targetName)
    local spell = GetSpellNameByID(profile.spellID) or profile.defaultName
    return string.format("#showtooltip %s\n/cast [@%s,exists,nodead][] %s",
        spell, targetName, spell)
end

local function BuildResetMacroBody(profile)
    return BuildMacroBody(profile, profile.resetTarget)
end

local CLASS_ATLAS = {
    WARRIOR     = "classicon-warrior",
    PALADIN     = "classicon-paladin",
    HUNTER      = "classicon-hunter",
    ROGUE       = "classicon-rogue",
    PRIEST      = "classicon-priest",
    DEATHKNIGHT = "classicon-deathknight",
    SHAMAN      = "classicon-shaman",
    MAGE        = "classicon-mage",
    WARLOCK     = "classicon-warlock",
    MONK        = "classicon-monk",
    DRUID       = "classicon-druid",
    DEMONHUNTER = "classicon-demonhunter",
    EVOKER      = "classicon-evoker",
}

local SPEC_NAME = {
    [62]=  "Arcane Mage",       [63]=  "Fire Mage",          [64]=  "Frost Mage",
    [65]=  "Holy Paladin",      [66]=  "Prot Paladin",        [70]=  "Ret Paladin",
    [71]=  "Arms Warrior",      [72]=  "Fury Warrior",        [73]=  "Prot Warrior",
    [102]= "Balance Druid",     [103]= "Feral Druid",         [104]= "Guardian Druid",    [105]= "Resto Druid",
    [250]= "Blood DK",          [251]= "Frost DK",            [252]= "Unholy DK",
    [253]= "BM Hunter",         [254]= "MM Hunter",           [255]= "Survival Hunter",
    [256]= "Discipline Priest", [257]= "Holy Priest",         [258]= "Shadow Priest",
    [259]= "Assassination Rog", [260]= "Outlaw Rogue",        [261]= "Subtlety Rogue",
    [262]= "Elemental Shaman",  [263]= "Enhancement Shaman",  [264]= "Resto Shaman",
    [265]= "Affliction Warlock",[266]= "Demo Warlock",        [267]= "Destro Warlock",
    [268]= "Brewmaster Monk",   [269]= "Windwalker Monk",     [270]= "Mistweaver Monk",
    [577]= "Havoc DH",          [581]= "Vengeance DH",       [1480]= "Devourer DH",
    [1467]="Devastation Evoker",[1468]="Preservation Evoker", [1473]="Augmentation Evoker",
}

-------------------------------------------------------------------------------
-- Screenshot mode — fake roster injected for promo screenshots
-------------------------------------------------------------------------------

-- pipct values mirror the patchwerk sim data so promo shots show real gains.
local SCREENSHOT_ROSTER = {
    { name = "DemoAlpha",   specID = 63,  classFile = "MAGE",        ilvl = 290, pipct = 6.3 },
    { name = "DemoBravo",   specID = 266, classFile = "WARLOCK",     ilvl = 290, pipct = 4.9 },
    { name = "DemoCharlie", specID = 258, classFile = "PRIEST",      ilvl = 290, pipct = 3.5 },
    { name = "DemoDelta",   specID = 251, classFile = "DEATHKNIGHT", ilvl = 290, pipct = 2.8 },
}

local function ApplyEnglishLocale()
    for k, v in pairs(ns.englishLocale) do L[k] = v end
end

-------------------------------------------------------------------------------
-- Member cache (populated at runtime; persisted via PIorityDB on load)
-------------------------------------------------------------------------------
local specCache    = {}  -- [name] = specID
local ilvlCache    = {}  -- [name] = average equipped item level (number)
local addonUsers   = {}  -- [name] = true (players who have PI_Helper installed)

-- Remove entries for players no longer in the current group.
local function PruneCacheToGroup()
    local current = { [UnitName("player")] = true }
    local numMembers = GetNumGroupMembers()
    if numMembers > 0 then
        local prefix = IsInRaid() and "raid" or "party"
        for i = 1, numMembers do
            local name = UnitName(prefix .. i)
            if name then current[name] = true end
        end
    end
    for name in pairs(specCache) do
        if not current[name] then
            specCache[name] = nil
            ilvlCache[name] = nil
        end
    end
    for name in pairs(addonUsers) do
        if not current[name] then addonUsers[name] = nil end
    end
end
local inspectQueue = {}
local inspectTimer = nil
local INSPECT_DELAY = 2  -- seconds between NotifyInspect calls

-- Slots that count toward average item level (skips shirt=4, tabard=19, bags).
local GEAR_SLOTS = { 1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17 }

local function CalcUnitIlvl(unit)
    local total, count = 0, 0
    for _, slot in ipairs(GEAR_SLOTS) do
        local link = GetInventoryItemLink(unit, slot)
        if link then
            local _, _, _, ilvl = GetItemInfo(link)
            if ilvl and ilvl > 0 then
                total = total + ilvl
                count = count + 1
            end
        end
    end
    return count > 0 and math.floor(total / count) or nil
end

local function CachePlayerIlvl()
    -- GetAverageItemLevel() -> avgTotal, avgEquipped, avgPvp
    local _, equipped = GetAverageItemLevel()
    if equipped and equipped > 0 then
        ilvlCache[UnitName("player")] = math.floor(equipped)
    end
end

local function GetUnitForName(name)
    if UnitName("player") == name then return "player" end
    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then return nil end
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, numMembers do
        local unit = prefix .. i
        if UnitName(unit) == name then return unit end
    end
    return nil
end

local function CachePlayerSpec()
    local specID = GetSpecializationInfo(GetSpecialization())
    if specID then specCache[UnitName("player")] = specID end
    CachePlayerIlvl()
end

local retryTimer = nil
local RETRY_DELAY = 2  -- seconds between retry passes

local function GetUnknownMembers()
    local unknown = {}
    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then return unknown end
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, numMembers do
        local unit = prefix .. i
        local name = UnitName(unit)
        if name and name ~= UnitName("player") and not specCache[name] then
            unknown[#unknown + 1] = name
        end
    end
    return unknown
end

local TryAutopick        -- defined after UI elements are in scope
local NotifyScanComplete -- defined after UI elements are in scope

-- Tracks whether the current scan actually had specs left to resolve. We only
-- treat a scan as "successful" when we go from having unknown members to having
-- none, so a group whose specs are all already cached (e.g. after /reload)
-- doesn't count as a fresh scan.
local hadUnknownMembers = false

local function ScheduleRetryIfNeeded()
    if retryTimer then retryTimer:Cancel() end
    local unknown = GetUnknownMembers()
    if #unknown == 0 then
        if hadUnknownMembers then
            hadUnknownMembers = false
            NotifyScanComplete()
        end
        TryAutopick()
        return
    end
    hadUnknownMembers = true
    retryTimer = C_Timer.NewTimer(RETRY_DELAY, function()
        retryTimer = nil
        -- Re-queue only members whose spec is still unknown
        local toRetry = GetUnknownMembers()
        if #toRetry == 0 then return end
        for _, name in ipairs(toRetry) do
            inspectQueue[#inspectQueue + 1] = name
        end
        if inspectTimer then inspectTimer:Cancel() end
        inspectTimer = C_Timer.NewTimer(0, ProcessInspectQueue)
    end)
end

-- Forward declaration so ScheduleRetryIfNeeded can reference it above.
ProcessInspectQueue = function()
    if #inspectQueue == 0 then
        inspectTimer = nil
        ScheduleRetryIfNeeded()
        return
    end
    local name = table.remove(inspectQueue, 1)
    local unit = GetUnitForName(name)
    if unit and UnitIsConnected(unit) and CanInspect(unit) then
        NotifyInspect(unit)
    else
        -- Not inspectable yet; put back at end of queue to retry in this pass.
        inspectQueue[#inspectQueue + 1] = name
    end
    inspectTimer = C_Timer.NewTimer(INSPECT_DELAY, ProcessInspectQueue)
end

local function QueueInspects()
    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then return end
    inspectQueue = {}
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, numMembers do
        local unit = prefix .. i
        local name = UnitName(unit)
        if name and name ~= UnitName("player") then
            inspectQueue[#inspectQueue + 1] = name
        end
    end
    if inspectTimer then inspectTimer:Cancel() end
    inspectTimer = C_Timer.NewTimer(0.5, ProcessInspectQueue)
end

-------------------------------------------------------------------------------
-- Addon presence announce
-------------------------------------------------------------------------------

local announceTimer = nil
local ANNOUNCE_DELAY = 3  -- seconds; debounce so GROUP_ROSTER_UPDATE spam doesn't flood

local function SendAddonAnnounce()
    local channel
    if IsInRaid()                   then channel = "RAID"
    elseif GetNumGroupMembers() > 0 then channel = "PARTY"
    end
    if channel then
        C_ChatInfo.SendAddonMessage(MSG_PREFIX, MSG_ANNOUNCE, channel)
    end
end

local function ScheduleAnnounce()
    if announceTimer then announceTimer:Cancel() end
    announceTimer = C_Timer.NewTimer(ANNOUNCE_DELAY, function()
        announceTimer = nil
        SendAddonAnnounce()
    end)
end

-------------------------------------------------------------------------------
-- Per-character target storage
-------------------------------------------------------------------------------
-- PIorityDB is account-wide, so the selected target is keyed by character to
-- keep a hunter's "pet" from showing up on a priest (and vice versa).

local function CharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

local function GetLastTarget()
    return PIorityDB and PIorityDB.charTargets and PIorityDB.charTargets[CharKey()]
end

local function SetLastTarget(name)  -- pass nil to clear
    if not PIorityDB then return end
    PIorityDB.charTargets = PIorityDB.charTargets or {}
    PIorityDB.charTargets[CharKey()] = name
end

-------------------------------------------------------------------------------
-- Macro helpers
-------------------------------------------------------------------------------

-- Last-known macro target per macro name. GetMacroBody does not return the
-- macro text during combat lockdown, so we cache the target whenever we can
-- read it out of combat and fall back to that cache in combat. Without this
-- the PI request popup never fires mid-fight, because the CHAT_MSG_ADDON gate
-- compares the sender against GetMacroTarget().
local macroTargetCache = {}

local function GetMacroTarget(profile)
    local body = GetMacroBody(profile.macroName)
    if not body then return macroTargetCache[profile.macroName] end
    local target = body:match("/cast %[@([^,]+),exists,nodead%]")
    macroTargetCache[profile.macroName] = target
    return target
end

-- Always create in the player (per-character) tab, never global, so each character
-- can have their own macro target without stomping other characters' macros.
local function CreateClassMacro(profile, body)
    return CreateMacro(profile.macroName, "INV_Misc_QuestionMark", body, true)
end

local function EnsureMacroExists(profile, targetName)
    if GetMacroIndexByName(profile.macroName) == 0 then
        CreateClassMacro(profile, BuildMacroBody(profile, targetName))
        print("|cff00ff96PIority:|r " .. L.MSG_MACRO_TARGETING:format(profile.macroName, targetName))
    end
end

local function UpdateMacroTarget(profile, targetName)
    EnsureMacroExists(profile, targetName)
    local body = GetMacroBody(profile.macroName)
    if not body then return end

    -- Matches any spell name after the conditional so it works in all locales.
    -- The `.-` swallows the legacy fallback bracket ([@focus] / [@pet,exists])
    -- from macros created by older versions, migrating them to the new format.
    local newBody, n = body:gsub(
        "/cast %[@[^,]+,exists,nodead%].-%[%] ([^\n]+)",
        "/cast [@" .. targetName .. ",exists,nodead][] %1",
        1
    )
    if n == 0 then
        print("|cffff4444PIority:|r " .. L.MSG_MACRO_NOT_FOUND:format(profile.macroName))
        return
    end

    EditMacro(profile.macroName, profile.macroName, nil, newBody)
    macroTargetCache[profile.macroName] = targetName
    print("|cff00ff96PIority:|r " .. L.MSG_MACRO_UPDATED:format(profile.macroName, targetName))
end

local ResetPITarget  -- defined after UI elements are in scope

-------------------------------------------------------------------------------
-- Roster building
-------------------------------------------------------------------------------

-- Which SimC PI table to rank by, chosen by group size: a party (<=5) uses the
-- 5-target profile, a raid (>5) uses the single-target profile. Returns nil if
-- the data modules aren't loaded, in which case members stay unscored and rank
-- alphabetically.
local function GetActivePIData()
    if not ns.piData then return nil end
    if GetNumGroupMembers() > 5 then
        return ns.piData.patchwerk1
    end
    return ns.piData.patchwerk5
end

-- Average equipped item level across the members we can rank. Used to normalize
-- gear so the score reflects a player's real throughput, not just their spec.
local function GroupAvgIlvl(members)
    local total, count = 0, 0
    for _, m in ipairs(members) do
        if m.ilvl and m.ilvl > 0 then
            total = total + m.ilvl
            count = count + 1
        end
    end
    if count == 0 then return nil end
    return total / count
end

-- The PI throughput gain a spec gets, as a percentage: (dpsWithPI - dpsNoPI) /
-- dpsNoPI. This is the raw effectiveness of PI on that spec, independent of gear,
-- and is exactly how the SimC tables rank specs.
local function PIPercent(specID, data)
    if not (specID and data and data.value and data.value2) then return nil end
    local withPI = data.value[specID]
    local base   = data.value2[specID]
    if not (withPI and base and base > 0) then return nil end
    return (withPI - base) / base * 100
end

-- PI is a damage cooldown, so tank and healer specs are ranked below every DPS
-- regardless of their sim value; they're only a target when no DPS is available.
-- Uses the spec's inherent role (Augmentation Evoker stays a damager).
local function IsSupportSpec(specID)
    if not (specID and GetSpecializationRoleByID) then return false end
    local role = GetSpecializationRoleByID(specID)
    return role == "TANK" or role == "HEALER"
end

-- A spec we actually rank and target for PI: a known, non-support (DPS) spec.
-- Tanks and healers are ignored entirely -- greyed out, no gain shown, never
-- auto-targeted -- even though tank specs do carry a sim value.
local function IsRankableSpec(specID)
    return specID ~= nil and not IsSupportSpec(specID)
end

local function GetSortedRoster()
    if PIorityDB and PIorityDB.screenshotMode then
        return SCREENSHOT_ROSTER
    end

    local numMembers = GetNumGroupMembers()
    local members = {}

    local selfName = UnitName("player")
    -- A priest never PIs themselves, so they're left out of their own list. Any
    -- other class can be a PI target, so show yourself in the roster too.
    local _, playerClass = UnitClass("player")
    local includeSelf = playerClass ~= "PRIEST"
    if includeSelf then
        members[#members + 1] = {
            name   = selfName,
            specID = specCache[selfName],
            level  = UnitLevel("player"),
            ilvl   = ilvlCache[selfName],
        }
    end

    if numMembers > 0 then
        local prefix = IsInRaid() and "raid" or "party"
        for i = 1, numMembers do
            local unit = prefix .. i
            local name = UnitName(unit)
            if name and name ~= selfName then
                members[#members + 1] = {
                    name   = name,
                    specID = specCache[name],
                    level  = UnitLevel(unit),
                    ilvl   = ilvlCache[name],
                }
            end
        end
    end

    local data = GetActivePIData()
    if data then
        local avgIlvl = GroupAvgIlvl(members)
        for _, m in ipairs(members) do
            -- Effectiveness = the spec's PI %-gain, scaled by how the player's
            -- gear compares to the group (missing gear -> neutral 1.0), so a
            -- better-geared player of the same spec ranks as the better target.
            -- Tanks/healers are skipped so they carry no score or gain.
            m.pipct = IsRankableSpec(m.specID) and PIPercent(m.specID, data) or nil
            if m.pipct then
                local gear = 1
                if avgIlvl and avgIlvl > 0 and m.ilvl and m.ilvl > 0 then
                    gear = m.ilvl / avgIlvl
                end
                m.score = m.pipct * gear
            end
        end
    end

    -- Rank by gear-normalized PI score; when the sim data isn't loaded no one is
    -- scored and members simply fall through to the alphabetical tiebreak.
    table.sort(members, function(a, b)
        local sa, sb = IsSupportSpec(a.specID), IsSupportSpec(b.specID)
        if sa ~= sb then return not sa end   -- DPS above tanks/healers
        if a.score and b.score then
            if a.score ~= b.score then return a.score > b.score end
            return a.name < b.name
        end
        if a.score then return true end   -- scored beats unscored
        if b.score then return false end
        return a.name < b.name            -- both unscored: alphabetical
    end)

    return members
end

-- Returns the name of the first group member with the Tank role assigned,
-- or nil if no one has a tank role (e.g. roles weren't assigned in a manual group).
local function FindFirstTank()
    if GetNumGroupMembers() == 0 then return nil end
    if UnitGroupRolesAssigned("player") == "TANK" then
        return UnitName("player")
    end
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, GetNumGroupMembers() do
        local unit = prefix .. i
        if UnitExists(unit) and UnitGroupRolesAssigned(unit) == "TANK" then
            return UnitName(unit)
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Sound options
-------------------------------------------------------------------------------

local SOUND_OPTIONS = {
    { key = "RAID_WARNING",  labelKey = "SOUND_RAID_WARNING",  kit = SOUNDKIT.RAID_WARNING           },
    { key = "PVP_QUEUE",     labelKey = "SOUND_PVP_QUEUE",     kit = SOUNDKIT.PVP_THROUGH_QUEUE      },
    { key = "READY_CHECK",   labelKey = "SOUND_READY_CHECK",   kit = SOUNDKIT.READY_CHECK            },
    { key = "WHISPER",       labelKey = "SOUND_WHISPER",       kit = SOUNDKIT.TELL_MESSAGE           },
    { key = "COIN",          labelKey = "SOUND_COIN",          kit = SOUNDKIT.LOOT_WINDOW_COIN_SOUND },
    { key = "ALARM",         labelKey = "SOUND_ALARM",         kit = SOUNDKIT.ALARM_CLOCK_WARNING_3  },
    { key = "EPIC_LOOT",     labelKey = "SOUND_EPIC_LOOT",     kit = SOUNDKIT.UI_EPICLOOT_TOAST      },
    { key = "QUEST_DONE",    labelKey = "SOUND_QUEST_DONE",    kit = SOUNDKIT.UI_AUTO_QUEST_COMPLETE  },
    { key = "BOSS_WARNING",  labelKey = "SOUND_BOSS_WARNING",  kit = SOUNDKIT.RAID_BOSS_EMOTE_WARNING },
    { key = "TTS_PI",        labelKey = "SOUND_TTS_PI",        tts = "plain"                         },
    { key = "TTS_NAME",      labelKey = "SOUND_TTS_NAME",      tts = "name"                          },
    { key = "NONE",          labelKey = "SOUND_NONE",          kit = nil                             },
}

local function GetSoundLabel(key)
    for _, opt in ipairs(SOUND_OPTIONS) do
        if opt.key == key then return L[opt.labelKey] end
    end
    return L.SOUND_RAID_WARNING
end

local function SpeakTTS(text)
    if not (C_VoiceChat and C_VoiceChat.SpeakText) then return end
    local voiceID = 0
    if C_TTSSettings and C_TTSSettings.GetVoiceOptionID then
        voiceID = C_TTSSettings.GetVoiceOptionID(0) or 0
    end
    local rate = (C_TTSSettings and C_TTSSettings.GetSpeechRate and C_TTSSettings.GetSpeechRate()) or 0
    local volume = (C_TTSSettings and C_TTSSettings.GetSpeechVolume and C_TTSSettings.GetSpeechVolume()) or 100
    C_VoiceChat.SpeakText(voiceID, text,
        Enum.VoiceTtsDestination and Enum.VoiceTtsDestination.QueuedLocalPlayback or 1,
        rate, volume)
end

-- Plays whatever the given option represents; requesterName feeds the TTS
-- name variant and may be nil (falls back to the plain phrase).
local function PlaySoundOption(opt, requesterName)
    if opt.tts then
        if opt.tts == "name" and requesterName then
            SpeakTTS(L.TTS_NAME_REQUESTED:format(Ambiguate(requesterName, "short")))
        else
            SpeakTTS(L.TTS_PI_REQUESTED)
        end
    elseif opt.kit then
        PlaySound(opt.kit)
    end
end

local function PlayPISound(requesterName)
    if not PIorityDB then return end
    local key = PIorityDB.soundKey or "RAID_WARNING"
    for _, opt in ipairs(SOUND_OPTIONS) do
        if opt.key == key then
            PlaySoundOption(opt, requesterName)
            return
        end
    end
end

-------------------------------------------------------------------------------
-- Glow options
-------------------------------------------------------------------------------

-- Glow control stored in ns so all closures share the same live reference.
ns.glow = {}

-------------------------------------------------------------------------------
-- UI
-------------------------------------------------------------------------------

local frame       -- forward-declare so SaveFrameLayout/RestoreFrameLayout can close over it
local notifFrame  -- same reason
local optFrame    -- settings window

-- Forward refs assigned when settings window is created
local reInspectBtn, notifToggleBtn, resetBtn

-- Main/options window layouts are shared across all characters by default.
-- When the "shared position" option is off they're stored per character, with
-- the shared values as fallback so a fresh character starts where the rest are.
local function GetLayoutStore()
    if PIorityDB.sharedLayout ~= false then return PIorityDB end
    PIorityDB.charLayouts = PIorityDB.charLayouts or {}
    local key = CharKey()
    PIorityDB.charLayouts[key] = PIorityDB.charLayouts[key] or {}
    return PIorityDB.charLayouts[key]
end

local function SaveFrameLayout()
    local point, _, relPoint, x, y = frame:GetPoint()
    GetLayoutStore().layout = {
        point    = point,
        relPoint = relPoint,
        x        = x,
        y        = y,
        width    = frame:GetWidth(),
        height   = frame:GetHeight(),
    }
end

local function RestoreFrameLayout()
    local store = GetLayoutStore()
    local l = store.layout or PIorityDB.layout
    if l then
        frame:ClearAllPoints()
        frame:SetPoint(l.point, UIParent, l.relPoint, l.x, l.y)
        frame:SetSize(
            math.max(200, l.width  or 290),
            math.max(150, l.height or 420)
        )
    end
end

-- Screen-absolute coordinates: the options window is anchored to the main
-- window until first dragged, so GetPoint() offsets wouldn't survive a
-- re-anchor to UIParent.
local function SaveOptLayout()
    local left, top = optFrame:GetLeft(), optFrame:GetTop()
    if not left or not top then return end
    GetLayoutStore().optLayout = { x = left, y = top }
end

local function RestoreOptLayout()
    local store = GetLayoutStore()
    local l = store.optLayout or PIorityDB.optLayout
    if l then
        optFrame:ClearAllPoints()
        optFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l.x, l.y)
    end
end

local function SaveNotifLayout()
    local point, _, relPoint, x, y = notifFrame:GetPoint()
    PIorityDB.notifLayout = { point = point, relPoint = relPoint, x = x, y = y }
end

local function RestoreNotifLayout()
    local l = PIorityDB.notifLayout
    if l then
        notifFrame:ClearAllPoints()
        notifFrame:SetPoint(l.point, UIParent, l.relPoint, l.x, l.y)
    end
end

-- Colour palette (purple/violet theme)
local P = {
    bg     = { 0.07, 0.07, 0.11, 0.97 },
    header = { 0.13, 0.10, 0.22, 1.00 },
    footer = { 0.09, 0.08, 0.14, 1.00 },
    border = { 0.22, 0.18, 0.32, 1.00 },
    sep    = { 0.30, 0.25, 0.44, 0.70 },
    accent = { 0.52, 0.32, 0.92, 1.00 },
    btnBg  = { 0.13, 0.11, 0.20, 0.92 },
    btnHov = { 0.22, 0.18, 0.34, 0.95 },
    btnBd  = { 0.28, 0.22, 0.42, 1.00 },
    btnHBd = { 0.55, 0.42, 0.85, 1.00 },
    text   = { 0.88, 0.86, 0.95, 1.00 },
    dim    = { 0.72, 0.68, 0.88, 1.00 },
    title  = { 1.00, 0.86, 0.42, 1.00 },
    chkBg  = { 0.08, 0.08, 0.13, 0.95 },
    chkBd  = { 0.28, 0.23, 0.42, 1.00 },
    chkOn  = { 0.28, 0.65, 0.35, 1.00 },
}

local HEADER_H = 32
local FOOTER_H = 32
local ROW_H    = 26

local solidBD = {
    bgFile   = "Interface/Buttons/WHITE8X8",
    edgeFile = "Interface/Buttons/WHITE8X8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function ApplyFlatBg(f, r, g, b, a, er, eg, eb, ea)
    f:SetBackdrop(solidBD)
    f:SetBackdropColor(r, g, b, a or 1)
    f:SetBackdropBorderColor(er or P.border[1], eg or P.border[2], eb or P.border[3], ea or P.border[4])
end

local function MakeFlatBtn(parent, text, w, h)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w or 70, h or 22)
    ApplyFlatBg(btn, P.btnBg[1], P.btnBg[2], P.btnBg[3], P.btnBg[4],
                     P.btnBd[1], P.btnBd[2], P.btnBd[3], P.btnBd[4])
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints()
    fs:SetJustifyH("CENTER")
    fs:SetTextColor(P.text[1], P.text[2], P.text[3])
    fs:SetText(text)
    btn.label = fs
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(P.btnHov[1], P.btnHov[2], P.btnHov[3], P.btnHov[4])
        self:SetBackdropBorderColor(P.btnHBd[1], P.btnHBd[2], P.btnHBd[3], P.btnHBd[4])
        fs:SetTextColor(1, 1, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        if self:IsEnabled() then
            self:SetBackdropColor(P.btnBg[1], P.btnBg[2], P.btnBg[3], P.btnBg[4])
            self:SetBackdropBorderColor(P.btnBd[1], P.btnBd[2], P.btnBd[3], P.btnBd[4])
            fs:SetTextColor(P.text[1], P.text[2], P.text[3])
        end
    end)
    local origSetEnabled = btn.SetEnabled
    function btn:SetEnabled(v)
        origSetEnabled(self, v)
        if v then
            self:SetBackdropColor(P.btnBg[1], P.btnBg[2], P.btnBg[3], P.btnBg[4])
            self:SetBackdropBorderColor(P.btnBd[1], P.btnBd[2], P.btnBd[3], P.btnBd[4])
            fs:SetTextColor(P.text[1], P.text[2], P.text[3])
        else
            self:SetBackdropColor(0.08, 0.07, 0.12, 1)
            self:SetBackdropBorderColor(P.btnBd[1], P.btnBd[2], P.btnBd[3], 0.4)
            fs:SetTextColor(0.45, 0.42, 0.55)
        end
    end
    return btn
end

-- Resize a flat button to fit its label text (runs on the next frame tick).
local function AutoSizeBtn(btn, minW, pad)
    C_Timer.After(0, function()
        local fs = btn.label or btn:GetFontString()
        if not fs then return end
        local w = fs:GetStringWidth()
        if w > 0 then btn:SetWidth(math.max(minW or 40, w + (pad or 22))) end
    end)
end

-- Forward refs: defined after notifFrame is created below.
local ShowNotifPreview
local ShowPreviewWithSound

-------------------------------------------------------------------------------
-- Main frame
-------------------------------------------------------------------------------

frame = CreateFrame("Frame", "PIorityFrame", UIParent, "BackdropTemplate")
frame:SetSize(290, 420)
frame:SetPoint("CENTER")
frame:SetMovable(true)
-- Keep WoW from saving this named movable frame per character in
-- layout-local.txt; PIorityDB is the single source of truth for positions.
frame:SetDontSavePosition(true)
frame:SetResizable(true)
frame:SetResizeBounds(200, 150)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
ApplyFlatBg(frame, P.bg[1], P.bg[2], P.bg[3], P.bg[4])
frame:Hide()

-- Header strip
local headerBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
headerBar:SetPoint("TOPLEFT",  frame, "TOPLEFT",  1, -1)
headerBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
headerBar:SetHeight(HEADER_H)
ApplyFlatBg(headerBar, P.header[1], P.header[2], P.header[3], P.header[4],
                        P.header[1], P.header[2], P.header[3], 0)

local accentLine = frame:CreateTexture(nil, "ARTWORK")
accentLine:SetHeight(2)
accentLine:SetColorTexture(P.accent[1], P.accent[2], P.accent[3], 1)
accentLine:SetPoint("TOPLEFT",  frame, "TOPLEFT",  1, -(HEADER_H + 1))
accentLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -(HEADER_H + 1))

-- PI spell icon in header
local headerIcon = headerBar:CreateTexture(nil, "OVERLAY")
headerIcon:SetSize(18, 18)
headerIcon:SetPoint("LEFT", headerBar, "LEFT", 10, 0)
headerIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
C_Timer.After(0, function()
    local spellID = (GetActiveProfile() or CLASS_CONFIG.PRIEST).spellID
    local iconPath = (C_Spell and C_Spell.GetSpellTexture) and C_Spell.GetSpellTexture(spellID)
                     or GetSpellTexture(spellID)
    if iconPath then headerIcon:SetTexture(iconPath) end
end)

local titleText = headerBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("CENTER", headerBar, "CENTER", 0, 0)
titleText:SetText("|cff8552ebPI|r|cffFFDC6Bority|r")

-- Close button
local closeBtn = CreateFrame("Button", nil, headerBar, "BackdropTemplate")
closeBtn:SetSize(24, 24)
closeBtn:SetPoint("RIGHT", headerBar, "RIGHT", -6, 0)
local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND")
closeBg:SetAllPoints()
closeBg:SetColorTexture(0.5, 0.1, 0.1, 0)
local closeLbl = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
closeLbl:SetAllPoints()
closeLbl:SetJustifyH("CENTER")
closeLbl:SetText("x")
closeLbl:SetTextColor(0.55, 0.45, 0.70)
closeBtn:SetScript("OnEnter", function()
    closeBg:SetColorTexture(0.5, 0.1, 0.1, 0.7)
    closeLbl:SetTextColor(1, 0.35, 0.35)
end)
closeBtn:SetScript("OnLeave", function()
    closeBg:SetColorTexture(0.5, 0.1, 0.1, 0)
    closeLbl:SetTextColor(0.55, 0.45, 0.70)
end)
closeBtn:SetScript("OnClick", function() frame:Hide() end)

-- Options button (opens settings window), anchored left of the close button
local optionsBtn = CreateFrame("Button", nil, headerBar, "BackdropTemplate")
optionsBtn:SetSize(52, 22)
optionsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
local optionsBtnBg = optionsBtn:CreateTexture(nil, "BACKGROUND")
optionsBtnBg:SetAllPoints()
optionsBtnBg:SetColorTexture(0.12, 0.10, 0.20, 0)
local optionsBtnLbl = optionsBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
optionsBtnLbl:SetAllPoints()
optionsBtnLbl:SetJustifyH("CENTER")
optionsBtnLbl:SetText("|cffb399dd" .. L.BTN_OPTIONS .. "|r")
optionsBtn.label = optionsBtnLbl
AutoSizeBtn(optionsBtn, 40, 24)
optionsBtn:SetScript("OnEnter", function()
    optionsBtnBg:SetColorTexture(0.25, 0.18, 0.40, 0.7)
    optionsBtnLbl:SetTextColor(0.80, 0.65, 1.00)
end)
optionsBtn:SetScript("OnLeave", function()
    optionsBtnBg:SetColorTexture(0.12, 0.10, 0.20, 0)
    optionsBtnLbl:SetTextColor(0.70, 0.58, 0.88)
end)
optionsBtn:SetScript("OnClick", function()
    if optFrame:IsShown() then
        optFrame:Hide()
    else
        optFrame:Show()
    end
end)

-- Drag via header
headerBar:EnableMouse(true)
headerBar:RegisterForDrag("LeftButton")
headerBar:SetScript("OnDragStart", function() frame:StartMoving() end)
headerBar:SetScript("OnDragStop",  function()
    frame:StopMovingOrSizing()
    SaveFrameLayout()
end)

-- Footer strip
local footerBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
footerBar:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  1, 1)
footerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
footerBar:SetHeight(FOOTER_H)
ApplyFlatBg(footerBar, P.footer[1], P.footer[2], P.footer[3], P.footer[4],
                        P.footer[1], P.footer[2], P.footer[3], 0)

local footerLine = frame:CreateTexture(nil, "ARTWORK")
footerLine:SetHeight(1)
footerLine:SetColorTexture(P.sep[1], P.sep[2], P.sep[3], P.sep[4])
footerLine:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  1, FOOTER_H + 1)
footerLine:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, FOOTER_H + 1)

-- Scroll list (starts directly below accent line, no button bar)
local LIST_TOP  = HEADER_H + 3
local TRACK_W   = 4
local THUMB_MIN = 20

local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",     1,              -LIST_TOP)
scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(TRACK_W + 6), FOOTER_H + 2)
scrollFrame:EnableMouseWheel(true)

-- Thin scrollbar track
local sbTrack = CreateFrame("Frame", nil, frame, "BackdropTemplate")
sbTrack:SetWidth(TRACK_W)
sbTrack:SetPoint("TOPRIGHT",    frame, "TOPRIGHT",    -(3),          -LIST_TOP)
sbTrack:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(3),          FOOTER_H + 2)
ApplyFlatBg(sbTrack, 0.10, 0.10, 0.15, 1, 0.10, 0.10, 0.15, 0)

local sbThumb = CreateFrame("Frame", nil, sbTrack, "BackdropTemplate")
sbThumb:SetWidth(TRACK_W)
ApplyFlatBg(sbThumb, P.border[1], P.border[2], P.border[3], 1,
                     P.border[1], P.border[2], P.border[3], 0)
sbThumb:Hide()

local content  -- forward-declared so UpdateScrollThumb can close over it

local function UpdateScrollThumb()
    local contentH = content:GetHeight()
    local viewH    = scrollFrame:GetHeight()
    if contentH <= viewH then sbThumb:Hide(); return end
    sbThumb:Show()
    local trackH  = sbTrack:GetHeight()
    local thumbH  = math.max(THUMB_MIN, trackH * (viewH / contentH))
    sbThumb:SetHeight(thumbH)
    local maxScroll = scrollFrame:GetVerticalScrollRange()
    local frac      = maxScroll > 0 and (scrollFrame:GetVerticalScroll() / maxScroll) or 0
    sbThumb:ClearAllPoints()
    sbThumb:SetPoint("TOP", sbTrack, "TOP", 0, -frac * (trackH - thumbH))
end

scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local max = self:GetVerticalScrollRange()
    local new = math.max(0, math.min(max, self:GetVerticalScroll() - delta * 20))
    self:SetVerticalScroll(new)
    UpdateScrollThumb()
end)

content = CreateFrame("Frame", nil, scrollFrame)
content:SetHeight(1)
scrollFrame:SetScrollChild(content)

local function SyncContentWidth()
    content:SetWidth(scrollFrame:GetWidth())
end
scrollFrame:SetScript("OnSizeChanged", function()
    SyncContentWidth()
    UpdateScrollThumb()
    if frame:IsShown() then frame.Refresh() end
end)

-- Autopick toggle
local CHK = 14
local autopickCheck = CreateFrame("Button", "PIorityAutopick", footerBar, "BackdropTemplate")
autopickCheck:SetSize(CHK, CHK)
autopickCheck:SetPoint("LEFT", footerBar, "LEFT", 10, 0)
ApplyFlatBg(autopickCheck, P.chkBg[1], P.chkBg[2], P.chkBg[3], P.chkBg[4],
                            P.chkBd[1], P.chkBd[2], P.chkBd[3], P.chkBd[4])

local chkMark = autopickCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
chkMark:SetAllPoints()
chkMark:SetJustifyH("CENTER")
chkMark:SetJustifyV("MIDDLE")

local chkChecked = false
function autopickCheck:GetChecked() return chkChecked end
function autopickCheck:SetChecked(v)
    chkChecked = v
    if v then
        chkMark:SetText("|cff33FF66v|r")
        autopickCheck:SetBackdropBorderColor(P.chkOn[1], P.chkOn[2], P.chkOn[3], P.chkOn[4])
    else
        chkMark:SetText("")
        autopickCheck:SetBackdropBorderColor(P.chkBd[1], P.chkBd[2], P.chkBd[3], P.chkBd[4])
    end
end
autopickCheck:SetScript("OnClick", function()
    autopickCheck:SetChecked(not chkChecked)
    PIorityDB.autopick = chkChecked
    if chkChecked then TryAutopick() end
end)
autopickCheck:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.14, 0.14, 0.22, 0.95)
end)
autopickCheck:SetScript("OnLeave", function(self)
    self:SetBackdropColor(P.chkBg[1], P.chkBg[2], P.chkBg[3], P.chkBg[4])
end)

local chkLabelBtn = CreateFrame("Button", nil, footerBar)
chkLabelBtn:SetPoint("LEFT", autopickCheck, "RIGHT", 5, 0)
local chkLabel = chkLabelBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
chkLabel:SetAllPoints()
chkLabel:SetTextColor(P.dim[1], P.dim[2], P.dim[3])
chkLabel:SetText(L.CHK_AUTOPICK)
chkLabelBtn:SetSize(chkLabel:GetStringWidth() + 2, CHK)
chkLabelBtn:SetScript("OnClick", function()
    autopickCheck:SetChecked(not chkChecked)
    PIorityDB.autopick = chkChecked
    if chkChecked then TryAutopick() end
end)
chkLabelBtn:SetScript("OnEnter", function() chkLabel:SetTextColor(1, 0.95, 1) end)
chkLabelBtn:SetScript("OnLeave", function() chkLabel:SetTextColor(P.dim[1], P.dim[2], P.dim[3]) end)
C_Timer.After(0, function()
    chkLabelBtn:SetWidth(math.max(10, chkLabel:GetStringWidth() + 2))
end)

local statusLabel = footerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
statusLabel:SetPoint("RIGHT", footerBar, "RIGHT", -10, 0)
statusLabel:SetJustifyH("RIGHT")
statusLabel:SetTextColor(P.dim[1], P.dim[2], P.dim[3])
statusLabel:SetText(L.STATUS_NONE)

-- Resize grip
local resizeGrip = CreateFrame("Button", nil, frame)
resizeGrip:SetSize(16, 16)
resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
resizeGrip:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
resizeGrip:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
resizeGrip:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")
resizeGrip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
resizeGrip:SetScript("OnMouseUp",   function()
    frame:StopMovingOrSizing()
    SaveFrameLayout()
    frame.Refresh()
end)

-------------------------------------------------------------------------------
-- Settings window
-------------------------------------------------------------------------------

optFrame = CreateFrame("Frame", "PIorityOptionsFrame", UIParent, "BackdropTemplate")
optFrame:SetSize(310, 192)
optFrame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 6, 0)
optFrame:SetMovable(true)
optFrame:SetDontSavePosition(true)
optFrame:SetClampedToScreen(true)
optFrame:EnableMouse(true)
optFrame:RegisterForDrag("LeftButton")
optFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
optFrame:SetScript("OnDragStop",  function(self)
    self:StopMovingOrSizing()
    SaveOptLayout()
end)
optFrame:SetFrameStrata("HIGH")
ApplyFlatBg(optFrame, P.bg[1], P.bg[2], P.bg[3], P.bg[4])
optFrame:Hide()

-- Settings header
local optHeader = CreateFrame("Frame", nil, optFrame, "BackdropTemplate")
optHeader:SetPoint("TOPLEFT",  optFrame, "TOPLEFT",  1, -1)
optHeader:SetPoint("TOPRIGHT", optFrame, "TOPRIGHT", -1, -1)
optHeader:SetHeight(HEADER_H)
ApplyFlatBg(optHeader, P.header[1], P.header[2], P.header[3], P.header[4],
                        P.header[1], P.header[2], P.header[3], 0)

local optAccent = optFrame:CreateTexture(nil, "ARTWORK")
optAccent:SetHeight(2)
optAccent:SetColorTexture(P.accent[1], P.accent[2], P.accent[3], 1)
optAccent:SetPoint("TOPLEFT",  optFrame, "TOPLEFT",  1, -(HEADER_H + 1))
optAccent:SetPoint("TOPRIGHT", optFrame, "TOPRIGHT", -1, -(HEADER_H + 1))

local optTitle = optHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
optTitle:SetPoint("CENTER", optHeader, "CENTER", 0, 0)
optTitle:SetText("|cffFFDC6B" .. L.OPT_TITLE .. "|r")

local optCloseBtn = CreateFrame("Button", nil, optHeader, "BackdropTemplate")
optCloseBtn:SetSize(24, 24)
optCloseBtn:SetPoint("RIGHT", optHeader, "RIGHT", -6, 0)
local optCloseBg = optCloseBtn:CreateTexture(nil, "BACKGROUND")
optCloseBg:SetAllPoints()
optCloseBg:SetColorTexture(0.5, 0.1, 0.1, 0)
local optCloseLbl = optCloseBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
optCloseLbl:SetAllPoints()
optCloseLbl:SetJustifyH("CENTER")
optCloseLbl:SetText("x")
optCloseLbl:SetTextColor(0.55, 0.45, 0.70)
optCloseBtn:SetScript("OnEnter", function()
    optCloseBg:SetColorTexture(0.5, 0.1, 0.1, 0.7)
    optCloseLbl:SetTextColor(1, 0.35, 0.35)
end)
optCloseBtn:SetScript("OnLeave", function()
    optCloseBg:SetColorTexture(0.5, 0.1, 0.1, 0)
    optCloseLbl:SetTextColor(0.55, 0.45, 0.70)
end)
optCloseBtn:SetScript("OnClick", function() optFrame:Hide() end)

optHeader:EnableMouse(true)
optHeader:RegisterForDrag("LeftButton")
optHeader:SetScript("OnDragStart", function() optFrame:StartMoving() end)
optHeader:SetScript("OnDragStop",  function()
    optFrame:StopMovingOrSizing()
    SaveOptLayout()
end)
optHeader:SetScript("OnMouseUp",   function() optFrame:StopMovingOrSizing() end)
optFrame:SetScript("OnMouseUp",    function() optFrame:StopMovingOrSizing() end)

-- Content area inside settings window
local OPT_TOP = HEADER_H + 3  -- offset from top of optFrame

-- Action buttons row
reInspectBtn = MakeFlatBtn(optFrame, L.BTN_REINSPECT, nil, 22)
reInspectBtn:SetPoint("TOPLEFT", optFrame, "TOPLEFT", 8, -(OPT_TOP + 8))
AutoSizeBtn(reInspectBtn)
reInspectBtn:SetScript("OnClick", function()
    wipe(specCache)
    wipe(ilvlCache)
    CachePlayerSpec()
    QueueInspects()
    print("|cff00ff96PIority:|r " .. L.MSG_REINSPECTING)
end)

notifToggleBtn = MakeFlatBtn(optFrame, L.BTN_ALERT_POS, nil, 22)
notifToggleBtn:SetPoint("LEFT", reInspectBtn, "RIGHT", 4, 0)
AutoSizeBtn(notifToggleBtn)
notifToggleBtn:SetScript("OnClick", function()
    if notifFrame:IsShown() and notifFrame.isPreview then
        notifFrame.isPreview = false
        notifFrame:Hide()
    else
        ShowNotifPreview()
    end
end)

resetBtn = MakeFlatBtn(optFrame, L.BTN_RESET, nil, 22)
resetBtn:SetPoint("LEFT", notifToggleBtn, "RIGHT", 4, 0)
AutoSizeBtn(resetBtn)
resetBtn:SetScript("OnClick", function() ResetPITarget() end)

-- Separator between buttons and sound section
local optSep = optFrame:CreateTexture(nil, "ARTWORK")
optSep:SetHeight(1)
optSep:SetColorTexture(P.sep[1], P.sep[2], P.sep[3], P.sep[4])
optSep:SetPoint("TOPLEFT",  optFrame, "TOPLEFT",  1, -(OPT_TOP + 42))
optSep:SetPoint("TOPRIGHT", optFrame, "TOPRIGHT", -1, -(OPT_TOP + 42))

-- Sound section label
local soundLabel = optFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
soundLabel:SetPoint("TOPLEFT", optFrame, "TOPLEFT", 10, -(OPT_TOP + 52))
soundLabel:SetTextColor(P.dim[1], P.dim[2], P.dim[3])
soundLabel:SetText(L.OPT_SOUND_LABEL)

-- Red "only for priests" hint on the same line, shown for non-priest characters.
local priestOnlyLabel = optFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
priestOnlyLabel:SetPoint("TOPRIGHT", optFrame, "TOPRIGHT", -10, -(OPT_TOP + 52))
priestOnlyLabel:SetJustifyH("RIGHT")
priestOnlyLabel:SetTextColor(1.0, 0.27, 0.27)
priestOnlyLabel:SetText(L.OPT_PRIESTS_ONLY)
priestOnlyLabel:Hide()

-- Custom sound dropdown (stretches to fill, leaving room for the preview button on the right)
local soundDropBtn = CreateFrame("Button", nil, optFrame, "BackdropTemplate")
soundDropBtn:SetHeight(24)
soundDropBtn:SetPoint("TOPLEFT",  optFrame, "TOPLEFT",  10,  -(OPT_TOP + 68))
soundDropBtn:SetPoint("TOPRIGHT", optFrame, "TOPRIGHT", -38, -(OPT_TOP + 68))
ApplyFlatBg(soundDropBtn, P.btnBg[1], P.btnBg[2], P.btnBg[3], P.btnBg[4],
                           P.btnBd[1], P.btnBd[2], P.btnBd[3], P.btnBd[4])

local soundDropLabel = soundDropBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
soundDropLabel:SetPoint("LEFT",  soundDropBtn, "LEFT",  8, 0)
soundDropLabel:SetPoint("RIGHT", soundDropBtn, "RIGHT", -24, 0)
soundDropLabel:SetJustifyH("LEFT")
soundDropLabel:SetTextColor(P.text[1], P.text[2], P.text[3])
soundDropLabel:SetText(L.SOUND_RAID_WARNING)

local soundArrow = soundDropBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
soundArrow:SetPoint("RIGHT", soundDropBtn, "RIGHT", -6, 0)
soundArrow:SetTextColor(P.accent[1], P.accent[2], P.accent[3])
soundArrow:SetText("v")

soundDropBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(P.btnHov[1], P.btnHov[2], P.btnHov[3], P.btnHov[4])
    self:SetBackdropBorderColor(P.btnHBd[1], P.btnHBd[2], P.btnHBd[3], P.btnHBd[4])
    soundDropLabel:SetTextColor(1, 1, 1)
end)
soundDropBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(P.btnBg[1], P.btnBg[2], P.btnBg[3], P.btnBg[4])
    self:SetBackdropBorderColor(P.btnBd[1], P.btnBd[2], P.btnBd[3], P.btnBd[4])
    soundDropLabel:SetTextColor(P.text[1], P.text[2], P.text[3])
end)

-- Dropdown popup list (parented to UIParent so it can extend outside the settings window)
local soundPopup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
soundPopup:SetFrameStrata("TOOLTIP")
ApplyFlatBg(soundPopup, P.bg[1], P.bg[2], P.bg[3], P.bg[4],
                         P.accent[1], P.accent[2], P.accent[3], 0.8)
soundPopup:Hide()

local POPUP_ROW_H = 22
soundPopup:SetHeight(#SOUND_OPTIONS * POPUP_ROW_H + 2)

local function UpdateSoundDropLabel()
    local key = (PIorityDB and PIorityDB.soundKey) or "RAID_WARNING"
    soundDropLabel:SetText(GetSoundLabel(key))
end

for i, opt in ipairs(SOUND_OPTIONS) do
    local row = CreateFrame("Button", nil, soundPopup, "BackdropTemplate")
    row:SetHeight(POPUP_ROW_H)
    row:SetPoint("TOPLEFT",  soundPopup, "TOPLEFT",  1, -1 - (i - 1) * POPUP_ROW_H)
    row:SetPoint("TOPRIGHT", soundPopup, "TOPRIGHT", -1, -1 - (i - 1) * POPUP_ROW_H)
    ApplyFlatBg(row, P.bg[1], P.bg[2], P.bg[3], 0, P.bg[1], P.bg[2], P.bg[3], 0)

    local rowLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rowLbl:SetPoint("LEFT", row, "LEFT", 10, 0)
    rowLbl:SetTextColor(P.text[1], P.text[2], P.text[3])
    rowLbl:SetText(L[opt.labelKey])

    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(P.btnHov[1], P.btnHov[2], P.btnHov[3], 0.9)
        rowLbl:SetTextColor(1, 1, 1)
    end)
    row:SetScript("OnLeave", function(self)
        -- Highlight active selection
        local cur = (PIorityDB and PIorityDB.soundKey) or "RAID_WARNING"
        if cur == opt.key then
            self:SetBackdropColor(P.accent[1] * 0.25, P.accent[2] * 0.25, P.accent[3] * 0.25, 0.6)
            rowLbl:SetTextColor(P.accent[1], P.accent[2], P.accent[3])
        else
            self:SetBackdropColor(P.bg[1], P.bg[2], P.bg[3], 0)
            rowLbl:SetTextColor(P.text[1], P.text[2], P.text[3])
        end
    end)
    row:SetScript("OnClick", function()
        if PIorityDB then PIorityDB.soundKey = opt.key end
        UpdateSoundDropLabel()
        soundPopup:Hide()
        PlaySoundOption(opt, UnitName("player"))
    end)
end

soundDropBtn:SetScript("OnClick", function()
    if soundPopup:IsShown() then
        soundPopup:Hide()
    else
        soundPopup:SetWidth(soundDropBtn:GetWidth())
        soundPopup:ClearAllPoints()
        soundPopup:SetPoint("TOPLEFT", soundDropBtn, "BOTTOMLEFT", 0, -2)
        soundPopup:Show()
        -- Refresh row highlight for current selection
        local cur = (PIorityDB and PIorityDB.soundKey) or "RAID_WARNING"
        for i, opt in ipairs(SOUND_OPTIONS) do
            local row = select(i, soundPopup:GetChildren())
            if row then
                if cur == opt.key then
                    row:SetBackdropColor(P.accent[1] * 0.25, P.accent[2] * 0.25, P.accent[3] * 0.25, 0.6)
                else
                    row:SetBackdropColor(P.bg[1], P.bg[2], P.bg[3], 0)
                end
            end
        end
    end
end)

-- Close popup when clicking elsewhere
optFrame:SetScript("OnHide", function() soundPopup:Hide() end)

-- Preview sound button anchored to the right edge of the settings window
local soundPreviewBtn = MakeFlatBtn(optFrame, ">", 24, 24)
soundPreviewBtn:SetPoint("TOPRIGHT", optFrame, "TOPRIGHT", -10, -(OPT_TOP + 68))
soundPreviewBtn:SetScript("OnClick", function()
    PlayPISound(UnitName("player"))
end)
soundPreviewBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(P.btnHov[1], P.btnHov[2], P.btnHov[3], P.btnHov[4])
    self:SetBackdropBorderColor(P.btnHBd[1], P.btnHBd[2], P.btnHBd[3], P.btnHBd[4])
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Preview sound", 1, 1, 1)
    GameTooltip:Show()
end)
soundPreviewBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(P.btnBg[1], P.btnBg[2], P.btnBg[3], P.btnBg[4])
    self:SetBackdropBorderColor(P.btnBd[1], P.btnBd[2], P.btnBd[3], P.btnBd[4])
    GameTooltip:Hide()
end)

-- Preview button: shows the PI request notification with the player's name + plays the sound
local previewBtn = MakeFlatBtn(optFrame, L.BTN_PREVIEW, nil, 22)
previewBtn:SetPoint("TOPLEFT",  optFrame, "TOPLEFT",  10, -(OPT_TOP + 100))
previewBtn:SetPoint("TOPRIGHT", optFrame, "TOPRIGHT", -10, -(OPT_TOP + 100))
AutoSizeBtn(previewBtn, 80, 24)
previewBtn:SetScript("OnClick", function() ShowPreviewWithSound() end)

-- Shared window position toggle (checked = one position for all characters)
local sharedPosCheck = CreateFrame("Button", nil, optFrame, "BackdropTemplate")
sharedPosCheck:SetSize(CHK, CHK)
sharedPosCheck:SetPoint("TOPLEFT", optFrame, "TOPLEFT", 10, -(OPT_TOP + 132))
ApplyFlatBg(sharedPosCheck, P.chkBg[1], P.chkBg[2], P.chkBg[3], P.chkBg[4],
                             P.chkBd[1], P.chkBd[2], P.chkBd[3], P.chkBd[4])

local sharedChkMark = sharedPosCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sharedChkMark:SetAllPoints()
sharedChkMark:SetJustifyH("CENTER")
sharedChkMark:SetJustifyV("MIDDLE")

local sharedChecked = true
function sharedPosCheck:SetChecked(v)
    sharedChecked = v
    if v then
        sharedChkMark:SetText("|cff33FF66v|r")
        sharedPosCheck:SetBackdropBorderColor(P.chkOn[1], P.chkOn[2], P.chkOn[3], P.chkOn[4])
    else
        sharedChkMark:SetText("")
        sharedPosCheck:SetBackdropBorderColor(P.chkBd[1], P.chkBd[2], P.chkBd[3], P.chkBd[4])
    end
end

local function OnSharedToggle()
    local v = not sharedChecked
    sharedPosCheck:SetChecked(v)
    PIorityDB.sharedLayout = v
    if v then
        -- Back to shared: snap both windows to the account-wide position.
        RestoreFrameLayout()
        RestoreOptLayout()
    else
        -- Per character from now on: seed this character's slots with the
        -- current on-screen positions so nothing jumps.
        SaveFrameLayout()
        SaveOptLayout()
    end
end
sharedPosCheck:SetScript("OnClick", OnSharedToggle)
sharedPosCheck:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.14, 0.14, 0.22, 0.95)
end)
sharedPosCheck:SetScript("OnLeave", function(self)
    self:SetBackdropColor(P.chkBg[1], P.chkBg[2], P.chkBg[3], P.chkBg[4])
end)

local sharedChkLabelBtn = CreateFrame("Button", nil, optFrame)
sharedChkLabelBtn:SetPoint("LEFT", sharedPosCheck, "RIGHT", 5, 0)
local sharedChkLabel = sharedChkLabelBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sharedChkLabel:SetAllPoints()
sharedChkLabel:SetTextColor(P.dim[1], P.dim[2], P.dim[3])
sharedChkLabel:SetText(L.CHK_SHARED_POS)
sharedChkLabelBtn:SetSize(sharedChkLabel:GetStringWidth() + 2, CHK)
sharedChkLabelBtn:SetScript("OnClick", OnSharedToggle)
sharedChkLabelBtn:SetScript("OnEnter", function() sharedChkLabel:SetTextColor(1, 0.95, 1) end)
sharedChkLabelBtn:SetScript("OnLeave", function() sharedChkLabel:SetTextColor(P.dim[1], P.dim[2], P.dim[3]) end)
C_Timer.After(0, function()
    sharedChkLabelBtn:SetWidth(math.max(10, sharedChkLabel:GetStringWidth() + 2))
end)

-------------------------------------------------------------------------------
-- Roster rows
-------------------------------------------------------------------------------

local rows = {}

local function MakeRow(index)
    local btn = CreateFrame("Button", nil, content)
    btn:SetHeight(ROW_H)
    btn:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -(index - 1) * ROW_H)
    btn:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(index - 1) * ROW_H)

    if index % 2 == 0 then
        local rowBg = btn:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints()
        rowBg:SetColorTexture(0, 0, 0, 0.12)
    end

    btn:SetHighlightTexture("Interface/Buttons/WHITE8X8")
    btn:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)

    local classIcon = btn:CreateTexture(nil, "ARTWORK")
    classIcon:SetSize(ROW_H - 4, ROW_H - 4)  -- 22x22 for ROW_H=26
    classIcon:SetPoint("LEFT", btn, "LEFT", 3, 0)
    btn.classIcon = classIcon

    -- Addon-presence indicator sits directly in front of the name (fixed slot
    -- so names stay column-aligned whether or not the player has PIority).
    local addonDot = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addonDot:SetPoint("LEFT", classIcon, "RIGHT", 4, 0)
    addonDot:SetWidth(20)
    addonDot:SetJustifyH("LEFT")
    btn.addonDot = addonDot

    local marker = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    marker:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    marker:SetWidth(10)
    marker:SetJustifyH("CENTER")
    btn.marker = marker

    local piGainText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    piGainText:SetPoint("RIGHT", marker, "LEFT", -2, 0)
    piGainText:SetWidth(44)
    piGainText:SetJustifyH("RIGHT")
    btn.piGainText = piGainText

    -- Name stretches to fill the space between the indicator and the PI gain.
    local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameText:SetPoint("LEFT",  addonDot,   "RIGHT", 2,  0)
    nameText:SetPoint("RIGHT", piGainText, "LEFT",  -4, 0)
    nameText:SetJustifyH("LEFT")
    btn.nameText = nameText

    -- Spec / character level / item level moved off the row into this tooltip
    -- to keep the list uncluttered. tipData is refreshed each layout pass.
    btn:SetScript("OnEnter", function(self)
        local d = self.tipData
        if not d then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(d.name, d.cr or 1, d.cg or 1, d.cb or 1)
        GameTooltip:AddDoubleLine("Spec",       d.spec,  P.dim[1], P.dim[2], P.dim[3], 1, 1, 1)
        GameTooltip:AddDoubleLine("Level",      d.level, P.dim[1], P.dim[2], P.dim[3], 1, 1, 1)
        GameTooltip:AddDoubleLine("Item Level", d.ilvl,  P.dim[1], P.dim[2], P.dim[3], 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnClick", function()
        if not btn.memberName then return end
        local profile = GetActiveProfile()
        if not profile then return end
        UpdateMacroTarget(profile, btn.memberName)
        SetLastTarget(btn.memberName)
        statusLabel:SetText(L.STATUS_TARGET .. "|cff00ff96" .. btn.memberName .. "|r")
        frame.Refresh()
    end)

    return btn
end

local function GetRow(i)
    if not rows[i] then rows[i] = MakeRow(i) end
    return rows[i]
end

function frame.Refresh()
    SyncContentWidth()
    local roster     = GetSortedRoster()
    local lastTarget = GetLastTarget()

    local inScreenshot = PIorityDB and PIorityDB.screenshotMode
    resetBtn:SetEnabled(not inScreenshot and lastTarget ~= nil)
    reInspectBtn:SetEnabled(not inScreenshot and GetNumGroupMembers() > 0)

    if lastTarget then
        statusLabel:SetText(L.STATUS_TARGET .. "|cff00ff96" .. lastTarget .. "|r")
    else
        statusLabel:SetText(L.STATUS_NONE)
    end

    for _, r in ipairs(rows) do r:Hide() end
    content:SetHeight(math.max(1, #roster * ROW_H))

    for i, entry in ipairs(roster) do
        local row = GetRow(i)
        row.memberName = entry.name

        local unit = GetUnitForName(entry.name)
        local _, classFile
        if unit then _, classFile = UnitClass(unit) end
        classFile = classFile or entry.classFile  -- fallback for screenshot roster
        local cc = classFile and RAID_CLASS_COLORS[classFile]
        if cc then
            row.nameText:SetTextColor(cc.r, cc.g, cc.b)
        else
            row.nameText:SetTextColor(1, 1, 1)
        end
        row.nameText:SetText(entry.name)

        local atlas = classFile and CLASS_ATLAS[classFile]
        if atlas then
            row.classIcon:SetAtlas(atlas)
            row.classIcon:SetAlpha(1)
        else
            row.classIcon:SetTexture(nil)
        end

        if addonUsers[entry.name] then
            row.addonDot:SetText("|cff00ff96[P]|r")
            row.addonDot:SetAlpha(1)
        else
            row.addonDot:SetText("")
        end

        -- Spec string for the hover tooltip. Greenish when the spec is ranked
        -- for PI (has a sim score); grey for tanks/healers and anything not ranked.
        local specStr
        if entry.specID then
            local ranked = IsRankableSpec(entry.specID) and entry.score ~= nil
            local sname  = SPEC_NAME[entry.specID] or ("Spec " .. entry.specID)
            specStr = ranked
                and ("|cff88bb88" .. sname .. "|r")
                or  ("|cff888888" .. sname .. "|r")
        else
            specStr = "|cff444455...|r"
        end

        -- Gear-normalized PI gain: the spec's %-gain scaled by the player's item
        -- level vs the group, so the shown number matches the ranking order.
        -- Falls back to the raw %-gain when unscored (e.g. screenshot roster).
        local gain = entry.score or entry.pipct
        row.piGainText:SetText(gain
            and ("|cff00ff96+%.1f%%|r"):format(gain)
            or  "|cff444455-|r")

        -- Level / item level now live in the tooltip built by the row OnEnter.
        row.tipData = {
            name  = entry.name,
            cr    = cc and cc.r, cg = cc and cc.g, cb = cc and cc.b,
            spec  = specStr,
            level = (entry.level and entry.level > 0) and tostring(entry.level) or "-",
            ilvl  = entry.ilvl and ("|cffffd700" .. entry.ilvl .. "|r") or "-",
        }

        row.marker:SetText(entry.name == lastTarget and "|cff00ff96>|r" or "")

        row:Show()
    end

    UpdateScrollThumb()
end

ResetPITarget = function()
    local profile = GetActiveProfile()
    if not profile then return end
    UpdateMacroTarget(profile, profile.resetTarget)
    SetLastTarget(nil)
    statusLabel:SetText(L.STATUS_NONE)
    frame.Refresh()
    print("|cff00ff96PIority:|r " .. L.MSG_RESET:format(profile.resetLabel))
end

TryAutopick = function()
    if not PIorityDB or not PIorityDB.autopick then return end
    local _, playerClass = UnitClass("player")
    if playerClass ~= "PRIEST" then return end
    if GetNumGroupMembers() == 0 then return end
    if #GetUnknownMembers() > 0 then return end
    local roster = GetSortedRoster()
    if #roster == 0 then return end
    local top = roster[1]
    -- Roster is sorted best-first by gear-normalized PI score. Never auto-target
    -- a tank/healer, even if they're the only ranked-looking entry.
    local topRanked = IsRankableSpec(top.specID) and top.score ~= nil
    if topRanked and GetLastTarget() ~= top.name then
        UpdateMacroTarget(CLASS_CONFIG.PRIEST, top.name)
        SetLastTarget(top.name)
        statusLabel:SetText(L.STATUS_AUTO .. "|cff00ff96" .. top.name .. "|r")
        frame.Refresh()
    end
end

-- A full 5-man party finished scanning (every member's spec resolved). Pop the
-- roster open so the player can pick the macro target. Fired once per scan from
-- ScheduleRetryIfNeeded, gated to real 5-man parties (not raids, not partial groups).
NotifyScanComplete = function()
    if IsInRaid() or GetNumGroupMembers() ~= 5 then return end
    frame.Refresh()
    if not frame:IsShown() then frame:Show() end
end

-- Hunter auto-pick: targets the first tank in the group. The solo case (own pet)
-- is covered by the leave-group reset, since @pet is the hunter macro's default.
-- Self-contained (checks the autopick setting and class on its own) so it's safe to call
-- from any event handler without needing the inspect/spec-cache machinery priests rely on.
local function TryAutopickHunter()
    if not PIorityDB or not PIorityDB.autopick then return end
    local _, playerClass = UnitClass("player")
    if playerClass ~= "HUNTER" then return end
    if GetNumGroupMembers() == 0 then return end

    local target = FindFirstTank()
    if target and GetLastTarget() ~= target then
        UpdateMacroTarget(CLASS_CONFIG.HUNTER, target)
        SetLastTarget(target)
        statusLabel:SetText(L.STATUS_AUTO .. "|cff00ff96" .. target .. "|r")
        frame.Refresh()
    end
end

-------------------------------------------------------------------------------
-- PI Request notification (priest side)
-------------------------------------------------------------------------------

local function CanCastPI()
    return IsSpellKnown(PI_SPELL_ID)
end

-- Ignore repeat requests inside this window so a requester spamming their
-- macro doesn't retrigger the popup and sound on the priest over and over.
local REQUEST_THROTTLE = 10  -- seconds; the popup itself lives for 8
local lastRequestAt = 0

notifFrame = CreateFrame("Frame", "PIorityNotif", UIParent, "BackdropTemplate")
notifFrame:SetSize(140, 170)
notifFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
notifFrame:SetFrameStrata("HIGH")
notifFrame:SetMovable(true)
notifFrame:SetDontSavePosition(true)
notifFrame:EnableMouse(true)
notifFrame:RegisterForDrag("LeftButton")
notifFrame:SetScript("OnDragStart", notifFrame.StartMoving)
notifFrame:SetScript("OnDragStop", function()
    notifFrame:StopMovingOrSizing()
    SaveNotifLayout()
end)
-- No background: notifFrame is intentionally transparent. Do NOT call ApplyFlatBg here.
notifFrame.isPreview = false
notifFrame:Hide()

local notifIcon = notifFrame:CreateTexture(nil, "ARTWORK")
notifIcon:SetSize(90, 90)
notifIcon:SetPoint("TOP", notifFrame, "TOP", 0, -10)
notifIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

-- Invisible frame over the icon used as the target for ActionButton proc glow.
local glowFrame = CreateFrame("Frame", nil, notifFrame)
glowFrame:SetSize(90, 90)
glowFrame:SetPoint("CENTER", notifIcon, "CENTER")

ns.glow.apply = function()
    if ActionButton_ShowOverlayGlow then ActionButton_ShowOverlayGlow(glowFrame) end
end

ns.glow.remove = function()
    if ActionButton_HideOverlayGlow then ActionButton_HideOverlayGlow(glowFrame) end
end

notifFrame:HookScript("OnHide", function() ns.glow.remove() end)

local iconShimmer = notifFrame:CreateTexture(nil, "OVERLAY")
iconShimmer:SetSize(90, 90)
iconShimmer:SetPoint("CENTER", notifIcon, "CENTER")
iconShimmer:SetTexture("Interface/Buttons/ButtonHilight-Square")
iconShimmer:SetBlendMode("ADD")
iconShimmer:SetVertexColor(1.0, 0.82, 0.0)

local shimAnim = iconShimmer:CreateAnimationGroup()
shimAnim:SetLooping("BOUNCE")
local sPulse = shimAnim:CreateAnimation("Alpha")
sPulse:SetFromAlpha(0.1)
sPulse:SetToAlpha(0.8)
sPulse:SetDuration(0.5)
shimAnim:Play()

local notifName = notifFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
notifName:SetPoint("TOP", notifIcon, "BOTTOM", 0, -10)
notifName:SetWidth(200)
notifName:SetJustifyH("CENTER")

local notifSub = notifFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
notifSub:SetPoint("TOP", notifName, "BOTTOM", 0, -4)
notifSub:SetTextColor(1.0, 0.82, 0.0)

local function ShowPIRequest(senderName)
    local iconPath = (C_Spell and C_Spell.GetSpellTexture) and C_Spell.GetSpellTexture(PI_SPELL_ID)
                     or GetSpellTexture(PI_SPELL_ID)
    if iconPath then notifIcon:SetTexture(iconPath) end
    notifSub:SetText(L.NOTIF_REQUESTS:format(GetSpellNameByID(PI_SPELL_ID) or "Power Infusion"))

    local unit = GetUnitForName(senderName)
    local _, classFile
    if unit then _, classFile = UnitClass(unit) end
    local cc = classFile and RAID_CLASS_COLORS[classFile]
    if cc then
        notifName:SetTextColor(cc.r, cc.g, cc.b)
    else
        notifName:SetTextColor(1, 1, 1)
    end
    notifName:SetText(senderName)

    notifFrame.requester = senderName
    notifFrame.isPreview = false
    notifFrame:Show()
    ns.glow.apply()

    if notifFrame.dismissTimer then notifFrame.dismissTimer:Cancel() end
    notifFrame.dismissTimer = C_Timer.NewTimer(8, function()
        notifFrame.dismissTimer = nil
        notifFrame.isPreview    = false
        notifFrame:Hide()
    end)

    PlayPISound(senderName)
end

ShowNotifPreview = function()
    local iconPath = (C_Spell and C_Spell.GetSpellTexture) and C_Spell.GetSpellTexture(PI_SPELL_ID)
                     or GetSpellTexture(PI_SPELL_ID)
    if iconPath then notifIcon:SetTexture(iconPath) end
    notifSub:SetText(L.NOTIF_REQUESTS:format(GetSpellNameByID(PI_SPELL_ID) or "Power Infusion"))
    notifName:SetTextColor(0.6, 0.6, 0.6)
    notifName:SetText(L.NOTIF_PREVIEW)
    notifFrame.requester = nil
    notifFrame.isPreview = true
    notifFrame:Show()
end

ShowPreviewWithSound = function()
    if notifFrame:IsShown() and notifFrame.isPreview then
        if notifFrame.dismissTimer then notifFrame.dismissTimer:Cancel() end
        notifFrame.dismissTimer = nil
        notifFrame.isPreview    = false
        notifFrame:Hide()
        return
    end

    local iconPath = (C_Spell and C_Spell.GetSpellTexture) and C_Spell.GetSpellTexture(PI_SPELL_ID)
                     or GetSpellTexture(PI_SPELL_ID)
    if iconPath then notifIcon:SetTexture(iconPath) end
    notifSub:SetText(L.NOTIF_REQUESTS:format(GetSpellNameByID(PI_SPELL_ID) or "Power Infusion"))

    local playerName = UnitName("player")
    local _, classFile = UnitClass("player")
    local cc = classFile and RAID_CLASS_COLORS[classFile]
    if cc then
        notifName:SetTextColor(cc.r, cc.g, cc.b)
    else
        notifName:SetTextColor(1, 1, 1)
    end
    notifName:SetText(playerName)

    notifFrame.requester = nil
    notifFrame.isPreview = true
    notifFrame:Show()
    ns.glow.apply()

    if notifFrame.dismissTimer then notifFrame.dismissTimer:Cancel() end
    notifFrame.dismissTimer = C_Timer.NewTimer(8, function()
        notifFrame.dismissTimer = nil
        notifFrame.isPreview    = false
        notifFrame:Hide()
    end)

    PlayPISound(playerName)
end

frame:HookScript("OnShow", function()
    if PIorityDB then PIorityDB.windowOpen = true end
end)

frame:HookScript("OnHide", function()
    if PIorityDB then PIorityDB.windowOpen = false end
    optFrame:Hide()
    if notifFrame.isPreview then
        notifFrame.isPreview = false
        notifFrame:Hide()
    end
end)

-------------------------------------------------------------------------------
-- PI Request sending (non-priest side or testing)
-------------------------------------------------------------------------------

local function SendPIRequest()
    local channel
    if IsInRaid()                         then channel = "RAID"
    elseif GetNumGroupMembers() > 0       then channel = "PARTY"
    end
    if not channel then return end
    C_ChatInfo.SendAddonMessage(MSG_PREFIX, MSG_REQUEST, channel)
end

-------------------------------------------------------------------------------
-- Bloodlust watch (hunter side)
-------------------------------------------------------------------------------
-- In a 5-man group with no Shaman/Mage/Evoker, lust duty falls to the hunter's
-- pet. Warn when the summoned pet isn't Ferocity and offer a secure button
-- that dismisses the current pet and then calls a Ferocity one from the call
-- slots ([nopet] conditional: first click dismisses, second click calls).

local LUST_CLASSES     = { SHAMAN = true, MAGE = true, EVOKER = true }
local FEROCITY_SPEC_ID = 74                   -- pet specs: 74 Ferocity, 79 Cunning, 81 Tenacity
local PRIMAL_RAGE_IDS  = { 272678, 264667 }   -- pet lust; fallback when spec info isn't ready
local DISMISS_PET_ID   = 2641
local CALL_PET_IDS     = { 883, 83242, 83243, 83244, 83245 }  -- Call Pet 1-5

local blTimer, blDismissed, blPendingRefresh
local blRetries  = 0
local blFeroSlot, blFeroName

local function HunterHasLustDuty()
    local _, playerClass = UnitClass("player")
    if playerClass ~= "HUNTER" then return false end
    -- Screenshot mode: pretend we're in a 5-man group with no other lust class.
    if PIorityDB and PIorityDB.screenshotMode then return true end
    if not IsInGroup() or IsInRaid() then return false end
    for i = 1, GetNumGroupMembers() - 1 do
        local _, classFile = UnitClass("party" .. i)
        if classFile and LUST_CLASSES[classFile] then return false end
    end
    return true
end

-- Returns true/false, or nil while the pet's spec info isn't available yet
-- (e.g. right after a loading screen).
local function PetCanLust()
    if not UnitExists("pet") then return false end
    local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    local specIndex = getSpec and getSpec(false, true)     -- isInspect=false, isPet=true
    local specID = specIndex and getInfo and getInfo(specIndex, false, true)
    if specID then return specID == FEROCITY_SPEC_ID end
    for _, id in ipairs(PRIMAL_RAGE_IDS) do
        if IsSpellKnown(id, true) then return true end
    end
    return nil
end

-- First call slot (1-5) holding a Ferocity pet, plus that pet's name.
local function FindFerocitySlot()
    if not (C_StableInfo and C_StableInfo.GetStablePetInfo) then return nil end
    for slot = 1, #CALL_PET_IDS do
        local info = C_StableInfo.GetStablePetInfo(slot)
        if info and info.specID == FEROCITY_SPEC_ID then
            return slot, info.name
        end
    end
end

local blFrame = CreateFrame("Frame", "PIorityBLWarn", UIParent, "BackdropTemplate")
blFrame:SetSize(270, 80)
blFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 220)
blFrame:SetFrameStrata("HIGH")
blFrame:SetMovable(true)
blFrame:SetDontSavePosition(true)
blFrame:SetClampedToScreen(true)
blFrame:EnableMouse(true)
blFrame:RegisterForDrag("LeftButton")
blFrame:SetScript("OnDragStart", blFrame.StartMoving)
blFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if not PIorityDB then return end
    local point, _, relPoint, x, y = self:GetPoint()
    PIorityDB.blLayout = { point = point, relPoint = relPoint, x = x, y = y }
end)
ApplyFlatBg(blFrame, P.bg[1], P.bg[2], P.bg[3], P.bg[4], 0.75, 0.25, 0.25, 1)
blFrame:Hide()

local function RestoreBLLayout()
    local l = PIorityDB and PIorityDB.blLayout
    if l then
        blFrame:ClearAllPoints()
        blFrame:SetPoint(l.point, UIParent, l.relPoint, l.x, l.y)
    end
end

local blIcon = blFrame:CreateTexture(nil, "ARTWORK")
blIcon:SetSize(30, 30)
blIcon:SetPoint("TOPLEFT", blFrame, "TOPLEFT", 10, -10)
blIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
C_Timer.After(0, function()
    local iconPath = (C_Spell and C_Spell.GetSpellTexture) and C_Spell.GetSpellTexture(PRIMAL_RAGE_IDS[1])
                     or GetSpellTexture(PRIMAL_RAGE_IDS[1])
    if iconPath then blIcon:SetTexture(iconPath) end
end)

local blTitle = blFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
blTitle:SetPoint("TOPLEFT", blIcon, "TOPRIGHT", 8, -1)
blTitle:SetPoint("RIGHT", blFrame, "RIGHT", -26, 0)
blTitle:SetJustifyH("LEFT")
blTitle:SetTextColor(1.0, 0.35, 0.30)
blTitle:SetText(L.BL_WARN_TITLE)

local blSub = blFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
blSub:SetPoint("TOPLEFT", blTitle, "BOTTOMLEFT", 0, -3)
blSub:SetPoint("RIGHT", blFrame, "RIGHT", -10, 0)
blSub:SetJustifyH("LEFT")
blSub:SetTextColor(P.dim[1], P.dim[2], P.dim[3])

local blClose = CreateFrame("Button", nil, blFrame)
blClose:SetSize(18, 18)
blClose:SetPoint("TOPRIGHT", blFrame, "TOPRIGHT", -4, -4)
local blCloseLbl = blClose:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
blCloseLbl:SetAllPoints()
blCloseLbl:SetJustifyH("CENTER")
blCloseLbl:SetText("x")
blCloseLbl:SetTextColor(0.55, 0.45, 0.70)
blClose:SetScript("OnEnter", function() blCloseLbl:SetTextColor(1, 0.35, 0.35) end)
blClose:SetScript("OnLeave", function() blCloseLbl:SetTextColor(0.55, 0.45, 0.70) end)
blClose:SetScript("OnClick", function()
    blDismissed = true
    blFrame:Hide()
end)

-- Secure button: needs SecureActionButtonTemplate, so it can't come from
-- MakeFlatBtn — styled here to match.
local blSwapBtn = CreateFrame("Button", "PIorityBLSwapBtn", blFrame,
                              "SecureActionButtonTemplate, BackdropTemplate")
blSwapBtn:SetSize(140, 22)
blSwapBtn:SetPoint("BOTTOM", blFrame, "BOTTOM", 0, 8)
blSwapBtn:RegisterForClicks("AnyDown")
blSwapBtn:SetAttribute("type", "macro")
ApplyFlatBg(blSwapBtn, P.btnBg[1], P.btnBg[2], P.btnBg[3], P.btnBg[4],
                       P.btnBd[1], P.btnBd[2], P.btnBd[3], P.btnBd[4])
local blSwapLbl = blSwapBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
blSwapLbl:SetAllPoints()
blSwapLbl:SetJustifyH("CENTER")
blSwapLbl:SetTextColor(P.text[1], P.text[2], P.text[3])
blSwapBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(P.btnHov[1], P.btnHov[2], P.btnHov[3], P.btnHov[4])
    self:SetBackdropBorderColor(P.btnHBd[1], P.btnHBd[2], P.btnHBd[3], P.btnHBd[4])
    blSwapLbl:SetTextColor(1, 1, 1)
    if self.tipText then
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.tipText, 1, 1, 1, true)
        GameTooltip:Show()
    end
end)
blSwapBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(P.btnBg[1], P.btnBg[2], P.btnBg[3], P.btnBg[4])
    self:SetBackdropBorderColor(P.btnBd[1], P.btnBd[2], P.btnBd[3], P.btnBd[4])
    blSwapLbl:SetTextColor(P.text[1], P.text[2], P.text[3])
    GameTooltip:Hide()
end)

local ScheduleBLCheck  -- forward-declared for the retry below

local function RefreshBLWarning()
    -- Secure attributes and protected-button visibility can't change in combat;
    -- defer the whole refresh to PLAYER_REGEN_ENABLED.
    if InCombatLockdown() then blPendingRefresh = true; return end
    blPendingRefresh = false

    local duty = HunterHasLustDuty()
    local canLust = duty and PetCanLust()
    if not duty or canLust == true then
        blDismissed = false
        blFrame:Hide()
        return
    end
    if canLust == nil then
        blRetries = blRetries + 1
        if blRetries <= 5 then ScheduleBLCheck() end
        return
    end
    blRetries = 0
    if blDismissed then return end

    blFeroSlot, blFeroName = FindFerocitySlot()
    local hasPet = UnitExists("pet")

    if blFeroSlot then
        blSub:SetText(hasPet and L.BL_WARN_WRONG_PET or L.BL_WARN_NO_PET)
        local callName    = GetSpellNameByID(CALL_PET_IDS[blFeroSlot])
        local dismissName = GetSpellNameByID(DISMISS_PET_ID)
        if callName and dismissName then
            blSwapBtn:SetAttribute("macrotext",
                ("/cast [nopet] %s; %s"):format(callName, dismissName))
            blSwapLbl:SetText(hasPet and L.BL_BTN_DISMISS
                              or L.BL_BTN_CALL:format(blFeroName or callName))
            blSwapBtn:SetWidth(math.max(90, blSwapLbl:GetStringWidth() + 22))
            blSwapBtn.tipText = hasPet and L.BL_TIP:format(blFeroName or callName) or nil
            blSwapBtn:Show()
        else
            blSwapBtn:Hide()
        end
    else
        blSub:SetText(L.BL_WARN_NO_FERO)
        blSwapBtn:Hide()
    end

    if not blFrame:IsShown() then
        blFrame:Show()
        PlayPISound()
    end
end

ScheduleBLCheck = function()
    local _, playerClass = UnitClass("player")
    if playerClass ~= "HUNTER" then return end
    if blTimer then blTimer:Cancel() end
    blTimer = C_Timer.NewTimer(1, function()
        blTimer = nil
        RefreshBLWarning()
    end)
end

-------------------------------------------------------------------------------
-- Minimap button
-------------------------------------------------------------------------------

local minimapBtn = (function()
    local RADIUS = 80  -- distance from minimap centre

    local btn = CreateFrame("Button", "PIorityMinimapBtn", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)

    -- Circular mask
    local mask = btn:CreateMaskTexture()
    mask:SetAllPoints()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
                    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints()
    icon:AddMaskTexture(mask)
    btn.icon = icon

    -- Highlight ring
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Border ring
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("CENTER")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local function UpdatePosition(angle)
        local rad = math.rad(angle)
        btn:SetPoint("CENTER", Minimap, "CENTER",
            RADIUS * math.cos(rad),
            RADIUS * math.sin(rad))
    end

    -- Drag to reposition
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local cx, cy = Minimap:GetCenter()
            local mx, my = GetCursorPosition()
            local scale  = Minimap:GetEffectiveScale()
            local angle  = math.deg(math.atan2((my / scale - cy), (mx / scale - cx)))
            if PIorityDB then PIorityDB.minimapAngle = angle end
            UpdatePosition(angle)
        end)
    end)
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if frame:IsShown() then
                frame:Hide()
            else
                CachePlayerSpec()
                frame.Refresh()
                frame:Show()
            end
        elseif button == "RightButton" then
            if optFrame:IsShown() then
                optFrame:Hide()
            else
                optFrame:Show()
            end
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff8552ebPI|r|cffFFDC6Bority|r")
        GameTooltip:AddLine("|cffAAAAAALeft-click|r to toggle roster", 1, 1, 1)
        GameTooltip:AddLine("|cffAAAAAARight-click|r to toggle settings", 1, 1, 1)
        GameTooltip:AddLine("|cffAAAAAADrag|r to reposition", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    function btn.Init()
        local angle = (PIorityDB and PIorityDB.minimapAngle) or 225
        UpdatePosition(angle)
        -- Set the active class macro's spell icon (texture available after login)
        local spellID = (GetActiveProfile() or CLASS_CONFIG.PRIEST).spellID
        local iconPath = (C_Spell and C_Spell.GetSpellTexture) and C_Spell.GetSpellTexture(spellID)
                         or GetSpellTexture(spellID)
        if iconPath then icon:SetTexture(iconPath) end
    end

    return btn
end)()

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("INSPECT_READY")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local arg1, arg2, arg3, arg4 = ...
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        PIorityDB = PIorityDB or {}
        if PIorityDB.priority then PIorityDB.priority = nil end
        -- Legacy account-wide target: dropped in favor of per-character charTargets.
        -- The macro still holds the value, so PLAYER_LOGIN re-seeds it from there.
        if PIorityDB.lastTarget then PIorityDB.lastTarget = nil end

        -- Screenshot mode: force English and re-apply text to widgets already created.
        if PIorityDB.screenshotMode then
            ApplyEnglishLocale()
            reInspectBtn.label:SetText(L.BTN_REINSPECT)
            AutoSizeBtn(reInspectBtn)
            notifToggleBtn.label:SetText(L.BTN_ALERT_POS)
            AutoSizeBtn(notifToggleBtn)
            resetBtn.label:SetText(L.BTN_RESET)
            AutoSizeBtn(resetBtn)
            chkLabel:SetText(L.CHK_AUTOPICK)
            C_Timer.After(0, function()
                chkLabelBtn:SetWidth(math.max(10, chkLabel:GetStringWidth() + 2))
            end)
            sharedChkLabel:SetText(L.CHK_SHARED_POS)
            C_Timer.After(0, function()
                sharedChkLabelBtn:SetWidth(math.max(10, sharedChkLabel:GetStringWidth() + 2))
            end)
            blTitle:SetText(L.BL_WARN_TITLE)
            statusLabel:SetText(L.STATUS_NONE)
        end

        -- Redirect caches to persisted subtables so writes survive reloads.
        PIorityDB.specCache = PIorityDB.specCache or {}
        PIorityDB.ilvlCache = PIorityDB.ilvlCache or {}
        specCache = PIorityDB.specCache
        ilvlCache = PIorityDB.ilvlCache

        -- Defaults for new settings
        if PIorityDB.soundKey == nil then PIorityDB.soundKey = "RAID_WARNING" end

        -- Drop entries for players not in the current group (stale data from last session).
        PruneCacheToGroup()

        -- One-time seeding (backwards compatibility): the first character that
        -- logs in with shared positions enabled defines the account-wide
        -- position for all others. Its own layout wins — promote any
        -- per-character layout this character may have over the shared slots.
        if not PIorityDB.sharedLayoutSeeded and PIorityDB.sharedLayout ~= false then
            local mine = PIorityDB.charLayouts and PIorityDB.charLayouts[CharKey()]
            if mine then
                if mine.layout    then PIorityDB.layout    = mine.layout end
                if mine.optLayout then PIorityDB.optLayout = mine.optLayout end
            end
            PIorityDB.sharedLayoutSeeded = true
        end

        RestoreFrameLayout()
        RestoreOptLayout()
        RestoreNotifLayout()
        RestoreBLLayout()
        autopickCheck:SetChecked(PIorityDB.autopick and true or false)
        sharedPosCheck:SetChecked(PIorityDB.sharedLayout ~= false)
        UpdateSoundDropLabel()

        -- The alert-position button configures the PI request notification,
        -- which only priests ever receive — disable it (with the dimmed flat-button
        -- style) for everyone else. Screenshot mode keeps the full UI enabled.
        local _, playerClass = UnitClass("player")
        if playerClass ~= "PRIEST" and not PIorityDB.screenshotMode then
            notifToggleBtn:SetEnabled(false)
            priestOnlyLabel:Show()
        end

        -- Bloodlust watch only matters for hunters; skip the event traffic otherwise.
        if playerClass == "HUNTER" then
            eventFrame:RegisterUnitEvent("UNIT_PET", "player")
            eventFrame:RegisterEvent("PET_STABLE_UPDATE")
            eventFrame:RegisterEvent("SPELLS_CHANGED")
            eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
        print("|cff00ff96" .. L.TITLE .. "|r " .. L.MSG_LOADED:format(PrimarySlash()))

    elseif event == "PLAYER_LOGIN" then
        -- WoW's per-character layout cache (layout-local.txt) restores named
        -- user-placed frames after ADDON_LOADED, stomping the positions applied
        -- there. Re-apply ours on top so PIorityDB always wins; together with
        -- SetDontSavePosition this also neutralizes stale cache entries left
        -- behind by older versions.
        RestoreFrameLayout()
        RestoreOptLayout()
        RestoreNotifLayout()
        RestoreBLLayout()
        C_ChatInfo.RegisterAddonMessagePrefix(MSG_PREFIX)
        -- Macro list is ready at this point, safe to create if missing.
        local profile = GetActiveProfile()
        if profile and GetMacroIndexByName(profile.macroName) == 0 then
            local idx = CreateClassMacro(profile, BuildResetMacroBody(profile))
            if idx and idx > 0 then
                print("|cff00ff96PIority:|r " .. L.MSG_MACRO_CREATED:format(profile.macroName))
            else
                print("|cffff4444PIority:|r " .. L.MSG_MACRO_LIMIT:format(profile.macroName))
            end
        end
        -- Warm the macro-target cache while out of combat, so the PI request
        -- popup still resolves the current target during the first fight even
        -- if the priest never touches the UI (GetMacroBody is nil in combat).
        if profile then GetMacroTarget(profile) end
        -- No saved target for this character: adopt whatever the macro currently
        -- targets (covers upgrades from the old account-wide setting and manual edits).
        if profile and GetLastTarget() == nil then
            local current = GetMacroTarget(profile)
            if current and current ~= profile.resetTarget then
                SetLastTarget(current)
            end
        end
        -- In screenshot mode open the window automatically with fake data.
        if PIorityDB and PIorityDB.screenshotMode then
            frame.Refresh()
            frame:Show()
            print("|cff00ff96PIority:|r |cffffff00[Screenshot mode active]|r  /pi screenshot off to exit")
        else
            -- Announce to any existing group members that this addon is loaded.
            ScheduleAnnounce()
            -- Reopen the window if it was open before the last reload/logout.
            if PIorityDB and PIorityDB.windowOpen then
                CachePlayerSpec()
                frame.Refresh()
                frame:Show()
            end
        end
        minimapBtn.Init()

    elseif event == "PLAYER_ENTERING_WORLD" then
        CachePlayerSpec()
        QueueInspects()
        TryAutopickHunter()
        ScheduleBLCheck()

    elseif event == "GROUP_ROSTER_UPDATE" then
        PruneCacheToGroup()
        CachePlayerSpec()
        QueueInspects()
        ScheduleAnnounce()
        -- Left the group: return the macro to its class default (@player / @pet).
        if GetNumGroupMembers() == 0 and GetLastTarget() then
            ResetPITarget()
        end
        TryAutopickHunter()
        -- Group composition changed: a previously dismissed BL warning may apply again.
        blDismissed = false
        ScheduleBLCheck()
        local inGroup = GetNumGroupMembers() > 0
        if frame:IsShown() then
            frame.Refresh()
        elseif inGroup and not frame:IsShown() then
            -- Only auto-open for priests who have no current group target assigned.
            local _, playerClass = UnitClass("player")
            local lastTarget = GetLastTarget()
            local targetStillInGroup = lastTarget and GetUnitForName(lastTarget) ~= nil
            if playerClass == "PRIEST" and not targetStillInGroup then
                frame.Refresh()
                frame:Show()
            end
        end

    elseif event == "INSPECT_READY" then
        local guid = arg1
        local numMembers = GetNumGroupMembers()
        local prefix = IsInRaid() and "raid" or "party"
        for i = 1, numMembers do
            local unit = prefix .. i
            if UnitGUID(unit) == guid then
                local name = UnitName(unit)
                if name then
                    local specID = GetInspectSpecialization(unit)
                    if specID and specID ~= 0 then
                        specCache[name] = specID
                    end
                    local ilvl = CalcUnitIlvl(unit)
                    if ilvl then ilvlCache[name] = ilvl end
                end
                break
            end
        end
        if frame:IsShown() then frame.Refresh() end

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        CachePlayerSpec()
        if frame:IsShown() then frame.Refresh() end

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        CachePlayerIlvl()
        if frame:IsShown() then frame.Refresh() end

    elseif event == "CHAT_MSG_ADDON" then
        -- arg1=prefix, arg2=message, arg3=channel, arg4=sender
        if arg1 ~= MSG_PREFIX then return end
        local senderName = arg4 and (arg4:match("^([^%-]+)") or arg4)
        if not senderName or senderName == UnitName("player") then return end

        if arg2 == MSG_REQUEST and CanCastPI() and senderName == GetMacroTarget(CLASS_CONFIG.PRIEST) then
            if GetTime() - lastRequestAt >= REQUEST_THROTTLE then
                lastRequestAt = GetTime()
                ShowPIRequest(senderName)
            end
        elseif arg2 == MSG_ANNOUNCE then
            addonUsers[senderName] = true
            if frame:IsShown() then frame.Refresh() end
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- arg1=unitToken, arg2=castGUID, arg3=spellID
        if arg1 == "player" and arg3 == PI_SPELL_ID then
            if notifFrame:IsShown() and not notifFrame.isPreview then
                if notifFrame.dismissTimer then
                    notifFrame.dismissTimer:Cancel()
                    notifFrame.dismissTimer = nil
                end
                notifFrame:Hide()
            end
        end

    elseif event == "UNIT_PET" or event == "PET_STABLE_UPDATE" or event == "SPELLS_CHANGED" then
        ScheduleBLCheck()

    elseif event == "PLAYER_REGEN_ENABLED" then
        if blPendingRefresh then RefreshBLWarning() end
    end
end)

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------
-- /pi           -> toggle window
-- /pi target N  -> update macro target directly
-- /pi help      -> print usage

-- /pirequest: any group member can call this (e.g. from a macro) to alert the priest.
SLASH_PIREQUEST1 = "/pirequest"
SlashCmdList["PIREQUEST"] = function() SendPIRequest() end

SLASH_PIH1 = "/pi"
SLASH_PIH2 = "/md"
SlashCmdList["PIH"] = function(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.*)")
    cmd = (cmd or ""):lower()

    if cmd == "screenshot" then
        if rest:lower() == "off" then
            PIorityDB.screenshotMode = nil
            print("|cff00ff96PIority:|r Screenshot mode disabled. Reloading UI...")
            ReloadUI()
        elseif not (PIorityDB and PIorityDB.screenshotMode) then
            PIorityDB = PIorityDB or {}
            PIorityDB.screenshotMode = true
            print("|cff00ff96PIority:|r Screenshot mode enabled. Reloading UI...")
            ReloadUI()
        else
            print("|cff00ff96PIority:|r Already in screenshot mode. Use |cffffff00/pi screenshot off|r to exit.")
        end
    elseif cmd == "target" then
        local name = rest:match("%S+")
        local profile = GetActiveProfile()
        if not profile then
            print("|cffff4444PIority:|r " .. L.MSG_NO_CLASS_MACRO)
        elseif name then
            UpdateMacroTarget(profile, name)
            SetLastTarget(name)
            frame.Refresh()
        else
            print("|cffff4444PIority:|r " .. L.MSG_USAGE_TARGET:format(PrimarySlash()))
        end
    elseif cmd == "help" then
        local slash = PrimarySlash()
        print("|cff00ff96" .. L.HELP_HEADER .. "|r")
        print(L.HELP_TOGGLE:format(slash))
        print(L.HELP_TARGET:format(slash))
        print(L.HELP_HELP:format(slash))
    else
        if frame:IsShown() then
            frame:Hide()
        else
            CachePlayerSpec()
            frame.Refresh()
            frame:Show()
        end
    end
end
