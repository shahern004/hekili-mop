-- RogueAssassination.lua
-- Updated May 30, 2025 - Enhanced Structure following Hunter Survival pattern
-- Mists of Pandaria module for Rogue: Assassination spec

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'ROGUE' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local spec = Hekili:NewSpecialization( 259 ) -- Assassination spec ID for MoP

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

-- Enhanced Combat Log Event Tracking (following Hunter Survival pattern)
local assassination_events = {}
local energy_events = {}
local combo_point_events = {}

-- Initialize frame for enhanced combat log tracking
local combatLogFrame = CreateFrame("Frame")
combatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

combatLogFrame:SetScript("OnEvent", function(self, event)
    local _, subEvent, _, sourceGUID, sourceName, _, _, destGUID, destName, destFlags, _, spellID, spellName, _, amount, overhealing, absorbed, critical = CombatLogGetCurrentEventInfo()
    
    if sourceGUID ~= UnitGUID("player") then return end
    
    local now = GetTime()
    
    -- POISON APPLICATION TRACKING
    if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH" then
        if spellID == 2818 then -- Deadly Poison
            ns.last_deadly_poison_applied = now
            ns.deadly_poison_target = destGUID
        elseif spellID == 8679 then -- Wound Poison
            ns.last_wound_poison_applied = now
            ns.wound_poison_target = destGUID
        elseif spellID == 3409 then -- Crippling Poison
            ns.last_crippling_poison_applied = now
        end
    end
    
    -- VENOMOUS WOUNDS PROC TRACKING
    if subEvent == "SPELL_ENERGIZE" and spellID == 51637 then -- Venomous Wounds
        ns.last_venomous_wounds = now
        ns.venomous_wounds_energy = (ns.venomous_wounds_energy or 0) + amount
    end
    
    -- COMBO POINT GENERATION TRACKING
    if subEvent == "SPELL_CAST_SUCCESS" then
        if spellID == 1752 then -- Sinister Strike
            ns.last_sinister_strike = now        elseif spellID == 2098 then -- Eviscerate
            ns.last_eviscerate = now
            ns.last_finisher_combo_points = UnitPower("player", 4) -- ComboPoints = 4 in MoP
        elseif spellID == 32645 then -- Envenom
            ns.last_envenom = now
            ns.last_finisher_combo_points = UnitPower("player", 4) -- ComboPoints = 4 in MoP
        elseif spellID == 79140 then -- Vendetta
            ns.last_vendetta_cast = now
        end
    end
    
    -- DOT TICK TRACKING for damage optimization
    if subEvent == "SPELL_PERIODIC_DAMAGE" then
        if spellID == 2818 then -- Deadly Poison
            ns.last_deadly_poison_tick = now
            ns.deadly_poison_damage = (ns.deadly_poison_damage or 0) + amount
        elseif spellID == 8680 then -- Wound Poison
            ns.last_wound_poison_tick = now
        end
    end
    
    -- ASSASSINATION PROC TRACKING
    if subEvent == "SPELL_AURA_APPLIED" then
        if spellID == 32645 then -- Envenom buff
            ns.last_envenom_buff = now
        elseif spellID == 79140 then -- Vendetta
            ns.last_vendetta_applied = now
        end
    end
end)

local tracked_bleeds = {}

-- Enhanced Resource Management System (following Hunter Survival pattern)
spec:RegisterResource( 4, { -- ComboPoints = 4 in MoP
    vendetta_combo = {
        talent = "vendetta",
        
        last = function ()
            return ns.last_vendetta_cast or 0
        end,

        interval = function ()
            return state.abilities.vendetta.cooldown
        end,

        stop = function ()
            return (GetTime() - (ns.last_vendetta_cast or 0)) > 120
        end,

        value = function ()
            -- Vendetta can allow more aggressive combo point spending
            return 0
        end,
    },
    
    mutilate_combo = {
        aura = "slice_and_dice",
        
        last = function ()
            return ns.last_mutilate_cast or 0
        end,

        interval = function ()
            return state.abilities.mutilate.cooldown
        end,

        stop = function ()
            return (GetTime() - (ns.last_mutilate_cast or 0)) > 10
        end,

        value = function ()
            -- Mutilate generates 2 combo points, 3 with Seal Fate crit
            local base_combo = 2
            if talent.seal_fate.enabled and state.crit_chance > 0.3 then
                return base_combo + 1
            end
            return base_combo
        end,
    },
} )

spec:RegisterResource( 3, { -- Energy = 3 in MoP
    venomous_wounds = {
        aura = "venomous_wounds",
        
        last = function ()
            return ns.last_venomous_wounds or 0
        end,

        interval = function ()
            return 3  -- Venomous Wounds procs every 3 seconds when poisons tick
        end,

        stop = function ()
            return (GetTime() - (ns.last_venomous_wounds or 0)) > 10
        end,

        value = function ()
            -- Venomous Wounds restores 10 energy per proc
            return 10
        end,
    },
    
    relentless_strikes = {
        talent = "relentless_strikes",
        
        last = function ()
            return ns.last_finisher_cast or 0
        end,

        interval = function ()
            return 5  -- Relentless Strikes has a chance to proc every 5 seconds
        end,

        stop = function ()
            return (GetTime() - (ns.last_finisher_cast or 0)) > 15
        end,

        value = function ()
            -- Relentless Strikes restores 25 energy, 20% chance per combo point
            local combo_points = ns.last_finisher_combo_points or 1
            local proc_chance = combo_points * 0.20
            return proc_chance > math.random() and 25 or 0
        end,
    },
    
    adrenaline_rush = {
        aura = "adrenaline_rush",
        
        last = function ()
            return ns.last_adrenaline_rush or 0
        end,

        interval = function ()
            return state.abilities.adrenaline_rush.cooldown
        end,

        stop = function ()
            return (GetTime() - (ns.last_adrenaline_rush or 0)) > 180
        end,

        value = function ()
            -- Adrenaline Rush provides 100% energy regeneration for 15 seconds
            return buff.adrenaline_rush.up and 20 or 0  -- 20 extra energy per second
        end,
    },
    
    preparation = {
        talent = "preparation",
        
        last = function ()
            return ns.last_preparation or 0
        end,

        interval = function ()
            return state.abilities.preparation.cooldown
        end,

        stop = function ()
            return (GetTime() - (ns.last_preparation or 0)) > 180
        end,

        value = function ()
            -- Preparation restores all energy
            return UnitPowerMax("player", 3) - UnitPower("player", 3) -- Energy = 3 in MoP
        end,
    },
} )

