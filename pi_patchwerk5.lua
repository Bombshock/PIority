-- AUTO-GENERATED from pi_patchwerk5.json by tools/convert-pi-data.js
-- Do not edit by hand; re-run the converter to regenerate.

local _, ns = ...
ns.piData = ns.piData or {}

ns.piData["patchwerk5"] = {
    title      = "Power Infusion | Castingpatchwerk5",
    fightStyle = "castingpatchwerk5",
    specId     = 258,
    classId    = 5,
    timestamp  = "2026-07-08 06:11",

    -- specID -> priority rank (1 = highest PI value)
    priority = {
        [63] = 1,  -- Fire Mage
        [269] = 2,  -- Windwalker Monk
        [266] = 3,  -- Demonology Warlock
        [263] = 4,  -- Enhancement Shaman
        [254] = 5,  -- Marksmanship Hunter
        [62] = 6,  -- Arcane Mage
        [102] = 7,  -- Balance Druid
        [104] = 8,  -- Guardian Druid
        [103] = 9,  -- Feral Druid
        [1467] = 10,  -- Devastation Evoker
        [70] = 11,  -- Retribution Paladin
        [262] = 12,  -- Elemental Shaman
        [255] = 13,  -- Survival Hunter
        [265] = 14,  -- Affliction Warlock
        [258] = 15,  -- Shadow Priest
        [1480] = 16,  -- Devourer Demon Hunter
        [577] = 17,  -- Havoc Demon Hunter
        [66] = 18,  -- Protection Paladin
        [64] = 19,  -- Frost Mage
        [581] = 20,  -- Vengeance Demon Hunter
        [250] = 21,  -- Blood Death Knight
        [73] = 22,  -- Protection Warrior
        [71] = 23,  -- Arms Warrior
        [253] = 24,  -- Beast_Mastery Hunter
        [252] = 25,  -- Unholy Death Knight
        [251] = 26,  -- Frost Death Knight
        [72] = 27,  -- Fury Warrior
        [267] = 28,  -- Destruction Warlock
        [261] = 29,  -- Subtlety Rogue
        [260] = 30,  -- Outlaw Rogue
        [259] = 31,  -- Assassination Rogue
        [268] = 32,  -- Brewmaster Monk
    },

    -- specID -> simmed PI DPS gain
    value = {
        [63] = 293551,  -- Fire Mage
        [269] = 363146,  -- Windwalker Monk
        [266] = 393593,  -- Demonology Warlock
        [263] = 339369,  -- Enhancement Shaman
        [254] = 219291,  -- Marksmanship Hunter
        [62] = 341301,  -- Arcane Mage
        [102] = 285533,  -- Balance Druid
        [104] = 211197,  -- Guardian Druid
        [103] = 234518,  -- Feral Druid
        [1467] = 355738,  -- Devastation Evoker
        [70] = 267419,  -- Retribution Paladin
        [262] = 474732,  -- Elemental Shaman
        [255] = 363127,  -- Survival Hunter
        [265] = 264666,  -- Affliction Warlock
        [258] = 332021,  -- Shadow Priest
        [1480] = 250033,  -- Devourer Demon Hunter
        [577] = 258585,  -- Havoc Demon Hunter
        [66] = 181860,  -- Protection Paladin
        [64] = 238545,  -- Frost Mage
        [581] = 251556,  -- Vengeance Demon Hunter
        [250] = 266778,  -- Blood Death Knight
        [73] = 239666,  -- Protection Warrior
        [71] = 198415,  -- Arms Warrior
        [253] = 213391,  -- Beast_Mastery Hunter
        [252] = 298473,  -- Unholy Death Knight
        [251] = 302430,  -- Frost Death Knight
        [72] = 211878,  -- Fury Warrior
        [267] = 246267,  -- Destruction Warlock
        [261] = 317156,  -- Subtlety Rogue
        [260] = 302932,  -- Outlaw Rogue
        [259] = 174020,  -- Assassination Rogue
        [268] = 223775,  -- Brewmaster Monk
    },

    -- specID -> secondary (bracketed) SimC series
    value2 = {
        [63] = 271978,  -- Fire Mage
        [269] = 341473,  -- Windwalker Monk
        [266] = 371582,  -- Demonology Warlock
        [263] = 323120,  -- Enhancement Shaman
        [254] = 208800,  -- Marksmanship Hunter
        [62] = 327100,  -- Arcane Mage
        [102] = 273916,  -- Balance Druid
        [104] = 202616,  -- Guardian Druid
        [103] = 225106,  -- Feral Druid
        [1467] = 341507,  -- Devastation Evoker
        [70] = 256755,  -- Retribution Paladin
        [262] = 456406,  -- Elemental Shaman
        [255] = 349365,  -- Survival Hunter
        [265] = 254700,  -- Affliction Warlock
        [258] = 319570,  -- Shadow Priest
        [1480] = 241188,  -- Devourer Demon Hunter
        [577] = 249454,  -- Havoc Demon Hunter
        [66] = 175531,  -- Protection Paladin
        [64] = 231484,  -- Frost Mage
        [581] = 244234,  -- Vengeance Demon Hunter
        [250] = 259392,  -- Blood Death Knight
        [73] = 233099,  -- Protection Warrior
        [71] = 192994,  -- Arms Warrior
        [253] = 207613,  -- Beast_Mastery Hunter
        [252] = 290638,  -- Unholy Death Knight
        [251] = 294643,  -- Frost Death Knight
        [72] = 206547,  -- Fury Warrior
        [267] = 240673,  -- Destruction Warlock
        [261] = 309981,  -- Subtlety Rogue
        [260] = 297184,  -- Outlaw Rogue
        [259] = 170904,  -- Assassination Rogue
        [268] = 222502,  -- Brewmaster Monk
    },

    -- specIDs in priority order
    order  = { 63, 269, 266, 263, 254, 62, 102, 104, 103, 1467, 70, 262, 255, 265, 258, 1480, 577, 66, 64, 581, 250, 73, 71, 253, 252, 251, 72, 267, 261, 260, 259, 268 },
    order2 = { 266, 269, 63, 262, 263, 1467, 62, 255, 258, 102, 70, 254, 265, 103, 577, 1480, 104, 252, 251, 250, 581, 261, 64, 73, 66, 253, 260, 267, 71, 72, 259, 268 },
}
