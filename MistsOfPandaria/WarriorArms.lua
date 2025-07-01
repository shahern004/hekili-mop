-- WarriorArms.lua
-- Updated May 30, 2025 - Enhanced Structure from Hunter Survival
-- Mists of Pandaria module for Warrior: Arms spec

print("WarriorArms: File starting to load...")
print("WarriorArms: Hekili exists:", tostring(Hekili ~= nil))
print("WarriorArms: Hekili.NewSpecialization exists:", tostring(Hekili and Hekili.NewSpecialization ~= nil))

if not Hekili or not Hekili.NewSpecialization then 
    print("WarriorArms: EARLY RETURN - Hekili or NewSpecialization missing!")
    return 
end

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
print("WarriorArms: Player class:", tostring(playerClass))
if playerClass ~= 'WARRIOR' then 
    print("WarriorArms: EARLY RETURN - Not a warrior!")
    return 
end

print("WarriorArms: Continuing with initialization...")

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

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
        if id == spellID then return name, _, count, _, duration, expires, caster end    end
    return nil
end

print("WarriorArms: About to call NewSpecialization(71)...")
local spec = Hekili:NewSpecialization( 71 ) -- Arms spec ID for MoP
print("WarriorArms: NewSpecialization returned:", tostring(spec ~= nil))

-- Enhanced Helper Functions (following Hunter Survival pattern)
local function UA_GetPlayerAuraBySpellID(spellID, filter)
    return UA_GetPlayerAuraBySpellID(spellID, filter or "HELPFUL")
end

local function GetTargetDebuffByID(spellID, caster)
    local name, icon, count, debuffType, duration, expirationTime, unitCaster = FindUnitDebuffByID("target", spellID, caster or "PLAYER")
    if name then
        return {
            name = name,
            icon = icon,
            count = count or 1,
            duration = duration,
            expires = expirationTime,
            applied = expirationTime - duration,
            caster = unitCaster
        }
    end
    return nil
end

-- Combat Log Event Tracking System (following Hunter Survival structure)
local armsCombatLogFrame = CreateFrame("Frame")
local armsCombatLogEvents = {}

local function RegisterArmsCombatLogEvent(event, handler)
    if not armsCombatLogEvents[event] then
        armsCombatLogEvents[event] = {}
    end
    table.insert(armsCombatLogEvents[event], handler)
end

armsCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
        
        if sourceGUID == UnitGUID("player") then
            local handlers = armsCombatLogEvents[subevent]
            if handlers then
                for _, handler in ipairs(handlers) do
                    handler(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, select(12, CombatLogGetCurrentEventInfo()))
                end
            end
        end
    end
end)

armsCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Colossus Smash debuff tracking
RegisterArmsCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 86346 then -- Colossus Smash
        -- Track Colossus Smash debuff for optimal damage window
    elseif spellID == 85288 then -- Raging Blow (berserker stance proc)
        -- Track Raging Blow availability
    elseif spellID == 12292 then -- Bloodbath
        -- Track Bloodbath DoT application
    end
end)

-- Overpower proc tracking
RegisterArmsCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 60503 then -- Taste for Blood (Overpower proc)
        -- Track Overpower proc availability
    elseif spellID == 46916 then -- Slam! proc
        -- Track Slam instant cast proc
    end
end)

-- Critical strike tracking for Deep Wounds
RegisterArmsCombatLogEvent("SPELL_DAMAGE", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical)
    if critical and (spellID == 12294 or spellID == 1464 or spellID == 78 or spellID == 845) then -- Mortal Strike, Slam, Heroic Strike, Cleave
        -- Apply Deep Wounds DoT on critical strikes
    end
end)

-- Target death tracking for DoT effects
RegisterArmsCombatLogEvent("UNIT_DIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags)
    -- Handle target death for DoT effect optimization (Deep Wounds, Rend)
end)

