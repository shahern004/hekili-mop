-- MonkMistweaver.lua
-- Updated May 30, 2025 - Modern Structure with Advanced Patterns
-- Mists of Pandaria module for Monk: Mistweaver spec
-- Enhanced implementation with comprehensive MoP Mistweaver healing mechanics

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

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

-- Enhanced helper functions for Mistweaver Monk
local function UA_GetPlayerAuraBySpellID(spellID)
    return FindUnitBuffByID("player", spellID)
end

local function GetTargetDebuffByID(spellID)
    return FindUnitDebuffByID("target", spellID, "PLAYER")
end

local function GetHealingSphereCount()
    -- Simplified healing sphere count tracking
    local count = 0
    for i = 1, 3 do
        if FindUnitBuffByID("player", 115464) then count = count + 1 end
    end
    return count
end

local spec = Hekili:NewSpecialization( 270 ) -- Mistweaver spec ID for MoP

-- Mistweaver-specific combat log event tracking
local mwCombatLogFrame = CreateFrame("Frame")
local mwCombatLogEvents = {}

local function RegisterMWCombatLogEvent(event, handler)
    if not mwCombatLogEvents[event] then
        mwCombatLogEvents[event] = {}
    end
    table.insert(mwCombatLogEvents[event], handler)
end

mwCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
        
        if sourceGUID == UnitGUID("player") then
            local handlers = mwCombatLogEvents[subevent]
            if handlers then
                for _, handler in ipairs(handlers) do
                    handler(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, select(12, CombatLogGetCurrentEventInfo()))
                end
            end
        end
    end
end)

mwCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Renewing Mist spread tracking
RegisterMWCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 119611 then -- Renewing Mist
        -- Track Renewing Mist application and spread mechanics
    elseif spellID == 115307 then -- Mana Tea stack
        -- Track Mana Tea stack accumulation
    elseif spellID == 124081 then -- Zen Sphere
        -- Track Zen Sphere applications
    end
end)

-- Uplift heal tracking for optimization
RegisterMWCombatLogEvent("SPELL_HEAL", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, amount, overhealing)
    if spellID == 116670 then -- Uplift
        -- Track Uplift healing efficiency
    elseif spellID == 115175 then -- Soothing Mist
        -- Track Soothing Mist channeling
    elseif spellID == 124682 then -- Enveloping Mist
        -- Track Enveloping Mist healing
    end
end)

-- Thunder Focus Tea proc tracking
RegisterMWCombatLogEvent("SPELL_CAST_SUCCESS", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if sourceGUID == UnitGUID("player") then
        if spellID == 116680 then -- Thunder Focus Tea
            -- Track Thunder Focus Tea activation
        elseif spellID == 100787 then -- Tiger Palm
            -- Track Tiger Palm for Power Strikes and Chi generation
        elseif spellID == 115313 then -- Summon Jade Serpent Statue
            -- Track statue placement
        end
    end
end)

-- Mana Tea consumption tracking
RegisterMWCombatLogEvent("SPELL_AURA_REMOVED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if destGUID == UnitGUID("player") and spellID == 115307 then -- Mana Tea stack consumed
        -- Track Mana Tea usage optimization
    end
end)

-- Enhanced Mana resource system for Mistweaver
spec:RegisterResource( 0, { -- Mana = 0 in MoP
    -- Mana Tea restoration
    mana_tea = {
        aura = "mana_tea",
        last = function ()
            local app = state.buff.mana_tea.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 0.5 ) * 0.5
        end,
        interval = 0.5,
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
            local regen = spirit * 0.5
            if state.buff.stance_of_the_wise_serpent.up then
                regen = regen * 1.5 -- Serpent Stance bonus
            end
            return regen
        end,
    },
    
    -- Spirit Channeling from Soothing Mist
    spirit_channeling = {
        aura = "soothing_mist",
        last = function ()
            local app = state.buff.soothing_mist.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 2 ) * 2
        end,
        interval = 2,
        value = function()
            return state.channeling.soothing_mist and 1000 or 0
        end,
    },
    
    -- Crackling Jade Lightning mana efficiency in Serpent Stance
    crackling_jade = {
        aura = "crackling_jade_lightning",
        last = function ()
            local app = state.buff.crackling_jade_lightning.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.channeling.crackling_jade_lightning and 500 or 0
        end,
    },
}, {
    base_regen = function ()
        local base = state.stat.spirit and ( state.stat.spirit * 0.5 ) or 0
        if state.buff.stance_of_the_wise_serpent.up then
            base = base * 1.5
        end
        if state.buff.meditation.up then
            base = base + (state.stat.spirit or 0) * 0.1
        end
        return base
    end,
} )

