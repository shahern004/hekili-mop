-- RogueAssassination.lua
-- Mists of Pandaria

if UnitClassBase( "player" ) ~= "ROGUE" then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State
local PTR = ns.PTR
local strformat, insert, sort, wipe, max, min = string.format, table.insert, table.sort, table.wipe, math.max, math.min

local orderedPairs = ns.orderedPairs

-- MoP Classic: Define UA_GetPlayerAuraBySpellID function for compatibility
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

local spec = Hekili:NewSpecialization( 259 )

-- MoP Fix: Manually set the class since GetSpecializationInfoByID doesn't work in Classic
if spec then
    spec.class = "ROGUE"
    spec.name = "Assassination"
    spec.role = "DAMAGER"
    print("DEBUG: Assassination spec registered successfully with class=" .. (spec.class or "nil"))
else
    print("DEBUG: ERROR - Failed to create Assassination specialization!")
end

spec:RegisterResource( Enum.PowerType.ComboPoints )

spec:RegisterResource( Enum.PowerType.Energy, {
    garrote_vim = {
        talent = "venomous_wounds",
        aura = "garrote",
        debuff = true,

        last = function ()
            local app = state.debuff.garrote.last_tick
            local exp = state.debuff.garrote.expires
            local tick = state.debuff.garrote.tick_time
            local t = state.query_time

            return min( exp, app + ( floor( ( t - app ) / tick ) * tick ) )
        end,

        stop = function ()
            return state.debuff.poisoned.down or state.active_dot.garrote == 0
        end,

        interval = function ()
            return state.debuff.garrote.tick_time
        end,

        value = function () return state.poisoned_garrotes * 8 end
    },
    rupture_vim = {
        talent = "venomous_wounds",
        aura = "rupture",
        debuff = true,

        last = function ()
            local app = state.debuff.rupture.last_tick
            local exp = state.debuff.rupture.expires
            local tick = state.debuff.rupture.tick_time
            local t = state.query_time

            return min( exp, app + ( floor( ( t - app ) / tick ) * tick ) )
        end,

        stop = function ()
            return state.debuff.poisoned.down or state.active_dot.rupture == 0
        end,

        interval = function ()
            return state.debuff.rupture.tick_time
        end,

        value = function () return state.poisoned_ruptures * 8 end
    }
} )

-- Talents
spec:RegisterTalents( {
    -- Tier 1
    nightstalker = { 92, 16511, 1 },    -- While Stealth or Shadow Dance is active, your abilities deal 25% more damage.
    subterfuge = { 90, 108208, 1 },     -- Your abilities requiring Stealth can still be used for 3 sec after Stealth breaks.
    shadow_focus = { 89, 108209, 1 },   -- Abilities used while in Stealth cost 75% less Energy.
    
    -- Tier 2
    deadly_throw = { 101, 26679, 1 },   -- Finishing move that throws a deadly projectile, dealing 50% weapon damage plus 355 and reducing the target's movement speed by 70% for 6 sec. Damage and duration increases per combo point.
    nerve_strike = { 103, 108210, 1 },  -- After performing a successful Kidney Shot or Cheap Shot, the target's damage is reduced by 50% for 6 sec.
    combat_readiness = { 102, 74001, 1 }, -- Requires Melee Weapon. A passive dodge that causes you to take 50% reduced damage from the next attack after dodging. This effect cannot occur more than once every 2 sec.
    
    -- Tier 3
    cheat_death = { 97, 31230, 1 },     -- Fatal attacks instead reduce you to 10% of your maximum health. For 3 sec afterward, you take 90% reduced damage. Cannot trigger more than once per 90 sec.
    leeching_poison = { 98, 108211, 1 }, -- When your Non-Lethal Poison is applied, you heal for 10% of your damage.
    elusiveness = { 99, 79008, 1 },     -- Feint also reduces all damage you take by 30% for 5 sec.
    
    -- Tier 4
    preparation = { 95, 14185, 1 },     -- When activated, this ability immediately finishes the cooldown on your Vanish, Sprint, and Shadowstep abilities.
    shadowstep = { 94, 36554, 1 },      -- Step through the shadows to appear behind your target and gain 70% increased movement speed for 2 sec.
    burst_of_speed = { 93, 108212, 1 }, -- Increases your movement speed by 70% for 4 sec. Usable while stealthed.
    
    -- Tier 5
    prey_on_the_weak = { 106, 131511, 1 }, -- Cheap Shot, Kidney Shot, Sap, and Gouge cause the target to take 10% additional damage for 10 sec.
    paralytic_poison = { 107, 108215, 1 }, -- Replaces your Non-Lethal Poison with Paralytic Poison, which stacks up to 5 times. Use Crippling Poison Gives your attacks a 20% chance to apply Paralytic Poison, which builds up and slows enemy attacks by up to 50%.
    dirty_tricks = { 105, 108216, 1 },  -- Cheap Shot, Gouge, and Sap no longer cost Energy.
    
    -- Tier 6
    shuriken_toss = { 111, 114014, 1 }, -- Throws a shuriken at an enemy target, dealing 240% of normal weapon damage. Awards 1 combo point.
    versatility = { 110, 76807, 1 },    -- You gain 50% increased healing while using a leather item in every slot. You also gain an additional 50% of the baseline health bonus of leather items.
    anticipation = { 112, 114015, 1 }   -- You can build anticipation charges through offensive abilities, up to 5. When you perform a finishing move, any unused combo points become anticipation charges.
} )

-- PvP Talents
spec:RegisterPvpTalents( { 
    -- Empty for MoP since PvP talents didn't exist
} )

local stealth = {
    normal = { "stealth" },
    vanish = { "vanish" },
    subterfuge = { "subterfuge" },
    shadow_dance = { "shadow_dance" },
    shadowmeld = { "shadowmeld" },

    basic = { "stealth", "vanish" },
    rogue = { "stealth", "vanish", "subterfuge", "shadow_dance" },
    ambush = { "stealth", "vanish", "subterfuge", "shadow_dance" },

    all = { "stealth", "vanish", "shadowmeld", "subterfuge", "shadow_dance" },
}
local stealth_dropped = 0
local envenom1, envenom2 = 0, 0
local first_envenom, second_envenom = 0, 0
local last = 0
local energySpent = 0
local ENERGY = Enum.PowerType.Energy
local lastEnergy = -1
local tracked_bleeds = {}
local valid_bleeds = { "garrote", "rupture" }
local application_events = {
    SPELL_AURA_APPLIED      = true,
    SPELL_AURA_APPLIED_DOSE = true,
    SPELL_AURA_REFRESH      = true,
}

local removal_events = {
    SPELL_AURA_REMOVED      = true,
    SPELL_AURA_BROKEN       = true,
    SPELL_AURA_BROKEN_SPELL = true,
}

