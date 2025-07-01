-- WarlockDemonology.lua
-- Updated May 28, 2025 


-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'WARLOCK' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class, state

local function getReferences()
    if not class then
        class, state = Hekili.Class, Hekili.State
    end
    return class, state
end

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

-- Enhanced helper functions for Demonology Warlock
local function UA_GetPlayerAuraBySpellID(spellID)
    return FindUnitBuffByID("player", spellID)
end

local function GetPetBuffByID(spellID)
    if UnitExists("pet") then
        return FindUnitBuffByID("pet", spellID)
    end
    return nil
end

local function GetTargetDebuffByID(spellID)
    return FindUnitDebuffByID("target", spellID, "PLAYER")
end

local spec = Hekili:NewSpecialization( 266 ) -- Demonology spec ID for MoP

-- Demonology-specific combat log event tracking
local demoCombatLogFrame = CreateFrame("Frame")
local demoCombatLogEvents = {}

local function RegisterDemoCombatLogEvent(event, handler)
    if not demoCombatLogEvents[event] then
        demoCombatLogEvents[event] = {}
    end
    table.insert(demoCombatLogEvents[event], handler)
end

demoCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
        
        if sourceGUID == UnitGUID("player") or sourceGUID == UnitGUID("pet") then
            local handlers = demoCombatLogEvents[subevent]
            if handlers then
                for _, handler in ipairs(handlers) do
                    handler(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, select(12, CombatLogGetCurrentEventInfo()))
                end
            end
        end
    end
end)

demoCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Demonic Fury generation tracking
RegisterDemoCombatLogEvent("SPELL_CAST_SUCCESS", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 686 then -- Shadow Bolt
        -- Shadow Bolt generates 40 Demonic Fury
    elseif spellID == 104027 then -- Soul Fire
        -- Soul Fire generates 60 Demonic Fury
    elseif spellID == 348 then -- Immolate
        -- Immolate generates 10 Demonic Fury
    end
end)

-- Doom tick tracking for Demonic Fury
RegisterDemoCombatLogEvent("SPELL_PERIODIC_DAMAGE", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 603 then -- Doom
        -- Doom tick generates 20 Demonic Fury
    elseif spellID == 172 then -- Corruption
        -- Corruption tick generates small Demonic Fury
    end
end)

-- Molten Core proc tracking
RegisterDemoCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 122355 then -- Molten Core
        -- Track Molten Core application for optimized Soul Fire usage
    end
end)

-- Pet death tracking for Grimoire talents
RegisterDemoCombatLogEvent("UNIT_DIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags)
    if sourceGUID == UnitGUID("pet") then
        -- Handle pet death for Grimoire mechanics
    end
end)

-- Enhanced Mana and Demonic Fury resource system for Demonology Warlock
spec:RegisterResource( 0, { -- Mana = 0 in MoP
    -- Life Tap mana generation
    life_tap = {
        aura = "life_tap",
        last = function ()
            local app = state.buff.life_tap.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1.5 ) * 1.5
        end,
        interval = 1.5,
        value = function()
            return state.health.current * 0.15 -- 15% of current health as mana
        end,
    },
    
    -- Dark Soul mana regeneration bonus
    dark_soul = {
        aura = "dark_soul",
        last = function ()
            local app = state.buff.dark_soul.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.buff.dark_soul.up and state.max_mana * 0.02 or 0 -- 2% max mana per second
        end,
    },
    
    -- Harvest Life mana return
    harvest_life = {
        aura = "harvest_life",
        last = function ()
            local app = state.buff.harvest_life.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.buff.harvest_life.up and 800 or 0 -- Fixed mana per second
        end,
    },
}, {
    -- Enhanced base mana regeneration with various bonuses
    base_regen = function ()
        local base = state.max_mana * 0.02 -- 2% of max mana per 5 seconds
        local spirit_bonus = base * (state.stat.spirit / 100)
        local talent_bonus = 0
        
        -- Talent bonuses
        if state.talent.drain_life.enabled and state.channeling and state.channeling.spell == "drain_life" then
            talent_bonus = talent_bonus + state.stat.spirit * 0.10 -- 10% spirit bonus while channeling Drain Life
        end
        
        return (base + spirit_bonus + talent_bonus) / 5 -- Convert to per-second
    end,
    
    -- Demonic Pact mana bonus
    demonic_pact = function ()
        return state.buff.demonic_pact.up and state.max_mana * 0.10 or 0 -- 10% mana bonus
    end,
} )

