-- DruidFeral.lua
--july 2025 by smufrik
-- DruidFeral.lua loading

-- MoP: Use UnitClass instead of UnitClassBase

local _, playerClass = UnitClass('player')
if playerClass ~= 'DRUID' then 
    -- Not a druid, exiting DruidFeral.lua
    return 
end
-- Druid detected, continuing DruidFeral.lua loading

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format

local spec = Hekili:NewSpecialization(103, true)

spec.name = "Feral"
spec.role = "DAMAGER"
spec.primaryStat = 2 -- Agility

-- Use MoP power type numbers instead of Enum
-- Energy = 3, ComboPoints = 4, Rage = 1, Mana = 0 in MoP Classic
spec:RegisterResource( 3 ) -- Energy
spec:RegisterResource( 4 ) -- ComboPoints 
spec:RegisterResource( 1 ) -- Rage
spec:RegisterResource( 0 ) -- Mana


-- Add reset_precast hook for state management and form checking
spec:RegisterHook( "reset_precast", function()
    -- Set safe default values to avoid errors
    local current_form = GetShapeshiftForm() or 0
    local current_energy = -1
    local current_cp = -1
    
    -- Safely access resource values using the correct state access pattern
    if state.energy then
        current_energy = state.energy.current or -1
    end
    if state.combo_points then
        current_cp = state.combo_points.current or -1
    end
    
    -- Fallback to direct API calls if state resources are not available
    if current_energy == -1 then
        current_energy = UnitPower("player", 3) or 0 -- Energy = power type 3
    end
    if current_cp == -1 then
        current_cp = UnitPower("player", 4) or 0 -- ComboPoints = power type 4
    end
    
    local cat_form_up = "nej"

    -- Hantera form-buffen
    if current_form == 3 then -- Cat Form
        applyBuff( "cat_form" )
        cat_form_up = "JA"
    else
        removeBuff( "cat_form" )
    end
end )

-- Additional debugging hook for when recommendations are generated
spec:RegisterHook( "runHandler", function( ability )
    -- Only log critical issues
    if not ability then
        -- Nil ability passed to runHandler
        return
    end
end )

-- Debug hook to check state at the beginning of each update cycle
spec:RegisterHook( "reset", function()
    -- Minimal essential verification
    if not state or not state.spec or state.spec.id ~= 103 then
        return
    end
    
    -- Basic state verification - level check
    if level and level < 10 then
        return
    end
end )

-- Talents - MoP compatible talent structure
-- Using tier/column system instead of retail IDs
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility
    feline_swiftness = { 1, 1, 1 }, -- Tier 1, Column 1
    displacer_beast  = { 1, 2, 1 }, -- Tier 1, Column 2  
    wild_charge      = { 1, 3, 1 }, -- Tier 1, Column 3

    -- Tier 2 (Level 30) - Healing/Utility
    yseras_gift      = { 2, 1, 1 }, -- Tier 2, Column 1
    renewal          = { 2, 2, 1 }, -- Tier 2, Column 2
    cenarion_ward    = { 2, 3, 1 }, -- Tier 2, Column 3

    -- Tier 3 (Level 45) - Crowd Control
    faerie_swarm         = { 3, 1, 1 }, -- Tier 3, Column 1
    mass_entanglement    = { 3, 2, 1 }, -- Tier 3, Column 2
    typhoon              = { 3, 3, 1 }, -- Tier 3, Column 3

    -- Tier 4 (Level 60) - Specialization Enhancement
    soul_of_the_forest   = { 4, 1, 1 }, -- Tier 4, Column 1
    incarnation_king_of_the_jungle = { 4, 2, 1 }, -- Tier 4, Column 2
    force_of_nature      = { 4, 3, 1 }, -- Tier 4, Column 3

    -- Tier 5 (Level 75) - Disruption
    disorienting_roar    = { 5, 1, 1 }, -- Tier 5, Column 1
    ursols_vortex        = { 5, 2, 1 }, -- Tier 5, Column 2
    mighty_bash          = { 5, 3, 1 }, -- Tier 5, Column 3

    -- Tier 6 (Level 90) - Major Enhancement
    heart_of_the_wild    = { 6, 1, 1 }, -- Tier 6, Column 1
    dream_of_cenarius    = { 6, 2, 1 }, -- Tier 6, Column 2
    natures_vigil        = { 6, 3, 1 }, -- Tier 6, Column 3
} )



-- Ticks gained on refresh (MoP version).
local tick_calculator = setfenv( function( t, action, pmult )
    local state = _G["Hekili"] and _G["Hekili"].State or {}
    local remaining_ticks = 0
    local potential_ticks = 0
    local remains = t.remains
    local tick_time = t.tick_time
    local ttd = min( state.fight_remains or 300, state.target and state.target.time_to_die or 300 )

    local aura = action
    if action == "primal_wrath" then aura = "rip" end

    local class = _G["Hekili"] and _G["Hekili"].Class or {}
    local duration = class.auras and class.auras[ aura ] and class.auras[ aura ].duration or 0
    local app_duration = min( ttd, duration )
    local app_ticks = app_duration / tick_time

    remaining_ticks = min( remains, ttd ) / tick_time
    duration = max( 0, min( remains + duration, 1.3 * duration, ttd ) )
    potential_ticks = min( duration, ttd ) / tick_time

    if action == "thrash" then aura = "thrash" end

    return max( 0, potential_ticks - remaining_ticks )
end, {} )