-- Comprehensive Tier sets with MoP Assassination Rogue progression
spec:RegisterGear( "tier13", 77011, 77012, 77013, 77014, 77015 ) -- T13 Blackfang Battleweave
spec:RegisterGear( "tier14", 85299, 85300, 85301, 85302, 85303 ) -- T14 Battlegear of the Thousandfold Blades
spec:RegisterGear( "tier14_lfr", 89293, 89294, 89295, 89296, 89297 ) -- LFR versions
spec:RegisterGear( "tier14_heroic", 90668, 90669, 90670, 90671, 90672 ) -- Heroic versions

spec:RegisterGear( "tier15", 95298, 95299, 95300, 95301, 95302 ) -- T15 Battlegear of the Thousandfold Blades
spec:RegisterGear( "tier15_lfr", 95953, 95954, 95955, 95956, 95957 ) -- LFR versions
spec:RegisterGear( "tier15_heroic", 96573, 96574, 96575, 96576, 96577 ) -- Heroic versions

spec:RegisterGear( "tier16", 99272, 99273, 99274, 99275, 99276 ) -- T16 Garb of the Shattered Vale
spec:RegisterGear( "tier16_lfr", 100089, 100090, 100091, 100092, 100093 ) -- LFR versions
spec:RegisterGear( "tier16_heroic", 100814, 100815, 100816, 100817, 100818 ) -- Heroic versions

-- Notable MoP Assassination Rogue items and legendary
spec:RegisterGear( "legendary_cloak", 102246 ) -- Jina-Kang, Kindness of Chi-Ji (DPS version)
spec:RegisterGear( "legendary_daggers", 77946, 77947 ) -- Golad, Twilight of Aspects / Tiriosh, Nightmare of Ages
spec:RegisterGear( "thunderforged_weapons", 96631, 96632, 96633 ) -- Thunderforged raid weapons
spec:RegisterGear( "kor_kron_rogue_gear", 105482, 105483, 105484 ) -- SoO specific items
spec:RegisterGear( "prideful_gladiator", 103649, 103650, 103651, 103652, 103653 ) -- PvP gear
spec:RegisterGear( "assassination_daggers", 94966, 94967, 94968 ) -- Assassination-specific weapons