spec:RegisterResource( 11, { -- DemonicFury = 11 in MoP
    max = 1000,
    
    regen = 0,
    regenRate = function( state )
        return 0 -- Demonic Fury generates from abilities, not passively
    end,
    
    -- Enhanced Demonic Fury generation from various sources
    generate = function( amount, overcap )
        local cur = state.demonic_fury.current
        local max = state.demonic_fury.max
        
        amount = amount or 0
        
        -- Apply Metamorphosis bonuses
        if state.buff.metamorphosis.up then
            amount = amount * 1.25 -- 25% more fury generation in Metamorphosis
        end
        
        if overcap then
            state.demonic_fury.current = cur + amount
        else
            state.demonic_fury.current = math.min( max, cur + amount )
        end
        
        if state.demonic_fury.current > cur then
            state.gain( amount, "demonic_fury" )
        end
    end,
    
    spend = function( amount )
        local cur = state.demonic_fury.current
        
        if cur >= amount then
            state.demonic_fury.current = cur - amount
            state.spend( amount, "demonic_fury" )
            return true
        end
        
        return false
    end,
} )

-- Enhanced Tier Sets with comprehensive bonuses
spec:RegisterGear( 13, 8, { -- Tier 14 (Heart of Fear)
    { 85373, head = 85373, shoulder = 85376, chest = 85374, hands = 85375, legs = 85377 }, -- LFR
    { 85900, head = 85900, shoulder = 85903, chest = 85901, hands = 85902, legs = 85904 }, -- Normal
    { 86547, head = 86547, shoulder = 86550, chest = 86548, hands = 86549, legs = 86551 }, -- Heroic
} )

spec:RegisterAura( "tier14_2pc_demo", {
    id = 105770,
    duration = 8,
    max_stack = 1,
} )

spec:RegisterAura( "tier14_4pc_demo", {
    id = 105788,
    duration = 30,
    max_stack = 3,
} )

spec:RegisterGear( 14, 8, { -- Tier 15 (Throne of Thunder)
    { 95298, head = 95298, shoulder = 95301, chest = 95299, hands = 95300, legs = 95302 }, -- LFR
    { 95705, head = 95705, shoulder = 95708, chest = 95706, hands = 95707, legs = 95709 }, -- Normal
    { 96101, head = 96101, shoulder = 96104, chest = 96102, hands = 96103, legs = 96105 }, -- Heroic
} )

spec:RegisterAura( "tier15_2pc_demo", {
    id = 138483,
    duration = 10,
    max_stack = 1,
} )

spec:RegisterAura( "tier15_4pc_demo", {
    id = 138486,
    duration = 15,
    max_stack = 1,
} )

spec:RegisterGear( 15, 8, { -- Tier 16 (Siege of Orgrimmar)
    { 99552, head = 99552, shoulder = 99555, chest = 99553, hands = 99554, legs = 99556 }, -- LFR  
    { 98237, head = 98237, shoulder = 98240, chest = 98238, hands = 98239, legs = 98241 }, -- Normal
    { 99097, head = 99097, shoulder = 99100, chest = 99098, hands = 99099, legs = 99101 }, -- Heroic
    { 99787, head = 99787, shoulder = 99790, chest = 99788, hands = 99789, legs = 99791 }, -- Mythic
} )

spec:RegisterAura( "tier16_2pc_demo", {
    id = 144583,
    duration = 15,
    max_stack = 1,
} )

spec:RegisterAura( "tier16_4pc_demo", {
    id = 144584,
    duration = 8,
    max_stack = 1,
} )

-- Legendary and Notable Items
spec:RegisterGear( "legendary_cloak", 102246, { -- Xing-Ho, Breath of Yu'lon
    back = 102246,
} )

spec:RegisterAura( "legendary_cloak_proc", {
    id = 148008,
    duration = 4,
    max_stack = 1,
} )

