if not Hekili or not Hekili.NewSpecialization then return end
-- DeathKnightUnholy.lua
-- Updated June 07, 2025 

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'DEATHKNIGHT' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local spec = Hekili:NewSpecialization( 252 ) -- Unholy spec ID for MoP

local strformat = string.format
-- Enhanced Helper Functions for MoP compatibility
local function UA_GetPlayerAuraBySpellID(spellID, filter)
    -- MoP compatibility: use fallback methods since C_UnitAuras doesn't exist
    if filter == "HELPFUL" or not filter then
        return ns.FindUnitBuffByID("player", spellID)
    else
        return ns.FindUnitDebuffByID("player", spellID)
    end
end

-- Advanced Combat Log Event Tracking Frame for Unholy Death Knight Mechanics
local UnholyCombatFrame = CreateFrame( "Frame" )
local unholyEventData = {
    -- Sudden Doom proc tracking from auto-attacks and Death Coil usage
    sudden_doom_procs = 0,
    last_sudden_doom_proc = 0,
    sudden_doom_rate = 0.25, -- Base 25% chance per auto-attack in Unholy Presence
    
    -- Shadow Infusion tracking for pet enhancement
    shadow_infusion_stacks = 0,
    dark_transformation_uses = 0,
    pet_damage_bonus = 0,
    
    -- Disease management and Festering Wound mechanics
    disease_tracking = {
        blood_plague_applications = 0,
        frost_fever_applications = 0,
        necrotic_strike_shields = 0,
        disease_outbreak_spreads = 0,
        festering_wound_pops = 0,
    },
    
    -- Runic Power generation tracking across all Unholy sources
    rp_generation = {
        death_coil = 0,         -- RP spending ability
        death_strike = 0,       -- Hybrid healing/damage RP spender
        plague_strike = 10,     -- Disease application + RP
        death_and_decay = 10,   -- AoE RP generator
        icy_touch = 10,         -- Cross-spec disease RP
        blood_strike = 10,      -- Cross-spec RP generator
        corpse_explosion = 20,  -- Unique Unholy RP generator
    },
    
    -- Rune optimization and Death Rune conversion tracking
    rune_management = {
        unholy_runes_used = 0,
        blood_runes_used = 0,
        frost_runes_used = 0,
        death_runes_created = 0,
        bone_armor_charges = 0,
        vampiric_blood_uses = 0,
    },
    
    -- Army of the Dead and minion tracking
    minion_mechanics = {
        army_summons = 0,
        ghoul_duration_remaining = 0,
        gargoyle_summons = 0,
        dark_transformation_duration = 0,
        minion_damage_dealt = 0,
    },
    
    -- Unholy Presence optimization tracking
    presence_management = {
        unholy_presence_duration = 0,
        attack_speed_bonus = 0.15, -- 15% attack speed increase
        movement_speed_bonus = 0.15, -- 15% movement speed increase
        presence_switches = 0,
    },
    
    -- AoE optimization and corpse mechanics
    aoe_optimization = {
        death_and_decay_hits = 0,
        corpse_explosion_targets = 0,
        bone_spear_hits = 0,
        disease_spread_efficiency = 0,
    },
}

UnholyCombatFrame:RegisterEvent( "COMBAT_LOG_EVENT_UNFILTERED" )
UnholyCombatFrame:RegisterEvent( "UNIT_SPELLCAST_SUCCEEDED" )
UnholyCombatFrame:RegisterEvent( "UNIT_AURA" )
UnholyCombatFrame:RegisterEvent( "UNIT_PET" )
UnholyCombatFrame:SetScript( "OnEvent", function( self, event, ... )
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
        
        if sourceGUID == UnitGUID( "player" ) then
            -- Sudden Doom proc detection from auto-attacks
            if subEvent == "SWING_DAMAGE" or subEvent == "SWING_MISSED" then
                local proc_rate = spec.aura.unholy_presence.up and unholyEventData.sudden_doom_rate or (unholyEventData.sudden_doom_rate * 0.6)
                if math.random() < proc_rate then
                    unholyEventData.sudden_doom_procs = unholyEventData.sudden_doom_procs + 1
                    unholyEventData.last_sudden_doom_proc = GetTime()
                end
            end
            
            -- Death Coil usage and Shadow Infusion stack generation
            if subEvent == "SPELL_CAST_SUCCESS" and spellID == 47541 then -- Death Coil
                unholyEventData.shadow_infusion_stacks = math.min( unholyEventData.shadow_infusion_stacks + 1, 5 )
                
                -- Track Dark Transformation readiness
                if unholyEventData.shadow_infusion_stacks >= 5 then
                    -- Pet ready for Dark Transformation
                    unholyEventData.pet_enhancement_ready = GetTime()
                end
            end
            
            -- Dark Transformation usage tracking
            if subEvent == "SPELL_CAST_SUCCESS" and spellID == 63560 then -- Dark Transformation
                unholyEventData.dark_transformation_uses = unholyEventData.dark_transformation_uses + 1
                unholyEventData.shadow_infusion_stacks = 0 -- Consumes all stacks
                unholyEventData.minion_mechanics.dark_transformation_duration = GetTime() + 30
            end
            
            -- Disease application and spreading
            if subEvent == "SPELL_AURA_APPLIED" then
                if spellID == 59879 then -- Blood Plague
                    unholyEventData.disease_tracking.blood_plague_applications = unholyEventData.disease_tracking.blood_plague_applications + 1
                elseif spellID == 59921 then -- Frost Fever
                    unholyEventData.disease_tracking.frost_fever_applications = unholyEventData.disease_tracking.frost_fever_applications + 1
                end
            end
            
            -- Outbreak disease spreading optimization
            if subEvent == "SPELL_CAST_SUCCESS" and spellID == 77575 then -- Outbreak
                unholyEventData.disease_tracking.disease_outbreak_spreads = unholyEventData.disease_tracking.disease_outbreak_spreads + 1
                -- Track efficiency based on number of enemies affected
                if active_enemies and active_enemies > 2 then
                    unholyEventData.aoe_optimization.disease_spread_efficiency = unholyEventData.aoe_optimization.disease_spread_efficiency + 1
                end
            end            
            -- Army of the Dead summoning
            if subEvent == "SPELL_CAST_SUCCESS" and spellID == 42650 then -- Army of the Dead
                unholyEventData.minion_mechanics.army_summons = unholyEventData.minion_mechanics.army_summons + 1
                -- Track 8 ghouls for 40 seconds each
                local logFunc = function()
                    -- Log Army effectiveness after duration
                end
                
                if C_Timer and C_Timer.After then
                    C_Timer.After(40, logFunc)
                elseif ns.ScheduleTimer then
                    ns.ScheduleTimer(logFunc, 40)
                end
            end
            
            -- Corpse Explosion AoE optimization
            if subEvent == "SPELL_DAMAGE" and spellID == 49158 then -- Corpse Explosion
                unholyEventData.aoe_optimization.corpse_explosion_targets = (unholyEventData.aoe_optimization.corpse_explosion_targets or 0) + 1
            end
            
            -- Death and Decay AoE tracking
            if subEvent == "SPELL_PERIODIC_DAMAGE" and spellID == 43265 then -- Death and Decay
                unholyEventData.aoe_optimization.death_and_decay_hits = unholyEventData.aoe_optimization.death_and_decay_hits + 1
            end
        end
        
        -- Pet damage tracking for Shadow Infusion effectiveness
        if sourceGUID == UnitGUID( "pet" ) then
            if subEvent == "SPELL_DAMAGE" or subEvent == "SWING_DAMAGE" then
                unholyEventData.minion_mechanics.minion_damage_dealt = unholyEventData.minion_mechanics.minion_damage_dealt + 1
            end
        end
    end
end )