-- Enhanced Rage resource system for Arms Warrior (MoP stance system)
spec:RegisterResource( 1, { -- Rage = 1 in MoP
    -- MoP Stance-based rage generation
    battle_stance_regen = {
        aura = "battle_stance",
        last = function ()
            local app = state.buff.battle_stance.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            -- Battle Stance: Most rage from auto-attacking, none from taking damage
            return state.buff.battle_stance.up and state.combat and 12 or 0
        end,
    },
    
    berserker_stance_regen = {
        aura = "berserker_stance",
        last = function ()
            local app = state.buff.berserker_stance.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            -- Berserker Stance: Rage from both auto-attacking and taking damage, but less from autos
            local auto_rage = state.combat and 8 or 0 -- Less than Battle Stance
            local damage_rage = state.combat and 4 or 0 -- Rage from taking damage
            return state.buff.berserker_stance.up and (auto_rage + damage_rage) or 0
        end,
    },
    
    defensive_stance_regen = {
        aura = "defensive_stance",
        last = function ()
            local app = state.buff.defensive_stance.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 3 ) * 3 -- 3 second intervals
        end,
        interval = 3,
        value = function()
            -- Defensive Stance: 1 rage per 3 seconds in combat, none from autos/damage
            return state.buff.defensive_stance.up and state.combat and 1 or 0
        end,
    },
    
    -- Mortal Strike rage generation (MoP: generates 10 rage instead of costing rage)
    mortal_strike_regen = {
        channel = "mortal_strike",
        last = function ()
            return state.last_cast_time.mortal_strike or 0
        end,
        interval = 1,
        value = function()
            return 10 -- Mortal Strike generates 10 rage in MoP
        end,
    },
    
    -- Berserker Rage rage generation
    berserker_rage = {
        aura = "berserker_rage",
        last = function ()
            local app = state.buff.berserker_rage.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.buff.berserker_rage.up and 5 or 0 -- 5 rage per second during Berserker Rage
        end,
    },
    
    -- Deadly Calm rage efficiency
    deadly_calm = {
        aura = "deadly_calm",
        last = function ()
            local app = state.buff.deadly_calm.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.buff.deadly_calm.up and 10 or 0 -- Abilities cost no rage during Deadly Calm
        end,
    },
    
    -- Charge rage generation (MoP: Juggernaut talent gives 15 rage per charge)
    charge_rage = {
        channel = "charge",
        last = function ()
            return state.last_cast_time.charge or 0
        end,
        interval = 1,
        value = function()
            return state.talent.juggernaut.enabled and 15 or 0
        end,
    },
}, {
    -- Enhanced base rage generation with MoP stance mechanics
    base_regen = function ()
        local base = 0
        local weapon_bonus = 0
        
        -- Weapon speed affects rage generation from auto attacks
        local weapon_speed = state.main_hand.speed or 2.6
        weapon_bonus = state.combat and (3.5 / weapon_speed) * 2.5 or 0
        
        -- Stance-specific rage generation is handled above in individual auras
        return base + weapon_bonus
    end,
    
    -- Unbridled Wrath rage generation
    unbridled_wrath = function ()
        return state.talent.unbridled_wrath.enabled and 1 or 0 -- Random rage generation from melee hits
    end,
    
    -- Anger Management rage efficiency
    anger_management = function ()
        return state.talent.anger_management.enabled and 0.5 or 0 -- Slight rage efficiency bonus
    end,
} )

-- Tier sets
spec:RegisterGear( 13, 1, { -- Tier 14 (Heart of Fear)
    { 85316, head = 85316, shoulder = 85319, chest = 85317, hands = 85318, legs = 85320 }, -- LFR
    { 85329, head = 85329, shoulder = 85332, chest = 85330, hands = 85331, legs = 85333 }, -- Normal
    { 86590, head = 86590, shoulder = 86593, chest = 86591, hands = 86592, legs = 86594 }, -- Heroic
} )

spec:RegisterAura( "tier14_2pc_arms", {
    id = 105771,
    duration = 30,
    max_stack = 1,
} )

spec:RegisterAura( "tier14_4pc_arms", {
    id = 105785,
    duration = 8,
    max_stack = 1,
} )

spec:RegisterGear( 14, 1, { -- Tier 15 (Throne of Thunder)
    { 95298, head = 95298, shoulder = 95301, chest = 95299, hands = 95300, legs = 95302 }, -- LFR
    { 95705, head = 95705, shoulder = 95708, chest = 95706, hands = 95707, legs = 95709 }, -- Normal
    { 96101, head = 96101, shoulder = 96104, chest = 96102, hands = 96103, legs = 96105 }, -- Heroic
} )

spec:RegisterAura( "tier15_2pc_arms", {
    id = 138165,
    duration = 20,
    max_stack = 1,
} )

spec:RegisterAura( "tier15_4pc_arms", {
    id = 138173,
    duration = 12,
    max_stack = 1,
} )

spec:RegisterGear( 15, 1, { -- Tier 16 (Siege of Orgrimmar)
    { 99691, head = 99691, shoulder = 99694, chest = 99692, hands = 99693, legs = 99695 }, -- LFR
    { 98342, head = 98342, shoulder = 98345, chest = 98343, hands = 98344, legs = 98346 }, -- Normal
    { 99236, head = 99236, shoulder = 99239, chest = 99237, hands = 99238, legs = 99240 }, -- Heroic
    { 99926, head = 99926, shoulder = 99929, chest = 99927, hands = 99928, legs = 99930 }, -- Mythic
} )

spec:RegisterAura( "tier16_2pc_arms", {
    id = 144438,
    duration = 30,
    max_stack = 1,
} )