spec:RegisterGear( "assurance_of_consequence", 104676, {
    trinket1 = 104676,
    trinket2 = 104676,
} )

spec:RegisterGear( "black_blood_of_yshaarj", 104810, {
    trinket1 = 104810,
    trinket2 = 104810,
} )

spec:RegisterGear( "purified_bindings_of_immerseus", 104770, {
    trinket1 = 104770,
    trinket2 = 104770,
} )

-- Comprehensive Talent System (MoP Talent Trees + Mastery Talents)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Healing/Survivability
    dark_regeneration         = { 2225, 1, 108359 }, -- Instantly restores 30% of your maximum health. Restores an additional 6% of your maximum health for each of your damage over time effects on hostile targets within 20 yards. 2 min cooldown.
    soul_leech                = { 2226, 1, 108370 }, -- When you deal damage with Malefic Grasp, Drain Soul, Shadow Bolt, Touch of Chaos, Chaos Bolt, Incinerate, Fel Flame, Haunt, or Soul Fire, you create a shield that absorbs (45% of Spell power) damage for 15 sec.
    harvest_life              = { 2227, 1, 108371 }, -- Drains the health from up to 3 nearby enemies within 20 yards, causing Shadow damage and gaining 2% of maximum health per enemy every 1 sec.

    -- Tier 2 (Level 30) - Crowd Control
    howl_of_terror            = { 2228, 1, 5484 },   -- Causes all nearby enemies within 10 yards to flee in terror for 8 sec. Targets are disoriented for 3 sec. 40 sec cooldown.
    mortal_coil               = { 2229, 1, 6789 },   -- Horrifies an enemy target, causing it to flee in fear for 3 sec. The caster restores 11% of maximum health when the effect successfully horrifies an enemy. 30 sec cooldown.
    shadowfury                = { 2230, 1, 30283 },  -- Stuns all enemies within 8 yards for 3 sec. 30 sec cooldown.

    -- Tier 3 (Level 45) - Defensive Cooldowns  
    soul_link                 = { 2231, 1, 108415 }, -- 20% of all damage taken by the Warlock is redirected to your demon pet instead. While active, both your demon and you will regenerate 3% of maximum health each second. Lasts as long as your demon is active.
    sacrificial_pact          = { 2232, 1, 108416 }, -- Sacrifice your summoned demon to prevent 300% of your maximum health in damage divided among all party and raid members within 40 yards. Lasts 8 sec.
    dark_bargain              = { 2233, 1, 110913 }, -- Prevents all damage for 8 sec. When the shield expires, 50% of the total amount of damage prevented is dealt to the caster over 8 sec. 3 min cooldown.

    -- Tier 4 (Level 60) - Utility
    blood_fear                = { 2234, 1, 111397 }, -- When you use Healthstone, enemies within 15 yards are horrified for 4 sec. 45 sec cooldown.
    burning_rush              = { 2235, 1, 111400 }, -- Increases your movement speed by 50%, but also deals damage to you equal to 4% of your maximum health every 1 sec.
    unbound_will              = { 2236, 1, 108482 }, -- Removes all Magic, Curse, Poison, and Disease effects and makes you immune to controlling effects for 6 sec. 2 min cooldown.

    -- Tier 5 (Level 75) - Grimoire Choice
    grimoire_of_supremacy     = { 2237, 1, 108499 }, -- Your demons deal 20% more damage and are transformed into more powerful demons with enhanced abilities.
    grimoire_of_service       = { 2238, 1, 108501 }, -- Summons a second demon with 100% increased damage for 15 sec. 2 min cooldown.
    grimoire_of_sacrifice     = { 2239, 1, 108503 }, -- Sacrifices your demon to grant you an ability depending on the demon sacrificed, and increases your damage by 15%. Lasts 15 sec.

    -- Tier 6 (Level 90) - DPS Enhancement
    archimondes_vengeance     = { 2240, 1, 108505 }, -- When you take direct damage, you reflect 15% of the damage taken back at the attacker. For the next 10 sec, you reflect 45% of all direct damage taken. This ability has 3 charges. 30 sec cooldown per charge.
    kiljaedens_cunning        = { 2241, 1, 108507 }, -- Your Malefic Grasp, Drain Life, and Drain Soul can be cast while moving.
    mannoroths_fury           = { 2242, 1, 108508 }  -- Your Rain of Fire, Hellfire, and Immolation Aura have no cooldown and require no Soul Shards to cast. They also no longer apply a damage over time effect.
} )