local stealth_spells = {
    [1784  ] = true,
    [115191] = true,
}

local tick_events = {
    SPELL_PERIODIC_DAMAGE   = true,
}

local death_events = {
    UNIT_DIED               = true,
    UNIT_DESTROYED          = true,
    UNIT_DISSIPATES         = true,
    PARTY_KILL              = true,
    SPELL_INSTAKILL         = true,
}

spec:RegisterStateExpr( "cp_max_spend", function ()
    return combo_points.max
end )

spec:RegisterStateExpr( "effective_combo_points", function ()
    return combo_points.current or 0
end )

spec:RegisterStateTable( "stealthed", setmetatable( {}, {
    __index = function( t, k )
        local kRemains = k == "remains" and "all" or k:match( "^(.+)_remains$" )

        if kRemains then
            local category = stealth[ kRemains ]
            if not category then return 0 end

            local remains = 0
            for _, aura in ipairs( category ) do
                remains = max( remains, buff[ aura ].remains )
            end

            return remains
        end

        local category = stealth[ k ]
        if not category then return false end

        for _, aura in ipairs( category ) do
            if buff[ aura ].up then return true end
        end

        return false
    end,
} ) )

spec:RegisterStateExpr( "master_assassin_remains", function ()
    if buff.master_assassin_any.up then return buff.master_assassin_any.remains end
    return 0
end )

local function isStealthed()
    return ( UA_GetPlayerAuraBySpellID( 1784 ) or UA_GetPlayerAuraBySpellID( 115191 ) or UA_GetPlayerAuraBySpellID( 115192 ) or UA_GetPlayerAuraBySpellID( 11327 ) or GetTime() - stealth_dropped < 0.2 )
end

local calculate_multiplier = setfenv( function( spellID )
    local mult = 1

    if spellID == 703 and talent.subterfuge.enabled and buff.subterfuge.up then
        mult = mult * 1.25
    end
    
    if buff.shadow_focus.up then
        mult = mult * 1.25
    end

    return mult
end, state )

-- Bleed Modifiers
local function NewBleed( key, spellID )
    tracked_bleeds[ key ] = {
        id = spellID,
        rate = {},
        last_tick = {},
        haste = {}
    }

    tracked_bleeds[ spellID ] = tracked_bleeds[ key ]
end

local function ApplyBleed( key, target )
    local bleed = tracked_bleeds[ key ]

    bleed.rate[ target ]         = 1
    bleed.last_tick[ target ]    = GetTime()
    bleed.haste[ target ]        = 100 + GetHaste()
end

local function UpdateBleedTick( key, target, time )
    local bleed = tracked_bleeds[ key ]

    if not bleed.rate[ target ] then return end

    bleed.last_tick[ target ] = time or GetTime()
end

local function RemoveBleed( key, target )
    local bleed = tracked_bleeds[ key ]

    bleed.rate[ target ]         = nil
    bleed.last_tick[ target ]    = nil
    bleed.haste[ target ]        = nil
end

NewBleed( "garrote", 703 )
NewBleed( "rupture", 1943 )

spec:RegisterCombatLogEvent( function( _, subtype, _,  sourceGUID, sourceName, _, _, destGUID, destName, destFlags, _, spellID, spellName )
    if sourceGUID == state.GUID then
        if removal_events[ subtype ] then
            if stealth_spells[ spellID ] then
                stealth_dropped = GetTime()
                return
            end
        end

        if spellID == 32645 and destGUID == state.GUID and application_events[ subtype ] then
            local now = GetTime()

            if now - last < 0.5 then
                last = now
                return
            end

            last = now
            local buff = UA_GetPlayerAuraBySpellID( 32645 )

            if not buff then
                envenom1 = 0
                envenom2 = 0
                return
            end

            local exp = buff.expirationTime or 0
            envenom2 = envenom1 > now and min( envenom1, exp ) or 0
            envenom1 = exp

            return
        end

        if tracked_bleeds[ spellID ] then
            if application_events[ subtype ] then
                ns.saveDebuffModifier( spellID, calculate_multiplier( spellID ) )
                ns.trackDebuff( spellID, destGUID, GetTime(), true )

                ApplyBleed( spellID, destGUID )
                return
            end

            if tick_events[ subtype ] then
                UpdateBleedTick( spellID, destGUID, GetTime() )
                return
            end

            if removal_events[ subtype ] then
                RemoveBleed( spellID, destGUID )
                return
            end
        end
    end

    if death_events[ subtype ] then
        RemoveBleed( "garrote", destGUID )
        RemoveBleed( "rupture", destGUID )
    end
end, false )

spec:RegisterUnitEvent( "UNIT_POWER_FREQUENT", "player", nil, function( event, unit, powerType )
    if powerType == "ENERGY" then
        local current = UnitPower( "player", ENERGY )

        if current < lastEnergy then
            energySpent = ( energySpent + lastEnergy - current ) % 30
        end

        lastEnergy = current
        return
    elseif powerType == "COMBO_POINTS" then
        Hekili:ForceUpdate( powerType, true )
    end
end )

spec:RegisterStateExpr( "energy_spent", function ()
    return energySpent
end )

spec:RegisterHook( "spend", function( amt, resource )
    if resource == "energy" and amt > 0 then
        if amt > 0 then
            energy_spent = energy_spent + amt
            local reduction = floor( energy_spent / 30 )
            energy_spent = energy_spent % 30

            if reduction > 0 then
                reduceCooldown( "vendetta", reduction )
            end
        end
    end
end )

spec:RegisterStateExpr( "poison_chance", function ()
    return 0.3
end )

spec:RegisterStateExpr( "persistent_multiplier", function ()
    if not this_action then return 1 end
    return 1
end )

-- Enemies with either Deadly Poison or Wound Poison applied.
spec:RegisterStateExpr( "poisoned_enemies", function ()
    return ns.countUnitsWithDebuffs( "deadly_poison_dot", "wound_poison_dot" )
end )

spec:RegisterStateExpr( "poison_remains", function ()
    return debuff.lethal_poison.remains
end )

-- Count of bleeds on targets.
spec:RegisterStateExpr( "bleeds", function ()
    local n = 0

    for _, aura in pairs( valid_bleeds ) do
        if debuff[ aura ].up then
            n = n + 1
        end
    end

    return n
end )

-- Count of bleeds on all poisoned (Deadly/Wound) targets.
spec:RegisterStateExpr( "poisoned_bleeds", function ()
    return ns.conditionalDebuffCount( "deadly_poison_dot", "wound_poison_dot", "garrote", "rupture" )
end )