-- Auras
spec:RegisterAuras( {
    faerie_fire = {
        id = 770, -- Faerie Fire (unified in MoP)
        duration = 40,
        max_stack = 1,
        name = "Faerie Fire",
    },
    -- challenging_roar = {
    --     id = 5209, -- Challenging Roar (not available to Feral in MoP)
    --     duration = 6,
    --     max_stack = 1,
    --     name = "Challenging Roar",
    -- },
    jungle_stalker = {
        id = 0, -- Dummy ID for Jungle Stalker tracking
        duration = 15,
        max_stack = 1,
    },
    bs_inc = {
        id = 0, -- Dummy ID for Berserk/Incarnation tracking
        duration = 15,
        max_stack = 1,
    },
    omen_of_clarity = {
        id = 16864,
        duration = 15,
        max_stack = 1,
    },
    savage_roar = {
        id = 52610,
        duration = function() return 12 + (combo_points.current * 6) end, -- MoP: 12s + 6s per combo point
        max_stack = 1,
    },
    rejuvenation = {
        id = 774,
        duration = 12,
        type = "Magic",
        max_stack = 1,
    },
    armor = {
        id = 0, -- Placeholder for armor debuff
        duration = 0,
        max_stack = 1,
    },
    mark_of_the_wild = {
        id = 1126,
        duration = 3600,
        max_stack = 1,
    },
    -- MoP/Classic aura IDs and durations

    aquatic_form = {
        id = 1066,
        duration = 3600,
        max_stack = 1,
    },
    bear_form = {
        id = 5487,
        duration = 3600,
        type = "Magic",
        max_stack = 1
    },
    berserk = {
        id = 106951,
        duration = 15,
        max_stack = 1,
        copy = { 106951, "berserk_cat" },
        multiplier = 1.5,
    },
    -- Bloodtalons removed (not in MoP)
    cat_form = {
        id = 768,
        duration = 3600,
        type = "Magic",
        max_stack = 1
    },
    cenarion_ward = {
        id = 102351,
        duration = 30,
        max_stack = 1
    },
    clearcasting = {
        id = 16870,
        duration = 15,
        type = "Magic",
        max_stack = 1,
        multiplier = 1,
    },
    dash = {
        id = 1850,
        duration = 15,
        type = "Magic",
        max_stack = 1
    },
    entangling_roots = {
        id = 339,
        duration = 30,
        mechanic = "root",
        type = "Magic",
        max_stack = 1
    },
    frenzied_regeneration = {
        id = 22842,
        duration = 6,
        max_stack = 1,
    },
    growl = {
        id = 6795,
        duration = 3,
        mechanic = "taunt",
        max_stack = 1
    },
    heart_of_the_wild = {
        id = 108292,
        duration = 45,
        type = "Magic",
        max_stack = 1,
    },
    hibernate = {
        id = 2637,
        duration = 40,
        mechanic = "sleep",
        type = "Magic",
        max_stack = 1
    },
    incapacitating_roar = {
        id = 99,
        duration = 3,
        mechanic = "incapacitate",
        max_stack = 1
    },
    infected_wounds = {
        id = 58180,
        duration = 12,
        type = "Disease",
        max_stack = 1,
    },
    innervate = {
        id = 29166,
        duration = 10,
        type = "Magic",
        max_stack = 1
    },
    ironfur = {
        id = 192081,
        duration = 7,
        type = "Magic",
        max_stack = 1
    },
    maim = {
        id = 22570,
        duration = function() return 1 + combo_points.current end,
        max_stack = 1,
    },
    mass_entanglement = {
        id = 102359,
        duration = 20,
        tick_time = 2.0,
        mechanic = "root",
        type = "Magic",
        max_stack = 1
    },
    mighty_bash = {
        id = 5211,
        duration = 5,
        mechanic = "stun",
        max_stack = 1
    },
    moonfire = {
        id = 8921,
        duration = 16,
        tick_time = 2,
        type = "Magic",
        max_stack = 1
    },
    moonkin_form = {
        id = 24858,
        duration = 3600,
        type = "Magic",
        max_stack = 1
    },
    predatory_swiftness = {
        id = 69369,
        duration = 8,
        type = "Magic",
        max_stack = 1,
    },
    prowl_base = {
        id = 5215,
        duration = 3600,
        max_stack = 1,
        multiplier = 1.6,
    },
    prowl = {
        alias = { "prowl_base" },
        aliasMode = "first",
        aliasType = "buff",
        duration = 3600,
        max_stack = 1
    },
    rake = {
        id = 1822, -- Correct Rake ID for MoP
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 1,
    },
    regrowth = {
        id = 8936,
        duration = 12,
        type = "Magic",
        max_stack = 1
    },
    rejuvenation_germination = {
        id = 155777,
        duration = 12,
        type = "Magic",
        max_stack = 1
    },
    rip = {
        id = 1079,
        duration = function () return 4 + ( combo_points.current * 4 ) end,
        tick_time = 2,
        mechanic = "bleed",
        max_stack = 1,
    },
    shadowmeld = {
        id = 58984,
        duration = 10,
        max_stack = 1,
    },
    sunfire = {
        id = 93402,
        duration = 12,
        type = "Magic",
        max_stack = 1
    },
    survival_instincts = {
        id = 61336,
        duration = 6,
        max_stack = 1
    },
    thrash_bear = {
        id = 77758,
        duration = 15,
        tick_time = 3,
        max_stack = 1,
    },
    thrash_cat = {
        id = 106830,
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 1,
    },
    tiger_dash = {
        id = 252216,
        duration = 5,
        type = "Magic",
        max_stack = 1
    },
    tigers_fury = {
        id = 5217,
        duration = 8, -- MoP: 8s duration
        multiplier = 1.15,
    },
    travel_form = {
        id = 783,
        duration = 3600,
        type = "Magic",
        max_stack = 1
    },
    typhoon = {
        id = 61391,
        duration = 6,
        type = "Magic",
        max_stack = 1
    },
    ursols_vortex = {
        id = 102793,
        duration = 10,
        type = "Magic",
        max_stack = 1
    },
    wild_charge = {
        id = 102401,
        duration = 0.5,
        max_stack = 1
    },
    wild_growth = {
        id = 48438,
        duration = 7,
        type = "Magic",
        max_stack = 1
    },
} )