-- Enhanced Glyphs System for Demonology Warlock
spec:RegisterGlyphs( {
    -- Major Glyphs (affecting DPS and mechanics)
    [56232] = "Glyph of Dark Soul",           -- Your Dark Soul also increases the critical strike damage bonus of your critical strikes by 10%.
    [56249] = "Glyph of Drain Life",          -- When using Drain Life, your Mana regeneration is increased by 10% of spirit.
    [56212] = "Glyph of Fear",                -- Your Fear spell no longer causes the target to run in fear. Instead, the target is disoriented for 8 sec or until they take damage.
    [56238] = "Glyph of Felguard",            -- Your Felguard's Legion Strike now hits all nearby enemies for 10% less damage.
    [56231] = "Glyph of Health Funnel",       -- When using Health Funnel, your demon takes 25% less damage.
    [56242] = "Glyph of Healthstone",         -- Your Healthstone provides 20% additional healing.
    [56226] = "Glyph of Imp Swarm",           -- Your Summon Imp spell now summons 4 Wild Imps. The cooldown of your Summon Imp ability is increased by 20 sec.
    [56248] = "Glyph of Life Tap",            -- Your Life Tap no longer costs health, but now requires mana and has a 2.5 sec cast time.
    [56233] = "Glyph of Nightmares",          -- The cooldown of your Fear spell is reduced by 8 sec, but it no longer deals damage.
    [56243] = "Glyph of Shadow Bolt",         -- Increases the travel speed of your Shadow Bolt by 100%.
    [56218] = "Glyph of Shadowflame",         -- Your Shadowflame also causes enemies to be slowed by 70% for 3 sec.
    [56247] = "Glyph of Soul Consumption",    -- Your Soul Fire now consumes health instead of a Soul Shard, but its damage is increased by 20%.
    [56251] = "Glyph of Corruption",          -- Your Corruption spell deals 20% more damage but no longer applies on target death.
    [56252] = "Glyph of Metamorphosis",       -- Increases the duration of Metamorphosis by 6 sec.
    [56253] = "Glyph of Demon Hunting",       -- Your demon abilities deal 15% more damage to demons.
    [56254] = "Glyph of Soul Link",           -- Soul Link transfers an additional 5% damage taken.
    [56255] = "Glyph of Demonic Circle",      -- Demonic Circle: Teleport can be used while rooted or snared.
    [56256] = "Glyph of Carrion Swarm",       -- Carrion Swarm deals 25% more damage.
    [56257] = "Glyph of Immolation Aura",     -- Immolation Aura reduces enemy movement speed by 50%.
    [56258] = "Glyph of Dark Regeneration",   -- Dark Regeneration cooldown reduced by 30 sec.
    [56259] = "Glyph of Enslave Demon",       -- Enslave Demon no longer breaks on damage dealt to the target.
    [56260] = "Glyph of Demon Training",      -- Your summoned demons gain 20% more health.
    [56261] = "Glyph of Soul Swap",           -- Soul Swap can be used on targets at 100% health.
    [56262] = "Glyph of Howl of Terror",      -- Howl of Terror affects one additional target.
    [56263] = "Glyph of Shadowfury",          -- Shadowfury has 5 yard longer range.
    [56264] = "Glyph of Curse of the Elements", -- Curse of the Elements affects all school vulnerabilities.
    [56265] = "Glyph of Banish",              -- Banish can affect one additional target.
    [56266] = "Glyph of Soulstone",           -- Soulstone can be cast on yourself.
    [56267] = "Glyph of Unending Breath",     -- Unending Breath also removes curse effects.
    [56268] = "Glyph of Ritual of Souls",     -- Ritual of Souls creates 3 additional Soulwells.
    
    -- Minor Glyphs (convenience and visual)
    [57259] = "Glyph of Conflagrate",         -- Your Conflagrate spell creates green flames.
    [56228] = "Glyph of Demonic Circle",      -- Your Demonic Circle is visible to party members.
    [56246] = "Glyph of Eye of Kilrogg",      -- Increases the vision radius of your Eye of Kilrogg by 30 yards.
    [58068] = "Glyph of Falling Meteor",      -- Your Meteor spell creates a larger visual effect.
    [58094] = "Glyph of Felguard",            -- Increases the size of your Felguard by 20%.
    [56244] = "Glyph of Health Funnel",       -- Health Funnel visual effect appears more intense.
    [58079] = "Glyph of Hand of Gul'dan",     -- Hand of Gul'dan creates a larger shadow explosion.
    [58081] = "Glyph of Shadow Bolt",         -- Your Shadow Bolt appears as green fel magic.
    [45785] = "Glyph of Verdant Spheres",     -- Changes the appearance of your Soul Shards to green fel spheres.
    [58093] = "Glyph of Voidwalker",          -- Increases the size of your Voidwalker by 20%.
    [58095] = "Glyph of Imp",                 -- Your Imp appears in different colors.
    [58096] = "Glyph of Succubus",            -- Your Succubus appears in different outfits.
    [58097] = "Glyph of Felhunter",           -- Your Felhunter appears more intimidating.
    [58098] = "Glyph of Demon Form",          -- Your Metamorphosis form appears different.
    [58099] = "Glyph of Ritual of Summoning", -- Ritual of Summoning circle appears larger.
} )

