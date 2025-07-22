-- MonkBrewmaster.lua
-- Updated July 21, 2025 - Comprehensive Rework for MoP Classic
-- Mists of Pandaria module for Monk: Brewmaster spec

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass("player")
if playerClass ~= "MONK" then return end

local addon, ns = ...
local Hekili = _G[addon]
local class = Hekili.Class
local state = Hekili.State

-- Initialize state.items to prevent 'attempt to index field "items" (a nil value)' error
state.items = state.items or {}

-- Legacy function for compatibility
local function getReferences()
    return class, state
end

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

-- Enhanced helper functions for Brewmaster Monk
local function UA_GetPlayerAuraBySpellID(spellID)
    return FindUnitBuffByID("player", spellID)
end

local function GetTargetDebuffByID(spellID)
    return FindUnitDebuffByID("target", spellID, "PLAYER")
end

local function GetStaggerLevel()
    if FindUnitBuffByID("player", 124273) then return "heavy" end -- Heavy Stagger
    if FindUnitBuffByID("player", 124274) then return "moderate" end -- Moderate Stagger
    if FindUnitBuffByID("player", 124275) then return "light" end -- Light Stagger
    return "none"
end

local spec = Hekili:NewSpecialization(268) -- Brewmaster spec ID for MoP
if not spec then
    print("Brewmaster: Failed to initialize specialization (ID 268).")
    return
end

-- Brewmaster-specific combat log event tracking
local bmCombatLogFrame = CreateFrame("Frame")
local bmCombatLogEvents = {}

local function RegisterBMCombatLogEvent(event, handler)
    if not bmCombatLogEvents[event] then
        bmCombatLogEvents[event] = {}
    end
    table.insert(bmCombatLogEvents[event], handler)
end

bmCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
        
        if destGUID == UnitGUID("player") or sourceGUID == UnitGUID("player") then
            local handlers = bmCombatLogEvents[subevent]
            if handlers then
                for _, handler in ipairs(handlers) do
                    handler(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, select(12, CombatLogGetCurrentEventInfo()))
                end
            end
        end
    end
end)

bmCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Track Elusive Brew stacks
RegisterBMCombatLogEvent("SPELL_AURA_APPLIED_DOSE", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if destGUID == UnitGUID("player") and spellID == 128938 then -- Elusive Brew Stack
        local _, _, count = FindUnitBuffByID("player", 128938)
        state.buff.elusive_brew_stack.stack = count or 0
    end
end)

-- Track Stagger absorption
RegisterBMCombatLogEvent("SPELL_ABSORB", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, amount)
    if destGUID == UnitGUID("player") and (spellID == 124273 or spellID == 124274 or spellID == 124275) then
        state.stagger_absorbed = (state.stagger_absorbed or 0) + amount
    end
end)

-- Track Chi generation
RegisterBMCombatLogEvent("SPELL_CAST_SUCCESS", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if sourceGUID == UnitGUID("player") then
        if spellID == 100787 or spellID == 121253 then -- Tiger Palm, Keg Smash
            state.last_chi_ability = timestamp
        elseif spellID == 115180 then -- Dizzying Haze
            state.last_threat_ability = timestamp
        elseif spellID == 115308 then -- Elusive Brew activation
            state.buff.elusive_brew_stack.stack = 0
        end
    end
end)

-- Track Purifying Brew
RegisterBMCombatLogEvent("SPELL_DISPEL", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, extraSpellID)
    if sourceGUID == UnitGUID("player") and spellID == 119582 then -- Purifying Brew
        state.stagger_cleansed = (state.stagger_cleansed or 0) + 1
    end
end)