-- Tier set bonuses as auras
spec:RegisterAura( "assassination_tier13_2pc", {
    id = 105849,
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "assassination_tier13_4pc", {
    id = 105850,
    duration = 6,
    max_stack = 1,
} )

spec:RegisterAura( "assassination_tier14_2pc", {
    id = 123286,
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "assassination_tier14_4pc", {
    id = 123287,
    duration = 15,
    max_stack = 1,
} )

spec:RegisterAura( "assassination_tier15_2pc", {
    id = 138142,
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "assassination_tier15_4pc", {
    id = 138143,
    duration = 12,
    max_stack = 1,
} )

spec:RegisterAura( "assassination_tier16_2pc", {
    id = 144906,
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "assassination_tier16_4pc", {
    id = 144907,
    duration = 10,
    max_stack = 3,
} )

-- Talents (MoP 6-tier talent system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Stealth/Opener
    nightstalker               = { 4908, 1, 14062  }, -- Damage increased by 50% while stealthed
    subterfuge                 = { 4909, 1, 108208 }, -- Abilities usable for 3 sec after breaking stealth
    shadow_focus               = { 4910, 1, 108209 }, -- Abilities cost 75% less energy while stealthed
    
    -- Tier 2 (Level 30) - Ranged/Utility
    deadly_throw               = { 4911, 1, 26679  }, -- Throws knife to interrupt and slow
    nerve_strike               = { 4912, 1, 108210 }, -- Reduces healing by 50% for 10 sec
    combat_readiness           = { 4913, 1, 74001  }, -- Stacks reduce damage taken
    
    -- Tier 3 (Level 45) - Survivability
    cheat_death                = { 4914, 1, 31230  }, -- Fatal damage instead leaves you at 7% health
    leeching_poison            = { 4915, 1, 108211 }, -- Poisons heal you for 10% of damage dealt
    elusiveness                = { 4916, 1, 79008  }, -- Feint and Cloak reduce damage by additional 30%
    
    -- Tier 4 (Level 60) - Mobility
    preparation                = { 4917, 1, 14185  }, -- Resets cooldowns of finishing moves
    shadowstep                 = { 4918, 1, 36554  }, -- Teleport behind target
    burst_of_speed             = { 4919, 1, 108212 }, -- Sprint that breaks movement impairing effects
    
    -- Tier 5 (Level 75) - Crowd Control
    prey_on_the_weak           = { 4920, 1, 51685  }, -- +20% damage to movement impaired targets
    paralytic_poison           = { 4921, 1, 108215 }, -- Poisons apply stacking slow and eventual stun
    dirty_tricks               = { 4922, 1, 108216 }, -- Blind and Gouge no longer break on damage
    
    -- Tier 6 (Level 90) - Ultimate
    shuriken_toss              = { 4923, 1, 114014 }, -- Ranged attack that generates combo points
    marked_for_death           = { 4924, 1, 137619 }, -- Target gains 5 combo points
    anticipation               = { 4925, 1, 115189 }  -- Store up to 10 combo points
} )

-- Comprehensive MoP Assassination Rogue Glyphs System
spec:RegisterGlyphs( {
    -- MAJOR GLYPHS (Critical tactical modifications)
    glyph_of_vendetta = {
        id = 63268,
        name = "Glyph of Vendetta",
        item = 45761,
        description = "Reduces Vendetta cooldown by 30 seconds.",
        effect = function() return "vendetta_cooldown_reduction" end,
    },
    glyph_of_mutilate = {
        id = 56808,
        name = "Glyph of Mutilate",
        item = 42954,
        description = "Reduces energy cost of Mutilate by 5.",
        effect = function() return "mutilate_energy_reduction" end,
    },
    glyph_of_envenom = {
        id = 56821,
        name = "Glyph of Envenom",
        item = 42967,
        description = "Increases duration of Envenom by 2 seconds.",
        effect = function() return "envenom_duration_increase" end,
    },
    glyph_of_rupture = {
        id = 56801,
        name = "Glyph of Rupture",
        item = 45762,
        description = "Increases Rupture duration by 4 seconds.",
        effect = function() return "rupture_duration_increase" end,
    },
    glyph_of_garrote = {
        id = 56812,
        name = "Glyph of Garrote",
        item = 42958,
        description = "Garrote silences the target for 3 seconds.",
        effect = function() return "garrote_silence" end,
    },
    glyph_of_cheap_shot = {
        id = 56806,
        name = "Glyph of Cheap Shot",
        item = 42952,
        description = "Increases duration of Cheap Shot by 0.5 seconds.",
        effect = function() return "cheap_shot_duration" end,
    },
    glyph_of_slice_and_dice = {
        id = 56810,
        name = "Glyph of Slice and Dice",
        item = 42956,
        description = "Slice and Dice also increases movement speed by 15%.",
        effect = function() return "slice_and_dice_movement" end,
    },
    glyph_of_vanish = {
        id = 56814,
        name = "Glyph of Vanish",
        item = 42960,
        description = "Vanish removes movement impairing effects.",
        effect = function() return "vanish_movement_freedom" end,
    },
    glyph_of_sprint = {
        id = 56802,
        name = "Glyph of Sprint",
        item = 42955,
        description = "Sprint increases movement speed by additional 30%.",
        effect = function() return "sprint_speed_increase" end,
    },
    glyph_of_feint = {
        id = 56813,
        name = "Glyph of Feint",
        item = 42959,
        description = "Feint lasts 2 additional seconds.",
        effect = function() return "feint_duration_increase" end,
    },
    glyph_of_evasion = {
        id = 56799,
        name = "Glyph of Evasion",
        item = 42946,
        description = "Evasion also increases movement speed by 50%.",
        effect = function() return "evasion_movement_speed" end,
    },
    glyph_of_backstab = {
        id = 56800,
        name = "Glyph of Backstab",
        item = 42947,
        description = "Backstab critical strikes grant 5% spell haste for 10 seconds.",
        effect = function() return "backstab_spell_haste" end,
    },
    glyph_of_smoke_bomb = {
        id = 63420,
        name = "Glyph of Smoke Bomb",
        item = 63268,
        description = "Smoke Bomb also heals you for 20% over its duration.",
        effect = function() return "smoke_bomb_healing" end,
    },
    glyph_of_deadly_throw = {
        id = 56807,
        name = "Glyph of Deadly Throw",
        item = 42953,
        description = "Increases slow duration of Deadly Throw by 2 seconds.",
        effect = function() return "deadly_throw_slow_duration" end,
    },
    glyph_of_expose_armor = {
        id = 56803,
        name = "Glyph of Expose Armor",
        item = 42948,
        description = "Expose Armor affects 2 additional nearby enemies.",
        effect = function() return "expose_armor_cleave" end,
    },
    glyph_of_kidney_shot = {
        id = 56809,
        name = "Glyph of Kidney Shot",
        item = 42957,
        description = "Reduces energy cost of Kidney Shot by 10.",
        effect = function() return "kidney_shot_energy_reduction" end,
    },
    glyph_of_blind = {
        id = 56811,
        name = "Glyph of Blind",
        item = 45760,
        description = "Blind no longer breaks on damage but lasts 4 seconds.",
        effect = function() return "blind_damage_immunity" end,
    },
    glyph_of_cloaking = {
        id = 63269,
        name = "Glyph of Cloaking",
        item = 45769,
        description = "Cloak of Shadows also increases movement speed by 40%.",
        effect = function() return "cloak_of_shadows_movement" end,
    },
    glyph_of_stealth = {
        id = 56815,
        name = "Glyph of Stealth",
        item = 42961,
        description = "Increases movement speed while stealthed by 15%.",
        effect = function() return "stealth_movement_speed" end,
    },
    glyph_of_recuperate = {
        id = 56805,
        name = "Glyph of Recuperate",
        item = 42951,
        description = "Recuperate heals for 50% more but costs 10 more energy.",
        effect = function() return "recuperate_enhanced_healing" end,
    },

    -- MINOR GLYPHS (Quality of life improvements)
    glyph_of_distraction = {
        id = 56818,
        name = "Glyph of Distraction",
        item = 42964,
        description = "Distraction no longer causes monsters to attack you.",
        effect = function() return "distraction_safe" end,
    },
    glyph_of_pick_lock = {
        id = 56819,
        name = "Glyph of Pick Lock",
        item = 42965,
        description = "Reduces cast time of Pick Lock by 50%.",
        effect = function() return "pick_lock_speed" end,
    },
    glyph_of_pick_pocket = {
        id = 56820,
        name = "Glyph of Pick Pocket",
        item = 42966,
        description = "Pick Pocket range increased by 5 yards.",
        effect = function() return "pick_pocket_range" end,
    },
    glyph_of_safe_fall = {
        id = 56816,
        name = "Glyph of Safe Fall",
        item = 42962,
        description = "Increases distance of safe fall by 100%.",
        effect = function() return "safe_fall_distance" end,
    },
    glyph_of_blurred_speed = {
        id = 56817,
        name = "Glyph of Blurred Speed",
        item = 42963,
        description = "Provides 40% movement speed while stealthed.",
        effect = function() return "blurred_speed" end,
    },
    glyph_of_poisons = {
        id = 56822,
        name = "Glyph of Poisons",
        item = 42968,
        description = "Applying poisons to weapons is 50% faster.",
        effect = function() return "poison_application_speed" end,
    },
    glyph_of_detection = {
        id = 64493,
        name = "Glyph of Detection",
        item = 45768,
        description = "Increases stealth detection while not stealthed.",
        effect = function() return "stealth_detection" end,
    },
    glyph_of_shiv = {
        id = 56804,
        name = "Glyph of Shiv",
        item = 42949,
        description = "Reduces cooldown of Shiv by 3 seconds.",
        effect = function() return "shiv_cooldown_reduction" end,
    },
    glyph_of_vigor = {
        id = 63324,
        name = "Glyph of Vigor",
        item = 45764,
        description = "Increases maximum energy by 10.",
        effect = function() return "energy_maximum_increase" end,
    },
    glyph_of_decoy = {
        id = 63326,
        name = "Glyph of Decoy",
        item = 45766,
        description = "Mirror Image creates an additional decoy.",
        effect = function() return "decoy_additional" end,
    },

    -- MOP-SPECIFIC GLYPHS
    glyph_of_redirect = {
        id = 94711,
        name = "Glyph of Redirect",
        item = 68709,
        description = "Redirect no longer has a cooldown.",
        effect = function() return "redirect_no_cooldown" end,
    },
    glyph_of_shadow_walk = {
        id = 114842,
        name = "Glyph of Shadow Walk",
        item = 87559,
        description = "Removes movement speed penalty from stealth.",
        effect = function() return "stealth_no_speed_penalty" end,
    },
    glyph_of_improved_distraction = {
        id = 146925,
        name = "Glyph of Improved Distraction",
        item = 104136,
        description = "Distraction summons a decoy for 5 seconds.",
        effect = function() return "distraction_decoy" end,
    },
    glyph_of_deadly_momentum = {
        id = 146694,
        name = "Glyph of Deadly Momentum",
        item = 104104,
        description = "Slice and Dice and Recuperate refresh when killing enemies.",
        effect = function() return "deadly_momentum_refresh" end,
    },
    glyph_of_sharp_knives = {
        id = 146627,
        name = "Glyph of Sharp Knives",
        item = 104095,
        description = "Fan of Knives damage reduced but cost reduced to 15 energy.",
        effect = function() return "fan_of_knives_efficient" end,
    },
    glyph_of_shadow_strike = {
        id = 146958,
        name = "Glyph of Shadow Strike",
        item = 104139,
        description = "Shadowstep can be used on friendly targets.",
        effect = function() return "shadowstep_friendly" end,
    },
    glyph_of_hemorrhaging_veins = {
        id = 146631,
        name = "Glyph of Hemorrhaging Veins",
        item = 104096,
        description = "Vendetta spreads Rupture to nearby enemies.",
        effect = function() return "vendetta_rupture_spread" end,
    },
    glyph_of_nightmares = {
        id = 146645,
        name = "Glyph of Nightmares",
        item = 104099,
        description = "Blind causes the target to run in fear instead.",
        effect = function() return "blind_fear_effect" end,
    },
    glyph_of_energy_flows = {
        id = 146654,
        name = "Glyph of Energy Flows",
        item = 104100,
        description = "Abilities used from stealth cost 20% less energy for 6 seconds.",
        effect = function() return "stealth_energy_efficiency" end,
    },
    glyph_of_recovery = {
        id = 146659,
        name = "Glyph of Recovery",
        item = 104101,
        description = "Finishing moves heal for 5% per combo point.",
        effect = function() return "finishing_move_healing" end,
    },
} )

-- Assassination specific auras
spec:RegisterAuras( {
    -- MoP: Envenom increases poison application chance by 30%
    envenom = {
        id = 32645,
        duration = function() return 1 + state.combo_points end,  -- 1 + CP seconds
        max_stack = 1,
    },
    -- Energy regeneration increased by 10%.
    venomous_wounds = {
        id = 79134, 
        duration = 3600,
        max_stack = 1,
    },
    -- Vendetta: Target takes 30% more damage from your attacks
    vendetta = {
        id = 79140,
        duration = 20,
        max_stack = 1,
    },
    -- Master Poisoner: Increases poison application chance and damage
    master_poisoner = {
        id = 93068,
        duration = 3600,
        max_stack = 1,
    },
    -- Cut to the Chase: Keeps up Slice and Dice when using Envenom
    cut_to_the_chase = {
        id = 51667,
        duration = 3600,
        max_stack = 1,
    },
    -- Assassination specific poison tracking
    deadly_poison = {
        id = 2818,
        duration = 12,
        max_stack = 5,
        tick_time = 3,
    },
    wound_poison = {
        id = 8679,
        duration = 15,
        max_stack = 5,
    },
    crippling_poison = {
        id = 3409,
        duration = 12,
        max_stack = 1,
    },
    mind_numbing_poison = {
        id = 5760,
        duration = 10,
        max_stack = 1,
    },
    leeching_poison = {
        id = 108211,
        duration = 3600,
        max_stack = 1,
    },
    paralytic_poison = {
        id = 113952,
        duration = 3600,
        max_stack = 1,
    },
} )

-- Base Rogue auras added directly to Assassination spec
spec:RegisterAuras( {
    -- Basic abilities
    stealth = {
        id = 1784,
        duration = 3600,
        max_stack = 1,
    },
    slice_and_dice = {
        id = 5171,
        duration = function() return 12 + 3 * state.combo_points end,
        max_stack = 1,
    },
    rupture = {
        id = 1943,
        duration = function() return 6 + 4 * state.combo_points end,
        max_stack = 1,
        tick_time = 2,
    },
    feint = {
        id = 1966,
        duration = function() return glyph.feint.enabled and 7 or 5 end,
        max_stack = 1,
    },
    vanish = {
        id = 1856,
        duration = 3,
        max_stack = 1,
    },
    sprint = {
        id = 2983,
        duration = function() return glyph.sprint.enabled and 9 or 8 end,
        max_stack = 1,
    },
    evasion = {
        id = 5277,
        duration = function() return glyph.evasion.enabled and 15 or 10 end,
        max_stack = 1,
    },
    cloak_of_shadows = {
        id = 31224,
        duration = 5,
        max_stack = 1,
    },
    
    -- MoP-specific shared abilities
    subterfuge = {
        id = 115191,
        duration = 3,
        max_stack = 1,
    },
    anticipation = {
        id = 115189,
        duration = 15,
        max_stack = 5,
    },
    burst_of_speed = {
        id = 108212,
        duration = 4,
        max_stack = 1,
    },
} )

-- Advanced Assassination Rogue Auras System with Generate Functions
spec:RegisterAuras( {
    -- ASSASSINATION CORE ABILITIES
    envenom = {
        id = 32645,
        duration = function() return 1 + state.combo_points end,
        max_stack = 1,
        generate = function( aura )
            local applied = action.envenom.lastCast or 0
            if applied > 0 and query_time - applied < aura.duration then
                aura.applied = applied
                aura.expires = applied + aura.duration
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    vendetta = {
        id = 79140,
        duration = 30,
        max_stack = 1,
        generate = function( aura )
            local applied = action.vendetta.lastCast or 0
            if applied > 0 and query_time - applied < aura.duration then
                aura.applied = applied
                aura.expires = applied + aura.duration
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    garrote = {
        id = 703,
        duration = 18,
        max_stack = 1,
        tick_time = 3,
        generate = function( aura )
            local applied = action.garrote.lastCast or 0
            if applied > 0 and query_time - applied < aura.duration then
                aura.applied = applied
                aura.expires = applied + aura.duration
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    rupture = {
        id = 1943,
        duration = function() return 6 + 4 * state.combo_points end,
        max_stack = 1,
        tick_time = 2,
        generate = function( aura )
            local applied = action.rupture.lastCast or 0
            if applied > 0 and query_time - applied < aura.duration then
                aura.applied = applied
                aura.expires = applied + aura.duration
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },

    -- STEALTH AND MOVEMENT ABILITIES
    stealth = {
        id = 1784,
        duration = 3600,
        max_stack = 1,
        generate = function( aura )
            if buff.stealth.up then
                aura.applied = buff.stealth.applied
                aura.expires = buff.stealth.expires
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    vanish = {
        id = 1856,
        duration = 3,
        max_stack = 1,
        generate = function( aura )
            local applied = action.vanish.lastCast or 0
            if applied > 0 and query_time - applied < aura.duration then
                aura.applied = applied
                aura.expires = applied + aura.duration
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    subterfuge = {
        id = 115191,
        duration = 3,
        max_stack = 1,
        generate = function( aura )
            if talent.subterfuge.enabled and stealthed.all then
                aura.applied = stealth_applied or query_time
                aura.expires = aura.applied + aura.duration
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    shadow_focus = {
        id = 108209,
        duration = 3600,
        max_stack = 1,
        generate = function( aura )
            if talent.shadow_focus.enabled then
                aura.applied = query_time
                aura.expires = query_time + 3600
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },

    -- MAINTENANCE BUFFS
    slice_and_dice = {
        id = 5171,
        duration = function() return 12 + 3 * state.combo_points end,
        max_stack = 1,
        generate = function( aura )
            local applied = action.slice_and_dice.lastCast or 0
            if applied > 0 and query_time - applied < aura.duration then
                aura.applied = applied
                aura.expires = applied + aura.duration
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    recuperate = {
        id = 73651,
        duration = function() return 6 + 6 * state.combo_points end,
        max_stack = 1,
        tick_time = 3,
        generate = function( aura )
            local applied = action.recuperate.lastCast or 0
            if applied > 0 and query_time - applied < aura.duration then
                aura.applied = applied
                aura.expires = applied + aura.duration
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },

    -- DEFENSIVE ABILITIES
    feint = {
        id = 1966,
        duration = function() return glyph.glyph_of_feint.enabled and 7 or 5 end,
        max_stack = 1,
        generate = function( aura )
            local applied = action.feint.lastCast or 0
            if applied > 0 and query_time - applied < aura.duration then
                aura.applied = applied
                aura.expires = applied + aura.duration
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    evasion = {
        id = 5277,
        duration = function() return glyph.glyph_of_evasion.enabled and 15 or 10 end,
        max_stack = 1,
        generate = function( aura )
            local applied = action.evasion.lastCast or 0
            if applied > 0 and query_time - applied < aura.duration then
                aura.applied = applied
                aura.expires = applied + aura.duration
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    cloak_of_shadows = {
        id = 31224,
        duration = 5,
        max_stack = 1,
        generate = function( aura )
            local applied = action.cloak_of_shadows.lastCast or 0
            if applied > 0 and query_time - applied < aura.duration then
                aura.applied = applied
                aura.expires = applied + aura.duration
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },

    -- MOBILITY ABILITIES
    sprint = {
        id = 2983,
        duration = function() return glyph.glyph_of_sprint.enabled and 9 or 8 end,
        max_stack = 1,
        generate = function( aura )
            local applied = action.sprint.lastCast or 0
            if applied > 0 and query_time - applied < aura.duration then
                aura.applied = applied
                aura.expires = applied + aura.duration
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    burst_of_speed = {
        id = 108212,
        duration = 4,
        max_stack = 1,
        generate = function( aura )
            local applied = action.burst_of_speed.lastCast or 0
            if applied > 0 and query_time - applied < aura.duration then
                aura.applied = applied
                aura.expires = applied + aura.duration
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },

    -- MOP TALENT AURAS
    anticipation = {
        id = 115189,
        duration = 15,
        max_stack = 5,
        generate = function( aura )
            if talent.anticipation.enabled then
                local stacks = anticipation_stacks or 0
                if stacks > 0 then
                    aura.applied = query_time
                    aura.expires = query_time + aura.duration
                    aura.count = stacks
                    aura.caster = "player"
                    return
                end
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    cut_to_the_chase = {
        id = 51667,
        duration = 3600,
        max_stack = 1,
        generate = function( aura )
            if talent.cut_to_the_chase.enabled then
                aura.applied = query_time
                aura.expires = query_time + 3600
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    lethality = {
        id = 14128,
        duration = 3600,
        max_stack = 1,
        generate = function( aura )
            if talent.lethality.enabled then
                aura.applied = query_time
                aura.expires = query_time + 3600
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },

    -- POISON AURAS
    deadly_poison = {
        id = 2818,
        duration = 12,
        max_stack = 5,
        tick_time = 3,
        generate = function( aura )
            if poison_applied_time and poison_applied_time > 0 and 
               query_time - poison_applied_time < aura.duration then
                aura.applied = poison_applied_time
                aura.expires = poison_applied_time + aura.duration
                aura.count = math.min(5, deadly_poison_stacks or 1)
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    wound_poison = {
        id = 8679,
        duration = 15,
        max_stack = 5,
        generate = function( aura )
            if wound_poison_applied and wound_poison_applied > 0 and 
               query_time - wound_poison_applied < aura.duration then
                aura.applied = wound_poison_applied
                aura.expires = wound_poison_applied + aura.duration
                aura.count = math.min(5, wound_poison_stacks or 1)
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    crippling_poison = {
        id = 3409,
        duration = 12,
        max_stack = 1,
        generate = function( aura )
            if crippling_poison_applied and crippling_poison_applied > 0 and 
               query_time - crippling_poison_applied < aura.duration then
                aura.applied = crippling_poison_applied
                aura.expires = crippling_poison_applied + aura.duration
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    mind_numbing_poison = {
        id = 5760,
        duration = 10,
        max_stack = 1,
        generate = function( aura )
            if mind_numbing_applied and mind_numbing_applied > 0 and 
               query_time - mind_numbing_applied < aura.duration then
                aura.applied = mind_numbing_applied
                aura.expires = mind_numbing_applied + aura.duration
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    leeching_poison = {
        id = 108211,
        duration = 3600,
        max_stack = 1,
        generate = function( aura )
            if talent.leeching_poison.enabled then
                aura.applied = query_time
                aura.expires = query_time + 3600
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    paralytic_poison = {
        id = 113952,
        duration = 3600,
        max_stack = 1,
        generate = function( aura )
            if talent.paralytic_poison.enabled then
                aura.applied = query_time
                aura.expires = query_time + 3600
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },

    -- TIER SET BONUSES
    rogue_t14_2pc = {
        id = 123123, -- Tier 14 2-piece
        duration = 3600,
        max_stack = 1,
        generate = function( aura )
            if set_bonus.tier14_2pc > 0 then
                aura.applied = query_time
                aura.expires = query_time + 3600
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    rogue_t14_4pc = {
        id = 123124, -- Tier 14 4-piece
        duration = 3600,
        max_stack = 1,
        generate = function( aura )
            if set_bonus.tier14_4pc > 0 then
                aura.applied = query_time
                aura.expires = query_time + 3600
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },

    -- SPECIAL PROC AURAS
    venomous_wounds = {
        id = 79134,
        duration = 3600,
        max_stack = 1,
        generate = function( aura )
            if talent.venomous_wounds.enabled then
                aura.applied = query_time
                aura.expires = query_time + 3600
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
    shadow_dance = {
        id = 51713,
        duration = function() return talent.improved_shadow_dance.enabled and 8 or 6 end,
        max_stack = 1,
        generate = function( aura )
            local applied = action.shadow_dance.lastCast or 0
            if applied > 0 and query_time - applied < aura.duration then
                aura.applied = applied
                aura.expires = applied + aura.duration
                aura.count = 1
                aura.caster = "player"
                return
            end
            aura.count = 0
            aura.applied = 0
            aura.expires = 0
            aura.caster = "nobody"
        end,
    },
} )

-- Assassination Rogue abilities
spec:RegisterAbilities( {
    mutilate = {
        id = 1329,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 50,  -- Corrected: MoP authentic energy cost
        spendType = "energy",
        
        handler = function ()
            -- MoP: Mutilate always generates 2 combo points (attacks with both weapons)
            local cp_gain = 2
            
            -- Seal Fate can add 1 CP per weapon if both crits (max 4 total)
            if talent.seal_fate.enabled and state.stat.crit > 0 then
                local crit_chance = state.stat.crit / 100
                -- Each weapon can crit independently
                if math.random() < crit_chance then
                    cp_gain = cp_gain + 1
                end
                if math.random() < crit_chance then
                    cp_gain = cp_gain + 1
                end
            end
            
            gain(cp_gain, "combo_points")
        end,
    },
      envenom = {
        id = 32645,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 35,  -- Verified: MoP authentic energy cost
        spendType = "energy",
        
        handler = function ()
            local cp = combo_points.current
            spend(cp, "combo_points")
            
            -- MoP: Envenom duration is 1 + cp seconds, increases poison chance by 30%
            applyBuff("envenom", 1 + cp)
            
            -- Cut to the Chase talent refreshes SnD to max duration
            if talent.cut_to_the_chase.enabled and buff.slice_and_dice.up then
                applyBuff("slice_and_dice", 21) -- 5 CP duration: 6 + 3*5 = 21 sec
            end
        end,
    },
      garrote = {
        id = 703,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 45,  -- Verified: MoP authentic energy cost
        spendType = "energy",
        
        requires = function()
            if not stealthed.all then return false, "not stealthed" end
            return true
        end,
        
        handler = function ()
            applyDebuff("target", "garrote")
            gain(1, "combo_points")
            
            -- MoP: Garrote silences for 3 sec with glyph
            if glyph.garrote.enabled then
                applyDebuff("target", "garrote_silence", 3)
            end
            
            if not buff.shadow_dance.up then
                removeBuff("stealth")
            end
        end,
    },
    
    vendetta = {
        id = 79140,
        cast = 0,
        cooldown = function() return glyph.vendetta.enabled and 90 or 120 end,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        handler = function ()
            applyDebuff("target", "vendetta")
        end,
    },
    
    rupture = {
        id = 1943,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 25,
        spendType = "energy",
        
        handler = function ()
            local cp = combo_points.current
            spend(cp, "combo_points")
            
            applyDebuff("target", "rupture")
        end,
    },
    
    slice_and_dice = {
        id = 5171,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            if glyph.slice_and_dice.enabled then return 0 end
            return 25
        end,
        spendType = "energy",
        
        handler = function ()
            local cp = combo_points.current
            spend(cp, "combo_points")
            
            applyBuff("slice_and_dice", 12 + (3 * cp))
        end,
    },
      ambush = {
        id = 8676,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 60,  -- Verified: MoP authentic energy cost
        spendType = "energy",
        
        requires = function()
            if not stealthed.all then return false, "not stealthed" end
            return true
        end,
        
        handler = function ()
            -- MoP: Ambush generates 2 CP (3 with glyph)
            gain(glyph.ambush.enabled and 3 or 2, "combo_points")
            
            if not buff.shadow_dance.up then
                removeBuff("stealth")
            end
        end,
    },
    
    vanish = {
        id = 1856,
        cast = 0,
        cooldown = function() return glyph.vanish.enabled and 150 or 180 end,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        handler = function ()
            applyBuff("vanish")
            applyBuff("stealth")
            -- Remove all threat
        end,
    },
    
    kick = {
        id = 1766,
        cast = 0,
        cooldown = function() return glyph.kick.enabled and 13 or 15 end,
        gcd = "off",
        
        handler = function ()
            -- Interrupt target and lock out that school for 5 sec
        end,
    },
    
    redirect = {
        id = 73981,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        handler = function ()
            -- Transfer combo points to new target
        end,
    },
    
    fan_of_knives = {
        id = 51723,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 35,
        spendType = "energy",
        
        handler = function ()
            gain(1, "combo_points")
        end,
    },
    
    shuriken_toss = {
        id = 114014,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 40,
        spendType = "energy",
        
        talent = "shuriken_toss",
        
        handler = function ()
            gain(1, "combo_points")
        end,
    },
    
    shadowstep = {
        id = 36554,
        cast = 0,
        cooldown = 24,
        gcd = "spell",
        
        talent = "shadowstep",
        
        handler = function ()
            -- Teleport behind target and increase next damage ability
            applyBuff("shadowstep")
        end,
    },
    
    preparation = {
        id = 14185,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
        
        talent = "preparation",
        
        handler = function ()
            -- Reset cooldowns of various abilities
            setCooldown("vanish", 0)
            setCooldown("sprint", 0)
            setCooldown("shadowstep", 0)
            
            -- If glyphed, also reset these
            if glyph.preparation.enabled then
                setCooldown("kick", 0)
                setCooldown("dismantle", 0) -- Not usually in MoP but included for completeness
                setCooldown("smoke_bomb", 0)
            end
        end,
    },
    
    burst_of_speed = {
        id = 108212,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 60,
        spendType = "energy",
        
        talent = "burst_of_speed",
        
        handler = function ()
            applyBuff("burst_of_speed")
            -- Remove movement impairing effects
        end,
    },
    
    tricks_of_the_trade = {
        id = 57934,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        handler = function ()
            applyBuff("tricks_of_the_trade")
        end,
    },
    
    distract = {
        id = 1725,
        cast = 0,
        cooldown = function() return glyph.distract.enabled and 20 or 30 end,
        gcd = "spell",
        
        spend = 30,
        spendType = "energy",
        
        handler = function ()
            -- Distracts targets, causing them to face away
        end,
    },
    
    feint = {
        id = 1966,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        
        spend = 20,
        spendType = "energy",
        
        handler = function ()
            applyBuff("feint")
        end,
    },
    
    blind = {
        id = 2094,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        spend = 15,
        spendType = "energy",
        
        handler = function ()
            applyDebuff("target", "blind")
        end,
    },
    
    evasion = {
        id = 5277,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        toggle = "defensives",
        
        handler = function ()
            applyBuff("evasion")
        end,
    },
    
    cloak_of_shadows = {
        id = 31224,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        toggle = "defensives",
        
        handler = function ()
            applyBuff("cloak_of_shadows")
            -- Remove magical debuffs
        end,
    },
    
    sap = {
        id = 6770,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 35,
        spendType = "energy",
        
        requires = function()
            if not stealthed.all then return false, "not stealthed" end
            return true
        end,
        
        handler = function ()
            applyDebuff("target", "sap")
        end,
    },
    
    sprint = {
        id = 2983,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        handler = function ()
            applyBuff("sprint")
        end,
    },
    
    apply_poison = {
        id = 2823, -- Deadly Poison
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        handler = function ()
            -- Apply poison to weapons
        end,
    },
} )

-- Register default pack for MoP Assassination Rogue
spec:RegisterPack( "Assassination", 20250517, [[Hekili:T1tBVTnUr8pkEYV8iQu0j)Nf5aP38KYDXtl9i5rPjbJPNH1YAksY(OkvoS5Q2O5vbgdIUw2dejxvLvuPzQdxiMmmpFmShjl3ZxaeHTWwodzLbh7(Gg35W)IVxtdNmTzpF(S)T3BtPS8wtpA5CELlztZQeX0BP8kaOBcbpNFgmrW68YHL0pCc6uzVqBNsxIxMTmppQKlu5lpdVMXHrMVNtSM(6awj4Mjdq1Q5lhhpZIWUq6jYBzNxZFs2dk6VtCzItwKJFriiKsOFJ0iBjzvQxEReb4KGkAwLYoTkELuUKyEPbzR4kWKV9zhHjevQi5Qemi93kj8QBdH3(S86R1viPsvoMqv0imVScGvGnml2CkD7OJkpz7LfbATIYs0ccnTZvmM(4cfS0dpEPTw3jEasRlSyqUoJdlsNzYX0LiKpyihcDJYiLza9admWK8I3hb4aUAHkoJ62ZA1cfUDO9vcOF1]])

-- Register pack selector for Assassination

-- Assassination-specific state tables
spec:RegisterStateTable("stealthed", { all = false, rogue = false })

-- Handle stealth state tracking
spec:RegisterHook("reset_preprocess", function()
    if buff.stealth.up or buff.vanish.up or buff.subterfuge.up then
        stealthed.all = true
        stealthed.rogue = true
    else
        stealthed.all = false
        stealthed.rogue = false
    end
    
    -- MoP stealth detection for abilities
    if talent.shadow_focus.enabled and stealthed.all then
        -- Shadow Focus reduces energy costs by 75% in stealth
        for action_name, action in pairs(state.actions) do
            if action.spendType == "energy" then
                action.spend = action.spend * 0.25
            end
        end
    end
end)

-- Register ranges for Assassination
spec:RegisterRanges(
    "mutilate",           -- 5 yards (melee)
    "garrote",            -- 5 yards (melee)
    "throw",              -- 30 yards
    "blind",              -- 15 yards
    "shuriken_toss"       -- 30 yards
)

-- Register options for Assassination
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 2,
    
    gcd = "spell",
    
    package = "Assassination",
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 3,
    
    potion = "virmen_bite_potion",
    
    -- Assassination-specific options
    envenom_pool_pct = 50,       -- Energy percentage to pool before Envenom
    priority_rotation = false,   -- Ignore energy pooling
    use_rupture = true,          -- Use Rupture in rotation
    use_garrote = true,          -- Use Garrote in rotation
    maintain_garrote = true,     -- Keep Garrote up in single target
    vendetta_duration = 20,      -- Vendetta duration (for sync calculations)
} )

-- Assassination-specific settings
spec:RegisterSetting("envenom_pool_pct", 50, {
    name = "Envenom Energy Pool %",
    desc = "Set the percentage of energy the addon should recommend to pool up to before using Envenom in non-priority rotations.",
    type = "range",
    min = 0,
    max = 100,
    step = 5,
    width = "full"
})

spec:RegisterSetting("priority_rotation", false, {
    name = "Use Priority Rotation",
    desc = "If checked, the addon will prioritize using abilities immediately instead of waiting for energy pools and buff alignments.",
    type = "toggle",
    width = "full"
})

spec:RegisterSetting("maintain_garrote", true, {
    name = "Maintain |T132297:0|t Garrote",
    desc = "If checked, the addon will recommend keeping |T132297:0|t Garrote active on the target in single-target scenarios.",
    type = "toggle",
    width = "full"
})
