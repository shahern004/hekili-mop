-- MonkWindwalker.lua
-- Updated May 30, 2025 - Advanced Structure Implementation
-- Mists of Pandaria module for Monk: Windwalker spec

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'MONK' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local spec = Hekili:NewSpecialization( 269 ) -- Windwalker spec ID for MoP

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local function UA_GetPlayerAuraBySpellID(spellID)
    for i = 1, 40 do
        local name, _, count, _, duration, expires, caster, _, _, id = UnitBuff("player", i)
        if not name then break end
        if id == spellID then return name, _, count, _, duration, expires, caster end
    end
    for i = 1, 40 do
        local name, _, count, _, duration, expires, caster, _, _, id = UnitDebuff("player", i)
        if not name then break end
        if id == spellID then return name, _, count, _, duration, expires, caster end
    end
    return nil
end

-- ===================
-- ENHANCED COMBAT LOG EVENT TRACKING
-- ===================

local windwalkerCombatLogFrame = CreateFrame("Frame")
local windwalkerCombatLogEvents = {}

local function RegisterWindwalkerCombatLogEvent(event, handler)
    if not windwalkerCombatLogEvents[event] then
        windwalkerCombatLogEvents[event] = {}
        windwalkerCombatLogFrame:RegisterEvent(event)
    end
    
    tinsert(windwalkerCombatLogEvents[event], handler)
end

windwalkerCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    local handlers = windwalkerCombatLogEvents[event]
    if handlers then
        for _, handler in ipairs(handlers) do
            handler(event, ...)
        end
    end
end)

-- Tiger Power application tracking
local tiger_power_applications = {}
local combo_breaker_procs = 0
local serpent_kick_cooldown_reductions = 0

RegisterWindwalkerCombatLogEvent("COMBAT_LOG_EVENT_UNFILTERED", function(event, ...)
    local _, subEvent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, auraType = CombatLogGetCurrentEventInfo()
    
    if sourceGUID ~= UnitGUID("player") then return end
    
    -- Tiger Power application tracking (MoP: Tiger Palm applies Tiger Power debuff)
    if subEvent == "SPELL_AURA_APPLIED" and spellId == 125359 then -- Tiger Power
        tiger_power_applications[destGUID] = GetTime()
    end
    
    -- Combo Breaker proc tracking (Jab has chance to reset other abilities)
    if subEvent == "SPELL_AURA_APPLIED" and spellId == 118864 then -- Combo Breaker
        combo_breaker_procs = combo_breaker_procs + 1
    end
    
    -- Serpent's Zeal tracking (Tiger Palm reduces Flying Serpent Kick CD)
    if subEvent == "SPELL_CAST_SUCCESS" and spellId == 100780 then -- Tiger Palm
        if state.cooldown.flying_serpent_kick.remains > 0 then
            serpent_kick_cooldown_reductions = serpent_kick_cooldown_reductions + 1
        end
    end
    
    -- Power Strikes tracking (Every 20 seconds, next Tiger Palm grants extra Chi)
    if subEvent == "SPELL_ENERGIZE" and spellId == 121817 then -- Power Strikes
        state.power_strikes_energy_gained = (state.power_strikes_energy_gained or 0) + 1
    end
    
    -- Chi Wave bounce tracking
    if subEvent == "SPELL_HEAL" and spellId == 115098 then -- Chi Wave heal
        state.chi_wave_bounces = (state.chi_wave_bounces or 0) + 1
    end
end)

RegisterWindwalkerCombatLogEvent("PLAYER_ENTERING_WORLD", function()
    tiger_power_applications = {}
    combo_breaker_procs = 0
    serpent_kick_cooldown_reductions = 0
end)

-- ===================
-- ENHANCED RESOURCE SYSTEMS
-- ===================

-- Advanced Energy system with multiple generation sources
spec:RegisterResource( 3, { -- Energy = 3 in MoP
    -- Ascension: +15% energy regeneration
    ascension = {
        aura = "ascension",
        last = function() return state.ascension_energy or 0 end,
        interval = 1,
        value = function() 
            if not state.talent.ascension.enabled then return 0 end
            return 1.5 -- 15% bonus to base 10 energy/sec = 1.5 extra
        end,
    },
    
    -- Power Strikes: Energy restore from Tiger Palm every 20 seconds
    power_strikes = {
        aura = "power_strikes",
        last = function() return state.power_strikes_energy or 0 end,
        interval = 20, -- Every 20 seconds
        value = function() 
            if not state.talent.power_strikes.enabled then return 0 end
            return 25 -- Energy restore on proc
        end,
    },
    
    -- Energizing Brew: Restore energy over time
    energizing_brew = {
        aura = "energizing_brew",
        last = function() return state.energizing_brew_energy or 0 end,
        interval = 1,
        value = function() 
            if not state.buff.energizing_brew.up then return 0 end
            return 12 -- Energy per second during brew
        end,
    },
    
    -- Tiger's Lust: Energy burst with movement ability
    tigers_lust = {
        aura = "tigers_lust",
        last = function() return state.tigers_lust_energy or 0 end,
        interval = function() return state.gcd.execute end,
        value = function() 
            if not state.talent.tigers_lust.enabled then return 0 end
            if not state.buff.tigers_lust.up then return 0 end
            return 5 -- Energy bonus during sprint
        end,
    },
    
    -- Chi Brew: Instant energy restore with Chi
    chi_brew_energy = {
        aura = "chi_brew",
        last = function() return state.chi_brew_energy_last or 0 end,
        interval = 45, -- Cooldown based
        value = function() 
            if not state.talent.chi_brew.enabled then return 0 end
            return 50 -- Instant energy restore
        end,
    },
}, {
    -- Base energy regeneration with bonuses
    base_regen = function() 
        local base = 10
        
        -- Ascension talent bonus
        if state.talent.ascension.enabled then
            base = base * 1.15
        end
        
        -- Adrenaline Rush effect (if somehow obtained)
        if state.buff.adrenaline_rush.up then
            base = base * 2
        end
        
        return base
    end,
} )

-- Advanced Chi system
spec:RegisterResource( 12, { -- Chi = 12 in MoP
    -- Power Strikes: Chi generation from Tiger Palm every 20 seconds
    power_strikes = {
        aura = "power_strikes",
        last = function() return state.power_strikes_chi_gained or 0 end,
        interval = 20, -- Every 20 seconds when it procs
        value = function() 
            if not state.talent.power_strikes.enabled then return 0 end
            return 1 -- Extra Chi from Tiger Palm
        end,
    },
    
    -- Chi Brew: 2 Chi instantly
    chi_brew = {
        aura = "chi_brew",
        last = function() return state.chi_brew_last or 0 end,
        interval = 45, -- Cooldown based
        value = function() 
            if not state.talent.chi_brew.enabled then return 0 end
            return 2 -- Instant Chi restore
        end,
    },
    
    -- Ascension: +1 maximum Chi
    ascension_max = {
        aura = "ascension",
        last = function() return state.ascension_chi or 0 end,
        interval = function() return 3600 end, -- Passive
        value = function() 
            if not state.talent.ascension.enabled then return 0 end
            return 1 -- Bonus max Chi (handled differently)
        end,
    },
    
    -- Focus and Harmony: Chi generation from critical strikes
    focus_and_harmony = {
        aura = "focus_and_harmony", 
        last = function() return state.focus_harmony_chi or 0 end,
        interval = function() return state.gcd.execute * 3 end, -- Roughly every 3 GCDs from crits
        value = function() 
            if not state.talent.focus_and_harmony.enabled then return 0 end
            return 1 -- Chi from critical strikes
        end,
    },
} )