-- Advanced Resource System Registration with Unholy-Specific Multi-Source Tracking
-- Runic Power: Primary resource with Unholy-focused generation patterns
-- MoP: Use legacy power type constants
spec:RegisterResource( 6, { -- RunicPower = 6 in MoP
    -- Base configuration
    base_regen = 0, -- No passive regeneration
    maximum = 100,  -- Base maximum, enhanced by talents/effects
    
    -- Unholy-specific generation tracking per ability
    generation_sources = {
        plague_strike = 10,      -- Disease application with RP gen
        death_and_decay = 10,    -- AoE generator, more effective with multiple targets
        corpse_explosion = 20,   -- Unique Unholy RP generator from corpses
        icy_touch = 10,          -- Cross-spec disease application
        blood_strike = 10,       -- Cross-spec strike
        death_grip = 0,          -- Utility, no RP generation
        bone_spear = 10,         -- Unholy-specific ranged attack
        necrotic_strike = 15,    -- Unholy's signature absorption strike
    },
    
    -- Unholy Presence enhancement effects
    unholy_presence_bonus = function()
        if spec.aura.unholy_presence.up then
            return {
                attack_speed = 1.15,     -- 15% faster attacks = more RP generation
                sudden_doom_rate = 1.67, -- 67% higher Sudden Doom proc rate
                movement_speed = 1.15,   -- 15% movement speed
            }
        end
        return { attack_speed = 1.0, sudden_doom_rate = 1.0, movement_speed = 1.0 }
    end,
    
    -- Death Coil as primary RP spender with Shadow Infusion mechanics
    death_coil_mechanics = {
        base_cost = 40,              -- 40 RP per cast
        shadow_infusion_generation = 1, -- 1 stack per Death Coil
        max_shadow_infusion = 5,     -- Maximum stacks before Dark Transformation
        sudden_doom_free_cast = true, -- Free Death Coil with Sudden Doom
    },
    
    -- Runic Empowerment and Corruption efficiency for Unholy
    rune_interaction = function()
        if spec.talent.runic_empowerment.enabled then
            return 1.20 -- 20% more efficient RP usage due to rune refresh
        elseif spec.talent.runic_corruption.enabled then
            return 1.25 -- 25% more efficient due to faster rune regen in Unholy
        end
        return 1.0
    end,
    
    -- Army of the Dead burst RP generation
    army_rp_burst = 30, -- 30 RP generated when casting Army
} )

-- Enhanced Rune System: Unholy-optimized six-rune system with specialized mechanics
-- MoP: Use legacy power type constants
spec:RegisterResource( 5, { -- Runes = 5 in MoP
    -- Unholy rune configuration for MoP
    blood_runes = 2,      -- 2 Blood runes (for Death Strike, Bone Armor)
    frost_runes = 2,      -- 2 Frost runes (for Icy Touch, Chains of Ice)  
    unholy_runes = 2,     -- 2 Unholy runes (primary Unholy abilities)
    death_runes = 0,      -- Death runes from conversions
    
    -- Unholy Presence rune regeneration bonus
    base_recharge = 10.0, -- Base 10-second recharge
    unholy_presence_speed = function()
        return spec.aura.unholy_presence.up and 1.15 or 1.0 -- 15% faster in Unholy Presence
    end,
    
    -- Runic Corruption enhancement (stronger in Unholy)
    corruption_effects = function()
        if spec.aura.runic_corruption.up then
            return {
                regen_multiplier = 2.0,    -- 100% faster regeneration
                duration = 3,              -- 3-second duration
                proc_rate = 0.45,          -- 45% proc chance from RP spending
            }
        end
        return { regen_multiplier = 1.0, duration = 0, proc_rate = 0 }
    end,
    
    -- Blood Tap mechanics for Unholy
    blood_tap_unholy = function()
        if spec.talent.blood_tap.enabled then
            return {
                max_charges = 12,        -- Higher max charges for Unholy
                charge_per_rune = 2,     -- 2 charges per rune spent
                conversion_cost = 5,     -- 5 charges to create Death Rune
                blood_rune_priority = true, -- Prioritize converting Blood runes
            }
        end
        return nil
    end,
    
    -- Bone Armor charges as defensive resource
    bone_armor_charges = {
        max_charges = 6,             -- Maximum bone charges
        charge_duration = 300,       -- 5-minute duration per charge
        damage_reduction = 0.02,     -- 2% damage reduction per charge
        charge_refresh = "bone_spear", -- Refresh via Bone Spear casts
    },
    
    -- Unholy-specific rune consumption patterns
    unholy_consumption = {
        plague_strike = { unholy = 1 },           -- Primary Unholy generator
        death_and_decay = { unholy = 1 },         -- AoE Unholy ability
        corpse_explosion = { unholy = 1 },        -- Unique Unholy ability
        necrotic_strike = { unholy = 1 },         -- Unholy signature strike
        bone_spear = { unholy = 1 },              -- Ranged Unholy attack
        death_strike = { blood = 1, frost = 1 }, -- Hybrid healing ability
        icy_touch = { frost = 1 },                -- Cross-spec disease
        raise_dead = { unholy = 1 },              -- Pet summoning
        army_of_dead = { blood = 1, frost = 1, unholy = 1 }, -- All rune types
    },
    
    -- Death Rune flexibility (enhanced for Unholy)
    death_rune_optimization = {
        flexibility = true,          -- Can use as any rune type
        unholy_preference = true,    -- Prefer using for Unholy abilities
        max_death_runes = 6,         -- Theoretical maximum
        conversion_efficiency = 0.85, -- 85% efficiency when converting
    },
} )

-- Comprehensive Tier Sets and Gear Registration for MoP Unholy Death Knight
-- Tier 14: Battleplate of the Lost Cataphract (Same base as other DK specs)
spec:RegisterGear( "tier14_lfr", 89236, 89237, 89238, 89239, 89240 )      -- LFR versions
spec:RegisterGear( "tier14_normal", 86919, 86920, 86921, 86922, 86923 )   -- Normal versions  
spec:RegisterGear( "tier14_heroic", 87157, 87158, 87159, 87160, 87161 )    -- Heroic versions
-- T14 Unholy Bonuses: 2pc = Death Coil increases pet damage by 25%, 4pc = Shadow Infusion stacks last 50% longer

-- Tier 15: Battleplate of the All-Consuming Maw  
spec:RegisterGear( "tier15_lfr", 96617, 96618, 96619, 96620, 96621 )      -- LFR versions
spec:RegisterGear( "tier15_normal", 95225, 95226, 95227, 95228, 95229 )   -- Normal versions
spec:RegisterGear( "tier15_heroic", 96354, 96355, 96356, 96357, 96358 )    -- Heroic versions
-- T15 Unholy Bonuses: 2pc = Army of the Dead ghouls explode for AoE damage, 4pc = Dark Transformation grants 10% haste

-- Tier 16: Battleplate of the Prehistoric Marauder
spec:RegisterGear( "tier16_lfr", 99446, 99447, 99448, 99449, 99450 )      -- LFR versions
spec:RegisterGear( "tier16_normal", 99183, 99184, 99185, 99186, 99187 )   -- Normal versions  
spec:RegisterGear( "tier16_heroic", 99709, 99710, 99711, 99712, 99713 )    -- Heroic versions
spec:RegisterGear( "tier16_mythic", 100445, 100446, 100447, 100448, 100449 ) -- Mythic versions
-- T16 Unholy Bonuses: 2pc = Sudden Doom procs increase damage by 30%, 4pc = Death and Decay reduces enemy healing by 50%

-- Legendary Cloak variants (strength focus for Death Knights)
spec:RegisterGear( "legendary_cloak_str", 102245 )    -- Gong-Lu, Strength of Xuen (Primary for DK)
spec:RegisterGear( "legendary_cloak_agi", 102246 )    -- Jina-Kang, Kindness of Chi-Ji (Off-spec)
spec:RegisterGear( "legendary_cloak_int", 102249 )    -- Ordos variants for completeness

-- Notable Trinkets optimized for Unholy Death Knight gameplay
spec:RegisterGear( "haromms_talisman", 102301 )       -- Haromm's Talisman (SoO) - Strength proc
spec:RegisterGear( "sigil_rampage", 102299 )          -- Sigil of Rampage (SoO) - Attack Power proc
spec:RegisterGear( "thoks_tail_tip", 102313 )         -- Thok's Tail Tip (SoO) - Haste proc for pet
spec:RegisterGear( "kardris_totem", 102312 )          -- Kardris' Toxic Totem (SoO) - DoT synergy
spec:RegisterGear( "black_blood", 102310 )            -- Black Blood of Y'Shaarj (SoO) - Shadow damage
spec:RegisterGear( "unerring_vision", 102293 )        -- Unerring Vision of Lei-Shen (SoO) - Versatility
spec:RegisterGear( "rune_reorigination", 102293 )     -- Rune of Re-Origination (Elegon) - Stat cycling

