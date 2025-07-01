-- RogueSubtlety.lua
-- Updated May 30, 2025 - Advanced Structure Implementation
-- Mists of Pandaria module for Rogue: Subtlety spec

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'ROGUE' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state

local function getReferences()
    if not class then
        class, state = Hekili.Class, Hekili.State
    end
    return class, state
end

local spec = Hekili:NewSpecialization( 261 ) -- Subtlety spec ID for MoP

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

local subtletyCombatLogFrame = CreateFrame("Frame")
local subtletyCombatLogEvents = {}

local function RegisterSubtletyCombatLogEvent(event, handler)
    if not subtletyCombatLogEvents[event] then
        subtletyCombatLogEvents[event] = {}
        subtletyCombatLogFrame:RegisterEvent(event)
    end
    
    tinsert(subtletyCombatLogEvents[event], handler)
end

subtletyCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    local handlers = subtletyCombatLogEvents[event]
    if handlers then
        for _, handler in ipairs(handlers) do
            handler(event, ...)
        end
    end
end)

-- Shadow Dance charge tracking
local shadow_dance_charges = 0
local shadow_dance_last_check = 0

RegisterSubtletyCombatLogEvent("COMBAT_LOG_EVENT_UNFILTERED", function(event, ...)
    local _, subEvent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
    
    if sourceGUID ~= UnitGUID("player") then return end
    
    local spellID, spellName, spellSchool
    if subEvent == "SPELL_CAST_SUCCESS" then
        spellID, spellName, spellSchool = select(12, CombatLogGetCurrentEventInfo())
        
        -- Shadow Dance usage tracking
        if spellID == 51713 then -- Shadow Dance
            shadow_dance_charges = max(0, shadow_dance_charges - 1)
        end
        
        -- Hemorrhage application tracking
        if spellID == 16511 then -- Hemorrhage
            local now = GetTime()
            state.hemorrhage_last_applied = now
        end
        
        -- Stealth ability tracking for Find Weakness
        if spellID == 8676 or spellID == 703 or spellID == 1833 then -- Ambush, Garrote, Cheap Shot
            state.find_weakness_trigger = GetTime()
        end
        
    elseif subEvent == "SPELL_AURA_APPLIED" then
        spellID, spellName, spellSchool = select(12, CombatLogGetCurrentEventInfo())
        
        -- Master of Subtlety proc tracking
        if spellID == 31665 then -- Master of Subtlety
            state.master_of_subtlety_applied = GetTime()
        end
        
        -- Honor Among Thieves proc tracking
        if spellID == 51699 then -- Honor Among Thieves stack
            state.honor_among_thieves_procs = (state.honor_among_thieves_procs or 0) + 1
        end
        
    elseif subEvent == "SPELL_ENERGIZE" then
        spellID, spellName, spellSchool = select(12, CombatLogGetCurrentEventInfo())
        local amount, powerType = select(16, CombatLogGetCurrentEventInfo())
        
        -- Honor Among Thieves combo point generation
        if spellID == 51699 and powerType == 4 then -- Combo Points
            state.hat_combo_points_gained = (state.hat_combo_points_gained or 0) + amount
        end
        
        -- Relentless Strikes energy generation
        if spellID == 58423 and powerType == 3 then -- Energy
            state.relentless_strikes_energy = (state.relentless_strikes_energy or 0) + amount
        end
    end
end)

-- Shadow Dance charge regeneration tracking
RegisterSubtletyCombatLogEvent("PLAYER_ENTERING_WORLD", function()
    shadow_dance_charges = 2 -- MoP Shadow Dance has 2 charges
    shadow_dance_last_check = GetTime()
end)

-- MoP compatibility: use fallback for C_Timer
local tickerFunc = function()
    local now = GetTime()
    local time_since_last = now - shadow_dance_last_check    
    if shadow_dance_charges < 2 and time_since_last >= 60 then -- 60 second recharge
        shadow_dance_charges = min(2, shadow_dance_charges + 1)
        shadow_dance_last_check = now
    end
end

-- Setup timer with MoP compatibility
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(1, tickerFunc)
elseif ns.ScheduleRepeatingTimer then
    ns.ScheduleRepeatingTimer(tickerFunc, 1)
