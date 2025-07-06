-- DruidFeral.lua
--july 2025 by smufrik

if UnitClassBase( "player" ) ~= "DRUID" then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local FindUnitBuffByID = ns.FindUnitBuffByID
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID

local strformat = string.format

local spec = Hekili:NewSpecialization( 103 )

spec:RegisterResource( Enum.PowerType.Energy )
spec:RegisterResource( Enum.PowerType.ComboPoints)
spec:RegisterResource( Enum.PowerType.Rage )
spec:RegisterResource( Enum.PowerType.LunarPower )
spec:RegisterResource( Enum.PowerType.Mana )

-- Talents
spec:RegisterTalents( {
    -- Tier 1 (Level 15)
    feline_swiftness = { 1, 131768, 1 }, -- Increases movement speed by 15%.
    displacer_beast  = { 2, 102280, 1 }, -- Teleports forward, activates Cat Form, and increases movement speed.
    wild_charge      = { 3, 102401, 1 }, -- Grants a movement ability that varies by shapeshift form.

    -- Tier 2 (Level 30)
    yseras_gift      = { 4, 145108, 1 }, -- Heals you for 2% of max health every 5 sec.
    renewal          = { 5, 108238, 1 }, -- Instantly heals you for 30% of max health.
    cenarion_ward    = { 6, 102351, 1 }, -- Protects a friendly target, healing them when they take damage.

    -- Tier 3 (Level 45)
    faerie_swarm         = { 7, 102355, 1 }, -- Reduces target's movement speed and prevents stealth.
    mass_entanglement    = { 8, 102359, 1 }, -- Roots the target and nearby enemies.
    typhoon              = { 9, 132469, 1 }, -- Knocks back enemies and dazes them.

    -- Tier 4 (Level 60)
    soul_of_the_forest   = { 10, 114107, 1 }, -- Finishing moves grant 4 energy per combo point spent.
    incarnation_king_of_the_jungle = { 11, 102543, 1 }, -- Improved Cat Form for 30 sec.
    force_of_nature      = { 12, 102703, 1 }, -- Summons treants to assist in combat.

    -- Tier 5 (Level 75)
    disorienting_roar    = { 13, 99, 1 }, -- Disorients all enemies within 10 yards.
    ursols_vortex        = { 14, 102793, 1 }, -- Creates a vortex that pulls and roots enemies.
    mighty_bash          = { 15, 5211, 1 }, -- Stuns the target for 5 sec.

    -- Tier 6 (Level 90)
    heart_of_the_wild    = { 16, 108292, 1 }, -- Temporarily improves abilities not associated with your specialization.
    dream_of_cenarius    = { 17, 108381, 1 }, -- Healing spells increase next damage, and vice versa.
    natures_vigil        = { 18, 124974, 1 }, -- Increases all damage and healing, and causes single-target damage to also heal a nearby ally.
} )



-- Ticks gained on refresh (MoP version).
local tick_calculator = setfenv( function( t, action, pmult )
    local remaining_ticks = 0
    local potential_ticks = 0
    local remains = t.remains
    local tick_time = t.tick_time
    local ttd = min( fight_remains, target.time_to_die )

    local aura = action
    if action == "primal_wrath" then aura = "rip" end

    local duration = class.auras[ aura ].duration
    local app_duration = min( ttd, duration )
    local app_ticks = app_duration / tick_time

    remaining_ticks = min( remains, ttd ) / tick_time
    duration = max( 0, min( remains + duration, 1.3 * duration, ttd ) )
    potential_ticks = min( duration, ttd ) / tick_time

    if action == "thrash" then aura = "thrash" end

    return max( 0, potential_ticks - remaining_ticks )
end, state )

