-- MonkBrewmaster.lua
-- Updated May 30, 2025 - Modern Structure with Advanced Patterns
-- Mists of Pandaria module for Monk: Brewmaster spec
-- Enhanced implementation with comprehensive MoP Brewmaster tanking mechanics

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'MONK' then return end

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

local spec = Hekili:NewSpecialization( 268 ) -- Brewmaster spec ID for MoP

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

-- Elusive Brew stack gain tracking
RegisterBMCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if destGUID == UnitGUID("player") and spellID == 128938 then -- Elusive Brew Stack
        -- Track Elusive Brew stack accumulation
    end
end)

-- Stagger damage absorption tracking
RegisterBMCombatLogEvent("SPELL_ABSORB", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, amount)
    if destGUID == UnitGUID("player") and (spellID == 124273 or spellID == 124274 or spellID == 124275) then -- Stagger
        -- Track stagger absorption amounts for optimization
    end
end)

-- Chi generation from Tiger Palm tracking
RegisterBMCombatLogEvent("SPELL_CAST_SUCCESS", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if sourceGUID == UnitGUID("player") then
        if spellID == 100787 then -- Tiger Palm
            -- Track Tiger Palm for Power Strikes and Chi generation
        elseif spellID == 115180 then -- Dizzying Haze
            -- Track Dizzying Haze for threat generation
        elseif spellID == 115308 then -- Elusive Brew activation
            -- Track Elusive Brew usage
        end
    end
end)

-- Purifying Brew cleanse tracking
RegisterBMCombatLogEvent("SPELL_DISPEL", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, extraSpellID)
    if sourceGUID == UnitGUID("player") and spellID == 119582 then -- Purifying Brew
        -- Track stagger cleansing for optimal Purifying Brew usage
    end
end)

-- Enhanced Energy resource system for Brewmaster
spec:RegisterResource( 3, { -- Energy = 3 in MoP
    -- Tiger Palm energy generation
    tiger_palm = {
        aura = "tiger_palm_energy",
        last = function ()
            local app = state.buff.tiger_palm_energy.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1.5 ) * 1.5
        end,
        interval = 1.5,
        value = function()
            local energy = 25
            if state.talent.ascension.enabled then energy = energy * 1.15 end
            if state.buff.power_strikes.up then energy = energy + 15 end
            return energy
        end,
    },
    
    -- Jab energy generation
    jab = {
        aura = "jab_energy",
        last = function ()
            local app = state.buff.jab_energy.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 2.0 ) * 2.0
        end,
        interval = 2.0,
        value = function()
            local energy = 20
            if state.talent.ascension.enabled then energy = energy * 1.15 end
            return energy
        end,
    },
    
    -- Ascension passive energy bonus
    ascension = {
        aura = "ascension",
        last = function ()
            local app = state.buff.ascension.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.talent.ascension.enabled and 2 or 0
        end,
    },
    
    -- Energizing Brew energy regeneration
    energizing_brew = {
        aura = "energizing_brew",
        last = function ()
            local app = state.buff.energizing_brew.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1.5 ) * 1.5
        end,
        interval = 1.5,
        value = 20,
    },
    
    -- Tiger's Lust energy burst
    tigers_lust = {
        aura = "tigers_lust",
        last = function ()
            local app = state.buff.tigers_lust.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 3 ) * 3
        end,
        interval = 3,
        value = 15,
    },
}, {
    base_regen = function ()
        local base = 10
        if state.talent.ascension.enabled then
            base = base * 1.15
        end
        if state.buff.power_strikes.up then
            base = base + 2
        end
        return base
    end,
} )

-- Enhanced Chi resource system for Brewmaster
spec:RegisterResource( 12, { -- Chi = 12 in MoP
    -- Power Strikes Chi generation
    power_strikes = {
        aura = "power_strikes",
        last = function ()
            local app = state.buff.power_strikes.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 20 ) * 20
        end,
        interval = 20,
        value = function()
            return state.talent.power_strikes.enabled and 1 or 0
        end,
    },
    
    -- Chi Brew instant restoration
    chi_brew = {
        aura = "chi_brew",
        last = function ()
            local app = state.buff.chi_brew.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.cooldown.chi_brew.remains == 0 and 2 or 0
        end,
    },
    
    -- Focus and Harmony Chi from critical strikes
    focus_and_harmony = {
        aura = "focus_and_harmony",
        last = function ()
            local app = state.buff.focus_and_harmony.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 6 ) * 6
        end,
        interval = 6,
        value = function()
            return state.spec.brewmaster and 1 or 0
        end,
    },
}, {
    max = function ()
        local base = 4
        if state.talent.ascension.enabled then
            base = base + 1
        end
        return base
    end,
} )