-- Enhanced Resource System
spec:RegisterResource(3, { -- Energy = 3 in MoP
    tiger_palm = {
        aura = "tiger_palm_energy",
        last = function()
            local app = state.buff.tiger_palm_energy.applied or state.query_time
            local t = state.query_time
            return app + math.floor((t - app) / 1.5) * 1.5
        end,
        interval = 1.5,
        value = function()
            local energy = 25
            if state.talent.ascension.enabled then energy = energy * 1.15 end
            if state.buff.power_strikes.up then energy = energy + 15 end
            return energy
        end,
    },
    jab = {
        aura = "jab_energy",
        last = function()
            local app = state.buff.jab_energy.applied or state.query_time
            local t = state.query_time
            return app + math.floor((t - app) / 2.0) * 2.0
        end,
        interval = 2.0,
        value = function()
            local energy = 40
            if state.talent.ascension.enabled then energy = energy * 1.15 end
            return energy
        end,
    },
    ascension = {
        aura = "ascension",
        last = function()
            local app = state.buff.ascension.applied or state.query_time
            local t = state.query_time
            return app + math.floor((t - app) / 1) * 1
        end,
        interval = 1,
        value = function()
            return state.talent.ascension.enabled and 2 or 0
        end,
    },
    energizing_brew = {
        aura = "energizing_brew",
        last = function()
            local app = state.buff.energizing_brew.applied or state.query_time
            local t = state.query_time
            return app + math.floor((t - app) / 1.5) * 1.5
        end,
        interval = 1.5,
        value = 20,
    },
}, {
    base_regen = function()
        local base = 10
        if state.talent.ascension.enabled then base = base * 1.15 end
        if state.buff.energizing_brew.up then base = base + 20 end
        return base
    end,
})

spec:RegisterResource(12, { -- Chi = 12 in MoP
    power_strikes = {
        aura = "power_strikes",
        last = function()
            local app = state.buff.power_strikes.applied or state.query_time
            local t = state.query_time
            return app + math.floor((t - app) / 20) * 20
        end,
        interval = 20,
        value = function()
            return state.talent.power_strikes.enabled and 1 or 0
        end,
    },
    chi_brew = {
        aura = "chi_brew",
        last = function()
            local app = state.buff.chi_brew.applied or state.query_time
            local t = state.query_time
            return app + math.floor((t - app) / 1) * 1
        end,
        interval = 1,
        value = function()
            return state.cooldown.chi_brew.remains == 0 and 2 or 0
        end,
    },
    keg_smash = {
        aura = "keg_smash",
        last = function()
            local app = state.ability.keg_smash.lastCast or state.query_time
            local t = state.query_time
            return app + math.floor((t - app) / 8) * 8
        end,
        interval = 8,
        value = 2,
    },
}, {
    max = function()
        return state.talent.ascension.enabled and 5 or 4
    end,
})

spec:RegisterResource(0, { -- Mana = 0 in MoP
    mana_tea = {
        aura = "mana_tea",
        last = function()
            local app = state.buff.mana_tea.applied or state.query_time
            local t = state.query_time
            return app + math.floor((t - app) / 1) * 1
        end,
        interval = 1,
        value = function()
            return state.buff.mana_tea.stack * 4000
        end,
    },
    meditation = {
        aura = "meditation",
        last = function()
            local app = state.buff.meditation.applied or state.query_time
            local t = state.query_time
            return app + math.floor((t - app) / 2) * 2
        end,
        interval = 2,
        value = function()
            local spirit = state.stat.spirit or 0
            return spirit * 0.5
        end,
    },
}, {
    base_regen = function()
        return state.stat.spirit and (state.stat.spirit * 0.5) or 0
    end,
})

-- Gear and Tier Sets
spec:RegisterGear("tier14", 85394, 85395, 85396, 85397, 85398) -- T14 LFR
spec:RegisterGear("tier14_normal", 85399, 85400, 85401, 85402, 85403) -- T14 Normal
spec:RegisterGear("tier14_heroic", 85404, 85405, 85406, 85407, 85408) -- T14 Heroic

spec:RegisterGear("tier15", 95832, 95833, 95834, 95835, 95836) -- T15 LFR
spec:RegisterGear("tier15_normal", 95837, 95838, 95839, 95840, 95841) -- T15 Normal
spec:RegisterGear("tier15_heroic", 95842, 95843, 95844, 95845, 95846) -- T15 Heroic
spec:RegisterGear("tier15_thunderforged", 95847, 95848, 95849, 95850, 95851) -- T15 Thunderforged

spec:RegisterGear("tier16", 98971, 98972, 98973, 98974, 98975) -- T16 LFR
spec:RegisterGear("tier16_normal", 98976, 98977, 98978, 98979, 98980) -- T16 Normal
spec:RegisterGear("tier16_heroic", 98981, 98982, 98983, 98984, 98985) -- T16 Heroic
spec:RegisterGear("tier16_mythic", 98986, 98987, 98988, 98989, 98990) -- T16 Mythic