-- Tweaking for new Feral APL.
local rip_applied = false

spec:RegisterEvent( "PLAYER_REGEN_ENABLED", function ()
    rip_applied = false
end )

-- Event handler to ensure Feral spec is enabled  
spec:RegisterEvent( "PLAYER_ENTERING_WORLD", function ()
    if state.spec.id == 103 then
        -- Ensure the spec is enabled in the profile
        if Hekili.DB and Hekili.DB.profile and Hekili.DB.profile.specs then
            if not Hekili.DB.profile.specs[103] then
                Hekili.DB.profile.specs[103] = {}
            end
            Hekili.DB.profile.specs[103].enabled = true
            
            -- Set default package if none exists
            if not Hekili.DB.profile.specs[103].package then
                Hekili.DB.profile.specs[103].package = "Feral"
            end
        end
    end
end )

--[[spec:RegisterStateExpr( "opener_done", function ()
    return rip_applied
end )--]]

-- Bloodtalons combat log and state tracking removed for MoP

spec:RegisterStateFunction( "break_stealth", function ()
    removeBuff( "shadowmeld" )
    if buff.prowl.up then
        setCooldown( "prowl", 6 )
        removeBuff( "prowl" )
    end
end )

-- Function to remove any form currently active.
spec:RegisterStateFunction( "unshift", function()
    if conduit.tireless_pursuit and conduit.tireless_pursuit.enabled and ( buff.cat_form.up or buff.travel_form.up ) then applyBuff( "tireless_pursuit" ) end

    removeBuff( "cat_form" )
    removeBuff( "bear_form" )
    removeBuff( "travel_form" )
    removeBuff( "moonkin_form" )
    removeBuff( "travel_form" )
    removeBuff( "aquatic_form" )
    removeBuff( "stag_form" )

    -- MoP: No Oath of the Elder Druid legendary or Restoration Affinity in MoP.
end )

local affinities = {
    bear_form = "guardian_affinity",
    cat_form = "feral_affinity",
    moonkin_form = "balance_affinity",
}

-- Function to apply form that is passed into it via string.
spec:RegisterStateFunction( "shift", function( form )
    -- MoP: No tireless_pursuit or wildshape_mastery in MoP.
    removeBuff( "cat_form" )
    removeBuff( "bear_form" )
    removeBuff( "travel_form" )
    removeBuff( "moonkin_form" )
    removeBuff( "aquatic_form" )
    removeBuff( "stag_form" )
    applyBuff( form )
    -- MoP: No Oath of the Elder Druid legendary or Restoration Affinity in MoP.
end )



spec:RegisterHook( "runHandler", function( ability )
    local a = class.abilities[ ability ]

    if not a or a.startsCombat then
        break_stealth()
    end
end )

spec:RegisterHook( "gain", function( amt, resource, overflow )
    if overflow == nil then overflow = true end
    if amt > 0 and resource == "combo_points" then
    end

end )





local combo_generators = {
    rake              = true,
    shred             = true,
    swipe_cat         = true,
    thrash_cat        = true
}



spec:RegisterStateTable( "druid", setmetatable( {},{
    __index = function( t, k )
        if k == "catweave_bear" then return false
        elseif k == "owlweave_bear" then return false
        elseif k == "owlweave_cat" then
            return false -- MoP: No Balance Affinity
        elseif k == "no_cds" then return not toggle.cooldowns
        -- MoP: No Primal Wrath or Lunar Inspiration
        elseif k == "primal_wrath" then return false
        elseif k == "lunar_inspiration" then return false
        elseif k == "delay_berserking" then return state.settings.delay_berserking
        elseif debuff[ k ] ~= nil then return debuff[ k ]
        end
    end
} ) )

-- MoP: Bleeding only considers Rake, Rip, and Thrash Cat (no Thrash Bear for Feral).
spec:RegisterStateExpr( "bleeding", function ()
    return debuff.rake.up or debuff.rip.up or debuff.thrash_cat.up
end )

-- MoP: Effective stealth is only Prowl or Incarnation (no Shadowmeld for snapshotting in MoP).
spec:RegisterStateExpr( "effective_stealth", function ()
    return buff.prowl.up or ( buff.incarnation and buff.incarnation.up )
end )

-- Essential state expressions for APL functionality
spec:RegisterStateExpr( "time_to_die", function ()
    return target.time_to_die or 300
end )

spec:RegisterStateExpr( "spell_targets", function ()
    return active_enemies or 1
end )



spec:RegisterStateExpr( "energy_deficit", function ()
    return energy.max - energy.current
end )

spec:RegisterStateExpr( "energy_time_to_max", function ()
    return energy.deficit / energy.regen
end )

spec:RegisterStateExpr( "cp_max_spend", function ()
    return combo_points.current >= 5 or ( combo_points.current >= 4 and buff.savage_roar.remains < 2 )
end )

spec:RegisterStateExpr( "time_to_pool", function ()
    local deficit = energy.max - energy.current
    if deficit <= 0 then return 0 end
    return deficit / energy.regen
end )

-- State expression to check if we can make recommendations
spec:RegisterStateExpr( "can_recommend", function ()
    return state.spec and state.spec.id == 103 and level >= 10
end )

-- Essential state expressions for APL functionality
spec:RegisterStateExpr( "current_energy", function ()
    return energy.current or 0
end )

spec:RegisterStateExpr( "current_combo_points", function ()
    return combo_points.current or 0
end )

spec:RegisterStateExpr( "max_energy", function ()
    return energy.max or 100
end )