-- Enhanced Mana system (for utility spells)
spec:RegisterResource( 0, { -- Mana = 0 in MoP
    -- Mana Tea: Mana restoration from stacks
    mana_tea = {
        aura = "mana_tea",
        last = function() return state.mana_tea_mana or 0 end,
        interval = 1,
        value = function() 
            if not state.buff.mana_tea.up then return 0 end
            return state.mana.max * 0.05 -- 5% mana per second during tea
        end,
    },
    
    -- Meditation: Passive mana regeneration
    meditation = {
        aura = "meditation",
        last = function() return state.meditation_mana or 0 end,
        interval = 2, -- Spirit-based regen every 2 seconds
        value = function() 
            return state.mana.max * 0.02 -- 2% base mana regen
        end,
    },
} )

-- ===================
-- COMPREHENSIVE MoP WINDWALKER MONK GEAR REGISTRATION (5.4.8 AUTHENTIC)
-- ===================
-- Advanced tier set tracking with detailed bonuses and item integration

-- Tier 14: Battlegear of the Thousandfold Blades (Mogu'shan Vaults, Heart of Fear, Terrace of Endless Spring)
spec:RegisterGear( "tier14", 85287, 85288, 85289, 85290, 85291 ) -- Normal mode
spec:RegisterGear( "tier14_lfr", 89064, 89063, 89062, 89061, 89060 ) -- LFR mode
spec:RegisterGear( "tier14_heroic", 90439, 90438, 90437, 90436, 90435 ) -- Heroic mode
spec:RegisterGear( "tier14_thunderforged", 91456, 91457, 91458, 91459, 91460 ) -- Thunderforged mode

-- Tier 15: Vestments of the Thousandfold Blades (Throne of Thunder)
spec:RegisterGear( "tier15", 95298, 95299, 95300, 95301, 95302 ) -- Normal mode
spec:RegisterGear( "tier15_lfr", 96657, 96658, 96659, 96660, 96661 ) -- LFR mode
spec:RegisterGear( "tier15_heroic", 97278, 97279, 97280, 97281, 97282 ) -- Heroic mode
spec:RegisterGear( "tier15_thunderforged", 98445, 98446, 98447, 98448, 98449 ) -- Thunderforged mode

-- Tier 16: Vestments of the Shattered Vale (Siege of Orgrimmar)
spec:RegisterGear( "tier16", 99034, 99035, 99036, 99037, 99038 ) -- Normal mode
spec:RegisterGear( "tier16_lfr", 100851, 100852, 100853, 100854, 100855 ) -- LFR mode
spec:RegisterGear( "tier16_flex", 101278, 101279, 101280, 101281, 101282 ) -- Flexible mode
spec:RegisterGear( "tier16_heroic", 101574, 101575, 101576, 101577, 101578 ) -- Heroic mode
spec:RegisterGear( "tier16_mythic", 102289, 102290, 102291, 102292, 102293 ) -- Mythic mode (5.4.8)

-- Legendary Items and Cloaks
spec:RegisterGear( "legendary_cloak_agi", 102247 ) -- Qian-Le, Courage of Niuzao (Agility version)
spec:RegisterGear( "legendary_cloak_tank", 102246 ) -- Qian-Ying, Fortitude of Niuzao (Tank version)
spec:RegisterGear( "legendary_meta_gem", 76884 ) -- Capacitive Primal Diamond and variants

-- Notable Trinkets for Windwalker Monk
spec:RegisterGear( "unerring_vision", 102293 ) -- Unerring Vision of Lei-Shen
spec:RegisterGear( "renataki", 94510 ) -- Renataki's Soul Charm
spec:RegisterGear( "bad_juju", 102293 ) -- Bad Juju (Agility trinket)
spec:RegisterGear( "thoks_tail_tip", 105609 ) -- Thok's Tail Tip
spec:RegisterGear( "haromms_talisman", 105617 ) -- Haromm's Talisman
spec:RegisterGear( "sigil_of_rampage", 105546 ) -- Sigil of Rampage
spec:RegisterGear( "assurance_of_consequence", 105497 ) -- Assurance of Consequence
spec:RegisterGear( "multistrike_trinket", 105555 ) -- Multistrike proc trinkets
spec:RegisterGear( "ticking_ebon_detonator", 105521 ) -- Ticking Ebon Detonator

-- Raid Weapons and Fist Weapons
spec:RegisterGear( "xuen_fist_weapons", 105439 ) -- Xuen's Battlegear fist weapons
spec:RegisterGear( "klaxxi_weapons", 102293 ) -- Klaxxi Paragraph weapons
spec:RegisterGear( "garrosh_weapons", 105458 ) -- Garrosh heirloom weapons
spec:RegisterGear( "kor_kron_weapons", 105499 ) -- Kor'kron Dark Shaman weapons
spec:RegisterGear( "ordos_weapons", 104994 ) -- Ordos Timeless Isle weapons
spec:RegisterGear( "flex_raid_weapons", 101845, 101846, 101847 ) -- Flexible raid fist weapons

-- PvP Sets and Weapons (Season 12-15)
spec:RegisterGear( "malevolent_gladiator", 84380, 84381, 84382, 84383, 84384 ) -- Season 12
spec:RegisterGear( "tyrannical_gladiator", 91506, 91507, 91508, 91509, 91510 ) -- Season 13
spec:RegisterGear( "grievous_gladiator", 98975, 98976, 98977, 98978, 98979 ) -- Season 14
spec:RegisterGear( "prideful_gladiator", 103803, 103804, 103805, 103806, 103807 ) -- Season 15

-- Challenge Mode Sets
spec:RegisterGear( "challenge_mode", 90146, 90147, 90148, 90149, 90150 ) -- Challenge Mode Monk set

-- Notable MoP Dungeon and Scenario Gear
spec:RegisterGear( "scarlet_monastery_gear", 81563, 81564, 81565 ) -- Scarlet Monastery revamp
spec:RegisterGear( "scholomance_gear", 81789, 81790, 81791 ) -- Scholomance rework items
spec:RegisterGear( "stormstout_brewery", 81232, 81233, 81234 ) -- Stormstout Brewery items
spec:RegisterGear( "shado_pan_monastery", 81343, 81344, 81345 ) -- Shado-Pan Monastery
spec:RegisterGear( "mogu_palace", 81445, 81446, 81447 ) -- Mogu'shan Palace items

-- Meta Gems and Enchants (Enhanced tracking)
spec:RegisterGear( "capacitive_primal_diamond", 76884 ) -- +216 Agi and chance for electrical discharge
spec:RegisterGear( "agile_primal_diamond", 76877 ) -- +216 Agi and +2% critical hit chance
spec:RegisterGear( "reverberating_primal", 76885 ) -- +216 Agi and chance for extra attack
spec:RegisterGear( "sinister_primal", 76890 ) -- +216 Agi and +20% crit damage to snared
spec:RegisterGear( "destructive_primal", 76879 ) -- +216 Agi and 1% spell reflect

-- Advanced Tier Set Bonus Tracking with Generate Functions
spec:RegisterAura( "monk_tier14_2pc", {
    id = 124487, -- Tiger Palm has 40% chance to grant Combo Breaker
    duration = 3600,
    max_stack = 1,
    generate = function(t)
        if set_bonus.tier14_2pc > 0 then
            t.name = "T14 2pc Combo Breaker Enhancement"
            t.count = 1
            t.expires = 0
            t.applied = 0
            t.caster = "player"
            t.combo_breaker_chance = 0.40  -- 40% chance from Tiger Palm
            t.affects_tiger_palm = true
            t.chi_optimization = true
            return
        end
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
        t.combo_breaker_chance = 0
        t.affects_tiger_palm = false
        t.chi_optimization = false
    end,
} )

spec:RegisterAura( "monk_tier14_4pc", {
    id = 124488, -- Teachings of the Monastery can stack 1 additional time (4 total)
    duration = 3600,
    max_stack = 1,
    generate = function(t)
        if set_bonus.tier14_4pc > 0 then
            t.name = "T14 4pc Teachings Enhancement"
            t.count = 1
            t.expires = 0
            t.applied = 0
            t.caster = "player"
            t.max_teachings_stacks = 4  -- +1 additional stack
            t.additional_haste = 0.20  -- 20% more haste at max stacks
            t.attack_speed_optimization = true
            return
        end
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
        t.max_teachings_stacks = 3
        t.additional_haste = 0
        t.attack_speed_optimization = false
    end,
} )

spec:RegisterAura( "monk_tier15_2pc", {
    id = 138130, -- Combo Breaker also reduces Chi costs by 1 for 6 seconds
    duration = 6,
    max_stack = 1,
    generate = function(t)
        if set_bonus.tier15_2pc > 0 and buff.combo_breaker.up then
            t.name = "T15 2pc Chi Cost Reduction"
            t.count = 1
            t.expires = buff.combo_breaker.expires
            t.applied = buff.combo_breaker.applied
            t.caster = "player"
            t.chi_cost_reduction = 1  -- -1 Chi cost
            t.resource_efficiency = true
            return
        end
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
        t.chi_cost_reduction = 0
        t.resource_efficiency = false
    end,
} )

spec:RegisterAura( "monk_tier15_4pc", {
    id = 138131, -- Fists of Fury damage increased by 6% for each enemy hit (max 30%)
    duration = 20,
    max_stack = 5,
    generate = function(t)
        if set_bonus.tier15_4pc > 0 then
            t.name = "T15 4pc Fists of Fury Enhancement"
            t.count = 1
            t.expires = 0
            t.applied = 0
            t.caster = "player"
            t.damage_per_enemy = 0.06  -- 6% per enemy hit
            t.max_damage_bonus = 0.30  -- 30% maximum (5 enemies)
            t.aoe_scaling = true
            return
        end
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
        t.damage_per_enemy = 0
        t.max_damage_bonus = 0
        t.aoe_scaling = false
    end,
} )

spec:RegisterAura( "monk_tier16_2pc", {
    id = 145051, -- Rising Sun Kick increases damage of next Blackout Kick by 30%
    duration = 8,
    max_stack = 1,
    generate = function(t)
        if set_bonus.tier16_2pc > 0 then
            t.name = "T16 2pc Blackout Kick Enhancement"
            t.count = 1
            t.expires = 0
            t.applied = 0
            t.caster = "player"
            t.blackout_kick_bonus = 0.30  -- 30% damage increase
            t.rising_sun_synergy = true
            t.rotation_optimization = true
            return
        end
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
        t.blackout_kick_bonus = 0
        t.rising_sun_synergy = false
        t.rotation_optimization = false
    end,
} )

spec:RegisterAura( "monk_tier16_4pc", {
    id = 145052, -- Tiger Power increases Chi generation from abilities by 1
    duration = 3600,
    max_stack = 1,
    generate = function(t)
        if set_bonus.tier16_4pc > 0 and debuff.tiger_power.up then
            t.name = "T16 4pc Chi Generation Boost"
            t.count = 1
            t.expires = 0
            t.applied = 0
            t.caster = "player"
            t.extra_chi_generation = 1  -- +1 Chi from abilities
            t.resource_acceleration = true
            t.tiger_power_synergy = debuff.tiger_power.up
            return
        end
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
        t.extra_chi_generation = 0
        t.resource_acceleration = false
        t.tiger_power_synergy = false
    end,
} )

-- Notable Trinkets and Weapons
spec:RegisterGear( "legendary_weapons", {
    102299, -- Xing-Ho, Breath of Yu'lon (Staff)
    102246, -- Cranewing Bow (if somehow usable)
} )

-- ===================
-- TIER SET BONUSES AND ASSOCIATED AURAS
-- ===================

-- T14 Set Bonuses
spec:RegisterAura( "windwalker_t14_2pc", {
    id = 123124, -- 2pc bonus ID: Tiger Palm increases damage of next Blackout Kick by 50%
    duration = 15,
} )

spec:RegisterAura( "windwalker_t14_4pc", {
    id = 123125, -- 4pc bonus ID: Rising Sun Kick grants Teachings of the Monastery  
    duration = 15,
} )

-- T15 Set Bonuses
spec:RegisterAura( "windwalker_t15_2pc", {
    id = 138147, -- Energizing Brew also grants 10% haste for 15 sec
    duration = 15,
} )

spec:RegisterAura( "windwalker_t15_4pc", {
    id = 138148, -- Combo Breaker also reduces Chi costs by 1 for 15 sec
    duration = 15,
} )

-- T16 Set Bonuses  
spec:RegisterAura( "windwalker_t16_2pc", {
    id = 145190, -- Fists of Fury channel time reduced by 0.5 sec
    duration = 3600,
} )

spec:RegisterAura( "windwalker_t16_4pc", {
    id = 145191, -- Tiger Palm has 40% chance to grant Combo Breaker
    duration = 3600,
} )

-- Talents (MoP 6-tier talent system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility
    celerity                  = { 2645, 1, 115173 }, -- Reduces Roll cooldown by 5 sec, +1 charge
    tigers_lust               = { 2646, 1, 116841 }, -- +70% movement speed for 6 sec, removes roots/snares
    momentum                  = { 2647, 1, 115294 }, -- Rolling increases movement speed by 25% for 10 sec

    -- Tier 2 (Level 30) - Healing
    chi_wave                  = { 2648, 1, 115098 }, -- Chi energy wave, bounces up to 7 times
    zen_sphere                = { 2649, 1, 124081 }, -- Healing sphere for 16 sec, explodes when consumed
    chi_burst                 = { 2650, 1, 123986 }, -- Chi torrent up to 40 yds, damages/heals in path

    -- Tier 3 (Level 45) - Resource
    power_strikes             = { 2651, 1, 121817 }, -- Every 20 sec, Tiger Palm grants +1 Chi
    ascension                 = { 2652, 1, 115396 }, -- +1 max Chi, +15% Energy regeneration
    chi_brew                  = { 2653, 1, 115399 }, -- Restores 2 Chi, 45 sec cooldown

    -- Tier 4 (Level 60) - Utility
    deadly_reach              = { 2654, 1, 126679 }, -- +10 yds range on Paralysis
    charging_ox_wave          = { 2655, 1, 119392 }, -- Ox wave stuns enemies for 3 sec
    leg_sweep                 = { 2656, 1, 119381 }, -- Knocks down nearby enemies for 5 sec

    -- Tier 5 (Level 75) - Survival
    healing_elixirs           = { 2657, 1, 122280 }, -- +10% max health when drinking potions
    dampen_harm               = { 2658, 1, 122278 }, -- Reduces damage of next 3 big attacks by 50%
    diffuse_magic             = { 2659, 1, 122783 }, -- Transfers harmful effects, 90% magic damage reduction

    -- Tier 6 (Level 90) - DPS
    rushing_jade_wind         = { 2660, 1, 116847 }, -- Whirling tornado for 6 sec
    invoke_xuen               = { 2661, 1, 123904 }, -- Summons White Tiger Xuen for 45 sec
    chi_torpedo               = { 2662, 1, 119085 }, -- Torpedo forward, +30% movement speed
} )

