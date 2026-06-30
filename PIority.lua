-- PIority: assign a Power Infusion macro target from a group/raid list.
-- Sorts players by spec priority; click a row to update the PI_H macro.

local _, ns = ...
local L = ns.L

local ADDON_NAME    = "PIority"
local MACRO_NAME    = "PI_H"
local PI_SPELL_ID   = 10060
local MSG_PREFIX    = "PIority"
local MSG_REQUEST   = "REQUEST"
local MSG_ANNOUNCE  = "ANNOUNCE"

-- Returns the client-localized name of Power Infusion.
-- Prefers the newer C_Spell API (11.0+) with a fallback to GetSpellInfo.
local function GetPISpellName()
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(PI_SPELL_ID)
    end
    return (GetSpellInfo(PI_SPELL_ID))  -- extra () drops extra return values
end

local function BuildMacroBody(targetName)
    local spell = GetPISpellName() or "Power Infusion"
    return string.format("#showtooltip %s\n/cast [@%s,exists,nodead][@focus][] %s", spell, targetName, spell)
end

local function BuildResetMacroBody()
    return BuildMacroBody("focus")
end

-------------------------------------------------------------------------------
-- Spec priority (lower number = higher priority).
-------------------------------------------------------------------------------
local SPEC_PRIORITY = {
    [63]   = 1,   -- Fire Mage
    [266]  = 2,   -- Demonology Warlock
    [269]  = 3,   -- Windwalker Monk
    [255]  = 4,   -- Survival Hunter
    [263]  = 5,   -- Enhancement Shaman
    [62]   = 6,   -- Arcane Mage
    [254]  = 7,   -- Marksmanship Hunter
    [262]  = 8,   -- Elemental Shaman
    [1467] = 9,   -- Devastation Evoker
    [258]  = 10,  -- Shadow Priest
    [102]  = 11,  -- Balance Druid
    [1480] = 12,  -- Devourer Demon Hunter
    [103]  = 13,  -- Feral Druid
    [265]  = 14,  -- Affliction Warlock
    [70]   = 15,  -- Retribution Paladin
    [104]  = 16,  -- Guardian Druid
    [251]  = 17,  -- Frost Death Knight
    [252]  = 18,  -- Unholy Death Knight
    [577]  = 19,  -- Havoc Demon Hunter
    [261]  = 20,  -- Subtlety Rogue
    [253]  = 21,  -- Beast Mastery Hunter
    [64]   = 22,  -- Frost Mage
    [581]  = 23,  -- Vengeance Demon Hunter
    [66]   = 24,  -- Protection Paladin
    [71]   = 25,  -- Arms Warrior
    [250]  = 26,  -- Blood Death Knight
    [72]   = 27,  -- Fury Warrior
    [73]   = 28,  -- Protection Warrior
    [267]  = 29,  -- Destruction Warlock
    [260]  = 30,  -- Outlaw Rogue
    [259]  = 31,  -- Assassination Rogue
    [268]  = 32,  -- Brewmaster Monk
}

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

local SCREENSHOT_ROSTER = {
    { name = "DemoAlpha",   specID = 63,  classFile = "MAGE",        level = 80, ilvl = 290 },
    { name = "DemoBravo",   specID = 266, classFile = "WARLOCK",     level = 80, ilvl = 290 },
    { name = "DemoCharlie", specID = 258, classFile = "PRIEST",      level = 80, ilvl = 290 },
    { name = "DemoDelta",   specID = 251, classFile = "DEATHKNIGHT", level = 80, ilvl = 290 },
}

local ENGLISH_STRINGS = {
    BTN_OPTIONS         = "Options",
    BTN_REINSPECT       = "Re-inspect",
    BTN_ALERT_POS       = "Alert pos",
    BTN_RESET           = "Reset",
    CHK_AUTOPICK        = "Auto-pick",
    STATUS_NONE         = "No target selected",
    STATUS_TARGET       = "Target: ",
    STATUS_AUTO         = "Auto: ",
    NOTIF_REQUESTS      = "requests %s",
    NOTIF_PREVIEW       = "(preview)",
    HELP_HEADER         = "PIority commands:",
    HELP_TOGGLE         = "  /pi            - toggle roster window",
    HELP_TARGET         = "  /pi target N   - update macro target directly",
    HELP_HELP           = "  /pi help       - this message",
    MSG_LOADED          = "loaded. Type |cffffff00/pi|r to open.",
    MSG_MACRO_CREATED   = "Macro '%s' created.",
    MSG_MACRO_LIMIT     = "Could not create macro '%s' - you may be at the macro limit.",
    MSG_MACRO_UPDATED   = "Macro '%s' -> %s",
    MSG_MACRO_NOT_FOUND = "Could not find the /cast [@...] line in '%s'. Update manually.",
    MSG_MACRO_TARGETING = "Created macro '%s' targeting %s",
    MSG_RESET           = "Target reset to @focus.",
    MSG_REINSPECTING    = "Re-inspecting all members...",
    MSG_PI_REQUESTED    = "PI requested.",
    MSG_NOT_IN_GROUP    = "You must be in a group to request PI.",
    MSG_USAGE_TARGET    = "Usage: /pi target <name>",
}