-- Count of Garrotes on all poisoned (Deadly/Wound) targets.
spec:RegisterStateExpr( "poisoned_garrotes", function ()
    return ns.conditionalDebuffCount( "deadly_poison_dot", "wound_poison_dot", "garrote" )
end )

-- Count of Ruptures on all poisoned (Deadly/Wound) targets.
spec:RegisterStateExpr( "poisoned_ruptures", function ()
    return ns.conditionalDebuffCount( "deadly_poison_dot", "wound_poison_dot", "rupture" )
end )

spec:RegisterStateExpr( "ss_buffed", function ()
    return false
end )

spec:RegisterStateExpr( "non_ss_buffed_targets", function ()
    return active_enemies
end )

spec:RegisterStateExpr( "ss_buffed_targets_above_pandemic", function ()
    return 0
end )

spec:RegisterStateExpr( "pmultiplier", function ()
    if not this_action or this_action == "variable" then return 0 end

    local a = class.abilities[ this_action ]
    if not a then return 0 end

    local aura = a.aura or this_action
    if not aura then return 0 end

    if debuff[ aura ] and debuff[ aura ].up then
        return debuff[ aura ].pmultiplier or 1
    end

    return 0
end )

spec:RegisterStateExpr( "envenom_stacks", function ()
    return ( first_envenom > query_time and 1 or 0 ) + ( second_envenom > query_time and 1 or 0 )
end )

spec:RegisterHook( "reset_precast", function ()
    if buff.vanish.up then applyBuff( "stealth" ) end

    if buff.stealth.up and talent.subterfuge.enabled then
        applyBuff( "subterfuge" )
    end

    -- Tracking Envenom buff stacks.
    first_envenom = min( buff.envenom.expires, envenom1 )
    second_envenom = envenom2

    if Hekili.ActiveDebug then
        Hekili:Debug( "Energy Cap in %.2f -- Enemies: %d, Bleeds: %d, P. Bleeds: %d, P. Garrotes: %d, P. Ruptures: %d", energy.time_to_max, active_enemies, bleeds, poisoned_bleeds, poisoned_garrotes, poisoned_ruptures )
    end
end )

-- We need to break stealth when we start combat from an ability.
spec:RegisterHook( "runHandler", function( ability )
    local a = class.abilities[ ability ]

    if stealthed.all and ( not a or a.startsCombat ) then
        if buff.stealth.up then
            setCooldown( "stealth", 2 )
            removeBuff( "stealth" )
            if talent.subterfuge.enabled then applyBuff( "subterfuge" ) end
        end

        if buff.shadowmeld.up then removeBuff( "shadowmeld" ) end
        if buff.vanish.up then removeBuff( "vanish" ) end
    end

    class.abilities.apply_poison = class.abilities[ action.apply_poison_actual.next_poison ]
end )

