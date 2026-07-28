#!/usr/bin/env node
/*
 * convert-pi-data.js
 * -------------------
 * Converts bloodytools/SimC Power Infusion export JSON (e.g. pi_patchwerk1.json)
 * into a Lua data module the PIority addon can load via its .toc.
 *
 * WoW addons cannot read JSON at runtime, so this bakes the sim data into a Lua
 * table keyed by WoW specID (what the addon actually looks specs up by), including
 * the priority ranking and the raw simmed PI DPS gain.
 *
 * Usage:
 *   node tools/convert-pi-data.js                       # convert every pi_*.json in the addon root
 *   node tools/convert-pi-data.js pi_patchwerk1.json    # convert specific file(s)
 *   node tools/convert-pi-data.js in.json -o out.lua    # single file, explicit output
 *
 * Each input FOO.json becomes FOO.lua next to it. Every generated module
 * registers itself under ns.piData["<profile>"], where <profile> is the file
 * name with a leading "pi_" stripped (pi_patchwerk1.json -> "patchwerk1").
 */

'use strict';

const fs = require('fs');
const path = require('path');

// Maps the SimC spec names used in the JSON to WoW specIDs. Keys match the JSON
// exactly, including SimC's underscore in "Beast_Mastery Hunter".
const NAME_TO_SPECID = {
    'Arcane Mage': 62,
    'Fire Mage': 63,
    'Frost Mage': 64,
    'Protection Paladin': 66,
    'Retribution Paladin': 70,
    'Arms Warrior': 71,
    'Fury Warrior': 72,
    'Protection Warrior': 73,
    'Balance Druid': 102,
    'Feral Druid': 103,
    'Guardian Druid': 104,
    'Blood Death Knight': 250,
    'Frost Death Knight': 251,
    'Unholy Death Knight': 252,
    'Beast_Mastery Hunter': 253,
    'Marksmanship Hunter': 254,
    'Survival Hunter': 255,
    'Shadow Priest': 258,
    'Assassination Rogue': 259,
    'Outlaw Rogue': 260,
    'Subtlety Rogue': 261,
    'Elemental Shaman': 262,
    'Enhancement Shaman': 263,
    'Affliction Warlock': 265,
    'Demonology Warlock': 266,
    'Destruction Warlock': 267,
    'Brewmaster Monk': 268,
    'Windwalker Monk': 269,
    'Havoc Demon Hunter': 577,
    'Vengeance Demon Hunter': 581,
    'Devastation Evoker': 1467,
    'Devourer Demon Hunter': 1480,
};

// ---------------------------------------------------------------------------

function parseArgs(argv) {
    const inputs = [];
    let output = null;
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a === '-o' || a === '--output') {
            output = argv[++i];
        } else if (a === '-h' || a === '--help') {
            return { help: true };
        } else {
            inputs.push(a);
        }
    }
    return { inputs, output };
}