spec:RegisterGear("legendary_cloak", 102246) -- Qian-Ying, Fortitude of Niuzao
spec:RegisterGear("legendary_cloak_agi", 102247) -- Qian-Le, Courage of Niuzao
spec:RegisterGear("haromms_talisman", 104780) -- Haromm's Talisman
spec:RegisterGear("thoks_tail_tip", 104605) -- Thok's Tail Tip
spec:RegisterGear("indomitable_primal", 76890) -- Indomitable Primal Diamond
spec:RegisterGear("austere_primal", 76885) -- Austere Primal Diamond

-- Tier Set Bonuses
spec:RegisterAura("tier14_2pc_tank", {
    id = 123456, -- Placeholder
    duration = 3600,
    max_stack = 1,
    generate = function(t)
        if state.set_bonus.tier14_2pc > 0 then
            t.name = "Yaungol Slayer 2pc"
            t.count = 1
            t.expires = state.query_time + 3600
            t.applied = state.query_time
            t.caster = "player"
            return
        end
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
    end,
})

spec:RegisterAura("tier14_4pc_tank", {
    id = 123457, -- Placeholder
    duration = 3600,
    max_stack = 1,
    generate = function(t)
        if state.set_bonus.tier14_4pc > 0 then
            t.name = "Yaungol Slayer 4pc"
            t.count = 1
            t.expires = state.query_time + 3600
            t.applied = state.query_time
            t.caster = "player"
            return
        end
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
    end,
})

spec:RegisterAura("tier15_2pc_tank", {
    id = 138229,
    duration = 3600,
    max_stack = 1,
    generate = function(t)
        if state.set_bonus.tier15_2pc > 0 then
            t.name = "Lightning Emperor 2pc"
            t.count = 1
            t.expires = state.query_time + 3600
            t.applied = state.query_time
            t.caster = "player"
            return
        end
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
    end,
})

spec:RegisterAura("tier15_4pc_tank", {
    id = 138230,
    duration = 3600,
    max_stack = 1,
    generate = function(t)
        if state.set_bonus.tier15_4pc > 0 then
            t.name = "Lightning Emperor 4pc"
            t.count = 1
            t.expires = state.query_time + 3600
            t.applied = state.query_time
            t.caster = "player"
            return
        end
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
    end,
})

spec:RegisterAura("tier16_2pc_tank", {
    id = 146987,
    duration = 3600,
    max_stack = 1,
    generate = function(t)
        if state.set_bonus.tier16_2pc > 0 then
            t.name = "Shattered Vale 2pc"
            t.count = 1
            t.expires = state.query_time + 3600
            t.applied = state.query_time
            t.caster = "player"
            return
        end
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
    end,
})

spec:RegisterAura("tier16_4pc_tank", {
    id = 146988,
    duration = 3600,
    max_stack = 1,
    generate = function(t)
        if state.set_bonus.tier16_4pc > 0 then
            t.name = "Shattered Vale 4pc"
            t.count = 1
            t.expires = state.query_time + 3600
            t.applied = state.query_time
            t.caster = "player"
            return
        end
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
    end,
})

-- Talents
spec:RegisterTalents({
    celerity = { 1, 1, 115173 },
    tigers_lust = { 1, 2, 116841 },
    momentum = { 1, 3, 115294 },
    chi_wave = { 2, 1, 115098 },
    zen_sphere = { 2, 2, 124081 },
    chi_burst = { 2, 3, 123986 },
    power_strikes = { 3, 1, 121817 },
    ascension = { 3, 2, 115396 },
    chi_brew = { 3, 3, 115399 },
    deadly_reach = { 4, 1, 126679 },
    charging_ox_wave = { 4, 2, 119392 },
    leg_sweep = { 4, 3, 119381 },
    healing_elixirs = { 5, 1, 122280 },
    dampen_harm = { 5, 2, 122278 },
    diffuse_magic = { 5, 3, 122783 },
    rushing_jade_wind = { 6, 1, 116847 },
    invoke_xuen = { 6, 2, 123904 },
    chi_torpedo = { 6, 3, 119085 },
})