-- Auras
spec:RegisterAuras( {
    -- Talent: Abilities used while in Stealth cost 75% less Energy.
    shadow_focus = {
        id = 108209,
        duration = 3600,
        max_stack = 1
    },
    
    -- Talent: Your abilities requiring Stealth can still be used for 3 sec after Stealth breaks.
    subterfuge = {
        id = 115192,
        duration = 3,
        max_stack = 1
    },
    
    -- Stunned.
    cheap_shot = {
        id = 1833,
        duration = 4,
        mechanic = "stun",
        max_stack = 1
    },
    
    -- Talent: Provides a moment of magic immunity, instantly removing all harmful spell effects. The cloak lingers, causing you to resist harmful spells for $d.
    cloak_of_shadows = {
        id = 31224,
        duration = 5,
        max_stack = 1
    },

    -- You have recently escaped certain death.
    cheated_death = {
        id = 45181,
        duration = 90,
        max_stack = 1
    },

    -- All damage taken reduced by $s1%.
    cheating_death = {
        id = 45182,
        duration = 3,
        max_stack = 1
    },

    -- Healing for ${$W1}.2% of maximum health every $t1 sec.
    crimson_vial = {
        id = 185311,
        duration = 4,
        type = "Magic",
        max_stack = 1
    },

    -- Each strike has a chance of poisoning the enemy, slowing movement speed by $3409s1% for $3409d.
    crippling_poison = {
        id = 3408,
        duration = 3600,
        max_stack = 1
    },

    -- Movement slowed by $s1%.
    crippling_poison_dot = {
        id = 3409,
        duration = 12,
        mechanic = "snare",
        type = "Magic",
        max_stack = 1
    },

    -- Each strike has a chance of causing the target to suffer Nature damage every $2818t1 sec for $2818d. Subsequent poison applications deal instant Nature damage.
    deadly_poison = {
        id = 2823,
        duration = 3600,
        max_stack = 1
    },

    -- Suffering $w1 Nature damage every $t1 seconds.
    deadly_poison_dot = {
        id = 2818,
        duration = function () return 12 * haste end,
        max_stack = 1,
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
        }
    },

    -- Disoriented.
    distract = {
        id = 1725,
        duration = 10,
        mechanic = "disorient",
        type = "Ranged",
        max_stack = 1
    },

    -- Talent: Dodge chance increased by ${$w1/2}%.$?a344363[ Dodging an attack while Evasion is active will trigger Mastery: Main Gauche.][]
    evasion = {
        id = 5277,
        duration = 10,
        max_stack = 1
    },

    -- Poison application chance increased by $s2%.$?s340081[  Poison critical strikes generate $340426s1 Energy.][]
    envenom = {
        id = 32645,
        duration = function () return effective_combo_points end,
        tick_time = 5,
        type = "Poison",
        max_stack = 1,
        meta = {
            stack = function( t, type ) if type == "buff" then return state.envenom_stacks end end,
            stacks = function( t, type ) if type == "buff" then return state.envenom_stacks end end,
        }
    },

    -- Talent: Damage taken from area-of-effect attacks reduced by $s1%$?$w2!=0[ and all other damage taken reduced by $w2%.  ][.]
    feint = {
        id = 1966,
        duration = 6,
        max_stack = 1
    },

    garrote = {
        id = 703,
        duration = 18,
        max_stack = 1,
        ss_buffed = false,
        meta = {
            duration = function( t ) return t.up and ( 18 * haste ) or class.auras.garrote.duration end,
            last_tick = function( t ) return t.up and ( tracked_bleeds.garrote.last_tick[ target.unit ] or t.applied ) or 0 end,
            tick_time = function( t )
                if t.down then return haste * 2 end
                local hasteMod = tracked_bleeds.garrote.haste[ target.unit ]
                hasteMod = 2 * ( hasteMod and ( 100 / hasteMod ) or haste )
                return hasteMod
            end,
            haste_pct = function( t ) return ( 100 / haste ) end,
            haste_pct_next_tick = function( t ) return t.up and ( tracked_bleeds.garrote.haste[ target.unit ] or ( 100 / haste ) ) or 0 end,
        }
    },

    -- Silenced.
    garrote_silence = {
        id = 1330,
        duration = 3,
        mechanic = "silence",
        max_stack = 1
    },

    -- Talent: Incapacitated.
    gouge = {
        id = 1776,
        duration = 4,
        mechanic = "incapacitate",
        max_stack = 1
    },

    -- Each strike has a chance of poisoning the enemy, inflicting $315585s1 Nature damage.
    instant_poison = {
        id = 315584,
        duration = 3600,
        max_stack = 1
    },

    -- Stunned.
    kidney_shot = {
        id = 408,
        duration = function() return ( 2 + effective_combo_points ) end,
        mechanic = "stun",
        max_stack = 1
    },

    -- Talent: When your Non-Lethal Poison is applied, you heal for 10% of your damage.
    leeching_poison = {
        id = 108211,
        duration = 3600,
        max_stack = 1
    },

    -- Talent: Attacks which strike this poison have $108212s1% chance to cause the victim to fall asleep for $108212d. Damage caused will awaken the victim. Limit 1.
    paralytic_poison = {
        id = 108215,
        duration = 3600,
        max_stack = 1
    },

    -- Asleep. Damage taken will awaken the victim.
    paralytic_poison_dot = {
        id = 113952,
        duration = 30,
        mechanic = "sleep",
        max_stack = 1
    },

    -- Talent: Target taking 10% increased damage.
    prey_on_the_weak = {
        id = 58670,
        duration = 10,
        max_stack = 1
    },

    rupture = {
        id = 1943,
        duration = function () return 4 * ( 1 + effective_combo_points ) end,
        tick_time = function() return 2 * haste end,
        mechanic = "bleed",
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
        }
    },

    -- Talent: Incapacitated.$?$w2!=0[  Damage taken increased by $w2%.][]
    sap = {
        id = 6770,
        duration = 60,
        mechanic = "sap",
        max_stack = 1
    },

    -- Talent: Movement speed increased by $s2%.
    shadowstep = {
        id = 36554,
        duration = 2,
        max_stack = 1
    },

    -- Attack speed increased by $w1%.
    slice_and_dice = {
        id = 5171,
        duration = function () return 6 * ( 1 + effective_combo_points ) end,
        max_stack = 1
    },

    sprint = {
        id = 2983,
        duration = 8,
        max_stack = 1
    },

    -- Stealthed.
    stealth = {
        id = 115191,
        duration = 3600,
        max_stack = 1,
        copy = 1784
    },

    -- Attacks deal $w1% additional damage.
    vendetta = {
        id = 79140,
        duration = 20,
        max_stack = 1
    },

    -- Improved stealth.$?$w3!=0[  Movement speed increased by $w3%.][]$?$w4!=0[  Damage increased by $w4%.][]
    vanish = {
        id = 11327,
        duration = 3,
        max_stack = 1
    },

    -- Each strike has a chance of inflicting additional Nature damage to the victim and reducing all healing received for $8680d.
    wound_poison = {
        id = 8679,
        duration = 3600,
        max_stack = 1
    },

    -- Healing effects reduced by $w2%.
    wound_poison_dot = {
        id = 8680,
        duration = 12,
        max_stack = 3
    },

    poisoned = {
        alias = { "deadly_poison_dot", "wound_poison_dot" },
        aliasMode = "longest",
        aliasType = "debuff",
        duration = 3600
    },

    lethal_poison = {
        alias = { "deadly_poison", "wound_poison", "instant_poison" },
        aliasMode = "shortest",
        aliasType = "buff",
        duration = 3600
    },

    nonlethal_poison = {
        alias = { "crippling_poison", "paralytic_poison", "leeching_poison" },
        aliasMode = "shortest",
        aliasType = "buff",
        duration = 3600
    },

    -- Tricks of the Trade debuff
    tricks_of_the_trade = {
        id = 57933,
        duration = 6,
        max_stack = 1
    },

    -- Crimson Tempest DoT
    crimson_tempest = {
        id = 122233,
        duration = function () return 6 + ( 6 * effective_combo_points ) end,
        tick_time = 2,
        mechanic = "bleed",
        max_stack = 1
    },

    -- Shadow Blades buff
    shadow_blades = {
        id = 121471,
        duration = 12,
        max_stack = 1
    },

    -- Shadow Dance buff
    shadow_dance = {
        id = 185313,
        duration = 8,
        max_stack = 1
    },

    -- Blind debuff
    blind = {
        id = 2094,
        duration = 60,
        mechanic = "disorient",
        max_stack = 1
    },
} )