-- Auras
spec:RegisterAuras( {
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
    bloodtalons = {
        id = 145152, -- MoP: Bloodtalons
        max_stack = 3,
        duration = 30,
        multiplier = 1.3,
    },
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
        multiplier = 1.6,
    },
    prowl = {
        alias = { "prowl_base" },
        aliasMode = "first",
        aliasType = "buff",
        duration = 3600
    },
    rake = {
        id = 155722,
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
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
    },
    shadowmeld = {
        id = 58984,
        duration = 3600,
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
        duration = 6,
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

-- Snapshotting
local tf_spells = { rake = true, rip = true, thrash = true, lunar_inspiration = true, primal_wrath = true }
local bt_spells = { rip = true, primal_wrath = true }
local mc_spells = { thrash = true }
local pr_spells = { rake = true }
local bs_spells = { rake = true }

local stealth_dropped = 0

-- MoP version: update calculate_pmultiplier for MoP snapshotting rules.
local function calculate_pmultiplier( spellID )
    local a = class.auras
    local tigers_fury = FindUnitBuffByID( "player", a.tigers_fury.id, "PLAYER" ) and a.tigers_fury.multiplier or 1
    local bloodtalons = FindUnitBuffByID( "player", a.bloodtalons.id, "PLAYER" ) and a.bloodtalons.multiplier or 1
    local prowling = ( FindUnitBuffByID( "player", a.prowl_base.id, "PLAYER" ) or GetTime() - stealth_dropped < 0.2 ) and a.prowl_base.multiplier or 1
    local berserk = FindUnitBuffByID( "player", a.berserk.id, "PLAYER" ) and a.berserk.multiplier or 1

    if spellID == a.rake.id then
        return 1 * tigers_fury * prowling * berserk
    elseif spellID == a.rip.id or spellID == a.primal_wrath.id then
        return 1 * bloodtalons * tigers_fury
    elseif spellID == a.thrash_cat.id then
        return 1 * tigers_fury
    elseif spellID == a.lunar_inspiration and a.lunar_inspiration.id then
        return 1 * tigers_fury
    end

    return 1
end

-- MoP version: persistent_multiplier for snapshotting.
spec:RegisterStateExpr( "persistent_multiplier", function( act )
    local mult = 1

    act = act or this_action

    if not act then return mult end

    local a = class.auras
    if tf_spells[ act ] and buff.tigers_fury.up then mult = mult * a.tigers_fury.multiplier end
    if bt_spells[ act ] and buff.bloodtalons.up then mult = mult * a.bloodtalons.multiplier end
    if pr_spells[ act ] and ( buff.prowl_base.up or GetTime() - stealth_dropped < 0.2 ) then mult = mult * a.prowl_base.multiplier end
    if bs_spells[ act ] and buff.berserk.up then mult = mult * a.berserk.multiplier end

    return mult
end )

local snapshots = {
    [155722] = true, -- Rake
    [1079]   = true, -- Rip
    [285381] = true, -- Primal Wrath
    [106830] = true, -- Thrash (Cat)
    [155625] = true  -- Lunar Inspiration
}

-- Tweaking for new Feral APL.
local rip_applied = false

spec:RegisterEvent( "PLAYER_REGEN_ENABLED", function ()
    rip_applied = false
end )

--[[spec:RegisterStateExpr( "opener_done", function ()
    return rip_applied
end )--]]

-- MoP: Bloodtalons and stealth snapshot tracking.
local last_bloodtalons_proc = 0
local last_bloodtalons_stack = 0

spec:RegisterCombatLogEvent( function( _, subtype, _,  sourceGUID, sourceName, _, _, destGUID, destName, destFlags, _, spellID, spellName )

    if sourceGUID == state.GUID then
        if subtype == "SPELL_AURA_REMOVED" then
            -- Track Prowl and Shadowmeld and Sudden Ambush dropping, give a 0.2s window for the Rake snapshot.
            if spellID == 58984 or spellID == 5215 or spellID == 102547 or spellID == 391974 or spellID == 340698 then
                stealth_dropped = GetTime()
            end
        elseif ( subtype == "SPELL_AURA_APPLIED" or subtype == "SPELL_AURA_REFRESH" or subtype == "SPELL_AURA_APPLIED_DOSE" ) then
            if snapshots[ spellID ] then
                local mult = calculate_pmultiplier( spellID )
                ns.saveDebuffModifier( spellID, mult )
                ns.trackDebuff( spellID, destGUID, GetTime(), true )
            end
        elseif subtype == "SPELL_CAST_SUCCESS" and ( spellID == class.auras.rip.id or spellID == class.auras.primal_wrath and class.auras.primal_wrath.id or 0 ) then
            rip_applied = true
        end

        -- MoP: Bloodtalons is a buff, not a stacking aura in MoP, so just track application/removal.
        if spellID == 145152 and ( subtype == "SPELL_AURA_APPLIED" or subtype == "SPELL_AURA_REFRESH" or subtype == "SPELL_AURA_REMOVED" ) then
            if subtype == "SPELL_AURA_APPLIED" or subtype == "SPELL_AURA_REFRESH" then
                last_bloodtalons_proc = GetTime()
                last_bloodtalons_stack = 1
            else
                last_bloodtalons_proc = 0
                last_bloodtalons_stack = 0
            end
        end
    end
end )

spec:RegisterStateExpr( "last_bloodtalons", function ()
    return last_bloodtalons_proc
end )

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

.caster  = "nobody"
end

spec:RegisterAuras( {
    bt_rake = {
        duration = 4,
        max_stack = 1,
        generate = bt_generator
    },
    bt_shred = {
        duration = 4,
        max_stack = 1,
        generate = bt_generator
    },
    bt_swipe = {
        duration = 4,
        max_stack = 1,
        generate = bt_generator
    },
    bt_thrash = {
        duration = 4,
        max_stack = 1,
        generate = bt_generator
    },
    bt_triggers = {
        alias = { "bt_rake", "bt_shred", "bt_swipe", "bt_thrash" },
        aliasMode = "longest",
        aliasType = "buff",
        duration = 4,
    },
} )

-- MoP: Bloodtalons is a single-stack buff, not a stacking aura, and triggers on Regrowth cast after using 3 different abilities.
local ComboPointPeriodic = setfenv( function()
    gain( 1, "combo_points" )
end, state )

spec:RegisterHook( "reset_precast", function ()
    if buff.cat_form.down then
        energy.regen = 10 + ( stat.haste * 10 )
    end
    debuff.rip.pmultiplier = nil
    debuff.rake.pmultiplier = nil
    debuff.thrash_cat.pmultiplier = nil

    -- MoP: No eclipse, no adaptive swarm.
    -- Bloodtalons
    if talent.bloodtalons.enabled then
        -- MoP: Bloodtalons is not stacking, so just check if it should be up.
        if buff.bloodtalons.up then
            buff.bloodtalons.expires = last_bloodtalons_proc + 30
        end
    end

    if prev_gcd[1].feral_frenzy and now - action.feral_frenzy.lastCast < gcd.execute and combo_points.current < 5 then
        gain( 5, "combo_points", false )
    end

    last_bloodtalons = nil

    if buff.jungle_stalker and buff.jungle_stalker.up then buff.jungle_stalker.expires = buff.bs_inc and buff.bs_inc.expires or buff.jungle_stalker.expires end

    if buff.bs_inc and buff.bs_inc.up then
        -- MoP: No Ashamane's Guidance.
        -- Queue combo point gain events every 1.5 seconds while Incarnation/Berserk is active, starting 1.5 seconds after cast
        local tick, expires = buff.bs_inc.applied, buff.bs_inc.expires
        for i = 1.5, expires - query_time, 1.5 do
            tick = query_time + i
            if tick < expires then
                state:QueueAuraEvent( "incarnation_combo_point_periodic", ComboPointPeriodic, tick, "AURA_TICK" )
            end
        end
    end

    -- MoP: No Sinful Hysteria, no Ravenous Frenzy.
end )

spec:RegisterHook( "gain", function( amt, resource, overflow )
    if overflow == nil then overflow = true end
    if amt > 0 and resource == "combo_points" then
        -- MoP: No Overflowing Power, no Berserk Incarnation storage.
        -- MoP: No Soul of the Forest energy refund on spend, only on finishers.
    end
    -- MoP: No Untamed Ferocity azerite.
end )

local function comboSpender( a, r )
    if r == "combo_points" and a > 0 then
        if talent.soul_of_the_forest and talent.soul_of_the_forest.enabled then
            gain( a * 2, "energy" )
        end

        if talent.predatory_swiftness and talent.predatory_swiftness.enabled and a >= 5 then
            applyBuff( "predatory_swiftness" )
        end
    end
end

spec:RegisterHook( "spend", comboSpender )

local combo_generators = {
    rake              = true,
    shred             = true,
    swipe_cat         = true,
    thrash_cat        = true
}

spec:RegisterStateExpr( "active_bt_triggers", function ()
    -- MoP: Bloodtalons is not stacking, so always 0 or 1.
    if not talent.bloodtalons.enabled then return 0 end
    return buff.bloodtalons.up and 1 or 0
end )

spec:RegisterStateFunction( "time_to_bt_triggers", function( n )
    -- MoP: Bloodtalons is not stacking, so only 1 stack.
    if not talent.bloodtalons.enabled or n > 1 then return 0 end
    if buff.bloodtalons.up then return buff.bloodtalons.remains end
    return 3600
end )

spec:RegisterStateFunction( "check_bloodtalons", function ()
    -- MoP: Bloodtalons is not stacking, so nothing to check.
end )

spec:RegisterStateTable( "druid", setmetatable( {},{
    __index = function( t, k )
        if k == "catweave_bear" then return false
        elseif k == "owlweave_bear" then return false
        elseif k == "owlweave_cat" then
            return false -- MoP: No Balance Affinity
        elseif k == "no_cds" then return not toggle.cooldowns
        elseif k == "primal_wrath" then return class.abilities.primal_wrath
        elseif k == "lunar_inspiration" then return debuff.lunar_inspiration
        elseif k == "delay_berserking" then return settings.delay_berserking
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
    local feralAura = 1
    local armor = armorFlag and 0.7 or 1
    local crit = 1 + ( state.stat.crit * 0.01 * ( critChanceMult or 1 ) )
    local mastery = masteryFlag and ( 1 + state.stat.mastery_value * 0.01 ) or 1
    local tf = state.buff.tigers_fury.up and class.auras.tigers_fury.multiplier or 1

    return coefficient * state.stat.attack_power * crit * mastery * feralAura * armor * tf
end

-- Force reset when Combo Points change, even if recommendations are in progress.
spec:RegisterUnitEvent( "UNIT_POWER_FREQUENT", "player", nil, function( _, _, powerType )
    if powerType == "COMBO_POINTS" then
        Hekili:ForceUpdate( powerType, true )
    end
end )

-- Abilities (MoP version, updated)
spec:RegisterAbilities( {
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

--[[ TODO: Revisit due to removal of Relentless Predator.
spec:RegisterSetting( "use_funnel", false, {
    name = strformat( "%s Funnel", Hekili:GetSpellLinkWithTexture( spec.abilities.ferocious_bite.id ) ),
    desc = function()
        return strformat( "If checked, when %s and %s are talented and %s is |cFFFFD100not|r talented, %s will be recommended over %s unless |W%s|w needs to be "
            .. "refreshed.\n\n"
            .. "Requires %s\n"
            .. "Requires %s\n"
            .. "Requires |W|c%sno %s|r|w",
            Hekili:GetSpellLinkWithTexture( spec.talents.taste_for_blood[2] ), Hekili:GetSpellLinkWithTexture( spec.talents.relentless_predator[2] ),
            Hekili:GetSpellLinkWithTexture( spec.talents.tear_open_wounds[2] ), Hekili:GetSpellLinkWithTexture( spec.abilities.ferocious_bite.id ),
            Hekili:GetSpellLinkWithTexture( spec.abilities.primal_wrath.id ), Hekili:GetSpellLinkWithTexture( spec.abilities.rip.id ),
            Hekili:GetSpellLinkWithTexture( spec.talents.taste_for_blood[2], nil, state.talent.taste_for_blood.enabled ),
            Hekili:GetSpellLinkWithTexture( spec.talents.relentless_predator[2], nil, state.talent.relentless_predator.enabled ),
            ( not state.talent.tear_open_wounds.enabled and "FF00FF00" or "FFFF0000" ),
            Hekili:GetSpellLinkWithTexture( spec.talents.tear_open_wounds[2], nil, not state.talent.tear_open_wounds.enabled ) )
    end,
    type = "toggle",
    width = "full"
} )  ]]

--[[ Currently handled by the APL
spec:RegisterSetting( "zerk_biteweave", false, {
    name = strformat( "%s Biteweave", Hekili:GetSpellLinkWithTexture( spec.abilities.berserk.id ) ),
    desc = function()
        return strformat( "If checked, the default priority will recommend %s more often when %s or %s is active.\n\n"
            .. "This option may not be optimal for all situations; the default setting is unchecked.", Hekili:GetSpellLinkWithTexture( spec.abilities.ferocious_bite.id ),
            Hekili:GetSpellLinkWithTexture( spec.abilities.berserk.id ), Hekili:GetSpellLinkWithTexture( spec.abilities.incarnation.id ) )
    end,
    type = "toggle",
    width = "full"
} )

spec:RegisterVariable( "zerk_biteweave", function()
    return settings.zerk_biteweave ~= false
end )--]]

--[[ spec:RegisterSetting( "owlweave_cat", false, {
    name = "|T136036:0|t Attempt Owlweaving (Experimental)",
    desc = "If checked, the addon will swap to Moonkin Form based on the default priority.",
    type = "toggle",
    width = "full"
} ) ]]

-- MoP/Classic relevant settings for Feral Druid

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
    return settings.regrowth ~= false
end )

spec:RegisterStateExpr( "filler_regrowth", function()
    return settings.regrowth ~= false
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
    return settings.lazy_swipe ~= false
end )

spec:RegisterPack( "Feral", 20250425.1, [[HHekili:fRXIUnUnYVLGdWRt3T(8Zn71ljaz31P1bBsweLUahoulPirhZgzjF6rsZcd9TFZqsjrrr9W(UEhkABmf5mdN3ZWz5OL3V0W1oMS8MXdhpB4jdpzWWrtgn7KLgXVULS0yRTZt2pc)HV9g4)Ejj02dx9vVaBx80rbjHoWxwA8qc1lEH)Yh0dYPWE3sCwEZOHtwASM66s47Le5S04(10Oul8FTtTein1kyf8BNyAGFQLhnkg(8QGWuRFH8e1JoaiKWGvupa9)LuRphMqDtTyKyQ1pMADDWxtTMny2GHPwFKeBNEfSRVDXDlU4JFzUrQ1f385uRpD7nFEX9lU9gJ0RsV6z7qQ9dEK3Hx3ZsIiMXRdTJw)UNT9siNbxappZy7WhjXrdIEHULy6yhF(zt1D0q7NiIdos97X0naSdm3ge4j2Zq19eToimMefBgh7k2dh1dYoTlLOEiVa)h33ZefAMSvS7hswTAqK9Za)3mmWoCqY2k0(kLThtFKegzUkj8vnBN67eSH6)OPR9gaQf3wM846eVy6pYPXuRihIpC4GivGyhqAtgmr9moEe7NB5yNnwqhZ9jHp(kOU5d6qab)qaOhgq9bIAJTpq3BiWFRGbu6zsyNuGg(poD2WEhXynbWXmdwz64bhmgzpIp8aWXiHpPHF5S1CJ9FyceSFMiKrpMmYj68ZMTBx)YRmTxfXwizJn1p60XhRc)q6wZqYQqsUATBq8ay18ZCYGX9kJGrcU09c5eCokyKZmmzCmWmHyxH)Wx1mIgNW2SSSNbVVE38pD71F8I7z)5xV4UlqtX0R4g9rd2gsqcXo(TN9x3yh(eYkJxtmFH65(o6QZ48s1VWyQ6abiWnbhiBkoA2k1EeWdZlEf7N9t2MZ0BIIafdk6YbHJGDaAlaJY3buOCwtCEkkh4Trf5Qh2Hfegdtl8JjHHjBJf4WLSI4hrFMid7ONsa18hqxwa0fM(o2rXGbyzAa2g)NMONvU8scKmuAetS9IxdoI3Ik2YaOg(sV(hXzD72TcDeBgf4bQr4xpwa0pfecU2ddI56pTsuoGrMBWl(rTV1vuFA0AWYQ9T(iEHSJd6YEHqmEmGkUbFE(LZVXyX3MdXq(Ki2rMUtolefgjHptbvEtWOceaoXridBnJNoyRt8Ptg2tX745IVcEa(HHdMPhUpa67rpr9vG2SwG2e9qd8e4)DkXfCkiykOLka6kkI9Kq20H1qBz7xH4g3cXnvWB)fyruxfu5Giw0VxwjPeQwZ3keulXzDobdgVUOC9vtWj)QyFsuKcPFsnKEi53tEgI)KD)lZA565Y7r2nW12)oMyYN)Qbg9itHfZcj6vFN1Hb(0VtaJ2KimXMC0NVvgNJfraXmpkc4xFyvh7OnMI3)D7Y8GhtDa9IhpUxgGlfBoZ)(KmV543EdqMxcFLrSeruq5qE6OvjOwqVNE2Kz1h2RgkY29vb1CPnjeYnX6sk6FGLNND4g8)5sqGQNswXoL5k4qMmpoi9WpWaPVna3FpX6mWYxPAYrNpAMGGUZ2H5x3(bizZykjQr5gW2Z1blNq0UDvI4RfoEbbU5S0UbhoJBXnlm(L53HXqxC7DlU)FKA1F2NGKFn(6Ci72B(5J5HQ(dItsm6712hZUgYuoWHgKakaFKIRdkaRPpUgsFeY9bYcdfDf0AUZvKRNDuZhGtI0Rskk9u0i1Qhly(YEjM1lt3FwwgIgSdbId4uOMjGbWa03HtWoarsDqXuzDezQvcTvj1r1N7eMhu)k5EvFQw72Lr8Fyyw0U7OBbnOTB9aIK5kJh8El8FjBOoGWGNkMEkh4G6yU9psH9czeQljo11QQTRZaaCi3Nh8gtv0nreridyzlC8XhRnhE2noAlAAlN0rL7LZRqc6zzKF2iD3t1RPoQvLS6H47zcMw(gWM90ZYISOtDpZFNBYMT)zQP3VqRUIvSyHQUmZyVZlsMSKTW)v01rVp5rXWCXVfCJC7IBGmY)553mhsi)27myF8IaiFhnPnnOynmYaREzS0ke9zLdmOOuAUqTyB58nzdFTGoVOTsqgQmm)OtlCD)erNzNS3d9iHv0oMwltSc)iN(kDxWVKJ2jZAby5WkpcCVklPX2Sjm2yKRYgKHmMHglYQ0QgBYQmIkgy1AwINk3UuMBXt)GPdic1hbq2diZmIgU2q(sDrhtrDQmlwZh0WOlu90DvEFU9XLl(YxW4S5z9l14aSxak(7yvna07l2043frCoB4GrL0DL6FqJzSD(K80m5CjgltUlfr6W7g2UZ4tYUcoTio7084SqX6GjYlRjG1YdK1uwD9cXbIVxOyPG3g8jD4kcpnIM(8JkuIQ35wVAPhi8MS19UDhXJg5z)Dws9BjhRWo40SJT)BIrxuX50)(YuoQeXxFYSvyEs(O5OQrEudIc05f5rOEzKxlaLva2xHNqRUqBTxQqXrqGlcDlwraCOuZCT4lUfCKF3T3Z71Iv)jVfSfV4UFE(9ghxaCGZxXuBFCDZp)H7v59ADVYHAPib1XmREQdk0OY95pVexur1(N5r5uN5r0)Y8l(wzX9yDsBEVs3lbMoXtoyoC9MCqSVIlPeF1DV(FHGlhBD2ZB1BDn(i6SB1YUMykb)69l(cRQq2lEC9TFB(1ZHe8YrEsmwG7RVDpRMwWAyvtF(WCepEMoiV)n9Skmo8EoEDWZ8UzORy(ce4k6B6gX2h4sJIXKfpFCwdGWTihbyYqDac7cTPZAKbPhEFOxL1Kl(DCwosxs9XABHkezVZM2oZ8266hZKmIUCFeoSE0uGm10zeyBwMkWawJepF0E8giTK9ZsdiYxeGEXJkoD84LgVyh6dwOr4Jhcmg6MTbHXIuJEtEJvEdY8(xjuwUnraPaQajXbBSJXfare(CzdsVIbJvbEEbVWA)OnyCdvk(cbBgfK)nSzQp(ohKYpjj23H4S95hWiGe)s721f3SRDS9d2rKFcKSyPN8EBDLaZLPErG9Us7FH6dF69)eyP7hLSfHeUHmY8nz5c8MbC8HpZQ4Lt5V56gAue7wloTGoyjDJ9OioK6)e(UzPwPwlI5hI9ijGO1LWE)hByzciMEvQ3ratWXlXfm2SiqYJKWSl))8xJiiKiBI(T3H5VrDwlVBB)xlWQGVs(dSAoASxbCLzZzi9VZswvGM75Gi1A0VjQaSyPXsygSx9KUrcqgNTvg3GTKFYgqRLjp8GWaPxTytg7E0qLhRg(6sdqGToiCPHXMKvH0NwAW(e(Y5Cx(WFDd7z4HQsHeEDx(r4mmOS0ad3c7toQfUzdSNxGGXEPXrGELsC5uREf9148ZsTMmJ)i7qiloyBoNGLXGrMcbvbHvJLxbTZgwCrk2oc9j1cD5yECOmIb36I1NADAQfeVVatsBcr1064S0TnJ3zm8MXElYhGTSMxu368ITMLxGgrhqsZ64T)0mIqMPovIPwKJbc23VVGTFwrsMz14TBNGtx1HDQ1XnslSSwwIeIr(lQ0KMD1xgtrhT6tSjFLk6ym7cbXGrIt59LyYKI3yk16hsTgoywZ63kqE2Ea5jfxVShORzT9Q58G4sHcK5YAFPoDQ51EFgVh3NPs3NmIuNcC2Mk9CCkItTVQxfEH(NUthx5KHnRZRxmEKq)w5r8KCli9bU2mukwt6Xso2kFHBQg7d2FQgnxLqfTgya3Frv2aZbG871gYqNVRU65wVVRzs2)zfW3S2BNJhGP6vBqG6uy))yqGU6TUGk0rc1fUTCNd4kYIuk1PmxsXvTfNQ93e4UeNLgqQ)f4dliq(oOR)MmcUPS8zCVjnPJlfWRmnxFxr3xv0H60YlhKRmQ7EttLjLdk2BNO)Sq7hHZOvrpu5iawuTtQaWBkpPwz51151oW4pQctqYfTo2GwHvDg36ewvAsBhOYQyu12Ti4bVklfK2s3CLjHYDUTe6zz5KNGLDIxCtHLYATI69VBZQMsCe1M1usojN(st2UfZLMcnv7uTjtfcFTI5yRjBu1b4IxVLjF6LlGDdQ8S(gPALxEo40XGYhmWcdqEtP4MEQnMsy3PQ9wUoTsdkxhVJ5n(Ojv1gHq(RjJq4KdbcfpwhcIpCiGilCfC()wD5Evedrngw9nntw0vY2QKwTYan3bht135m8kmAOYDO9yOseNi7v5MRXcwoAyxOScl18XgQZHIJrZbXSW2K)g1bWvTyUwNm)Mgl)Ahr8ooZ2To0Y1mfY6SY1mPXnxpPg)NACt3yQ1QEyuDvXetfM9niMeQavcLVhJUOovuPmpQKyEHdXQj2oL7ASsMTh3bf0tBjxX6Do0LHEuRHiRUOUyX1SVG6ICv5PxuDQ1Y4rktZ18In8cjuNbYMQMz0SMcvwm5JQ58Oo5Klvl1x1dBE(VfUP0fF8aGsb1MpFLzveLfNRbtgLsPuRvQ9bV8WM6Y6tmT5kcRZ(tiEv7gu1uCBUldYfwRKH0EmKMnF56whFR3RYmj1G6aWy(EKV4FyOiLS6SpzDlOSwEhhTZUim7RVpdiv2VyDDmbDFtN1C9g5Sw(1plh1qPz(SjJFE3tA4Tj(ZPFkS9I0GAxSMQgwRHHsTPchB2IVLziTl3)9XUTVQ1PwFCT1(GMkfOEt6Ag70dY6L1FoMxxPAdoK(Qw7eQQoEQl11pQIPqvwt8GB(QgmW61sVo24ZAD1WAMRse1whO1LDO9VvMO0ke7eTr8LsTiO8CRYtfRqXw9t14kQlesljMuMD1uFEp4NrvRFMw9wjp1R64Vn5NszwDBYYTwBK2NRwvbA1PKvrSwZgQr4Q6YQE(175ofedotJjI1s6X6NXPUMuS8OmXiSHvUiJB5Ld3RoL9FyjGsPm0wtMQuSyTb0DR2ConJnLmzvzeMySUXLBlHyGPQAiOT9TTb8pWGJMVPpD2XsUjKMjlMwh)Fw(Vp]] )