-- Enhanced Mana resource system for Brewmaster utility spells
spec:RegisterResource( 0, { -- Mana = 0 in MoP
    -- Mana Tea restoration
    mana_tea = {
        aura = "mana_tea",
        last = function ()
            local app = state.buff.mana_tea.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.buff.mana_tea.stack * 4000
        end,
    },
    
    -- Meditation passive mana regeneration
    meditation = {
        aura = "meditation",
        last = function ()
            local app = state.buff.meditation.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 2 ) * 2
        end,
        interval = 2,
        value = function()
            local spirit = state.stat.spirit or 0
            return spirit * 0.5
        end,
    },
}, {
    base_regen = function ()
        return state.stat.spirit and ( state.stat.spirit * 0.5 ) or 0
    end,
} )

-- Comprehensive Tier Sets for MoP Brewmaster Monk
-- T14 - Yaungol Slayer's Battlegear (Monk Tank Set)
spec:RegisterGear( "tier14", 85394, 85395, 85396, 85397, 85398 ) -- LFR
spec:RegisterGear( "tier14_normal", 85399, 85400, 85401, 85402, 85403 ) -- Normal
spec:RegisterGear( "tier14_heroic", 85404, 85405, 85406, 85407, 85408 ) -- Heroic

-- T15 - Battlegear of the Lightning Emperor (Monk Tank Set)
spec:RegisterGear( "tier15", 95832, 95833, 95834, 95835, 95836 ) -- LFR
spec:RegisterGear( "tier15_normal", 95837, 95838, 95839, 95840, 95841 ) -- Normal
spec:RegisterGear( "tier15_heroic", 95842, 95843, 95844, 95845, 95846 ) -- Heroic
spec:RegisterGear( "tier15_thunderforged", 95847, 95848, 95849, 95850, 95851 ) -- Thunderforged

-- T16 - Battlegear of the Shattered Vale (Monk Tank Set)
spec:RegisterGear( "tier16", 98971, 98972, 98973, 98974, 98975 ) -- LFR
spec:RegisterGear( "tier16_normal", 98976, 98977, 98978, 98979, 98980 ) -- Normal
spec:RegisterGear( "tier16_heroic", 98981, 98982, 98983, 98984, 98985 ) -- Heroic
spec:RegisterGear( "tier16_mythic", 98986, 98987, 98988, 98989, 98990 ) -- Mythic

-- Legendary Items for MoP
spec:RegisterGear( "legendary_cloak", 102246 ) -- Qian-Ying, Fortitude of Niuzao
spec:RegisterGear( "legendary_cloak_agi", 102247 ) -- Qian-Le, Courage of Niuzao

-- Notable Trinkets and Proc Items
spec:RegisterGear( "haromms_talisman", 104780 ) -- Haromm's Talisman
spec:RegisterGear( "thoks_tail_tip", 104605 ) -- Thok's Tail Tip
spec:RegisterGear( "blood_of_the_old_god", 104814 ) -- Blood of the Old God
spec:RegisterGear( "vial_of_living_corruption", 104816 ) -- Vial of Living Corruption

-- Meta Gems for MoP
spec:RegisterGear( "indomitable_primal", 76890 ) -- Indomitable Primal Diamond
spec:RegisterGear( "austere_primal", 76885 ) -- Austere Primal Diamond

-- PvP Sets
spec:RegisterGear( "malevolent", 85301, 85302, 85303, 85304, 85305 ) -- Malevolent Gladiator's Ironskin
spec:RegisterGear( "tyrannical", 95801, 95802, 95803, 95804, 95805 ) -- Tyrannical Gladiator's Ironskin
spec:RegisterGear( "grievous", 98941, 98942, 98943, 98944, 98945 ) -- Grievous Gladiator's Ironskin