spec:RegisterStateExpr( "energy_regen", function ()
    return energy.regen or 10
end )

spec:RegisterStateExpr( "in_combat", function ()
    return combat > 0
end )

spec:RegisterStateExpr( "player_level", function ()
    return level or 85
end )

-- Additional essential state expressions for APL compatibility
spec:RegisterStateExpr( "cat_form", function ()
    return buff.cat_form.up
end )

spec:RegisterStateExpr( "bear_form", function ()
    return buff.bear_form.up
end )

spec:RegisterStateExpr( "health_pct", function ()
    return health.percent or 100
end )

spec:RegisterStateExpr( "target_health_pct", function ()
    return target.health.percent or 100
end )

-- MoP Tier Sets

-- Tier 15 (MoP - Throne of Thunder)
spec:RegisterGear( "tier15", 95841, 95842, 95843, 95844, 95845 )
-- 2-piece: Increases the duration of Savage Roar by 6 sec.
spec:RegisterAura( "t15_2pc", {
    id = 138123, -- Custom ID for tracking
    duration = 3600,
    max_stack = 1
} )
-- 4-piece: Your finishing moves have a 10% chance per combo point to grant Tiger's Fury for 3 sec.
spec:RegisterAura( "t15_4pc", {
    id = 138124, -- Custom ID for tracking
    duration = 3,
    max_stack = 1
} )

-- Tier 16 (MoP - Siege of Orgrimmar)
spec:RegisterGear( "tier16", 99155, 99156, 99157, 99158, 99159 )
-- 2-piece: When you use Tiger's Fury, you gain 1 combo point.
spec:RegisterAura( "t16_2pc", {
    id = 145164, -- Custom ID for tracking
    duration = 3600,
    max_stack = 1
} )
-- 4-piece: Finishing moves increase the damage of your next Mangle, Shred, or Ravage by 40%.
spec:RegisterAura( "t16_4pc", {
    id = 145165, -- Custom ID for tracking
    duration = 15,
    max_stack = 1
} )



-- MoP: Update calculate_damage for MoP snapshotting and stat scaling.
local function calculate_damage( coefficient, masteryFlag, armorFlag, critChanceMult )
    local hekili = _G["Hekili"]
    local state = hekili and hekili.State or {}
    local class = hekili and hekili.Class or {}
    
    local feralAura = 1
    local armor = armorFlag and 0.7 or 1
    local crit = 1 + ( (state.stat and state.stat.crit or 0) * 0.01 * ( critChanceMult or 1 ) )
    local mastery = masteryFlag and ( 1 + ((state.stat and state.stat.mastery_value or 0) * 0.01) ) or 1
    local tf = (state.buff and state.buff.tigers_fury and state.buff.tigers_fury.up) and 
               ((class.auras and class.auras.tigers_fury and class.auras.tigers_fury.multiplier) or 1.15) or 1

    return coefficient * (state.stat and state.stat.attack_power or 1000) * crit * mastery * feralAura * armor * tf
end

-- Force reset when Combo Points change, even if recommendations are in progress.
spec:RegisterUnitEvent( "UNIT_POWER_FREQUENT", "player", nil, function( _, _, powerType )
    if powerType == "COMBO_POINTS" then
        Hekili:ForceUpdate( powerType, true )
    end
end )