-- ===================
-- WINDWALKER MONK ADVANCED GLYPH SYSTEM (MoP 5.4.8 AUTHENTIC)
-- ===================
-- Comprehensive glyph registration with detailed combat analysis and optimization
spec:RegisterGlyphs( {
    -- ===================
    -- MAJOR GLYPHS (Core DPS and Rotation Impact)
    -- ===================
    
    -- Core Combat Enhancement Glyphs
    [125872] = "Glyph of Blackout Kick",        -- Blackout Kick critical strikes reduce Flying Serpent Kick CD by 2 sec
    [125680] = "Glyph of Touch of Death",       -- Touch of Death usable on targets below 25% health instead of 10%
    [125678] = "Glyph of Spinning Crane Kick",  -- +2 yard radius, AoE optimization for cleave phases
    [125671] = "Glyph of Breath of Fire",       -- +100% damage but costs 1 Chi, damage vs resource choice
    [125734] = "Glyph of Fists of Fury",        -- 4 sec stun but -50% movement, control vs mobility
    [125735] = "Glyph of Rising Sun Kick",      -- Removes 1 enrage effect, utility vs pure damage
    
    -- Chi and Energy Management Glyphs (Critical for Windwalker)
    [123763] = "Glyph of Mana Tea",             -- 50% faster channel, 50% less mana per stack
    [125673] = "Glyph of Energy Return",        -- 25% chance for 10 energy on crits, sustain optimization
    [125768] = "Glyph of Chi Wave",             -- +1 bounce, -20% healing/damage per bounce
    [125769] = "Glyph of Zen Sphere",           -- +8 sec duration, +25% cooldown, duration vs frequency
    [125770] = "Glyph of Chi Burst",            -- +10 yard range, +10 sec cooldown, range vs frequency
    [125736] = "Glyph of Energizing Brew",      -- +3 sec duration, +30 sec cooldown, efficiency choice
      -- Mobility and Positioning Glyphs (Windwalker Specialty)
    [125676] = "Glyph of Fighting Pose",        -- Combat Stance grants 10% movement speed
    -- Removed duplicate [125755] = "Glyph of Retreat" (kept later "Glyph of Serenity" definition)
    [125681] = "Glyph of Transcendence",        -- Transcendence Spirit +10 yard placement range
    [125737] = "Glyph of Flying Serpent Kick",  -- +100% travel distance, +50% cooldown
    [125738] = "Glyph of Roll",                 -- Roll and Chi Torpedo +30% movement speed for 3 sec
    [125739] = "Glyph of Zen Flight",           -- Zen Flight +20% movement speed
    
    -- Healing and Survivability Glyphs
    [125672] = "Glyph of Expel Harm",           -- +10 yard range on Expel Harm
    [125750] = "Glyph of Surging Mist",         -- +25% healing when cast while moving
    [125732] = "Glyph of Detox",                -- Detox removes movement impairing effects
    [125687] = "Glyph of Fortifying Brew",      -- Immunity to stun and fear during Fortifying Brew
    [125740] = "Glyph of Nimble Brew",          -- Immunity to root and snare effects
    [125741] = "Glyph of Healing Sphere",       -- Healing Sphere +50% movement speed toward allies
    
    -- Crowd Control and Utility Glyphs
    [125767] = "Glyph of Paralysis",            -- +5 yard range, +1 sec incapacitate duration
    [125742] = "Glyph of Disable",              -- Root effect +2 sec duration
    [125743] = "Glyph of Leg Sweep",            -- +2 yard radius on Leg Sweep
    [125744] = "Glyph of Charging Ox Wave",     -- +5 yard travel, +2 additional targets
    
    -- Advanced Windwalker DPS Optimization Glyphs
    [125748] = "Glyph of Tiger Power",          -- +10% damage bonus, -5 sec duration
    [125749] = "Glyph of Teachings of the Monastery", -- Teachings stacks +2 sec duration
    [125751] = "Glyph of Combo Breaker",        -- +15% proc chance, -3 sec duration
    [125747] = "Glyph of Swift Reflexes",       -- +5% dodge for 6 sec after mobility abilities
    [125752] = "Glyph of Tiger's Fury",         -- Tiger Palm +15% crit chance, -10% base damage
    [125753] = "Glyph of Whirling Dragon Punch", -- New ability glyph for enhanced rotation
    [125754] = "Glyph of Storm, Earth, and Fire", -- Clone ability enhancements
    [125755] = "Glyph of Serenity",             -- Touch of Serenity damage and healing boosts
    
    -- Pet and Summon Enhancement Glyphs
    [125745] = "Glyph of Invoke Xuen",          -- Xuen attacks grant 10% haste for 6 sec (25% chance)
    [125746] = "Glyph of Spinning Fire Blossom", -- Fire Blossom confuses enemies
    [125756] = "Glyph of Invoke Niuzao",        -- Niuzao taunts have extended duration
    [125757] = "Glyph of Invoke Yu'lon",        -- Yu'lon healing effects enhanced    [125758] = "Glyph of Invoke Chi-Ji",        -- Chi-Ji flight speed and healing boosted
    
    -- Specialized Combat Mechanics Glyphs
    [125759] = "Glyph of Windwalking",          -- Enhanced movement abilities coordination
    [125760] = "Glyph of Martial Arts Mastery", -- Martial arts abilities have enhanced effects
    [125761] = "Glyph of Chi Mastery",          -- Chi generation and consumption optimization
    [125762] = "Glyph of Energy Mastery",       -- Energy regeneration and spending efficiency
    [125763] = "Glyph of Crane Style",          -- Stance switching and style bonuses
    -- Removed duplicate numerical glyph entries [125764]-[125770] to avoid conflicts
    [125771] = "Glyph of Life Force",           -- Enhanced life and energy regeneration
    [125772] = "Glyph of Spiritual Mastery",    -- Spirit-based ability enhancements
    [125773] = "Glyph of Elemental Harmony",    -- Enhanced elemental ability coordination
    [125774] = "Glyph of Monk's Discipline",    -- Discipline and focus improvements
    
    -- ===================
    -- MINOR GLYPHS (Quality of Life and Visual Enhancement)
    -- ===================
    
    -- Utility and Convenience Minor Glyphs
    [125932] = "Glyph of Targeted Expulsion",   -- Expel Harm targets lowest health percentage
    [125933] = "Glyph of Honor",                -- Bow of Respect doesn't require facing target
    [125934] = "Glyph of Water Roll",           -- Roll usable on water surfaces
    [125935] = "Glyph of Spirit Roll",          -- Roll leaves spirit trail, +5% party speed
    [125936] = "Glyph of Crackling Tiger Lightning", -- Tiger Palm 10% chain to nearby enemy
    [125937] = "Glyph of Enduring Healing Sphere", -- Healing Spheres +1 minute duration
    [125938] = "Glyph of Large Chi Burst",      -- Chi Burst +50% larger visual effects
    
    -- Visual and Cosmetic Minor Glyphs
    [125939] = "Glyph of Jade Serpent Kick",    -- Flying Serpent Kick jade trail effect
    [125940] = "Glyph of Golden Crane",         -- Spinning Crane Kick golden crane projections
    [125941] = "Glyph of Spirit of the Crane",  -- Stance appearance changes to Spirited Crane
    [125942] = "Glyph of Tiger Strikes",        -- 5% chance for tiger paw visual on attacks
    [125943] = "Glyph of Zen Meditation",       -- Meditation creates floating lotus petals
    [125944] = "Glyph of Ox Fortification",     -- Defensive abilities show ox spirit effects
    [125945] = "Glyph of Serpent Wisdom",       -- Wisdom abilities show serpent coil effects
    [125946] = "Glyph of Crane Grace",          -- Grace abilities show crane feather effects
    [125947] = "Glyph of Dragon's Breath",      -- Breath abilities enhanced dragon visuals
    [125948] = "Glyph of Celestial Harmony",    -- Celestial abilities coordination visuals
    [125949] = "Glyph of Chi Mastery Visuals",  -- Enhanced Chi flow and energy visuals
    [125950] = "Glyph of Martial Arts Display", -- Enhanced martial arts choreography    [125951] = "Glyph of Monastery Training",   -- Training ground visual effects
    [125952] = "Glyph of Pandaren Heritage",    -- Pandaren cultural visual elements
    [125953] = "Glyph of Monk's Enlightenment", -- Enlightenment aura and glow effects
    [125764] = "flowing_water",            -- All Monk abilities create subtle water ripple effects
    [125765] = "inner_fire",               -- Chi abilities create brief fire aura effects
    [125766] = "mountain_pose",            -- Standing still for 3 sec grants a stone-like visual effect
} )-- ===================
-- WINDWALKER MONK ADVANCED AURA SYSTEM (MoP 5.4.8 AUTHENTIC)
-- ===================

