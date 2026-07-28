-- AUTO-GENERATED from pi_patchwerk1.json by tools/convert-pi-data.js
-- Do not edit by hand; re-run the converter to regenerate.

local _, ns = ...
ns.piData = ns.piData or {}

ns.piData["patchwerk1"] = {
    title      = "Power Infusion | Castingpatchwerk",
    fightStyle = "castingpatchwerk",
    specId     = 258,
    classId    = 5,
    timestamp  = "2026-07-08 06:01",

    -- specID -> priority rank (1 = highest PI value)
    priority = {
        [63] = 1,  -- Fire Mage
        [104] = 2,  -- Guardian Druid
        [102] = 3,  -- Balance Druid
        [269] = 4,  -- Windwalker Monk
        [263] = 5,  -- Enhancement Shaman
        [253] = 6,  -- Beast_Mastery Hunter
        [266] = 7,  -- Demonology Warlock
        [255] = 8,  -- Survival Hunter
        [254] = 9,  -- Marksmanship Hunter
        [262] = 10,  -- Elemental Shaman
        [265] = 11,  -- Affliction Warlock
        [103] = 12,  -- Feral Druid
        [62] = 13,  -- Arcane Mage
        [70] = 14,  -- Retribution Paladin
        [66] = 15,  -- Protection Paladin
        [259] = 16,  -- Assassination Rogue
        [1480] = 17,  -- Devourer Demon Hunter
        [71] = 18,  -- Arms Warrior
        [258] = 19,  -- Shadow Priest
        [252] = 20,  -- Unholy Death Knight
        [581] = 21,  -- Vengeance Demon Hunter
        [250] = 22,  -- Blood Death Knight
        [577] = 23,  -- Havoc Demon Hunter
        [251] = 24,  -- Frost Death Knight
        [64] = 25,  -- Frost Mage
        [1467] = 26,  -- Devastation Evoker
        [73] = 27,  -- Protection Warrior
        [72] = 28,  -- Fury Warrior
        [267] = 29,  -- Destruction Warlock
        [260] = 30,  -- Outlaw Rogue
        [261] = 31,  -- Subtlety Rogue
        [268] = 32,  -- Brewmaster Monk
    },

    -- specID -> simmed PI DPS gain
    value = {
        [63] = 121949,  -- Fire Mage
        [104] = 83686,  -- Guardian Druid
        [102] = 122094,  -- Balance Druid
        [269] = 124202,  -- Windwalker Monk
        [263] = 118498,  -- Enhancement Shaman
        [253] = 127386,  -- Beast_Mastery Hunter
        [266] = 124266,  -- Demonology Warlock
        [255] = 124140,  -- Survival Hunter
        [254] = 134059,  -- Marksmanship Hunter
        [262] = 135989,  -- Elemental Shaman
        [265] = 119052,  -- Affliction Warlock
        [103] = 139515,  -- Feral Druid
        [62] = 117993,  -- Arcane Mage
        [70] = 116774,  -- Retribution Paladin
        [66] = 78633,  -- Protection Paladin
        [259] = 111825,  -- Assassination Rogue
        [1480] = 107730,  -- Devourer Demon Hunter
        [71] = 116645,  -- Arms Warrior
        [258] = 121693,  -- Shadow Priest
        [252] = 132262,  -- Unholy Death Knight
        [581] = 74706,  -- Vengeance Demon Hunter
        [250] = 71579,  -- Blood Death Knight
        [577] = 123262,  -- Havoc Demon Hunter
        [251] = 137607,  -- Frost Death Knight
        [64] = 120263,  -- Frost Mage
        [1467] = 117601,  -- Devastation Evoker
        [73] = 85252,  -- Protection Warrior
        [72] = 122594,  -- Fury Warrior
        [267] = 117411,  -- Destruction Warlock
        [260] = 129489,  -- Outlaw Rogue
        [261] = 125187,  -- Subtlety Rogue
        [268] = 86733,  -- Brewmaster Monk
    },

    -- specID -> secondary (bracketed) SimC series
    value2 = {
        [63] = 114707,  -- Fire Mage
        [104] = 79445,  -- Guardian Druid
        [102] = 116024,  -- Balance Druid
        [269] = 118103,  -- Windwalker Monk
        [263] = 112705,  -- Enhancement Shaman
        [253] = 121381,  -- Beast_Mastery Hunter
        [266] = 118514,  -- Demonology Warlock
        [255] = 118416,  -- Survival Hunter
        [254] = 127980,  -- Marksmanship Hunter
        [262] = 130026,  -- Elemental Shaman
        [265] = 114033,  -- Affliction Warlock
        [103] = 133650,  -- Feral Druid
        [62] = 113103,  -- Arcane Mage
        [70] = 111972,  -- Retribution Paladin
        [66] = 75673,  -- Protection Paladin
        [259] = 107689,  -- Assassination Rogue
        [1480] = 104005,  -- Devourer Demon Hunter
        [71] = 112621,  -- Arms Warrior
        [258] = 117615,  -- Shadow Priest
        [252] = 128285,  -- Unholy Death Knight
        [581] = 72472,  -- Vengeance Demon Hunter
        [250] = 69626,  -- Blood Death Knight
        [577] = 119927,  -- Havoc Demon Hunter
        [251] = 133919,  -- Frost Death Knight
        [64] = 117064,  -- Frost Mage
        [1467] = 114527,  -- Devastation Evoker
        [73] = 83081,  -- Protection Warrior
        [72] = 119542,  -- Fury Warrior
        [267] = 114889,  -- Destruction Warlock
        [260] = 127005,  -- Outlaw Rogue
        [261] = 123443,  -- Subtlety Rogue
        [268] = 86350,  -- Brewmaster Monk
    },

    -- specIDs in priority order
    order  = { 63, 104, 102, 269, 263, 253, 266, 255, 254, 262, 265, 103, 62, 70, 66, 259, 1480, 71, 258, 252, 581, 250, 577, 251, 64, 1467, 73, 72, 267, 260, 261, 268 },
    order2 = { 63, 269, 254, 102, 253, 262, 103, 263, 266, 255, 265, 62, 70, 104, 259, 258, 71, 252, 1480, 251, 577, 64, 1467, 72, 66, 267, 260, 581, 73, 250, 261, 268 },
}
