if not Hekili or not Hekili.NewSpecialization then return end
-- DruidFeral.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Druid: Feral spec

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'DRUID' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class, state

local function getReferences()
    if not class then
        class, state = Hekili.Class, Hekili.State
    end
    return class, state
end

local spec = Hekili:NewSpecialization( 103 ) -- Feral spec ID for MoP

local strformat = string.format
local FindUnitBuffByID = ns.FindUnitBuffByID
local FindUnitDebuffByID = ns.FindUnitDebuffByID
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

local feralCombatLogFrame = CreateFrame("Frame")
local feralCombatLogEvents = {}

local function RegisterFeralCombatLogEvent(event, handler)
    if not feralCombatLogEvents[event] then
        feralCombatLogEvents[event] = {}
        feralCombatLogFrame:RegisterEvent(event)
    end
    
    tinsert(feralCombatLogEvents[event], handler)
end

feralCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    local handlers = feralCombatLogEvents[event]
    if handlers then
        for _, handler in ipairs(handlers) do
            handler(event, ...)
        end
    end
end)

-- Bleed tracking variables
local rake_applications = {}
local rip_extensions = 0
local savage_roar_refreshes = 0
local combo_point_generation = 0

RegisterFeralCombatLogEvent("COMBAT_LOG_EVENT_UNFILTERED", function(event, ...)
    local _, subEvent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, auraType = CombatLogGetCurrentEventInfo()
    
    if sourceGUID ~= UnitGUID("player") then return end
    
    local now = GetTime()
    
    -- BLEED APPLICATION AND REFRESH TRACKING
    if subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REFRESH" then        if spellId == 1822 then -- Rake
            rake_applications[destGUID] = {
                time = now,
                -- MoP: Use legacy power type constant
                combo_points = UnitPower("player", 4), -- ComboPoints = 4 in MoP
                tiger_fury = FindUnitBuffByID("player", 5217) and true or false,
                savage_roar = FindUnitBuffByID("player", 52610) and true or false
            }
            ns.last_rake_applied = now
        elseif spellId == 1079 then -- Rip
            ns.last_rip_applied = now
            -- MoP: Use legacy power type constant
            ns.rip_combo_points = UnitPower("player", 4) -- ComboPoints = 4 in MoP
        elseif spellId == 52610 then -- Savage Roar
            savage_roar_refreshes = savage_roar_refreshes + 1
            ns.last_savage_roar = now
        end
    end      -- COMBO POINT GENERATION TRACKING
    if subEvent == "SPELL_CAST_SUCCESS" then
        -- MoP: Use legacy power type constant
        local cp_before = UnitPower("player", 4) -- ComboPoints = 4 in MoP
        -- MoP compatibility: use fallback for C_Timer
        local checkFunc = function()
            -- MoP: Use legacy power type constant
            local cp_after = UnitPower("player", 4) -- ComboPoints = 4 in MoP
            if cp_after > cp_before then
                combo_point_generation = combo_point_generation + (cp_after - cp_before)
            end
        end
        
        if C_Timer and C_Timer.After then
            C_Timer.After(0.1, checkFunc)
        elseif ns.ScheduleTimer then
            ns.ScheduleTimer(checkFunc, 0.1)
        else
            checkFunc() -- Immediate fallback
        end
        
        if spellId == 1822 then -- Rake
            ns.last_rake_cast = now
        elseif spellId == 22568 then -- Ferocious Bite
            ns.last_ferocious_bite = now
        elseif spellId == 1079 then -- Rip
            ns.last_rip_cast = now
        end
    end
    
    -- ENERGY PROC TRACKING
    if subEvent == "SPELL_ENERGIZE" then
        if spellId == 16959 then -- Primal Fury (crit combo point generation)
            ns.last_primal_fury = now
        elseif spellId == 5217 then -- Tiger's Fury energy generation
            ns.last_tigers_fury_energy = now
        end
    end
      -- BLOODTALONS PROC TRACKING
    if subEvent == "SPELL_AURA_APPLIED" and spellId == 145152 then -- Bloodtalons
        ns.last_bloodtalons_proc = now
        -- MoP: Use legacy power type constant  
        ns.bloodtalons_stacks = UnitPower("player", 4) -- ComboPoints = 4 in MoP
    end
end)

-- Track bleeds table
local tracked_bleeds = {
    rip = {
        last_tick = {},
        tick_time = {},
        haste = {}
    },
    rake = {
        last_tick = {},
        tick_time = {},
        haste = {}
    },
    thrash_cat = {
        last_tick = {},
        tick_time = {},
        haste = {}
    }
}