end

-- ===================
-- ENHANCED RESOURCE SYSTEMS
-- ===================

-- Advanced Energy system with multiple generation sources
spec:RegisterResource( 3, { -- Energy = 3 in MoP
    -- Relentless Strikes: Finishers have chance to restore energy
    relentless_strikes = {
        aura = "relentless_strikes",
        last = function() return state.relentless_strikes_energy or 0 end,
        interval = function() return state.gcd.execute * 2 end,
        value = function() 
            if not state.talent.relentless_strikes.enabled then return 0 end
            return state.combo_points.current * 5 -- 5 energy per combo point spent on finishers
        end,
    },
    
    -- Adrenaline Rush: 100% energy regeneration
    adrenaline_rush = {
        aura = "adrenaline_rush",
        last = function() return state.adrenaline_rush_energy or 0 end,
        interval = 1,
        value = function() 
            if not state.buff.adrenaline_rush.up then return 0 end
            return 10 -- Double energy regeneration
        end,
    },
    
    -- Shadow Focus: 75% reduced energy costs while stealthed
    shadow_focus = {
        aura = "shadow_focus",
        last = function() return state.shadow_focus_energy or 0 end,
        interval = function() return state.gcd.execute end,
        value = function() 
            if not state.talent.shadow_focus.enabled then return 0 end
            if not state.stealthed.all then return 0 end
            return 5 -- Effective energy gain from reduced costs
        end,
    },
    
    -- Preparation: Instantly restores energy
    preparation = {
        aura = "preparation",
        last = function() return state.preparation_energy or 0 end,
        interval = 180, -- Cooldown based
        value = function() 
            if not state.talent.preparation.enabled then return 0 end
            return 100 -- Full energy restoration
        end,
    },
    
    -- Energetic Recovery: Energy over time after finishers
    energetic_recovery = {
        aura = "energetic_recovery",
        last = function() return state.energetic_recovery_energy or 0 end,
        interval = 1,
        value = function() 
            if not state.talent.energetic_recovery.enabled then return 0 end
            if not state.buff.energetic_recovery.up then return 0 end
            return 8 -- Energy per second during recovery
        end,
    },
}, {
    -- Base energy regeneration with bonuses
    base_regen = function() 
        local base = 10
        
        -- Vitality bonus
        if state.buff.vitality.up then
            base = base * 1.25
        end
        
        -- Shadow Focus reduces effective costs (simulated as increased regen)
        if state.talent.shadow_focus.enabled and state.stealthed.all then
            base = base * 1.75 -- 75% cost reduction = 175% effective regen
        end
        
        return base
    end,
} )

-- Advanced Combo Points system
spec:RegisterResource( 4, { -- ComboPoints = 4 in MoP
    -- Honor Among Thieves: Combo points from party/raid crits
    honor_among_thieves = {
        aura = "honor_among_thieves",
        last = function() return state.hat_combo_points_gained or 0 end,
        interval = 2, -- Roughly every 2 seconds in raid
        value = function() 
            if not state.talent.honor_among_thieves.enabled then return 0 end
            return 1 -- One combo point per proc
        end,
    },
    
    -- Anticipation: Store up to 10 combo points
    anticipation = {
        aura = "anticipation",
        last = function() return state.anticipation_combo_points or 0 end,
        interval = function() return state.gcd.execute end,
        value = function() 
            if not state.talent.anticipation.enabled then return 0 end
            if state.combo_points.current >= 5 then
                return min(5, state.buff.anticipation.stack or 0) -- Convert stored points
            end
            return 0
        end,
    },
    
    -- Vendetta: Enhanced combo point generation during Vendetta
    vendetta = {
        aura = "vendetta",
        last = function() return state.vendetta_combo_points or 0 end,
        interval = function() return state.gcd.execute * 1.5 end,
        value = function() 
            if not state.buff.vendetta.up then return 0 end
            return 1 -- Bonus combo point generation
        end,
    },
    
    -- Premeditation: 2 combo points instantly
    premeditation = {
        aura = "premeditation",
        last = function() return state.premeditation_combo_points or 0 end,
        interval = 20, -- Cooldown based
        value = function() 
            if not state.cooldown.premeditation.ready then return 0 end
            return 2 -- Instant combo points
        end,
    },
} )