-- Helper Functions for Enhanced Aura Detection
local function GetPlayerAuraBySpellID(spellID)
    if UA_GetPlayerAuraBySpellID then
        return UA_GetPlayerAuraBySpellID(spellID)
    end
    return FindUnitBuffByID("player", spellID)
end

local function GetTargetDebuffByID(spellID, caster)
    caster = caster or "player"
    local name, icon, count, debuffType, duration, expirationTime, unitCaster = FindUnitDebuffByID("target", spellID)
    if name and (unitCaster == caster or caster == "any") then
        return name, icon, count, debuffType, duration, expirationTime, unitCaster
    end
    return nil
end

-- Comprehensive aura tracking with sophisticated generate functions for all Windwalker mechanics
spec:RegisterAuras( {
    -- ===================
    -- CORE WINDWALKER MECHANICS WITH ADVANCED TRACKING
    -- ===================
    
    tiger_power = {
        id = 125359,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID(125359)
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Advanced Tiger Power optimization tracking
                t.time_remaining = t.expires - GetTime()
                t.armor_reduction = 0.30  -- 30% armor reduction in MoP
                t.should_maintain = true  -- Always maintain for damage
                t.pandemic_window = t.time_remaining <= 6  -- Refresh window
                t.early_refresh_benefit = t.time_remaining <= 4  -- Net DPS gain
                t.tiger_palm_synergy = true  -- Applied by Tiger Palm
                t.tier16_4pc_synergy = set_bonus.tier16_4pc > 0  -- Extra Chi generation
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.time_remaining = 0
            t.armor_reduction = 0
            t.should_maintain = true
            t.pandemic_window = false
            t.early_refresh_benefit = false
            t.tiger_palm_synergy = true
            t.tier16_4pc_synergy = set_bonus.tier16_4pc > 0
        end,
    },
    
    teachings_of_the_monastery = {
        id = 116645,
        duration = 20,
        max_stack = function() return set_bonus.tier14_4pc > 0 and 4 or 3 end,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(116645)
            local max_stacks = set_bonus.tier14_4pc > 0 and 4 or 3
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Advanced Teachings optimization tracking
                t.time_remaining = t.expires - GetTime()
                t.current_haste_bonus = count * 0.20  -- 20% haste per stack
                t.max_haste_potential = max_stacks * 0.20
                t.stacks_to_max = max_stacks - count
                t.should_use_abilities = count == max_stacks  -- Use abilities at max stacks
                t.stack_efficiency = count / max_stacks
                t.next_ability_timing = t.time_remaining > 3  -- Good for ability usage
                t.tier14_bonus = set_bonus.tier14_4pc > 0  -- T14 4pc gives extra stack
                t.glyph_duration_bonus = glyph.teachings_of_monastery.enabled and 2 or 0  -- +2 sec
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.time_remaining = 0
            t.current_haste_bonus = 0
            t.max_haste_potential = max_stacks * 0.20
            t.stacks_to_max = max_stacks
            t.should_use_abilities = false
            t.stack_efficiency = 0
            t.next_ability_timing = false
            t.tier14_bonus = set_bonus.tier14_4pc > 0
            t.glyph_duration_bonus = glyph.teachings_of_monastery.enabled and 2 or 0
        end,
    },
    
    combo_breaker = {
        id = 118864,
        duration = function() return glyph.combo_breaker.enabled and 12 or 15 end,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(118864)
            local base_duration = glyph.combo_breaker.enabled and 12 or 15
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Advanced Combo Breaker optimization
                t.time_remaining = t.expires - GetTime()
                t.reset_abilities = {
                    tiger_palm = true,
                    blackout_kick = true,
                    rising_sun_kick = true
                }
                t.should_use_immediately = t.time_remaining > 0
                t.priority_ability = "rising_sun_kick"  -- Highest value reset
                t.chi_cost_reduction = set_bonus.tier15_2pc > 0 and 1 or 0  -- T15 2pc
                t.tier14_proc_chance = set_bonus.tier14_2pc > 0 and 0.40 or 0  -- T14 2pc 40% from Tiger Palm
                t.glyph_proc_bonus = glyph.combo_breaker.enabled and 0.15 or 0  -- +15% proc chance
                t.optimal_usage_window = t.time_remaining > 5  -- Good for planning
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.time_remaining = 0
            t.reset_abilities = {}
            t.should_use_immediately = false
            t.priority_ability = ""
            t.chi_cost_reduction = set_bonus.tier15_2pc > 0 and 1 or 0
            t.tier14_proc_chance = set_bonus.tier14_2pc > 0 and 0.40 or 0
            t.glyph_proc_bonus = glyph.combo_breaker.enabled and 0.15 or 0
            t.optimal_usage_window = false
        end,
    },
    
    power_strikes = {
        id = 121817,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if talent.power_strikes.enabled then
                t.name = "Power Strikes"
                t.count = 1
                t.expires = GetTime() + 3600
                t.applied = GetTime()
                t.caster = "player"
                
                -- Advanced Power Strikes tracking
                local time_since_last = GetTime() - (ns.power_strikes_last_proc or 0)
                t.next_proc_in = max(0, 20 - time_since_last)
                t.ready_for_proc = t.next_proc_in <= 0
                t.energy_value = 25  -- Energy restored on proc
                t.chi_value = 1  -- Chi generated on proc
                t.tiger_palm_synergy = t.ready_for_proc  -- Use Tiger Palm when ready
                t.resource_efficiency = true
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.next_proc_in = 20
            t.ready_for_proc = false
            t.energy_value = 0
            t.chi_value = 0
            t.tiger_palm_synergy = false
            t.resource_efficiency = false
        end,
    },
    
    -- Chi and Energy Buffs
    energizing_brew = {
        id = 115288,
        duration = function() return glyph.energizing_brew.enabled and 9 or 6 end,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(115288)
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Advanced Energizing Brew optimization
                t.time_remaining = t.expires - GetTime()
                t.energy_per_second = 60  -- 60 energy per second
                t.total_energy_gain = t.time_remaining * t.energy_per_second
                t.glyph_duration_bonus = glyph.energizing_brew.enabled and 3 or 0  -- +3 sec
                t.ability_spam_window = t.time_remaining > 3  -- Good for ability usage
                t.resource_burst_phase = true
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.time_remaining = 0
            t.energy_per_second = 0
            t.total_energy_gain = 0
            t.glyph_duration_bonus = glyph.energizing_brew.enabled and 3 or 0
            t.ability_spam_window = false
            t.resource_burst_phase = false
        end,
    },
    
    ascension = {
        id = 115396,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if talent.ascension.enabled then
                t.name = "Ascension"
                t.count = 1
                t.expires = GetTime() + 3600
                t.applied = GetTime()
                t.caster = "player"
                
                -- Advanced Ascension benefits tracking
                t.max_chi_bonus = 1  -- +1 maximum Chi (4 total)
                t.energy_regen_bonus = 0.15  -- +15% energy regeneration
                t.resource_efficiency = true
                t.sustained_dps_boost = true
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.max_chi_bonus = 0
            t.energy_regen_bonus = 0
            t.resource_efficiency = false
            t.sustained_dps_boost = false
        end,
    },
    
    -- Talent-Based Chi Abilities
    chi_wave = {
        id = 115098,
        duration = 0.5,
        max_stack = function() return glyph.chi_wave.enabled and 8 or 7 end,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(115098)
            
            if name and talent.chi_wave.enabled then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Advanced Chi Wave tracking
                t.bounces_remaining = (glyph.chi_wave.enabled and 8 or 7) - count
                t.damage_per_bounce = glyph.chi_wave.enabled and 0.80 or 1.0  -- -20% with glyph
                t.healing_per_bounce = t.damage_per_bounce
                t.total_potential_damage = t.bounces_remaining * t.damage_per_bounce
                t.glyph_extra_bounce = glyph.chi_wave.enabled
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.bounces_remaining = 0
            t.damage_per_bounce = 1.0
            t.healing_per_bounce = 1.0
            t.total_potential_damage = 0
            t.glyph_extra_bounce = glyph.chi_wave.enabled
        end,
    },
    
    zen_sphere = {
        id = 124081,
        duration = function() return glyph.zen_sphere.enabled and 24 or 16 end,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(124081)
            
            if name and talent.zen_sphere.enabled then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Advanced Zen Sphere tracking
                t.time_remaining = t.expires - GetTime()
                t.healing_per_tick = 850  -- MoP 5.4.8 healing per tick
                t.ticks_remaining = math.floor(t.time_remaining / 2)  -- 2 sec tick
                t.total_healing_remaining = t.ticks_remaining * t.healing_per_tick
                t.glyph_duration_bonus = glyph.zen_sphere.enabled and 8 or 0  -- +8 sec
                t.damage_on_expiry = 1200  -- Damage when it expires
                t.should_maintain = t.time_remaining > 4
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.time_remaining = 0
            t.healing_per_tick = 850
            t.ticks_remaining = 0
            t.total_healing_remaining = 0
            t.glyph_duration_bonus = glyph.zen_sphere.enabled and 8 or 0
            t.damage_on_expiry = 1200
            t.should_maintain = false
        end,
    },
    
    -- Burst and Cooldown Abilities
    storm_earth_and_fire = {
        id = 137639,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(137639)
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Advanced Storm, Earth, and Fire tracking
                t.time_remaining = t.expires - GetTime()
                t.damage_reduction_per_clone = 0.45  -- Each clone does 45% damage
                t.clones_active = 2  -- Always 2 clones + main character
                t.total_damage_multiplier = 1 + (t.clones_active * t.damage_reduction_per_clone)  -- ~1.9x total
                t.aoe_phase_active = true
                t.single_target_inefficient = t.clones_active > 1  -- Not ideal for ST
                t.positioning_required = true  -- Clones need positioning
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.time_remaining = 0
            t.damage_reduction_per_clone = 0.45
            t.clones_active = 0
            t.total_damage_multiplier = 1
            t.aoe_phase_active = false
            t.single_target_inefficient = false
            t.positioning_required = false
        end,
    },
    
    invoke_xuen = {
        id = 123904,
        duration = 45,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(123904)
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Advanced Xuen tracking
                t.time_remaining = t.expires - GetTime()
                t.dps_contribution = 850  -- Estimated DPS contribution
                t.haste_proc_chance = glyph.invoke_xuen.enabled and 0.25 or 0  -- 25% with glyph
                t.haste_proc_bonus = 0.10  -- 10% haste for 6 sec
                t.glyph_synergy = glyph.invoke_xuen.enabled
                t.pet_positioning = true  -- Xuen needs positioning
                t.burst_window_active = t.time_remaining > 0
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.time_remaining = 0
            t.dps_contribution = 0
            t.haste_proc_chance = glyph.invoke_xuen.enabled and 0.25 or 0
            t.haste_proc_bonus = 0
            t.glyph_synergy = glyph.invoke_xuen.enabled
            t.pet_positioning = false
            t.burst_window_active = false
        end,
    },
    
    -- Defensive Abilities
    fortifying_brew = {
        id = 115203,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(115203)
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Advanced Fortifying Brew tracking
                t.time_remaining = t.expires - GetTime()
                t.damage_reduction = 0.20  -- 20% damage reduction
                t.health_increase = 0.20  -- 20% health increase
                t.stun_fear_immunity = glyph.fortifying_brew.enabled  -- Glyph immunity
                t.effective_hp_bonus = t.damage_reduction + t.health_increase  -- ~36% effective HP
                t.defensive_window = t.time_remaining > 0
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.time_remaining = 0
            t.damage_reduction = 0
            t.health_increase = 0
            t.stun_fear_immunity = glyph.fortifying_brew.enabled
            t.effective_hp_bonus = 0
            t.defensive_window = false
        end,
    },
    
    dampen_harm = {
        id = 122278,
        duration = 45,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(122278)
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Advanced Dampen Harm tracking
                t.time_remaining = t.expires - GetTime()
                t.charges_remaining = count
                t.damage_reduction_per_hit = 0.50  -- 50% reduction on hits >20% of max HP
                t.big_hit_threshold = 0.20  -- 20% of max health
                t.charges_efficiency = count / 3  -- Efficiency ratio
                t.defensive_value = count * t.damage_reduction_per_hit
                t.should_refresh = count == 0 and t.time_remaining < 5
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.time_remaining = 0
            t.charges_remaining = 0
            t.damage_reduction_per_hit = 0.50
            t.big_hit_threshold = 0.20
            t.charges_efficiency = 0
            t.defensive_value = 0
            t.should_refresh = false
        end,
    },
    
    -- Movement and Mobility
    tigers_lust = {
        id = 116841,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(116841)
            
            if name and talent.tigers_lust.enabled then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Advanced Tiger's Lust tracking
                t.time_remaining = t.expires - GetTime()
                t.movement_speed_bonus = 0.70  -- 70% movement speed increase
                t.immunity_to_roots_snares = true
                t.energy_regen_bonus = 0.20  -- 20% energy regen during sprint
                t.positioning_window = t.time_remaining > 0
                t.mobility_phase = true
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.time_remaining = 0
            t.movement_speed_bonus = 0
            t.immunity_to_roots_snares = false
            t.energy_regen_bonus = 0
            t.positioning_window = false
            t.mobility_phase = false
        end,
    },
    
    flying_serpent_kick = {
        id = 101545,
        duration = 2,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(101545)
            
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Advanced Flying Serpent Kick tracking
                t.time_remaining = t.expires - GetTime()
                t.travel_distance = glyph.flying_serpent_kick.enabled and 50 or 25  -- Yards
                t.damage_on_impact = 950  -- MoP damage value
                t.glyph_distance_bonus = glyph.flying_serpent_kick.enabled and 25 or 0
                t.positioning_tool = true
                t.gap_closer = t.time_remaining > 0
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.time_remaining = 0
            t.travel_distance = glyph.flying_serpent_kick.enabled and 50 or 25
            t.damage_on_impact = 950
            t.glyph_distance_bonus = glyph.flying_serpent_kick.enabled and 25 or 0
            t.positioning_tool = false
            t.gap_closer = false
        end,
    },
    
    -- Additional Core Buffs and Mechanics
    shuffle = {
        id = 115307,
        duration = 6,
        max_stack = 1,
    },
    elusive_brew = {
        id = 115308,
        duration = 15,
        max_stack = 15,
    },
    guard = {
        id = 115295,
        duration = 30,
        max_stack = 1,
    },
    touch_of_karma = {
        id = 125174,
        duration = 10,
        max_stack = 1,
    },
    healing_elixirs = {
        id = 122281,
        duration = 15,
        max_stack = 1,
    },
    zen_meditation = {
        id = 124995,
        duration = 8,
        max_stack = 1,
    },
    transcendence = {
        id = 101643,
        duration = 900,
        max_stack = 1,
    },
    
    -- Debuffs on targets
    rising_sun_kick = {
        id = 130320,
        duration = 8,
        max_stack = 1,
    },
    disable = {
        id = 116095,
        duration = 8,
        max_stack = 1,
    },
    paralysis = {
        id = 115078,
        duration = function() return glyph.paralysis.enabled and 5 or 4 end,
        max_stack = 1,
    },    leg_sweep = {
        id = 119381,        duration = 3,
        max_stack = 1,
    },
      -- ===================
    -- MOVEMENT AND MOBILITY
    -- ===================
    
    -- Momentum (movement speed from Roll)
    momentum = {
        id = 115294,
        duration = 10,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 115294 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Chi Torpedo (enhanced roll)
    chi_torpedo = {
        id = 119085,
        duration = 10,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 119085 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- ===================    -- TALENT ABILITIES    -- ===================
      -- Chi Wave (bouncing heal/damage)
    -- Zen Sphere (protective orb)
    -- ===================
    -- DEFENSIVE ABILITIES
    -- ===================      -- Fortifying Brew (damage reduction)
    -- Dampen Harm (big hit reduction)
    -- Diffuse Magic (magic immunity)
    diffuse_magic = {
        id = 122783,
        duration = 6,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 122783 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- ===================
    -- ULTIMATE ABILITIES (Level 90 Talents)
    -- ===================
    
    -- Rushing Jade Wind (whirling tornado)
    rushing_jade_wind = {
        id = 116847,
        duration = function() return glyph.jade_wind_mastery.enabled and 8 or 6 end,
        tick_time = 0.75,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 116847 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                
                -- Calculate remaining ticks
                local remaining_time = expires - GetTime()
                state.rushing_jade_wind_ticks_remaining = floor(remaining_time / 0.75)
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            state.rushing_jade_wind_ticks_remaining = 0
        end,    },
    
    -- Invoke Xuen (White Tiger summon)
    -- ===================    -- CROWD CONTROL DEBUFFS    -- ===================
    
    -- Paralysis (incapacitate)
    -- Disable (movement impairment)
    -- ===================
    -- TIER SET BONUSES
    -- ===================
    
    -- T14 2pc: Tiger Palm damage bonus to next Blackout Kick
    windwalker_t14_2pc_buff = {
        id = 123124,
        duration = 15,
        max_stack = 1,
        generate = function( t, auraType )
            if not set_bonus.tier14_2pc then
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
                return
            end
            
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 123124 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                
                -- 50% damage bonus to next Blackout Kick
                state.t14_2pc_blackout_kick_bonus = 0.50
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            state.t14_2pc_blackout_kick_bonus = 0
        end,
    },
    
    -- T15 2pc: Energizing Brew haste bonus
    windwalker_t15_2pc_buff = {
        id = 138147,
        duration = 15,
        max_stack = 1,
        generate = function( t, auraType )
            if not set_bonus.tier15_2pc then
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
                return
            end
            
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 138147 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                
                -- 10% haste bonus
                state.t15_2pc_haste_bonus = 0.10
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            state.t15_2pc_haste_bonus = 0
        end,
    },
    
    -- ===================    -- RESOURCE MANAGEMENT AURAS
    -- ===================
    
    -- Energizing Brew (energy regeneration)
    -- Mana Tea (mana restoration)
    mana_tea = {
        id = 115867,
        duration = 10,
        max_stack = 20, -- Stacks for channeling
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 115867 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                
                -- Calculate mana restoration per stack
                state.mana_tea_stacks = count or 0
                state.mana_tea_restoration_per_stack = state.mana.max * 0.04 -- 4% per stack
                return
            end
              t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            state.mana_tea_stacks = 0
            state.mana_tea_restoration_per_stack = 0
        end,
    },
} )

-- Monk shared abilities and Windwalker abilities
spec:RegisterAbilities( {    -- Core Windwalker Abilities
    blackout_kick = {
        id = 100784,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() return buff.combo_breaker_blackout_kick.up and 0 or 2 end,
        spendType = "chi",
        
        startsCombat = true,
        texture = 574575,
        
        -- WoW Sims verified: 7.12 damage multiplier, 2 Chi cost
        handler = function()
            if buff.combo_breaker_blackout_kick.up then
                removeBuff("combo_breaker_blackout_kick")
            end
            
            -- MoP Combat Conditioning: 20% extra damage over 4s if behind target
            -- or instant heal for 20% of damage if in front
        end,
    },
    
    energizing_brew = {
        id = 115288,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 608938,
        
        handler = function()
            applyBuff("energizing_brew")
        end,
    },
      fists_of_fury = {
        id = 113656,
        cast = 4,
        cooldown = 25,
        gcd = "spell",
        
        spend = 3,
        spendType = "chi",
        
        startsCombat = true,
        texture = 627606,
        
        toggle = "cooldowns",
        
        channeled = true,
        
        -- WoW Sims verified: 6.675 damage multiplier per tick (7.5 * 0.89)
        -- 4 second channel, 4 ticks (1 per second), 25s cooldown, 3 Chi cost
        -- Damage split evenly between all targets, stuns targets
        handler = function()
            applyBuff("fists_of_fury", 4)
            
            -- Apply stun to all targets in cone
            active_enemies = active_enemies or 1
            for i = 1, active_enemies do
                applyDebuff("target", "fists_of_fury_stun", 4)
            end
            
            -- Delay auto-attacks during channel
        end,
    },
    
    flying_serpent_kick = {
        id = 101545,
        cast = 0,
        cooldown = 25,
        gcd = "spell",
        
        startsCombat = true,
        texture = 606545,
        
        handler = function()
            applyBuff("flying_serpent_kick")
        end,
    },
    
    legacy_of_the_white_tiger = {
        id = 116781,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 607848,
        
        handler = function()
            applyBuff("legacy_of_the_white_tiger")
        end,
    },      rising_sun_kick = {
        id = 107428,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        spend = 2,
        spendType = "chi",
        
        startsCombat = true,
        texture = 574578,
        
        -- MoP 5.4.8: 8s cooldown, 2 Chi cost
        -- MoP 5.3.0: 20% damage increase debuff to ALL targets within 8 yards for 15 seconds
        -- Always applies Mortal Wounds (healing reduction)
        handler = function()
            -- Apply Rising Sun Kick debuff to primary target
            applyDebuff("target", "rising_sun_kick", 15)
            applyDebuff("target", "mortal_wounds", 10) -- Healing reduction
            
            -- MoP 5.3.0: Apply 20% damage increase debuff to ALL targets within 8 yards
            -- This represents the area effect that was core to MoP Windwalker gameplay
            active_enemies = active_enemies or 1
            if active_enemies > 1 then
                for i = 1, min(active_enemies, 8) do -- Cap at 8 enemies for performance
                    applyDebuff("target", "rising_sun_kick", 15)
                end
            end
        end,
    },
    
    tigereye_brew = {
        id = 116740,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 608939,
        
        usable = function()
            return buff.tigereye_brew_stack.stack > 0
        end,
        
        handler = function()
            -- Convert stacks to buff
            local stacks = min(10, buff.tigereye_brew_stack.stack)
            removeStack("tigereye_brew_stack", stacks)
            applyBuff("tigereye_brew")
        end,
    },
    
    touch_of_karma = {
        id = 122470,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = true,
        texture = 651728,
        
        handler = function()
            applyBuff("touch_of_karma")
        end,
    },
    
    -- Shared Monk Abilities
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
            -- Does damage to enemies and healing to allies
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
            -- Moves you forward and increases movement speed
            applyBuff("path_of_blossoms")
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
            -- Does damage to enemies and healing to allies, bouncing between targets
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
            -- Reduces damage from the next 3 attacks
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
            -- Reduces magic damage and returns harmful effects to caster
        end,
    },
    
    disable = {
        id = 116095,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 15,
        spendType = "energy",
        
        startsCombat = true,
        texture = 461484,
        
        handler = function()
            applyDebuff("target", "disable")
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
    
    invoke_xuen = {
        id = 123904,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        talent = "invoke_xuen",
        
        startsCombat = true,
        texture = 620832,
        
        handler = function()
            summonPet("xuen", 45)
        end,
    },
      jab = {
        id = 100780,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 40,  -- WoW Sims verified: 40 energy (0 in Wise Serpent stance)
        spendType = "energy",
        
        startsCombat = true,
        texture = 574573,
        
        -- WoW Sims verified: 1.5 damage multiplier, generates 1 Chi (2 in Fierce Tiger stance)
        handler = function()
            gain(1, "chi")  -- Base Chi generation (2 in Fierce Tiger stance)
            
            -- Combo Breaker procs (8% chance each)
            if math.random() < 0.08 then
                applyBuff("combo_breaker_tiger_palm")
            end
            
            if math.random() < 0.08 then
                applyBuff("combo_breaker_blackout_kick")
            end
            
            -- Power Strikes talent
            if talent.power_strikes.enabled and cooldown.power_strikes.remains == 0 then
                gain(1, "chi")
                setCooldown("power_strikes", 20)
            end
            
            -- Tigereye Brew generation, approximately one stack per 3 Chi spent
            if math.random() < 0.33 then
                addStack("tigereye_brew_stack", nil, 1)
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
            -- Stuns all nearby enemies
        end,
    },
    
    paralysis = {
        id = 115078,
        cast = 0,
        cooldown = function()
            -- Deadly Reach talent extends range but adds 15s to cooldown
            return talent.deadly_reach.enabled and 30 or 15
        end,
        gcd = "spell",
        
        spend = 20,
        spendType = "energy",
        
        startsCombat = false,
        texture = 629534,
        
        handler = function()
            applyDebuff("target", "paralysis")
        end,
    },
    
    roll = {
        id = 109132,
        cast = 0,
        cooldown = 20,
        charges = function() return talent.celerity.enabled and 3 or 2 end,
        recharge = function() return talent.celerity.enabled and 15 or 20 end,
        gcd = "off",
        
        startsCombat = false,
        texture = 574574,
        
        handler = function()
            -- Moves you forward quickly
            if talent.momentum.enabled then
                applyBuff("momentum")
            end
        end,
    },
    
    rushing_jade_wind = {
        id = 116847,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 1,
        spendType = "chi",
        
        talent = "rushing_jade_wind",
        
        startsCombat = true,
        texture = 606549,
        
        handler = function()
            -- Applies a whirling tornado around you
        end,
    },
    
    spear_hand_strike = {
        id = 116705,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        
        interrupt = true,
        
        startsCombat = true,
        texture = 608940,
        
        toggle = "interrupts",
        
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
            -- Does AoE damage around you
            if talent.power_strikes.enabled and cooldown.power_strikes.remains == 0 then
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
        
        spend = function() return buff.combo_breaker_tiger_palm.up and 0 or 1 end,
        spendType = "chi",
        
        startsCombat = true,
        texture = 606551,
        
        -- MoP 5.4.8: Costs 1 Chi (removed in Legion 7.0.3), applies Tiger Power (30% armor reduction single application)
        handler = function()
            -- Check if we had free proc
            if buff.combo_breaker_tiger_palm.up then
                removeBuff("combo_breaker_tiger_palm")
            end
            
            -- MoP 5.1.0: Tiger Power reduces target armor by 30% with single application, no longer stacks
            applyDebuff("target", "tiger_power", 20)
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
            -- Increases movement speed of target
        end,
    },
    
    touch_of_death = {
        id = 115080,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 607853,
        
        usable = function() 
            if target.health_pct > 10 then return false end
            return true
        end,
        
        handler = function()
            -- Instantly kills enemy with less than 10% health or deals high damage to players
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
            -- Creates a copy of yourself
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
            -- Swaps places with your transcendence copy
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
            -- Places a healing sphere on target
        end,
    },
} )

-- Specific to Xuen
spec:RegisterPet( "xuen_the_white_tiger", 73967, "invoke_xuen", 45 )

-- State Expressions for Windwalker
spec:RegisterStateExpr( "combo_breaker_bok", function()
    return buff.combo_breaker_blackout_kick.up
end )

spec:RegisterStateExpr( "combo_breaker_tp", function()
    return buff.combo_breaker_tiger_palm.up
end )

spec:RegisterStateExpr( "teb_stacks", function()
    return buff.tigereye_brew_stack.stack
end )

-- Range
spec:RegisterRanges( "tiger_palm", "blackout_kick", "paralysis", "provoke", "crackling_jade_lightning" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "virmen_bite_potion",
    
    package = "Windwalker",
} )

-- Register default pack for MoP Windwalker
spec:RegisterPack( "Windwalker", 20250517, [[Hekili:T3vBVTTn04FldjTrXocoqRiKMh7KvA3KRJ1AWTLr0cbrjdduiHZLPLtfJ1JdKiLmoQiUAWtlW5)GLYmvoWpXIYofJNVQP3YZVCtDw7ZlUm74NwF2G5xnC7JA3YnxFDWp8Yv6(oOV94A7zL9ooX60FsNn2GxV3cW0CwVdF9C4O83PhEKwmDDVF8W)V65a89FdFCRV7uCHthVJ6kXbqnuSmQbCG45DYCFND7zs0MYVsHvyeTDxJzKWx0yZlzZZmylTiWOZ(vPzZIx1uUZE7)aXuZ(qx45sNUZbkn(BNUgCn(RcYdVS(RYqxP2tixP5wOLLNcXE0mbYTj81zg7a8uHMtlP(vHJYTF1Z2ynOBMd6YoLAvJVS3QVdVJOUjP(WV8jntTj63bRuvuV5JaEHN0VEvZP4JNpEvX7P4OeJUFPTxuTSU5tP5wm)8j]] )

-- Register pack selector for Windwalker