-- Enhanced Chi resource system for Mistweaver
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
    
    -- Focus and Harmony Chi from critical heals
    focus_and_harmony = {
        aura = "focus_and_harmony",
        last = function ()
            local app = state.buff.focus_and_harmony.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 6 ) * 6
        end,
        interval = 6,
        value = function()
            return state.spec.mistweaver and 1 or 0
        end,
    },
    
    -- Muscle Memory Chi generation
    muscle_memory = {
        aura = "muscle_memory",
        last = function ()
            local app = state.buff.muscle_memory.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 10 ) * 10
        end,
        interval = 10,
        value = function()
            return state.buff.muscle_memory.up and 1 or 0
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

-- Enhanced Energy resource system for Serpent Stance
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
            local energy = 20
            if state.talent.ascension.enabled then energy = energy * 1.15 end
            if state.buff.power_strikes.up then energy = energy + 10 end
            if state.buff.stance_of_the_wise_serpent.up then energy = energy * 0.5 end -- Reduced in Serpent Stance
            return energy
        end,
    },
    
    -- Jab energy generation in Serpent Stance
    jab_serpent = {
        aura = "jab_serpent",
        last = function ()
            local app = state.buff.jab_serpent.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 2.0 ) * 2.0
        end,
        interval = 2.0,
        value = function()
            local energy = 15
            if state.talent.ascension.enabled then energy = energy * 1.15 end
            if state.buff.stance_of_the_wise_serpent.up then energy = energy * 0.5 end
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
            return state.talent.ascension.enabled and 1.5 or 0
        end,
    },
}, {
    base_regen = function ()
        local base = 10
        if state.talent.ascension.enabled then
            base = base * 1.15
        end
        if state.buff.stance_of_the_wise_serpent.up then
            base = base * 0.5 -- Reduced energy regen in Serpent Stance
        end
        return base
    end,
} )

-- Comprehensive Tier Sets for MoP Mistweaver Monk
-- T14 - Yaungol Slayer's Battlegear (Monk Healer Set)
spec:RegisterGear( "tier14", 85393, 85394, 85395, 85396, 85397 ) -- LFR
spec:RegisterGear( "tier14_normal", 85398, 85399, 85400, 85401, 85402 ) -- Normal
spec:RegisterGear( "tier14_heroic", 85403, 85404, 85405, 85406, 85407 ) -- Heroic

-- T15 - Battlegear of the Lightning Emperor (Monk Healer Set)
spec:RegisterGear( "tier15", 95825, 95826, 95827, 95828, 95829 ) -- LFR
spec:RegisterGear( "tier15_normal", 95830, 95831, 95832, 95833, 95834 ) -- Normal
spec:RegisterGear( "tier15_heroic", 95835, 95836, 95837, 95838, 95839 ) -- Heroic
spec:RegisterGear( "tier15_thunderforged", 95840, 95841, 95842, 95843, 95844 ) -- Thunderforged

-- T16 - Battlegear of the Shattered Vale (Monk Healer Set)
spec:RegisterGear( "tier16", 98961, 98962, 98963, 98964, 98965 ) -- LFR
spec:RegisterGear( "tier16_normal", 98966, 98967, 98968, 98969, 98970 ) -- Normal
spec:RegisterGear( "tier16_heroic", 98971, 98972, 98973, 98974, 98975 ) -- Heroic
spec:RegisterGear( "tier16_mythic", 98976, 98977, 98978, 98979, 98980 ) -- Mythic