-- ===================
-- COMPREHENSIVE TIER SET REGISTRATION
-- ===================

-- Tier 13 (Dragon Soul) - ALL DIFFICULTY LEVELS
spec:RegisterGear( "tier13", 
    -- LFR
    78391, 78392, 78393, 78394, 78395,
    -- Normal
    77024, 77025, 77026, 77027, 77028,
    -- Heroic
    78027, 78028, 78029, 78030, 78031
)

-- Tier 14 (Mogu'shan Vaults / Heart of Fear / Terrace) - ALL DIFFICULTY LEVELS
spec:RegisterGear( "tier14", 
    -- LFR
    89236, 89237, 89238, 89239, 89240,
    -- Normal
    85299, 85300, 85301, 85302, 85303,
    -- Heroic
    89041, 89042, 89043, 89044, 89045
)

-- Tier 15 (Throne of Thunder) - ALL DIFFICULTY LEVELS
spec:RegisterGear( "tier15", 
    -- LFR
    95824, 95825, 95826, 95827, 95828,
    -- Normal
    95298, 95299, 95300, 95301, 95302,
    -- Heroic
    96567, 96568, 96569, 96570, 96571
)

-- Tier 16 (Siege of Orgrimmar) - ALL DIFFICULTY LEVELS
spec:RegisterGear( "tier16", 
    -- LFR
    103321, 103322, 103323, 103324, 103325,
    -- Normal
    99342, 99343, 99344, 99345, 99346,
    -- Heroic
    104581, 104582, 104583, 104584, 104585,
    -- Mythic (added later in patch)
    105849, 105850, 105851, 105852, 105853
)

-- ===================
-- LEGENDARY ITEMS AND NOTABLE GEAR
-- ===================

-- Legendary Daggers Questline (Subtlety BiS)
spec:RegisterGear( "legendary_daggers", {
    77946, -- Golad, Twilight of Aspects (Main Hand)
    77948, -- Tiriosh, Nightmare of Ages (Off Hand)
    78480, -- Fangs of the Father (Set bonus)
} )

-- Notable MoP Legendary Items
spec:RegisterGear( "legendary_cloak", {
    102246, -- Qian-Ying, Fortitude of Niuzao (Tank)
    102247, -- Qian-Le, Courage of Niuzao (DPS)
    102248, -- Fen-Yu, Fury of Xuen (DPS Alternative)
} )

-- PvP Sets
spec:RegisterGear( "gladiator_s12", 84430, 84431, 84432, 84433, 84434 ) -- Malevolent
spec:RegisterGear( "gladiator_s13", 91672, 91673, 91674, 91675, 91676 ) -- Tyrannical  
spec:RegisterGear( "gladiator_s14", 98758, 98759, 98760, 98761, 98762 ) -- Grievous

-- Challenge Mode Sets
spec:RegisterGear( "challenge_mode", 90713, 90714, 90715, 90716, 90717 )

-- ===================
-- TIER SET BONUSES AND ASSOCIATED AURAS
-- ===================

-- T13 Set Bonuses
spec:RegisterAura( "subtlety_t13_2pc", {
    id = 105849, -- 2pc bonus ID
    duration = 3600,
} )

spec:RegisterAura( "subtlety_t13_4pc", {
    id = 105850, -- 4pc bonus ID  
    duration = 3600,
} )

-- T14 Set Bonuses
spec:RegisterAura( "subtlety_t14_2pc", {
    id = 123125, -- Shadow Clone chance increase
    duration = 3600,
} )

spec:RegisterAura( "subtlety_t14_4pc", {
    id = 123126, -- Find Weakness duration increase
    duration = 3600,
} )

-- T15 Set Bonuses
spec:RegisterAura( "subtlety_t15_2pc", {
    id = 138150, -- Hemorrhage crit chance increase
    duration = 3600,
} )

spec:RegisterAura( "subtlety_t15_4pc", {
    id = 138151, -- Shadow Dance energy cost reduction
    duration = 3600,
} )

-- T16 Set Bonuses  
spec:RegisterAura( "subtlety_t16_2pc", {
    id = 145193, -- Shadow Clone damage increase
    duration = 3600,
} )

spec:RegisterAura( "subtlety_t16_4pc", {
    id = 145194, -- Backstab and Ambush chance for extra combo point
    duration = 3600,
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

-- ===================
-- COMPREHENSIVE GLYPH SYSTEM (40+ Glyphs)
-- ===================

spec:RegisterGlyphs( {
    -- ===================
    -- MAJOR GLYPHS (Core Functionality Changes)
    -- ===================
    
    -- Stealth and Opener Glyphs
    [56813] = "ambush",                -- Ambush critical strikes generate 2 additional combo points
    [63253] = "shadow_dance",          -- Increases Shadow Dance duration by 2 seconds  
    [89758] = "vanish",                -- When you Vanish, your threat is reduced on all enemies
    [56798] = "sap",                   -- Increases Sap duration by 20 seconds
    [58039] = "blurred_speed",         -- Sprint can be used while stealthed but reduces duration by 5 sec
    [56811] = "sprint",                -- Increases Sprint duration by 1 second
    
    -- Positional and Combat Glyphs
    [56800] = "backstab",              -- Backstab deals 20% additional damage when used on stunned targets
    [56807] = "hemorrhage",            -- Hemorrhage deals 40% additional damage
    [56819] = "preparation",           -- Adds Dismantle, Kick, and Smoke Bomb to abilities reset by Preparation
    [56820] = "crippling_poison",      -- Crippling Poison reduces movement speed by additional 20%
    [56812] = "garrote",               -- Garrote silences the target for 3 seconds
    
    -- Finishing Move Glyphs  
    [56802] = "eviscerate",            -- Eviscerate critical strikes have 50% chance to refund 1 combo point
    [56801] = "rupture",               -- Rupture ability no longer has range limitation
    [56810] = "slice_and_dice",        -- Slice and Dice costs no energy
    [56803] = "expose_armor",          -- Expose Armor lasts 24 seconds longer
    
    -- Defensive and Utility Glyphs
    [56804] = "feint",                 -- Increases Feint duration by 2 seconds
    [56799] = "evasion",               -- Increases Evasion duration by 5 seconds
    [63269] = "cloak_of_shadows",      -- Cloak of Shadows removes harmful magic effects when used
    [56809] = "gouge",                 -- Reduces energy cost of Gouge by 25
    [56805] = "kick",                  -- Reduces cooldown of Kick by 2 seconds
    
    -- Poison Glyphs
    [58038] = "poisons",               -- Weapon enchantments no longer have time restriction
    [91299] = "blind",                 -- Removes damage over time effects from Blind target
    [58032] = "distract",              -- Reduces cooldown of Distract by 10 seconds
    [56806] = "deadly_throw",          -- Deadly Throw interrupts spellcasting for 3 seconds
    
    -- AoE and Multi-target Glyphs
    [63254] = "fan_of_knives",         -- Increases range of Fan of Knives by 5 yards
    [63256] = "tricks_of_the_trade",   -- Tricks of the Trade lasts additional 4 seconds
    
    -- Utility and Quality of Life Glyphs
    [58027] = "pick_lock",             -- Pick Lock no longer requires Thieves' Tools
    [58017] = "pick_pocket",           -- Allows Pick Pocket to be used in combat
    [58033] = "safe_fall",             -- Reduces falling damage by 30%
    
    -- ===================
    -- MINOR GLYPHS (Cosmetic and Convenience)
    -- ===================
    
    -- Utility Minor Glyphs
    [63415] = "blinding_powder",       -- Blind no longer requires reagent
    [57115] = "detection",             -- Increases stealth detection range
    [57114] = "distract",              -- Increases Distract range by 5 yards
    [57112] = "pick_pocket",           -- Increases Pick Pocket range by 5 yards
    [57116] = "poisons",               -- 50% chance to apply poison to other weapon
    [57113] = "safe_fall",             -- Reduces falling damage by 30%
    [57117] = "vanish",                -- Reduces Vanish cooldown by 30 seconds
    [57118] = "tricks_of_the_trade",   -- Tricks grants 10% movement speed for 6 sec
    
    -- Cosmetic Minor Glyphs
    [58037] = "hemorrhaging_veins",    -- Hemorrhage trails blood on floor
    [92579] = "shadow_dance",          -- Shadow Dance has unique visual effect
    [94657] = "stealth",               -- Enhanced stealth visual effects
    
    -- ===================
    -- MOP-SPECIFIC GLYPHS
    -- ===================
    
    -- New MoP Major Glyphs
    [108214] = "shadow_clone",         -- Shadow Clone duration increased by 2 seconds
    [108213] = "shadow_step",          -- Shadow Step range increased by 5 yards
    [115189] = "anticipation",         -- Anticipation stores 1 additional combo point
    [108212] = "burst_of_speed",       -- Burst of Speed removes all movement impairing effects
    [108211] = "leeching_poison",      -- Leeching Poison heals for 15% more
    [108215] = "paralytic_poison",     -- Paralytic Poison slows by additional 10%
    
    -- Advanced Subtlety Glyphs
    [114015] = "shuriken_toss",        -- Shuriken Toss generates combo points at max range
    [137619] = "marked_for_death",     -- Marked for Death has 50% shorter cooldown if target dies
    [76577]  = "shadowmeld",           -- Shadowmeld can be used in combat (Night Elf racial)
    
    -- PvP-Focused Glyphs
    [56806] = "cheap_shot",            -- Cheap Shot has 10 yard range
    [89775] = "redirect",              -- Redirect no longer has cooldown
    [94023] = "smoke_bomb",            -- Smoke Bomb lasts 2 seconds longer
    [63420] = "expose_armor",          -- Expose Armor affects up to 3 nearby enemies
} )

-- ===================
-- ADVANCED ACTION PRIORITY LIST REGISTRATION
-- ===================

spec:RegisterAPL( "subtlety", 20250530, {
    name = "Subtlety (Enhanced MoP Implementation)",
    desc = "Advanced Subtlety Rogue rotation with sophisticated decision-making for MoP.",
    
    -- Pre-combat preparation
    precombat = {
        -- Stealth before combat
        { "stealth", "!stealthed.all&!in_combat" },
        
        -- Apply poisons
        { "deadly_poison", "!poison.deadly.up&!poison.wound.up" },
        { "crippling_poison", "!poison.nonlethal.up&pvp" },
        
        -- Premeditation if talented
        { "premeditation", "talent.premeditation.enabled&combo_points<=2" },
        
        -- Shadow Focus if moving into combat
        { "shadow_focus", "talent.shadow_focus.enabled&in_stealth&energy<40" },
    },
    
    -- Main combat rotation
    combat = {
        -- === EMERGENCY ACTIONS ===
        -- Cloak of Shadows for magic damage
        { "cloak_of_shadows", 
          "health.pct<=35&debuff.magic.up&!buff.cloak_of_shadows.up" },
        
        -- Evasion for physical damage
        { "evasion", 
          "health.pct<=40&incoming_damage_5s>health.max*0.3&!buff.evasion.up" },
        
        -- Feint for AoE damage reduction
        { "feint", 
          "incoming_damage_3s>health.max*0.25&energy>=20&!buff.feint.up" },
        
        -- === STEALTH MANAGEMENT ===
        -- Shadow Dance usage for burst windows
        { "shadow_dance", 
          "energy>=75&!buff.stealthed.all&!buff.shadow_blades.up&" ..
          "buff.slice_and_dice.up&(" ..
          "cooldown.cold_blood.ready|cooldown.cold_blood.remains>20" ..
          ")&toggle.cooldowns" },
        
        -- Vanish for repositioning and burst
        { "vanish", 
          "time>15&energy>=60&combo_points<=2&!buff.stealthed.all&" ..
          "cooldown.shadow_dance.remains>15&target.time_to_die>25&toggle.cooldowns" },
        
        -- === STEALTH ABILITIES ===
        -- Garrote application from stealth
        { "garrote", 
          "stealthed.all&!dot.garrote.ticking&target.time_to_die>12" },
        
        -- Ambush from stealth
        { "ambush", 
          "stealthed.all&combo_points<5&energy>=40&" ..
          "(buff.find_weakness.down|buff.find_weakness.remains<3)" },
        
        -- Cheap Shot for control
        { "cheap_shot", 
          "stealthed.all&combo_points<5&target.time_to_die>6&" ..
          "!dot.garrote.ticking&target.debuff.stun.down" },
        
        -- === MAJOR COOLDOWNS ===
        -- Shadow Blades for sustained DPS
        { "shadow_blades", 
          "buff.bloodlust.react|target.time_to_die<40|" ..
          "(buff.shadow_dance.up&combo_points>=3)|" ..
          "cooldown.shadow_dance.remains>45&toggle.cooldowns" },
        
        -- Cold Blood for finishing moves
        { "cold_blood", 
          "combo_points>=4&buff.slice_and_dice.up&" ..
          "(buff.shadow_dance.up|buff.find_weakness.up)&toggle.cooldowns" },
        
        -- Preparation for cooldown reset
        { "preparation", 
          "cooldown.vanish.remains>60&cooldown.shadow_dance.remains>40&" ..
          "energy<30&toggle.cooldowns" },
        
        -- === FINISHING MOVES ===
        -- Slice and Dice maintenance (highest priority)
        { "slice_and_dice", 
          "combo_points>=2&(" ..
          "!buff.slice_and_dice.up|" ..
          "buff.slice_and_dice.remains<=6" ..
          ")&target.time_to_die>8" },
        
        -- Rupture application and refresh
        { "rupture", 
          "combo_points>=4&(" ..
          "!dot.rupture.ticking|" ..
          "dot.rupture.remains<=4" ..
          ")&target.time_to_die>12&buff.slice_and_dice.up" },
        
        -- Execute phase Eviscerate
        { "eviscerate", 
          "combo_points>=3&target.health.pct<20&buff.slice_and_dice.up" },
        
        -- Burst window Eviscerate
        { "eviscerate", 
          "combo_points>=5&buff.slice_and_dice.up&" ..
          "(buff.shadow_dance.up|buff.find_weakness.up|buff.shadow_blades.up)" },
        
        -- Standard Eviscerate
        { "eviscerate", 
          "combo_points>=5&buff.slice_and_dice.up&" ..
          "(dot.rupture.up|target.time_to_die<8)" },
        
        -- Emergency healing
        { "recuperate", 
          "health.pct<50&combo_points>=1&energy<50&!buff.recuperate.up" },
        
        -- === COMBO POINT GENERATORS ===
        -- Hemorrhage for debuff and behind positioning
        { "hemorrhage", 
          "combo_points<5&(" ..
          "!dot.hemorrhage.ticking|" ..
          "dot.hemorrhage.remains<4" ..
          ")&target.time_to_die>8" },
        
        -- Backstab from behind
        { "backstab", 
          "position.behind&combo_points<5&energy>=40&" ..
          "(!dot.hemorrhage.ticking|dot.hemorrhage.remains>4)" },
        
        -- Hemorrhage when not behind
        { "hemorrhage", 
          "combo_points<5&!position.behind&energy>=30" },
        
        -- Ghostly Strike if talented
        { "ghostly_strike", 
          "talent.ghostly_strike.enabled&combo_points<5&energy>=40" },
        
        -- Shuriken Toss for ranged combat
        { "shuriken_toss", 
          "talent.shuriken_toss.enabled&combo_points<5&" ..
          "energy<30&target.distance>8" },
        
        -- === UTILITY ABILITIES ===
        -- Shadowstep for positioning
        { "shadowstep", 
          "talent.shadowstep.enabled&target.distance>=12&" ..
          "!position.behind&cooldown.shadowstep.ready" },
        
        -- Burst of Speed for mobility
        { "burst_of_speed", 
          "talent.burst_of_speed.enabled&movement.distance>20&" ..
          "!buff.burst_of_speed.up" },
        
        -- === RESOURCE MANAGEMENT ===
        -- Wait for energy when needed
        { "wait", 
          "energy<40&combo_points<4&cooldown.shadow_dance.remains>10", 
          "sec=0.1" },
        
        -- Auto attack when all else fails
        { "auto_attack", "true" },
    },
    
    -- AoE rotation for multiple targets
    aoe = {
        -- Crimson Tempest for AoE DoT
        { "crimson_tempest", 
          "combo_points>=4&spell_targets.fan_of_knives>=4&" ..
          "(!dot.crimson_tempest.ticking|dot.crimson_tempest.remains<4)" },
        
        -- Slice and Dice for AoE
        { "slice_and_dice", 
          "combo_points>=2&(!buff.slice_and_dice.up|" ..
          "buff.slice_and_dice.remains<8)&spell_targets.fan_of_knives>=3" },
        
        -- Fan of Knives for combo points
        { "fan_of_knives", 
          "combo_points<5&spell_targets.fan_of_knives>=3&energy>=35" },
        
        -- Garrote on priority targets
        { "garrote", 
          "stealthed.all&!dot.garrote.ticking&spell_targets.fan_of_knives<=4" },
        
        -- Standard finisher
        { "eviscerate", "combo_points>=5&buff.slice_and_dice.up" },
        
        -- Fallback generator
        { "hemorrhage", "combo_points<5&energy>=30" },
    },
    
    -- Cleave rotation for 2-3 targets  
    cleave = {
        -- DoT management on primary target
        { "rupture", 
          "combo_points>=4&!dot.rupture.ticking&target.time_to_die>12" },
        
        { "garrote", 
          "stealthed.all&!dot.garrote.ticking&target.time_to_die>12" },
        
        -- Slice and Dice maintenance
        { "slice_and_dice", 
          "combo_points>=2&(!buff.slice_and_dice.up|" ..
          "buff.slice_and_dice.remains<6)" },
        
        -- Primary combo generators
        { "hemorrhage", "combo_points<5&energy>=30" },
        { "backstab", "position.behind&combo_points<5&energy>=40" },
        
        -- Finishers
        { "eviscerate", "combo_points>=5&buff.slice_and_dice.up" },
    },
}, {
    -- Advanced parameters for sophisticated execution
    energy_pooling_enabled = true,
    stealth_optimization = true,
    burst_window_detection = true,
    positional_awareness = true,
    threat_management = true,
})

-- Register opener-specific APL
spec:RegisterAPL( "subtlety_opener", 20250530, {
    name = "Subtlety Opener",
    desc = "Optimized opener sequence for Subtlety Rogue",
    
    combat = {
        -- Stealth opener sequence
        { "stealth", "!stealthed.all&!in_combat" },
        { "premeditation", 
          "stealthed.all&talent.premeditation.enabled&combo_points<=2" },
        { "garrote", 
          "stealthed.all&!dot.garrote.ticking&target.time_to_die>12" },
        { "ambush", "stealthed.all&combo_points<5&energy>=40" },
        { "slice_and_dice", "combo_points>=2&!buff.slice_and_dice.up" },
        { "rupture", 
          "combo_points>=4&!dot.rupture.ticking&buff.slice_and_dice.up" },
    },
})

-- Register execute-specific APL
spec:RegisterAPL( "subtlety_execute", 20250530, {
    name = "Subtlety Execute",
    desc = "Execute phase optimization for Subtlety Rogue",
    
    combat = {
        -- Execute priority (target below 20% health)
        { "eviscerate", "combo_points>=3&target.health.pct<20" },
        { "eviscerate", 
          "combo_points>=4&target.health.pct<35&" ..
          "(buff.find_weakness.up|dot.rupture.up)" },
        { "rupture", 
          "combo_points>=4&!dot.rupture.ticking&" ..
          "target.health.pct<50&target.time_to_die>8" },
        { "hemorrhage", "combo_points<5&energy>=30" },
        { "backstab", "position.behind&combo_points<5&energy>=40" },
    },
})

-- Register context-aware APL selection
spec:RegisterAPLCondition( "opener", "combat.time<=10" )
spec:RegisterAPLCondition( "execute", "target.health.pct<=20" )
spec:RegisterAPLCondition( "aoe", "active_enemies>=4" )
spec:RegisterAPLCondition( "cleave", "active_enemies>=2&active_enemies<=3" )
spec:RegisterAPLCondition( "single_target", "active_enemies=1" )