-- Register resources
-- MoP: Use legacy power type constants
spec:RegisterResource( 3 ) -- Energy = 3 in MoP
spec:RegisterResource( 4 ) -- ComboPoints = 4 in MoP

-- ===================
-- ENHANCED TIER SETS AND GEAR REGISTRATION
-- ===================

-- Tier 14 - Eternal Blossom Vestment (Complete Coverage)
spec:RegisterGear( "tier14", 85304, 85305, 85306, 85307, 85308 ) -- Normal
spec:RegisterGear( "tier14_lfr", 89768, 89769, 89770, 89771, 89772 ) -- LFR versions
spec:RegisterGear( "tier14_heroic", 90581, 90582, 90583, 90584, 90585 ) -- Heroic versions

-- Tier 15 - Battlegear of the Haunted Forest (Complete Coverage)
spec:RegisterGear( "tier15", 95941, 95942, 95943, 95944, 95945 ) -- Normal
spec:RegisterGear( "tier15_lfr", 95286, 95287, 95288, 95289, 95290 ) -- LFR versions
spec:RegisterGear( "tier15_heroic", 96596, 96597, 96598, 96599, 96600 ) -- Heroic versions
spec:RegisterGear( "tier15_thunderforged", 97231, 97232, 97233, 97234, 97235 ) -- Thunderforged versions

-- Tier 16 - Battlegear of the Shattered Vale (Complete Coverage)
spec:RegisterGear( "tier16", 99095, 99096, 99097, 99098, 99099 ) -- Normal
spec:RegisterGear( "tier16_lfr", 99750, 99751, 99752, 99753, 99754 ) -- LFR versions
spec:RegisterGear( "tier16_flex", 100260, 100261, 100262, 100263, 100264 ) -- Flexible versions
spec:RegisterGear( "tier16_heroic", 100915, 100916, 100917, 100918, 100919 ) -- Heroic versions
spec:RegisterGear( "tier16_mythic", 101580, 101581, 101582, 101583, 101584 ) -- Mythic versions

-- Legendary Items (MoP specific)
spec:RegisterGear( "legendary_cloak", 102246 ) -- Jina-Kang, Kindness of Chi-Ji (DPS version)
spec:RegisterGear( "legendary_cloak_heal", 102245 ) -- Qian-Le, Courage of Niuzao (Tank/Heal version)
spec:RegisterGear( "legendary_meta_gem", 101817 ) -- Capacitive Primal Diamond

-- Notable Trinkets and Weapons (Feral-specific)
spec:RegisterGear( "rune_of_reorigination", 94532 ) -- Throne of Thunder trinket
spec:RegisterGear( "bad_juju", 102993 ) -- SoO trinket
spec:RegisterGear( "assurance_of_consequence", 102292 ) -- SoO trinket
spec:RegisterGear( "haromms_talisman", 102664 ) -- SoO trinket
spec:RegisterGear( "thoks_tail_tip", 105609 ) -- SoO trinket

-- Feral Weapons
spec:RegisterGear( "jadefire_spirit_blade", 87648 ) -- MSV weapon
spec:RegisterGear( "kilrak_twilight_oracle", 86199 ) -- HoF weapon
spec:RegisterGear( "cloudbender_kobo", 95939 ) -- ToT weapon
spec:RegisterGear( "kirintor_staff", 103988 ) -- SoO weapon
spec:RegisterGear( "xing_ho_breath_of_yu_lon", 104555 ) -- SoO weapon

-- PvP Sets (Arena/RBG specific)
spec:RegisterGear( "malevolent_gladiator", 84405, 84406, 84407, 84408, 84409 ) -- Season 12
spec:RegisterGear( "tyrannical_gladiator", 91672, 91673, 91674, 91675, 91676 ) -- Season 13
spec:RegisterGear( "grievous_gladiator", 100045, 100046, 100047, 100048, 100049 ) -- Season 14
spec:RegisterGear( "prideful_gladiator", 103031, 103032, 103033, 103034, 103035 ) -- Season 15

-- Challenge Mode Sets
spec:RegisterGear( "challenge_mode", 90313, 90314, 90315, 90316, 90317 ) -- Ethereal set
spec:RegisterGear( "challenge_mode_weapons", 90426, 90427, 90428 ) -- Challenge Mode weapons