-- Legendary Items for MoP
spec:RegisterGear( "legendary_cloak", 102248 ) -- Jina-Kang, Kindness of Chi-Ji
spec:RegisterGear( "legendary_cloak_int", 102249 ) -- Hyoju, Niuzao's Blessing

-- Notable Healing Trinkets and Proc Items
spec:RegisterGear( "dysmorphic_samophlange", 104574 ) -- Dysmorphic Samophlange of Discontinuity
spec:RegisterGear( "spark_of_zandalar", 104557 ) -- Spark of Zandalar
spec:RegisterGear( "prismatic_prison", 104467 ) -- Prismatic Prison of Pride
spec:RegisterGear( "purified_bindings", 104509 ) -- Purified Bindings of Immerseus

-- Meta Gems for MoP Mistweaver
spec:RegisterGear( "revitalizing_primal", 76892 ) -- Revitalizing Primal Diamond
spec:RegisterGear( "ember_primal", 76895 ) -- Ember Primal Diamond
spec:RegisterGear( "burning_primal", 76884 ) -- Burning Primal Diamond

-- PvP Sets for Mistweaver
spec:RegisterGear( "malevolent", 85306, 85307, 85308, 85309, 85310 ) -- Malevolent Gladiator's Ironskin
spec:RegisterGear( "tyrannical", 95806, 95807, 95808, 95809, 95810 ) -- Tyrannical Gladiator's Ironskin
spec:RegisterGear( "grievous", 98946, 98947, 98948, 98949, 98950 ) -- Grievous Gladiator's Ironskin

-- Challenge Mode Sets
spec:RegisterGear( "challenge_mode", 88441, 88442, 88443, 88444, 88445 ) -- Challenge Mode Monk Transmog