-- Abilities
spec:RegisterAbilities( {
    -- Ambush the target, causing $s1 Physical damage.$?s383281[    Has a $193315s3% chance to hit an additional time, making your next Pistol Shot half cost and double damage.][]    |cFFFFFFFFAwards $s2 combo $lpoint:points;$?s383281[ each time it strikes][].|r
    ambush = {
        id = 8676,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 60,
        spendType = "energy",

        startsCombat = true,
        usable = function () return stealthed.ambush, "requires stealth" end,

        cp_gain = function ()
            return 2
        end,

        handler = function ()
            gain( action.ambush.cp_gain, "combo_points" )
        end,
    },

    -- Stuns the target for $d.    |cFFFFFFFFAwards $s2 combo $lpoint:points;.|r
    cheap_shot = {
        id = 1833,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function ()
            if talent.dirty_tricks.enabled then return 0 end
            return 40 end,
        spendType = "energy",

        startsCombat = true,

        cycle = function () if talent.prey_on_the_weak.enabled then return "prey_on_the_weak" end end,

        usable = function ()
            if target.is_boss then return false, "cheap_shot assumed unusable in boss fights" end
            return stealthed.all, "not stealthed"
        end,

        nodebuff = "cheap_shot",

        cp_gain = function () return 1 end,

        handler = function ()
            applyDebuff( "target", "cheap_shot", 4 )

            if talent.prey_on_the_weak.enabled then
                applyDebuff( "target", "prey_on_the_weak" )
            end

            gain( action.cheap_shot.cp_gain, "combo_points" )
        end
    },

    -- Talent: Provides a moment of magic immunity, instantly removing all harmful spell effects. The cloak lingers, causing you to resist harmful spells for $d.
    cloak_of_shadows = {
        id = 31224,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        startsCombat = false,

        toggle = "interrupts",
        buff = "dispellable_magic",

        handler = function ()
            removeBuff( "dispellable_magic" )
            applyBuff( "cloak_of_shadows" )
        end
    },

    -- Drink an alchemical concoction that heals you for $?a354425&a193546[${$O1}.1][$o1]% of your maximum health over $d.
    crimson_vial = {
        id = 185311,
        cast = 0,
        cooldown = 30,
        gcd = "totem",
        school = "nature",

        spend = 30,
        spendType = "energy",

        startsCombat = false,
        texture = 1373904,

        handler = function ()
            applyBuff( "crimson_vial" )
        end
    },

    crippling_poison = {
        id = 3408,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        essential = true,
        texture = 132274,

        readyTime = function () return buff.crippling_poison.remains - 120 end,

        handler = function ()
            applyBuff( "crippling_poison" )
        end
    },

    deadly_poison = {
        id = 2823,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        essential = true,
        texture = 132290,

        readyTime = function () return buff.deadly_poison.remains - 120 end,

        handler = function ()
            applyBuff( "deadly_poison" )
        end
    },

    -- Deal damage with increased attack power, increasing by $s1% per combo point:    1 point  : $s2% attack power    2 points: $s3% attack power    3 points: $s4% attack power    4 points: $s5% attack power    5 points: $s6% attack power
    dispatch = {
        id = 111240,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",

        spend = function() return 30 end,
        spendType = "energy",

        startsCombat = true,

        usable = function() 
            return effective_combo_points > 0 and target.health_pct < 35, "requires combo_points and target below 35% health" 
        end,

        handler = function ()
            spend( combo_points.current, "combo_points" )
        end
    },

    -- Throws a distraction, attracting the attention of all nearby monsters for $s1 seconds. Usable while stealthed.
    distract = {
        id = 1725,
        cast = 0,
        cooldown = 30,
        gcd = "totem",
        school = "physical",

        spend = 30,
        spendType = "energy",

        startsCombat = false,
        texture = 132289,

        handler = function ()
        end
    },

    -- Finishing move that drives your poisoned blades in deep, dealing instant Nature damage and increasing your poison application chance by 30%. Damage and duration increased per combo point. 1 point : 288 damage, 2 sec 2 points: 575 damage, 3 sec 3 points: 863 damage, 4 sec 4 points: 1,150 damage, 5 sec 5 points: 1,438 damage, 6 sec
    envenom = {
        id = 32645,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "nature",

        spend = 35,
        spendType = "energy",

        startsCombat = true,

        usable = function () return combo_points.current > 0, "requires combo_points" end,

        handler = function ()
            local app_duration = spec.auras.envenom.duration + min( 0.3 * spec.auras.envenom.duration, buff.envenom.remains )
            second_envenom = first_envenom
            first_envenom = query_time + app_duration

            addStack( "envenom" ) -- Buff.
            applyDebuff( "target", "envenom" ) -- Debuff.

            spend( combo_points.current, "combo_points" )
        end
    },

    -- Talent: Increases your dodge chance by ${$s1/2}% for $d.$?a344363[ Dodging an attack while Evasion is active will trigger Mastery: Main Gauche.][]
    evasion = {
        id = 5277,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "physical",

        startsCombat = false,

        toggle = "defensives",

        handler = function ()
            applyBuff( "evasion" )
        end,
    },

    -- Sprays knives at all enemies within 18 yards, dealing 544 Physical damage and applying your active poisons at their normal rate. Deals reduced damage beyond 8 targets. Awards 1 combo point.
    fan_of_knives = {
        id = 51723,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 35,
        spendType = "energy",

        startsCombat = true,
        cycle = function () return buff.deadly_poison.up and "deadly_poison_dot" or nil end,

        cp_gain = function()
            return 1
        end,

        handler = function ()
            gain( action.fan_of_knives.cp_gain, "combo_points" )

            -- This is a rough estimation for AoE poison applications. If required, can be iterated on in the future if it needs to be referenced in an APL
            local newDeadlyPoisons = floor( poison_chance * max( 0, true_active_enemies - active_dot.deadly_poison_dot ) )

            if buff.deadly_poison.up then
                applyDebuff( "target", "deadly_poison_dot" )
                active_dot.deadly_poison_dot = min( active_enemies, active_dot.deadly_poison_dot + newDeadlyPoisons )
            end
        end
    },

    -- Talent: Performs an evasive maneuver, reducing damage taken from area-of-effect attacks by $s1% $?s79008[and all other damage taken by $s2% ][]for $d.
    feint = {
        id = 1966,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        school = "physical",

        spend = function () return 35 end,
        spendType = "energy",

        startsCombat = false,
        texture = 132294,

        handler = function ()
            applyBuff( "feint" )
        end
    },

    -- Garrote the enemy, causing 2,407 Bleed damage over 18 sec. Awards 1 combo point.
    garrote = {
        id = 703,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",

        spend = 45,
        spendType = "energy",

        startsCombat = true,
        aura = "garrote",
        cycle = "garrote",

        cp_gain = function() return 1 end,

        handler = function ()
            applyDebuff( "target", "garrote" )
            debuff.garrote.pmultiplier = persistent_multiplier

            gain( action.garrote.cp_gain, "combo_points" )
        end
    },

    -- Talent: Gouges the eyes of an enemy target, incapacitating for $d. Damage will interrupt the effect.    Must be in front of your target.    |cFFFFFFFFAwards $s2 combo $lpoint:points;.|r
    gouge = {
        id = 1776,
        cast = 0,
        cooldown = 25,
        gcd = "totem",
        school = "physical",

        spend = function () return talent.dirty_tricks.enabled and 0 or 45 end,
        spendType = "energy",

        startsCombat = true,

        cp_gain = function ()
            return 1
        end,

        handler = function ()
            applyDebuff( "target", "gouge" )
            gain( action.gouge.cp_gain, "combo_points" )
        end
    },

    instant_poison = {
        id = 315584,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        essential = true,
        texture = 132273,

        readyTime = function () return buff.instant_poison.remains - 120 end,

        handler = function ()
            applyBuff( "instant_poison" )
        end
    },

    -- A quick kick that interrupts spellcasting and prevents any spell in that school from being cast for 5 sec.
    kick = {
        id = 1766,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        school = "physical",

        startsCombat = true,

        toggle = "interrupts",

        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function ()
            interrupt()
        end
    },

    -- Finishing move that stuns the target$?a426588[ and creates shadow clones to stun all other nearby enemies][]. Lasts longer per combo point, up to 5:;    1 point  : 2 seconds;    2 points: 3 seconds;    3 points: 4 seconds;    4 points: 5 seconds;    5 points: 6 seconds
    kidney_shot = {
        id = 408,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        spend = 25,
        spendType = "energy",

        startsCombat = true,

        usable = function ()
            if target.is_boss then return false, "kidney_shot assumed unusable in boss fights" end
            return combo_points.current > 0, "requires combo points"
        end,

        handler = function ()
            applyDebuff( "target", "kidney_shot", 1 + combo_points.current )
            spend( combo_points.current, "combo_points" )
        end
    },

    -- Talent: When your Non-Lethal Poison is applied, you heal for 10% of your damage.
    leeching_poison = {
        id = 108211,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",

        talent = "leeching_poison",
        startsCombat = false,

        handler = function ()
            applyBuff( "leeching_poison" )
        end
    },

    -- Attack with both weapons, dealing a total of 649 Physical damage. Awards 2 combo points.
    mutilate = {
        id = 1329,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",

        spend = 60,
        spendType = "energy",

        startsCombat = true,
        texture = 132304,

        handler = function ()
            gain( 2, "combo_points" )
        end
    },

    -- Talent: Attacks which strike this poison have $108212s1% chance to cause the victim to fall asleep for $108212d. Damage caused will awaken the victim. Limit 1.
    paralytic_poison = {
        id = 108215,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",

        talent = "paralytic_poison",
        startsCombat = false,

        handler = function ()
            applyBuff( "paralytic_poison" )
        end
    },

    -- Throws a poison-coated knife, dealing 171 damage and applying your active Lethal and Non-Lethal Poisons. Awards 1 combo point.
    poisoned_knife = {
        id = 185565,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",

        spend = 40,
        spendType = "energy",

        startsCombat = true,

        handler = function ()
        end
    },

    -- Talent: When activated, this ability immediately finishes the cooldown on your Vanish, Sprint, and Shadowstep abilities.
    preparation = {
        id = 14185,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        school = "physical",

        talent = "preparation",
        startsCombat = false,

        handler = function ()
            resetCooldown( "vanish" )
            resetCooldown( "sprint" )
            resetCooldown( "shadowstep" )
        end
    },

    -- Pick the target's pocket.
    pick_pocket = {
        id = 921,
        cast = 0,
        cooldown = 0.5,
        gcd = "off",

        startsCombat = true,
        texture = 133644,

        handler = function ()
        end
    },

    -- Finishing move that tears open the target, dealing Bleed damage over time. Lasts longer per combo point. 1 point : 1,250 over 8 sec 2 points: 1,876 over 12 sec 3 points: 2,501 over 16 sec 4 points: 3,126 over 20 sec 5 points: 3,752 over 24 sec
    rupture = {
        id = 1943,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",

        spend = 25,
        spendType = "energy",

        startsCombat = true,
        aura = "rupture",
        cycle = "rupture",

        usable = function ()
            if combo_points.current == 0 then return false, "requires combo_points" end
            return true
        end,

        handler = function ()
            debuff.rupture.pmultiplier = persistent_multiplier
            applyDebuff( "target", "rupture" )

            spend( combo_points.current, "combo_points" )
        end
    },

    sap = {
        id = 6770,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",

        spend = function () return talent.dirty_tricks.enabled and 0 or 35 end,
        spendType = "energy",

        startsCombat = false,

        handler = function ()
            applyDebuff( "target", "sap" )
        end
    },

    -- Talent: Step through the shadows to appear behind your target and gain 70% increased movement speed for 2 sec.
    shadowstep = {
        id = 36554,
        cast = 0,
        cooldown = 24,
        gcd = "off",

        talent = "shadowstep",
        startsCombat = false,
        texture = 132303,

        handler = function ()
            applyBuff( "shadowstep" )
            setDistance( 5 )
        end
    },

    -- Talent: Throws a shuriken at an enemy target, dealing 240% of normal weapon damage. Awards 1 combo point.
    shuriken_toss = {
        id = 114014,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",

        spend = 40,
        spendType = "energy",

        talent = "shuriken_toss",
        startsCombat = true,

        cp_gain = 1,

        handler = function()
            gain( 1, "combo_points" )
        end
    },

    -- Finishing move that consumes combo points to increase attack speed by 50%. Lasts longer per combo point. 1 point : 12 seconds 2 points: 18 seconds 3 points: 24 seconds 4 points: 30 seconds 5 points: 36 seconds
    slice_and_dice = {
        id = 5171,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",

        spend = 25,
        spendType = "energy",

        startsCombat = false,
        texture = 132306,

        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function ()
            applyBuff( "slice_and_dice", combo_points.current * 6 )
            spend( combo_points.current, "combo_points" )
        end
    },

    -- Increases your movement speed by 70% for 8 sec. Usable while stealthed.
    sprint = {
        id = 2983,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,
        texture = 132307,

        toggle = "interrupts",

        handler = function ()
            applyBuff( "sprint" )
        end
    },

    -- Conceals you in the shadows until cancelled, allowing you to stalk enemies without being seen.
    stealth = {
        id = 1784,
        cast = 0,
        cooldown = 2,
        gcd = "off",
        school = "physical",

        startsCombat = false,
        texture = 132320,

        usable = function ()
            if time > 0 then return false, "cannot stealth in combat"
            elseif buff.stealth.up then return false, "already in stealth"
            elseif buff.vanish.up then return false, "already vanished" end
            return true
        end,

        handler = function ()
            applyBuff( "stealth" )
            if talent.subterfuge.enabled then applyBuff( "subterfuge" ) end
        end,

        copy = 115191
    },

    -- Increases your Energy regeneration rate by 100% for 15 sec.
    vendetta = {
        id = 79140,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "physical",

        startsCombat = true,
        texture = 458726,

        toggle = "cooldowns",

        handler = function ()
            applyBuff( "vendetta" )
            applyDebuff( "target", "vendetta" )
        end
    },

    -- Allows you to vanish from sight, entering stealth while in combat. For the first 3 sec after vanishing, damage and harmful effects received will not break stealth. Also breaks movement impairing effects.
    vanish = {
        id = 1856,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        startsCombat = false,
        texture = 132331,

        disabled = function ()
            if ( settings.solo_vanish and solo ) or group then return false end
            return true
        end,

        toggle = "cooldowns",

        handler = function ()
            applyBuff( "vanish" )
            applyBuff( "stealth" )
            if talent.subterfuge.enabled then applyBuff( "subterfuge" ) end
        end
    },

    wound_poison = {
        id = 8679,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        essential = true,
        texture = 134197,

        readyTime = function () return buff.wound_poison.remains - 120 end,

        handler = function ()
            applyBuff( "wound_poison" )
        end
    },

    -- TODO: Dragontempered Blades allows for 2 Lethal Poisons and 2 Non-Lethal Poisons.
    apply_poison_actual = {
        name = "|cff00ccff[" .. _G.MINIMAP_TRACKING_VENDOR_POISON .. "]|r",
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        essential = true,

        next_poison = function()
            if buff.lethal_poison.down then
                if action.deadly_poison.known and buff.deadly_poison.down then return "deadly_poison"
                elseif action.instant_poison.known and buff.instant_poison.down then return "instant_poison"
                elseif action.wound_poison.known and buff.wound_poison.down then return "wound_poison" end

            elseif buff.nonlethal_poison.down then
                if talent.leeching_poison.enabled and buff.leeching_poison.down then return "leeching_poison"
                elseif talent.paralytic_poison.enabled and buff.paralytic_poison.down then return "paralytic_poison"
                elseif action.crippling_poison.known and buff.crippling_poison.down then return "crippling_poison" end
            end

            return "apply_poison_actual"
        end,

        texture = function ()
            local np = action.apply_poison_actual.next_poison
            if np == "apply_poison_actual" then return 136242 end
            return action[ np ].texture
        end,

        bind = function ()
            return action.apply_poison_actual.next_poison
        end,

        readyTime = function ()
            if action.apply_poison_actual.next_poison ~= "apply_poison_actual" then return 0 end
            return 0.01 + min( buff.lethal_poison.remains, buff.nonlethal_poison.remains )
        end,

        handler = function ()
            applyBuff( action.apply_poison_actual.next_poison )
        end,

        copy = "apply_poison"
    },

    -- Shiv the target, dealing 1,250 Physical damage. Awards 1 combo point.
    shiv = {
        id = 5938,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",

        spend = 40,
        spendType = "energy",

        startsCombat = true,

        cp_gain = function() return 1 end,

        handler = function ()
            gain( action.shiv.cp_gain, "combo_points" )
        end
    },

    -- Your next damaging ability threatens the target, causing them to deal 20% less damage to everyone except you for 6 sec. Awards 1 combo point.
    tricks_of_the_trade = {
        id = 57934,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        school = "physical",

        spend = 15,
        spendType = "energy",

        startsCombat = false,

        handler = function ()
            applyDebuff( "target", "tricks_of_the_trade" )
        end
    },

    -- Finishing move that causes a Crimson Tempest to erupt on the target and all nearby enemies, dealing Bleed damage every 2 sec for 6 to 30 sec. Longer duration per combo point.
    crimson_tempest = {
        id = 121411,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",

        spend = 35,
        spendType = "energy",

        startsCombat = true,

        usable = function () return combo_points.current > 0, "requires combo_points" end,

        handler = function ()
            applyDebuff( "target", "crimson_tempest", 6 + ( 6 * combo_points.current ) )
            spend( combo_points.current, "combo_points" )
        end
    },

    -- Draws upon surrounding shadows to empower your weapons, causing your attacks to deal 50% additional damage as Shadow damage and granting your abilities a chance to generate Shadow Clones for 12 sec.
    shadow_blades = {
        id = 121471,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",

        startsCombat = false,
        texture = 376022,

        toggle = "cooldowns",

        handler = function ()
            applyBuff( "shadow_blades" )
        end
    },

    -- Jade Serpent Potion (MoP Classic consumable)
    jade_serpent_potion = {
        id = 76093,
        cast = 0,
        cooldown = 0,
        gcd = "off",

        startsCombat = false,
        item = true,

        handler = function ()
            -- Potion effect handled by game
        end
    },

    -- Blind the target, causing it to wander disoriented for 1 min.
    blind = {
        id = 2094,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        school = "physical",

        spend = function () return talent.dirty_tricks.enabled and 0 or 30 end,
        spendType = "energy",

        startsCombat = true,

        handler = function ()
            applyDebuff( "target", "blind" )
        end
    },

    -- Generic trinket support
    use_items = {
        id = 0,
        cast = 0,
        cooldown = 0,
        gcd = "off",

        item = true,
        startsCombat = false,

        handler = function ()
            -- Generic item use
        end
    }
} )