local function ApplyEnglishLocale()
    for k, v in pairs(ENGLISH_STRINGS) do L[k] = v end
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

local TryAutopick  -- defined after UI elements are in scope

local function ScheduleRetryIfNeeded()
    if retryTimer then retryTimer:Cancel() end
    local unknown = GetUnknownMembers()
    if #unknown == 0 then
        TryAutopick()
        return
    end
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
-- Macro helpers
-------------------------------------------------------------------------------

local function GetMacroTarget()
    local body = GetMacroBody(MACRO_NAME)
    if not body then return nil end
    return body:match("/cast %[@([^,]+),exists,nodead%]")
end

-- Always create in the player (per-character) tab, never global, so each priest
-- can have their own PI target without stomping other characters' macros.
local function CreatePIMacro(body)
    return CreateMacro(MACRO_NAME, "INV_Misc_QuestionMark", body, true)
end

local function EnsureMacroExists(targetName)
    if GetMacroIndexByName(MACRO_NAME) == 0 then
        CreatePIMacro(BuildMacroBody(targetName))
        print("|cff00ff96PIority:|r " .. L.MSG_MACRO_TARGETING:format(MACRO_NAME, targetName))
    end
end

local function UpdateMacroTarget(targetName)
    EnsureMacroExists(targetName)
    local body = GetMacroBody(MACRO_NAME)
    if not body then return end

    -- Pattern matches any spell name after the conditional so it works in all locales.
    local newBody, n = body:gsub(
        "(/cast %[@)([^,]+)(,exists,nodead%]%[@focus%]%[%] [^\n]+)",
        "%1" .. targetName .. "%3",
        1
    )
    if n == 0 then
        print("|cffff4444PIority:|r " .. L.MSG_MACRO_NOT_FOUND:format(MACRO_NAME))
        return
    end

    EditMacro(MACRO_NAME, MACRO_NAME, nil, newBody)
    print("|cff00ff96PIority:|r " .. L.MSG_MACRO_UPDATED:format(MACRO_NAME, targetName))
end

local ResetPITarget  -- defined after UI elements are in scope

-------------------------------------------------------------------------------
-- Roster building
-------------------------------------------------------------------------------

local function GetSortedRoster()
    if PIorityDB and PIorityDB.screenshotMode then
        return SCREENSHOT_ROSTER
    end

    local numMembers = GetNumGroupMembers()
    local members = {}

    local selfName = UnitName("player")
    if numMembers == 0 then
        -- Solo: nothing to show (priest is excluded from own list)
    else
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

    table.sort(members, function(a, b)
        local pa = a.specID and SPEC_PRIORITY[a.specID]
        local pb = b.specID and SPEC_PRIORITY[b.specID]
        if pa and pb then return pa < pb end
        if pa then return true end   -- known spec beats unknown
        if pb then return false end
        return a.name < b.name      -- both unknown: alphabetical
    end)

    return members
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
    { key = "NONE",          labelKey = "SOUND_NONE",          kit = nil                             },
}

local function GetSoundLabel(key)
    for _, opt in ipairs(SOUND_OPTIONS) do
        if opt.key == key then return L[opt.labelKey] end
    end
    return L.SOUND_RAID_WARNING
end

local function PlayPISound()
    if not PIorityDB then return end
    local key = PIorityDB.soundKey or "RAID_WARNING"
    for _, opt in ipairs(SOUND_OPTIONS) do
        if opt.key == key then
            if opt.kit then PlaySound(opt.kit) end
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

