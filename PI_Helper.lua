-- PI_Helper: assign a Power Infusion macro target from a group/raid list.
-- Sorts players by spec priority; click a row to update the PI_H macro.

local _, ns = ...
local L = ns.L

local ADDON_NAME    = "PI_Helper"
local MACRO_NAME    = "PI_H"
local PI_SPELL_ID   = 10060
local MSG_PREFIX    = "PIHelper"
local MSG_REQUEST   = "REQUEST"

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
-- "Devourer Demon Hunter" is not a real spec and has been omitted.
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
-- Member cache (populated at runtime; persisted via PIHelperDB on load)
-------------------------------------------------------------------------------
local specCache    = {}  -- [name] = specID
local ilvlCache    = {}  -- [name] = average equipped item level (number)

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
-- Macro helpers
-------------------------------------------------------------------------------

local function EnsureMacroExists(targetName)
    if GetMacroIndexByName(MACRO_NAME) == 0 then
        CreateMacro(MACRO_NAME, "INV_Misc_QuestionMark", BuildMacroBody(targetName), false)
        print("|cff00ff96PI Helper:|r " .. L.MSG_MACRO_TARGETING:format(MACRO_NAME, targetName))
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
        print("|cffff4444PI Helper:|r " .. L.MSG_MACRO_NOT_FOUND:format(MACRO_NAME))
        return
    end

    EditMacro(MACRO_NAME, MACRO_NAME, nil, newBody)
    print("|cff00ff96PI Helper:|r " .. L.MSG_MACRO_UPDATED:format(MACRO_NAME, targetName))
end

local ResetPITarget  -- defined after UI elements are in scope

-------------------------------------------------------------------------------
-- Roster building
-------------------------------------------------------------------------------

local function GetSortedRoster()
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
-- UI
-------------------------------------------------------------------------------

local function SaveFrameLayout()
    local point, _, relPoint, x, y = frame:GetPoint()
    PIHelperDB.layout = {
        point    = point,
        relPoint = relPoint,
        x        = x,
        y        = y,
        width    = frame:GetWidth(),
        height   = frame:GetHeight(),
    }
end

local function RestoreFrameLayout()
    local l = PIHelperDB.layout
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
    PIHelperDB.notifLayout = { point = point, relPoint = relPoint, x = x, y = y }
end

local function RestoreNotifLayout()
    local l = PIHelperDB.notifLayout
    if l then
        notifFrame:ClearAllPoints()
        notifFrame:SetPoint(l.point, UIParent, l.relPoint, l.x, l.y)
    end
end

local frame = CreateFrame("Frame", "PIHelperFrame", UIParent, "BackdropTemplate")
frame:SetSize(290, 420)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:SetResizable(true)
frame:SetResizeBounds(200, 150)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    SaveFrameLayout()
end)
frame:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
frame:SetBackdropColor(0.05, 0.05, 0.1, 0.92)
frame:SetBackdropBorderColor(0.4, 0.4, 0.6)
frame:Hide()

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
title:SetJustifyH("LEFT")
title:SetText("|cff00ff96" .. L.TITLE .. "|r")

local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
closeBtn:SetScript("OnClick", function() frame:Hide() end)

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

-- Size a button to its label width so text never clips.
local function FitButton(btn, minWidth)
    btn:SetHeight(22)
    local fs = btn:GetFontString()
    local w = fs and fs:GetStringWidth() or 0
    btn:SetWidth(math.max(minWidth or 60, w + 24))
end

-- Re-inspect button
local reInspectBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
reInspectBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -8)
reInspectBtn:SetText(L.BTN_REINSPECT)
FitButton(reInspectBtn)
reInspectBtn:SetScript("OnClick", function()
    wipe(specCache)
    wipe(ilvlCache)
    CachePlayerSpec()
    QueueInspects()
    print("|cff00ff96PI Helper:|r " .. L.MSG_REINSPECTING)
end)