-- Enhanced Aura System for Demonology Warlock (40+ auras)
spec:RegisterAuras( {
    -- Demonology Signature Auras
    corruption = {
        id = 172,
        duration = 18,
        tick_time = 3,
        type = "Magic",
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 172 )
            
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
        end
    },
    
    doom = {
        id = 603,
        duration = 60,
        tick_time = 15,
        type = "Magic",
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 603 )
            
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
        end
    },
    
    hand_of_guldan = {
        id = 86040,
        duration = 6,
        tick_time = 2,
        type = "Magic",
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 86040 )
            
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
        end
    },
    
    immolation_aura = {
        id = 104025,
        duration = 6,
        tick_time = 1,
        type = "Magic",
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 104025 )
            
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
        end
    },
    
    metamorphosis = {
        id = 103958,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 103958 )
            
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
        end
    },
    
    molten_core = {
        id = 122355,
        duration = 15,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 122355 )
            
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
        end
    },
    
    dark_soul = {
        id = 113858,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 113858 )
            
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
        end
    },
    
    -- Talent Auras
    soul_leech = {
        id = 108370,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 108370 )
            
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
        end
    },
    
    harvest_life = {
        id = 108371,
        duration = 8,
        tick_time = 1,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 108371 )
            
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
        end
    },
    
    burning_rush = {
        id = 111400,
        duration = 3600,
        tick_time = 1,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 111400 )
            
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
        end
    },
    
    -- Grimoire Auras
    grimoire_of_supremacy = {
        id = 108499,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 108499 )
            
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
        end
    },
    
    grimoire_of_service = {
        id = 108501,
        duration = 25,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 108501 )
            
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
        end
    },
    
    grimoire_of_sacrifice = {
        id = 108503,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 108503 )
            
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
        end
    },
    hellfire = {
        id = 1949,
        duration = 16,
        tick_time = 1,
        max_stack = 1,
    },
    shadowflame = {
        id = 47960,
        duration = 8,
        tick_time = 2,
        max_stack = 1,
    },
    bane_of_doom = {
        id = 603,
        duration = 60,
        tick_time = 15,
        max_stack = 1,
    },
    bane_of_agony = {
        id = 980,
        duration = 24,
        max_stack = 10,
    },
      -- Metamorphosis and related
    metamorphosis = {
        id = 103958,
        duration = 30, -- Maximum duration, but limited by Demonic Fury
        max_stack = 1,
        tick_time = 1, -- Drains Demonic Fury every second
        
        meta = {
            -- In MoP, Metamorphosis drains 40 Demonic Fury per second
            tick = function()
                if demonic_fury.current >= 40 then
                    spend(40, "demonic_fury")
                else
                    -- Not enough Demonic Fury, end Metamorphosis
                    removeBuff("metamorphosis")
                end
            end,
        },
    },
    dark_apotheosis = {
        id = 114168,
        duration = 3600,
        max_stack = 1,
    },
    molten_core = {
        id = 122355,
        duration = 15,
        max_stack = 5,
    },
    
    -- Procs and Talents
    dark_soul_knowledge = {
        id = 113861,
        duration = 20,
        max_stack = 1,
    },
    demonic_rebirth = {
        id = 89140,
        duration = 15,
        max_stack = 1,
    },
    demonic_calling = {
        id = 119904,
        duration = 20,
        max_stack = 1,
    },
    
    -- Wild Imps
    wild_imps = {
        duration = 20,
        max_stack = 4,
    },
    
    -- Defensives
    dark_bargain = {
        id = 110913,
        duration = 8,
        max_stack = 1,
    },
    soul_link = {
        id = 108415,
        duration = 3600,
        max_stack = 1,
    },
    unbound_will = {
        id = 108482,
        duration = 6,
        max_stack = 1,
    },
    
    -- Pet-related
    grimoire_of_sacrifice = {
        id = 108503,
        duration = 15,
        max_stack = 1,
    },
    
    -- Utility
    dark_regeneration = {
        id = 108359,
        duration = 12,
        tick_time = 3,
        max_stack = 1,
    },
    unending_breath = {
        id = 5697,
        duration = 600,
        max_stack = 1,
    },
    unending_resolve = {
        id = 104773,
        duration = 8,
        max_stack = 1,
    },
    demonic_circle = {
        id = 48018,
        duration = 900,
        max_stack = 1,
    },
    demonic_gateway = {
        id = 113900,
        duration = 15,
        max_stack = 1,
    },
} )