-- Challenge Mode Sets
spec:RegisterGear( "challenge_mode", 88431, 88432, 88433, 88434, 88435 ) -- Challenge Mode Monk Transmog

-- Tier Set Bonuses
spec:RegisterAura( "tier14_2pc_tank", {
    id = 123456, -- Placeholder for 2pc bonus
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "tier14_4pc_tank", {
    id = 123457, -- Placeholder for 4pc bonus
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "tier15_2pc_tank", {
    id = 138229, -- Lightning Emperor 2pc: Shuffle duration increased
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "tier15_4pc_tank", {
    id = 138230, -- Lightning Emperor 4pc: Elusive Brew additional charges
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "tier16_2pc_tank", {
    id = 146987, -- Shattered Vale 2pc: Guard absorb increase
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "tier16_4pc_tank", {
    id = 146988, -- Shattered Vale 4pc: Keg Smash buff
    duration = 3600,
    max_stack = 1,
} )

-- Talents (MoP 6-tier talent system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility
    celerity                  = { 2645, 1, 115173 }, -- Reduces Roll cooldown by 5 sec, adds 1 charge
    tigers_lust               = { 2646, 1, 116841 }, -- Increases ally movement speed by 70% for 6 sec
    momentum                  = { 2647, 1, 115294 }, -- Rolling increases movement speed by 25% for 10 sec
    
    -- Tier 2 (Level 30) - Healing  
    chi_wave                  = { 2648, 1, 115098 }, -- Chi energy bounces between friends and foes
    zen_sphere                = { 2649, 1, 124081 }, -- Healing sphere around target, explodes on expire
    chi_burst                 = { 2650, 1, 123986 }, -- Chi torrent damages enemies, heals allies
    
    -- Tier 3 (Level 45) - Resource
    power_strikes             = { 2651, 1, 121817 }, -- Every 20 sec, Tiger Palm grants 1 additional Chi
    ascension                 = { 2652, 1, 115396 }, -- +1 max Chi, +15% Energy regeneration
    chi_brew                  = { 2653, 1, 115399 }, -- Restores 2 Chi, 45 sec cooldown
    
    -- Tier 4 (Level 60) - Control
    deadly_reach              = { 2654, 1, 126679 }, -- Increases Paralysis range by 10 yds
    charging_ox_wave          = { 2655, 1, 119392 }, -- Ox wave stuns enemies for 3 sec
    leg_sweep                 = { 2656, 1, 119381 }, -- Stuns nearby enemies for 5 sec
    
    -- Tier 5 (Level 75) - Defense
    healing_elixirs           = { 2657, 1, 122280 }, -- Potions heal for +10% max health
    dampen_harm               = { 2658, 1, 122278 }, -- Reduces next 3 large attacks by 50%
    diffuse_magic             = { 2659, 1, 122783 }, -- Transfers debuffs, 90% magic damage reduction
    
    -- Tier 6 (Level 90) - Ultimate    rushing_jade_wind         = { 2660, 1, 116847 }, -- Whirling tornado damages nearby enemies
    invoke_xuen               = { 2661, 1, 123904 }, -- Summons White Tiger Xuen for 45 sec
    chi_torpedo               = { 2662, 1, 119085 }  -- Torpedo forward, +30% movement speed
} )

-- Comprehensive Glyph System for MoP Brewmaster Monk
spec:RegisterGlyphs( {
    -- Major Glyphs for Brewmaster
    [125731] = "afterlife", -- Glyph of Afterlife: Spirit of deceased party members aid you
    [125872] = "blackout_kick", -- Glyph of Blackout Kick: Reduces cooldown by 2 sec, reduces damage by 20%
    [125671] = "breath_of_fire", -- Glyph of Breath of Fire: Reduces Breath of Fire cooldown by 3 sec
    [125732] = "detox", -- Glyph of Detox: Detox heals the target when removing effects
    [125757] = "enduring_healing_sphere", -- Glyph of Enduring Healing Sphere: Healing Spheres last 60 sec longer
    [125672] = "expel_harm", -- Glyph of Expel Harm: Increases range to 20 yards
    [125676] = "fighting_pose", -- Glyph of Fighting Pose: Reduces movement penalty while channeling Soothing Mist
    [125687] = "fortifying_brew", -- Glyph of Fortifying Brew: Increases duration by 5 sec, reduces effectiveness
    [125677] = "guard", -- Glyph of Guard: Increases Guard's absorb by 10%, reduces healing bonus
    [123763] = "mana_tea", -- Glyph of Mana Tea: Reduces mana cost of spells during channel by 50%
    [125767] = "paralysis", -- Glyph of Paralysis: Reduces damage required to break Paralysis by 50%
    [125755] = "retreat", -- Glyph of Retreat: Increases retreat distance and removes movement slowing effects
    [125678] = "spinning_crane_kick", -- Glyph of Spinning Crane Kick: Reduces energy cost by 5 for each unique target hit
    [125750] = "surging_mist", -- Glyph of Surging Mist: Reduces healing but increases movement speed
    [125932] = "targeted_expulsion", -- Glyph of Targeted Expulsion: Expel Harm now affects targeted ally
    [125679] = "touch_of_death", -- Glyph of Touch of Death: Reduces health requirement to 25% for non-player targets
    [125680] = "transcendence", -- Glyph of Transcendence: Increases range to 40 yards
    [125681] = "zen_meditation", -- Glyph of Zen Meditation: Increases damage reduction but prevents movement
    
    -- Additional Brewmaster-specific Major Glyphs
    [125682] = "keg_smash", -- Glyph of Keg Smash: Increases Keg Smash radius by 2 yards
    [125683] = "purifying_brew", -- Glyph of Purifying Brew: Reduces cooldown by 3 sec, reduces clear amount
    [125684] = "clash", -- Glyph of Clash: Reduces cooldown by 10 sec, reduces disable duration
    [125685] = "elusive_brew", -- Glyph of Elusive Brew: Increases maximum stacks by 5
    [125686] = "dizzying_haze", -- Glyph of Dizzying Haze: Increases range by 5 yards
    [125688] = "leer_of_the_ox", -- Glyph of Leer of the Ox: Reduces cooldown by 30 sec
    [125689] = "spear_hand_strike", -- Glyph of Spear Hand Strike: Reduces cooldown by 5 sec for successful interrupts
    [125690] = "nimble_brew", -- Glyph of Nimble Brew: Reduces cooldown by 30 sec
    [125691] = "stoneskin", -- Glyph of Stoneskin: Reduces magic damage taken by 10% while Fortifying Brew is active
    [125692] = "shuffle", -- Glyph of Shuffle: Increases Shuffle duration by 2 sec
    [125693] = "healing_sphere", -- Glyph of Healing Sphere: Increases movement speed near Healing Spheres
    [125694] = "spinning_fire_blossom", -- Glyph of Spinning Fire Blossom: Increases range and reduces cast time
    [125695] = "tigers_lust", -- Glyph of Tiger's Lust: Removes movement impairing effects from the target
    [125696] = "wind_through_the_reeds", -- Glyph of Wind Through the Reeds: Chi Wave bounces 2 additional times
    
    -- Minor Glyphs for Brewmaster
    [125697] = "crackling_jade_lightning", -- Glyph of Crackling Jade Lightning: Causes lightning to be verdant green
    [125698] = "honor", -- Glyph of Honor: Bow respectfully when targeting fellow monks
    [125699] = "spirit_roll", -- Glyph of Spirit Roll: Roll leaves a spirit behind for 20 sec
    [125700] = "zen_flight", -- Glyph of Zen Flight: Flight form has a trailing cloud effect
    [125701] = "water_roll", -- Glyph of Water Roll: Roll on water surface for brief period
    [125702] = "jab", -- Glyph of Jab: Jab has a chance to generate a small healing sphere
    [125703] = "blackout_kick_visual", -- Glyph of Blackout Kick: Changes visual effect to appear more shadowy
    [125704] = "spinning_crane_kick_visual", -- Glyph of Spinning Crane Kick: Changes visual to golden crane
    [125705] = "breath_of_fire_visual", -- Glyph of Breath of Fire: Changes color to blue flame
    [125706] = "tiger_palm", -- Glyph of Tiger Palm: Tiger Palm triggers a brief afterimage
    [125707] = "ox_statue", -- Glyph of the Ox Statue: Statue appears as a jade ox
    [125708] = "rising_sun_kick", -- Glyph of Rising Sun Kick: Kick produces a sun-like visual effect
    [125709] = "touch_of_karma", -- Glyph of Touch of Karma: Visual effect shows karmic balance
    [125710] = "fortifying_brew_visual", -- Glyph of Fortifying Brew: Character glows with earthen power
    [125711] = "guard_visual", -- Glyph of Guard: Shield effect has ox motifs
    [125712] = "transcendence_visual", -- Glyph of Transcendence: Spirit form appears more translucent
} )

-- Statuses for Brewmaster predictions
spec:RegisterStateTable( "stagger", setmetatable({}, {
    __index = function( t, k )
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
}))

-- Enhanced Aura System with Advanced Generate Functions for Brewmaster
spec:RegisterAuras( {
    -- === Core Brewmaster Tanking Mechanics ===
    
    -- Stagger damage taken and amplify staggering
    moderate_stagger = {
        id = 124274,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 124274 )
            
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

    heavy_stagger = {
        id = 124273,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 124273 )
            
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

    light_stagger = {
        id = 124275,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 124275 )
            
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

    -- Elusive Brew: Increases dodge chance based on stacks
    elusive_brew = {
        id = 128939,
        duration = function() return buff.elusive_brew.stack * 1 end, -- 1 second per stack
        max_stack = 15,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 128939 )
            
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

    -- Elusive Brew: Stacks gained from critical strikes
    elusive_brew_stack = {
        id = 128938,
        duration = 60,
        max_stack = 15,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 128938 )
            
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

    -- Guard: Absorbs damage
    guard = {
        id = 115295,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115295 )
            
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

    -- Shuffle: Increases Stagger amount and parry chance
    shuffle = {
        id = 115307,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115307 )
            
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

    -- === Brewmaster Combat Abilities ===

    -- Breath of Fire: Disorients enemies
    breath_of_fire = {
        id = 123725,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 123725, "PLAYER" )
            
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

    -- Keg Smash: Reduces enemy movement speed and attack speed
    keg_smash = {
        id = 121253,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 121253, "PLAYER" )
            
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

    -- Dizzying Haze: Reduces enemy movement speed
    dizzying_haze = {
        id = 115180,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 115180, "PLAYER" )
            
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

    -- === Defensive Cooldowns ===

    -- Fortifying Brew: Reduces damage taken and increases health
    fortifying_brew = {
        id = 120954,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 120954 )
            
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

    -- Zen Meditation: Reduces damage taken, immobilized
    zen_meditation = {
        id = 115176,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115176 )
            
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

    -- === Talent-Based Auras ===

    -- Power Strikes: Next Tiger Palm generates additional Chi
    power_strikes = {
        id = 129914,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 129914 )
            
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

    -- Ascension: Passive Chi and Energy bonus
    ascension = {
        id = 115396,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
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
        end
    },

    -- Dampen Harm: Reduces damage from large attacks
    dampen_harm = {
        id = 122278,
        duration = 45,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 122278 )
            
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

    -- Diffuse Magic: Reduces magic damage
    diffuse_magic = {
        id = 122783,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 122783 )
            
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

    -- === Movement and Utility ===

    -- Tiger's Lust: Increases movement speed
    tigers_lust = {
        id = 116841,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 116841 )
            
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

    -- Momentum: Movement speed after Roll
    momentum = {
        id = 119085,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 119085 )
            
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

    -- Chi Torpedo: Enhanced movement
    chi_torpedo = {
        id = 119085,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 119085 )
            
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

    -- === Ultimate Abilities ===

    -- Rushing Jade Wind: Whirling wind around the monk
    rushing_jade_wind = {
        id = 116847,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 116847 )
            
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

    -- Invoke Xuen: White Tiger companion
    invoke_xuen = {
        id = 123904,
        duration = 45,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 123904 )
            
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

    -- === Resource Management ===

    -- Mana Tea: Stacks for mana restoration
    mana_tea = {
        id = 115294,
        duration = 3600,
        max_stack = 20,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115294 )
            
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

    -- Energizing Brew: Energy regeneration
    energizing_brew = {
        id = 115288,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115288 )
            
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

    -- === Tier Set Bonuses ===

    -- Tier 15 2pc: Shuffle duration increase
    tier15_2pc_tank = {
        id = 138229,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
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
        end
    },

    -- Tier 15 4pc: Elusive Brew bonus
    tier15_4pc_tank = {
        id = 138230,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
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
        end
    },

    -- Tier 16 2pc: Guard absorb increase
    tier16_2pc_tank = {
        id = 146987,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
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
        end
    },

    -- Tier 16 4pc: Keg Smash buff
    tier16_4pc_tank = {
        id = 146988,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
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
        end
    },

    -- === Helper Auras for Resource Tracking ===

    -- Tiger Palm energy tracking
    tiger_palm_energy = {
        id = 999001,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            t.name = "Tiger Palm Energy"
            t.count = 1
            t.expires = state.query_time + 3600
            t.applied = state.query_time
            t.caster = "player"
        end
    },

    -- Jab energy tracking
    jab_energy = {
        id = 999002,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            t.name = "Jab Energy"
            t.count = 1
            t.expires = state.query_time + 3600
            t.applied = state.query_time
            t.caster = "player"
        end
    },

    -- Chi Brew tracking
    chi_brew = {
        id = 999003,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            t.name = "Chi Brew"
            t.count = 1
            t.expires = state.query_time + 3600
            t.applied = state.query_time
            t.caster = "player"
        end
    },

    -- Focus and Harmony Chi tracking
    focus_and_harmony = {
        id = 999004,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            t.name = "Focus and Harmony"
            t.count = 1
            t.expires = state.query_time + 3600
            t.applied = state.query_time
            t.caster = "player"
        end
    },

    -- Meditation mana tracking
    meditation = {
        id = 999005,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            t.name = "Meditation"
            t.count = 1
            t.expires = state.query_time + 3600
            t.applied = state.query_time
            t.caster = "player"
        end
    },
    -- Dizzying Haze: Slows and forces enemies to attack you
    dizzying_haze = {
        id = 115180,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 115180, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count
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
    -- Fortifying Brew: Increases stamina and reduces damage taken
    fortifying_brew = {
        id = 120954,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 120954 )
            
            if name then
                t.name = name
                t.count = count
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
    -- Zen Meditation: Reduces damage taken
    zen_meditation = {
        id = 115176,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115176 )
            
            if name then
                t.name = name
                t.count = count
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
    -- Mastery: Elusive Brawler
    -- Increases your chance to dodge by 15%.
    elusive_brawler = {
        id = 117967,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 117967 )
            
            if name then
                t.name = name
                t.count = count
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
    -- Tiger Power (Stance buff)
    tiger_power = {
        id = 125359,
        duration = 30,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 125359 )
            
            if name then
                t.name = name
                t.count = count
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
    -- Power Guard (reduces damage taken)
    power_guard = {
        id = 118636,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 118636 )
            
            if name then
                t.name = name
                t.count = count
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
    -- Weakened Blows (caused by Keg Smash)
    weakened_blows = {
        id = 115798,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 115798, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count
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

-- Monk shared abilities and Brewmaster abilities
spec:RegisterAbilities( {
    -- Core Brewmaster Abilities
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
        
        usable = function() return buff.elusive_brew_stack.stack > 0 end,
        
        handler = function()
            -- Convert elusive_brew_stack to elusive_brew buff
            local stacks = buff.elusive_brew_stack.stack
            if stacks > 0 then
                removeBuff("elusive_brew_stack")
                -- Each stack gives 1% dodge for 15 seconds, max 15%
                local dodge_duration = min(stacks * 15, 225) -- Max 15 stacks * 15 seconds
                applyBuff("elusive_brew", dodge_duration)
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
        
        startsCombat = false,
        texture = 611417,
        
        toggle = "defensives",
        
        handler = function()
            applyBuff("guard")
        end,
    },
      keg_smash = {
        id = 121253,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        spend = 40,
        spendType = "energy",
        
        startsCombat = true,
        texture = 594274,
        
        handler = function()
            applyDebuff("target", "keg_smash")
            applyDebuff("target", "weakened_blows")
            
            -- Generate 2 Chi - core mechanic for Brewmaster
            gain(2, "chi")
            
            -- Chance to proc Elusive Brew stack on crit
            if crit_chance > 0 then
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
        
        startsCombat = false,
        texture = 595276,
        
        toggle = "defensives",
        
        handler = function()
            -- Purifies 50% of staggered damage when used
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
            -- Summons a statue for 15 mins
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
            -- Applies group buff for crit and 5% stats
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
        cooldown = 15,
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
        
        spend = 0,
        spendType = "energy",
        
        startsCombat = true,
        texture = 606551,
        
        handler = function()
            -- Builds stack of Tiger Power
            addStack("tiger_power", nil, 1)
            -- Power Guard in defensive stance
            applyBuff("power_guard")
            
            if talent.power_strikes.enabled and cooldown.power_strikes.remains == 0 then
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

-- Specific to Xuen and Black Ox
spec:RegisterPet( "xuen_the_white_tiger", 73967, "invoke_xuen", 45 )
spec:RegisterTotem( "black_ox_statue", 627607 )

-- State Expressions
spec:RegisterStateExpr( "stagger_pct", function()
    if buff.heavy_stagger.up then return 0.6
    elseif buff.moderate_stagger.up then return 0.4
    elseif buff.light_stagger.up then return 0.2
    else return 0 end
end )

spec:RegisterStateExpr( "stagger_amount", function()
    if health.current == 0 then return 0 end
    local base_amount = health.max * 0.05 -- Base stagger amount
    if buff.heavy_stagger.up then return base_amount * 3
    elseif buff.moderate_stagger.up then return base_amount * 2
    elseif buff.light_stagger.up then return base_amount
    else return 0 end
end )

spec:RegisterStateExpr( "effective_stagger", function()
    local amount = stagger_amount
    if buff.shuffle.up then
        amount = amount * 1.2 -- 20% more stagger with Shuffle
    end
    return amount
end )

spec:RegisterStateExpr( "chi_cap", function()
    if talent.ascension.enabled then return 5 else return 4 end
end )

spec:RegisterStateExpr( "energy_regen_rate", function()
    local base_rate = 10 -- Base energy per second
    if talent.ascension.enabled then
        base_rate = base_rate * 1.15 -- 15% increase from Ascension
    end
    return base_rate
end )

spec:RegisterStateExpr( "should_purify", function()
    return stagger_amount > health.max * 0.08 and chi.current > 0
end )

-- Range
spec:RegisterRanges( "keg_smash", "paralysis", "provoke", "crackling_jade_lightning" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "virmen_bite_potion",
    
    package = "Brewmaster",
} )

-- Register default pack for MoP Brewmaster Monk
spec:RegisterPack( "Brewmaster", 20250517, [[Hekili:T3vBVTTnu4FldiHr5osojoRZh7KvA3KRJvA2jDLA2jz1yvfbpquu6iqjvswkspfePtl6VGQIQUnbJeHAVQDcOWrbE86CaE4GUwDBB4CvC5m98jdNZzDX6w)v)V(i)h(jDV7GFWEh)9T6rhFQVnSVzsmypSlD2OXqskYJCKfpPWXt87zPkZGZVRSLAXYUYORTmYLwaXlyc8LkGusGO7469JwjTfTH0PwPbJaeivvLsvrfoeQtcGbWlG0A)Ff9)8jPyqXgkz5Qkz5kLRyR12Uco1veB5MUOfIMXnV2Nw8UqEkeUOLXMFtKUOMcEvjzmqssgiE37NuLYlP5NnNgEE5(vJDjgvCeXmQVShsbh(AfIigS2JOmiUeXm(KJ0JkOtQu0Ky)iYcJvqQrthQ(5Fcu5ILidEZjQ0CoYXj)USIip9kem)i81l2cOFLlk9cKGk5nuuDXZes)SEHXiZdLP1gpb968CvpxbSVDaPzgwP6ahsQWnRs)uOKnc0)]] )

-- Register pack selector for Brewmaster
spec:RegisterPackSelector( "brewmaster", "Brewmaster", "|T608951:0|t Brewmaster",
    "Handles all aspects of Brewmaster Monk tanking rotation with focus on survival and mitigation.",
    nil )