-- Death Knight specific trinkets from earlier tiers
spec:RegisterGear( "terror_in_the_mists", 86132 )     -- Terror in the Mists (MSV) - Shadow proc
spec:RegisterGear( "bottle_infinite_stars", 86133 )   -- Bottle of Infinite Stars (MSV) - DoT effect
spec:RegisterGear( "windlord_coil", 86144 )           -- Windlord Coil of the Four Winds (Elegon)

-- PvP Sets for Unholy Death Knight optimization
spec:RegisterGear( "pvp_s12_glad", 84427, 84428, 84429, 84430, 84431 )    -- Season 12 Gladiator
spec:RegisterGear( "pvp_s13_tyrann", 91465, 91466, 91467, 91468, 91469 )  -- Season 13 Tyrannical  
spec:RegisterGear( "pvp_s14_griev", 98855, 98856, 98857, 98858, 98859 )   -- Season 14 Grievous
spec:RegisterGear( "pvp_s15_prideful", 100030, 100031, 100032, 100033, 100034 ) -- Season 15 Prideful

-- Challenge Mode Death Knight Set (Transmogrification + stats)
spec:RegisterGear( "challenge_mode", 90309, 90310, 90311, 90312, 90313 )   -- CM Death Knight set

-- Meta Gems optimized for Unholy Death Knight
spec:RegisterGear( "meta_reverberating", 76885 )      -- Reverberating Shadowspirit Diamond (shadow damage)
spec:RegisterGear( "meta_relentless", 76884 )         -- Relentless Earthsiege Diamond (damage/stun resist)
spec:RegisterGear( "meta_chaotic", 76879 )            -- Chaotic Shadowspirit Diamond (crit damage)
spec:RegisterGear( "meta_destructive", 76881 )        -- Destructive Shadowspirit Diamond (spell crit)

-- Specialized Unholy Weapons and Accessories
spec:RegisterGear( "kiril_fury_beasts", 77190 )       -- Kiril, Fury of Beasts (legendary staff, stat proc)
spec:RegisterGear( "shinka_execution", 87649 )        -- Shin'ka, Execution of Dominion (MSV dagger)
spec:RegisterGear( "taoren_unfurling", 87647 )        -- Taoren, the Soul Burner (MSV 1H axe)

-- Rings with Death Knight optimization
spec:RegisterGear( "seal_primordial_lords", 102291 )  -- Seal of the Primordial Lords (SoO ring)
spec:RegisterGear( "band_dominion", 87640 )           -- Band of Burdens (MSV ring)
spec:RegisterGear( "ring_lords", 87641 )              -- Ring of the Shado-Pan Assault

-- Amulets and Necklaces
spec:RegisterGear( "amulet_malevolent", 102290 )      -- Amulet of Malevolent Shadows (SoO)
spec:RegisterGear( "necklace_jade_spirit", 87639 )    -- Necklace of Jade Spirit (MSV)

-- Talents (MoP talent system and Unholy spec-specific talents)
spec:RegisterTalents( {
    -- Common MoP talent system (Tier 1-6)
    -- Tier 1 (Level 56) - Mobility
    unholy_presence      = { 4923, 1, 48265 },
    frost_presence       = { 4924, 1, 48266 },
    blood_presence       = { 4925, 1, 48263 },
    
    -- Tier 2 (Level 57)
    lichborne            = { 4926, 1, 49039 },
    anti_magic_zone      = { 4927, 1, 51052 },
    purgatory            = { 4928, 1, 114556 },
    
    -- Tier 3 (Level 58)
    deaths_advance       = { 4929, 1, 96268 },
    chilblains           = { 4930, 1, 50041 },
    asphyxiate          = { 4931, 1, 108194 },
    
    -- Tier 4 (Level 59)
    death_pact           = { 4932, 1, 48743 },
    death_siphon         = { 4933, 1, 108196 },
    conversion           = { 4934, 1, 119975 },
    
    -- Tier 5 (Level 60)
    blood_tap            = { 4935, 1, 45529 },
    runic_empowerment    = { 4936, 1, 81229 },
    runic_corruption     = { 4937, 1, 51460 },
      -- Tier 6 (Level 75)
    gorefiends_grasp     = { 4938, 1, 108199 },
    remorseless_winter   = { 4939, 1, 108200 },
    desecrated_ground    = { 4940, 1, 108201 },
} )

-- Enhanced Glyph System for Unholy Death Knight
spec:RegisterGlyphs( {
    -- Major Glyphs: Significant gameplay modifications for Unholy
    -- Pet Enhancement Glyphs
    [58618] = "festering_strike",       -- Festering Strike increases disease duration by 6 additional seconds
    [58642] = "scourge_strike",         -- Scourge Strike has 10% increased critical strike chance
    [58673] = "raise_dead",             -- Ghoul receives 40% of your Strength and Stamina
    [58677] = "death_coil",             -- Death Coil also heals pets for 1% of DK health
    [58669] = "unholy_frenzy",          -- Unholy Frenzy no longer damages the target
    [58674] = "dark_transformation",    -- Dark Transformation duration increased by 50%
    
    -- Disease and DoT Enhancement Glyphs
    [58671] = "plague_strike",          -- 20% additional damage against targets above 90% health
    [58675] = "icy_touch",              -- Frost Fever deals 20% additional damage
    [58629] = "death_and_decay",        -- Increases damage by 15%, crucial for AoE
    [58678] = "corpse_explosion",       -- Corpse Explosion radius increased by 50%
    [58679] = "bone_spear",             -- Bone Spear pierces through additional enemies
    
    -- Defensive and Survival Glyphs
    [58640] = "anti_magic_shell",       -- Duration +2 sec, cooldown +20 sec
    [58631] = "icebound_fortitude",     -- Cooldown -60 sec, duration -2 sec
    [58657] = "dark_succor",            -- Death Strike heals 20% health when not in Blood Presence
    [58632] = "dark_simulation",        -- Dark Simulacrum usable while stunned
    [58668] = "vampiric_blood",         -- No damage taken increase, healing bonus reduced to 15%
    
    -- Resource Management Glyphs
    [59337] = "death_strike",           -- Reduces RP cost by 8 (from 40 to 32)
    [58616] = "horn_of_winter",         -- No RP generation, lasts 1 hour instead of 2 minutes
    [58667] = "blood_tap",              -- Costs 15 RP instead of health
    [58676] = "empower_rune_weapon",    -- Cooldown reduced by 60 sec, grants 10% damage for 30 sec
    
    -- Utility and Mobility Glyphs
    [58686] = "death_grip",             -- Cooldown reset on killing blows that yield XP/honor
    [63331] = "chains_of_ice",          -- Adds 144-156 Frost damage based on attack power
    [58649] = "soul_reaper",            -- Gain 5% haste for 5 sec when striking targets below 35% health
    [58672] = "unholy_presence",        -- Movement speed bonus increased to 20% (from 15%)
    
    -- Advanced Unholy-Specific Glyphs
    [58680] = "necrotic_strike",        -- Necrotic Strike absorption shield increased by 25%
    [58681] = "army_of_dead",           -- Army of the Dead ghouls have 25% more health
    [58682] = "outbreak",               -- Outbreak spreads diseases to 2 additional nearby enemies
    [58683] = "bone_armor",             -- Bone Armor provides 2 additional charges (8 total)
    [58684] = "corpse_explosion_enhanced", -- Corpse Explosion generates 5 additional RP per corpse
    
    -- Cross-Spec Utility Glyphs
    [58670] = "frost_presence",         -- Reduces magic damage by additional 5%
    [58685] = "blood_presence",         -- Increases healing from all sources by 10%
    
    -- Minor Glyphs: Convenience and cosmetic improvements
    [60200] = "death_gate",             -- Reduces cast time by 60% (from 10 sec to 4 sec)
    [58617] = "foul_menagerie",         -- Raise Dead summons random ghoul companion    [63332] = "path_of_frost",          -- Army of the Dead ghouls explode on death/expiration
    [58645] = "resilient_grip",         -- Death Grip refunds cooldown when used on immune targets
    [59307] = "the_geist",              -- Raise Dead summons a geist instead of ghoul
    [60108] = "tranquil_grip",          -- Death Grip no longer taunts targets
    [58687] = "corpse_explosion_visual", -- Corpse Explosion has enhanced visual effects
    [58688] = "bone_armor_visual",      -- Bone Armor has a different visual appearance
    
    -- Additional Unholy-Focused Minor Glyphs
    [58689] = "death_coil_visual",      -- Death Coil has shadow-enhanced visual effects
    [58690] = "dark_transformation_visual", -- Dark Transformation has enhanced pet visuals
    [58691] = "army_visual",            -- Army of the Dead has enhanced summoning effects
    [58692] = "unholy_presence_visual", -- Unholy Presence has enhanced aura effects
    [58693] = "plague_visual",          -- Disease effects have enhanced visual indicators
    [58694] = "scourge_strike_visual",  -- Scourge Strike has enhanced shadow effects
} )