spec:RegisterAura( "tier16_4pc_arms", {
    id = 144440,
    duration = 15,
    max_stack = 5,
} )

-- Legendary and Notable Items
spec:RegisterGear( "legendary_cloak", 102246, { -- Oxheart, Fearbreaker of Garrosh
    back = 102246,
} )

spec:RegisterAura( "legendary_cloak_proc", {
    id = 148010,
    duration = 4,
    max_stack = 1,
} )

spec:RegisterGear( "thoks_tail_tip", 104769, {
    trinket1 = 104769,
    trinket2 = 104769,
} )

spec:RegisterGear( "sigil_of_rampage", 104770, {
    trinket1 = 104770,
    trinket2 = 104770,
} )

spec:RegisterGear( "ticking_ebon_detonator", 104810, {
    trinket1 = 104810,
    trinket2 = 104810,
} )

spec:RegisterGear( "gorehowl", 105531, {
    main_hand = 105531,
} )

-- Comprehensive Talent System (MoP Talent Trees)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility
    juggernaut                 = { 2047, 1, 103156 }, -- Your Charge ability has 2 charges, shares charges with Intervene, and generates 15 Rage.
    double_time                = { 2048, 1, 103827 }, -- Your Charge ability has 2 charges, shares charges with Intervene, and no longer generates Rage.
    warbringer                 = { 2049, 1, 103828 }, -- Charge also roots the target for 4 sec, and Hamstring generates more Rage.

    -- Tier 2 (Level 30) - Healing/Survival
    second_wind                = { 2050, 1, 29838 },  -- While below 35% health, you regenerate 3% of your maximum health every 1 sec.
    enraged_regeneration       = { 2051, 1, 55694 },  -- Instantly heals you for 10% of your total health and regenerates an additional 10% over 5 sec.
    impending_victory          = { 2052, 1, 103840 }, -- Instantly attack the target causing damage and healing you for 10% of your maximum health.

    -- Tier 3 (Level 45) - Utility
    staggering_shout           = { 2053, 1, 107566 }, -- Causes all enemies within 10 yards to have their movement speed reduced by 50% for 15 sec.
    piercing_howl              = { 2054, 1, 12323 },  -- Causes all enemies within 10 yards to have their movement speed reduced by 50% for 15 sec.
    disrupting_shout           = { 2055, 1, 102060 }, -- Interrupts all enemy spell casts and prevents any spell in that school from being cast for 4 sec.

    -- Tier 4 (Level 60) - Survivability
    bladestorm                 = { 2056, 1, 46924 },  -- Become a whirling maelstrom of steel, striking all nearby enemies for weapon damage over 6 sec.
    shockwave                  = { 2057, 1, 46968 },  -- Sends a wave through the ground, causing damage and stunning all enemies within 10 yards for 4 sec.
    dragon_roar                = { 2058, 1, 118000 }, -- Roar with the fury of a dragon, dealing damage to all enemies within 8 yards.

    -- Tier 5 (Level 75) - Berserker Powers
    mass_spell_reflection      = { 2059, 1, 114028 }, -- Reflects the next spell cast on you or your party members back at its caster.
    safeguard                  = { 2060, 1, 114029 }, -- Intervene now removes all movement impairing effects and provides 30% damage reduction.
    vigilance                  = { 2061, 1, 114030 }, -- Focus your protective instincts on a party member, reducing their damage taken by 30%.

    -- Tier 6 (Level 90) - Ultimate Abilities
    avatar                     = { 2062, 1, 107574 }, -- Transform into a colossus for 24 sec, becoming immune to movement effects and increasing damage by 20%.
    bloodbath                  = { 2063, 1, 12292 },  -- Your attacks trigger a bleeding DoT that lasts 1 min and stacks up to 3 times.
    storm_bolt                 = { 2064, 1, 107570 }  -- Hurl your weapon at an enemy, causing damage and stunning for 4 sec. 1.5 sec cast, 30 sec cooldown.
} )