-- Glyphs
spec:RegisterGlyphs({
    [125731] = "afterlife",
    [125872] = "blackout_kick",
    [125671] = "breath_of_fire",
    [125732] = "detox",
    [125757] = "enduring_healing_sphere",
    [125672] = "expel_harm",
    [125676] = "fighting_pose",
    [125687] = "fortifying_brew",
    [125677] = "guard",
    [123763] = "mana_tea",
    [125767] = "paralysis",
    [125755] = "retreat",
    [125678] = "spinning_crane_kick",
    [125750] = "surging_mist",
    [125932] = "targeted_expulsion",
    [125679] = "touch_of_death",
    [125680] = "transcendence",
    [125681] = "zen_meditation",
    [125682] = "keg_smash",
    [125683] = "purifying_brew",
    [125684] = "clash",
    [125685] = "elusive_brew",
    [125686] = "dizzying_haze",
    [125689] = "spear_hand_strike",
    [125690] = "nimble_brew",
    [125691] = "stoneskin",
    [125692] = "shuffle",
    [125693] = "healing_sphere",
    [125694] = "spinning_fire_blossom",
    [125695] = "tigers_lust",
    [125696] = "wind_through_the_reeds",
    [125697] = "crackling_jade_lightning",
    [125698] = "honor",
    [125699] = "spirit_roll",
    [125700] = "zen_flight",
    [125701] = "water_roll",
    [125702] = "jab",
    [125703] = "blackout_kick_visual",
    [125704] = "spinning_crane_kick_visual",
    [125705] = "breath_of_fire_visual",
    [125706] = "tiger_palm",
    [125707] = "ox_statue",
    [125708] = "rising_sun_kick",
    [125709] = "touch_of_karma",
    [125710] = "fortifying_brew_visual",
    [125711] = "guard_visual",
    [125712] = "transcendence_visual",
})

-- Statuses for Stagger
spec:RegisterStateTable("stagger", {
    __index = function(t, k)
        if k == "light" then
            return FindUnitBuffByID("player", 124275)
        elseif k == "moderate" then
            return FindUnitBuffByID("player", 124274)
        elseif k == "heavy" then
            return FindUnitBuffByID("player", 124273)
        elseif k == "any" then
            return FindUnitBuffByID("player", 124275) or FindUnitBuffByID("player", 124274) or FindUnitBuffByID("player", 124273)
        end
        return false
    end,
})