local function SaveFrameLayout()
    local point, _, relPoint, x, y = frame:GetPoint()
    PIorityDB.layout = {
        point    = point,
        relPoint = relPoint,
        x        = x,
        y        = y,
        width    = frame:GetWidth(),
        height   = frame:GetHeight(),
    }
end

local function RestoreFrameLayout()
    local l = PIorityDB.layout
    if l then
        frame:ClearAllPoints()
        frame:SetPoint(l.point, UIParent, l.relPoint, l.x, l.y)
        frame:SetSize(
            math.max(200, l.width  or 290),
            math.max(150, l.height or 420)
        )
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
    local iconPath = (C_Spell and C_Spell.GetSpellTexture) and C_Spell.GetSpellTexture(PI_SPELL_ID)
                     or GetSpellTexture(PI_SPELL_ID)
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
optFrame:SetSize(310, 168)
optFrame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 6, 0)
optFrame:SetMovable(true)
optFrame:SetClampedToScreen(true)
optFrame:EnableMouse(true)
optFrame:RegisterForDrag("LeftButton")
optFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
optFrame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
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
optHeader:SetScript("OnDragStop",  function() optFrame:StopMovingOrSizing() end)
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
        if opt.kit then PlaySound(opt.kit) end
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
    PlayPISound()
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

    local rank = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rank:SetPoint("LEFT", classIcon, "RIGHT", 3, 0)
    rank:SetWidth(16)
    rank:SetJustifyH("RIGHT")
    btn.rankText = rank

    local addonDot = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addonDot:SetPoint("LEFT", rank, "RIGHT", 2, 0)
    addonDot:SetWidth(22)
    addonDot:SetJustifyH("LEFT")
    btn.addonDot = addonDot

    local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameText:SetPoint("LEFT", addonDot, "RIGHT", 2, 0)
    nameText:SetWidth(90)  -- default; overwritten each Refresh
    nameText:SetJustifyH("LEFT")
    btn.nameText = nameText

    local ilvlText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ilvlText:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    ilvlText:SetWidth(30)
    ilvlText:SetJustifyH("RIGHT")
    btn.ilvlText = ilvlText

    local marker = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    marker:SetPoint("RIGHT", ilvlText, "LEFT", -2, 0)
    marker:SetWidth(10)
    btn.marker = marker

    local levelText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    levelText:SetPoint("RIGHT", marker, "LEFT", -4, 0)
    levelText:SetWidth(22)
    levelText:SetJustifyH("RIGHT")
    btn.levelText = levelText

    local specText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    specText:SetPoint("LEFT",  nameText,  "RIGHT", 4,  0)
    specText:SetPoint("RIGHT", levelText, "LEFT",  -4, 0)
    specText:SetJustifyH("LEFT")
    specText:SetTextColor(P.dim[1], P.dim[2], P.dim[3])
    btn.specText = specText

    btn:SetScript("OnClick", function()
        if not btn.memberName then return end
        UpdateMacroTarget(btn.memberName)
        PIorityDB.lastTarget = btn.memberName
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
    local lastTarget = PIorityDB and PIorityDB.lastTarget

    -- Name column: 50% of the space not consumed by fixed columns, min 90px.
    -- Fixed left (icon+rank+dot+gaps)=70, fixed right (ilvl+marker+level+gaps)=78, total=148.
    local nameWidth = math.max(90, math.floor((scrollFrame:GetWidth() - 148) * 0.50))

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
        row.nameText:SetWidth(nameWidth)

        row.rankText:SetText("|cff555566" .. i .. ".|r")

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

        if entry.specID then
            local prio  = SPEC_PRIORITY[entry.specID]
            local sname = SPEC_NAME[entry.specID] or ("Spec " .. entry.specID)
            row.specText:SetText(prio
                and ("|cff88bb88" .. sname .. "|r")
                or  ("|cff888888" .. sname .. "|r"))
        else
            row.specText:SetText("|cff444455...|r")
        end

        row.levelText:SetText((entry.level and entry.level > 0)
            and ("|cff999999" .. entry.level .. "|r")
            or  "|cff444455-|r")

        row.ilvlText:SetText(entry.ilvl
            and ("|cffffd700" .. entry.ilvl .. "|r")
            or  "|cff444455-|r")

        row.marker:SetText(entry.name == lastTarget and "|cff00ff96>|r" or "")

        row:Show()
    end

    UpdateScrollThumb()
end

ResetPITarget = function()
    UpdateMacroTarget("focus")
    PIorityDB.lastTarget = nil
    statusLabel:SetText(L.STATUS_NONE)
    frame.Refresh()
    print("|cff00ff96PIority:|r " .. L.MSG_RESET)
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
    if top.specID and SPEC_PRIORITY[top.specID] and PIorityDB.lastTarget ~= top.name then
        UpdateMacroTarget(top.name)
        PIorityDB.lastTarget = top.name
        statusLabel:SetText(L.STATUS_AUTO .. "|cff00ff96" .. top.name .. "|r")
        frame.Refresh()
    end
end

-------------------------------------------------------------------------------
-- PI Request notification (priest side)
-------------------------------------------------------------------------------

local function CanCastPI()
    return IsSpellKnown(PI_SPELL_ID)
end

notifFrame = CreateFrame("Frame", "PIorityNotif", UIParent, "BackdropTemplate")
notifFrame:SetSize(140, 170)
notifFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
notifFrame:SetFrameStrata("HIGH")
notifFrame:SetMovable(true)
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
    notifSub:SetText(L.NOTIF_REQUESTS:format(GetPISpellName() or "Power Infusion"))

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

    PlayPISound()
end

ShowNotifPreview = function()
    local iconPath = (C_Spell and C_Spell.GetSpellTexture) and C_Spell.GetSpellTexture(PI_SPELL_ID)
                     or GetSpellTexture(PI_SPELL_ID)
    if iconPath then notifIcon:SetTexture(iconPath) end
    notifSub:SetText(L.NOTIF_REQUESTS:format(GetPISpellName() or "Power Infusion"))
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
    notifSub:SetText(L.NOTIF_REQUESTS:format(GetPISpellName() or "Power Infusion"))

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

    PlayPISound()
end

frame:HookScript("OnHide", function()
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
        -- Set PI spell icon (texture available after login)
        local iconPath = (C_Spell and C_Spell.GetSpellTexture) and C_Spell.GetSpellTexture(PI_SPELL_ID)
                         or GetSpellTexture(PI_SPELL_ID)
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
        PIorityDB = PIorityDB or { lastTarget = nil }
        if PIorityDB.priority then PIorityDB.priority = nil end

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

        RestoreFrameLayout()
        RestoreNotifLayout()
        autopickCheck:SetChecked(PIorityDB.autopick and true or false)
        UpdateSoundDropLabel()
        print("|cff00ff96" .. L.TITLE .. "|r " .. L.MSG_LOADED)

    elseif event == "PLAYER_LOGIN" then
        C_ChatInfo.RegisterAddonMessagePrefix(MSG_PREFIX)
        -- Macro list is ready at this point, safe to create if missing.
        local _, playerClass = UnitClass("player")
        if playerClass == "PRIEST" and GetMacroIndexByName(MACRO_NAME) == 0 then
            local idx = CreatePIMacro(BuildResetMacroBody())
            if idx and idx > 0 then
                print("|cff00ff96PIority:|r " .. L.MSG_MACRO_CREATED:format(MACRO_NAME))
            else
                print("|cffff4444PIority:|r " .. L.MSG_MACRO_LIMIT:format(MACRO_NAME))
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
        end
        minimapBtn.Init()

    elseif event == "PLAYER_ENTERING_WORLD" then
        CachePlayerSpec()
        QueueInspects()

    elseif event == "GROUP_ROSTER_UPDATE" then
        PruneCacheToGroup()
        CachePlayerSpec()
        QueueInspects()
        ScheduleAnnounce()
        local inGroup = GetNumGroupMembers() > 0
        if frame:IsShown() then
            frame.Refresh()
        elseif inGroup and not frame:IsShown() then
            -- Only auto-open for priests who have no current group target assigned.
            local _, playerClass = UnitClass("player")
            local lastTarget = PIorityDB and PIorityDB.lastTarget
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

        if arg2 == MSG_REQUEST and CanCastPI() and senderName == GetMacroTarget() then
            ShowPIRequest(senderName)
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
        if name then
            UpdateMacroTarget(name)
        else
            print("|cffff4444PIority:|r " .. L.MSG_USAGE_TARGET)
        end
    elseif cmd == "help" then
        print("|cff00ff96" .. L.HELP_HEADER .. "|r")
        print(L.HELP_TOGGLE)
        print(L.HELP_TARGET)
        print(L.HELP_HELP)
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