-- Demonology Warlock abilities
spec:RegisterAbilities( {
    -- Core Rotational Abilities
    shadow_bolt = {
        id = 686,
        cast = function() return 2.5 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.075,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136197,
        
        handler = function()
            -- Generate Demonic Fury
            gain( 25, "demonic_fury" )
            
            -- Chance to proc Molten Core
            if math.random() < 0.1 then -- 10% chance
                if buff.molten_core.stack < 5 then
                    addStack( "molten_core" )
                end
            end
        end,
    },
    
    touch_of_chaos = {
        id = 103964,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 30,
        spendType = "demonic_fury",
        
        startsCombat = true,
        texture = 615099,
        
        usable = function()
            return buff.metamorphosis.up, "requires metamorphosis"
        end,
        
        handler = function()
            -- Replaces Shadow Bolt in Meta form
        end,
    },
    
    corruption = {
        id = 172,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136118,
        
        handler = function()
            applyDebuff( "target", "corruption" )
            -- Generate Demonic Fury
            gain( 6, "demonic_fury" )
        end,
    },
    
    doom = {
        id = 603,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 10,
        spendType = "demonic_fury",
        
        startsCombat = true,
        texture = 136122,
        
        usable = function()
            return buff.metamorphosis.up, "requires metamorphosis"
        end,
        
        handler = function()
            applyDebuff( "target", "doom" )
        end,
    },
    
    hand_of_guldan = {
        id = 105174,
        cast = function() return 1.5 * haste end,
        cooldown = 15,
        gcd = "spell",
        
        spend = 0.01,
        spendType = "mana",
        
        startsCombat = true,
        texture = 537432,
        
        handler = function()
            applyDebuff( "target", "hand_of_guldan" )
            -- Generate Demonic Fury
            gain( 5 * 3, "demonic_fury" ) -- 5 per target hit, assuming 3 targets
            
            -- Summon Wild Imps
            if not buff.wild_imps.up then
                applyBuff( "wild_imps" )
                buff.wild_imps.stack = 1
            else
                addStack( "wild_imps", nil, 1 )
            end
        end,
    },
    
    soul_fire = {
        id = 6353,
        cast = function() 
            if buff.molten_core.up then return 0 end
            return 4 * haste 
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.08,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135808,
        
        handler = function()
            -- Generate Demonic Fury
            gain( 30, "demonic_fury" )
            
            -- Consume Molten Core if active
            if buff.molten_core.up then
                if buff.molten_core.stack > 1 then
                    removeStack( "molten_core" )
                else
                    removeBuff( "molten_core" )
                end
            end
        end,
    },
    
    fel_flame = {
        id = 77799,
        cast = 0,
        cooldown = 1.5,
        gcd = "spell",
        
        spend = 0.07,
        spendType = "mana",
        
        startsCombat = true,
        texture = 132402,
        
        handler = function()
            -- Generate Demonic Fury
            gain( 10, "demonic_fury" )
        end,
    },
    
    life_tap = {
        id = 1454,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 136126,
        
        handler = function()
            -- Costs 15% health, returns 15% mana
            local health_cost = health.max * 0.15
            local mana_return = mana.max * 0.15
            
            spend( health_cost, "health" )
            gain( mana_return, "mana" )
        end,
    },
    
    curse_of_the_elements = {
        id = 1490,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.01,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136130,
        
        handler = function()
            -- Apply debuff
        end,
    },
      -- Metamorphosis
    metamorphosis = {
        id = 103958,
        cast = 0,
        cooldown = 0, -- No cooldown in MoP
        gcd = "spell",
        
        spend = 400, -- Requires minimum 400 Demonic Fury to activate
        spendType = "demonic_fury",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 530482,
        
        usable = function()
            return not buff.metamorphosis.up and demonic_fury.current >= 400, "requires at least 400 demonic fury and not already in metamorphosis"
        end,
        
        handler = function()
            applyBuff( "metamorphosis" )
            -- In MoP, Metamorphosis drains 40 Demonic Fury per second while active
            -- This will be handled by the buff's tick mechanics
        end,
    },
    
    cancel_metamorphosis = {
        id = 103958,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        startsCombat = false,
        texture = 530482,
        
        usable = function()
            return buff.metamorphosis.up, "requires metamorphosis active"
        end,
        
        handler = function()
            removeBuff( "metamorphosis" )
        end,
    },
    
    immolation_aura = {
        id = 104025,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 50,
        spendType = "demonic_fury",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 135817,
        
        usable = function()
            return buff.metamorphosis.up, "requires metamorphosis"
        end,
        
        handler = function()
            applyBuff( "immolation_aura" )
        end,
    },
    
    void_ray = {
        id = 115422,
        cast = function() return 3 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        channeled = true,
        
        spend = 24,
        spendType = "demonic_fury",
        
        startsCombat = true,
        texture = 530707,
        
        usable = function()
            return buff.metamorphosis.up, "requires metamorphosis"
        end,
        
        handler = function()
            -- Meta channeled spell
        end,
    },
    
    dark_apotheosis = {
        id = 114168,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 473510,
        
        toggle = "defensives",
        
        handler = function()
            applyBuff( "dark_apotheosis" )
        end,
    },
    
    hellfire = {
        id = 1949,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        channeled = true,
        
        spend = 0.64,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135818,
        
        handler = function()
            applyBuff( "hellfire" )
            
            -- Generate Demonic Fury per tick
            -- Assuming 4 ticks over 4 seconds (1 per second)
            for i = 1, 4 do
                gain( 10, "demonic_fury" )
            end
        end,
    },
    
    -- Cooldowns
    dark_soul = {
        id = 113861,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 538042,
        
        handler = function()
            applyBuff( "dark_soul_knowledge" )
        end,
    },
    
    summon_felguard = {
        id = 30146,
        cast = 6,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136216,
        
        handler = function()
            -- Summon pet
        end,
    },
    
    command_demon = {
        id = 119898,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 134400,
        
        handler = function()
            -- Command current demon based on demon type
        end,
    },
    
    summon_doomguard = {
        id = 18540,
        cast = 0,
        cooldown = 600,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = false,
        texture = 603013,
        
        handler = function()
            -- Summon Doomguard for 1 minute
        end,
    },
    
    summon_infernal = {
        id = 1122,
        cast = 0,
        cooldown = 600,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136219,
        
        handler = function()
            -- Summon Infernal for 1 minute
        end,
    },
    
    -- Defensive and Utility
    dark_bargain = {
        id = 110913,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 538038,
        
        handler = function()
            applyBuff( "dark_bargain" )
        end,
    },
    
    unending_resolve = {
        id = 104773,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 136150,
        
        handler = function()
            applyBuff( "unending_resolve" )
        end,
    },
    
    demonic_circle_summon = {
        id = 48018,
        cast = 0.5,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 136126,
        
        handler = function()
            applyBuff( "demonic_circle" )
        end,
    },
    
    demonic_circle_teleport = {
        id = 48020,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 607512,
        
        handler = function()
            -- Teleport to circle
        end,
    },
    
    -- Talent abilities
    howl_of_terror = {
        id = 5484,
        cast = 0,
        cooldown = 40,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = true,
        texture = 607510,
        
        handler = function()
            -- Fear all enemies in 10 yards
        end,
    },
    
    mortal_coil = {
        id = 6789,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
        texture = 607514,
        
        handler = function()
            -- Fear target and heal 11% of max health
            local heal_amount = health.max * 0.11
            gain( heal_amount, "health" )
        end,
    },
    
    shadowfury = {
        id = 30283,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
        texture = 457223,
        
        handler = function()
            -- Stun all enemies in 8 yards
        end,
    },
    
    grimoire_of_sacrifice = {
        id = 108503,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 538443,
        
        handler = function()
            applyBuff( "grimoire_of_sacrifice" )
        end,
    },
} )