-- Abilities (MoP version, updated)
spec:RegisterAbilities( {
    -- Debug ability that should always be available for testing
    savage_roar = {
        id = 52610,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 25,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        usable = function() return combo_points.current > 0 and buff.cat_form.up end,
        handler = function()
            applyBuff("savage_roar")
            spend(combo_points.current, "combo_points")
        end,
    },
    mangle_cat = {
        id = 33876,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 35,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        handler = function()
            gain(1, "combo_points")
        end,
    },
    faerie_fire_feral = {
        id = 770,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",
        startsCombat = true,
        handler = function()
            applyDebuff("target", "faerie_fire")
        end,
    },
    mark_of_the_wild = {
        id = 1126,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        startsCombat = false,
        handler = function()
            applyBuff("mark_of_the_wild")
        end,
    },
    healing_touch = {
        id = 5185,
        cast = 2.5,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        spend = 0.1,
        spendType = "mana",
        startsCombat = false,
        handler = function()
            applyBuff("regrowth") -- fallback, as healing_touch is not a HoT
        end,
    },
    frenzied_regeneration = {
        id = 22842,
        cast = 0,
        cooldown = 36,
        gcd = "off",
        school = "physical",
        spend = 10,
        spendType = "rage",
        startsCombat = false,
        form = "bear_form",
        handler = function()
            applyBuff("frenzied_regeneration")
        end,
    },
    -- Barkskin: Reduces all damage taken by 20% for 12 sec. Usable in all forms.
    barkskin = {
        id = 22812,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        school = "nature",
        startsCombat = false,
        handler = function ()
            applyBuff( "barkskin" )
        end
    },

    -- Bear Form: Shapeshift into Bear Form.
    bear_form = {
        id = 5487,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        startsCombat = false,
        essential = true,
        noform = "bear_form",
        handler = function ()
            shift( "bear_form" )
        end,
    },

    -- Berserk: Reduces the cost of all Cat Form abilities by 50% for 15 sec.
    berserk = {
        id = 106951,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        toggle = "cooldowns",
        handler = function ()
            if buff.cat_form.down then shift( "cat_form" ) end
            applyBuff( "berserk" )
        end,
        copy = { "berserk_cat" }
    },

    -- Cat Form: Shapeshift into Cat Form.
    cat_form = {
        id = 768,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        startsCombat = false,
        essential = true,
        noform = "cat_form",
        handler = function ()
            shift( "cat_form" )
        end,
    },

    -- Dash: Increases movement speed by 70% for 15 sec.
    dash = {
        id = 1850,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        school = "physical",
        startsCombat = false,
        handler = function ()
            shift( "cat_form" )
            applyBuff( "dash" )
        end,
    },

    -- Disorienting Roar (MoP talent): Disorients all enemies within 10 yards for 3 sec.
    disorienting_roar = {
        id = 99,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "physical",
        talent = "disorienting_roar",
        startsCombat = true,
        handler = function ()
            applyDebuff( "target", "incapacitating_roar" )
        end,
    },

    -- Entangling Roots: Roots the target in place for 30 sec.
    entangling_roots = {
        id = 339,
        cast = 1.7,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        spend = 0.1,
        spendType = "mana",
        startsCombat = true,
        handler = function ()
            applyDebuff( "target", "entangling_roots" )
        end,
    },

    -- Faerie Swarm (MoP talent): Reduces target's movement speed and prevents stealth.
    faerie_swarm = {
        id = 102355,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        talent = "faerie_swarm",
        startsCombat = true,
        handler = function ()
            -- Debuff application handled elsewhere if needed
        end,
    },

    -- Ferocious Bite: Finishing move that causes Physical damage per combo point.
    ferocious_bite = {
        id = 22568,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = function ()
            return max( 25, min( 35, energy.current ) )
        end,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        usable = function () return combo_points.current > 0 end,
        handler = function ()
            spend( min( 5, combo_points.current ), "combo_points" )
        end,
    },

    -- Growl: Taunts the target to attack you.
    growl = {
        id = 6795,
        cast = 0,
        cooldown = 8,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        form = "bear_form",
        handler = function ()
            applyDebuff( "target", "growl" )
        end,
    },

    -- Incarnation: King of the Jungle (MoP talent): Improved Cat Form for 30 sec.
    incarnation_king_of_the_jungle = {
        id = 102543,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",
        talent = "incarnation_king_of_the_jungle",
        startsCombat = false,
        toggle = "cooldowns",
        handler = function ()
            if buff.cat_form.down then shift( "cat_form" ) end
            applyBuff( "incarnation_king_of_the_jungle" )
        end,
        copy = { "incarnation" }
    },

    -- Maim: Finishing move that causes damage and stuns the target.
    maim = {
        id = 22570,
        cast = 0,
        cooldown = 20,
        gcd = "totem",
        school = "physical",
        spend = 35,
        spendType = "energy",
        talent = "maim",
        startsCombat = false,
        form = "cat_form",
        usable = function () return combo_points.current > 0 end,
        handler = function ()
            applyDebuff( "target", "maim", combo_points.current )
            spend( combo_points.current, "combo_points" )
        end,
    },

    -- Mass Entanglement (MoP talent): Roots the target and nearby enemies.
    mass_entanglement = {
        id = 102359,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "nature",
        talent = "mass_entanglement",
        startsCombat = true,
        handler = function ()
            applyDebuff( "target", "mass_entanglement" )
        end,
    },

    -- Mighty Bash: Stuns the target for 5 sec.
    mighty_bash = {
        id = 5211,
        cast = 0,
        cooldown = 50,
        gcd = "spell",
        school = "physical",
        talent = "mighty_bash",
        startsCombat = true,
        handler = function ()
            applyDebuff( "target", "mighty_bash" )
        end,
    },

    -- Moonfire: Applies a DoT to the target.
    moonfire = {
        id = 8921,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "arcane",
        spend = 0.06,
        spendType = "mana",
        startsCombat = false,
        form = "moonkin_form",
        handler = function ()
            if not buff.moonkin_form.up then unshift() end
            applyDebuff( "target", "moonfire" )
        end,
    },

    -- Prowl: Enter stealth.
    prowl = {
        id = 5215,
        cast = 0,
        cooldown = 6,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        nobuff = "prowl",
        handler = function ()
            shift( "cat_form" )
            applyBuff( "prowl_base" )
        end,
    },

    -- Rake: Bleed damage and awards 1 combo point.
    rake = {
        id = 1822,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 35,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        handler = function ()
            applyDebuff( "target", "rake" )
            gain( 1, "combo_points" )
        end,
    },

    -- Regrowth: Heals a friendly target.
    regrowth = {
        id = 8936,
        cast = function ()
            if buff.predatory_swiftness.up then return 0 end
            return 1.5 * haste
        end,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        spend = 0.10,
        spendType = "mana",
        startsCombat = false,
        handler = function ()
            if buff.predatory_swiftness.down then
                unshift()
            end
            removeBuff( "predatory_swiftness" )
            applyBuff( "regrowth" )
        end,
    },

    -- Rejuvenation: Heals the target over time.
    rejuvenation = {
        id = 774,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        spend = 0.08,
        spendType = "mana",
        startsCombat = false,
        handler = function ()
            if buff.cat_form.up or buff.bear_form.up then
                unshift()
            end
            applyBuff( "rejuvenation" )
        end,
    },

    -- Rip: Finishing move that causes Bleed damage over time.
    rip = {
        id = 1079,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 20,
        spendType = "energy",
        talent = "rip",
        startsCombat = true,
        form = "cat_form",
        usable = function ()
            return combo_points.current > 0
        end,
        handler = function ()
            applyDebuff( "target", "rip" )
            spend( combo_points.current, "combo_points" )
        end,
    },

    -- Shred: Deals damage and awards 1 combo point.
    shred = {
        id = 5221,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 40,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        handler = function ()
            gain( 1, "combo_points" )
        end,
    },

    -- Skull Bash: Interrupts spellcasting.
    skull_bash = {
        id = 80965,
        cast = 0,
        cooldown = 10,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        toggle = "interrupts",
        interrupt = true,
        form = function ()
            return buff.bear_form.up and "bear_form" or "cat_form"
        end,
        handler = function ()
            interrupt()
        end,
    },

    -- Survival Instincts: Reduces all damage taken by 50% for 6 sec.
    survival_instincts = {
        id = 61336,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        handler = function ()
            applyBuff( "survival_instincts" )
        end,
    },

    -- Thrash (Cat): Deals damage and applies a bleed to all nearby enemies.
    thrash_cat = {
        id = 106830,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",
        spend = 40,
        spendType = "energy",
        startsCombat = false,
        form = "cat_form",
        handler = function ()
            applyDebuff( "target", "thrash_cat" )
            gain( 1, "combo_points" )
        end,
    },

    -- Tiger's Fury: Instantly restores 60 Energy and increases damage done by 15% for 6 sec.
    tigers_fury = {
        id = 5217,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        school = "physical",
        spend = -60,
        spendType = "energy",
        startsCombat = false,
        handler = function ()
            shift( "cat_form" )
            applyBuff( "tigers_fury" )
        end,
    },

    -- Swipe (Cat): Swipe nearby enemies, dealing damage and awarding 1 combo point.
    swipe_cat = {
        id = 62078,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 45,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        handler = function ()
            gain( 1, "combo_points" )
        end,
    },

    -- Wild Charge (MoP talent): Movement ability that varies by shapeshift form.
    wild_charge = {
        id = 102401,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        school = "physical",
        talent = "wild_charge",
        startsCombat = false,
        handler = function ()
            applyBuff( "wild_charge" )
        end,
    },

    -- Cenarion Ward (MoP talent): Protects a friendly target, healing them when they take damage.
    cenarion_ward = {
        id = 102351,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "nature",
        talent = "cenarion_ward",
        startsCombat = false,
        handler = function ()
            applyBuff( "cenarion_ward" )
        end,
    },

    -- Typhoon (MoP talent): Knocks back enemies and dazes them.
    typhoon = {
        id = 132469,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "nature",
        talent = "typhoon",
        startsCombat = true,
        handler = function ()
            applyDebuff( "target", "typhoon" )
        end,
    },

    -- Heart of the Wild (MoP talent): Temporarily improves abilities not associated with your specialization.
    heart_of_the_wild = {
        id = 108292,
        cast = 0,
        cooldown = 360,
        gcd = "off",
        school = "nature",
        talent = "heart_of_the_wild",
        startsCombat = false,
        handler = function ()
            applyBuff( "heart_of_the_wild" )
        end,
    },

    -- Renewal (MoP talent): Instantly heals you for 30% of max health.
    renewal = {
        id = 108238,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "nature",
        talent = "renewal",
        startsCombat = false,
        handler = function ()
            -- Healing handled by game
        end,
    },

    -- Force of Nature (MoP talent): Summons treants to assist in combat.
    force_of_nature = {
        id = 102703,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "nature",
        talent = "force_of_nature",
        startsCombat = true,
        handler = function ()
            -- Summon handled by game
        end,
    },

    -- Shadowmeld: Night Elf racial ability
    shadowmeld = {
        id = 58984,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        usable = function () return race.night_elf end,
        handler = function ()
            applyBuff( "shadowmeld" )
        end,
    },
} )