local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -36)
scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 40)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetHeight(1)
scrollFrame:SetScrollChild(content)

-- Keep content width in sync with the scroll frame so rows always fill 100%.
local function SyncContentWidth()
    content:SetWidth(scrollFrame:GetWidth())
end
scrollFrame:SetScript("OnSizeChanged", function()
    SyncContentWidth()
    if frame:IsShown() then frame.Refresh() end
end)

local autopickCheck = CreateFrame("CheckButton", "PIHelperAutopick", frame, "UICheckButtonTemplate")
autopickCheck:SetSize(24, 24)
autopickCheck:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 6)
autopickCheck.text:SetText(L.CHK_AUTOPICK)
autopickCheck:SetScript("OnClick", function(self)
    PIHelperDB.autopick = self:GetChecked() and true or false
    if PIHelperDB.autopick then TryAutopick() end
end)

local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
resetBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 6)
resetBtn:SetText(L.BTN_RESET)
FitButton(resetBtn)
resetBtn:SetScript("OnClick", function() ResetPITarget() end)

local statusLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
statusLabel:SetPoint("BOTTOM", frame, "BOTTOM", 0, 12)
statusLabel:SetText(L.STATUS_NONE)

local rows = {}

local function MakeRow(index)
    local btn = CreateFrame("Button", nil, content)
    btn:SetHeight(24)
    btn:SetPoint("TOPLEFT",  content, "TOPLEFT",  0,  -(index - 1) * 26)
    btn:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0,  -(index - 1) * 26)
    btn:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight", "ADD")

    -- Fixed-width left columns
    local rank = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rank:SetPoint("LEFT", btn, "LEFT", 4, 0)
    rank:SetWidth(20)
    btn.rankText = rank

    local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameText:SetPoint("LEFT", rank, "RIGHT", 2, 0)
    nameText:SetWidth(80)
    btn.nameText = nameText

    -- Fixed-width right columns (anchored from the right edge)
    local marker = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    marker:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    marker:SetWidth(12)
    btn.marker = marker

    local ilvlText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ilvlText:SetPoint("RIGHT", marker, "LEFT", -2, 0)
    ilvlText:SetWidth(32)
    ilvlText:SetJustifyH("RIGHT")
    btn.ilvlText = ilvlText

    local levelText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    levelText:SetPoint("RIGHT", ilvlText, "LEFT", -2, 0)
    levelText:SetWidth(24)
    levelText:SetJustifyH("RIGHT")
    btn.levelText = levelText

    -- Spec column stretches between nameText and levelText
    local specText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    specText:SetPoint("LEFT",  nameText,  "RIGHT", 4, 0)
    specText:SetPoint("RIGHT", levelText, "LEFT",  -4, 0)
    specText:SetJustifyH("LEFT")
    specText:SetTextColor(0.7, 0.7, 0.7)
    btn.specText = specText

    btn:SetScript("OnClick", function()
        if not btn.memberName then return end
        UpdateMacroTarget(btn.memberName)
        PIHelperDB.lastTarget = btn.memberName
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
    local roster = GetSortedRoster()
    local lastTarget = PIHelperDB and PIHelperDB.lastTarget

    -- Context-sensitive button states
    resetBtn:SetEnabled(lastTarget ~= nil)
    reInspectBtn:SetEnabled(GetNumGroupMembers() > 0)

    for _, r in ipairs(rows) do r:Hide() end
    content:SetHeight(math.max(1, #roster * 26))

    for i, entry in ipairs(roster) do
        local row = GetRow(i)
        row.memberName = entry.name

        row.rankText:SetText("|cff888888" .. i .. ".|r")

        local unit = GetUnitForName(entry.name)
        local _, _, classFile = unit and UnitClass(unit) or UnitClass("player")
        local cc = classFile and RAID_CLASS_COLORS[classFile]
        if cc then
            row.nameText:SetTextColor(cc.r, cc.g, cc.b)
        else
            row.nameText:SetTextColor(1, 1, 1)
        end
        row.nameText:SetText(entry.name)

        if entry.specID then
            local prio = SPEC_PRIORITY[entry.specID]
            local sname = SPEC_NAME[entry.specID] or ("Spec " .. entry.specID)
            if prio then
                row.specText:SetText("|cffaaddaa" .. sname .. "|r")
            else
                row.specText:SetText("|cffaaaaaa" .. sname .. "|r")
            end
        else
            row.specText:SetText("|cff666666...|r")
        end

        if entry.level and entry.level > 0 then
            row.levelText:SetText("|cffcccccc" .. entry.level .. "|r")
        else
            row.levelText:SetText("|cff666666-|r")
        end

        if entry.ilvl then
            row.ilvlText:SetText("|cffffd700" .. entry.ilvl .. "|r")
        else
            row.ilvlText:SetText("|cff666666-|r")
        end

        if entry.name == lastTarget then
            row.marker:SetText("|cff00ff96>|r")
        else
            row.marker:SetText("")
        end

        row:Show()
    end
end

-- Both defined here so frame, statusLabel, and macro helpers are all in scope.
ResetPITarget = function()
    UpdateMacroTarget("focus")
    PIHelperDB.lastTarget = nil
    statusLabel:SetText(L.STATUS_NONE)
    frame.Refresh()
    print("|cff00ff96PI Helper:|r " .. L.MSG_RESET)
end

TryAutopick = function()
    if not PIHelperDB or not PIHelperDB.autopick then return end
    local _, playerClass = UnitClass("player")
    if playerClass ~= "PRIEST" then return end
    if GetNumGroupMembers() == 0 then return end
    if #GetUnknownMembers() > 0 then return end
    local roster = GetSortedRoster()
    if #roster == 0 then return end
    local top = roster[1]
    if top.specID and SPEC_PRIORITY[top.specID] and PIHelperDB.lastTarget ~= top.name then
        UpdateMacroTarget(top.name)
        PIHelperDB.lastTarget = top.name
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

local notifFrame = CreateFrame("Frame", "PIHelperNotif", UIParent)
notifFrame:SetSize(120, 160)
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
notifFrame.isPreview = false
notifFrame:Hide()

-- Spell icon
local notifIcon = notifFrame:CreateTexture(nil, "ARTWORK")
notifIcon:SetSize(90, 90)
notifIcon:SetPoint("TOP", notifFrame, "TOP", 0, 0)
notifIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

-- Pulsing glow on the icon only
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

-- Requester name
local notifName = notifFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
notifName:SetPoint("TOP", notifIcon, "BOTTOM", 0, -8)
notifName:SetWidth(180)
notifName:SetJustifyH("CENTER")

-- Sub line
local notifSub = notifFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
notifSub:SetPoint("TOP", notifName, "BOTTOM", 0, -4)
notifSub:SetTextColor(1.0, 0.82, 0.0)


local function ShowPIRequest(senderName)
    local iconPath = (C_Spell and C_Spell.GetSpellTexture) and C_Spell.GetSpellTexture(PI_SPELL_ID)
                     or GetSpellTexture(PI_SPELL_ID)
    if iconPath then notifIcon:SetTexture(iconPath) end

    notifSub:SetText(L.NOTIF_REQUESTS:format(GetPISpellName() or "Power Infusion"))

    -- Class-colour the name if we can find the unit
    local unit = GetUnitForName(senderName)
    local _, _, classFile = unit and UnitClass(unit) or nil, nil, nil
    local cc = classFile and RAID_CLASS_COLORS[classFile]
    if cc then
        notifName:SetTextColor(cc.r, cc.g, cc.b)
    else
        notifName:SetTextColor(1, 1, 1)
    end
    notifName:SetText(senderName)

    notifFrame.requester  = senderName
    notifFrame.isPreview  = false
    notifFrame:Show()

    if notifFrame.dismissTimer then notifFrame.dismissTimer:Cancel() end
    notifFrame.dismissTimer = C_Timer.NewTimer(8, function()
        notifFrame.dismissTimer = nil
        notifFrame.isPreview = false
        notifFrame:Hide()
    end)

    PlaySound(SOUNDKIT.RAID_WARNING)
end

local function ShowNotifPreview()
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

-- Toggle button on the main frame to preview the notification position.
local notifToggleBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
notifToggleBtn:SetPoint("TOPRIGHT", reInspectBtn, "TOPLEFT", -4, 0)
notifToggleBtn:SetText(L.BTN_ALERT_POS)
FitButton(notifToggleBtn)
notifToggleBtn:SetScript("OnClick", function()
    if notifFrame:IsShown() and notifFrame.isPreview then
        notifFrame.isPreview = false
        notifFrame:Hide()
    else
        ShowNotifPreview()
    end
end)

frame:HookScript("OnHide", function()
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
    if not channel then
        print("|cffff4444PI Helper:|r " .. L.MSG_NOT_IN_GROUP)
        return
    end
    C_ChatInfo.SendAddonMessage(MSG_PREFIX, MSG_REQUEST, channel)
    print("|cff00ff96PI Helper:|r " .. L.MSG_PI_REQUESTED)
end

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

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local arg1, arg2, arg3, arg4 = ...
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        PIHelperDB = PIHelperDB or { lastTarget = nil }
        if PIHelperDB.priority then PIHelperDB.priority = nil end

        -- Redirect caches to persisted subtables so writes survive reloads.
        PIHelperDB.specCache = PIHelperDB.specCache or {}
        PIHelperDB.ilvlCache = PIHelperDB.ilvlCache or {}
        specCache = PIHelperDB.specCache
        ilvlCache = PIHelperDB.ilvlCache

        -- Drop entries for players not in the current group (stale data from last session).
        PruneCacheToGroup()

        RestoreFrameLayout()
        RestoreNotifLayout()
        autopickCheck:SetChecked(PIHelperDB.autopick and true or false)
        print("|cff00ff96" .. L.TITLE .. "|r " .. L.MSG_LOADED)

    elseif event == "PLAYER_LOGIN" then
        C_ChatInfo.RegisterAddonMessagePrefix(MSG_PREFIX)
        -- Macro list is ready at this point, safe to create if missing.
        local _, playerClass = UnitClass("player")
        if playerClass == "PRIEST" and GetMacroIndexByName(MACRO_NAME) == 0 then
            local idx = CreateMacro(MACRO_NAME, "INV_Misc_QuestionMark", BuildResetMacroBody(), true)
            if idx and idx > 0 then
                print("|cff00ff96PI Helper:|r " .. L.MSG_MACRO_CREATED:format(MACRO_NAME))
            else
                print("|cffff4444PI Helper:|r " .. L.MSG_MACRO_LIMIT:format(MACRO_NAME))
            end
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        CachePlayerSpec()
        QueueInspects()

    elseif event == "GROUP_ROSTER_UPDATE" then
        PruneCacheToGroup()
        CachePlayerSpec()
        QueueInspects()
        local inGroup = GetNumGroupMembers() > 0
        if frame:IsShown() then
            frame.Refresh()
        elseif inGroup and not frame:IsShown() then
            -- Only auto-open for priests who have no current group target assigned.
            local _, playerClass = UnitClass("player")
            local lastTarget = PIHelperDB and PIHelperDB.lastTarget
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
        if arg1 == MSG_PREFIX and arg2 == MSG_REQUEST and CanCastPI() then
            local senderName = arg4 and (arg4:match("^([^%-]+)") or arg4)
            if senderName and senderName ~= UnitName("player") then
                ShowPIRequest(senderName)
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

    if cmd == "target" then
        local name = rest:match("%S+")
        if name then
            UpdateMacroTarget(name)
        else
            print("|cffff4444PI Helper:|r " .. L.MSG_USAGE_TARGET)
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