-- Enhanced Glyphs System for Arms Warrior (following Hunter Survival comprehensiveness)
-- Note: RegisterGlyphs method not available in MoP, glyphs handled differently
--[[
spec:RegisterGlyphs( {
    -- Major Glyphs (affecting DPS and mechanics)
    [58095] = "Glyph of Berserker Rage",      -- Berserker Rage increases movement speed by 50% for its duration.
    [58096] = "Glyph of Bloodthirst",         -- Your Bloodthirst ability heals you for an additional 1% of your maximum health.
    [58097] = "Glyph of Bloody Healing",      -- Increases the healing received from Bloodthirst by 40%.
    [58098] = "Glyph of Bull Rush",           -- Charge now moves you a greater distance and through enemies.
    [58099] = "Glyph of Cleaving",            -- Your Cleave ability affects 1 additional target.
    [58100] = "Glyph of Colossus Smash",      -- Your Colossus Smash generates 10 additional Rage when it critically strikes.
    [58101] = "Glyph of Demoralizing Shout",  -- Reduces the rage cost of Demoralizing Shout by 50%.
    [58102] = "Glyph of Die by the Sword",    -- Die by the Sword also reflects damage back to attackers.
    [58103] = "Glyph of Enraged Speed",       -- Enrage increases your movement speed by 30%.
    [58104] = "Glyph of Execute",             -- Your Execute hits up to 2 additional enemies for 50% damage.
    [58105] = "Glyph of Hamstring",           -- Your Hamstring ability also reduces the target's damage by 10%.
    [58106] = "Glyph of Heroic Strike",       -- Your Heroic Strike increases the damage of your next ability by 15%.
    [58107] = "Glyph of Hindering Strikes",   -- Your auto attacks have a chance to reduce enemy movement speed by 50%.
    [58108] = "Glyph of Intimidating Shout",  -- Reduces the cooldown on Intimidating Shout by 15 sec.
    [58109] = "Glyph of Long Charge",         -- Increases the range of your Charge ability by 5 yards.
    [58110] = "Glyph of Mortal Strike",       -- Your Mortal Strike ability spreads its healing absorption to 1 nearby enemy.
    [58111] = "Glyph of Overpower",           -- Overpower has a 25% chance to reset the cooldown on Mortal Strike.
    [58112] = "Glyph of Raging Blow",         -- Raging Blow has no cooldown, but the rage cost is increased by 100%.
    [58113] = "Glyph of Rallying Cry",        -- Rallying Cry grants an additional 10% maximum health.
    [58114] = "Glyph of Rend",                -- Your Rend ability affects all enemies within 5 yards of your target.
    [58115] = "Glyph of Revenge",             -- Revenge also increases your movement speed by 30% for 6 sec.
    [58116] = "Glyph of Shield Slam",         -- Shield Slam silences the target for 3 sec.
    [58117] = "Glyph of Shield Wall",         -- Shield Wall reflects 20% of damage back to attackers.
    [58118] = "Glyph of Slam",                -- Slam has a 25% chance to reset the cooldown on Overpower.
    [58119] = "Glyph of Spell Reflection",    -- Spell Reflection lasts 50% longer.
    [58120] = "Glyph of Sweeping Strikes",    -- Increases the duration of Sweeping Strikes by 4 sec.
    [58121] = "Glyph of Thunder Clap",        -- Thunder Clap also reduces attack speed by an additional 10%.
    [58122] = "Glyph of Victory Rush",        -- Victory Rush increases your movement speed by 50% for 6 sec.
    [58123] = "Glyph of Whirlwind",           -- Whirlwind generates 5 rage for each target hit.
    [58124] = "Glyph of Wind and Thunder",    -- Reduces the rage cost of Thunder Clap by 10.
    
    -- Minor Glyphs (convenience and visual)
    [58125] = "Glyph of Battle",              -- You appear to be in a battle stance even when you're not.
    [58126] = "Glyph of Berserker Stance",    -- You appear to be in berserker stance even when you're not.
    [58127] = "Glyph of Bloodcurdling Shout", -- Your shouts have enhanced visual and sound effects.
    [58128] = "Glyph of Burning Anger",       -- Your character glows with inner fire when enraged.
    [58129] = "Glyph of Defensive Stance",    -- You appear to be in defensive stance even when you're not.
    [58130] = "Glyph of Gushing Wound",       -- Your critical strikes cause more dramatic bleeding effects.    [58131] = "Glyph of the Savage Beast",    -- Your weapons appear to drip with blood.
    [58132] = "Glyph of Thunder Strike",      -- Your weapon attacks create lightning effects.
    [58133] = "Glyph of the Weaponmaster",    -- Your weapons appear to be of exceptional quality.
    [58134] = "Glyph of Intimidation",        -- Your character appears more menacing.
} )
--]]