spec:RegisterRanges( "rake", "shred", "skull_bash", "growl", "moonfire" )

spec:RegisterOptions( {
    enabled = true,

    aoe = 3,
    cycle = false,

    nameplates = true,
    nameplateRange = 10,
    rangeFilter = false,

    damage = true,
    damageDots = false,
    damageExpiration = 3,

    potion = "tempered_potion",

    package = "Feral"
} )


spec:RegisterSetting( "rip_duration", 9, {
    name = strformat( "%s Duration", Hekili:GetSpellLinkWithTexture( spec.abilities.rip.id ) ),
    desc = strformat( "If set above |cFFFFD1000|r, %s will not be recommended if the target will die within the specified timeframe.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.rip.id ) ),
    type = "range",
    min = 0,
    max = 18,
    step = 0.1,
    width = 1.5
} )

spec:RegisterSetting( "regrowth", true, {
    name = strformat( "Filler %s", Hekili:GetSpellLinkWithTexture( spec.abilities.regrowth.id ) ),
    desc = strformat( "If checked, %s may be recommended as a filler when higher priority abilities are not available. This is generally only at very low energy.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.regrowth.id ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterVariable( "regrowth", function()
    return state.settings.regrowth ~= false
end )

spec:RegisterStateExpr( "filler_regrowth", function()
    return state.settings.regrowth ~= false
end )

spec:RegisterSetting( "solo_prowl", false, {
    name = strformat( "Allow %s in Combat When Solo", Hekili:GetSpellLinkWithTexture( spec.abilities.prowl.id ) ),
    desc = strformat( "If checked, %s can be recommended in combat when you are solo. This is off by default because it may drop combat outside of a group/encounter.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.prowl.id ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "allow_shadowmeld", nil, {
    name = strformat( "Use %s", Hekili:GetSpellLinkWithTexture( spec.auras.shadowmeld.id ) ),
    desc = strformat( "If checked, %s can be recommended for Night Elf players if its conditions for use are met. Only recommended in boss fights or groups to avoid resetting combat.",
        Hekili:GetSpellLinkWithTexture( spec.auras.shadowmeld.id ) ),
    type = "toggle",
    width = "full",
    get = function () return not Hekili.DB.profile.specs[ 103 ].abilities.shadowmeld.disabled end,
    set = function ( _, val )
        Hekili.DB.profile.specs[ 103 ].abilities.shadowmeld.disabled = not val
    end,
} )

spec:RegisterSetting( "lazy_swipe", false, {
    name = strformat( "Minimize %s in AOE", Hekili:GetSpellLinkWithTexture( spec.abilities.shred.id ) ),
    desc = "If checked, Shred will be minimized in multi-target situations. This is a DPS loss but can be easier to execute.",
    type = "toggle",
    width = "full"
} )

spec:RegisterVariable( "lazy_swipe", function()
    return state.settings.lazy_swipe ~= false
end )


spec:RegisterPack( "Feral", 20250710, [[Hekili:fRr)VTTn2)wcoaxN1oF(JO0E7scqARZMlAskIZkWHdZsks0XCrwYtFKSuyO)2V3JKsIIIIwo76D)W6COiFVhFF)bxmAXTlM77MswC14HJTg(2rdhm6DwJgF8I5PpVHSy(gxVhCVh(rO7A4FxsIDdYDsjjP43EoiY1hHrsuwSh89fZVlJgKolCXDAb8ilyVBiElUA0WjlMVI67t47LK4Ty(TROj5o4)5M7iqDUt0s4V9sPrH5ob0Ku4ZlJIZD(fYd0a6aGqIJwsda0)3YD(yCg1p35coH(J5oxg9LChRbwdgM78EsQB(NGD91ZVz25V)ZtNN7C(vFm35dxF1hND7SRVAE(NY)0JUXu37ciVbV0NMLqStxf7MS6np6gKrofUabb2PUX3tstgK8eDdX2Zn9Stps3rJDFGio4i1VNsxdWoYEtuuGypdv3tYQOyKFBNM6l2dh1dkoTpLOEOGOW733ZKeBNTrS77YwUCqI7Ja)3ooYnEq2Mg0(sLTNsVNeNyVml(znBNg6fTMgEVTV7AaQv3wM84YSGu6pYPXCNepsiC4OevG4gr2LmyI6z8ciUpUJJD6ybDmnKeF)ZG6wiOdbe8DrGEyeneiQ1UHaDVMa)wbdO0ZMWoPan8)4eRH9oGXAIGJzhT02laoykYEeF4oGJrIFqd)YBJ9A3)0gi4WcriJESzKtYzNATDB)6RCuVgITyYAxAyYjJpuf(X0n2XKLXKs1A)O0bWQLN5Tdg3Rocgj4s3kKtW5OGroZWKXXaZeIBd(dFv7eAAgBZYYEg8(Ynt)W1x((ZVL9ZVC(nNJMI5FIB0Nmytmbje30xF6FFTB8diRmDfX(jAG)BOlpLZlv)cJPQdeGa3gCGSU6OfR06rapmpfuTF2FY2CHEtscOyqrxoiCeSdqBbyuHEGcL3kI3djLaFxurP6HBCfHXW0SWusCC2Mubo8jljHj0hjYWo5Hmqn)o0LfaDHPVNBskyawNgGTX)tB0ZkxEjbsgkNNsCdsxboI3Gk2YaOf(sV(hWzDB3MqsrScgBrbGMeUHdfW9drXG394OuUk0oPlpWoZp6PWKDV1L0qAYkW4A3B9E8o5Mg1L9crzcyavCd(40lME18zFDkeg5dIWhfQpLCruEKf)if06Tb7kGB4LMG8Svm26GnEPNmzypfhKNj(k4e4hgoWspCVdu5tEGgQanRDaTj6Hg4mi8BuIp4xqWuqJva0n0f7jHSJg2cTvSFfIB8oiUJe82FbwevxbToiOf9B1vsQHQv8TcX1Y8wvsWG9RpkxF2g8ZVmnKKKOq6VTfspM87zpcHGkU)1zTCvD59i7j4s3FhZn5JFzogaPqHftej55qVvXrH0Vra72Sem3Ms0xUvgNJfuaXmpqc4AFytF7OzMsaGTBlCINs9a9I7pSxbGRfEUWf)Kch643EfqMxaFLrSerGq5OE6OvjOwrVNC6eR2J81cf56)SGAUWLedPN4Cbf9pWs1ZnEn()8jiq1tjlzNYEjCiBwAQi9WpWaPVna3FVMzdD2ilb6VX1J5i39oi7YukjXOucyYLAC1ZaA72gH41cNGOi)sgy3GdNnn7QzZ)LP3GbnND9nZU9FL7036dq2UZ)YuiD2R(5d5XM(tIxwk6P1netNgsnoYJgLbI73tX1bX9k69RG8fHKDG0UqbvfTw6kf5Xfh1(o4Ki9QKtspf9pTATcMVSpbREfA6wfPeoNDiqCaNc1dbmaMBHECc2disQhkMQRritTsOTjPoQ9KLWeF63izR2ZTA72cI)DdlITDdDdObTztaqKmhx8O1BG)LSM6bcdEUx6PCGdQJ52)af2lKcOUS2uxRP2UodGYi1yQH(zc3)fWQyHdp8qT5SZUWjBq7y5KmACT8EgsiVid8thP7AQEl1rSQKvpeFpsW0WxdMSNCAryeDA7fo38ZwV57PIE)kL6ggXIfA6FSG9oTk5XAMc)xrvhD(ugYcZ9(AWlY1ZUcYa)NNE1uib8RVzo7JNhbj3OjhPbvRHHby1hJLsHOVi9)bvLoZfQvBRKVjB3Rf0LfPvdYqLGLh9Okp3pq0z1j78qpsyfPJPXYeRWFusF1Ul4xkr7eRDaSsyvgUTxJL0yAAcJgdCv3GmMXm0yr2Kw1yt2Kr0WaRvZs8uL2LYClEUgmDarC9eaYbazwq0W1gsoQl6ykQt1zXA(GggDLQNURYXL2hxm7ZFgdZwMIVuJcWA)v83XkraO3NCPPVjH4D6WbJQP7k1VaJPND2KYCk5CjgltURej6W7A2Ul4tYUcoPkm7rIQVBE8eOADwv19BZbvVwHjeHs2cD72dkdQe4(nwI4BihQCREAfbmu9CdFvk6Pb1ciROH(79DR1moRFPR7BLdBJmcdSq0Pd5EOOwS8ybOCIW6)FaTwID1ElIfhbbEvuxXIc4dLewQaE(1Gp4BU(wEBrC6p51Gz0538ZtVD(HvWhy4nSs2hVU8Z)YDiCSwpJCOwZjEB8ZMN6ffvt5(89lNdvuT)jnupPxEW4pp98VwxCpwN0M3wZ9sGPt8ucMxUEtji2xXLukR6Ux)VqWvITo70S5TUf3eDZzetM)R3o7ZSY3yZI4YR)60lNcPIvIRSuSs0NF9lRixwTZNnSeXJT0b59VDKnHXFPUbEz0J8(mORW7kC4lAQ5AX2h4ttsXm7oBCrRzWTiZPNmuhGWweB7Tc5r6H3761yn5cvhxKqZf0qSouOAo2qW02ZKx3wNsMuq01R5)L19KkKPM7HaBwfAbdyT47Sr7Xak2rQklM)KBCikBXX4bCb66nrXPIKwEvz71EfYP(JmqjfsmpbWliVZsJw7MIlaYdCWvdY)0NPHWNo(NaRJWKSniSWnWVIaaL7)2RgGIc(WdfZcKpfX10KewpefqqqnS0kXIWtJPHpGtck3j3zwk)qS2(d8dFcBIgUWYeiu(ZsnhXHg6fK5dAOoeAkud2pbeawz5)(xtiiKiRt(T3GP2q9wjVB3WNRWAUtyec8)eRxHMgubxF8xiYjvi9FcjwexGMB5Gi3z0VjQXPAPXsyguYdKUrcqMwSvg3GTuy2AquZKjbG3Y8pnBDblF0qLXVcFDXC2VWr)YDec)6k20KbrcK9N)I3Vyo)qlMJbHG9j7lh38CShoGCWDX8dGAXvIwL70RQq9Zon3zIfFkXGJCoynhPCr6IRgRqqnqyZiCnqR1WQls12rOpPvOlhjGdLrm42weWCNtYDGOGvysAtiQoQnolDJz8AXWBb7TkkjBznJe25SQTweTuJOdijRoE7pPGiKzQhjXuRI8IG949fST4(YikzHSxG4BEPFjtkWnhFJIQyZ5ajt5vn6Kr3q4iK4ugccJ1xniKCNFi3z4alZQXkq2ApG8KQRxXuKmRu3mdaexkuGmxw74K0Pn369z8ECFos6(uqK60tl2uTzgPio1o6Pg8c9Zxshx5TdnRARxmEGq5wzstsw)sFGRnx1VetQZsUXu8O2wJav7cOmXRPzFYoD6MlwJA5YTuOPDTLKDArvM60KRhnQ29Ud9nSlrRA04oDXWmQ)R2EqU)cgy0(jDEW7iHykcWilf2Lb7OxEWDecv9paUpO0CNbMKBU4UZrWylr1zuUtBKD3(svbAZMrQiwBzdTiCRB5yIFDm3Pq5Wgn5tqKNVk7BFgMT89UEKx9j)i8v2x0sZA5Ta6bB3QjRLdzhXuLiCERohkLI2QdPkB7WyW1DlpPYI6aZzK0E1BMCz1OQFf6ExdmVMgP(MfSd3bgYbTAo4n8QQmh9grqvEXGmrUsvNMt1SZqPIAlN2Ez(FUGpctMgf9br561XN8LINq1oRutPro7ktAWvpVlfAQ1hhMmviKYINdMj9o1hbfVQpB(tbUc2guoyD4rHivEoz6yqLVVoHdId4(iWsXrPRMUibUg0PQup9MAV3SoEnR8EAiAHriuoNwecV9LabPeVaq8UxciedFap))yV9lAOdxADhwwJtH8u1e9VQJYrdvUdjeVfZhoyu1Tb7awleNiQPCNW4(5g2fk7GgEx6qmPZ4XKWhnFXRk1Klh1NYQA5M78nUB6bU36JTUJV(5D(8FB598QZqxZB21CTaACHQXtTXczvDYO6TIjMkSx0iKQBAOmBy1bd3fvtDdgU76uTgLqQXkQz1124KxS7(TO0tfJC6(gSKkYKRdirkkq9sbXybhifoOAgZy4GQWLI290AuQDYPABe1DGFTdVjnzNTvOf)wOKdI6CS7ab1eJTfvRyI0Q51zEG3YKqJHBxJcyXjkm3kIrAWRy95R2WqC3VgYx2tHSDEAvhw11E12k4rK)LAVUAkD03xKs9bPweRKG1E8YjnF56wBRBVmolPSXBdaJ57r(I)UHI05AThoyFVRRu2X3BzxeM913XCKk7xTUoMGUV1sz8TuRL2hH5HhAY7fJzyQbmFFglaBVin0Ohog7bt93jQjhEMn33XZ6Sl3)9XOTFZgVOPotPf1gZZK322TNB5LG(ImDX0j4UCHiOMC22AdWm9yKw0STFV4()wQEZBWOkC7u7epUbUWoeQBCwDDyE6dJ2wpOBVtV7NatRsIPMY()V5c21b4z2mur9OnFcmfzXt6WyMd7ObA6Faol2V2MjA5gWPg24omEhdYBV6m0FX6DKIX1HMQ0O4OwJd53SFuAEtpYuwJ3xdJ7nUEz4IxZttlzTzlVlG)ogC08n9PGnwYYw6bdXu8qFOzPRIahXZxNTmHT0I)Zd]])