-- Auras
spec:RegisterAuras({
    moderate_stagger = {
        id = 124274,
        duration = 10,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 124274)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    heavy_stagger = {
        id = 124273,
        duration = 10,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 124273)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    light_stagger = {
        id = 124275,
        duration = 10,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 124275)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    elusive_brew = {
        id = 128939,
        duration = function() return state.buff.elusive_brew_stack.stack * 1 end,
        max_stack = 15,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 128939)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    elusive_brew_stack = {
        id = 128938,
        duration = 60,
        max_stack = 15,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 128938)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    guard = {
        id = 115295,
        duration = 30,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115295)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    shuffle = {
        id = 115307,
        duration = function()
            local base = 6
            if state.talent.rushing_jade_wind.enabled then base = base + 6 end
            if state.set_bonus.tier15_2pc > 0 then base = base + 2 end
            return base
        end,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115307)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    breath_of_fire = {
        id = 123725,
        duration = 8,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("target", 123725, "PLAYER")
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    keg_smash = {
        id = 121253,
        duration = 8,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("target", 121253, "PLAYER")
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    dizzying_haze = {
        id = 115180,
        duration = 15,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("target", 115180, "PLAYER")
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    fortifying_brew = {
        id = 120954,
        duration = function()
            return state.glyph.fortifying_brew.enabled and 25 or 20
        end,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 120954)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    zen_meditation = {
        id = 115176,
        duration = 8,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115176)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    power_strikes = {
        id = 129914,
        duration = 30,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 129914)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    ascension = {
        id = 115396,
        duration = 3600,
        max_stack = 1,
        generate = function(t)
            if state.talent.ascension.enabled then
                t.name = "Ascension"
                t.count = 1
                t.expires = state.query_time + 3600
                t.applied = state.query_time
                t.caster = "player"
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    dampen_harm = {
        id = 122278,
        duration = 45,
        max_stack = 3,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 122278)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    diffuse_magic = {
        id = 122783,
        duration = 6,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 122783)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    tigers_lust = {
        id = 116841,
        duration = 6,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 116841)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    momentum = {
        id = 119085,
        duration = 10,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 119085)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    chi_torpedo = {
        id = 119085,
        duration = 6,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 119085)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    rushing_jade_wind = {
        id = 116847,
        duration = 6,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 116847)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    invoke_xuen = {
        id = 123904,
        duration = 45,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 123904)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    mana_tea = {
        id = 115294,
        duration = 3600,
        max_stack = 20,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115294)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    energizing_brew = {
        id = 115288,
        duration = 6,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115288)
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    tiger_palm_energy = {
        id = 999001,
        duration = 3600,
        max_stack = 1,
        generate = function(t)
            t.name = "Tiger Palm Energy"
            t.count = 1
            t.expires = state.query_time + 3600
            t.applied = state.query_time
            t.caster = "player"
        end,
    },
    jab_energy = {
        id = 999002,
        duration = 3600,
        max_stack = 1,
        generate = function(t)
            t.name = "Jab Energy"
            t.count = 1
            t.expires = state.query_time + 3600
            t.applied = state.query_time
            t.caster = "player"
        end,
    },
    chi_brew = {
        id = 999003,
        duration = 3600,
        max_stack = 1,
        generate = function(t)
            t.name = "Chi Brew"
            t.count = 1
            t.expires = state.query_time + 3600
            t.applied = state.query_time
            t.caster = "player"
        end,
    },
})

-- Abilities
spec:RegisterAbilities({
    breath_of_fire = {
        id = 115181,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        spend = 1,
        spendType = "chi",
        startsCombat = true,
        texture = 571657,
        handler = function()
            applyDebuff("target", "breath_of_fire")
        end,
    },
    dizzying_haze = {
        id = 115180,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        spend = 20,
        spendType = "energy",
        startsCombat = true,
        texture = 614680,
        handler = function()
            applyDebuff("target", "dizzying_haze")
        end,
    },
    elusive_brew = {
        id = 115308,
        cast = 0,
        cooldown = 6,
        gcd = "off",
        toggle = "defensives",
        startsCombat = false,
        texture = 603532,
        buff = "elusive_brew_stack",
        usable = function() return state.buff.elusive_brew_stack.stack > 0 end,
        handler = function()
            local stacks = state.buff.elusive_brew_stack.stack
            if stacks > 0 then
                removeBuff("elusive_brew_stack")
                applyBuff("elusive_brew", math.min(stacks * 1, 15))
            end
        end,
    },
    fortifying_brew = {
        id = 115203,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        toggle = "defensives",
        startsCombat = false,
        texture = 432106,
        handler = function()
            applyBuff("fortifying_brew")
        end,
    },
    guard = {
        id = 115295,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        spend = 2,
        spendType = "chi",
        toggle = "defensives",
        startsCombat = false,
        texture = 611417,
        handler = function()
            applyBuff("guard")
        end,
    },
    keg_smash = {
        id = 121253,
        cast = 0,
        cooldown = 8,
        charges = 2,
        recharge = 8,
        gcd = "spell",
        spend = 40,
        spendType = "energy",
        startsCombat = true,
        texture = 594274,
        handler = function()
            applyDebuff("target", "keg_smash")
            gain(2, "chi")
            if math.random() < state.crit_chance then
                addStack("elusive_brew_stack", nil, 1)
            end
        end,
    },
    purifying_brew = {
        id = 119582,
        cast = 0,
        cooldown = 1,
        charges = 3,
        recharge = 15,
        gcd = "off",
        spend = 1,
        spendType = "chi",
        toggle = "defensives",
        startsCombat = false,
        texture = 595276,
        handler = function()
            if state.stagger.any then
                state.stagger_cleansed = (state.stagger_cleansed or 0) + 1
            end
        end,
    },
    shuffle = {
        id = 115307,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = 2,
        spendType = "chi",
        startsCombat = false,
        texture = 634317,
        handler = function()
            applyBuff("shuffle")
        end,
    },
    summon_black_ox_statue = {
        id = 115315,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        startsCombat = false,
        texture = 627606,
        handler = function()
            -- Summons statue
        end,
    },
    zen_meditation = {
        id = 115176,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        toggle = "defensives",
        startsCombat = false,
        texture = 642414,
        handler = function()
            applyBuff("zen_meditation")
        end,
    },
    chi_brew = {
        id = 115399,
        cast = 0,
        cooldown = 45,
        gcd = "off",
        talent = "chi_brew",
        startsCombat = false,
        texture = 647487,
        handler = function()
            gain(2, "chi")
            applyBuff("chi_brew")
        end,
    },
    chi_burst = {
        id = 123986,
        cast = 1,
        cooldown = 30,
        gcd = "spell",
        talent = "chi_burst",
        startsCombat = true,
        texture = 135734,
        handler = function()
            -- AoE damage/heal
        end,
    },
    chi_torpedo = {
        id = 115008,
        cast = 0,
        cooldown = 20,
        charges = 2,
        recharge = 20,
        gcd = "off",
        talent = "chi_torpedo",
        startsCombat = false,
        texture = 607849,
        handler = function()
            applyBuff("chi_torpedo")
        end,
    },
    chi_wave = {
        id = 115098,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        talent = "chi_wave",
        startsCombat = true,
        texture = 606541,
        handler = function()
            -- Bouncing damage/heal
        end,
    },
    dampen_harm = {
        id = 122278,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        talent = "dampen_harm",
        toggle = "defensives",
        startsCombat = false,
        texture = 620827,
        handler = function()
            applyBuff("dampen_harm")
        end,
    },
    diffuse_magic = {
        id = 122783,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        talent = "diffuse_magic",
        toggle = "defensives",
        startsCombat = false,
        texture = 612968,
        handler = function()
            applyBuff("diffuse_magic")
        end,
    },
    expel_harm = {
        id = 115072,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        spend = 40,
        spendType = "energy",
        startsCombat = true,
        texture = 627485,
        handler = function()
            gain(1, "chi")
        end,
    },
    jab = {
        id = 100780,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = 40,
        spendType = "energy",
        startsCombat = true,
        texture = 574573,
        handler = function()
            gain(1, "chi")
            if state.talent.power_strikes.enabled and state.cooldown.power_strikes.remains == 0 then
                gain(1, "chi")
                setCooldown("power_strikes", 20)
            end
        end,
    },
    leg_sweep = {
        id = 119381,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        talent = "leg_sweep",
        startsCombat = true,
        texture = 642414,
        handler = function()
            -- AoE stun
        end,
    },
    roll = {
        id = 109132,
        cast = 0,
        cooldown = function() return state.talent.celerity.enabled and 15 or 20 end,
        charges = function() return state.talent.celerity.enabled and 3 or 2 end,
        recharge = function() return state.talent.celerity.enabled and 15 or 20 end,
        gcd = "off",
        startsCombat = false,
        texture = 574574,
        handler = function()
            if state.talent.momentum.enabled then
                applyBuff("momentum")
            end
        end,
    },
    spear_hand_strike = {
        id = 116705,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        interrupt = true,
        toggle = "interrupts",
        startsCombat = true,
        texture = 608940,
        usable = function() return target.casting end,
        handler = function()
            interrupt()
        end,
    },
    spinning_crane_kick = {
        id = 101546,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = 40,
        spendType = "energy",
        startsCombat = true,
        texture = 606544,
        handler = function()
            if state.talent.power_strikes.enabled and state.cooldown.power_strikes.remains == 0 then
                gain(1, "chi")
                setCooldown("power_strikes", 20)
            end
        end,
    },
    tiger_palm = {
        id = 100787,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = 25,
        spendType = "energy",
        startsCombat = true,
        texture = 606551,
        handler = function()
            gain(1, "chi")
            if state.talent.power_strikes.enabled and state.cooldown.power_strikes.remains == 0 then
                gain(1, "chi")
                setCooldown("power_strikes", 20)
            end
        end,
    },
    tigers_lust = {
        id = 116841,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        spend = 1,
        spendType = "chi",
        talent = "tigers_lust",
        startsCombat = false,
        texture = 651727,
        handler = function()
            applyBuff("tigers_lust")
        end,
    },
    transcendence = {
        id = 101643,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        startsCombat = false,
        texture = 627608,
        handler = function()
            -- Creates spirit
        end,
    },
    transcendence_transfer = {
        id = 119996,
        cast = 0,
        cooldown = 25,
        gcd = "spell",
        startsCombat = false,
        texture = 627609,
        handler = function()
            -- Teleports to spirit
        end,
    },
    zen_sphere = {
        id = 124081,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = 1,
        spendType = "chi",
        talent = "zen_sphere",
        startsCombat = false,
        texture = 651728,
        handler = function()
            -- Applies HoT/DoT
        end,
    },
    invoke_xuen = {
        id = 123904,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        talent = "invoke_xuen",
        toggle = "cooldowns",
        startsCombat = true,
        texture = 620832,
        handler = function()
            applyBuff("invoke_xuen")
        end,
    },
})

-- Pets and Totems
spec:RegisterPet("xuen_the_white_tiger", 73967, "invoke_xuen", 45)
spec:RegisterTotem("black_ox_statue", 627607)

-- State Expressions
spec:RegisterStateExpr("stagger_pct", function()
    if state.buff.heavy_stagger.up then return 0.6
    elseif state.buff.moderate_stagger.up then return 0.4
    elseif state.buff.light_stagger.up then return 0.2
    else return 0 end
end)

spec:RegisterStateExpr("stagger_amount", function()
    if state.health.current == 0 then return 0 end
    local base_amount = state.health.max * 0.05
    if state.buff.heavy_stagger.up then return base_amount * 3
    elseif state.buff.moderate_stagger.up then return base_amount * 2
    elseif state.buff.light_stagger.up then return base_amount
    else return 0 end
end)

spec:RegisterStateExpr("effective_stagger", function()
    local amount = state.stagger_amount
    if state.buff.shuffle.up then
        amount = amount * 1.2
    end
    if state.set_bonus.tier16_2pc > 0 then
        amount = amount * 1.1
    end
    return amount
end)

spec:RegisterStateExpr("chi_cap", function()
    return state.talent.ascension.enabled and 5 or 4
end)

spec:RegisterStateExpr("energy_regen_rate", function()
    local base_rate = 10
    if state.talent.ascension.enabled then
        base_rate = base_rate * 1.15
    end
    if state.buff.energizing_brew.up then
        base_rate = base_rate + 20
    end
    return base_rate
end)

spec:RegisterStateExpr("should_purify", function()
    return state.stagger_amount > state.health.max * 0.08 and state.chi.current > 0
end)

-- Ranges
spec:RegisterRanges("keg_smash", "paralysis", "provoke", "crackling_jade_lightning")

-- Options
spec:RegisterOptions({
    enabled = true,
    aoe = 3,
    nameplates = true,
    nameplateRange = 8,
    damage = true,
    damageExpiration = 8,
    potion = "virmen_bite_potion",
    package = "Brewmaster",
})

-- Event Handler for Initialization
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        local _, playerClass = UnitClass("player")
        if playerClass ~= "MONK" then return end
        local specID = GetSpecializationInfo(GetSpecialization())
        if specID == 268 then
            state.items = state.items or {}
            if not class.abilities then
                print("Brewmaster: Hekili.Class.abilities is nil. Aborting.")
                return
            end
            if not spec then
                print("Brewmaster: Failed to initialize specialization (ID 268).")
                return
            end
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        state.items = state.items or {}
        for i = 0, 19 do
            local itemID = GetInventoryItemID("player", i)
            if itemID then
                state.items[itemID] = { equipped = true }
            end
        end
    end
end)

-- Register default pack
spec:RegisterPack("Brewmaster", 20250721, [[Hekili:T3vBVTTnu4FldiHr5osojoRZh7KvA3KRJvA2jDLA2jz1yvfbpquu6iqjvswkspfePtl6VGQIQUnbJeHAVQDcOWrbE86CaE4GUwDBB4CvC5m98jdNZzDX6w)v)V(i)h(jDV7GFWEh)9T6rhFQVnSVzsmypSlD2OXqskYJCKfpPWXt87zPkZGZVRSLAXYUYORTmYLwaXlyc8LkGusGO7469JwjTfTH0PwPbJaeivvLsvrfoeQtcGbWlG0A)Ff9)8jPyqXgkz5Qkz5kLRyR12Uco1veB5MUOfIMXnV2Nw8UqEkeUOLXMFtKUOMcEvjzmqssgiE37NuLYlP5NnNgEE5(vJDjgvCeXmQVShsbh(AfIigS2JOmiUeXm(KJ0JkOtQu0Ky)iYcJvqQrthQ(5Fcu5ILidEZjQ0CoYXj)USIip9kem)i81l2cOFLlk9cKGk5nuuDXZes)SEHXiZdLP1gpb968CvpxbSVDaPzgwP6ahsQWnRs)uOKnc0)]])

print("Brewmaster: Script loaded successfully.")