-- Arms Warrior specific auras
spec:RegisterAuras( {
    -- Core buffs/debuffs
    battle_shout = {
        id = 6673,
        duration = 3600,
        max_stack = 1,
    },
    commanding_shout = {
        id = 469,
        duration = 3600,
        max_stack = 1,
    },    colossus_smash = {
        id = 86346,
        duration = 6,
        max_stack = 1,
    },
    mortal_strike_debuff = {
        id = 12294,
        duration = 10,
        max_stack = 1,
    },
    sudden_death = {
        id = 52437,
        duration = 10,
        max_stack = 1,
    },
    taste_for_blood = {
        id = 60503,
        duration = 10,
        max_stack = 3,
    },
    sweeping_strikes = {
        id = 12328,
        duration = 10,
        max_stack = 1,
    },    overpower = {
        id = 7384,
        duration = 5,  -- WoW Sims: 5 second window to use Overpower after dodge
        max_stack = 1,
    },
    deadly_calm = {
        id = 85730,
        duration = 10,
        max_stack = 1,
    },
    enrage = {
        id = 12880,
        duration = 8,
        max_stack = 1,
    },
    berserker_rage = {
        id = 18499,
        duration = function() return glyph.unending_rage.enabled and 8 or 6 end,
        max_stack = 1,
    },
    
    -- Talent-specific buffs/debuffs
    avatar = {
        id = 107574,
        duration = 24,
        max_stack = 1,
    },
    bladestorm = {
        id = 46924,
        duration = 6,
        max_stack = 1,
    },
    bloodbath = {
        id = 12292,
        duration = 12,
        max_stack = 1,
    },
    bloodbath_dot = {
        id = 113344,
        duration = 6,
        tick_time = 1,
        max_stack = 1,
    },
    dragon_roar = {
        id = 118000,
        duration = 4,
        max_stack = 1,
    },
    second_wind = {
        id = 29838,
        duration = 3600,
        max_stack = 1,
    },
    vigilance = {
        id = 114030,
        duration = 12,
        max_stack = 1,
    },
    
    -- Defensives
    die_by_the_sword = {
        id = 118038,
        duration = function() return glyph.die_by_the_sword.enabled and 4 or 8 end,
        max_stack = 1,
    },
    shield_wall = {
        id = 871,
        duration = 12,
        max_stack = 1,
    },
    spell_reflection = {
        id = 23920,
        duration = function() return glyph.spell_reflection.enabled and 4 or 5 end,
        max_stack = 1,
    },
    mass_spell_reflection = {
        id = 114028,
        duration = 5,
        max_stack = 1,
    },
    enraged_regeneration = {
        id = 55694,
        duration = 5,
        tick_time = 1,
        max_stack = 1,
    },
    
    -- Crowd control / utility
    hamstring = {
        id = 1715,
        duration = 15,
        max_stack = 1,
    },
    piercing_howl = {
        id = 12323,
        duration = 15,
        max_stack = 1,
    },
    staggering_shout = {
        id = 107566,
        duration = 15,
        max_stack = 1,
    },
    shockwave = {
        id = 46968,
        duration = 4,
        max_stack = 1,
    },
    storm_bolt = {
        id = 107570,
        duration = 3,
        max_stack = 1,
    },
    war_banner = {
        id = 114207,
        duration = 15,
        max_stack = 1,
    },
    rallying_cry = {
        id = 97462,
        duration = 10,
        max_stack = 1,
    },
    demoralizing_shout = {
        id = 1160,
        duration = 10,
        max_stack = 1,
    },
    disrupting_shout = {
        id = 102060,
        duration = 4,
        max_stack = 1,
    },
    intimidating_shout = {
        id = 5246,
        duration = 8,
        max_stack = 1,
    },    charge_root = {
        id = 105771,
        duration = function() 
            if talent.warbringer.enabled then
                return 4
            elseif glyph.bull_rush.enabled then
                return 1
            end
            return 0
        end,
        max_stack = 1,
    },
      -- DoTs and debuffs
    rend = {
        id = 772,
        duration = 15,  -- WoW Sims: 5 ticks over 15 seconds
        tick_time = 3,  -- WoW Sims: 3 second intervals
        max_stack = 1,
    },
} )

