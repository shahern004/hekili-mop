-- RogueCombat.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Rogue: Combat spec

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

local spec = Hekili:NewSpecialization( 260 ) -- Combat spec ID for MoP

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

-- Register resources
spec:RegisterResource( 4 ) -- ComboPoints = 4 in MoP
spec:RegisterResource( 3 ) -- Energy = 3 in MoP

-- Enhanced Combat Log Event Tracking for Combat Rogue
local combatCombatLogFrame = CreateFrame("Frame")
local combatCombatLogEvents = {}

local function RegisterCombatCombatLogEvent(event, handler)
    combatCombatLogEvents[event] = handler
end

local function CombatCombatLogEventHandler(self, event, ...)
    local subEvent = select(2, ...)
    local handler = combatCombatLogEvents[subEvent]
    if handler then
        handler(...)
    end
end

combatCombatLogFrame:SetScript("OnEvent", CombatCombatLogEventHandler)
combatCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Combat Rogue specific combat log tracking
RegisterCombatCombatLogEvent("SPELL_ENERGIZE", function(timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, amount, powerType)
    if sourceGUID == UnitGUID("player") then
        if spellID == 51637 then -- Relentless Strikes
            state.relentless_strikes_procs = (state.relentless_strikes_procs or 0) + 1
            state.relentless_strikes_last_proc = GetTime()
        elseif spellID == 14181 then -- Restless Blades energy return
            state.restless_blades_energy = (state.restless_blades_energy or 0) + amount
            state.restless_blades_last_proc = GetTime()
        elseif spellID == 108216 then -- Adrenaline Rush energy gain
            state.adrenaline_rush_energy = (state.adrenaline_rush_energy or 0) + amount
        end
    end
end)

RegisterCombatCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, auraType)
    if sourceGUID == UnitGUID("player") then
        if spellID == 84617 then -- Revealing Strike
            state.revealing_strike_applied = GetTime()
            state.revealing_strike_target = destGUID
        elseif spellID == 84745 then -- Shallow Insight (Bandit's Guile 1st)
            state.bandits_guile_stacks = 1
            state.bandits_guile_applied = GetTime()
        elseif spellID == 84746 then -- Moderate Insight (Bandit's Guile 2nd)
            state.bandits_guile_stacks = 2
            state.bandits_guile_applied = GetTime()
        elseif spellID == 84747 then -- Deep Insight (Bandit's Guile 3rd)
            state.bandits_guile_stacks = 3
            state.bandits_guile_applied = GetTime()
        elseif spellID == 13750 then -- Adrenaline Rush
            state.adrenaline_rush_applied = GetTime()
        elseif spellID == 13877 then -- Blade Flurry
            state.blade_flurry_applied = GetTime()
        end
    end
end)

RegisterCombatCombatLogEvent("SPELL_AURA_REMOVED", function(timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, auraType)
    if sourceGUID == UnitGUID("player") then
        if spellID == 84617 then -- Revealing Strike removed
            state.revealing_strike_applied = 0
            state.revealing_strike_target = nil
        elseif spellID == 13750 then -- Adrenaline Rush removed
            state.adrenaline_rush_applied = 0
        elseif spellID == 13877 then -- Blade Flurry removed  
            state.blade_flurry_applied = 0
        end
    end
end)

RegisterCombatCombatLogEvent("SPELL_CAST_SUCCESS", function(timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if sourceGUID == UnitGUID("player") then
        if spellID == 1752 then -- Sinister Strike
            state.sinister_strike_casts = (state.sinister_strike_casts or 0) + 1
            state.last_sinister_strike = GetTime()
        elseif spellID == 51690 then -- Killing Spree
            state.killing_spree_last_cast = GetTime()
        elseif spellID == 2098 then -- Eviscerate
            state.last_eviscerate = GetTime()
            -- Restless Blades cooldown reduction
            if state.combo_points and state.combo_points > 0 then
                local reduction = state.combo_points * 2 -- 2 seconds per combo point
                state.restless_blades_reduction = (state.restless_blades_reduction or 0) + reduction
            end
        elseif spellID == 5171 then -- Slice and Dice
            state.last_slice_and_dice = GetTime()
            -- Restless Blades cooldown reduction
            if state.combo_points and state.combo_points > 0 then
                local reduction = state.combo_points * 2
                state.restless_blades_reduction = (state.restless_blades_reduction or 0) + reduction
            end
        end
    end
end)

-- Enhanced Resource Systems for Combat Rogue
spec:RegisterResource( 3, { -- Energy = 3 in MoP
    base_regen = function ()
        local combat_potency_bonus = 0
        local relentless_strikes_bonus = 0
        local adrenaline_rush_bonus = 0
        
        -- Combat Potency: 20% chance on white hit to gain 15 energy
        if talent.combat_potency and talent.combat_potency.enabled then
            combat_potency_bonus = 3 -- Average 15 * 0.20 = 3 energy per second from auto attacks
        end
        
        -- Relentless Strikes: Finishing moves have 20% chance per combo point to restore 25 energy
        if talent.relentless_strikes and talent.relentless_strikes.enabled then
            relentless_strikes_bonus = 2 -- Average bonus from finishing moves
        end
        
        -- Adrenaline Rush: 100% increased energy regeneration
        if buff.adrenaline_rush.up then
            adrenaline_rush_bonus = 10 -- Doubles base regen
        end
        
        return 10 + combat_potency_bonus + relentless_strikes_bonus + adrenaline_rush_bonus
    end,
} )

spec:RegisterResource( 4, { -- ComboPoints = 4 in MoP
    base_regen = function ()
        local cp_generation = 0
        
        -- Sinister Strike and other builders generate combo points
        if action.sinister_strike.lastCast and GetTime() - action.sinister_strike.lastCast < 1 then
            cp_generation = cp_generation + 1
        end
        
        -- Combat Potency can grant combo points
        if talent.combat_potency and talent.combat_potency.enabled then
            cp_generation = cp_generation + 0.2 -- 20% chance on white hit
        end
        
        return cp_generation
    end,
} )

-- Comprehensive Tier Set Registration for Combat Rogue
-- Tier 13: Blackfang Battleweave (Dragon Soul)
spec:RegisterGear( "tier13", 77009, 77010, 77011, 77012, 77013 )
spec:RegisterGear( "tier13_lfr", 78773, 78774, 78775, 78776, 78777 )
spec:RegisterGear( "tier13_heroic", 78393, 78394, 78395, 78396, 78397 )

-- Tier 14: Battlegear of the Thousandfold Blades (Mogu'shan Vaults/Heart of Fear)
spec:RegisterGear( "tier14", 85299, 85300, 85301, 85302, 85303 )
spec:RegisterGear( "tier14_lfr", 89238, 89239, 89240, 89241, 89242 )
spec:RegisterGear( "tier14_heroic", 86659, 86660, 86661, 86662, 86663 )

-- Tier 15: Battlegear of the Unblinking Vigil (Throne of Thunder)
spec:RegisterGear( "tier15", 95298, 95299, 95300, 95301, 95302 )
spec:RegisterGear( "tier15_lfr", 96665, 96666, 96667, 96668, 96669 )
spec:RegisterGear( "tier15_heroic", 96425, 96426, 96427, 96428, 96429 )
spec:RegisterGear( "tier15_thunderforged", 97045, 97046, 97047, 97048, 97049 )

-- Tier 16: Barbed Assassin Battlegear (Siege of Orgrimmar)
spec:RegisterGear( "tier16", 99375, 99376, 99377, 99378, 99379 )
spec:RegisterGear( "tier16_lfr", 104426, 104427, 104428, 104429, 104430 )
spec:RegisterGear( "tier16_normal", 99375, 99376, 99377, 99378, 99379 )
spec:RegisterGear( "tier16_heroic", 104906, 104907, 104908, 104909, 104910 )
spec:RegisterGear( "tier16_mythic", 105249, 105250, 105251, 105252, 105253 )

-- MoP Legendary Items for Rogues
spec:RegisterGear( "golad_twilight_of_aspects", 77949 ) -- Legendary Dagger (Main Hand)
spec:RegisterGear( "tiriosh_nightmare_of_ages", 77950 ) -- Legendary Dagger (Off Hand)
spec:RegisterGear( "legendary_daggers", 77949, 77950 ) -- Combined set

-- Notable MoP Trinkets for Combat Rogues
spec:RegisterGear( "relic_of_xuen", 79328 ) -- Relic of Xuen (Agility)
spec:RegisterGear( "bottle_of_infinite_stars", 79327 ) -- Bottle of Infinite Stars
spec:RegisterGear( "terror_in_the_mists", 87057 ) -- Terror in the Mists
spec:RegisterGear( "windswept_pages", 77207 ) -- Windswept Pages
spec:RegisterGear( "bell_of_enraging_resonance", 77211 ) -- Bell of Enraging Resonance
spec:RegisterGear( "vial_of_shadows", 77207 ) -- Vial of Shadows
spec:RegisterGear( "heart_of_unliving", 77201 ) -- Heart of Unliving
spec:RegisterGear( "creche_of_the_final_dragon", 77205 ) -- Creche of the Final Dragon

-- Rogue set bonuses with tier identification
spec:RegisterGear( "rogue_pvp_s11", 72412, 72413, 72414, 72415, 72416 ) -- S11 PvP Set
spec:RegisterGear( "rogue_pvp_s12", 84415, 84416, 84417, 84418, 84419 ) -- S12 PvP Set  
spec:RegisterGear( "rogue_pvp_s13", 91379, 91380, 91381, 91382, 91383 ) -- S13 PvP Set
spec:RegisterGear( "rogue_pvp_s14", 103532, 103533, 103534, 103535, 103536 ) -- S14 PvP Set

-- Notable Combat Rogue weapons
spec:RegisterGear( "gurthalak_voice_of_deeps", 77191 ) -- Gurthalak, Voice of the Deeps (Tentacle proc)
spec:RegisterGear( "experimental_specimen_slicer", 78478 ) -- Experimental Specimen Slicer
spec:RegisterGear( "vishanka_jaws_of_earth", 77218 ) -- Vishanka, Jaws of the Earth
spec:RegisterGear( "the_sleeper", 77193 ) -- The Sleeper (Proc: Sleep)
spec:RegisterGear( "tarecgosa_rest", 71086 ) -- Tarecgosa's Rest (Legendary Staff)
spec:RegisterGear( "dragonwrath", 71086 ) -- Dragonwrath, Tarecgosa's Rest

-- Tier set aura associations for Combat Rogue
spec:RegisterAuras( {
    -- T13 Set Bonuses
    rogue_t13_2pc = {
        id = 105849, -- 2 pieces: Tricks of the Trade grants you 15 energy.
        duration = 3600,
        max_stack = 1,
    },
    rogue_t13_4pc = {
        id = 105856, -- 4 pieces: Shadow Dance also grants 100% increased combo point generation for its duration.
        duration = 3600,
        max_stack = 1,
    },
    
    -- T14 Set Bonuses
    rogue_t14_2pc = {
        id = 123123, -- 2 pieces: Sinister Strike has a 40% chance to grant Insight, increasing agility by 2000 for 15 sec.
        duration = 3600,
        max_stack = 1,
    },
    rogue_t14_4pc = {
        id = 123125, -- 4 pieces: Finishing moves have a 15% chance per combo point to make your next Fan of Knives cost no energy.
        duration = 3600,
        max_stack = 1,
    },
    
    -- T15 Set Bonuses  
    rogue_t15_2pc = {
        id = 138142, -- 2 pieces: Blade Flurry strikes 1 additional nearby enemy.
        duration = 3600,
        max_stack = 1,
    },
    rogue_t15_4pc = {
        id = 138144, -- 4 pieces: Revealing Strike also increases your agility by 750 for 24 sec.
        duration = 3600,
        max_stack = 1,
    },
    
    -- T16 Set Bonuses
    rogue_t16_2pc = {
        id = 144953, -- 2 pieces: Sinister Strike generates 1 additional combo point.
        duration = 3600,
        max_stack = 1,
    },
    rogue_t16_4pc = {
        id = 144954, -- 4 pieces: Finishing moves have a 15% chance per combo point to grant Shadow Clone, causing abilities to strike an additional time for 6 sec.
        duration = 3600,
        max_stack = 1,
    },
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

-- Comprehensive MoP Combat Rogue Glyphs System
spec:RegisterGlyphs( {
    -- MAJOR GLYPHS (Critical tactical modifications for Combat spec)
    glyph_of_adrenaline_rush = {
        id = 56808,
        name = "Glyph of Adrenaline Rush",
        item = 42954,
        description = "Increases the duration of Adrenaline Rush by 5 seconds.",
        effect = function() return "adrenaline_rush_duration" end,
    },
    glyph_of_blade_flurry = {
        id = 56818,
        name = "Glyph of Blade Flurry",
        item = 42964,
        description = "Blade Flurry has no energy cost, but no longer generates combo points.",
        effect = function() return "blade_flurry_energy_free" end,
    },
    glyph_of_killing_spree = {
        id = 63252,
        name = "Glyph of Killing Spree",
        item = 45761,
        description = "Reduces the cooldown of Killing Spree by 45 seconds.",
        effect = function() return "killing_spree_cooldown_reduction" end,
    },
    glyph_of_revealing_strike = {
        id = 56814,
        name = "Glyph of Revealing Strike",
        item = 42960,
        description = "Revealing Strike increases damage of finishing moves by additional 10%.",
        effect = function() return "revealing_strike_damage_bonus" end,
    },
    glyph_of_sinister_strike = {
        id = 56821,
        name = "Glyph of Sinister Strike",
        item = 42967,
        description = "Sinister Strike has a 20% chance to generate an additional combo point.",
        effect = function() return "sinister_strike_combo_chance" end,
    },
    glyph_of_eviscerate = {
        id = 56802,
        name = "Glyph of Eviscerate",
        item = 42948,
        description = "Eviscerate critical strikes have a 50% chance to refund 1 combo point.",
        effect = function() return "eviscerate_combo_refund" end,
    },
    glyph_of_slice_and_dice = {
        id = 56810,
        name = "Glyph of Slice and Dice", 
        item = 42956,
        description = "Slice and Dice costs no energy.",
        effect = function() return "slice_and_dice_free" end,
    },
    glyph_of_expose_armor = {
        id = 56803,
        name = "Glyph of Expose Armor",
        item = 42949,
        description = "Expose Armor lasts 24 seconds longer.",
        effect = function() return "expose_armor_duration" end,
    },
    glyph_of_fan_of_knives = {
        id = 63254,
        name = "Glyph of Fan of Knives",
        item = 45762,
        description = "Increases the range of Fan of Knives by 5 yards.",
        effect = function() return "fan_of_knives_range" end,
    },
    glyph_of_preparation = {
        id = 56819,
        name = "Glyph of Preparation",
        item = 42965,
        description = "Adds Dismantle, Kick, and Smoke Bomb to abilities reset by Preparation.",
        effect = function() return "preparation_extended_reset" end,
    },
    glyph_of_blind = {
        id = 91299,
        name = "Glyph of Blind",
        item = 42966,
        description = "Removes damage over time effects from the target of Blind.",
        effect = function() return "blind_dot_removal" end,
    },
    glyph_of_vanish = {
        id = 89758,
        name = "Glyph of Vanish",
        item = 42961,
        description = "When you Vanish, your threat is reset on all enemies.",
        effect = function() return "vanish_threat_reset" end,
    },
    glyph_of_sprint = {
        id = 56811,
        name = "Glyph of Sprint",
        item = 42955,
        description = "Increases the duration of Sprint by 1 second.",
        effect = function() return "sprint_duration" end,
    },
    glyph_of_feint = {
        id = 56804,
        name = "Glyph of Feint",
        item = 42959,
        description = "Increases the duration of Feint by 2 seconds.",
        effect = function() return "feint_duration" end,
    },
    glyph_of_evasion = {
        id = 56799,
        name = "Glyph of Evasion",
        item = 42946,
        description = "Increases the duration of Evasion by 5 seconds.",
        effect = function() return "evasion_duration" end,
    },
    glyph_of_gouge = {
        id = 56809,
        name = "Glyph of Gouge",
        item = 42957,
        description = "Reduces the energy cost of Gouge by 25.",
        effect = function() return "gouge_energy_reduction" end,
    },
    glyph_of_kick = {
        id = 56805,
        name = "Glyph of Kick",
        item = 42951,
        description = "Reduces the cooldown of Kick by 2 seconds.",
        effect = function() return "kick_cooldown_reduction" end,
    },
    glyph_of_deadly_throw = {
        id = 56806,
        name = "Glyph of Deadly Throw",
        item = 42952,
        description = "Deadly Throw now interrupts spellcasting for 3 seconds.",
        effect = function() return "deadly_throw_interrupt" end,
    },
    glyph_of_tricks_of_the_trade = {
        id = 63256,
        name = "Glyph of Tricks of the Trade",
        item = 42968,
        description = "Tricks of the Trade lasts an additional 4 seconds.",
        effect = function() return "tricks_duration" end,
    },
    glyph_of_crippling_poison = {
        id = 56820,
        name = "Glyph of Crippling Poison",
        item = 42963,
        description = "Crippling Poison reduces movement speed by an additional 20%.",
        effect = function() return "crippling_poison_slow" end,
    },
    glyph_of_sap = {
        id = 56798,
        name = "Glyph of Sap",
        item = 42945,
        description = "Increases the duration of Sap by 20 seconds.",
        effect = function() return "sap_duration" end,
    },

    -- MINOR GLYPHS (Quality of life improvements)
    glyph_of_blinding_powder = {
        id = 63415,
        name = "Glyph of Blinding Powder",
        item = 45764,
        description = "Blind ability no longer requires a reagent.",
        effect = function() return "blind_no_reagent" end,
    },
    glyph_of_detection = {
        id = 57115,
        name = "Glyph of Detection",
        item = 42972,
        description = "Increases the range at which you can detect stealthed or invisible enemies.",
        effect = function() return "stealth_detection_range" end,
    },
    glyph_of_distraction = {
        id = 57114,
        name = "Glyph of Distraction",
        item = 42973,
        description = "Increases the range of Distract by 5 yards.",
        effect = function() return "distract_range" end,
    },
    glyph_of_hemorrhaging_veins = {
        id = 58037,
        name = "Glyph of Hemorrhaging Veins",
        item = 42974,
        description = "Hemorrhage ability now trails blood on the floor.",
        effect = function() return "hemorrhage_visual" end,
    },
    glyph_of_pick_pocket = {
        id = 57112,
        name = "Glyph of Pick Pocket",
        item = 42975,
        description = "Increases the range of Pick Pocket by 5 yards.",
        effect = function() return "pick_pocket_range" end,
    },
    glyph_of_poisons = {
        id = 58036,
        name = "Glyph of Poisons",
        item = 42976,
        description = "Applying poisons to weapons grants 50% chance to apply to other weapon as well.",
        effect = function() return "poison_application_spread" end,
    },
    glyph_of_safe_fall = {
        id = 57113,
        name = "Glyph of Safe Fall",
        item = 42977,
        description = "Reduces the damage taken from falling by 30%.",
        effect = function() return "safe_fall_damage_reduction" end,
    },
    glyph_of_tricks_minor = {
        id = 57118,
        name = "Glyph of Tricks of the Trade",
        item = 42978,
        description = "When you use Tricks of the Trade, you gain 10% increased movement speed for 6 seconds.",
        effect = function() return "tricks_movement_speed" end,
    },
    glyph_of_vanish_minor = {
        id = 57117,
        name = "Glyph of Vanish",
        item = 42979,
        description = "Reduces the cooldown of Vanish ability by 30 seconds.",
        effect = function() return "vanish_cooldown_reduction" end,
    },
    glyph_of_pick_lock = {
        id = 58027,
        name = "Glyph of Pick Lock",
        item = 42980,
        description = "Pick Lock no longer requires Thieves' Tools.",
        effect = function() return "pick_lock_no_tools" end,
    },

    -- MOP-SPECIFIC GLYPHS
    glyph_of_blade_throw = {
        id = 146666,
        name = "Glyph of Blade Throw",
        item = 104102,
        description = "Throw attacks have 100% increased range.",
        effect = function() return "throw_range_increase" end,
    },
    glyph_of_combat_expertise = {
        id = 146667,
        name = "Glyph of Combat Expertise",
        item = 104103,
        description = "Combat abilities grant 10% parry for 8 seconds.",
        effect = function() return "combat_parry_bonus" end,
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

-- Combat specific auras
spec:RegisterAuras( {
    -- Energy regeneration increased by 20%.
    adrenaline_rush = {
        id = 13750,
        duration = function() return glyph.adrenaline_rush.enabled and 20 or 15 end,
        max_stack = 1,
    },
    -- Revealing Strike: Increases the effectiveness of your finishing moves by 35%.
    revealing_strike = {
        id = 84617,
        duration = 24,
        max_stack = 1,
    },
    -- Blade Flurry: Strikes enemies within 8 yards with normalized attacks.
    blade_flurry = {
        id = 13877,
        duration = 3600,
        max_stack = 1,
    },
    -- Killing Spree: Teleporting between enemies, dealing damage over 3 sec.
    killing_spree = {
        id = 51690,
        duration = 3,
        max_stack = 1,
    },
    -- Restless Blades: Finishing moves reduce cooldowns
    restless_blades = {
        id = 79096,
        duration = 3600,
        max_stack = 1,
    },
    -- Bandit's Guile: Three stacks of insight increasing damage
    shallow_insight = {
        id = 84745,
        duration = 15,
        max_stack = 1,
    },
    -- Shared rogue auras
    -- Stealth-related
    stealth = {
        id = 1784,
        duration = 3600,
        max_stack = 1,
    },
    vanish = {
        id = 11327,
        duration = 3,
        max_stack = 1,
    },
    -- Poisons
    crippling_poison = {
        id = 3408,
        duration = 3600,
        max_stack = 1,
    },
    deadly_poison = {
        id = 2823,
        duration = 3600,
        max_stack = 1,
    },
    deadly_poison_dot = {
        id = 2818,
        duration = function () return 12 * haste end,
        tick_time = 3,
        max_stack = 5,
        meta = {
            last_tick = function( t ) return t.up and ( tracked_bleeds.deadly_poison_dot.last_tick[ target.unit ] or t.applied ) or 0 end,
            tick_time = function( t )
                if t.down then return haste * 2 end
                local hasteMod = tracked_bleeds.deadly_poison_dot.haste[ target.unit ]
                hasteMod = 2 * ( hasteMod and ( 100 / hasteMod ) or haste )
                return hasteMod 
            end,
            haste_pct = function( t ) return ( 100 / haste ) end,
            haste_pct_next_tick = function( t ) return t.up and ( tracked_bleeds.deadly_poison_dot.haste[ target.unit ] or ( 100 / haste ) ) or 0 end,
        },
    },
    mind_numbing_poison = {
        id = 5761,
        duration = 3600,
        max_stack = 1,
    },
    wound_poison = {
        id = 8679,
        duration = 3600,
        max_stack = 1,
    },
    leeching_poison = {
        id = 108211,
        duration = 3600,
        max_stack = 1,
    },
    paralytic_poison = {
        id = 108215,
        duration = 3600,
        max_stack = 1,
    },
    -- Bleeds
    garrote = {
        id = 703,
        duration = function() return glyph.garrote.enabled and 21 or 18 end,
        tick_time = 3,
        max_stack = 1,
        meta = {
            last_tick = function( t ) return t.up and ( tracked_bleeds.garrote.last_tick[ target.unit ] or t.applied ) or 0 end,
            tick_time = function( t )
                if t.down then return haste * 3 end
                local hasteMod = tracked_bleeds.garrote.haste[ target.unit ]
                hasteMod = 3 * ( hasteMod and ( 100 / hasteMod ) or haste )
                return hasteMod 
            end,
            haste_pct = function( t ) return ( 100 / haste ) end,
            haste_pct_next_tick = function( t ) return t.up and ( tracked_bleeds.garrote.haste[ target.unit ] or ( 100 / haste ) ) or 0 end,
        },
    },
    rupture = {
        id = 1943,
        duration = function() 
            if combo_points.current == 0 then return 8
            elseif combo_points.current == 1 then return 10
            elseif combo_points.current == 2 then return 12
            elseif combo_points.current == 3 then return 14
            elseif combo_points.current == 4 then return 16
            else return 18 end
        end,
        tick_time = 2,
        max_stack = 1,
        meta = {
            last_tick = function( t ) return t.up and ( tracked_bleeds.rupture.last_tick[ target.unit ] or t.applied ) or 0 end,
            tick_time = function( t )
                if t.down then return haste * 2 end
                local hasteMod = tracked_bleeds.rupture.haste[ target.unit ]
                hasteMod = 2 * ( hasteMod and ( 100 / hasteMod ) or haste )
                return hasteMod 
            end,
            haste_pct = function( t ) return ( 100 / haste ) end,
            haste_pct_next_tick = function( t ) return t.up and ( tracked_bleeds.rupture.haste[ target.unit ] or ( 100 / haste ) ) or 0 end,
        },
    },
    moderate_insight = {
        id = 84746,
        duration = 15,
        max_stack = 1,
    },
    deep_insight = {
        id = 84747,
        duration = 15,
        max_stack = 1,
    },
    -- Redirect: Transfers combo points from one target to another
    redirect = {
        id = 73981,
        duration = 3600, -- It's an active ability without a buff duration
        max_stack = 1,
    },
    -- Combat Potency: Chance to generate Energy on off-hand attacks
    combat_potency = {
        id = 35553,
        duration = 3600, -- It's a passive ability
        max_stack = 1,
    },
} )

-- Advanced auras system for Combat Rogue following the enhanced structure
spec:RegisterAuras( {
    -- ===================
    -- CORE COMBAT ABILITIES
    -- ===================
    
    -- Stealth and Vanish
    stealth = {
        id = 1784,
        duration = 3600,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 1784 )
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
    vanish = {
        id = 1856,
        duration = 3,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 1856 )
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
    
    -- Core finishing move buffs
    slice_and_dice = {
        id = 5171,
        duration = function() return 12 + 3 * combo_points.current end,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 5171 )
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
    
    -- Rupture DoT tracking
    rupture = {
        id = 1943,
        duration = function() 
            if combo_points.current == 1 then return 10
            elseif combo_points.current == 2 then return 12
            elseif combo_points.current == 3 then return 14
            elseif combo_points.current == 4 then return 16
            elseif combo_points.current >= 5 then return 18
            else return 8 end
        end,
        tick_time = 2,
        max_stack = 1,
        meta = {
            last_tick = function( t ) return t.up and ( tracked_bleeds.rupture.last_tick[ target.unit ] or t.applied ) or 0 end,
            tick_time = function( t )
                if t.down then return haste * 2 end
                local hasteMod = tracked_bleeds.rupture.haste[ target.unit ]
                hasteMod = 2 * ( hasteMod and ( 100 / hasteMod ) or haste )
                return hasteMod 
            end,
            haste_pct = function( t ) return ( 100 / haste ) end,
            haste_pct_next_tick = function( t ) return t.up and ( tracked_bleeds.rupture.haste[ target.unit ] or ( 100 / haste ) ) or 0 end,
        },
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitDebuffByID( "target", 1943, "player" )
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                
                local now = GetTime()
                if not tracked_bleeds.rupture.haste[ target.unit ] then
                    tracked_bleeds.rupture.haste[ target.unit ] = 100 / haste
                end
                tracked_bleeds.rupture.last_tick[ target.unit ] = now
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- ===================
    -- COMBAT-SPECIFIC AURAS
    -- ===================
    
    -- Adrenaline Rush
    adrenaline_rush = {
        id = 13750,
        duration = 15,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 13750 )
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
    
    -- Blade Flurry
    blade_flurry = {
        id = 13877,
        duration = function() return glyph.blade_flurry.enabled and 15 or 10 end,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 13877 )
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
    
    -- Killing Spree
    killing_spree = {
        id = 51690,
        duration = 3,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 51690 )
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
    
    -- Revealing Strike debuff
    revealing_strike = {
        id = 84617,
        duration = 30,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitDebuffByID( "target", 84617, "player" )
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
    
    -- Bandit's Guile progression
    shallow_insight = {
        id = 84745,
        duration = 15,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 84745 )
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
    moderate_insight = {
        id = 84746,
        duration = 15,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 84746 )
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
    deep_insight = {
        id = 84747,
        duration = 15,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 84747 )
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
    -- SHARED ROGUE ABILITIES
    -- ===================
    
    -- Defensive abilities
    feint = {
        id = 1966,
        duration = function() return glyph.feint.enabled and 7 or 5 end,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 1966 )
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
    evasion = {
        id = 5277,
        duration = function() return glyph.evasion.enabled and 15 or 10 end,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 5277 )
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
    cloak_of_shadows = {
        id = 31224,
        duration = 5,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 31224 )
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
    
    -- Movement abilities
    sprint = {
        id = 2983,
        duration = function() return glyph.sprint.enabled and 9 or 8 end,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 2983 )
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
    -- POISONS
    -- ===================
    
    -- Main Hand Poisons
    deadly_poison = {
        id = 2823,
        duration = 3600,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 2823 )
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
    wound_poison = {
        id = 8679,
        duration = 3600,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 8679 )
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
    
    -- Off Hand Poisons
    crippling_poison = {
        id = 3408,
        duration = 3600,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 3408 )
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
    mind_numbing_poison = {
        id = 5761,
        duration = 3600,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 5761 )
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
    
    -- MoP Poisons
    leeching_poison = {
        id = 108211,
        duration = 3600,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 108211 )
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
    paralytic_poison = {
        id = 108215,
        duration = 3600,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 108215 )
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
    
    -- Poison DoTs
    deadly_poison_dot = {
        id = 2818,
        duration = function () return 12 * haste end,
        tick_time = 3,
        max_stack = 5,
        meta = {
            last_tick = function( t ) return t.up and ( tracked_bleeds.deadly_poison_dot.last_tick[ target.unit ] or t.applied ) or 0 end,
            tick_time = function( t )
                if t.down then return haste * 3 end
                local hasteMod = tracked_bleeds.deadly_poison_dot.haste[ target.unit ]
                hasteMod = 3 * ( hasteMod and ( 100 / hasteMod ) or haste )
                return hasteMod 
            end,
            haste_pct = function( t ) return ( 100 / haste ) end,
            haste_pct_next_tick = function( t ) return t.up and ( tracked_bleeds.deadly_poison_dot.haste[ target.unit ] or ( 100 / haste ) ) or 0 end,
        },
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitDebuffByID( "target", 2818, "player" )
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                
                local now = GetTime()
                if not tracked_bleeds.deadly_poison_dot.haste[ target.unit ] then
                    tracked_bleeds.deadly_poison_dot.haste[ target.unit ] = 100 / haste
                end
                tracked_bleeds.deadly_poison_dot.last_tick[ target.unit ] = now
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- ===================
    -- MOP TALENT AURAS
    -- ===================
    
    -- Shadow Clone
    shadow_clone = {
        id = 108213,
        duration = 15,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 108213 )
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
    
    -- Subterfuge
    subterfuge = {
        id = 115191,
        duration = 3,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 115191 )
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
    
    -- Anticipation
    anticipation = {
        id = 115189,
        duration = 15,
        max_stack = 5,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 115189 )
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
    
    -- Burst of Speed
    burst_of_speed = {
        id = 108212,
        duration = 4,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 108212 )
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
    
    -- Shadow Focus (Passive)
    shadow_focus = {
        id = 108209,
        duration = 3600,
        max_stack = 1,
        generate = function( t, auraType )
            local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "player", 108209 )
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
    -- PASSIVE SYSTEMS
    -- ===================
    
    -- Combat Potency (Passive)
    combat_potency = {
        id = 35553,
        duration = 3600,
        max_stack = 1,
        generate = function( t, auraType )
            if talent.combat_potency.enabled then
                t.name = "Combat Potency"
                t.count = 1
                t.expires = now + 3600
                t.applied = now
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Restless Blades (Passive)
    restless_blades = {
        id = 79096,
        duration = 3600,
        max_stack = 1,
        generate = function( t, auraType )
            if talent.restless_blades.enabled then
                t.name = "Restless Blades"
                t.count = 1
                t.expires = now + 3600
                t.applied = now
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
} )

-- Utility functions
local tracked_bleeds = {}
local function NewBleed(key, id)
    tracked_bleeds[key] = {
        id = id,
        last_seen = 0,
        duration = 0
    }
end

local function UpdateBleed(key, present, expirationTime)
    if not tracked_bleeds[key] then return end
    
    local now = GetTime()
    local bleed = tracked_bleeds[key]
    
    if present and expirationTime then
        bleed.last_seen = now
        bleed.duration = expirationTime - now
    end
end

-- Combat Rogue abilities
spec:RegisterAbilities({
    adrenaline_rush = {
        id = 13750,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 136206,
        
        handler = function ()
            applyBuff("adrenaline_rush")
        end,
    },
    
    ambush = {
        id = 8676,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 60,
        spendType = "energy",
        
        requires = function()
            if not stealthed.all then return false, "not stealthed" end
            return true
        end,
        
        handler = function ()
            gain(glyph.ambush.enabled and 3 or 1, "combo_points")
            removeBuff("stealth")
        end,
    },
    
    blade_flurry = {
        id = 13877,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        
        spend = function() return glyph.blade_flurry.enabled and 0 or 10 end,
        spendType = "energy",
        
        handler = function ()
            if buff.blade_flurry.up then
                removeBuff("blade_flurry")
            else
                applyBuff("blade_flurry")
            end
        end,
    },
    
    eviscerate = {
        id = 2098,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 35,
        spendType = "energy",
        
        handler = function ()
            spend(combo_points, "combo_points")
        end,
    },
    
    killing_spree = {
        id = 51690,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 236277,
        
        handler = function ()
            applyBuff("killing_spree")
        end,
    },
    
    redirect = {
        id = 73981,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        startsCombat = false,
        texture = 236286,
        
        handler = function ()
            -- Just applies the effect; no buff to track
        end,
    },
    
    revealing_strike = {
        id = 84617,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 40,
        spendType = "energy",
        
        startsCombat = true,
        texture = 132298,
        
        handler = function ()
            applyDebuff("target", "revealing_strike")
        end,
    },
    
    sinister_strike = {
        id = 1752,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 40,
        spendType = "energy",
        
        handler = function ()
            gain(1 + (glyph.sinister_strike.enabled and math.random() < 0.2 and 1 or 0), "combo_points")
        end,
    }
})

-- Now define Combat spec states and expressions
spec:RegisterStateExpr("cp_max_spend", function()
    return combo_points.max
end)

-- Combat Potency passive for off-hand energy regen
spec:RegisterHook("reset_postinit", function()
    if state.talent.combat_potency.enabled then
        state:RegisterAuraTracking("combat_potency", {
            aura = "combat_potency",
            state = "combat_potency",
            onApply = function() 
                gain(3, "energy") -- Combat Potency proc (modified for MoP version)
            end,
        })
    end
end)

-- Finish the spec setup for Combat
spec:RegisterStateTable("stealthed", { all = false, rogue = false })
spec:RegisterStateTable("opener_done", { sinister_strike = false, revealing_strike = false })

-- Register ranges for Combat
spec:RegisterRanges(
    "sinister_strike",    -- 5 yards (melee)
    "garrote",            -- 5 yards (melee)
    "shuriken_toss",      -- 30 yards
    "throw",              -- 30 yards
    "blind"               -- 15 yards
)

-- Register default pack for MoP Combat Rogue
spec:RegisterPack( "Combat", 20250517, [[Hekili:T1vBVTTnu4FlbiQSZfnsajQtA2cBlSTJvAm7njo5i5bYqjRtasiik)vfdC9d7tLsksKRceSacS73n7dNjgfORdxKuofvkQXWghRdh7iih7ii)m5rJg9H1SxJw(qAiih(7FAJRyDF9)9EU7VsCgF)upgdVgM)P8HposKXisCicp7(ob2ZXdpixyxvynaLeWZA67v)OBP5fV9IDgOJvzNJVky08ejfY6Fk5cpMPzlPift10fZQMrbrTe)GkbJb(KuIztYJ1YJkuS0LuPitvI1wPcMQZ9w68ttCwc3fj2OUia3wKYLf1wUksoeD5WyKpYpTtn(qbjlGGwaYJCJ6kPCbvrYhSKibHsXEhtYCbuuiP5Iwjr4f0Mn4r)ZhOrqfacFyjXM1TK4JbLD27PVzAcKpTrqLiWkjGdHv(oguYcq(IMwbQajGbbonWfynQh0KVsK)kTDMaHhdiJG6IT2Ot6Ng6G7Z61J6X(JN8GaLPpxluG3xi8)]])

-- Register pack selector for Combat

-- Register options for Combat
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 2,
    
    gcd = "spell",
    
    package = "Combat",
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 3,
    
    potion = "virmen_bite_potion",
    
    -- Combat-specific options
    blade_flurry_targets = 2,    -- Number of targets for Blade Flurry to be worth using
    priority_rotation = false,   -- Ignore energy pooling
    allow_ads = false,           -- Permit usage of Adrenaline Rush if add waves are coming soon
    use_revealing_strike = true, -- Use Revealing Strike in rotation
    use_slice_and_dice = true,   -- Use Slice and Dice in rotation
    use_rupture = true,          -- Use Rupture in rotation
    killing_spree_allowed = true, -- Allow Killing Spree usage
} )

-- Combat-specific settings
spec:RegisterSetting("priority_rotation", false, {
    name = "Use Priority Rotation",
    desc = "If checked, the addon will prioritize using abilities immediately instead of waiting for energy pools and buff alignments.",
    type = "toggle",
    width = "full"
})

spec:RegisterSetting("use_revealing_strike", true, {
    name = "Use |T132298:0|t Revealing Strike",
    desc = "If checked, the addon will recommend using |T132298:0|t Revealing Strike to increase the effectiveness of your finishers.",
    type = "toggle",
    width = "full"
})

spec:RegisterSetting("blade_flurry_targets", 2, {
    name = "Blade Flurry Target Threshold",
    desc = "Set the number of targets required for the addon to recommend using Blade Flurry.",
    type = "range",
    min = 2,
    max = 10,
    step = 1,
    width = "full"
})

-- ===================
-- ADVANCED ACTION PRIORITY LIST REGISTRATION FOR COMBAT ROGUE
-- ===================

spec:RegisterAPL( "combat", 20250517, {
    name = "Combat (Enhanced MoP Implementation)",
    desc = "Advanced Combat Rogue rotation with sophisticated decision-making for MoP.",
    
    -- Pre-combat preparation
    precombat = {
        -- Apply poisons
        { "apply_poison", "lethal=instant,nonlethal=crippling" },
        
        -- Stealth before combat
        { "stealth", "!stealthed.all&!in_combat" },
        
        -- Apply Slice and Dice
        { "slice_and_dice", "!buff.slice_and_dice.up" },
    },
    
    -- Main combat rotation  
    combat = {
        -- === INTERRUPT ===
        { "kick", "target.casting&target.cast.interruptible" },
        
        -- === EMERGENCY ABILITIES ===
        { "cloak_of_shadows", 
          "health.pct<=35&debuff.magic.up&!buff.cloak_of_shadows.up" },
        { "evasion", 
          "health.pct<=40&incoming_damage_5s>health.max*0.3&!buff.evasion.up" },
        { "feint", 
          "incoming_damage_3s>health.max*0.25&energy>=20&!buff.feint.up" },
        
        -- === MAJOR COOLDOWNS ===
        { "adrenaline_rush", 
          "time>4&(combo_points<=2|energy<=30)&toggle.cooldowns" },
        { "killing_spree", 
          "energy<=30&buff.slice_and_dice.up&toggle.cooldowns" },
        { "vanish", 
          "time>10&!buff.adrenaline_rush.up&combo_points<=3&toggle.cooldowns" },
        
        -- === BLADE FLURRY MANAGEMENT ===
        { "blade_flurry", 
          "!buff.blade_flurry.up&spell_targets.blade_flurry>=settings.blade_flurry_targets" },
        { "blade_flurry", 
          "buff.blade_flurry.up&spell_targets.blade_flurry=1" },
        
        -- === STEALTH ABILITIES ===
        { "shadowclone", 
          "buff.stealth.up|buff.vanish.up" },
        
        -- === FINISHING MOVES ===
        -- Slice and Dice maintenance (highest priority)
        { "slice_and_dice", 
          "combo_points>=1&buff.slice_and_dice.remains<=2&" ..
          "settings.use_slice_and_dice" },
        
        -- Rupture for DoT damage
        { "rupture", 
          "combo_points>=4&!dot.rupture.ticking&" ..
          "target.time_to_die>12&settings.use_rupture" },
        
        -- Execute phase Eviscerate  
        { "eviscerate", 
          "combo_points>=4&target.time_to_die<=6" },
        
        -- Standard Eviscerate
        { "eviscerate", 
          "combo_points>=5&target.time_to_die>6" },
        
        -- === COMBO POINT GENERATORS ===
        -- Revealing Strike for debuff
        { "revealing_strike", 
          "!debuff.revealing_strike.up&combo_points<=4&" ..
          "settings.use_revealing_strike" },
        
        -- Sinister Strike for combo points
        { "sinister_strike", 
          "combo_points<=4" },
        
        -- === UTILITY ===
        { "shuriken_toss", 
          "talent.shuriken_toss.enabled&target.distance>8&combo_points<5" },
        
        -- Auto attack fallback
        { "auto_attack", "true" },
    },
    
    -- AoE rotation for multiple targets
    aoe = {
        -- Blade Flurry for cleave
        { "blade_flurry", 
          "!buff.blade_flurry.up&spell_targets.blade_flurry>=2" },
        
        -- Slice and Dice maintenance
        { "slice_and_dice", 
          "combo_points>=1&(!buff.slice_and_dice.up|" ..
          "buff.slice_and_dice.remains<=2)" },
        
        -- Fan of Knives for AoE combo generation
        { "fan_of_knives", 
          "combo_points<5&spell_targets.fan_of_knives>=3&energy>=35" },
        
        -- Crimson Tempest for AoE DoT
        { "crimson_tempest", 
          "combo_points>=4&spell_targets.fan_of_knives>=4&" ..
          "(!dot.crimson_tempest.ticking|dot.crimson_tempest.remains<4)" },
        
        -- Standard finisher
        { "eviscerate", "combo_points>=5&buff.slice_and_dice.up" },
        
        -- Fallback generator
        { "sinister_strike", "combo_points<5&energy>=40" },
    },
    
    -- Cleave rotation for 2-3 targets  
    cleave = {
        -- Blade Flurry for cleave
        { "blade_flurry", 
          "!buff.blade_flurry.up&spell_targets.blade_flurry>=2" },
        
        -- Slice and Dice maintenance
        { "slice_and_dice", 
          "combo_points>=1&(!buff.slice_and_dice.up|" ..
          "buff.slice_and_dice.remains<=2)" },
        
        -- Revealing Strike
        { "revealing_strike", 
          "!debuff.revealing_strike.up&combo_points<=4" },
        
        -- Sinister Strike
        { "sinister_strike", "combo_points<=4" },
        
        -- Eviscerate
        { "eviscerate", "combo_points>=5&target.time_to_die>6" },
    },
}, {
    -- Advanced parameters for sophisticated execution
    energy_pooling_enabled = true,
    bandits_guile_optimization = true,
    blade_flurry_management = true,
    restless_blades_tracking = true,
})