spec:RegisterRanges( "pick_pocket", "mutilate", "blind", "shadowstep" )

spec:RegisterOptions( {
    enabled = true,

    aoe = 3,
    cycle = false,

    nameplates = true,
    nameplateRange = 10,
    rangeFilter = false,

    canFunnel = true,
    funnel = false,

    damage = true,
    damageExpiration = 6,

    potion = "virmens_bite",

    package = "Assassination",
} )

spec:RegisterPack( "Assassination", 20250406, [[Hekili:9QvAZTnU5)plE6ufNzZQvs2YzBN1EgLyL9VsDKZyPU703isisil838Q8WhD8Op79bNeeeeskjtFXUHchpx45c)GxnC1YvlcrL4vZhny04bVFWz9hmCWWXRwu(sgE1ImuWdO7HpsqXW)Frv(JKhrrdPZ8sukkKsGI0Q8ay2vlwxrIkNLSADBQoy4zdHTvKHdGHhdCyljmeZxlUiy1ILBjf78P)hANVGX78t3a)oOKKMSZpIuuctVjnFN))h(bsePpii5PBira7)lWGvjLyysPCUZ)N35)L0VUZ)0prEgh2yVVD3N39zyt)XK7Mn5d3mDXo)jZVEN)hVD(1Zwo725lOl4ruobToc)oQf4YnPbvfEBj3V9Da5RedC1LxmW(kJsFsFH)25DSUyCiPkUjnpFqp(MAtCQvKGI8QsiLInvIYVhx2hhrkXV(Q4xr4hXrxDzwe6fCo)x)0zQzljXyVYuVqc(QHJBXdCEgoP0ROKKCVxoEtoUqQ1HPL9BmF)CCmIKaYQjzwhbNKEO880NmiYjuQOnnipbpa0YKcrP0vKe6r938O(cpIfKyD1Mn9BmF)QmZ9xUnNef5LUXRCl2Bl4IyHiTxeJsmhKVufvs(zUrdCgta3OjPt35hIlXCptdoIsXEfKYkeDsbxGJmG(CIu0pMssVITPLxD5zMBpicJE8WPWLJeY5httJctFccuGtwQH0xs3ctwKJYiHEBi5yp0JiseBgoBceuPF9AGtxu4l9oHzP0gUkdglknnmQQO0ILVQa7jjxHG8Yv0x3hUNfpYrdOQftX(6Dt)4TF5dtwY(8RtUBcn8C3N55fk6NLJdsJxJk)Pl)feLULQds0tp8oYMl5IE754Qq75c2IXLOTmDYgxcqWrrgUKr7mAC3ZSCtwx8wwwjiihLZfMqmJL6JtfKocl5(GtMnhC7(itXbRWSBVB2Y)1o)BMTyjBbtJXWUtcEr4HwvcP4kFrM8SqqNjm1CNFmkbsVgdbWkzwQw8F6rt2kCNz7rsHpHj3dUyxJrLB35JvSvJmBOlXlKUcQ(UfJIk32plO834hQ0Jue4CSZppTeXZThKMes4sknP9wylIS1chf4dzarHoZEcb5alWbxoO)qk3ItFe897XJwifIagyOxFLz1dZjjuZT4NBa3x2VItPhhHs5dFKgjWjWtF9mQCnEdoPas1yCOSxQfQ2O4yJMVzDokjylld5(2pKbIAlubBnYizKUOqiCXO)FQ5gTMkJeCX(5Ik2wrXC9Z09U)6vkvZfFD6hxs92Np53N(LPZHVRJPe(HTcYfbRSqlXPypHxWHgB3fPL5p2dzKh3t)005lM9htfDs8pxo7gAuQInQJvGr4N3c5DZ5z4bwCQwyY4bV(knRsJiN3ANo81uuMMGnc2OnByBhXKIqi9DGKZqTpiuTVY)4Qlh1706KAY(KwcUF)BObpY)HvBzbu6reHgJUNea(NGrQ4xWj5qqqHDwxQtdw1lMaWt8fsybTuhwzu40Mod1PxBeTr1jm0aGiHSHLRaxsd)5BIoETJHCx0SVwZIBYMoZ7lJaU92BU(2)CEtPMM)MhCD9xxqt1Pc8AMGJwkegmnjQofrF1Qb2xx7Tr0DJ6S9udBRiVD6wuIIZWHUO6PTl(dzq1k()2EQohKKJ33qhQcmfjbxu4GN2BfH1O5vJuELq6CCzh2sRSMYeOl543vebDpvYjWWULJJGkJCrfM8EhIlF1Pz9dRYzrukzhQNMY7nWoRr5bOeApc55GBjLL8lkC24EhJgSgyaoN2Y9XQ7SZDVnv5VSx9DY9I(qYszP6vA7wCEkPi(xu(q2zfFB86fpsYH4WcV1GDNLvwZ9RtnN7Lm5gwXKjFGMrEgCxp2Oe6Lfph6xgfbgYou2n48htZ55POlRpFG(4ek7cfxsJEDnEsfX06Lx0jhn1R3AmQOuJK1dkjRuWzI44Ar0xVIydNcV4Q8qCoT(uaCDQcnY3AoLWl7fT9k0nP69Q3Lhb4)d3fmN8awJX6dxuRA2Oq0ljp7LxvSvB7QXAjV1Z0TCQzaVypNX3hHGcuqevHUztBu3YEw6tqSKQAgBZQXuY(XyoHBedvD0TK8rmCpMCl0RXD3UKFHi)tp7NO(6397txUqRDbO7VdHM1cynmhMe5GnuhcXQVdBJ0iDVHGuOh4U2qu6tA1HVRHHrm8coMfWhLSCqOSSisG4giSMGfquOhKj7sLwNuhZdwpaTrcrGIrx3MZcvBQvDtXA)hBqZ486J)dsuKSLncOR4NXbvL0M1rjuu2oD0G)knLmTPP3AviFGcpIrdBAnzDP6MDtFolkLFNho)YYjP5SsaN(0wmW8e6O3Kg8GWMFtkk0otXsAP48jkJGnyHeIWhOGkbbhuuLe9fWCr25dxvfNRFEFD6sRCwdxQgUAwGZsWudfYIH4uQlnUOHjHBr4s)HAdoetWewlcn6sxyccRIZ6W9w0xHKpNkb389V(QINDIM2BT5aEH6MHGlUnPr)a5acoe1AV4IEUDe6DIQ3XM2pjuwQP1bGu0UkhMJzZNCd9FU5MP3PKm7ceCHPXRw8ekpHEpdks2GLNeNLMl12308MeVHMObUhuofs6I0yk(avLPXikae(bBPbLf9395Bi0ZWr)D4QKjfvzucsxaxyaQkVoYB6tLABSvcd1)Z4OQk2pkokVmXBuRD4zDUy9(n6ueLExhNeo2btvUqDYt1LGpoMEENmT9nP58EwSCP)QXdNatVAb7l6J2iq8a(Co7vGeLTx9HvlcGutyi4A1ItG72lGfZVh97hzLnHppHFD)oXebyaJ3sgzSc(B(KtY4RXgUpRkxnFuNs23eZPO5aKTC1IMHJUncnHtyN)VbNBwGuOHzrdyb241qfulBY1yylmW8WTz4e7KwgLYvwW3dbDAztlBWzNymVFaMTGTSHeX)bdaqUNOh)zfL(IovvJJGrdQjUgEZgQuhGvt50zUmfFFWtVArboy1Ib9hwlJuyQ1vhzS0o)xFv40irMwBib608reHIuH)CNcp(B5qWiKayYyxmPdOTpqMPshs5ZfU4ttKVDr(ABRDyVB6YLYy97DX69bq(bQRQkIug(RUzOo(5hi5vlhO(FRZOhr7wxDje5mwJYQMzmdC0B)rKZu2lXERz09JT9Dv7GL(UPyEKp4VR36)aEMxNVWAhVs53B(7w5PASz7VKiZk3UBC44hAEs70xFB8Z4AFvNNXDG1gLTorFUM11ZAgdydb9Jg(C3wDhIFBuUPPO7vZvdWTR1i54UpZCWAhODZo5gPz9KGNBRwGCrsGTbrlIgFx)79joghjoHy3wHcdjy0HWXgY4iBLfALmd6c4SXnD6miQkpsdaZnuVJdrEBvn2V2jfKAi3Tvm4iOJcaEBP9Bwa9GbGx(x5Lom7hJqXzavGgoOtnZkg6Sdr5PkuI68bnkuOquxVLp6qMoQTq5Vfe)mPR7eBDchFnNRNJrRUZYSpS3LQOde4B6CRdBSMVT5(mnkwEbbMK3DskxG3R7dQnnJIMzIArXw45Byd0r1)q0D16zS3mnul2BbM6AAPnPvl4fn9H6o7ux4)FikKAtmE0DEg7a4RD2WNGxux1H4(6BRtONp0gkAS5wf2nGK)yqJ3D9C3YTByZpuvtRtzNf4BbnopJM(1vvqPByHokq6Tv5VXHPt8rRfMMWJAirFJy5BRNalLrSGLUE2f1Kgc1XHUV7oj(ryK(ba8V7MkovPG0RVDX75ObSFe535)wxE3x0Q)ilk3(Ehb3TXOvs)IlK56D)8fIf5e((wlQfi(hWnCpONKyLeanbAfoZGAGq14b6oq1)XEzcKI9)OXCNXZGvNRXkT)EWALPATLmvA)vxP35Uj6YTUtWX8hdg3msXCXPbSJN6Urs86hhUD1odxxhVnUBRRJN)FVYIEBeh2nbTrL6xg3DE(2pbEhvS4havLBPnn)NKimumeLbxiInZQ)7d]] )