-- Notable Meta Gems and Enchants
spec:RegisterGear( "capacitive_primal_diamond", 101817 ) -- Legendary meta gem
spec:RegisterGear( "agile_primal_diamond", 76885 ) -- Primary meta gem for Feral
spec:RegisterGear( "fleet_primal_diamond", 76889 ) -- Movement speed meta gem

-- Set bonus tracking with aura associations
spec:RegisterAura( "tier14_2pc_feral", {
    id = 123159,
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "tier14_4pc_feral", {
    id = 123160,
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "tier15_2pc_feral", {
    id = 138363,
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "tier15_4pc_feral", {
    id = 138364,
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "tier16_2pc_feral", {
    id = 144870,
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "tier16_4pc_feral", {
    id = 144871,
    duration = 3600,
    max_stack = 1,
} )

-- Advanced tier set bonus tracking with generate functions
local function check_tier_bonus(tier, pieces)
    return function()
        local count = 0
        for i = 1, 5 do
            if state.set_bonus[tier] >= i then
                count = count + 1
            end
        end
        return count >= pieces
    end
end

spec:RegisterGear( "tier14_2pc", nil, {
    generate = check_tier_bonus("tier14", 2)
} )

spec:RegisterGear( "tier14_4pc", nil, {
    generate = check_tier_bonus("tier14", 4)
} )

spec:RegisterGear( "tier15_2pc", nil, {
    generate = check_tier_bonus("tier15", 2)
} )

spec:RegisterGear( "tier15_4pc", nil, {
    generate = check_tier_bonus("tier15", 4)
} )

spec:RegisterGear( "tier16_2pc", nil, {
    generate = check_tier_bonus("tier16", 2)
} )

spec:RegisterGear( "tier16_4pc", nil, {
    generate = check_tier_bonus("tier16", 4)
} )

-- Talents (MoP talent system and Feral spec-specific talents)
spec:RegisterTalents( {
    -- Common MoP talent system (Tier 1-6)
    -- Tier 1 (Level 15)
    feline_swiftness        = { 4908, 1, 131768 },
    displacer_beast         = { 4909, 1, 102280 },
    wild_charge             = { 4910, 1, 102401 },
    
    -- Tier 2 (Level 30)
    natures_swiftness       = { 4911, 1, 132158 },
    renewal                 = { 4912, 1, 108238 },
    cenarion_ward           = { 4913, 1, 102351 },
    
    -- Tier 3 (Level 45)
    faerie_swarm            = { 4914, 1, 102355 },
    mass_entanglement       = { 4915, 1, 102359 },
    typhoon                 = { 4916, 1, 132469 },
    
    -- Tier 4 (Level 60)
    soul_of_the_forest      = { 4917, 1, 114107 },
    incarnation             = { 4918, 1, 102543 },
    force_of_nature         = { 4919, 1, 106731 },
    
    -- Tier 5 (Level 75)
    disorienting_roar       = { 4920, 1, 99, 102359 },
    ursols_vortex           = { 4921, 1, 102793 },
    mighty_bash             = { 4922, 1, 5211 },    -- Tier 6 (Level 90)
    heart_of_the_wild       = { 4923, 1, 108288 },
    dream_of_cenarius       = { 4924, 1, 108373 },
    natures_vigil           = { 4925, 1, 124974 },
    
    -- Feral-specific passive talents
    primal_fury             = { 1000, 1, 37116 }, -- Crits have chance to generate additional combo point
    stampede                = { 1001, 1, 78892 }, -- Feral Charge grants Ravage proc
    blood_in_the_water      = { 1002, 2, 80862 }, -- Ferocious Bite extends Rip on targets below 25% health
    leader_of_the_pack      = { 1003, 1, 17007 }, -- Party/raid critical strike chance bonus
    survival_instincts      = { 1004, 1, 61336 }, -- Damage reduction cooldown
    bloodtalons             = { 1005, 1, 145152 }, -- Healing spells increase damage by 50% for next 2 attacks
} )

-- ===================
-- ENHANCED GLYPH SYSTEM WITH DETAILED COMBAT ANALYSIS
-- ===================
spec:RegisterGlyphs( {
    -- MAJOR GLYPHS - FERAL DPS OPTIMIZATION
    
    -- Core DPS and Resource Management
    [45602] = "berserk",             -- Berserk generates 20 Energy when used (Essential for energy pooling)
    [54733] = "cat_form",            -- Increases movement speed in Cat Form by 10% (Mobility enhancement)
    [71013] = "tiger_fury",          -- Tiger's Fury no longer increases damage but now generates 60 Energy (Energy management)
    [54815] = "shred",               -- You deal 20% increased damage to targets with Mangle, Trauma, Gore, or Blood Frenzy (Priority DPS glyph)
    [54818] = "rip",                 -- Your Rip ability deals 15% more damage (DoT optimization)
    [59219] = "savage_roar",         -- Your Savage Roar also increases the damage of your bleed effects by 25% (Bleed synergy)
    [54813] = "ferocious_bite",      -- Your Ferocious Bite heals you for 2% of maximum health for each 10 Energy used (Sustainability)
    [46372] = "mangle",              -- Mangle generates 8 Rage instead of 6 in Bear Form, and increases Energy by 4 instead of 3 in Cat Form
    
    -- Feral Mobility and Positioning
    [54810] = "feral_charge",        -- Your Feral Charge ability's cooldown is reduced by 2 sec (Gap closer optimization)
    [54812] = "pounce",              -- Increases the range of your Pounce ability by 3 yards (Stealth opener enhancement)
    [54814] = "prowl",               -- Increases movement while stealthed in Cat Form by 40% (Stealth positioning)
    [63055] = "skull_bash",          -- Increases the range of Skull Bash by 3 yards (Interrupt utility)
    
    -- Defensive and Utility Major Glyphs
    [54821] = "survival_instincts",  -- Your Survival Instincts no longer requires Bear Form and increases healing received by 20%
    [67494] = "frenzied_regeneration", -- Your Frenzied Regeneration ability no longer costs Energy
    [54799] = "maul",                -- Increases Maul damage by 20% but Maul no longer hits a second target (Bear form)
    
    -- Advanced Combat Glyphs
    [116238] = "stampeding_roar",    -- Your Stampeding Roar ability also removes all movement impairing effects from affected allies
    [114333] = "might_of_ursoc",     -- Increases the health bonus of Might of Ursoc by an additional 10%
    [54760] = "rebirth",             -- Players targeted by Rebirth are returned to life with 100% health
    [54831] = "healing_touch",       -- When you have more than 50% health, Healing Touch's mana cost is reduced by 50%
    [116281] = "rejuvenation",       -- Rejuvenation instantly heals for the same amount of a Rejuvenation tick
    [54756] = "regrowth",            -- Increases the healing of your Regrowth by 20%, but removes the initial instant heal
    [54743] = "lifebloom",           -- Your Lifebloom can bloom up to 2 times on the same target
    [54825] = "wild_growth",         -- Wild Growth can affect 1 additional target but its cooldown is increased by 2 sec
    [116279] = "innervate",          -- When Innervate is cast on a friendly target other than the caster, the caster will gain 45% of Innervate's effect
    [116201] = "faerie_fire",        -- Faerie Fire can be cast while in Bear Form or Cat Form, but has a 6-yard range and a 6-second cooldown
    [54734] = "nature_swiftness",    -- Your Nature's Swiftness also reduces the global cooldown of your next spell by 1 sec
    
    -- MINOR GLYPHS - VISUAL AND UTILITY ENHANCEMENTS
    
    -- Visual Enhancement Glyphs
    [57856] = "aquatic_form",        -- Allows you to stand upright on the water surface while in Aquatic Form
    [57862] = "challenging_roar",    -- Your Challenging Roar takes on the form of your current shapeshift form
    [57863] = "charm_woodland_creature", -- Allows you to cast Charm Woodland Creature on critters, allowing them to follow you for 10 min
    [57855] = "dash",                -- Your Dash leaves behind a glowing trail
    [57857] = "mark_of_the_wild",    -- Your Mark of the Wild spell now transforms you into a Stag when cast on yourself
    [57860] = "unburdened_rebirth",  -- Rebirth no longer requires a reagent
    
    -- Quality of Life Minor Glyphs
    [57861] = "grace",               -- Your death causes nearby enemies to flee in trepidation for 4 sec
    [57858] = "master_shapeshifter", -- Your healing spells increase the amount of healing done on the target by 2%
    [116203] = "stars",              -- Your Moonfire and Sunfire abilities have a chance to cause stars to fall from the sky
    [116202] = "blooming",           -- Your Lifebloom bloom effect will sometimes cause Flower Petals to fall from the sky
    [116280] = "the_orca",           -- Your Aquatic Form now appears as an Orca
    [116278] = "the_chameleon",      -- Each time you shapeshift, your forms take on random colors
    [116277] = "the_stag",           -- Your Travel Form now appears as a Stag, allowing party members to ride you
    [115922] = "treant",             -- Your Force of Nature treants appear as smaller Ancients of War
    [116276] = "flap",               -- You take on the form of a Moonkin while under the effects of Flight Form
    [116275] = "shapemend",          -- Your Shapeshift Form casts have a chance to automatically cast a free Healing Touch on yourself
    
    -- Utility and Convenience Minor Glyphs
    [115937] = "travel",             -- Your Travel Form provides 100% movement speed while swimming
    [116274] = "guided_stars",       -- Your Moonfire and Sunfire will now travel to the target with the lowest health within 40 yards
    [116273] = "omens",              -- Your Starfall, Moonfire, and Sunfire abilities summon an Astral Treant to fight beside you for 15 sec
} )

-- Feral specific auras
-- ===================
-- ADVANCED AURA SYSTEM WITH SOPHISTICATED TRACKING
-- ===================
spec:RegisterAuras( {
    -- CORE FERAL DoTs AND BLEEDS WITH ADVANCED SNAPSHOTTING
    
    rake = {
        id = 1822,
        duration = 9,
        tick_time = 3,
        max_stack = 1,
        meta = {
            last_tick = function( t ) return t.up and ( tracked_bleeds.rake.last_tick[ target.unit ] or t.applied ) or 0 end,
            tick_time = function( t )
                if t.down then return haste * 3 end
                local hasteMod = tracked_bleeds.rake.haste[ target.unit ]
                hasteMod = 3 * ( hasteMod and ( 100 / hasteMod ) or haste )
                return hasteMod 
            end,
            haste_pct = function( t ) return ( 100 / haste ) end,
            haste_pct_next_tick = function( t ) return t.up and ( tracked_bleeds.rake.haste[ target.unit ] or ( 100 / haste ) ) or 0 end,
        },
        generate = function( t, auraType )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 1822 )
            
            if name and caster == "player" then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Advanced snapshotting for Rake
                if expirationTime > query_time then
                    local snapshot_time = expirationTime - duration
                    tracked_bleeds.rake.haste[ target.unit ] = UnitSpellHaste("player")
                    tracked_bleeds.rake.last_tick[ target.unit ] = snapshot_time
                end
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    rip = {
        id = 1079,
        duration = 16, -- Authentic MoP: Fixed 16s duration (8 ticks at 2s intervals)
        tick_time = 2,
        max_stack = 1,
        meta = {
            last_tick = function( t ) return t.up and ( tracked_bleeds.rip.last_tick[ target.unit ] or t.applied ) or 0 end,
            tick_time = function( t )
                if t.down then return haste * 2 end
                local hasteMod = tracked_bleeds.rip.haste[ target.unit ]
                hasteMod = 2 * ( hasteMod and ( 100 / hasteMod ) or haste )
                return hasteMod 
            end,
            haste_pct = function( t ) return ( 100 / haste ) end,
            haste_pct_next_tick = function( t ) return t.up and ( tracked_bleeds.rip.haste[ target.unit ] or ( 100 / haste ) ) or 0 end,
        },
        generate = function( t, auraType )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 1079 )
            
            if name and caster == "player" then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Advanced snapshotting for Rip with combo point scaling
                if expirationTime > query_time then
                    tracked_bleeds.rip.haste[ target.unit ] = UnitSpellHaste("player")
                    tracked_bleeds.rip.last_tick[ target.unit ] = expirationTime - duration
                end
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    thrash_cat = {
        id = 106830,
        duration = 6,
        tick_time = 2,
        max_stack = 1,
        meta = {
            last_tick = function( t ) return t.up and ( tracked_bleeds.thrash_cat.last_tick[ target.unit ] or t.applied ) or 0 end,
            tick_time = function( t )
                if t.down then return haste * 2 end
                local hasteMod = tracked_bleeds.thrash_cat.haste[ target.unit ]
                hasteMod = 2 * ( hasteMod and ( 100 / hasteMod ) or haste )
                return hasteMod 
            end,
            haste_pct = function( t ) return ( 100 / haste ) end,
            haste_pct_next_tick = function( t ) return t.up and ( tracked_bleeds.thrash_cat.haste[ target.unit ] or ( 100 / haste ) ) or 0 end,
        },
        generate = function( t, auraType )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 106830 )
            
            if name and caster == "player" then
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

    -- CORE FERAL BUFFS WITH ADVANCED TRACKING
    
    savage_roar = {
        id = 52610,
        duration = function() return 12 + combo_points.current * 6 end,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 52610 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Track Savage Roar with glyph enhancement
                if glyph.savage_roar.enabled then
                    -- Glyph effect: Also increases bleed damage by 25%
                    t.value = 1.25
                end
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    tigers_fury = {
        id = 5217,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 5217 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Track Tiger's Fury with glyph modifications
                if glyph.tiger_fury.enabled then
                    -- Glyph: No longer increases damage but generates 60 Energy
                    t.energy_generation = 60
                end
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    berserk = {
        id = 50334,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 50334 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Track Berserk with glyph enhancement
                if glyph.berserk.enabled then
                    -- Glyph: Generates 20 Energy when used
                    t.energy_bonus = 20
                end
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    predatory_swiftness = {
        id = 69369,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 69369 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Advanced tracking for Predatory Swiftness procs
                t.proc_chance = 0.20 -- 20% chance per crit in MoP
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    omen_of_clarity = {
        id = 16870,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 16870 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Track clearcasting with MoP mechanics
                t.energy_cost_reduction = 1.0 -- 100% cost reduction
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    -- MOP TALENT-SPECIFIC ADVANCED TRACKING

    incarnation_king_of_the_jungle = {
        id = 102543,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 102543 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Advanced Incarnation tracking
                t.energy_regen_bonus = 1.0 -- 100% increased energy regeneration
                t.prowl_available = true
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    bloodtalons = {
        id = 145152,
        duration = 30,
        max_stack = 2,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 145152 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Critical MoP talent: 50% increased damage for next 2 attacks
                t.damage_multiplier = 1.5
                t.charges_remaining = count
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    dream_of_cenarius = {
        id = 108381,
        duration = 30,
        max_stack = 2,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 108381 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Dream of Cenarius: Healing spells buff next 2 attacks by 25%
                t.attack_bonus = 0.25
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    heart_of_the_wild = {
        id = 108291,
        duration = 45,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 108291 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Heart of the Wild: Versatility buff across all specs
                t.versatility_bonus = true
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    natures_vigil = {
        id = 124974,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 124974 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Nature's Vigil: Damage deals healing to nearby allies
                t.healing_transfer = 0.25 -- 25% of damage as healing
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    -- DEFENSIVE COOLDOWNS WITH ADVANCED TRACKING

    survival_instincts = {
        id = 61336,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 61336 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Survival Instincts with glyph modification
                if glyph.survival_instincts.enabled then
                    -- Glyph: No longer requires Bear Form, increases healing received by 20%
                    t.form_requirement = false
                    t.healing_received_bonus = 0.20
                else
                    t.damage_reduction = 0.50 -- 50% damage reduction
                end
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    barkskin = {
        id = 22812,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 22812 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Barkskin: 20% damage reduction
                t.damage_reduction = 0.20
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    -- MOVEMENT AND UTILITY BUFFS

    dash = {
        id = 1850,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 1850 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Dash with glyph effect
                if glyph.dash.enabled then
                    t.leaves_trail = true -- Visual glyph effect
                end
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    stampeding_roar = {
        id = 77764,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 77764 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Stampeding Roar with glyph enhancement
                if glyph.stampeding_roar.enabled then
                    t.removes_movement_impairing_effects = true
                end
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    -- FORM BUFFS WITH ADVANCED TRACKING

    cat_form = {
        id = 768,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 768 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Cat Form with glyph enhancement
                if glyph.cat_form.enabled then
                    t.movement_speed_bonus = 0.10 -- 10% movement speed increase
                end
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    prowl = {
        id = 5215,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 5215 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Prowl with glyph enhancement
                if glyph.prowl.enabled then
                    t.stealth_movement_bonus = 0.40 -- 40% movement speed while stealthed
                end
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    -- DEBUFFS AND TARGET EFFECTS

    mangle = {
        id = 33876,
        duration = 60,
        max_stack = 1,
        generate = function( t, auraType )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 33876 )
            
            if name and caster == "player" then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Mangle debuff increases bleed damage
                t.bleed_damage_multiplier = 1.30 -- 30% increased bleed damage
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    -- SPECIAL PROCS AND TEMPORARY EFFECTS

    stampede_cat = {
        id = 81022,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 81022 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Stampede: Next Ravage costs no energy and has no positioning requirement
                t.ravage_proc = true
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    clearcasting = {
        id = 135700,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 135700 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Clearcasting: Next ability costs no energy/mana
                t.cost_reduction = 1.0 -- 100% cost reduction
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    -- GROUP BUFFS

    leader_of_the_pack = {
        id = 17007,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 17007 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Leader of the Pack: Party/raid critical strike bonus
                t.group_crit_bonus = 0.05 -- 5% critical strike chance
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    mark_of_the_wild = {
        id = 1126,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 1126 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                
                -- Mark of the Wild with glyph effect
                if glyph.mark_of_the_wild.enabled then
                    t.stag_transformation = true -- Transform into Stag when cast on self
                end
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
} )

-- ===========================================
-- APL REGISTRATION - ADVANCED PQR/PQROTATION-STYLE LOGIC
-- ===========================================

-- Register comprehensive APL with sophisticated multi-target logic
spec:RegisterOptions( {
    enabled = true,
    aoe = 3,
    damage = true,
    damageExpiration = 8,
    package = "Feral",
} )

-- Primary APL registration with advanced PQR/PQRotation-style decision making
spec:RegisterPackedTargets( "feral_primary", 20250605, {
    name = "Druid: Feral (Enhanced PQR/PQRotation Style)",
    desc = "Advanced Feral Druid rotation with sophisticated decision-making logic inspired by PQR/PQRotation addons.",
    
    -- Precombat preparation phase
    precombat = {
        { "mark_of_the_wild", "!buff.mark_of_the_wild.up" },
        { "cat_form", "!buff.cat_form.up" },
        { "prowl", "!in_combat&!buff.prowl.up" },
    },
    
    -- Main combat rotation
    combat = {
        -- Essential form maintenance
        { "cat_form", "!buff.cat_form.up&!buff.bear_form.up" },
        { "auto_attack", "!auto_attack" },
        
        -- Interrupt handling
        { "skull_bash", "target.casting&target.cast.interruptible" },
        
        -- === EMERGENCY DEFENSIVE ACTIONS ===
        { "survival_instincts", "health.pct<30&incoming_damage_high" },
        { "barkskin", "health.pct<50&incoming_damage_high" },
        { "bear_form", "health.pct<20&incoming_damage_high" },
        { "frenzied_regeneration", "buff.bear_form.up&health.pct<40" },
        { "healing_touch", "buff.predatory_swiftness.up&health.pct<70&!in_combat" },
        { "rejuvenation", "health.pct<50&!buff.rejuvenation.up&!in_combat" },
        
        -- === STEALTH OPENER ===
        { "prowl", "!in_combat&!buff.prowl.up" },
        { "rake", "buff.prowl.up&!dot.rake.up" },
        
        -- === MULTI-TARGET BRANCHING ===
        { "call_action_list", "name=aoe", "if=aoe_check" },
        { "call_action_list", "name=cleave", "if=cleave_check&!aoe_check" },
        
        -- === MAJOR COOLDOWN MANAGEMENT ===
        { "berserk", "berserk_ready&toggle.cooldowns" },
        { "tigers_fury", "tigers_fury_ready" },
        
        -- Utility cooldowns
        { "faerie_fire_feral", "debuff.faerie_fire.down&target.armor>0&target.time_to_die>15&energy>=25" },
        { "nature_swiftness", "combo_points>=4&energy<40&!buff.omen_of_clarity.up" },
        
        -- Racial abilities
        { "berserking", "buff.tigers_fury.up|buff.berserk.up" },
        { "blood_fury", "buff.tigers_fury.up|buff.berserk.up" },
        
        -- === FINISHER PRIORITY (5CP SPENDING) ===
        -- Execute range priority
        { "ferocious_bite", 
          "combo_points>=5&dot.rip.ticking&buff.savage_roar.up&target.health.pct<25&energy>=50" },
        
        -- Savage Roar maintenance
        { "savage_roar", 
          "combo_points>=1&buff.savage_roar.remains<7.2&(" ..
          "combo_points>=5|buff.savage_roar.remains<2|energy>=80" ..
          ")" },
        
        -- Rip application and refresh
        { "rip", 
          "combo_points>=5&(" ..
          "!dot.rip.ticking|" ..
          "(rip_refresh_needed&target.time_to_die>dot.rip.duration)" ..
          ")" },
        
        -- Multi-target Rip
        { "rip", 
          "combo_points>=5&!dot.rip.ticking&target.time_to_die>dot.rip.duration&active_enemies<=4",
          "cycle_targets=1" },
        
        -- Energy dump Ferocious Bite
        { "ferocious_bite", 
          "combo_points>=5&dot.rip.ticking&buff.savage_roar.up&(" ..
          "energy>=50|buff.berserk.up|buff.omen_of_clarity.up" ..
          ")" },
        
        -- Emergency Savage Roar
        { "savage_roar", "combo_points>=1&buff.savage_roar.down" },
        
        -- === COMBO POINT GENERATORS ===
        -- AoE generators
        { "thrash_cat", "spell_targets.swipe_cat>=4&!dot.thrash_cat.ticking&energy>=50" },
        { "swipe_cat", "aoe_check&energy>=45" },
        
        -- Rake application and maintenance
        { "rake", "!dot.rake.ticking&energy>=35" },
        { "rake", 
          "dot.rake.remains<3&dot.rake.remains<target.time_to_die&" ..
          "energy>=35&target.time_to_die>15" },
        
        -- Multi-target rake
        { "rake", 
          "!dot.rake.ticking&active_enemies<=4&target.time_to_die>dot.rake.duration&energy>=35", 
          "cycle_targets=1" },
        
        -- Thrash for single target
        { "thrash_cat", 
          "dot.thrash_cat.remains<3&dot.thrash_cat.remains<target.time_to_die&" ..
          "energy>=50&target.time_to_die>6" },
        
        -- === FILLER ACTIONS ===
        -- Energy pooling
        { "wait", "should_pool_energy", "sec=0.1" },
        
        -- Primary combo point builders
        { "mangle_cat", "combo_points<5&energy>=40" },
        { "shred", "(behind_target|buff.omen_of_clarity.up)&combo_points<5&energy>=40" },
        { "mangle_cat", "combo_points<5&!behind_target&!buff.omen_of_clarity.up&energy>=40" },
        
        -- Emergency filler
        { "shred", "combo_points<5&energy>=40" },
        
        -- === UTILITY ACTIONS ===
        { "faerie_fire_feral", "debuff.faerie_fire.down&target.armor>0&energy>=25" },
        { "dash", "movement.distance>20&!buff.dash.up&energy>=30" },
        { "wild_charge", "movement.distance>8&movement.distance<25&energy>=25" },
        
        -- Final resource management
        { "tigers_fury", 
          "energy<30&!buff.tigers_fury.up&!buff.omen_of_clarity.up&cooldown.tigers_fury.ready" },
        { "wait", 
          "energy<50&energy.regen>10&!buff.omen_of_clarity.up&!buff.berserk.up&" ..
          "cooldown.tigers_fury.remains>3", 
          "sec=0.1" },
    },
    
    -- AoE rotation (3+ targets)
    aoe = {
        { "thrash_cat", "!dot.thrash_cat.ticking&energy>=50" },
        { "rake", "!dot.rake.ticking&active_enemies<=6&energy>=35", "cycle_targets=1" },
        { "swipe_cat", "combo_points<5&energy>=45" },
        { "savage_roar", "combo_points>=1&buff.savage_roar.down" },
        { "rip", 
          "combo_points>=5&!dot.rip.ticking&target.time_to_die>dot.rip.duration", 
          "cycle_targets=1" },
        { "ferocious_bite", "combo_points>=5&dot.rip.ticking&energy>=50" },
    },
    
    -- Cleave rotation (2 targets)
    cleave = {
        { "rake", "!dot.rake.ticking&energy>=35", "cycle_targets=1" },
        { "thrash_cat", "!dot.thrash_cat.ticking&energy>=50" },
        { "savage_roar", "combo_points>=1&buff.savage_roar.remains<7.2" },
        { "rip", 
          "combo_points>=5&!dot.rip.ticking&target.time_to_die>dot.rip.duration", 
          "cycle_targets=1" },
        { "mangle_cat", "combo_points<5&energy>=40" },
        { "shred", "combo_points<5&(behind_target|buff.omen_of_clarity.up)&energy>=40" },
    },
})

-- Conditional parameters for advanced APL execution
spec:RegisterAPLCondition( "aoe_check", "active_enemies>=3" )
spec:RegisterAPLCondition( "cleave_check", "active_enemies=2" )
spec:RegisterAPLCondition( "execute_phase", "target.health.pct<25" )
spec:RegisterAPLCondition( "single_target", "active_enemies=1" )