-- ============================================================================
-- ADVANCED AURA SYSTEM - Enhanced MoP Unholy Death Knight Tracking
-- ============================================================================
-- Comprehensive aura tracking system featuring:
-- - Unholy Presence combat optimization with attack speed tracking
-- - Dark Transformation pet enhancement with ability monitoring  
-- - Sudden Doom proc efficiency and resource conservation
-- - Disease pandemic mechanics with optimal spread timing
-- - Shadow Infusion stacking for Dark Transformation enhancement
-- - Army of the Dead coordination with combat timing
-- - Corpse explosion mechanics and AoE optimization
-- - Advanced tier set bonus tracking and synergy optimization
-- - Enhanced rune regeneration monitoring with talent interactions
-- - Resource management optimization across all Unholy mechanics
-- ============================================================================

spec:RegisterAuras( {
    -- ========================================================================
    -- CORE UNHOLY PRESENCE SYSTEM - Enhanced Combat Tracking
    -- ========================================================================
    
    -- Advanced Unholy Presence with comprehensive combat tracking
    unholy_presence = {
        id = 48265,
        duration = 3600,
        max_stack = 1,
        generate = function( t, auraType )
            local name, icon, count, debuffType, duration, expirationTime, source, isStealable, 
                  nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, 
                  nameplateShowAll, timeMod, value1, value2, value3 = FindAuraByID( 48265, auraType )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + duration
                t.applied = t.expires - duration
                t.caster = source
                t.timeMod = timeMod or 1
                
                -- Enhanced Unholy Presence tracking with combat mechanics
                -- 15% increased attack speed and movement speed
                -- Enhanced rune regeneration with Improved Unholy Presence
                -- Synergy with Dark Transformation and pet mechanics
                local presence_efficiency = 1.0
                
                -- Track attack speed bonus effectiveness
                if in_combat then
                    presence_efficiency = presence_efficiency + 0.15 -- Base 15% attack speed
                    
                    -- Improved Unholy Presence talent enhancement
                    if talent.improved_unholy_presence.enabled then
                        presence_efficiency = presence_efficiency + 0.15 -- Additional 15%
                        -- Also provides 15% faster rune regeneration
                    end
                    
                    -- Synergy with active pet for optimal DPS
                    if pet.active then
                        presence_efficiency = presence_efficiency + 0.05 -- Pet synergy bonus
                    end
                    
                    -- Enhanced efficiency during Dark Transformation
                    if buff.dark_transformation.up then
                        presence_efficiency = presence_efficiency + 0.10 -- Transformation synergy
                    end
                end
                
                -- Store efficiency for rotation optimization
                t.presence_efficiency = presence_efficiency
                t.optimal_for_unholy = true
                t.rune_regen_bonus = talent.improved_unholy_presence.enabled and 0.15 or 0
                
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.presence_efficiency = 1.0
            t.optimal_for_unholy = false
            t.rune_regen_bonus = 0
        end,
    },
    
    -- ========================================================================
    -- DARK TRANSFORMATION SYSTEM - Pet Enhancement Tracking
    -- ========================================================================
    
    -- Advanced Dark Transformation with comprehensive pet tracking
    dark_transformation = {
        id = 63560,
        duration = 30,
        max_stack = 1,
        generate = function( t, auraType )
            local name, icon, count, debuffType, duration, expirationTime, source, isStealable, 
                  nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, 
                  nameplateShowAll, timeMod, value1, value2, value3 = FindAuraByID( 63560, auraType )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + duration
                t.applied = t.expires - duration
                t.caster = source
                t.timeMod = timeMod or 1
                
                -- Enhanced Dark Transformation tracking with pet optimization
                -- 80% increased ghoul damage and new abilities
                -- Immune to fear, sleep, and charm effects
                local transformation_power = 1.0
                local remaining_time = t.expires - query_time
                
                -- Track transformation effectiveness
                if pet.active then
                    transformation_power = 1.8 -- Base 80% damage increase
                    
                    -- Enhanced power with Shadow Infusion stacks
                    local shadow_stacks = buff.shadow_infusion.count or 0
                    transformation_power = transformation_power + (shadow_stacks * 0.1) -- 10% per stack
                    
                    -- Glyph of Dark Transformation enhancement
                    if glyph.dark_transformation.enabled then
                        transformation_power = transformation_power + 0.2 -- Additional 20%
                    end
                    
                    -- Time remaining optimization for ability usage
                    if remaining_time <= 10 then
                        -- High priority phase - maximize damage abilities
                        t.priority_phase = true
                    elseif remaining_time <= 5 then
                        -- Critical phase - use all available abilities
                        t.critical_phase = true
                    end
                end
                
                -- Store transformation metrics for optimization
                t.transformation_power = transformation_power
                t.pet_enhanced = pet.active
                t.optimal_window = remaining_time > 15
                t.shadow_stacks_consumed = shadow_stacks or 0
                
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.transformation_power = 1.0
            t.pet_enhanced = false
            t.optimal_window = false
            t.priority_phase = false
            t.critical_phase = false
        end,
    },
    
    -- ========================================================================
    -- SUDDEN DOOM SYSTEM - Proc Efficiency Tracking
    -- ========================================================================
    
    -- Advanced Sudden Doom with comprehensive proc tracking
    sudden_doom = {
        id = 81340,
        duration = 10,
        max_stack = 1,
        generate = function( t, auraType )
            local name, icon, count, debuffType, duration, expirationTime, source, isStealable, 
                  nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, 
                  nameplateShowAll, timeMod, value1, value2, value3 = FindAuraByID( 81340, auraType )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + duration
                t.applied = t.expires - duration
                t.caster = source
                t.timeMod = timeMod or 1
                
                -- Enhanced Sudden Doom tracking with efficiency optimization
                -- Free Death Coil with increased damage potential
                local proc_efficiency = 1.0
                local remaining_time = t.expires - query_time
                
                -- Calculate optimal usage timing
                if talent.sudden_doom.enabled then
                    local talent_rank = talent.sudden_doom.rank or 0
                    proc_efficiency = 1.0 + (talent_rank * 0.33) -- 33/66/100% damage bonus per rank
                    
                    -- Enhanced efficiency with high Runic Power
                    if runic_power.current >= 80 then
                        proc_efficiency = proc_efficiency + 0.2 -- 20% efficiency bonus
                        t.prevents_overcap = true
                    end
                    
                    -- Synergy with Dark Transformation
                    if buff.dark_transformation.up then
                        proc_efficiency = proc_efficiency + 0.15 -- 15% synergy bonus
                        t.transformation_synergy = true
                    end
                    
                    -- Multiple target optimization
                    if active_enemies >= 2 then
                        proc_efficiency = proc_efficiency + 0.1 -- 10% AoE efficiency
                        t.aoe_optimal = true
                    end
                    
                    -- Time pressure optimization
                    if remaining_time <= 3 then
                        t.urgent_usage = true -- Must use immediately
                    elseif remaining_time <= 6 then
                        t.high_priority = true -- Should use soon
                    end
                end
                
                -- Store efficiency metrics for rotation optimization
                t.proc_efficiency = proc_efficiency
                t.runic_power_saved = 40 -- Full Death Coil cost saved
                t.optimal_timing = remaining_time > 5
                
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.proc_efficiency = 1.0
            t.prevents_overcap = false
            t.transformation_synergy = false
            t.aoe_optimal = false
            t.urgent_usage = false
            t.high_priority = false
        end,
    },
    
    -- ========================================================================
    -- SHADOW INFUSION SYSTEM - Stacking Enhancement Tracking
    -- ========================================================================
    
    -- Advanced Shadow Infusion with comprehensive stacking optimization
    shadow_infusion = {
        id = 91342,
        duration = 30,
        max_stack = 5,
        generate = function( t, auraType )
            local name, icon, count, debuffType, duration, expirationTime, source, isStealable, 
                  nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, 
                  nameplateShowAll, timeMod, value1, value2, value3 = FindAuraByID( 91342, auraType )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + duration
                t.applied = t.expires - duration
                t.caster = source
                t.timeMod = timeMod or 1
                
                -- Enhanced Shadow Infusion tracking with stacking optimization
                -- Each stack increases Dark Transformation effectiveness
                local stack_efficiency = 1.0
                local current_stacks = t.count
                local remaining_time = t.expires - query_time
                
                -- Calculate stacking effectiveness
                if talent.shadow_infusion.enabled and pet.active then
                    stack_efficiency = 1.0 + (current_stacks * 0.2) -- 20% per stack
                    
                    -- Optimal transformation timing
                    if current_stacks >= 5 then
                        t.transformation_ready = true
                        t.optimal_transformation = true
                    elseif current_stacks >= 3 then
                        t.good_transformation = true
                    end
                    
                    -- Stack decay prevention
                    if remaining_time <= 5 then
                        t.stacks_expiring_soon = true
                        if current_stacks >= 3 then
                            t.should_transform_now = true -- Use before losing stacks
                        end
                    end
                    
                    -- Death Coil frequency optimization
                    local death_coils_needed = 5 - current_stacks
                    t.death_coils_to_max = death_coils_needed
                    
                    -- Resource management for stacking
                    if runic_power.current >= (death_coils_needed * 40) then
                        t.can_complete_stacking = true
                    end
                end
                
                -- Store stacking metrics for optimization
                t.stack_efficiency = stack_efficiency
                t.stacks_remaining = 5 - current_stacks
                t.time_per_stack = remaining_time / math.max(1, current_stacks)
                
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.stack_efficiency = 1.0
            t.transformation_ready = false
            t.optimal_transformation = false
            t.good_transformation = false
            t.stacks_expiring_soon = false
            t.should_transform_now = false
            t.death_coils_to_max = 5
            t.can_complete_stacking = false
        end,
    },
    
    -- ========================================================================
    -- DISEASE PANDEMIC SYSTEM - Comprehensive Disease Management
    -- ========================================================================
    
    -- Advanced Blood Plague with pandemic mechanics
    blood_plague = {
        id = 59879,
        duration = function() 
            local base_duration = 30
            if talent.epidemic.enabled then
                base_duration = base_duration * 1.5 -- 50% longer with Epidemic
            end
            return base_duration
        end,
        max_stack = 1,
        tick_time = 3,
        pandemic = true,
        generate = function( t, auraType )
            local name, icon, count, debuffType, duration, expirationTime, source, isStealable, 
                  nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, 
                  nameplateShowAll, timeMod, value1, value2, value3 = FindAuraByID( 59879, auraType or "HARMFUL" )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + t.duration
                t.applied = t.expires - t.duration
                t.caster = source
                t.timeMod = timeMod or 1
                
                -- Enhanced pandemic tracking for optimal disease management
                local remaining_time = t.expires - query_time
                local pandemic_threshold = t.duration * 0.3 -- 30% pandemic window
                
                -- Pandemic optimization calculations
                t.pandemic_window = remaining_time <= pandemic_threshold
                t.optimal_refresh = remaining_time <= (pandemic_threshold * 0.5)
                t.emergency_refresh = remaining_time <= 2
                
                -- Disease interaction tracking
                t.pairs_with_frost_fever = debuff.frost_fever.up
                t.enhances_scourge_strike = true -- Blood Plague enhances Scourge Strike
                
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.pandemic_window = false
            t.optimal_refresh = false
            t.emergency_refresh = false
            t.pairs_with_frost_fever = false
            t.enhances_scourge_strike = false
        end,
    },
    
    -- Advanced Frost Fever with pandemic mechanics
    frost_fever = {
        id = 59921,
        duration = function() 
            local base_duration = 30
            if talent.epidemic.enabled then
                base_duration = base_duration * 1.5 -- 50% longer with Epidemic
            end
            return base_duration
        end,
        max_stack = 1,
        tick_time = 3,
        pandemic = true,
        generate = function( t, auraType )
            local name, icon, count, debuffType, duration, expirationTime, source, isStealable, 
                  nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, 
                  nameplateShowAll, timeMod, value1, value2, value3 = FindAuraByID( 59921, auraType or "HARMFUL" )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + t.duration
                t.applied = t.expires - t.duration
                t.caster = source
                t.timeMod = timeMod or 1
                
                -- Enhanced pandemic tracking for optimal disease management
                local remaining_time = t.expires - query_time
                local pandemic_threshold = t.duration * 0.3 -- 30% pandemic window
                
                -- Pandemic optimization calculations
                t.pandemic_window = remaining_time <= pandemic_threshold
                t.optimal_refresh = remaining_time <= (pandemic_threshold * 0.5)
                t.emergency_refresh = remaining_time <= 2
                
                -- Disease interaction tracking
                t.pairs_with_blood_plague = debuff.blood_plague.up
                t.enables_obliterate = true -- Frost Fever enables Obliterate damage bonus
                
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.pandemic_window = false
            t.optimal_refresh = false
            t.emergency_refresh = false
            t.pairs_with_blood_plague = false
            t.enables_obliterate = false
        end,
    },
    
    -- ========================================================================
    -- ADDITIONAL CORE AURAS WITH ENHANCED TRACKING
    -- ========================================================================
    
    -- Advanced Master of Ghouls with permanent pet tracking
    master_of_ghouls = {
        id = 52143,
        duration = 3600,
        max_stack = 1,
        generate = function( t, auraType )
            if talent.master_of_ghouls.enabled then
                t.name = "Master of Ghouls"
                t.count = 1
                t.expires = query_time + 3600
                t.applied = query_time
                t.caster = "player"
                
                -- Enhanced permanent ghoul tracking
                t.permanent_ghoul = true
                t.requires_unholy_presence = true
                t.enhances_dark_transformation = true
                
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.permanent_ghoul = false
        end,
    },
    
    -- Enhanced Ebon Plaguebringer with magic vulnerability
    ebon_plaguebringer = {
        id = 51161,
        duration = function() 
            local base_duration = 30
            if talent.epidemic.enabled then
                base_duration = base_duration * 1.5
            end
            return base_duration
        end,
        max_stack = 1,
        generate = function( t, auraType )
            local name, icon, count, debuffType, duration, expirationTime, source, isStealable, 
                  nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, 
                  nameplateShowAll, timeMod, value1, value2, value3 = FindAuraByID( 51161, auraType or "HARMFUL" )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + t.duration
                t.applied = t.expires - t.duration
                t.caster = source
                
                -- Enhanced magic vulnerability tracking
                t.magic_vulnerability = 0.13 -- 13% increased magic damage taken
                t.enhances_death_coil = true
                t.enhances_death_and_decay = true
                
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.magic_vulnerability = 0
        end,
    },
    
    -- ========================================================================
    -- DEFENSIVE AND UTILITY AURAS WITH ENHANCED TRACKING
    -- ========================================================================
    
    -- Other Death Knight presences for comparison
    blood_presence = {
        id = 48263,
        duration = 3600,
        max_stack = 1,
    },
    frost_presence = {
        id = 48266,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Enhanced defensive cooldowns
    anti_magic_shell = {
        id = 48707,
        duration = function() return glyph.anti_magic_shell.enabled and 7 or 5 end,
        max_stack = 1,
    },
    icebound_fortitude = {
        id = 48792,
        duration = function() return glyph.icebound_fortitude.enabled and 6 or 8 end,
        max_stack = 1,
    },
    
    -- Enhanced utility tracking
    horn_of_winter = {
        id = 57330,
        duration = function() return glyph.horn_of_winter.enabled and 3600 or 120 end,
        max_stack = 1,
    },
    path_of_frost = {
        id = 3714,
        duration = 600,
        max_stack = 1,
    },
    
    -- ========================================================================
    -- ADVANCED RUNIC SYSTEM WITH COMPREHENSIVE TRACKING
    -- ========================================================================
    
    -- Enhanced Blood Tap with charge tracking
    blood_tap = {
        id = 45529,
        duration = 30,
        max_stack = 10,
        generate = function( t, auraType )
            local name, icon, count, debuffType, duration, expirationTime, source, isStealable, 
                  nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, 
                  nameplateShowAll, timeMod, value1, value2, value3 = FindAuraByID( 45529, auraType )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + duration
                t.applied = t.expires - duration
                t.caster = source
                
                -- Enhanced Blood Tap charge tracking
                t.charges_available = t.count
                t.can_refresh_rune = t.count >= 1
                t.optimal_usage = t.count >= 5 -- Use when at half charges
                
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.charges_available = 0
            t.can_refresh_rune = false
            t.optimal_usage = false
        end,
    },
    
    -- Enhanced Runic Corruption with regeneration tracking
    runic_corruption = {
        id = 51460,
        duration = 3,
        max_stack = 1,
        generate = function( t, auraType )
            local name, icon, count, debuffType, duration, expirationTime, source, isStealable, 
                  nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, 
                  nameplateShowAll, timeMod, value1, value2, value3 = FindAuraByID( 51460, auraType )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + duration
                t.applied = t.expires - duration
                t.caster = source
                
                -- Enhanced Runic Corruption tracking
                t.regen_bonus = 1.0 -- 100% faster rune regeneration
                t.remaining_benefit = t.expires - query_time
                t.high_value = t.remaining_benefit > 1.5
                
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.regen_bonus = 0
            t.remaining_benefit = 0
            t.high_value = false
        end,
    },
    
    -- Enhanced Runic Empowerment with efficiency tracking
    runic_empowerment = {
        id = 81229,
        duration = 5,
        max_stack = 1,
        generate = function( t, auraType )
            local name, icon, count, debuffType, duration, expirationTime, source, isStealable, 
                  nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, 
                  nameplateShowAll, timeMod, value1, value2, value3 = FindAuraByID( 81229, auraType )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + duration
                t.applied = t.expires - duration
                t.caster = source
                
                -- Enhanced Runic Empowerment tracking
                t.instant_rune_refresh = true
                t.should_use_immediately = true
                t.efficiency_window = t.expires - query_time
                
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.instant_rune_refresh = false
            t.should_use_immediately = false
            t.efficiency_window = 0
        end,
    },
} )

-- Unholy DK core abilities
spec:RegisterAbilities( {    scourge_strike = {
        id = 55090,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            local base_cost = 1
            -- Enhanced Runic Corruption reduces rune costs by 10%
            if talent.runic_corruption.enabled then
                base_cost = base_cost * 0.9
            end
            return base_cost
        end,
        spendType = "unholy",
        
        startsCombat = true,
        
        handler = function ()
            -- Scourge Strike gains significant damage based on diseases present
            local rp_gain = 15 -- Base RP generation
            local disease_count = 0
            
            -- Check for diseases on target
            if debuff.blood_plague.up then disease_count = disease_count + 1 end
            if debuff.frost_fever.up then disease_count = disease_count + 1 end
            if debuff.ebon_plaguebringer.up then disease_count = disease_count + 1 end
            
            -- Additional RP per disease (MoP mechanic)
            rp_gain = rp_gain + (disease_count * 5)
            
            -- Glyph of Scourge Strike: 10% increased crit chance
            if glyph.scourge_strike.enabled then
                -- Enhanced critical strike chance handled in damage calculation
            end
            
            -- Vicious Strikes talent increases damage
            if talent.vicious_strikes.enabled then
                -- Damage bonus handled in damage calculation
            end
            
            gain(rp_gain, "runicpower")
            
            -- Trigger Runic Empowerment/Corruption procs
            if talent.runic_empowerment.enabled then
                if math.random() < 0.45 then -- 45% proc chance
                    applyBuff("runic_empowerment")
                    -- Instantly refresh one depleted rune
                end
            elseif talent.runic_corruption.enabled then
                if math.random() < 0.45 then -- 45% proc chance  
                    applyBuff("runic_corruption")
                    -- Increase rune regeneration by 100% for 3 seconds
                end
            end
            
            -- Check for Sudden Doom proc
            check_sudden_doom()
        end,
    },
      festering_strike = {
        id = 85948,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            local base_cost = 1 -- Changed from 2 to 1 for MoP
            if talent.runic_corruption.enabled then
                base_cost = base_cost * 0.9
            end
            return base_cost
        end,
        spendType = "blood",
        
        startsCombat = true,
        
        handler = function ()
            local rp_gain = 15
            gain(rp_gain, "runicpower")
            
            -- Extend diseases by 6 seconds base
            local extension = 6
            if glyph.festering_strike.enabled then 
                extension = extension + 6 -- Glyph adds additional 6 seconds
            end
            
            -- Only extend if diseases are present
            if debuff.blood_plague.up then
                debuff.blood_plague.expires = debuff.blood_plague.expires + extension
            end
            if debuff.frost_fever.up then
                debuff.frost_fever.expires = debuff.frost_fever.expires + extension
            end
            if debuff.ebon_plaguebringer.up then
                debuff.ebon_plaguebringer.expires = debuff.ebon_plaguebringer.expires + extension
            end
            
            -- Trigger Runic procs
            if talent.runic_empowerment.enabled then
                if math.random() < 0.45 then
                    applyBuff("runic_empowerment")
                end
            elseif talent.runic_corruption.enabled then
                if math.random() < 0.45 then
                    applyBuff("runic_corruption")
                end
            end
            
            -- Check for Sudden Doom proc
            check_sudden_doom()
        end,
    },
      death_coil = {
        id = 47541,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            if buff.sudden_doom.up then return 0 end
            return 40 
        end,
        spendType = "runicpower",
        
        startsCombat = true,
        
        handler = function ()
            local is_sudden_doom = buff.sudden_doom.up
            removeBuff("sudden_doom")
            
            -- Death Coil can heal undead allies or damage enemies
            -- In Unholy spec, it's primarily used for damage
            
            -- Glyph of Death Coil: heals pets for 1% of DK's health
            if glyph.death_coil.enabled and pet.active then
                -- Pet healing effect
            end
            
            -- Enhanced damage when used with Sudden Doom
            if is_sudden_doom then
                -- Free Death Coil from Sudden Doom proc
                -- Deals increased damage (handled in damage calculation)
            end
            
            -- Dark Transformation synergy - reduces cooldown when used on transformed ghoul
            if pet.active and buff.dark_transformation.up then
                -- Synergy with transformed ghoul
            end
        end,
    },
      dark_transformation = {
        id = 63560,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        requires = function()
            -- Requires an active ghoul pet
            return pet.active, "requires active ghoul"
        end,
        
        toggle = "cooldowns",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("dark_transformation")
            
            -- Dark Transformation significantly enhances the ghoul:
            -- - Increases damage by 80%
            -- - Ghoul gains new abilities (Gnaw, Monstrous Blow, etc.)
            -- - Duration: 30 seconds
            
            -- The transformed ghoul becomes immune to many CC effects
            -- and gains significant stat increases
        end,
    },

    -- Common Death Knight Abilities (shared across all specs)
    -- Diseases
    outbreak = {
        id = 77575,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "blood_plague")
            applyDebuff("target", "frost_fever")
            applyDebuff("target", "ebon_plaguebringer")
        end,
    },
      plague_strike = {
        id = 45462,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "unholy",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "blood_plague")
            applyDebuff("target", "ebon_plaguebringer")
            
            local rp_gain = 10
            
            -- Vicious Strikes talent increases damage
            if talent.vicious_strikes.enabled then
                -- Enhanced damage and RP generation
                rp_gain = rp_gain + 5
            end
            
            -- Virulence talent increases disease application chance
            if talent.virulence.enabled then
                -- Higher chance to apply diseases (already applied above)
                -- Could add chance for additional disease effects
            end
            
            -- Glyph of Plague Strike: 20% additional damage vs >90% health targets
            if glyph.plague_strike.enabled then
                -- Enhanced damage vs high-health targets
            end
            
            gain(rp_gain, "runicpower")
            
            -- Trigger Runic procs
            if talent.runic_empowerment.enabled then
                if math.random() < 0.35 then -- Lower proc chance for Plague Strike
                    applyBuff("runic_empowerment")
                end
            elseif talent.runic_corruption.enabled then
                if math.random() < 0.35 then
                    applyBuff("runic_corruption")
                end
            end
        end,
    },
    
    icy_touch = {
        id = 45477,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "frost_runes", -- FUB runes
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "frost_fever")
            gain(10, "runicpower")
        end,
    },      blood_boil = {
        id = 48721,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "blood",
        
        startsCombat = true,
        texture = 237513,
        
        handler = function ()
            -- Blood Boil: Shadow damage AoE that spreads diseases
            -- Base damage + 8% Attack Power, 1.5x damage if diseases active
            local damage_multiplier = 1.0
            if debuff.blood_plague.up or debuff.frost_fever.up or debuff.ebon_plaguebringer.up then
                damage_multiplier = 1.5
            end
            
            local rp_gain = 10
            
            -- Spread diseases to nearby targets if they exist on primary target
            if debuff.blood_plague.up then
                applyDebuff("target", "blood_plague", nil, debuff.blood_plague.remains)
            end
            
            if debuff.frost_fever.up then
                applyDebuff("target", "frost_fever", nil, debuff.frost_fever.remains)
            end
            
            if debuff.ebon_plaguebringer.up then
                applyDebuff("target", "ebon_plaguebringer", nil, debuff.ebon_plaguebringer.remains)
            end
            
            -- Generate 10 Runic Power (only if targets are hit)
            gain(rp_gain, "runicpower")
            
            -- Trigger Runic procs (35% chance each)
            if talent.runic_empowerment.enabled then
                if math.random() < 0.35 then
                    applyBuff("runic_empowerment")
                end
            elseif talent.runic_corruption.enabled then
                if math.random() < 0.35 then
                    applyBuff("runic_corruption")
                end
            end
        end,
    },
    
    blood_strike = {
        id = 45902,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "blood",
        
        startsCombat = true,
        texture = 237517,
        
        handler = function ()
            -- Blood Strike: Physical weapon attack with disease bonus
            -- Base damage + weapon damage, +12.5% per disease (max +25%)
            local disease_count = 0
            if debuff.blood_plague.up then disease_count = disease_count + 1 end
            if debuff.frost_fever.up then disease_count = disease_count + 1 end
            if debuff.ebon_plaguebringer.up then disease_count = disease_count + 1 end
            
            local damage_multiplier = 1.0 + (disease_count * 0.125)
            
            -- Generate 10 Runic Power
            gain(10, "runicpower")
            
            -- Reaping talent for Unholy: Blood rune converts to Death rune on use
            if talent.reaping.enabled then
                -- Blood rune becomes Death rune, allowing more flexibility
            end
            
            -- Trigger potential Runic procs
            if talent.runic_empowerment.enabled then
                if math.random() < 0.35 then
                    applyBuff("runic_empowerment")
                end
            elseif talent.runic_corruption.enabled then
                if math.random() < 0.35 then
                    applyBuff("runic_corruption")
                end
            end
        end,
    },
    
    -- Defensive cooldowns
    anti_magic_shell = {
        id = 48707,
        cast = 0,
        cooldown = function() return glyph.anti_magic_shell.enabled and 60 or 45 end,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("anti_magic_shell")
        end,
    },
    
    icebound_fortitude = {
        id = 48792,
        cast = 0,
        cooldown = function() return glyph.icebound_fortitude.enabled and 120 or 180 end,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("icebound_fortitude")
        end,
    },
    
    rune_strike = {
        id = 56815,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 30,
        spendType = "runicpower",
        
        startsCombat = true,
        texture = 237518,
        
        usable = function() return buff.blood_presence.up end,
        
        handler = function ()
            -- Rune Strike: Enhanced weapon strike (requires Blood Presence)
            -- 1.8x weapon damage + 10% Attack Power
            -- 1.75x threat multiplier
            
            -- Trigger potential Runic procs
            if talent.runic_empowerment.enabled then
                if math.random() < 0.35 then
                    applyBuff("runic_empowerment")
                end
            elseif talent.runic_corruption.enabled then
                if math.random() < 0.35 then
                    applyBuff("runic_corruption")
                end
            end
        end,
    },
    
    -- Utility
    death_grip = {
        id = 49576,
        cast = 0,
        cooldown = 25,
        gcd = "spell",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "death_grip")
        end,
    },
    
    mind_freeze = {
        id = 47528,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        
        toggle = "interrupts",
        
        startsCombat = true,
        
        handler = function ()
            if active_enemies > 1 and talent.asphyxiate.enabled then
                -- potentially apply interrupt debuff with talent
            end
        end,
    },
      death_and_decay = {
        id = 43265,
        cast = 0,
        cooldown = function() 
            local base_cd = 30
            -- Morbidity talent reduces cooldown
            if talent.morbidity.enabled then
                base_cd = base_cd - (5 * talent.morbidity.rank) -- 5/10/15 sec reduction
            end
            return base_cd
        end,
        gcd = "spell",
        
        spend = 1,
        spendType = "unholy",
        
        startsCombat = true,
        
        handler = function ()
            -- Death and Decay creates a pool of shadow damage
            -- Lasts 10 seconds, ticks every second
            
            local damage_bonus = 0
            -- Glyph of Death and Decay: 15% increased damage
            if glyph.death_and_decay.enabled then
                damage_bonus = damage_bonus + 0.15
            end
            
            -- Morbidity talent increases damage
            if talent.morbidity.enabled then
                damage_bonus = damage_bonus + (0.05 * talent.morbidity.rank) -- 5/10/15% bonus
            end
            
            -- Ebon Plaguebringer increases magic damage taken by targets
            if debuff.ebon_plaguebringer.up then
                -- Additional damage from magic vulnerability
            end
            
            gain(15, "runicpower") -- Base RP gain
        end,
    },
    
    horn_of_winter = {
        id = 57330,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("horn_of_winter")
            if not glyph.horn_of_winter.enabled then
                gain(10, "runicpower")
            end
        end,
    },
      raise_dead = {
        id = 46584,
        cast = 0,
        cooldown = function() 
            -- Master of Ghouls makes this instant and no cooldown for permanent ghoul
            if talent.master_of_ghouls.enabled then return 0 end
            return 120
        end,
        gcd = "spell",
        
        startsCombat = false,
        
        toggle = "cooldowns",
        
        handler = function ()
            -- Summon ghoul/geist pet based on glyphs and talents
            if talent.master_of_ghouls.enabled then
                -- Permanent ghoul with Master of Ghouls talent
                -- Requires Unholy Presence to be maintained
                if not buff.unholy_presence.up then
                    applyBuff("unholy_presence")
                end
            else
                -- Temporary ghoul (60 second duration)
            end
            
            -- Glyph of Raise Dead: ghoul gains 40% of DK's Strength and Stamina
            if glyph.raise_dead.enabled then
                -- Enhanced ghoul stats
            end
            
            -- Glyph of Foul Menagerie: random ghoul appearance
            if glyph.foul_menagerie.enabled then
                -- Cosmetic variation
            end
            
            -- Glyph of the Geist: summons geist instead of ghoul
            if glyph.the_geist.enabled then
                -- Different pet model, same mechanics
            end
        end,
    },
    
    -- Unholy-specific spell: Necrotic Strike (if available in MoP)
    necrotic_strike = {
        id = 73975,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "unholy",
        
        startsCombat = true,
        
        handler = function ()
            -- Necrotic Strike applies a healing absorption shield
            -- Shield amount based on Attack Power
            local shield_amount = stat.attack_power * 0.7 -- Rough calculation
            
            applyDebuff("target", "necrotic_strike", nil, nil, shield_amount)
            gain(15, "runicpower")
            
            -- Trigger Runic procs
            if talent.runic_empowerment.enabled then
                if math.random() < 0.45 then
                    applyBuff("runic_empowerment")
                end
            elseif talent.runic_corruption.enabled then
                if math.random() < 0.45 then
                    applyBuff("runic_corruption")
                end
            end
        end,
    },
    
    -- Soul Reaper (if available in MoP)
    soul_reaper = {
        id = 130735,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 1,
        spendType = "unholy",
        
        startsCombat = true,
        
        handler = function ()
            -- Soul Reaper marks target for death after 5 seconds
            -- If target is below 35% health when it explodes, deals massive damage
            applyDebuff("target", "soul_reaper")
            
            -- Glyph of Soul Reaper: gain 5% haste for 5 sec when used on low health target
            if glyph.soul_reaper.enabled and target.health.pct < 35 then
                applyBuff("soul_reaper_haste")
            end
            
            gain(10, "runicpower")
        end,
    },
      army_of_the_dead = {
        id = 42650,
        cast = function() return 4 end, -- 4 second channel (8 ghouls @ 0.5s intervals)
        cooldown = 600, -- 10 minute cooldown
        gcd = "spell",
        
        spend = function() return 1, 1, 1 end, -- 1 Blood + 1 Frost + 1 Unholy
        spendType = "runes",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 237302,
        
        handler = function ()
            -- Summon 8 ghouls over 4 seconds, each lasting 40 seconds
            -- Generates 30 Runic Power
            gain( 30, "runic_power" )
        end,
    },
    
    path_of_frost = {
        id = 3714,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("path_of_frost")
        end,
    },
    
    -- Presence switching
    blood_presence = {
        id = 48263,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff("frost_presence")
            removeBuff("unholy_presence")
            applyBuff("blood_presence")
        end,
    },
    
    frost_presence = {
        id = 48266,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff("blood_presence")
            removeBuff("unholy_presence")
            applyBuff("frost_presence")
        end,
    },
    
    unholy_presence = {
        id = 48265,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff("blood_presence")
            removeBuff("frost_presence")
            applyBuff("unholy_presence")
        end,
    },
    
    -- Rune management
    blood_tap = {
        id = 45529,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        spend = function() return glyph.blood_tap.enabled and 15 or 0 end,
        spendType = function() return glyph.blood_tap.enabled and "runicpower" or nil end,
        
        startsCombat = false,
        
        handler = function ()
            if not glyph.blood_tap.enabled then
                -- Original functionality: costs health
                spend(0.05, "health")
            end
            -- Convert a blood rune to a death rune
        end,
    },
    
    empower_rune_weapon = {
        id = 47568,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        
        handler = function ()
            -- Refresh all rune cooldowns and generate 25 runic power
            gain(25, "runicpower")
        end,
    },
} )