-- Tier Set Bonuses for Mistweaver
spec:RegisterAura( "tier14_2pc_heal", {
    id = 123460, -- Placeholder for 2pc bonus
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "tier14_4pc_heal", {
    id = 123461, -- Placeholder for 4pc bonus
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "tier15_2pc_heal", {
    id = 138240, -- Lightning Emperor 2pc: Renewing Mist duration increase
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "tier15_4pc_heal", {
    id = 138241, -- Lightning Emperor 4pc: Uplift critical strike bonus
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "tier16_2pc_heal", {
    id = 147010, -- Shattered Vale 2pc: Soothing Mist healing increase
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "tier16_4pc_heal", {
    id = 147011, -- Shattered Vale 4pc: Enveloping Mist Chi cost reduction
    duration = 3600,
    max_stack = 1,
} )

-- Talents (MoP 6-tier talent system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility
    celerity                  = { 1, 1, 115173 }, -- Reduces Roll cooldown by 5 sec, adds 1 charge
    tigers_lust               = { 1, 2, 116841 }, -- Increases ally movement speed by 70% for 6 sec
    momentum                  = { 1, 3, 115294 }, -- Rolling increases movement speed by 25% for 10 sec
    
    -- Tier 2 (Level 30) - Healing
    chi_wave                  = { 2, 1, 115098 }, -- Chi energy bounces between friends and foes
    zen_sphere                = { 2, 2, 124081 }, -- Healing sphere around target, explodes on expire
    chi_burst                 = { 2, 3, 123986 }, -- Chi torrent damages enemies, heals allies
    
    -- Tier 3 (Level 45) - Resource
    power_strikes             = { 3, 1, 121817 }, -- Every 20 sec, Tiger Palm grants 1 additional Chi
    ascension                 = { 3, 2, 115396 }, -- +1 max Chi, +15% Energy regeneration
    chi_brew                  = { 3, 3, 115399 }, -- Restores 2 Chi, 45 sec cooldown
    
    -- Tier 4 (Level 60) - Control
    deadly_reach              = { 4, 1, 126679 }, -- Increases Paralysis range by 10 yds
    charging_ox_wave          = { 4, 2, 119392 }, -- Ox wave stuns enemies for 3 sec
    leg_sweep                 = { 4, 3, 119381 }, -- Stuns nearby enemies for 5 sec
    
    -- Tier 5 (Level 75) - Defense   
    healing_elixirs           = { 5, 1, 122280 }, -- Potions heal for +10% max health
    dampen_harm               = { 5, 2, 122278 }, -- Reduces next 3 large attacks by 50%
    diffuse_magic             = { 5, 3, 122783 }, -- Transfers debuffs, 90% magic damage reduction
    
    -- Tier 6 (Level 90) - Ultimate
    rushing_jade_wind         = { 6, 1, 116847 }, -- Whirling tornado damages nearby enemies
    invoke_xuen               = { 6, 2, 123904 }, -- Summons White Tiger Xuen for 45 sec
    chi_torpedo               = { 6, 3, 119085 }  -- Torpedo forward, +30% movement speed
} )

-- Comprehensive Glyph System for MoP Mistweaver Monk
spec:RegisterGlyphs( {
    -- Major Glyphs for Mistweaver Healing
    [125731] = "afterlife", -- Glyph of Afterlife: Spirit of deceased party members aid you
    [125732] = "detox", -- Glyph of Detox: Detox heals the target when removing effects
    [125757] = "enduring_healing_sphere", -- Glyph of Enduring Healing Sphere: Healing Spheres last 60 sec longer
    [125671] = "expel_harm", -- Glyph of Expel Harm: Increases range to 20 yards
    [125676] = "fortifying_brew", -- Glyph of Fortifying Brew: Increases duration by 5 sec, reduces effectiveness
    [123763] = "mana_tea", -- Glyph of Mana Tea: Reduces mana cost of spells during channel by 50%
    [125767] = "paralysis", -- Glyph of Paralysis: Reduces damage required to break Paralysis by 50%
    [125755] = "retreat", -- Glyph of Retreat: Increases retreat distance and removes movement slowing effects
    [125678] = "spinning_crane_kick", -- Glyph of Spinning Crane Kick: Reduces energy cost by 5 for each unique target hit
    [125750] = "surging_mist", -- Glyph of Surging Mist: Reduces healing but increases movement speed
    [125932] = "targeted_expulsion", -- Glyph of Targeted Expulsion: Expel Harm now affects targeted ally
    [125679] = "touch_of_death", -- Glyph of Touch of Death: Reduces health requirement to 25% for non-player targets
    [125680] = "transcendence", -- Glyph of Transcendence: Increases range to 40 yards
    [125681] = "zen_meditation", -- Glyph of Zen Meditation: Increases damage reduction but prevents movement
    [146950] = "renewing_mist", -- Glyph of Renewing Mist: Increases spread radius by 10 yards
    
    -- Additional Mistweaver-specific Major Glyphs
    [125713] = "soothing_mist", -- Glyph of Soothing Mist: Increases channel duration by 2 sec
    [125714] = "enveloping_mist", -- Glyph of Enveloping Mist: Reduces cast time by 0.5 sec, reduces healing
    [125715] = "uplift", -- Glyph of Uplift: Increases Uplift range by 10 yards
    [125716] = "thunder_focus_tea", -- Glyph of Thunder Focus Tea: Reduces cooldown by 15 sec
    [125717] = "healing_sphere", -- Glyph of Healing Sphere: Increases sphere duration by 30 sec
    [125718] = "chi_wave", -- Glyph of Chi Wave: Increases number of bounces by 2
    [125719] = "zen_sphere", -- Glyph of Zen Sphere: Increases heal radius when sphere explodes
    [125720] = "chi_burst", -- Glyph of Chi Burst: Reduces cast time by 0.5 sec
    [125721] = "life_cocoon", -- Glyph of Life Cocoon: Increases absorb amount by 50%, increases cooldown
    [125722] = "revival", -- Glyph of Revival: Reduces cooldown by 2 min, reduces range
    [125723] = "summon_jade_serpent", -- Glyph of Summon Jade Serpent Statue: Statue heals for 50% more, lasts 50% less time
    [125724] = "teachings_of_monastery", -- Glyph of Teachings of the Monastery: Stacks grant 15% bonus instead of 10%
    [125725] = "muscle_memory", -- Glyph of Muscle Memory: Increases proc chance by 5%
    [125726] = "vital_mists", -- Glyph of Vital Mists: Reduces mana cost of Enveloping Mist by 20%
    [125727] = "crackling_jade_lightning", -- Glyph of Crackling Jade Lightning: Healing while channeling
    [125728] = "focus_and_harmony", -- Glyph of Focus and Harmony: Increases Chi gain from crits
    [125729] = "surging_mist_movement", -- Glyph of Surging Mist: Can cast while moving, costs 50% more mana
    [125730] = "serpent_stance", -- Glyph of Stance of the Wise Serpent: Increases healing by 10%, reduces energy regen by 20%
    
    -- Minor Glyphs for Mistweaver
    [125733] = "crackling_jade_lightning_visual", -- Glyph of Crackling Jade Lightning: Causes lightning to be verdant green
    [125734] = "honor", -- Glyph of Honor: Bow respectfully when targeting fellow monks
    [125735] = "spirit_roll", -- Glyph of Spirit Roll: Roll leaves a spirit behind for 20 sec
    [125736] = "zen_flight", -- Glyph of Zen Flight: Flight form has a trailing cloud effect
    [125737] = "water_roll", -- Glyph of Water Roll: Roll on water surface for brief period
    [125738] = "jab", -- Glyph of Jab: Jab has a chance to generate a small healing sphere
    [125739] = "soothing_mist_visual", -- Glyph of Soothing Mist: Channeling produces calming green mist
    [125740] = "enveloping_mist_visual", -- Glyph of Enveloping Mist: Target is surrounded by glowing jade cocoon
    [125741] = "renewing_mist_visual", -- Glyph of Renewing Mist: Produces floating jade serpents
    [125742] = "uplift_visual", -- Glyph of Uplift: Healing produces rising jade energy
    [125743] = "life_cocoon_visual", -- Glyph of Life Cocoon: Cocoon appears as blooming lotus
    [125744] = "revival_visual", -- Glyph of Revival: Healing wave appears as flowing serpent
    [125745] = "chi_wave_visual", -- Glyph of Chi Wave: Wave appears as swimming jade fish
    [125746] = "zen_sphere_visual", -- Glyph of Zen Sphere: Sphere has swirling yin-yang symbol
    [125747] = "chi_burst_visual", -- Glyph of Chi Burst: Burst appears as exploding jade flower
    [125748] = "thunder_focus_tea_visual", -- Glyph of Thunder Focus Tea: Tea ceremony visual effects
    [125749] = "jade_serpent_statue", -- Glyph of Jade Serpent Statue: Statue has enhanced jade appearance
    [125751] = "healing_sphere_visual", -- Glyph of Healing Sphere: Spheres glow with inner jade light
    [125752] = "transcendence_visual", -- Glyph of Transcendence: Spirit form appears more translucent
    [125753] = "tigers_lust_visual", -- Glyph of Tiger's Lust: Target briefly shows tiger stripes
    [125754] = "fortifying_brew_visual", -- Glyph of Fortifying Brew: Character glows with earthen power
} )

-- Statuses for Mistweaver
spec:RegisterStateTable( "healing_spheres", setmetatable({}, {
    __index = function( t, k )
        if k == "count" then
            -- In MoP, we would have to check for healing spheres on the ground
            -- This is a simplification
            return 0
        end
        return 0
    end,
}))

-- Enhanced Aura System with Advanced Generate Functions for Mistweaver
spec:RegisterAuras( {
    -- === Core Mistweaver Healing Mechanics ===

    -- Serpent Stance (automatically gained for Mistweavers)
    stance_of_the_wise_serpent = {
        id = 115070,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if state.spec.mistweaver then
                t.name = "Stance of the Wise Serpent"
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

    -- Mana Tea: Restores 4% of maximum mana per stack
    mana_tea = {
        id = 115867,
        duration = 30,
        max_stack = 20,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115867 )
            
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

    -- Jade Mist: Healing mist jumps to nearby targets
    jade_mist = {
        id = 115151,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115151 )
            
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

    -- Renewing Mist: HoT that also jumps to new targets
    renewing_mist = {
        id = 119611,
        duration = 18,
        tick_time = 2,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 119611, "PLAYER" )
            
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

    -- Soothing Mist: Channeled healing
    soothing_mist = {
        id = 115175,
        duration = 8,
        tick_time = 1,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115175 )
            
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
        end    },

    -- Removed duplicate enveloping_mist definition (kept later definition at line 1255)

    -- === Advanced Mistweaver Mechanics ===

    -- Thunder Focus Tea: Enhanced next spell
    thunder_focus_tea = {
        id = 116680,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 116680 )
            
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
        end    },    -- Removed duplicate teachings_of_the_monastery definition (kept later definition at line 1303)

    -- Removed duplicate muscle_memory definition (kept later definition at line 1375)

    -- Removed duplicate vital_mists definition (kept later definition at line 1351)

    -- === Defensive and Utility Auras ===

    -- Fortifying Brew: Damage reduction
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

    -- Chi Wave: Bouncing Chi energy
    chi_wave = {
        id = 115098,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115098 )
            
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

    -- Zen Sphere: Healing sphere around target
    zen_sphere = {
        id = 124081,
        duration = 16,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 124081, "PLAYER" )
            
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
            t.caster = "nobody"        end
    },

    -- Removed duplicate momentum definition (kept later definition at line 1471)

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

    -- === Tier Set Bonuses ===

    -- Tier 15 2pc: Renewing Mist duration increase
    tier15_2pc_heal = {
        id = 138240,
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

    -- Tier 15 4pc: Uplift critical strike bonus
    tier15_4pc_heal = {
        id = 138241,
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

    -- Tier 16 2pc: Soothing Mist healing increase
    tier16_2pc_heal = {
        id = 147010,
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

    -- Tier 16 4pc: Enveloping Mist Chi cost reduction
    tier16_4pc_heal = {
        id = 147011,
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
        id = 999011,
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

    -- Jab energy tracking (Serpent Stance)
    jab_serpent = {
        id = 999012,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            t.name = "Jab Serpent"
            t.count = 1
            t.expires = state.query_time + 3600
            t.applied = state.query_time
            t.caster = "player"
        end
    },

    -- Chi Brew tracking
    chi_brew = {
        id = 999013,
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
        id = 999014,
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
        id = 999015,
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

    -- Spirit Channeling mana tracking
    spirit_channeling = {
        id = 999016,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            t.name = "Spirit Channeling"
            t.count = 1
            t.expires = state.query_time + 3600
            t.applied = state.query_time
            t.caster = "player"
        end
    },    -- Crackling Jade Lightning mana tracking
    crackling_jade_lightning = {
        id = 999017,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            t.name = "Crackling Jade Lightning"
            t.count = 1
            t.expires = state.query_time + 3600
            t.applied = state.query_time
            t.caster = "player"
        end
    },

    -- Life Cocoon: Absorbs damage and increases healing received
    life_cocoon = {
        id = 116849,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 116849, "PLAYER" )
            
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
    
    -- Enveloping Mist: Increases healing received from Soothing Mist
    enveloping_mist = {
        id = 124682,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 124682, "PLAYER" )
            
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
    
    -- Uplift: AoE heal for all targets with Renewing Mist
    uplift = {
        id = 116670,
        duration = 1,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 116670 )
            
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
    
    -- Teachings of the Monastery: Modifies Tiger Palm, Blackout Kick, and Jab
    teachings_of_the_monastery = {
        id = 116645,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 116645 )
            
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
    
    -- Serpent's Zeal - Gained from Blackout Kick in Serpent Stance
    serpents_zeal = {
        id = 127722,
        duration = 20,
        max_stack = 2,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 127722 )
            
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
    
    -- Vital Mists - Stacks from Jab, consumed by Surging Mist
    vital_mists = {
        id = 118674,
        duration = 30,
        max_stack = 5,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 118674 )
            
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
    
    -- Muscle Memory - Gained from Tiger Palm in Serpent Stance
    muscle_memory = {
        id = 118864,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 118864 )
            
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
    
    -- Mastery: Gift of the Serpent
    gift_of_the_serpent = {
        id = 117907,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 117907 )
            
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
    
    -- Zen Focus: Reduces mana cost while channeling Soothing Mist
    zen_focus = {
        id = 124416,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 124416 )
            
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
    
    -- Path of Blossoms from Chi Torpedo
    path_of_blossoms = {
        id = 121027,
        duration = 10,
        max_stack = 2,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 121027 )
            
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
    
    -- Momentum from talent
    momentum = {
        id = 119085,
        duration = 10,
        max_stack = 2,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 119085 )
            
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
    
    -- Paralysis
    paralysis = {
        id = 115078,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 115078, "PLAYER" )
            
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

-- Monk shared abilities and Mistweaver abilities
spec:RegisterAbilities( {
    -- Core Mistweaver Abilities
    enveloping_mist = {
        id = 124682,
        cast = function()
            if buff.soothing_mist.up then return 0 end
            return 2
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 3,
        spendType = "chi",
        
        startsCombat = false,
        texture = 775461,
        
        handler = function()
            applyBuff("enveloping_mist", "target")
        end,
    },
    
    life_cocoon = {
        id = 116849,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        toggle = "defensives", 
        
        startsCombat = false,
        texture = 627485,
        
        handler = function()
            applyBuff("life_cocoon", "target")
        end,
    },
    
    mana_tea = {
        id = 123761,
        cast = function() return glyph.mana_tea.enabled and 0 or 0.5 end,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 608939,
        
        buff = "mana_tea",
        
        usable = function()
            return buff.mana_tea.stack > 0, "requires mana_tea stacks"
        end,
        
        handler = function()
            -- Consumption of stacks depends on channel duration
            -- In the simple case, consumes all stacks at once
            local stacks = buff.mana_tea.stack
            removeStack("mana_tea", stacks)
        end,
    },
    
    renewing_mist = {
        id = 119611,
        cast = 0,
        cooldown = 8,
        charges = 2,
        recharge = 8,
        gcd = "spell",
        
        spend = 1,
        spendType = "chi",
        
        startsCombat = false,
        texture = 627487,
        
        handler = function()
            applyBuff("renewing_mist", "target")
        end,
    },
    
    revival = {
        id = 115310,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 627483,
        
        handler = function()
            applyBuff("revival")
        end,
    },
    
    soothing_mist = {
        id = 115175,
        cast = 8,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = false,
        texture = 606550,
        
        channeled = true,
        
        handler = function()
            applyBuff("soothing_mist", "target")
        end,
    },
    
    surging_mist = {
        id = 116694,
        cast = function() 
            if buff.soothing_mist.up then return 0 end
            return 2
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            if buff.vital_mists.stack == 5 then return 0 end
            return 0.2 * (1 - 0.2 * buff.vital_mists.stack)
        end,
        spendType = "mana",
        
        startsCombat = false,
        texture = 606549,
        
        handler = function()
            if buff.vital_mists.stack == 5 then
                removeBuff("vital_mists")
            else
                removeStack("vital_mists", buff.vital_mists.stack)
            end
            
            if buff.thunder_focus_tea.up then
                removeBuff("thunder_focus_tea")
            end
        end,
    },
    
    thunder_focus_tea = {
        id = 116680,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        
        startsCombat = false,
        texture = 611418,
        
        handler = function()
            applyBuff("thunder_focus_tea")
        end,
    },
    
    uplift = {
        id = 116670,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 2,
        spendType = "chi",
        
        startsCombat = false,
        texture = 775466,
        
        handler = function()
            -- Heals all targets with Renewing Mist
            -- If Thunder Focus Tea is active, double the healing
            if buff.thunder_focus_tea.up then
                removeBuff("thunder_focus_tea")
            end
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
            -- Maximum of one sphere at a time
        end,
    },
    
    -- Special Mistweaver abilities
    blackout_kick = {
        id = 100784,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 2,
        spendType = "chi",
        
        startsCombat = true,
        texture = 574575,
        
        handler = function()
            -- In Serpent Stance, generates Serpent's Zeal
            addStack("serpents_zeal", nil, 1)
        end,
    },
    
    detox = {
        id = 115450,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = false,
        texture = 460692,
        
        handler = function()
            -- Removes 1 Magic effect and 1 Poison/Disease effect
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
            
            -- In Serpent Stance, generates 1 stack of Vital Mists
            addStack("vital_mists", nil, 1)
            
            -- Power Strikes talent
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
        
        spend = 1,
        spendType = "chi",
        
        startsCombat = true,
        texture = 606551,
        
        handler = function()
            -- In Serpent Stance, generates Muscle Memory for next Surging Mist
            applyBuff("muscle_memory")
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
    
    expel_harm = {
        id = 115072,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = true,
        texture = 627485,
        
        handler = function()
            -- Healing to self and damage to nearby enemy
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
        
        spend = 0.1,
        spendType = "mana",
        
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
        
        spend = 0.15,
        spendType = "mana",
        
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
} )

-- Specific to Xuen
spec:RegisterPet( "xuen_the_white_tiger", 73967, "invoke_xuen", 45 )

-- State Expressions for Mistweaver
spec:RegisterStateExpr( "healing_sphere_count", function()
    return healing_spheres.count or 0
end )

spec:RegisterStateExpr( "vital_mists_stack", function()
    return buff.vital_mists.stack
end )

-- Range and Targeting
spec:RegisterRanges( "renewing_mist", "tiger_palm", "blackout_kick", "paralysis", "provoke", "crackling_jade_lightning" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "virmen_bite_potion",
    
    package = "Mistweaver",
} )

-- Register default pack for MoP Mistweaver Monk
spec:RegisterPack( "Mistweaver", 20250517, [[Hekili:v3vBVnTns4FthjJY5gC03WlKGSqLVA2qzDXDZfbgJt)g7oLK7pszKDQAXnr5JTOl3JNPh3KiBSWCPHEyI6DfWo7bU5WHuT09qSHGzrtbcnZ5YXXsxGBpXlpjDRBl(mGfKiLsf6n5PZpC8MO2)W7cIRPqn5rCRgk5wQxrpCXrRH72sOoHJUu1HPOujjrKxTdF2HZ5wNXLk(kC9OQTgDxXQgOuZkExxDxXQYEQnQrtcxPxuQFbTe1sGvzsgLo0n4U8zYkm55aZQm5u8sfLnkLl81hskEqrMzXlSE3tvY3MBbCvZli5lQnY3mMh)ENKvTMBJTkV8CsVMoOvHXLsH3aOkYUkj(5RZgGTxHnJ3B(j44FWr)lXH06W9GCbg)Z8VuCLo0hVZmEPsOUbRrz5G5jQo0rzt)8VbbYAM2jkz5Y1qkiG8NnQEzRq(4cYOb7UCOmrCkebZoVOkL9KM9B1JMDDVGnzrCVYgYbAXrxNv6kTyK)YKj4MaLO)5jZi)bKLSxlQMfVf4eN3Q)ycUhD3cV9eLc8Vu9TjAo69R)SyEz1p)rIJ93Dl2mOF0Qx4aCkqpj(KmcqcRfhT)]] )

-- Register pack selector for Mistweaver