-- Advanced Aura System with Generate Functions (following Hunter Survival pattern)
spec:RegisterAuras( {
    -- Arms-specific Auras
    colossus_smash = {
        id = 86346,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuff( "target", 86346, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    mortal_strike = {
        id = 12294,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local debuff = GetTargetDebuffByID(12294, "PLAYER")
            if debuff then
                t.name = debuff.name
                t.count = debuff.count
                t.expires = debuff.expires
                t.applied = debuff.applied
                t.caster = debuff.caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    rend = {
        id = 94009,
        duration = 15,
        tick_time = 3,
        max_stack = 1,
        generate = function( t )
            local debuff = GetTargetDebuffByID(94009, "PLAYER")
            if debuff then
                t.name = debuff.name
                t.count = debuff.count
                t.expires = debuff.expires
                t.applied = debuff.applied
                t.caster = debuff.caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    deep_wounds = {
        id = 115767,
        duration = 12,
        tick_time = 3,
        max_stack = 1,
        generate = function( t )
            local debuff = GetTargetDebuffByID(115767, "PLAYER")
            if debuff then
                t.name = debuff.name
                t.count = debuff.count
                t.expires = debuff.expires
                t.applied = debuff.applied
                t.caster = debuff.caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    taste_for_blood = {
        id = 60503,
        duration = 9,
        max_stack = 5,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 60503 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    slam_proc = {
        id = 46916,
        duration = 5,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 46916 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    sudden_death = {
        id = 52437,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 52437 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    bloodbath = {
        id = 113344,
        duration = 60,
        tick_time = 3,
        max_stack = 3,
        generate = function( t )
            local debuff = GetTargetDebuffByID(113344, "PLAYER")
            if debuff then
                t.name = debuff.name
                t.count = debuff.count
                t.expires = debuff.expires
                t.applied = debuff.applied
                t.caster = debuff.caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Shared Warrior Auras
    battle_stance = {
        id = 2457,
        duration = 3600,
        max_stack = 1
    },
    
    defensive_stance = {
        id = 71,
        duration = 3600,
        max_stack = 1
    },
    
    berserker_stance = {
        id = 2458,
        duration = 3600,
        max_stack = 1
    },
    
    berserker_rage = {
        id = 18499,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 18499 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    deadly_calm = {
        id = 85730,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 85730 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    avatar = {
        id = 107574,
        duration = 24,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 107574 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    sweeping_strikes = {
        id = 12328,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 12328 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    recklessness = {
        id = 1719,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 1719 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    shield_wall = {
        id = 871,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 871 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    die_by_the_sword = {
        id = 118038,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 118038 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    spell_reflection = {
        id = 23920,
        duration = 5,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 23920 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    rallying_cry = {
        id = 97462,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 97462 )
            
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    commanding_shout = {
        id = 469,
        duration = 300,
        max_stack = 1
    },
    
    battle_shout = {
        id = 6673,
        duration = 300,
        max_stack = 1
    },
} )

-- MoP Stance System - Abilities no longer require specific stances
spec:RegisterAbilities( {
    -- Core rotational abilities
    mortal_strike = {
        id = 12294,
        cast = 0,
        cooldown = 6,  -- MoP: 6 second cooldown
        gcd = "spell",
        
        spend = function()
            -- MoP: Mortal Strike generates 10 rage instead of costing rage
            return -10
        end,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132355,
        
        handler = function()
            -- Apply 50% healing reduction debuff for 10 seconds
            applyDebuff( "target", "mortal_strike_debuff", 10 )
            
            -- MoP: Each cast gives 2 charges of Overpower
            if not buff.taste_for_blood.up then
                applyBuff( "taste_for_blood" )
                buff.taste_for_blood.stack = 2
            else
                addStack( "taste_for_blood", nil, 2 )
                if buff.taste_for_blood.stack > 3 then
                    buff.taste_for_blood.stack = 3
                end
            end
        end,
    },
      overpower = {
        id = 7384,
        cast = 0,
        cooldown = 0,
        gcd = function() return 1.0 end,  -- MoP: Reduced global cooldown
        
        spend = 10,  -- MoP: 10 rage cost
        spendType = "rage",
        
        startsCombat = true,
        texture = 132223,
        
        charges = function()
            -- MoP: Works off a charge system
            return buff.taste_for_blood.stack or 0
        end,
        
        usable = function()
            return buff.taste_for_blood.up, "requires taste for blood charges (from mortal strike)"
        end,
        
        handler = function()
            removeStack( "taste_for_blood", 1 )
            
            -- Glyph of Overpower: 25% chance to reset Mortal Strike cooldown
            if glyph.overpower.enabled and math.random() < 0.25 then
                setCooldown( "mortal_strike", 0 )
            end
        end,
    },
      colossus_smash = {
        id = 86346,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        spend = 20,  -- WoW Sims: 20 rage cost
        spendType = "rage",
        
        startsCombat = true,
        texture = 464973,
        
        handler = function()
            applyDebuff( "target", "colossus_smash" )
            if glyph.colossus_smash.enabled then
                applyBuff( "enrage" )
            end
        end,
    },    execute = {
        id = 5308,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            if buff.sudden_death.up then return 0 end
            -- MoP: Execute costs 30 rage base, consumes up to 70 extra rage for more damage
            return 30
        end,
        spendType = "rage",
        
        startsCombat = true,
        texture = 135358,
        
        usable = function()
            return target.health_pct < 20 or buff.sudden_death.up, "requires target below 20% health or sudden_death buff"
        end,
        
        handler = function()
            if buff.sudden_death.up then
                removeBuff( "sudden_death" )
            else
                -- MoP: Consume extra rage for additional damage (up to 70 rage total)
                local current_rage = rage.current
                local extra_rage = math.min( current_rage, 70 )
                if extra_rage > 0 then
                    spend( extra_rage, "rage" )
                end
            end
            
            -- MoP: Execute grants Sudden Execute buff
            applyBuff( "sudden_execute" )
        end,
    },slam = {
        id = 1464,
        cast = 0,  -- MoP: Slam is now instant cast
        cooldown = 0,
        gcd = "spell",
        
        spend = 25,  -- MoP: 25 rage cost
        spendType = "rage",
        
        startsCombat = true,
        texture = 132340,
        
        handler = function()
            -- MoP: Slam deals 275% weapon damage + 10% more during Colossus Smash
            -- Glyph of Slam: 25% chance to reset Overpower cooldown
            if glyph.slam.enabled and math.random() < 0.25 then
                if not buff.taste_for_blood.up then
                    applyBuff( "taste_for_blood" )
                    buff.taste_for_blood.stack = 1
                else
                    addStack( "taste_for_blood", nil, 1 )
                end
            end
            
            -- MoP: While Sweeping Strikes is active, 35% of Slam damage hits all enemies within 2 yards
            if buff.sweeping_strikes.up then
                -- This is handled by the game engine
            end
        end,
    },
      rend = {
        id = 772,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 10,  -- WoW Sims: 10 rage cost
        spendType = "rage",
        
        startsCombat = true,
        texture = 132155,
        
        handler = function()
            applyDebuff( "target", "rend" )
            
            -- Trigger Taste for Blood (Arms passive that builds stacks on Rend/auto crit)
            if not buff.taste_for_blood.up then
                applyBuff( "taste_for_blood" )
                buff.taste_for_blood.stack = 1
            elseif buff.taste_for_blood.stack < 3 then
                addStack( "taste_for_blood", nil, 1 )
            end
        end,
    },
    
    -- Defensive / utility
    battle_shout = {
        id = 6673,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = false,
        texture = 132333,
        
        handler = function()
            applyBuff( "battle_shout" )
        end,
    },
    
    commanding_shout = {
        id = 469,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = false,
        texture = 132351,
        
        handler = function()
            applyBuff( "commanding_shout" )
        end,
    },
      sweeping_strikes = {
        id = 12328,
        cast = 0,
        cooldown = 10,  -- MoP: 10-second cooldown, can always maintain if you have rage
        gcd = "spell",
        
        spend = 20,  -- Rage cost to maintain
        spendType = "rage",
        
        startsCombat = false,
        texture = 132306,
        
        handler = function()
            applyBuff( "sweeping_strikes" )
            -- MoP: Sweeping Strikes now deals 50% damage to targets (down from 100%)
            -- MoP: While active, 35% of Slam damage hits all enemies within 2 yards
        end,
    },
    
    charge = {
        id = 100,
        cast = 0,
        cooldown = function() 
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 20
            end
            return 20 
        end,
        charges = function()
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 2
            end
            return 1
        end,
        recharge = 20,
        gcd = "off",
        
        spend = function()
            if talent.juggernaut.enabled then return -15 end
            return 0
        end,
        spendType = "rage",
        
        range = function() 
            if glyph.long_charge.enabled then
                return 30
            end
            return 25 
        end,
        
        startsCombat = true,
        texture = 132337,
        
        handler = function()
            if talent.warbringer.enabled or glyph.bull_rush.enabled then
                applyDebuff( "target", "charge_root" )
            end
        end,
    },
    
    hamstring = {
        id = 1715,
        cast = 0,
        cooldown = 0,
        gcd = function() return glyph.hamstring.enabled and 0.5 or 1.5 end,
        
        spend = function() 
            if talent.warbringer.enabled then return 5 end
            return 10 
        end,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132316,
        
        handler = function()
            applyDebuff( "target", "hamstring" )
        end,
    },
      deadly_calm = {
        id = 85730,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 464593,
        
        handler = function()
            applyBuff( "deadly_calm" )
        end,
    },
    
    berserker_rage = {
        id = 18499,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = false,
        texture = 136009,
        
        handler = function()
            applyBuff( "berserker_rage" )
        end,
    },
    
    heroic_leap = {
        id = 6544,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 236171,
        
        handler = function()
            -- No specific effect, just the leap
        end,
    },
    
    rallying_cry = {
        id = 97462,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 132351,
        
        handler = function()
            applyBuff( "rallying_cry" )
        end,
    },
    
    die_by_the_sword = {
        id = 118038,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 132336,
        
        handler = function()
            applyBuff( "die_by_the_sword" )
        end,
    },
    
    intervene = {
        id = 3411,
        cast = 0,
        cooldown = function() 
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 20
            end
            return 30 
        end,
        charges = function()
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 2
            end
            return 1
        end,
        recharge = function() 
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 20
            end
            return 30 
        end,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        range = function() 
            if glyph.long_charge.enabled then
                return 30
            end
            return 25 
        end,
        
        startsCombat = false,
        texture = 132365,
        
        handler = function()
            if talent.safeguard.enabled then
                -- Apply damage reduction to the target (handled by the game)
            end
        end,
    },
    
    -- Talent abilities
    avatar = {
        id = 107574,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 613534,
        
        handler = function()
            applyBuff( "avatar" )
        end,
    },
    
    bloodbath = {
        id = 12292,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 236304,
        
        handler = function()
            applyBuff( "bloodbath" )
        end,
    },
    
    bladestorm = {
        id = 46924,
        cast = 0,
        cooldown = function() return glyph.bladestorm.enabled and 75 or 90 end,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 236303,
        
        handler = function()
            applyBuff( "bladestorm" )
        end,
    },
    
    dragon_roar = {
        id = 118000,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 642418,
        
        handler = function()
            applyDebuff( "target", "dragon_roar" )
        end,
    },
    
    shockwave = {
        id = 46968,
        cast = 0,
        cooldown = 40,
        gcd = "spell",
        
        spend = function() 
            if glyph.burning_anger.enabled then return 20 end
            return 0 
        end,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 236312,
        
        handler = function()
            applyDebuff( "target", "shockwave" )
        end,
    },
    
    storm_bolt = {
        id = 107570,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 613535,
        
        handler = function()
            applyDebuff( "target", "storm_bolt" )
        end,
    },
    
    vigilance = {
        id = 114030,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 236331,
        
        handler = function()
            applyBuff( "vigilance" )
        end,
    },
    
    impending_victory = {
        id = 103840,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 10,
        spendType = "rage",
        
        startsCombat = true,
        texture = 589768,
        
        handler = function()
            local heal_amount = health.max * (glyph.bloody_healing.enabled and 0.2 or 0.1)
            gain( heal_amount, "health" )
        end,
    },
    
    staggering_shout = {
        id = 107566,
        cast = 0,
        cooldown = 40,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132346,
        
        handler = function()
            applyDebuff( "target", "staggering_shout" )
        end,
    },
    
    piercing_howl = {
        id = 12323,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132117,
        
        handler = function()
            applyDebuff( "target", "piercing_howl" )
        end,
    },
    
    disrupting_shout = {
        id = 102060,
        cast = 0,
        cooldown = function() 
            -- MoP: Shares cooldown with Pummel
            return cooldown.pummel.remains > 0 and cooldown.pummel.remains or 15
        end,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "interrupts",
        
        startsCombat = true,
        texture = 613534,
        
        handler = function()
            applyDebuff( "target", "disrupting_shout" )
            setCooldown( "pummel", 15 )
        end,
    },
    
    pummel = {
        id = 6552,
        cast = 0,
        cooldown = function() 
            -- MoP: Shares cooldown with Disrupting Shout
            return cooldown.disrupting_shout.remains > 0 and cooldown.disrupting_shout.remains or 15
        end,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "interrupts",
        
        startsCombat = true,
        texture = 132938,
        
        handler = function()
            interrupt()
            setCooldown( "disrupting_shout", 15 )
        end,
    },
    
    -- MoP-specific abilities
    thunder_clap = {
        id = 6343,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = function() 
            if glyph.wind_and_thunder.enabled then return 10 end
            return 20 
        end,
        spendType = "rage",
        
        startsCombat = true,
        texture = 136105,
        
        handler = function()
            -- MoP: With Blood and Thunder talent, applies Deep Wounds to all targets hit
            if talent.blood_and_thunder.enabled then
                applyDebuff( "target", "deep_wounds" )
            end
            
            -- Base Thunder Clap slow effect
            applyDebuff( "target", "thunder_clap_slow" )
        end,
    },
    
    deep_wounds = {
        id = 115767,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132090,
        
        -- Passive ability triggered by critical strikes
        handler = function()
            applyDebuff( "target", "deep_wounds" )
        end,
    },
} )

-- Range
spec:RegisterRanges( "mortal_strike", "charge", "heroic_throw" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    gcd = 1645,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "golemblood",
    
    package = "Arms",
} )

-- Default pack for MoP Arms Warrior
print("WarriorArms: About to RegisterPack 'Arms'...")
spec:RegisterPack( "Arms", 20250515, [[Hekili:TznBVTTnu4FlXjHjMjENnWUYJaUcMLf8KvAm7nYjPPQonGwX2jzlkiuQumzkaLRQiQOeH9an1Y0YnpYoWgwlYFltwGtRJ(aiCN9tobHNVH)8TCgF)(5ElyJlFNlcDnPXD5A8j0)(MNZajDa3aNjp2QphnPtoKvyF)GcKKOzjI08QjnOVOCXMj3nE)waT58Pw(aFm0P)MM]] )
print("WarriorArms: RegisterPack 'Arms' completed")

-- Register pack selector for Arms