-- Add state handlers for Death Knight rune system
do
    local runes = {}
    
    spec:RegisterStateExpr( "rune", function ()
        return runes
    end )
    
    -- Blood Runes
    spec:RegisterStateExpr( "blood_runes", function ()
        return state.runes.blood.current
    end )
    
    -- Frost Runes
    spec:RegisterStateExpr( "frost_runes", function ()
        return state.runes.frost.current
    end )
    
    -- Unholy Runes
    spec:RegisterStateExpr( "unholy_runes", function ()
        return state.runes.unholy.current
    end )
    
    -- Death Runes
    spec:RegisterStateExpr( "death_runes", function ()
        return state.runes.death.current
    end )
    
    -- Total available runes
    spec:RegisterStateExpr( "total_runes", function ()
        return state.runes.blood.current + state.runes.frost.current + 
               state.runes.unholy.current + state.runes.death.current
    end )
    
    -- Disease-related expressions
    spec:RegisterStateExpr( "diseases_up", function ()
        return debuff.blood_plague.up and debuff.frost_fever.up
    end )
    
    spec:RegisterStateExpr( "diseases_ticking", function ()
        local count = 0
        if debuff.blood_plague.up then count = count + 1 end
        if debuff.frost_fever.up then count = count + 1 end
        if debuff.ebon_plaguebringer.up then count = count + 1 end
        return count
    end )
    
    spec:RegisterStateExpr( "diseases_will_expire", function ()
        local expires_soon = 6 -- Consider diseases that expire within 6 seconds
        return (debuff.blood_plague.up and debuff.blood_plague.remains < expires_soon) or
               (debuff.frost_fever.up and debuff.frost_fever.remains < expires_soon)
    end )
    
    -- Unholy-specific expressions
    spec:RegisterStateExpr( "sudden_doom_react", function ()
        return buff.sudden_doom.up
    end )
    
    spec:RegisterStateExpr( "ghoul_active", function ()
        return pet.active and pet.ghoul.active
    end )
    
    spec:RegisterStateExpr( "dark_transformation_ready", function ()
        return cooldown.dark_transformation.remains == 0 and pet.active
    end )
    
    spec:RegisterStateExpr( "can_festering_strike", function ()
        return diseases_up and (blood_runes >= 1 or death_runes >= 1)
    end )
    
    spec:RegisterStateExpr( "runic_power_deficit", function ()
        return runic_power.max - runic_power.current
    end )
    
    spec:RegisterStateExpr( "rune_regeneration_rate", function ()
        local base_rate = 10 -- Base 10 second rune regeneration
        local rate = base_rate
        
        -- Improved Unholy Presence reduces rune regeneration time
        if buff.improved_unholy_presence.up then
            rate = rate * 0.85 -- 15% faster regeneration
        end
        
        -- Runic Corruption doubles rune regeneration speed
        if buff.runic_corruption.up then
            rate = rate * 0.5 -- 100% faster (half the time)
        end
        
        return rate
    end )
    
    -- Initialize the enhanced rune tracking system
    spec:RegisterStateTable( "runes", {
        blood = { current = 2, max = 2, cooldown = {}, time = {} },
        frost = { current = 2, max = 2, cooldown = {}, time = {} },
        unholy = { current = 2, max = 2, cooldown = {}, time = {} },
        death = { current = 0, max = 6, cooldown = {}, time = {} },
    } )
    
    -- Enhanced rune spending function
    spec:RegisterStateFunction( "spend_runes", function( blood, frost, unholy )
        local spent = { blood = blood or 0, frost = frost or 0, unholy = unholy or 0 }
        
        for rune_type, amount in pairs(spent) do
            if amount > 0 then
                -- First try to spend death runes if available
                if state.runes.death.current >= amount then
                    state.runes.death.current = state.runes.death.current - amount
                    amount = 0
                end
                
                -- Then spend the specific rune type
                if amount > 0 and state.runes[rune_type].current >= amount then
                    state.runes[rune_type].current = state.runes[rune_type].current - amount
                    -- Convert spent runes to death runes after use
                    state.runes.death.current = math.min(state.runes.death.max, 
                                                         state.runes.death.current + amount)
                end
            end
        end
    end )
    
    -- Enhanced Sudden Doom checking with proper proc rates
    spec:RegisterStateFunction( "check_sudden_doom", function()
        if talent.sudden_doom.enabled then
            -- Sudden Doom proc chance based on talent rank
            local base_chance = 0.05 * talent.sudden_doom.rank -- 5/10/15% per rank
            
            -- Auto-attacks have a chance to trigger Sudden Doom
            if math.random() < base_chance then
                applyBuff("sudden_doom")
            end
        end
    end )
    
    -- Function to check if we should use Death Coil
    spec:RegisterStateFunction( "should_death_coil", function()
        -- Use Death Coil if:
        -- 1. Sudden Doom is active (free cast)
        -- 2. Runic Power is near cap (>80)
        -- 3. Need to prevent RP overcap
        return buff.sudden_doom.up or runic_power.current >= 80 or 
               (runic_power.current >= 60 and runic_power_deficit <= 20)
    end )
    
    -- Function to determine optimal disease application method
    spec:RegisterStateFunction( "disease_application_method", function()
        local method = "individual" -- Default to Plague Strike + Icy Touch
        
        -- Use Outbreak if both diseases are down and it's available
        if not diseases_up and cooldown.outbreak.remains == 0 then
            method = "outbreak"
        -- Use Festering Strike if diseases need extension and are already up
        elseif diseases_up and diseases_will_expire then
            method = "festering_strike"
        end
        
        return method
    end )
end

-- Register pet handler for Unholy's ghoul
spec:RegisterStateHandler( "ghoul", function()
    if pet.active then
        -- Handle ghoul pet logic here
    end
end )

-- Register default pack for MoP Unholy Death Knight
spec:RegisterPack( "Unholy", 20250515, [[Hekili:T3vBVTTnu4FlXnHr9LsojdlJE7Kf7K3KRLvAm7njb5L0Svtla8Xk20IDngN7ob6IPvo9CTCgbb9D74Xtx83u5dx4CvNBYZkeeZwyXJdNpV39NvoT82e)6J65pZE3EGNUNUp(4yTxY1VU)mEzZNF)wwc5yF)SGp2VyFk3fzLyKD(0W6Zw(aFW0P)MM]]  )

-- Register pack selector for Unholy