-- State Expressions for Demonology
spec:RegisterStateExpr( "demonic_fury", function()
    return demonic_fury.current
end )

-- Range
spec:RegisterRanges( "shadow_bolt", "corruption", "hand_of_guldan" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    gcd = 1645,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "jade_serpent",
    
    package = "Demonology",
} )

-- Default pack for MoP Demonology Warlock
spec:RegisterPack( "Demonology", 20250515, [[Hekili:T3vBVTTn04FldjHr9LSgR2e75XVc1cbKzKRlvnTo01OEckA2IgxVSbP5cFcqifitljsBPIYPKQbbXQPaX0YCRwRNFAxBtwR37pZUWZB3SZ0Zbnu(ndREWP)8dyNF3BhER85x(jym5nymTYnv0drHbpz5IW1vZgbo1P)MM]] )

-- Register pack selector for Demonology
spec:RegisterPackSelector( "demonology", "Demonology", "|T136172:0|t Demonology",
    "Handles all aspects of Demonology Warlock DPS with focus on Metamorphosis and demonic summons.",
    nil )

-- Tier Set Bonus Auras (Enhanced)
spec:RegisterAuras( {
    tier14_2pc_demo = {
        id = 105770,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 105770 )
            
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
        end
    },
    
    tier14_4pc_demo = {
        id = 105788,
        duration = 30,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 105788 )
            
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
        end
    },
    
    tier15_2pc_demo = {
        id = 138483,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 138483 )
            
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
        end
    },
    
    tier15_4pc_demo = {
        id = 138486,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 138486 )
            
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
        end
    },
    
    tier16_2pc_demo = {
        id = 144583,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 144583 )
            
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
        end
    },
    
    tier16_4pc_demo = {
        id = 144584,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 144584 )
            
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
        end
    },
    
    -- Legendary and Trinket Auras
    legendary_cloak_proc = {
        id = 148008,
        duration = 4,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 148008 )
            
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
        end
    },
    
    -- Pet Auras
    felguard_pursuit = {
        id = 30153,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPetBuffByID( 30153 )
            
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
        end
    },
    
    -- Defensive Auras
    dark_bargain = {
        id = 110913,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 110913 )
            
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
        end
    },
    
    unbound_will = {
        id = 108482,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = UA_GetPlayerAuraBySpellID( 108482 )
            
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
        end
    },
    
    -- Crowd Control Auras
    fear = {
        id = 5782,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 5782 )
            
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
        end
    },
    
    shadowfury = {
        id = 30283,
        duration = 3,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 30283 )
            
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
        end
    },
    
    -- Additional DoT Auras
    agony = {
        id = 980,
        duration = 24,
        tick_time = 2,
        max_stack = 10,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 980 )
            
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
        end
    },
    
    unstable_affliction = {
        id = 30108,
        duration = 14,
        tick_time = 2,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 30108 )
            
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
        end
    },
} )