// Escape a JS string for embedding inside a Lua double-quoted literal.
function luaStr(s) {
    return '"' + String(s == null ? '' : s)
        .replace(/\\/g, '\\\\')
        .replace(/"/g, '\\"')
        .replace(/\n/g, '\\n')
        .replace(/\r/g, '') + '"';
}

// profile key from a file path: pi_patchwerk1.json -> "patchwerk1"
function profileKey(file) {
    return path.basename(file).replace(/\.json$/i, '').replace(/^pi_/i, '');
}

// Resolve a JSON spec name to a specID, tracking anything unmapped.
function toSpecID(name, unmapped) {
    const id = NAME_TO_SPECID[name];
    if (id === undefined) unmapped.add(name);
    return id;
}

function convert(file) {
    const raw = fs.readFileSync(file, 'utf8');
    const json = JSON.parse(raw);
    const unmapped = new Set();

    const data = json.data || {};

    // Split the two SimC series: plain "Fire Mage" vs the "{Fire Mage}" variant.
    const value = {};   // specID -> primary PI gain
    const value2 = {};  // specID -> bracketed (baseline) series, if present
    for (const [name, num] of Object.entries(data)) {
        const m = name.match(/^\{(.+)\}$/);
        if (m) {
            const id = toSpecID(m[1], unmapped);
            if (id !== undefined) value2[id] = num;
        } else {
            const id = toSpecID(name, unmapped);
            if (id !== undefined) value[id] = num;
        }
    }

    // Priority ordering comes from the SimC-provided sorted key lists.
    const order = (json.sorted_data_keys || [])
        .map((n) => toSpecID(n, unmapped))
        .filter((id) => id !== undefined);
    const order2 = (json.sorted_data_keys_2 || [])
        .map((n) => toSpecID(n, unmapped))
        .filter((id) => id !== undefined);

    // specID -> rank (1 = highest PI value), derived from `order`.
    const priority = {};
    order.forEach((id, i) => { priority[id] = i + 1; });

    return {
        profile: profileKey(file),
        title: json.title,
        subtitle: json.subtitle,
        fightStyle: json.simc_settings && json.simc_settings.fight_style,
        specId: json.spec_id,
        classId: json.class_id,
        timestamp: json.timestamp,
        value, value2, order, order2, priority,
        unmapped: [...unmapped],
    };
}

// Render one converted profile as a Lua chunk registering into ns.piData.
function renderLua(c, sourceName) {
    const specComment = (id) => {
        const name = Object.keys(NAME_TO_SPECID).find((k) => NAME_TO_SPECID[k] === id);
        return name ? '  -- ' + name : '';
    };

    // Priority table, emitted in rank order for readability.
    const prioLines = c.order.map((id) =>
        `        [${id}] = ${c.priority[id]},${specComment(id)}`).join('\n');

    // Value tables, emitted in rank order so they line up with priority.
    const valueLines = c.order
        .filter((id) => c.value[id] !== undefined)
        .map((id) => `        [${id}] = ${c.value[id]},${specComment(id)}`).join('\n');

    const hasValue2 = Object.keys(c.value2).length > 0;
    const value2Lines = hasValue2 ? c.order
        .filter((id) => c.value2[id] !== undefined)
        .map((id) => `        [${id}] = ${c.value2[id]},${specComment(id)}`).join('\n') : '';

    const orderArr = (arr) => '{ ' + arr.join(', ') + ' }';

    const L = [];
    L.push(`-- AUTO-GENERATED from ${sourceName} by tools/convert-pi-data.js`);
    L.push(`-- Do not edit by hand; re-run the converter to regenerate.`);
    L.push(``);
    L.push(`local _, ns = ...`);
    L.push(`ns.piData = ns.piData or {}`);
    L.push(``);
    L.push(`ns.piData[${luaStr(c.profile)}] = {`);
    L.push(`    title      = ${luaStr(c.title)},`);
    L.push(`    fightStyle = ${luaStr(c.fightStyle)},`);
    L.push(`    specId     = ${c.specId != null ? c.specId : 'nil'},`);
    L.push(`    classId    = ${c.classId != null ? c.classId : 'nil'},`);
    L.push(`    timestamp  = ${luaStr(c.timestamp)},`);
    L.push(``);
    L.push(`    -- specID -> priority rank (1 = highest PI value)`);
    L.push(`    priority = {`);
    L.push(prioLines);
    L.push(`    },`);
    L.push(``);
    L.push(`    -- specID -> simmed PI DPS gain`);
    L.push(`    value = {`);
    L.push(valueLines);
    L.push(`    },`);
    if (hasValue2) {
        L.push(``);
        L.push(`    -- specID -> secondary (bracketed) SimC series`);
        L.push(`    value2 = {`);
        L.push(value2Lines);
        L.push(`    },`);
    }
    L.push(``);
    L.push(`    -- specIDs in priority order`);
    L.push(`    order  = ${orderArr(c.order)},`);
    if (c.order2.length) {
        L.push(`    order2 = ${orderArr(c.order2)},`);
    }
    L.push(`}`);
    L.push(``);
    return L.join('\n');
}

function main() {
    const { inputs, output, help } = parseArgs(process.argv.slice(2));
    if (help) {
        console.log('Usage: node tools/convert-pi-data.js [pi_*.json ...] [-o out.lua]');
        return;
    }

    const root = path.resolve(__dirname, '..');
    let files = inputs && inputs.length ? inputs : null;
    if (!files) {
        files = fs.readdirSync(root)
            .filter((f) => /^pi_.*\.json$/i.test(f))
            .map((f) => path.join(root, f));
        if (files.length === 0) {
            console.error('No pi_*.json files found in ' + root);
            process.exit(1);
        }
    }

    if (output && files.length > 1) {
        console.error('-o/--output can only be used with a single input file.');
        process.exit(1);
    }

    for (const file of files) {
        const abs = path.isAbsolute(file) ? file : path.resolve(process.cwd(), file);
        const c = convert(abs);
        const lua = renderLua(c, path.basename(abs));
        const outPath = output
            ? path.resolve(process.cwd(), output)
            : abs.replace(/\.json$/i, '.lua');
        fs.writeFileSync(outPath, lua, 'utf8');

        const rel = path.relative(process.cwd(), outPath) || outPath;
        console.log(`${path.basename(abs)} -> ${rel}  (${c.order.length} specs, profile "${c.profile}")`);
        if (c.unmapped.length) {
            console.warn('  WARNING: unmapped spec names (skipped): ' + c.unmapped.join(', '));
        }
    }
}

main();
