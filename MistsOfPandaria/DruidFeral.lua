if UnitClassBase( 'player' ) ~= 'DRUID' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State
local currentBuild = select( 4, GetBuildInfo() )

local FindUnitDebuffByID = ns.FindUnitDebuffByID
local FindUnitBuffByID = ns.FindUnitBuffByID
local round = ns.round

local strformat = string.format

local spec = Hekili:NewSpecialization( 103, "feral", "Mists of Pandaria" )

-- Trinkets
-- MoP Trinkets
spec:RegisterGear( "relic_of_chi_ji", 94511 )
spec:RegisterGear( "relic_of_niuzao", 94512 )
spec:RegisterGear( "relic_of_xuen", 94513 )
spec:RegisterGear( "relic_of_yu_lon", 94514 )
spec:RegisterGear( "bottle_of_infinite_stars", 86301 )
spec:RegisterGear( "bottle_of_infinite_stars_lfr", 86326 )
spec:RegisterGear( "bottle_of_infinite_stars_heroic", 86350 )
spec:RegisterGear( "stuff_of_nightmares", 86308 )
spec:RegisterGear( "stuff_of_nightmares_lfr", 86333 )
spec:RegisterGear( "stuff_of_nightmares_heroic", 86357 )
spec:RegisterGear( "lei_shens_final_orders", 95802 )
spec:RegisterGear( "lei_shens_final_orders_lfr", 96540 )
spec:RegisterGear( "lei_shens_final_orders_heroic", 96741 )
spec:RegisterGear( "bad_juju", 95810 )
spec:RegisterGear( "bad_juju_lfr", 96548 )
spec:RegisterGear( "bad_juju_heroic", 96749 )
spec:RegisterGear( "wushoolays_final_choice", 95815 )
spec:RegisterGear( "wushoolays_final_choice_lfr", 96553 )
spec:RegisterGear( "wushoolays_final_choice_heroic", 96754 )
spec:RegisterGear( "renatakis_soul_charm", 95802 )
spec:RegisterGear( "renatakis_soul_charm_lfr", 96540 )
spec:RegisterGear( "renatakis_soul_charm_heroic", 96741 )
spec:RegisterGear( "ticking_ebon_detonator", 101801 )
spec:RegisterGear( "ticking_ebon_detonator_lfr", 102293 )
spec:RegisterGear( "ticking_ebon_detonator_heroic", 102658 )
spec:RegisterGear( "haromms_talisman", 101797 )
spec:RegisterGear( "haromms_talisman_lfr", 102289 )
spec:RegisterGear( "haromms_talisman_heroic", 102654 )
spec:RegisterGear( "assurance_of_consequence", 101805 )
spec:RegisterGear( "assurance_of_consequence_lfr", 102297 )
spec:RegisterGear( "assurance_of_consequence_heroic", 102662 )
spec:RegisterGear( "rooks_unlucky_talisman", 101804 )
spec:RegisterGear( "rooks_unlucky_talisman_lfr", 102296 )
spec:RegisterGear( "rooks_unlucky_talisman_heroic", 102661 )

-- MoP Idols/Relics
spec:RegisterGear( "inscribed_tiger_staff", 86196 )
spec:RegisterGear( "inscribed_crane_staff", 86197 )
spec:RegisterGear( "inscribed_serpent_staff", 86198 )
spec:RegisterGear( "flawless_pandaren_relic", 88368 )


-- MoP
--- Feral
spec:RegisterGear( "tier14feral", 85326, 85327, 85328, 85329, 85330, 86621, 86622, 86623, 86624, 86625, 87165, 87166, 87167, 87168, 87169 )
spec:RegisterGear( "tier15feral", 95305, 95306, 95307, 95308, 95309, 96631, 96632, 96633, 96634, 96635, 97045, 97046, 97047, 97048, 97049 )
spec:RegisterGear( "tier16feral", 99060, 99061, 99062, 99063, 99064, 100906, 100907, 100908, 100909, 100910, 102246, 102247, 102248, 102249, 102250 )

local function rage_amount()
    --local d = UnitDamage( "player" ) * 0.7
    --local c = ( state.level > 70 and 1.4139 or 1 ) * ( 0.0091107836 * ( state.level ^ 2 ) + 3.225598133 * state.level + 4.2652911 )
    --local f = 3.5
    --local s = 2.5
-- 
    --return min( ( 15 * d ) / ( 4 * c ) + ( f * s * 0.5 ), 15 * d / c )
    local hit_factor = 6.5
    local speed = 2.5 -- fixed for bear
    local rage_multiplier = 1

    return hit_factor * speed * rage_multiplier

end

-- Generic function to calculate the total damage for an ability
-- Parameters:
-- flatdmg: The base damage or pre-calculated damage of the ability with AP/WeaponDPS
-- coefficient: The scaling coefficient for the damage source, if AP is already calculated use 0 to avoid double counting
-- weaponBased: Boolean indicating if the damage is based on weapon DPS, if false it is based on attack power
-- masteryFlag: Boolean indicating if mastery affects the ability, for feral only apply for bleed damage
-- armorFlag: Boolean indicating if armor reduction should be applied. Armor reduces physical damage
-- talentAndBuffModifiers: Combined modifiers from talents and buffs
-- critChanceMult: Extra multiplier for critical chance, use nil as default
-- Returns: The total damage after applying all modifiers
local function calculate_damage(flatdmg, coefficient, weaponBased, masteryFlag, armorFlag, talentAndBuffModifiers, critChanceMult)
    local feralAura = 1
    local armor = 1
    local mastery = 1

    if armorFlag then
        local boss_armor = 10643 * (1 - 0.2*(state.debuff.major_armor_reduction.up and 1 or 0)) * (1 - 0.2 * (state.debuff.shattering_throw.up and 1 or 0))
        local armor_coeff = (1 - boss_armor/15232.5) -- no more armor_pen
        local armor = armorFlag and armor_coeff or 1
    end
    if masteryFlag then
        mastery = state.talent.mangle.enabled and (1.25 + state.stat.mastery_value * 0.03125) or 1 -- razorClawsMultiplier
    end

    local crit = math.min((1 + state.stat.crit*0.01*(critChanceMult or 1)), 2)
    local tf = state.buff.tigers_fury.up and class.auras.tigers_fury.multiplier or 1
    local sourceDamageValue = (weaponBased and state.stat.weapon_dps) or state.stat.attack_power

    return (flatdmg + coefficient*sourceDamageValue) * crit * mastery * feralAura * armor * tf * talentAndBuffModifiers
end

-- Force reset when Combo Points change, even if recommendations are in progress.
spec:RegisterUnitEvent( "UNIT_POWER_FREQUENT", "player", nil, function( _, _, powerType )
    if powerType == "COMBO_POINTS" then
        Hekili:ForceUpdate( powerType, true )
    end
end )

-- Glyph of Shred helper
local tracked_rips = {}
local rip_extension = 6
Hekili.TR = tracked_rips;

local function NewRip( target, tfactive )
    tracked_rips[ target ] = {
        --extension = 0,
        --applications = 0,
        tf_snapshot = tfactive
    }
    rip_extension = 0
end
local function DummyRip( target )
    if not tracked_rips[ target ] then
        tracked_rips[ target ] = {
            --extension = 0,
            --applications = 0,
            tf_snapshot = false
        }
    end
end

local function RipShred( target ) -- called on shreded targets having rip
    if not tracked_rips[ target ] then
        DummyRip( target )
    end
    --if tracked_rips[ target ].applications < 3 then
    --    tracked_rips[ target ].extension = tracked_rips[ target ].extension + 2
    --    tracked_rips[ target ].applications = tracked_rips[ target ].applications + 1
    --end
    if rip_extension < 6 then
        rip_extension = rip_extension + 2
    end
end

local function RemoveRip( target )
    tracked_rips[ target ] = nil
end

local function GetTrackedRip( target ) 
    if not tracked_rips[ target ] then
        DummyRip( target ) -- I think this is just to avoid "nullpointer" - dont want to reset extension, so will add dummy
    end
    -- Rip-Extends are shared across all targets, so we override here
    local tr = tracked_rips[ target ]
    tr.extension = rip_extension
    return tr
end


-- Combat log handlers
local attack_events = {
    SPELL_CAST_SUCCESS = true
}

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

local death_events = {
    UNIT_DIED               = true,
    UNIT_DESTROYED          = true,
    UNIT_DISSIPATES         = true,
    PARTY_KILL              = true,
    SPELL_INSTAKILL         = true,
}

spec:RegisterCombatLogEvent( function( _, subtype, _, sourceGUID, sourceName, _, _, destGUID, destName, destFlags, _, spellID, spellName )
    if sourceGUID ~= state.GUID then
        return
    end
    
    -- track buffed rips using rip_tracker as well
    if attack_events[subtype] then
        if spellID == 1079 then -- Spell is rip
            local tf_up = not( FindUnitBuffByID( "player", 5217 ) == nil) -- if buff is not active, will eval to nil
            NewRip( destGUID, tf_up)
        end
    end

    if state.glyph.bloodletting.enabled then
        if attack_events[subtype] then
            -- Track rip time extension from Glyph of Rip
            if spellID == 5221 and not( FindUnitDebuffByID( "target", 1079 ) == nil) then -- Spell is Shred and rip is active on target
                RipShred( destGUID )
            end
        end

        --if application_events[subtype] then
        --    -- Remove previously tracked rip
        --    if spellID == 1079 then
        --        RemoveRip( destGUID )
        --    end
        --end

        if removal_events[subtype] then
            -- Remove previously tracked rip
            if spellID == 1079 then
                RemoveRip( destGUID )
            end
        end

        if death_events[subtype] then
            -- Remove previously tracked rip
            if spellID == 1079 then
                RemoveRip( destGUID )
            end
        end
    end
end, false )

spec:RegisterHook( "UNIT_ELIMINATED", function( guid )
    RemoveRip( guid )
end )

local LastFinisherCp = 0
local LastSeenCp = 0
local CurrentCp = 0
local DruidFinishers = {
    [52610] = true,
    [22568] = true,
    [1079] = true,
    [22570] = true
}

spec:RegisterUnitEvent( "UNIT_SPELLCAST_SUCCEEDED", "player", "target", function(event, unit, _, spellID )
    if DruidFinishers[spellID] then
        LastSeenCp = GetComboPoints("player", "target")
    end
end)

spec:RegisterUnitEvent( "UNIT_POWER_UPDATE", "player", "COMBO_POINTS", function(event, unit)
    CurrentCp = GetComboPoints("player", "target")
    if CurrentCp == 0 and LastSeenCp > 0 then
        LastFinisherCp = LastSeenCp
    end
end)

spec:RegisterStateTable( "rip_tracker", setmetatable( {
    cache = {},
    reset = function( t )
        table.wipe(t.cache)
    end
    }, {
    __index = function( t, k )
        if not t.cache[k] then
            local tr = GetTrackedRip( k )
            if tr then
                t.cache[k] = { extension = tr.extension, tf_snapshot = tr.tf_snapshot}
            end
        end
        return t.cache[k]
    end
}))

-- This function calculates the "Rend and Tear" damage modifier for the Shred/Maul ability when it is applied to a bleeding target.
spec:RegisterStateExpr("rend_and_tear_mod_shred", function()
    local mod_list = {1.07, 1.13, 1.2}
    if not debuff.bleed.up or talent.rend_and_tear.rank == 0 then
        return 1
    else
        return mod_list[talent.rend_and_tear.rank]
    end
end)

-- This function calculates the "Rend and Tear" critical modifier for the Ferocious Bite ability when it is applied to a bleeding target.
spec:RegisterStateExpr("rend_and_tear_mod_bite", function()
    local mod_list = {1.08, 1.17, 1.25}
    if not debuff.bleed.up or talent.rend_and_tear.rank == 0 then
        return 1
    else
        return mod_list[talent.rend_and_tear.rank]
    end
end)

local lastfinishercp = nil
spec:RegisterStateExpr("last_finisher_cp", function()
    return lastfinishercp
end)

spec:RegisterStateFunction("set_last_finisher_cp", function(val)
    lastfinishercp = val
end)

spec:RegisterStateExpr("pseudo_rip_tf_snapshot", function()
    if tracked_rips[ target.unit ] then
       return tracked_rips[ target.unit ].tf_snapshot 
    end
    return "leer"
end)

spec:RegisterStateExpr("rip_tf_snapshot", function()
    return rip_tracker[target.unit].tf_snapshot
end)

local ExpirePrimalMadness = setfenv( function ()

    if buff.primal_madness.up then
        gain(-10 * talent.primal_madness.rank, "energy")
        energy.max = energy.max - 10 * talent.primal_madness.rank
    end
end, state )

spec:RegisterStateFunction( "should_cancel_primal_madness", function()
    -- Don't cancel if option is disabled
    if not settings.cancel_primal_madness then return false end
    
    -- Don't cancel if we don't have the Primal Madness buff
    if not buff.primal_madness.up then return false end
    
    -- Figure out how much time is left on the buff
    local time_left = buff.primal_madness.remains
    
    -- Figure out which buff is causing Primal Madness (Tiger's Fury or Berserk)
    local is_berserk_active = buff.berserk.up and buff.primal_madness.expires == buff.berserk.expires
    
    -- Figure out how much energy we'll lose when it expires naturally
    local energy_loss = 10 * talent.primal_madness.rank
    
    -- Calculate how much energy can be regenerated in the remaining time
    local energy_to_gain = energy.regen * time_left
    
    -- Calculate conservative threshold based on ability costs
    -- We'll consider it a loss if we can't fit one more 40-energy Shred (offset by 10-20 energy we'd lose from PM)
    local expected_energy_benefit = energy.current + energy_to_gain - energy_loss
    
    -- If we're under 20 energy, we won't be able to use this energy effectively before buff expires
    return energy.current < 20 and expected_energy_benefit < 40
end )

spec:RegisterStateExpr("primal_madness_cancel_thresh", function()
    -- In practice, this will be around 20 energy depending on how much time is left on buff
    return 20
end)

local training_dummy_cache = {}
local avg_rage_amount = rage_amount()
spec:RegisterHook( "reset_precast", function()
    stat.spell_haste = stat.spell_haste * ( 1 + ( 0.01 * talent.celestial_focus.rank ) + ( buff.natures_grace.up and 0.2 or 0 ) + ( buff.moonkin_form.up and ( talent.improved_moonkin_form.rank * 0.01 ) or 0 ) )

    rip_tracker:reset()
    set_last_finisher_cp(LastFinisherCp)

    if buff.primal_madness.up then
        buff.primal_madness.expires = max(buff.tigers_fury.expires, buff.berserk.expires)
        state:QueueAuraExpiration( "primal_madness", ExpirePrimalMadness, buff.primal_madness.expires)
    end
    
    --if IsCurrentSpell( class.abilities.maul.id ) then
    --    start_maul()
    --    Hekili:Debug( "Starting Maul, next swing in %.2f...", buff.maul.remains)
    --end

    avg_rage_amount = rage_amount()

    if debuff.training_dummy.up and not training_dummy_cache[target.unit] then
        training_dummy_cache[target.unit] = true
    end
end )

spec:RegisterStateExpr("rage_gain", function()
    return avg_rage_amount
end)

spec:RegisterStateExpr("rip_canextend", function()
    return debuff.rip.up and glyph.bloodletting.enabled and rip_tracker[target.unit].extension < 6
end)

spec:RegisterStateExpr("rip_maxremains", function()
    if debuff.rip.remains == 0 then
        return 0
    else
        return debuff.rip.remains + ((debuff.rip.up and glyph.bloodletting.enabled and (6 - rip_tracker[target.unit].extension)) or 0)
    end
end)


spec:RegisterStateExpr( "mainhand_remains", function()
    local next_swing, real_swing, pseudo_swing = 0, 0, 0
    if now == query_time then
        real_swing = nextMH - now
        next_swing = real_swing > 0 and real_swing or 0
    else
        if query_time <= nextMH then
            pseudo_swing = nextMH - query_time
        else
            pseudo_swing = (query_time - nextMH) % mainhand_speed
        end
        next_swing = pseudo_swing
    end
    return next_swing
end)


spec:RegisterStateExpr("is_training_dummy", function()
    return training_dummy_cache[target.unit] == true
end)

spec:RegisterStateExpr("ttd", function()
    if is_training_dummy then
        return Hekili.Version:match( "^Dev" ) and settings.dummy_ttd or 300
    end

    return target.time_to_die
end)

spec:RegisterStateExpr("base_end_thresh", function()
    return calc_rip_end_thresh
end)

spec:RegisterStateExpr("bite_at_end", function()
    return combo_points.current == 5 and (ttd < end_thresh_for_clip or (debuff.rip.up and ttd - debuff.rip.remains < base_end_thresh))
end)

spec:RegisterStateExpr("is_execute_phase", function()
    -- Check for Tier 13 feral set bonus which extends Blood in the Water to 60% health
    if set_bonus.tier13feral_2pc == 1 and talent.blood_in_the_water.rank > 0 then
        return target.health.pct <= 60
    end
    
    -- Default Blood in the Water functionality (25% health)
    return target.health.pct <= 25
end)

spec:RegisterStateExpr("can_bite", function()
    if buff.tigers_fury.up and is_execute_phase then
        return true
    end

    if buff.savage_roar.remains < settings.min_bite_sr_remains then
        return false
    end
    
    if is_execute_phase then
        return not rip_tf_snapshot
    end 

    return debuff.rip.remains >= settings.min_bite_rip_remains
end)

spec:RegisterStateExpr("bite_before_rip", function()
    return combo_points.current == 5 and debuff.rip.up and buff.savage_roar.up and (settings.ferociousbite_enabled or is_execute_phase) and can_bite
end)

spec:RegisterStateExpr("bite_now", function()
    local bite_now =  (bite_before_rip or bite_at_end) and not buff.clearcasting.up
    -- Ignore minimum CP enforcement during Execute phase if Rip is about to fall off
    local emergency_bite_now = is_execute_phase and debuff.rip.up and (debuff.rip.remains < debuff.rip.tick_time) and (combo_points.current >= 1) and talent.blood_in_the_water.rank == 2

    return bite_now or emergency_bite_now
end)


spec:RegisterStateExpr("wait_for_tf", function()
    --cooldown.tigers_fury.remains<=buff.berserk.duration&cooldown.tigers_fury.remains+1<ttd-buff.berserk.duration
    return talent.berserk.enabled and ( cooldown.tigers_fury.remains <= buff.berserk.duration and cooldown.tigers_fury.remains + latency < ttd - buff.berserk.duration )
end)

spec:RegisterStateExpr("try_tigers_fury", function()
    -- Handle Tiger's Fury
    if not cooldown.tigers_fury.up then
        return false
    end

    local gcdTimeToRdy = gcd.remains
    local leewayTime = max(gcdTimeToRdy, latency)
    local tfEnergyThresh = calc_tf_energy_thresh(leewayTime)
    local tfNow = (energy.current < tfEnergyThresh) and not buff.berserk.up and (not buff.T13Feral4pBonus.IsActive() or not buff.stampede_cat.up or (active_enemies > 1))

    -- Return the result
    return tfNow
end)

spec:RegisterStateExpr("try_berserk", function()
    -- Berserk algorithm: time Berserk for just after a Tiger's Fury
    -- Since Berserk is a 3min CD, we almost always (99% of the time) want to use it with Tiger's Fury
    
    local is_clearcast = buff.clearcasting.up
    local berserk_now = cooldown.berserk.up and buff.tigers_fury.up and not is_clearcast

    -- VERY rare exception: Only use without Tiger's Fury in critical situations
    -- 1. Tiger's Fury cooldown is extremely long (>15s)
    -- 2. The fight is about to end and we'd miss using Berserk entirely
    -- 3. No Clearcasting active
    if cooldown.berserk.up and not buff.tigers_fury.up and not is_clearcast and 
       (cooldown.tigers_fury.remains > 15 and ttd < 30) then
        berserk_now = true
    end

    return berserk_now
end)


spec:RegisterStateExpr("rip_now", function() 
    --!debuff.rip.up&combo_points.current=5&ttd>=end_thresh
    local rip_cc_check = debuff.bleed.up and not buff.clearcasting.up or true

    local rip_now = combo_points.current == 5 and ttd >= end_thresh and rip_cc_check and (not debuff.rip.up or (query_time > rip_refresh_time and not is_execute_phase))
    
    local max_rip_ticks = aura.rip.duration/aura.rip.tick_time

    -- Delay Rip refreshes if Tiger's Fury will be usable soon enough for the snapshot to outweigh the lost Rip ticks from waiting
    if rip_now and not buff.tigers_fury.up then
        local buffed_tick_count = math.min(max_rip_ticks, math.floor((ttd - final_tick_leeway) / aura.rip.tick_time))
        local delay_breakpoint = final_tick_leeway + 0.15 * buffed_tick_count * aura.rip.tick_time

        if tf_expected_before(time, time + delay_breakpoint) then
            local delay_seconds = delay_breakpoint
            local energy_to_dump = energy.current + delay_seconds * energy.regen - calc_tf_energy_thresh(latency)
            local seconds_to_dump = delay_seconds --ceil(energy_to_dump / action.shred.cost)

            if seconds_to_dump < delay_seconds then
                return false
            end
        end
    end

    return rip_now

end)

-- Rake calcs

spec:RegisterStateExpr("final_rake_tick_leeway", function()
    return max(debuff.rake.remains % debuff.rake.tick_time, 0)
end)

spec:RegisterStateExpr("rake_now", function()
    
    -- Ensure ttd (time-to-die) is a valid number
    if type(ttd) ~= "number" then
        ttd = 0
    end

    -- Ensure calc_rake_dpe and calc_shred_dpe are valid numbers
    if type(calc_rake_dpe) ~= "number" then
        calc_rake_dpe = 0
    end
    if type(calc_shred_dpe) ~= "number" then
        calc_shred_dpe = 0
    end

    -- Existing rake_now logic...
    local rake_cc_check = not buff.clearcasting.up or not debuff.rake.up or debuff.rake.remains < 1
    local rake_now = (not debuff.rake.up or (debuff.rake.remains < debuff.rake.tick_time)) and (ttd > debuff.rake.tick_time) and rake_cc_check

    if rake_now then
        rake_now = ttd > debuff.rake.tick_time and rake_cc_check
    end

    if settings.rake_dpe_check and rake_now then
        rake_now = calc_rake_dpe >= calc_shred_dpe
    end

    if rake_now and debuff.rip.up then
        local remaining_rip_dur = rip_maxremains
        local energy_for_shreds = energy.current - action.rake.cost - action.rip.cost + debuff.rip.remains * energy.regen
        local max_shreds_possible = min(energy_for_shreds / action.shred.cost, debuff.rip.remains / aura.rip.tick_time)

        rake_now = not rip_canextend or max_shreds_possible > remaining_rip_dur / aura.rip.tick_time
    end

    if rake_now and not buff.tigers_fury.up then
        local buffed_tick_count = math.floor(min(aura.rake.duration, ttd) / aura.rake.tick_time)
        local delay_breakpoint = final_rake_tick_leeway + 0.15 * buffed_tick_count * aura.rake.tick_time

        if tf_expected_before(query_time, query_time + delay_breakpoint) then
            local delay_seconds = delay_breakpoint
            local energy_to_dump = energy.current + delay_seconds * energy.regen - calc_tf_energy_thresh(latency)
            local seconds_to_dump = math.ceil(energy_to_dump / action.shred.cost)

            if seconds_to_dump < delay_seconds then
                rake_now = false
            end
        end
    end

    return rake_now
end)

spec:RegisterStateExpr("roar_now", function()
    return combo_points.current >= 1 and (not buff.savage_roar.up or clip_roar) and (debuff.rip.up or combo_points.current <3 or ttd < base_end_thresh)
end)

spec:RegisterStateExpr("ravage_now", function()
    return action.ravage.usable and not buff.clearcasting.up and energy.current + 2 * energy.regen < energy.max
end)

spec:RegisterStateExpr("ff_now", function()
    return settings.maintain_ff and debuff.major_armor_reduction.down
end)

spec:RegisterStateFunction("calc_tf_energy_thresh", function(leeway)
    local delayTime = leeway + (buff.clearcasting.up and 1 or 0) + (buff.stampede_cat.up and active_enemies == 1 and 1 or 0)
    return (40.0 - delayTime *  energy.regen)
end)

spec:RegisterStateExpr("final_tick_leeway", function()
    return max(debuff.rip.remains % debuff.rip.tick_time, 0) --debuff.rip.tick_time_remains not possible because of shred extensions (crashes default)
end)

spec:RegisterStateExpr("end_thresh_for_clip", function()
    return base_end_thresh + final_tick_leeway
end)

spec:RegisterStateExpr("rip_refresh_time", function()
    return calc_rip_refresh_time
end)

--- Return the time at which Rip should be refreshed.
spec:RegisterStateExpr("calc_rip_refresh_time", function()
    local reaction_time = latency -- TODO: This appears to always be 0.1, a very low value, in order to clip the rip with TF the addon has a 0.2s window to perform this query before TF drops and then the user must react in the remaining time.
    local now = query_time
    if not debuff.rip.up then
        return query_time - reaction_time
    end

    -- If we're not gaining a new Tiger's Fury snapshot, then use the standard 1 tick refresh window
    local standard_refresh_time = debuff.rip.expires -- - debuff.rip.tick_time -- TODO: reimplement 1 tick refresh window when we find out how to calc overridablility

    if not buff.tigers_fury.up or is_execute_phase or (combo_points.current < 5) then
        return standard_refresh_time
    end

    -- Likewise, if the existing TF buff will still be up at the start of the normal window, then don't clip unnecessarily
    local tf_end = buff.tigers_fury.expires

    if tf_end > standard_refresh_time + reaction_time then
        return standard_refresh_time
    end

    -- Potential clips for a TF snapshot should be done as late as possible
    local latest_possible_snapshot = tf_end - reaction_time * 2 

    -- Determine if an early clip would cost us an extra Rip cast over the course of the fight
    local max_rip_dur = aura.rip.duration + (glyph.bloodletting.enabled and 6 or 0)
    local ttd_absolute = ttd + now -- Note that standard_refresh_time and latest_possible_snapshot are absolute time units, not intervals of time.

    local final_possible_rip_cast = ttd_absolute - cached_rip_end_thresh -- TODO: ingore execution fase for now '(talent.blood_in_the_water.rank == 2 and target.time_to_25 - reaction_time) or ', target.time_to_25 does not exist
    local min_rips_possible = math.floor((final_possible_rip_cast - standard_refresh_time) / max_rip_dur)
    local projected_rip_casts = math.floor((final_possible_rip_cast - latest_possible_snapshot) / max_rip_dur)

    -- If the clip is free, then always allow it
    if projected_rip_casts == min_rips_possible then
        return latest_possible_snapshot
    end

    -- If the clip costs us a Rip cast (30 Energy), then we need to determine whether the damage gain is worth the spend.
    -- First calculate the maximum number of buffed Rip ticks we can get out before the fight ends.
    local buffed_tick_count = min(max_rip_dur/aura.rip.tick_time + 1, (ttd_absolute - latest_possible_snapshot) / aura.rip.tick_time)

    -- Subtract out any ticks that would already be buffed by an existing snapshot
    if rip_tf_snapshot then
        buffed_tick_count = buffed_tick_count - debuff.rip.ticks_remain
    end

    -- Perform a DPE comparison vs. Shred
    local tick_dmg = calc_rip_tick_damage
    local expected_damage_gain = tick_dmg * (1.0 - 1.0/1.15) * buffed_tick_count
    local energy_equivalent = expected_damage_gain / action.shred.damage * action.shred.cost

    Hekili:Debug("Rip TF snapshot is worth %.1f Energy, DMG gain %.1f, ticks %.1f, dmg: %.1f", energy_equivalent, expected_damage_gain, buffed_tick_count, tick_dmg)

    return (energy_equivalent > action.rip.cost) and latest_possible_snapshot or standard_refresh_time
end)

spec:RegisterStateExpr("mangle_refresh_now", function()
    --!debuff.mangle.up&ttd>=1
    return (not debuff.mangle.up) and ttd > 1
end)

spec:RegisterStateExpr("mangle_refresh_pending", function()
    return (not mangle_refresh_now) and ((debuff.mangle.up and debuff.mangle.remains < ttd - 1))
end)

spec:RegisterStateExpr("clip_mangle", function()
    -- This only works in simulation-context
        --if mangle_refresh_pending then
        --    local num_mangles_remaining = floor(1 + (ttd - 1 - debuff.mangle.remains) / 60)
        --    local earliest_mangle = ttd - num_mangles_remaining * 60
        --    return earliest_mangle <= 0
        --end

    if mangle_refresh_pending then
        return (ttd + 5 > debuff.mangle.remains) and (ttd -5 < debuff.mangle_cat.duration) and not buff.clearcasting.up
    end

    return false
end)

spec:RegisterStateExpr("mangle_now", function()
    -- Ensure debuff.mangle is a table with required fields
    if type(debuff.mangle) ~= "table" then
        debuff.mangle = { up = false, remains = 2 } -- Default values
    else
        -- Ensure required fields exist
        debuff.mangle.up = debuff.mangle.up or false
        debuff.mangle.remains = debuff.mangle.remains or 0
    end

    -- Existing mangle_now logic...
    return (mangle_refresh_now or clip_mangle)
end)

spec:RegisterStateExpr("ff_procs_ooc", function()
    return glyph.omen_of_clarity.enabled
end)


spec:RegisterStateExpr("calc_rake_dpe", function()
    local rake_dmg = action.rake.damage + action.rake.tick_damage*(math.floor(min(aura.rake.duration,ttd)/aura.rake.tick_time))
    return rake_dmg / action.rake.cost
end)

spec:RegisterStateExpr("calc_shred_dpe", function()
    local shred_dpe = action.shred.damage/action.shred.cost
    return shred_dpe
end)


spec:RegisterStateExpr("calc_bite_dpe", function()
    local avg_base_damage = 377.877920772
    local scaling_per_combo_point = 0.125
    local dmg_per_combo_point = 576.189844175
    local cp = combo_points.current

    local base_cost = (buff.clearcasting.up and 0) or (25 * ((buff.berserk.up and 0.5) or 1))
    local excess_energy = min(25, energy.current - base_cost) or 0

    local bonus_crit = rend_and_tear_mod_bite
    local damage_multiplier = (1 + talent.feral_aggression.rank*0.05) * (1 + excess_energy/25)

    local bite_damage = avg_base_damage + cp*(dmg_per_combo_point + state.stat.attack_power*scaling_per_combo_point)

    bite_damage = calculate_damage(bite_damage, 0, false, false, true, damage_multiplier, bonus_crit) 
    Hekili:Debug("bite_damage (%.2f), excess_energy (%d)", bite_damage, excess_energy)

    local bite_dpe = bite_damage / (base_cost + excess_energy) -- TODO: check if this should include excess energy

    return bite_dpe
end)

spec:RegisterStateExpr("calc_rip_tick_damage", function() -- TODO move this to an action?
    local base_damage = 56
    local combo_point_coeff = 161
    local attack_power_coeff = 0.0207
    local cp = combo_points.current

    local damage_multiplier = (glyph.rip.enabled and 1.15 or 1) * (debuff.mangle.up and 1.3 or 1)
    local flat_damage = base_damage + cp*(combo_point_coeff + state.stat.attack_power*attack_power_coeff)

    local tick_damage = calculate_damage(flat_damage, 0, false, true, false, damage_multiplier)

    Hekili:Debug("Rip tick damage (%.2f)", tick_damage)

    return tick_damage
end)

local cachedRipEndThresh = 10 -- placeholder until first calc
spec:RegisterStateExpr("cached_rip_end_thresh", function()
    return cachedRipEndThresh
end)

spec:RegisterStateExpr("calc_rip_end_thresh", function()
    if combo_points.current < 5 then
        return cachedRipEndThresh
    end
    
    --Calculate the minimum DoT duration at which a Rip cast will provide higher DPE than a Bite cast
    local expected_bite_dpe = calc_bite_dpe
    local expected_rip_tick_dpe = calc_rip_tick_damage/action.rip.cost
    local num_ticks_to_break_even = 1 + math.floor(expected_bite_dpe/expected_rip_tick_dpe)

    Hekili:Debug("Bite Break-Even Point = %d Rip ticks", num_ticks_to_break_even)

    local end_thresh = num_ticks_to_break_even * aura.rip.tick_time

    --Store the result so we can keep using it even when not at 5 CP
    cachedRipEndThresh = end_thresh

    return end_thresh

end)

spec:RegisterStateExpr("clip_roar", function()
    local local_ttd = ttd
    local rip_max_remains = rip_maxremains
    local roar_remains = buff.savage_roar.remains
    local combo_point = combo_points.current

    if combo_point == 0 then
        return false
    end

    if not debuff.rip.up or (local_ttd - debuff.rip.remains < cachedRipEndThresh) then
        return false
    end
    
    -- Calculate with projected Rip end time assuming full Glyph of Shred extensions
    if (roar_remains > rip_max_remains + settings.rip_leeway) then
        return false
    end
    
    if (roar_remains >= local_ttd) then
        return false
    end
    
    -- Calculate when roar would end if casted now
    -- Calculate roar duration since aura.savage_roar.duration gives wrong values
    local new_roar_dur = 9 + (combo_points.current*5) + (talent.endless_carnage.rank * 4)
    Hekili:Debug("Roar duration: (%.1f VS %.1f) CP: (%.1f)", new_roar_dur, aura.savage_roar.duration, combo_points.current)
    
    
    --If a fresh Roar cast now would cover us to end of fight, then clip now for maximum CP efficiency.
    if new_roar_dur >= local_ttd then
        return true
    end
    
    --If waiting another GCD to build an additional CP would lower our total Roar casts for the fight, then force a wait.    
    if new_roar_dur + 1 + (combo_points.current < 5 and 5 or 0) >= local_ttd then
        return false
    end
    
    -- Clip as soon as we have enough CPs for the new roar to expire well after the current rip
    if not is_execute_phase then
        return new_roar_dur >= (rip_max_remains + settings.min_roar_offset)
    end
    
    -- Under Execute conditions, ignore the offset rule and instead optimize for as few Roar casts as possible
    if combo_point < 5 then
        return false
    end
    
    local min_roars_possible = math.floor((local_ttd - roar_remains) / new_duration)
    local projected_roar_casts = math.floor(local_ttd / new_duration)
    Hekili:Debug("Roar execution: min (%.1f) VS projected (%.1f)", min_roars_possible, projected_roar_casts)
        
    return projected_roar_casts == min_roars_possible
end)

spec:RegisterStateFunction("tf_expected_before", function(current_time, future_time)
    if cooldown.tigers_fury.remains > 0 then
        return current_time + cooldown.tigers_fury.remains < future_time
    end
    if buff.berserk.up then
        return current_time + buff.berserk.remains < future_time
    end
    return true
end)


spec:RegisterStateFunction("berserk_expected_at", function(current_time, future_time)
    if not talent.berserk.enabled then
        return false
    end
    if buff.berserk.up then
        return future_time < current_time + buff.berserk.remains
    end
    if cooldown.berserk.remains > 0 then
        return (future_time > current_time + cooldown.berserk.remains)
    end
    if buff.tigers_fury.up then
        return (future_time > current_time + buff.tigers_fury.remains)
    end

    return tf_expected_before(current_time, future_time)
end)


spec:RegisterStateExpr("rip_refresh_pending", function()
    return debuff.rip.up and (debuff.rip.remains < ttd - base_end_thresh) and (combo_points.current >= (is_execute_phase and 1 or 5))
end)

spec:RegisterStateExpr("rake_refresh_pending", function()
    return debuff.rake.up and (debuff.rake.remains < ttd - debuff.rake.tick_time)
end)

spec:RegisterStateExpr("roar_refresh_pending", function()
    return buff.savage_roar.up and (buff.savage_roar.remains < ttd - latency) and combo_points.current >= 1
end)

--- Calculates and returns a table of pending actions with their respective refresh times and costs.
spec:RegisterStateExpr("pending_actions", function()
    local pending_actions = {
        mangle_cat = {
            refresh_time = 0,
            refresh_cost = 0
        },
        rake = {
            refresh_time = 0,
            refresh_cost = 0
        },
        rip = {
            refresh_time = 0,
            refresh_cost = 0
        },
        savage_roar = {
            refresh_time = 0,
            refresh_cost = 0
        }
    }

    if rip_refresh_pending and query_time < rip_refresh_time then
        pending_actions.rip.refresh_time = rip_refresh_time
        pending_actions.rip.refresh_cost = action.rip.cost * (berserk_expected_at(query_time, rip_refresh_time) and 0.5 or 1)
    else
        pending_actions.rip.refresh_time = 0
        pending_actions.rip.refresh_cost = 0
    end

    if rake_refresh_pending and debuff.rake.remains > debuff.rake.tick_time then
        pending_actions.rake.refresh_time = debuff.rake.expires - debuff.rake.tick_time
        pending_actions.rake.refresh_cost = action.rake.cost * (berserk_expected_at(query_time, pending_actions.rake.refresh_time) and 0.5 or 1)
    else
        pending_actions.rake.refresh_time = 0
        pending_actions.rake.refresh_cost = 0
    end

    if mangle_refresh_pending then
        pending_actions.mangle_cat.refresh_time = query_time + debuff.mangle.remains
        pending_actions.mangle_cat.refresh_cost = action.mangle_cat.cost * (berserk_expected_at(query_time, pending_actions.mangle_cat.refresh_time) and 0.5 or 1)
    else
        pending_actions.mangle_cat.refresh_time = 0
        pending_actions.mangle_cat.refresh_cost = 0
    end

    if roar_refresh_pending then
        pending_actions.savage_roar.refresh_time = buff.savage_roar.expires
        pending_actions.savage_roar.refresh_cost = action.savage_roar.cost * (berserk_expected_at(query_time, buff.savage_roar.expires) and 0.5 or 1)
    else
        pending_actions.savage_roar.refresh_time = 0
        pending_actions.savage_roar.refresh_cost = 0
    end

    if pending_actions.rip.refresh_time > 0 and pending_actions.savage_roar.refresh_time > 0 then
        if pending_actions.rip.refresh_time < pending_actions.savage_roar.refresh_time then
            pending_actions.savage_roar.refresh_time = 0
            pending_actions.savage_roar.refresh_cost = 0
        else
            pending_actions.rip.refresh_time = 0
            pending_actions.rip.refresh_cost = 0
        end
    end
    
    return pending_actions
end)

--- This function sorts pending actions based on their refresh times.
-- Actions with a refresh time of 0 are placed at the end of the list.
spec:RegisterStateFunction("sorted_actions", function(pending_actions_map)
    Hekili:Debug("sorted_actions called")
    local sorted_action_list = {}
    for entry in pairs(pending_actions_map) do
        table.insert(sorted_action_list, entry)
    end

    table.sort(sorted_action_list, function(a, b)
        if pending_actions_map[a].refresh_time == 0 then
            return false
        elseif pending_actions_map[b].refresh_time == 0 then
            return true
        else
            return pending_actions_map[a].refresh_time < pending_actions_map[b].refresh_time
        end
    end)

    return sorted_action_list
end)

--- Calculates and returns the refresh time of the next pending action.
spec:RegisterStateExpr("next_refresh_at", function()
    local pending_actions_map = pending_actions
    local sorted_action_list = sorted_actions(pending_actions_map)
    
    -- Om det finns inga giltiga aktioner att sortera, returnera en tid långt i framtiden men inte ett enormt värde
    if not sorted_action_list or #sorted_action_list == 0 then
        return query_time + 300 -- 5 minuter i framtiden istället för ett extremt stort värde
    end
    
    -- Validera att refresh_time är inom rimliga gränser för att förhindra jämförelser med orimliga värden
    local refresh_time = pending_actions_map[sorted_action_list[1]].refresh_time
    
    if refresh_time <= 0 or refresh_time > (query_time + 600) then
        return query_time + 300 -- Returnera en rimlig default-tid om värdet verkar orimligt
    end
    
    return refresh_time
end)

-- Floating energy - energy that should be reserved for upcoming abilities
spec:RegisterStateExpr("floating_energy", function()
    -- Reserve energy for important abilities based on current situation
    local reserved = 0
    
    -- Reserve energy for Tiger's Fury if it's coming off cooldown soon
    if cooldown.tigers_fury.remains <= 3 and not buff.tigers_fury.up then
        reserved = reserved + 0 -- Tiger's Fury has no energy cost
    end
    
    -- Reserve energy for Berserk if it's available
    if cooldown.berserk.ready and not buff.berserk.up then
        reserved = reserved + 0 -- Berserk has no energy cost
    end
    
    -- Reserve some energy for emergency abilities (default safety margin)
    reserved = reserved + 20
    
    return reserved
end)

spec:RegisterStateExpr("excess_e", function()
    return energy.current - floating_energy
end)

-- Behind target detection for Shred positioning requirement
spec:RegisterStateExpr("behind_target", function()
    -- In MoP Classic, positioning is important for abilities like Shred
    -- We'll use a combination of distance and facing detection
    if not target.exists or target.distance > 5 then 
        return false 
    end
    
    -- For MoP Classic, we can try to use CheckInteractDistance and facing
    -- CheckInteractDistance with index 3 is roughly melee range (10 yards)
    -- CheckInteractDistance with index 2 is trade distance (11.11 yards)
    -- For simplicity, we'll assume behind target if:
    -- 1. We're in melee range (distance <= 5)
    -- 2. Target is not facing us (simplified check)
    
    -- Since we can't easily detect exact positioning in Classic API,
    -- we'll use a probability-based approach for positioning
    -- Most players try to position correctly for Shred, so we'll assume
    -- a higher chance of being behind target when in melee range
    
    local distance = target.distance
    if distance <= 5 then
        -- Assume 85% chance of being behind target when in melee range
        -- This accounts for player skill in positioning
        return true
    end
    
    return false
end)

spec:RegisterStateExpr("movement_speed", function()
    return select( 2, GetUnitSpeed( "player" ) )
end)

spec:RegisterStateExpr("bear_mode_tank_enabled", function()
    return settings.bear_form_mode == "tank"
end)

-- Resources
spec:RegisterResource( Enum.PowerType.Rage, {
    enrage = {
        aura = "enrage",

        last = function()
            local app = state.buff.enrage.applied
            local t = state.query_time

            return app + floor( t - app )
        end,

        interval = 1,
        value = 2
    },

    mainhand = {
        swing = "mainhand",
        aura = "bear_form",

        last = function()
            local swing = state.combat == 0 and state.now or state.swings.mainhand
            local t = state.query_time

            return swing + ( floor( ( t - swing ) / state.swings.mainhand_speed ) * state.swings.mainhand_speed )
        end,

        interval = "mainhand_speed",

        stop = function() return state.swings.mainhand == 0 end,
        value = function( now )
            return rage_amount()
        end,
    },
} )
spec:RegisterResource( Enum.PowerType.Mana )
spec:RegisterResource( Enum.PowerType.ComboPoints )
spec:RegisterResource( Enum.PowerType.Energy)


-- Talents (Feral only for MoP)
spec:RegisterTalents( {
    -- Tier 1 (Level 15)
    feline_swiftness = { 1, 1, 131768 },
    displacer_beast = { 1, 2, 102280 },
    wild_charge = { 1, 3, 102401 },

    -- Tier 2 (Level 30)
    yseras_gift = { 2, 1, 145108 },
    renewal = { 2, 2, 108238 },
    cenarion_ward = { 2, 3, 102351 },

    -- Tier 3 (Level 45)
    faerie_swarm = { 3, 1, 102355 },
    mass_entanglement = { 3, 2, 102359 },
    typhoon = { 3, 3, 132469 },

    -- Tier 4 (Level 60)
    soul_of_the_forest = { 4, 1, 114107 },
    incarnation = { 4, 2, 102543 },
    force_of_nature = { 4, 3, 106737 },

    -- Tier 5 (Level 75)
    disorienting_roar = { 5, 1, 99 },
    ursols_vortex = { 5, 2, 102793 },
    mighty_bash = { 5, 3, 5211 },

    -- Tier 6 (Level 90)
    heart_of_the_wild = { 6, 1, 108291 },
    dream_of_cenarius = { 6, 2, 108373 },
    natures_vigil = { 6, 3, 124974 },
} )


-- Glyphs (registered individually as the RegisterGlyphs method is not available)
-- Major Glyphs
spec:RegisterGear( "glyph_berserk", 116238 )
spec:RegisterGear( "glyph_ferocious_bite", 116236 )
spec:RegisterGear( "glyph_feral_charge", 116201 )
spec:RegisterGear( "glyph_prowl", 116239 )
spec:RegisterGear( "glyph_savage_roar", 116240 )
spec:RegisterGear( "glyph_shred", 116202 )
spec:RegisterGear( "glyph_tigers_fury", 116203 )
spec:RegisterGear( "glyph_cat_form", 116237 )
spec:RegisterGear( "glyph_dash", 116200 )
spec:RegisterGear( "glyph_ninth_life", 116241 )
spec:RegisterGear( "glyph_faerie_fire", 94386 )
spec:RegisterGear( "glyph_aquatic_form", 116199 )
spec:RegisterGear( "glyph_stampeding_roar", 116242 )

-- Minor Glyphs
spec:RegisterGear( "glyph_grace", 116243 )
spec:RegisterGear( "glyph_treant", 116244 )
spec:RegisterGear( "glyph_mark_of_the_wild", 116245 )
spec:RegisterGear( "glyph_challenging_roar", 116246 )
spec:RegisterGear( "glyph_unburdened_rebirth", 116247 )
spec:RegisterGear( "glyph_travel", 116248 )


-- Auras
spec:RegisterAuras( {
    -- Attempts to cure $3137s1 poison every $t1 seconds.
    abolish_poison = {
        id = 2893,
        duration = 12,
        tick_time = 3,
        max_stack = 1,
    },
    -- Immune to Polymorph effects.  Increases swim speed by $5421s1% and allows underwater breathing.
    aquatic_form = {
        id = 1066,
        duration = 3600,
        max_stack = 1,
    },
    -- All damage taken is reduced by $s2%.  While protected, damaging attacks will not cause spellcasting delays.
    barkskin = {
        id = 22812,
        duration = 12,
        max_stack = 1,
    },
    -- Stunned.
    bash = {
        id = 5211,
        duration = 4,
        max_stack = 1,
    },
    bear_form = {
        id = 5487,
        duration = 3600,
        max_stack = 1,
        copy = { 5487, 9634, "dire_bear_form" }
    },
    -- Your abilities cost 50% less Energy/Rage. 
    berserk = {
        id = 106952,
        duration = 15,
        max_stack = 1,
    },
    -- Immune to Polymorph effects.  
    cat_form = {
        id = 768,
        duration = 3600,
        max_stack = 1,
    },
    -- Increases critical strike chance by 25% and critical strike damage by 50%.
    cenarion_ward = {
        id = 102351,
        duration = 30,
        max_stack = 1,
    },
    -- Taunted.
    challenging_roar = {
        id = 5209,
        duration = 6,
        max_stack = 1,
    },
    -- Your next spell costs no mana.
    clearcasting = {
        id = 16870,
        duration = 15,
        max_stack = 1,
        copy = "omen_of_clarity"
    },
    -- Invulnerable, but unable to act.
    cyclone = {
        id = 33786,
        duration = 6,
        max_stack = 1,
    },
    -- Increases movement speed by $s1% while in Cat Form.
    dash = {
        id = 1850,
        duration = 15,
        max_stack = 1,
    },
    -- Movement slowed.
    dazed = {
        id = 1604,
        duration = 8,
        max_stack = 1,
    },
    -- Decreases melee attack power by $s1.
    demoralizing_roar = {
        id = 99,
        duration = 30,
        max_stack = 1,
    },
    -- Reduced spell resistance.
    faerie_fire = {
        id = 770,
        duration = 300,
        max_stack = 3,
    },
    -- MoP specific: Armor reduced and cannot stealth or turn invisible.
    major_armor_reduction = {
        alias = { "faerie_fire", "sunder_armor", "expose_armor" },
        aliasType = "debuff",
        aliasMode = "first"
    },
    -- Reduces damage from falling.
    feline_grace = {
        id = 20719,
        duration = 3600,
        max_stack = 1,
    },
    -- Immobilized.
    feral_charge_effect = {
        id = 16979,
        duration = 4,
        max_stack = 1,
    },
    flight_form = {
        id = 33943,
        duration = 3600,
        max_stack = 1,
    },
    form = {
        alias = { "aquatic_form", "cat_form", "bear_form", "flight_form", "moonkin_form", "swift_flight_form", "travel_form"  },
        aliasType = "buff",
        aliasMode = "first"
    },
    -- Converting rage into health.
    frenzied_regeneration = {
        id = 22842,
        duration = 20,
        max_stack = 1,
    },
    -- Taunted.
    growl = {
        id = 6795,
        duration = 3,
        max_stack = 1,
    },
    -- Heart of the Wild (MoP talent)
    heart_of_the_wild = {
        id = 108291,
        duration = 45,
        max_stack = 1,
    },
    -- Asleep.
    hibernate = {
        id = 2637,
        duration = 40,
        max_stack = 1,
    },
    -- $42231s1 damage every $t3 seconds, and time between attacks increased by $s2%.$?$w1<0[ Movement slowed by $w1%.][]
    hurricane = {
        id = 16914,
        duration = 10,
        tick_time = 1,
        max_stack = 1,
    },
    -- Incarnation: King of Beasts (MoP)
    incarnation_king_of_beasts = {
        id = 102543,
        duration = 30,
        max_stack = 1,
    },
    -- Regenerating mana.
    innervate = {
        id = 29166,
        duration = 10,
        tick_time = 1,
        max_stack = 1,
    },
    -- Chance to hit with melee and ranged attacks decreased by $s2% and $s1 Nature damage every $t1 sec.
    insect_swarm = {
        id = 5570,
        duration = 12,
        tick_time = 2,
        max_stack = 1,
    },
    -- $s1 damage every $t sec
    lacerate = {
        id = 33745,
        duration = 15,
        tick_time = 3,
        max_stack = 3,
    },
    -- Heals $s1 every second and $s2 when effect finishes or is dispelled.
    lifebloom = {
        id = 33763,
        duration = 10,
        tick_time = 1,
        max_stack = 3,
    },
    -- Lunar Shower (MoP)
    lunar_shower = {
        id = 81192,
        duration = 3,
        max_stack = 3,
    },
    -- Stunned and taking increased damage from bleeds.
    maim = {
        id = 22570,
        duration = function() return combo_points.current end,
        max_stack = 1,
    },
    -- Taking additional damage from bleed effects.
    mangle = {
        id = 33876,
        duration = 60,
        max_stack = 1,
        copy = { 33878, 33987, 33988, 33989, 33990, 33991 },
    },
    -- Alias for cat mangle debuff
    mangle_cat = {
        alias = "mangle",
        aliasType = "debuff"
    },
    mark_of_the_wild = {
        id = 1126,
        duration = 3600,
        max_stack = 1,
        shared = "player",
    },
    -- TODO: remove
    maul = {
        duration = function() return swings.mainhand_speed end,
        max_stack = 1,
    },
    -- $s1 Arcane damage every $t1 seconds.
    moonfire = {
        id = 8921,
        duration = 12,
        tick_time = 3,
        max_stack = 1,
    },
    -- Immune to Polymorph effects.  
    moonkin_form = {
        id = 24858,
        duration = 3600,
        max_stack = 1,
    },
    -- Your next Nature spell will be an instant cast spell.
    natures_swiftness = {
        id = 17116,
        duration = 3600,
        max_stack = 1,
    },
    -- Stealthed.  Movement speed slowed by $s2%.
    prowl = {
        id = 5215,
        duration = 3600,
        max_stack = 1,
    },
    -- Bleeding for $s2 damage every $t2 seconds.
    rake = {
        id = 1822,
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 1,
    },
    -- Heals $s2 every $t2 seconds.
    regrowth = {
        id = 8936,
        duration = 6,
        max_stack = 1,
    },
    -- Heals $s1 damage every $t1 seconds.
    rejuvenation = {
        id = 774,
        duration = 12,
        tick_time = 3,
        max_stack = 1,
    },
    -- Renewal (MoP talent)
    renewal = {
        id = 108238,
        duration = 0,
        max_stack = 1,
    },
    -- Bleed damage every $t1 seconds.
    rip = {
        id = 1079,
        duration = 16,
        tick_time = 2,
        max_stack = 1,
    },
    -- Physical damage done increased by $s2%.
    savage_roar = {
        id = 52610,
        duration = function()
            if combo_points.current == 0 then
                return 0
            end
            -- Base duration is 14s + 5s per combo point in MoP
            return 14 + (combo_points.current * 5)
        end,
        max_stack = 1,
    },
    -- Shattering Throw effect
    shattering_throw = {
        id = 64382,
        duration = 10,
        max_stack = 1,
    },
    -- Summoning stars from the sky.
    starfall = {
        id = 48505,
        duration = 10,
        tick_time = 1,
        max_stack = 1,
    },
    -- Reduces all damage taken.
    survival_instincts = {
        id = 61336,
        duration = 12,
        max_stack = 1,
    },
    -- Immune to Polymorph effects.  Movement speed increased by $40121s2% and allows you to fly.
    swift_flight_form = {
        id = 40120,
        duration = 3600,
        max_stack = 1,
    },
    -- Causes $s1 Nature damage to attackers.
    thorns = {
        id = 782, -- Try different Thorns ID for MoP
        duration = 20,
        max_stack = 1,
        shared = "target",
    },
    -- Increases damage done by $s1.
    tigers_fury = {
        id = 5217,
        duration = 6,
        max_stack = 1,
        multiplier = function() return 1.15 end,
    },
    -- Tracking humanoids.
    track_humanoids = {
        id = 5225,
        duration = 3600,
        max_stack = 1,
    },
    -- Heals nearby party members.
    tranquility = {
        id = 740,
        duration = 8,
        max_stack = 1,
    },
    -- Immune to Polymorph effects.  Movement speed increased.
    travel_form = {
        id = 783,
        duration = 3600,
        max_stack = 1,
    },
    -- Bleeding for damage every 3 seconds.
    thrash = {
        id = 77758,
        duration = 6,
        tick_time = 3,
        max_stack = 1,
    },
    -- Dazed.
    typhoon = {
        id = 50516,
        duration = 6,
        max_stack = 1,
    },
    -- Stunned.
    war_stomp = {
        id = 20549,
        duration = 2,
        max_stack = 1,
    },
    -- Training dummy marker
    training_dummy = {
        id = 4688, -- Generic training dummy
        duration = 3600,
        max_stack = 1,
    },

    -- Bleed debuff group for MoP
    rupture = {
        id = 1943,
        duration = 6,
        max_stack = 1,
        shared = "target",
    },
    garrote = {
        id = 703,
        duration = 18,
        max_stack = 1,
        shared = "target",
    },
    rend = {
        id = 772,
        duration = 15,
        max_stack = 1,
        shared = "target",
    },
    deep_wound = {
        id = 43104,
        duration = 12,
        max_stack = 1,
        shared = "target",
    },
    bleed = {
        alias = { "lacerate", "rip", "rake", "deep_wound", "rend", "garrote", "rupture", "thrash" },
        aliasType = "debuff",
        aliasMode = "longest"
    },

    -- MoP Specific buffs
    stampeding_roar = {
        id = 77764,
        duration = 8,
        max_stack = 1,
    },

    -- Ysera's Gift (MoP talent)
    yseras_gift = {
        id = 145108,
        duration = 5,
        max_stack = 1,
    },

    -- Wild Charge effects (MoP talent)
    wild_charge_movement = {
        id = 102401,
        duration = 0.5,
        max_stack = 1,
    },

    -- Displacer Beast (MoP talent)
    displacer_beast = {
        id = 102280,
        duration = 4,
        max_stack = 1,
    },

    -- Dream of Cenarius (MoP talent)
    dream_of_cenarius_damage = {
        id = 108373,
        duration = 30,
        max_stack = 2,
    },
    dream_of_cenarius_healing = {
        id = 108374,
        duration = 30,
        max_stack = 2,
    },

    -- Nature's Vigil (MoP talent)
    natures_vigil = {
        id = 124974,
        duration = 30,
        max_stack = 1,
    },

    -- Force of Nature treants (MoP version)
    force_of_nature = {
        id = 106737,
        duration = 15,
        max_stack = 1,
    },

    -- Soul of the Forest (MoP talent)
    soul_of_the_forest = {
        id = 114107,
        duration = 8,
        max_stack = 1,
    },

    -- Predatory Swiftness (MoP ability)
    predatory_swiftness = {
        id = 69369,
        duration = 8,
        max_stack = 3,
    },

    -- Armor buff/debuff for defensive calculations
    
    -- Missing MoP auras for Feral
    enrage = {
        id = 5229,
        duration = 10,
        max_stack = 1,
    },
    
    -- Nature's Grace (MoP druid buff)
    natures_grace = {
        id = 16886,
        duration = 15,
        max_stack = 1,
    },
    
    -- Primal Madness (theoretical MoP talent buff - may not exist in client)
    primal_madness = {
        id = 80316,
        duration = 15,
        max_stack = 1,
    },
} )

-- Form Helper
spec:RegisterStateFunction( "swap_form", function( form )
    removeBuff( "form" )
    removeBuff( "maul" )

    if form == "bear_form" then
        spend( rage.current, "rage" )
        if talent.furor.rank==3 then
            gain( 10, "rage" )
        end
    end

    if form then
        applyBuff( form )
    end
end )

spec:RegisterStateFunction( "finish_maul", function()
    if not buff.maul.up then return end

    local next_swing = state.swings.mainhand_remains
    if next_swing <= 0 then
        next_swing = state.swings.mainhand_speed
    end

    -- If maul is still active, apply it again
    if buff.maul.expires > state.query_time + next_swing then
        applyBuff( "maul", next_swing )
        state:QueueAuraExpiration( "maul", finish_maul, buff.maul.expires )
    else
        removeBuff( "maul" )
    end
end )

spec:RegisterStateFunction( "start_maul", function()
    local next_swing = mainhand_remains
    if next_swing <= 0 then
        next_swing = mainhand_speed
    end
    applyBuff( "maul", next_swing )
    state:QueueAuraExpiration( "maul", finish_maul, buff.maul.expires )
end )


-- Abilities
spec:RegisterAbilities( {
    --Shapeshift into aquatic form, increasing swim speed by 50% and allowing the Druid to breathe underwater.  Also protects the caster from Polymorph effects.The act of shapeshifting frees the caster of movement slowing effects.
    aquatic_form = {
        id = 1066,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 0.08, 
        spendType = "mana",

        startsCombat = false,
        texture = 132112,

        handler = function()
            swap_form( "aquatic_form" )
        end,
    },

    --The Druid's skin becomes as tough as bark.  All damage taken is reduced by 20%.  While protected, damaging attacks will not cause spellcasting delays.  This spell is usable while stunned, frozen, incapacitated, feared or asleep.  Usable in all forms.  Lasts 12 sec.
    barkskin = {
        id = 22812,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,
        texture = 136097,

        toggle = "defensives",
        
        handler = function()
            applyBuff( "barkskin" )
        end,
    },

    --Stuns the target for 4 sec.
    bash = {
        id = 5211,
        cast = 0,
        cooldown = 60,
        gcd = "spell",

        spend = function() return (buff.clearcasting.up and 0) or 10 end, 
        spendType = "rage",

        startsCombat = true,
        texture = 132114,
        debuff = "casting",
        readyTime = state.timeToInterrupt,
        toggle = "interrupts",

        form = "bear_form",
        handler = function()
            interrupt()
            removeBuff( "clearcasting" )
            applyDebuff( "target", "bash", 4 )
        end,
    },

    --Shapeshift into Bear Form, increasing armor contribution from cloth and leather items by 120% and Stamina by 20%.  Also protects the caster from Polymorph effects and allows the use of various bear abilities.
    bear_form = {
        id = 5487,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 0.05, 
        spendType = "mana",

        startsCombat = false,
        texture = 132276,

        handler = function()
            swap_form( "bear_form" )
        end,

        copy = "dire_bear_form"
    },

    --Your abilities cost 50% less Energy/Rage for 15 seconds.
    berserk = {
        id = 106952,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        startsCombat = false,
        texture = 236149,
        toggle = "cooldowns",

        handler = function()
            applyBuff( "berserk" )
        end,
    },

    --Shapeshift into Cat Form, causing agility to increase attack power.  Also protects the caster from Polymorph effects and allows the use of various cat abilities.
    cat_form = {
        id = 768,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 0.05, 
        spendType = "mana",

        startsCombat = false,
        texture = 132115,

        handler = function()
            swap_form( "cat_form" )
        end,
    },

    --Forces all nearby enemies within 10 yards to focus attacks on you for 6 sec.
    challenging_roar = {
        id = 5209,
        cast = 0,
        cooldown = 180,
        gcd = "spell",

        spend = 15, 
        spendType = "rage",

        startsCombat = true,
        texture = 132117,

        form = "bear_form",
        handler = function()
            applyDebuff( "target", "challenging_roar", 6 )
        end,
    },

    --Claw the enemy, causing damage and awarding 1 combo point.
    claw = {
        id = 1082,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = 40, 
        spendType = "energy",

        startsCombat = true,
        texture = 132140,

        form = "cat_form",
        handler = function()
            gain( 1, "combo_points" )
        end,
    },

    --Increases movement speed by 70% while in Cat Form for 15 sec.  Does not break prowling.
    dash = {
        id = 1850,
        cast = 0,
        cooldown = function() return 180 * ( glyph.dash.enabled and 0.8 or 1 ) end,
        gcd = "off",

        startsCombat = false,
        texture = 132120,
        toggle = "cooldowns",

        handler = function()
            applyBuff( "dash" )
        end,
    },

    --The Druid roars, reducing the physical damage caused by all enemies within 10 yards for 30 sec.
    demoralizing_roar = {
        id = 99,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 10, 
        spendType = "rage",

        startsCombat = true,
        texture = 132121,

        form = "bear_form",
        handler = function()
            applyDebuff( "target", "demoralizing_roar", 30 )
        end,
    },

    --Generates 20 Rage, and then generates an additional 10 Rage over 10 sec.
    enrage = {
        id = 5229,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,
        texture = 132126,

        form = "bear_form",
        handler = function()
            gain(20, "rage" )
            applyBuff( "enrage" )
        end,
    },

    --Decreases the armor of the target by 12% for 5 min.  While affected, the target cannot stealth or turn invisible.
    faerie_fire = {
        id = 770,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 0.08, 
        spendType = "mana",

        startsCombat = true,
        texture = 136033,

        handler = function()
            applyDebuff( "target", "faerie_fire", 300 )
        end,
    },

    --Decreases the armor of the target by 12% for 5 min.  While affected, the target cannot stealth or turn invisible.  Deals damage when used in Bear Form.
    faerie_fire_feral = {
        id = 16857,
        cast = 0,
        cooldown = 6,
        gcd = "totem",

        startsCombat = true,
        texture = 136033,

        form = "bear_form",
        handler = function()
            applyDebuff( "target", "faerie_fire", 300 )
        end,
    },

    --Causes you to charge an enemy, immobilizing them for 4 sec.
    feral_charge_bear = {
        id = 16979,
        cast = 0,
        cooldown = function() return 15 * ( glyph.feral_charge.enabled and ( 13 / 15 ) or 1 ) end,
        gcd = "off",

        spend = 5, 
        spendType = "rage",

        minRange = 8,
        maxRange = function() return glyph.feral_charge.enabled and 30 or 25 end,

        startsCombat = true,
        texture = 132183,

        buff = "bear_form",
        handler = function()
            applyDebuff("target", "feral_charge_effect", 4)
        end,
    },

    --Causes you to leap behind an enemy, dazing them for 3 sec.
    feral_charge_cat = {
        id = 49376,
        cast = 0,
        cooldown = function() return 30 * ( glyph.feral_charge.enabled and ( 28 / 30 ) or 1 ) end,
        gcd = "off",

        spend = 10, 
        spendType = "energy",

        minRange = 8,
        maxRange = function() return glyph.feral_charge.enabled and 30 or 25 end,

        startsCombat = true,
        texture = 304501,

        buff = "cat_form",
        handler = function()
            applyDebuff("target", "dazed", 3)
        end,
    },

    --Finishing move that causes damage per combo point and consumes up to 25 additional energy to increase damage by up to 100%.
    ferocious_bite = {
        id = 22568,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function()
            local base_cost = (buff.clearcasting.up and 0) or (25 * ((buff.berserk.up and 0.5) or 1))
            local excess_energy = min(25, energy.current - base_cost) or 0
            return base_cost + excess_energy
        end, 
        spendType = "energy",

        startsCombat = true,
        texture = 132127,

        form = "cat_form",
        handler = function()
            removeBuff( "clearcasting" )
            set_last_finisher_cp(combo_points.current)
            spend( combo_points.current, "combo_points" )
        end,
    },

    --Shapeshift into flight form, increasing movement speed by 150% and allowing you to fly.
    flight_form = {
        id = 33943,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 0.08, 
        spendType = "mana",

        startsCombat = false,
        texture = 132128,

        handler = function()
            swap_form( "flight_form" )
        end,
    },

    --Increases maximum health by 30% and healing received by 30%.  Lasts 20 sec.
    frenzied_regeneration = {
        id = 22842,
        cast = 0,
        cooldown = 90,
        gcd = "off",

        startsCombat = false,
        texture = 132091,
        toggle = "defensives",

        form = "bear_form",
        handler = function()
            applyBuff( "frenzied_regeneration" )
        end,
    },

    --Taunts the target to attack you.
    growl = {
        id = 6795,
        cast = 0,
        cooldown = 8,
        gcd = "off",

        startsCombat = true,
        texture = 132270,

        form = "bear_form",
        handler = function()
            applyDebuff( "target", "growl", 3 )
        end,
    },

    --Heals a friendly target.
    healing_touch = {
        id = 5185,
        cast = 2.5,
        cooldown = 0,
        gcd = "spell",

        spend = function() return (buff.clearcasting.up and 0) or 0.3 end,  
        spendType = "mana",

        startsCombat = false,
        texture = 136041,

        handler = function()
            removeBuff( "clearcasting" )
        end,
    },

    --Causes the target to regenerate mana.
    innervate = {
        id = 29166,
        cast = 0,
        cooldown = 180,
        gcd = "spell",

        startsCombat = false,
        texture = 136048,

        toggle = "cooldowns",
        handler = function ()
            applyBuff( "innervate" )
        end,
    },

    --Lacerates the enemy target, dealing damage and making them bleed.  This effect stacks up to 3 times.
    lacerate = {
        id = 33745,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return (buff.clearcasting.up and 0) or 15 end,
        spendType = "rage",

        startsCombat = true,
        texture = 132131,

        form = "bear_form",
        handler = function()
            removeBuff( "clearcasting" )
            applyDebuff( "target", "lacerate", 15, min( 3, debuff.lacerate.stack + 1 ) )
        end,
    },

    --Finishing move that causes damage and stuns the target.  Lasts longer per combo point.
    maim = {
        id = 22570,
        cast = 0,
        cooldown = 10,
        gcd = "totem",

        spend = function() return (buff.clearcasting.up and 0) or (35 * ((buff.berserk.up and 0.5) or 1)) end,
        spendType = "energy",

        startsCombat = true,
        texture = 132134,
        toggle = "interrupts",
        readyTime = state.timeToInterrupt,
        debuff = "casting",

        form = "cat_form",
        handler = function()
            interrupt()
            applyDebuff( "target", "maim", combo_points.current )
            removeBuff( "clearcasting" )
            set_last_finisher_cp(combo_points.current)
            spend( combo_points.current, "combo_points" )
        end,
    },

    --Mangle the target, causing the target to take 30% additional damage from bleed effects for 1 min.
    mangle_bear = {
        id = 33878,
        cast = 0,
        cooldown = function() return buff.berserk.up and 0 or 6 end,
        gcd = "spell",

        spend = function() return (buff.clearcasting.up and 0) or 15 end, 
        spendType = "rage",

        startsCombat = true,
        texture = 132135,

        form = "bear_form",
        handler = function()
            applyDebuff( "target", "mangle", 60 )
            removeBuff( "clearcasting" )
        end,
    },

    --Mangle the target, causing the target to take 30% additional damage from bleed effects for 1 min.  Awards 1 combo point.
    mangle_cat = {
        id = 33876,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function () return (buff.clearcasting.up and 0) or (35 * ((buff.berserk.up and 0.5) or 1)) end, 
        spendType = "energy",

        startsCombat = true,
        texture = 132135,

        form = "cat_form",
        handler = function()
            applyDebuff( "target", "mangle", 60 )
            removeBuff( "clearcasting" )
            gain( 1, "combo_points" )
        end,
    },

    --Increases attributes and magical resistances for the party or raid.
    mark_of_the_wild = {
        id = 1126,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return glyph.mark_of_the_wild.enabled and 0.12 or 0.24 end, 
        spendType = "mana",

        startsCombat = false,
        texture = 136078,

        handler = function()
            applyBuff( "mark_of_the_wild" )
        end,
    },

    --An attack that instantly deals damage.
    maul = {
        id = 6807,
        cast = 0,
        cooldown = 3,
        gcd = "off",

        spend = function() return (buff.clearcasting.up and 0) or 15 end, 
        spendType = "rage",

        startsCombat = true,
        texture = 132136,

        form = "bear_form",
        handler = function()
            removeBuff( "clearcasting" )
        end,
    },

    --Allows the Druid to prowl around, reducing movement speed.
    prowl = {
        id = 5215,
        cast = 0,
        cooldown = 10,
        gcd = "off",

        startsCombat = false,
        texture = 514640,

        form = "cat_form",
        handler = function()
            applyBuff( "prowl" )
        end,
    },

    --Consume 2 or 3 Lacerate applications to increase critical strike chance by 3%/9% for 10 sec.
    pulverize = {
        id = 2818, -- MoP Classic Pulverize ID
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function () return (buff.clearcasting.up and 0) or 15 end,
        spendType = "rage",

        startsCombat = true,
        texture = 132318,

        usable = function() return debuff.lacerate.stack >= 2, "requires 2+ lacerate stacks" end,

        form = "bear_form",
        handler = function()
            local stacks = debuff.lacerate.stack
            if stacks >= 2 then
                applyBuff("pulverize", 10, min( 3, stacks ) )
                removeDebuff("target","lacerate")
            end
            removeBuff( "clearcasting" )
        end,
    },

    --Rake the target for Bleed damage and additional Bleed damage over time.  Awards 1 combo point.
    rake = {
        id = 1822,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function () return (buff.clearcasting.up and 0) or (35 * ((buff.berserk.up and 0.5) or 1)) end, 
        spendType = "energy",

        startsCombat = true,
        texture = 132122,
        damage = function ()
            local damage_multiplier = (debuff.mangle.up and 1.3 or 1) * rend_and_tear_mod_shred
            return calculate_damage( 56, 0.147, false, true, false, damage_multiplier )
        end,
        tick_damage = function ()
            local damage_multiplier = (debuff.mangle.up and 1.3 or 1)
            return calculate_damage( 56, 0.147, false, true, false, damage_multiplier )
        end,

        readyTime = function() return max( 0, debuff.rake.remains - debuff.rake.tick_time ) end,

        form = "cat_form",
        handler = function()
            applyDebuff( "target", "rake" )
            removeBuff( "clearcasting" )
            gain( 1, "combo_points" )
        end,
    },

    --Ravage the target, causing high damage.  Must be prowling or have Stampede.  Awards 1 combo point.
    ravage = {
        id = 6785,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return (buff.clearcasting.up and 0) or (60 * ((buff.berserk.up and 0.5) or 1)) end, 
        spendType = "energy",

        startsCombat = true,
        texture = 132141,

        usable = function() return buff.prowl.up or buff.incarnation_king_of_beasts.up, "must be prowling or have incarnation" end,

        form = "cat_form",
        handler = function()
            removeBuff( "clearcasting" )
            gain( 1, "combo_points" )
        end,
    },

    --Heals a friendly target over time.
    rejuvenation = {
        id = 774,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function() return (buff.clearcasting.up and 0) or 0.2 end, 
        spendType = "mana",

        startsCombat = false,
        texture = 136081,

        handler = function()
            removeBuff( "clearcasting" )
            applyBuff( "target", "rejuvenation" )
        end,
    },

    --Finishing move that causes Bleed damage over time.  Damage increases per combo point.
    rip = {
        id = 1079,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function ()
            if buff.clearcasting.up then
                return 0
            end
            return (30 * ((buff.berserk.up and 0.5) or 1))
        end,
        spendType = "energy",

        startsCombat = true,
        texture = 132152,

        usable = function() return combo_points.current > 0, "requires combo_points" end,
        readyTime = function() return max( 0, debuff.rip.remains - debuff.rip.tick_time ) end,

        handler = function ()
            applyDebuff( "target", "rip" )
            removeBuff( "clearcasting" )
            set_last_finisher_cp(combo_points.current)
            spend( combo_points.current, "combo_points" )
        end,
    },

    --Finishing move that increases autoattack damage.  Lasts longer per combo point.
    savage_roar = {
        id = 52610,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function() return 25 * ((buff.berserk.up and 0.5) or 1) end, 
        spendType = "energy",

        startsCombat = false,
        texture = 236167,

        usable = function() return combo_points.current > 0, "requires combo_points" end,
        handler = function ()
            applyBuff( "savage_roar" )
            set_last_finisher_cp(combo_points.current)
            spend( combo_points.current, "combo_points" )
        end,
    },

    --Shred the target, causing high damage.  Must be behind the target.  Awards 1 combo point.
    shred = {
        id = 5221,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",

        spend = function () return (buff.clearcasting.up and 0) or (40 * ((buff.berserk.up and 0.5) or 1)) end, 
        spendType = "energy",

        startsCombat = true,
        texture = 136231,

        form = "cat_form",
        damage = function ()
            local damage_multiplier = (debuff.mangle.up and 1.3 or 1)
            return calculate_damage( 56 , 5.40, true, false, true, damage_multiplier)
        end,

        handler = function ()
            gain( 1, "combo_points" )
            removeBuff( "clearcasting" )
        end,
    },

    --You charge and skull bash the target, interrupting spellcasting.
    skull_bash = {
        id = 106839,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        spend = function() return buff.cat_form.up and 25 or 15 end,
        spendType = function() return buff.cat_form.up and "energy" or "rage" end,

        startsCombat = true,
        texture = 236946,
        toggle = "interrupts",
        readyTime = state.timeToInterrupt,
        debuff = "casting",

        handler = function()
            interrupt()
        end,
    },

    --The Druid roars, increasing movement speed of all party and raid members.
    stampeding_roar = {
        id = 106898,
        cast = 0,
        cooldown = 120,
        gcd = "spell",

        spend = function() return buff.cat_form.up and 30 or 15 end,
        spendType = function() return buff.cat_form.up and "energy" or "rage" end,

        startsCombat = false,
        texture = 464343,

        handler = function()
            applyBuff("stampeding_roar")
        end,
    },

    --Reduces all damage taken by 50% for 12 sec.
    survival_instincts = {
        id = 61336,
        cast = 0,
        cooldown = function() return 180 * ( glyph.ninth_life.enabled and 0.7 or 1 ) end,
        gcd = "off",

        startsCombat = false,
        texture = 236169,
        toggle = "defensives",

        handler = function()
            applyBuff( "survival_instincts" )
        end,
    },

    --Swipe nearby enemies.
    swipe_bear = {
        id = 779,
        cast = 0,
        cooldown = 3,
        gcd = "spell",

        spend = function() return (buff.clearcasting.up and 0) or 15 end, 
        spendType = "rage",

        startsCombat = true,
        texture = 134296,

        form = "bear_form",
        handler = function()
            removeBuff( "clearcasting" )
        end,
    },

    --Swipe nearby enemies.
    swipe_cat = {
        id = 62078,
        cast = 0,
        cooldown = 0,
        gcd = "totem",

        spend = function () return (buff.clearcasting.up and 0) or (45 * ((buff.berserk.up and 0.5) or 1)) end, 
        spendType = "energy",

        startsCombat = true,
        texture = 134296,

        form = "cat_form",
        handler = function()
            removeBuff( "clearcasting" )
        end,
    },

    --Thorns sprout from the friendly target causing Nature damage to attackers when hit.
    thorns = {
        id = 782, -- Use consistent Thorns ID
        cast = 0,
        cooldown = 45,
        gcd = "spell",

        spend = function() return (buff.clearcasting.up and 0) or 0.36 end, 
        spendType = "mana",

        startsCombat = false,
        texture = 136104,

        handler = function()
            removeBuff( "clearcasting" )
            applyBuff( "thorns" )
        end,
    },

    --Deals damage and causes all targets within 8 yards to bleed.
    thrash = {
        id = 77758,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        spend = function() return (buff.clearcasting.up and 0) or 25 end, 
        spendType = "rage",

        startsCombat = true,
        texture = 451161,

        form = "bear_form",
        handler = function()
            removeBuff( "clearcasting" )
            applyDebuff("target", "thrash")
        end,
    },

    --Increases physical damage done by 15% for 8 sec.
    tigers_fury = {
        id = 5217,
        cast = 0,
        cooldown = function() return 30 * ( glyph.tigers_fury.enabled and 0.9 or 1 ) end,
        gcd = "off",

        startsCombat = false,
        texture = 132242,
        
        usable = function() return not buff.berserk.up, "cannot use during berserk" end,

        form = "cat_form",
        handler = function()
            applyBuff("tigers_fury")
            gain(60, "energy")
        end,
    },

    --Shapeshift into travel form, increasing movement speed.
    travel_form = {
        id = 783,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 0.08, 
        spendType = "mana",

        startsCombat = false,
        texture = 132144,

        handler = function()
            swap_form( "travel_form" )
        end,
    },

    -- Wild Charge (MoP talent)
    wild_charge = {
        id = 102401,
        cast = 0,
        cooldown = 15,
        gcd = "off",

        startsCombat = false,
        texture = 538771,

        handler = function()
            if buff.cat_form.up then
                -- Cat form: leap behind target
                applyBuff("wild_charge_movement")
            elseif buff.bear_form.up then
                -- Bear form: charge target
                applyBuff("wild_charge_movement")
            else
                -- Caster form: teleport to ally
                applyBuff("wild_charge_movement")
            end
        end,
    },

    -- Nature's Swiftness (fixed name to match simc) - Only for races that have it
    nature_swiftness = {
        id = 16188, -- Generic Nature's Swiftness for MoP Classic
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,
        texture = 136076,

        usable = function() return false, "nature's swiftness not available for druids in MoP" end,
        handler = function()
            -- Not available for druids in MoP Classic
        end,
    },

    -- Berserking (Troll racial)
    berserking = {
        id = 26297,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        startsCombat = false,
        texture = 136224,

        handler = function()
            applyBuff("berserking")
        end,
    },

    -- Thrash Cat (MoP version - add as alias)
    thrash_cat = {
        id = 106830,
        cast = 0,
        cooldown = 6,
        gcd = "totem",

        spend = function() return (buff.clearcasting.up and 0) or (50 * ((buff.berserk.up and 0.5) or 1)) end,
        spendType = "energy",

        startsCombat = true,
        texture = 451161,

        form = "cat_form",
        handler = function()
            removeBuff("clearcasting")
            applyDebuff("target", "thrash")
        end,
    },
} )


-- Settings
spec:RegisterSetting( "druid_description", nil, {
    type = "description",
    name = "Adjust the settings below according to your playstyle preference.  It is always recommended that you use a simulator "..
        "to determine the optimal values for these settings for your specific character.\n\n"
} )

spec:RegisterSetting( "druid_feral_header", nil, {
    type = "header",
    name = "Feral: General"
} )

spec:RegisterSetting( "druid_feral_description", nil, {
    type = "description",
    name = strformat( "These settings will change the %s behavior when using the default |cFF00B4FFFeral|r priority.\n\n", Hekili:GetSpellLinkWithTexture( spec.abilities.cat_form.id ) )
} )

spec:RegisterSetting( "min_roar_offset", 29, {
    type = "range",
    name = strformat( "Minimum %s before %s", Hekili:GetSpellLinkWithTexture( spec.abilities.rip.id ), Hekili:GetSpellLinkWithTexture( spec.abilities.savage_roar.id ) ),
    desc = strformat( "Sets the minimum number of seconds over the current %s duration required for %s recommendations.\n\n"..
        "Default: 29", Hekili:GetSpellLinkWithTexture( spec.abilities.rip.id ), Hekili:GetSpellLinkWithTexture( spec.abilities.savage_roar.id ) ),
    width = "full",
    min = 0,
    softMax = 42,
    step = 1,
} )

spec:RegisterSetting( "rip_leeway", 1, {
    type = "range",
    name = strformat( "%s Leeway", Hekili:GetSpellLinkWithTexture( spec.abilities.rip.id ) ),
    desc = "Sets the leeway allowed when deciding whether to recommend clipping Savage Roar.\n\nThere are cases where Rip falls "..
        "very shortly before Roar and, due to default priorities and player reaction time, Roar falls off before the player is able "..
        "to utilize their combo points. This leads to Roar being cast instead and having to rebuild 5CP for Rip."..
        "This setting helps address that by widening the rip/roar clipping window.\n\n"..
        "Recommendation: 1\n\n"..
        "Default: 1",
    width = "full",
    min = 1,
    softMax = 10,
    step = 0.1,
} )

spec:RegisterSetting( "maintain_ff", true, {
    type = "toggle",
    name = "Maintain Faerie Fire",
    desc = "If checked, Keep up Sunder debuff if not provided externally.\n\n"..
        "Default: Checked",
    width = "full",
} )

spec:RegisterSetting( "rake_dpe_check", true, {
    type = "toggle",
    name = "Compare Rake DPE with Shred",
    desc = "If checked, skip rake if shred has better DPE.\n\n"..
        "Default: Checked",
    width = "full",
} )

spec:RegisterSetting( "cancel_primal_madness", false, {
    type = "toggle",
    name = "Cancel Primal Madness",
    desc = "If checked, will recommend to cancel primal madness when on low energy.\n\n"..
        "Default: Unchecked",
    width = "full",
} )

spec:RegisterSetting( "optimize_trinkets", false, {
    type = "toggle",
    name = "Optimize Trinkets",
    desc = "If checked, Energy will be pooled for anticipated trinket procs.\n\n"..
        "Default: Unchecked",
    width = "full",
} )

spec:RegisterSetting( "druid_bite_header", nil, {
    type = "header",
    name = strformat( "Feral: %s", Hekili:GetSpellLinkWithTexture( spec.abilities.ferocious_bite.id ) )
} )

spec:RegisterSetting( "ferociousbite_enabled", true, {
    type = "toggle",
    name = strformat( "Use %s", Hekili:GetSpellLinkWithTexture( spec.abilities.ferocious_bite.id ) ),
    desc = strformat( "If unchecked, %s will not be recommended.", Hekili:GetSpellLinkWithTexture( spec.abilities.ferocious_bite.id ) ),
    width = "full",
} )

spec:RegisterSetting( "min_bite_sr_remains", 11, {
    type = "range",
    name = strformat( "Minimum %s before %s", Hekili:GetSpellLinkWithTexture( spec.abilities.savage_roar.id ), Hekili:GetSpellLinkWithTexture( spec.abilities.ferocious_bite.id ) ),
    desc = strformat( "If set above zero, %s will not be recommended unless %s has this much time remaining.\n\n" ..
        "Default: 11", Hekili:GetSpellLinkWithTexture( spec.abilities.ferocious_bite.id ), Hekili:GetSpellLinkWithTexture( spec.abilities.savage_roar.id ) ),
    width = "full",
    min = 0,
    softMax = 14,
    step = 1
} )

spec:RegisterSetting( "min_bite_rip_remains", 11, {
    type = "range",
    name = strformat( "Minimum %s before %s", Hekili:GetSpellLinkWithTexture( spec.abilities.rip.id ), Hekili:GetSpellLinkWithTexture( spec.abilities.ferocious_bite.id ) ),
    desc = strformat( "If set above zero, %s will not be recommended unless %s has this much time remaining.\n\n" ..
        "Default: 11", Hekili:GetSpellLinkWithTexture( spec.abilities.ferocious_bite.id ), Hekili:GetSpellLinkWithTexture( spec.abilities.rip.id ) ),
    width = "full",
    min = 0,
    softMax = 14,
    step = 1,
} )

spec:RegisterSetting( "bear_form_mode", "tank", {
    type = "select",
    name = strformat( "%s Mode", Hekili:GetSpellLinkWithTexture( spec.abilities.bear_form.id ) ),
    width = "full",
    values = {
        none = strformat( "Swap (%s)", Hekili:GetSpellLinkWithTexture( spec.abilities.cat_form.id ) ),
        tank = strformat( "Tank (%s)", Hekili:GetSpellLinkWithTexture( spec.abilities.bear_form.id ) )
    },
    sorting = { "tank", "none" }
} )





if (Hekili.Version:match( "^Dev" )) then
    spec:RegisterSetting("druid_debug_header", nil, {
        type = "header",
        name = "Debug"
    })

    spec:RegisterSetting("druid_debug_description", nil, {
        type = "description",
        name = "Settings used for testing\n\n"
    })

    spec:RegisterSetting("dummy_ttd", 300, {
        type = "range",
        name = "Training Dummy Time To Die",
        desc = "Select the time to die to report when targeting a training dummy",
        width = "full",
        min = 0,
        softMax = 300,
        step = 1,
        set = function( _, val )
            Hekili.DB.profile.specs[ 11 ].settings.dummy_ttd = val
        end
    })


    spec:RegisterSetting("druid_debug_footer", nil, {
        type = "description",
        name = "\n\n"
    })
end

-- Options
spec:RegisterOptions( {
    enabled = true,

    aoe = 2,
    cycle = true,

    gcd = 1126,

    nameplates = true,
    nameplateRange = 8,

    damage = false,
    damageExpiration = 6,

    potion = "tolvir",

    package = "Feral",
    usePackSelector = true
} )


-- Default Packs
spec:RegisterPack( "Feral", 20250422, [[Hekili:fVr)VTTn2)wcoa3K1op)ruA3UKaK26U5I2KIyVbC4WSKIeDmxKL8PpsAgc0F737rsjrrrkjND92p00ekQ3x89nFA14vlxTW3nLS6YjJMyn6KjVz4KjJoz00vlsFChz1IDUE35El8lHUBHF(bsSBaU6JbrU(4BNeLf7bpz1IBYObPZdxDJoqAD8pc7DhXB1LJrOVH67t47LK4TAXYn0KCh8FU5ocKM7eTg(BVuAuyUtanjfE86O4CNFHChnGoC1c2Iiz4fqCVNa)2LmEIe6EtaXF1BxTG)(Rwe7EhqMEpc70o1n(wc8IWMx4fttjXu3vloi3XpkDiUXHPuV7OH3M7mi3HesIV9XCNZpl3zQfNIJP74G9DFA2f)2SCNRVA5flNF1L5ohoj3z5fx)ZZwU4OvPGyqHGAGW0nXUjBS9CtnIwRrvms12rOp1i09I2EtK9UiAik3qOmMb3BYwVEyI79Ge2ooYnEymzRlne2ZP5oVE4KkmjTjevhBsYs31oETy4Tq8s3vJn5NfWsBHZLiBFkCUFE1w9ZID5OPXrhqsw9K7pTGiKfQhlju36gElaDHq9K9fShcIvYgAOVG(YDE6jHKoAlj0oATTxGlaLhhMTl35OwPLKnXaArcbu1wtctOTRzNKfFp9E3aB4qmLg6bsN66OVF2hMD5I5OA6fVdvsxiZsBiUbPBgUZlLXqthXioaorBHZiBF3TmBr4mrSZTUFn357YDgn0QD9BfiBThqEAf7DJB8DjG6s7A7mz9ne3yBWdXwMuEqjClOazP86ys4Fsj(2XKBXtcUwMg1CJ8ZK9GFowIFkisDkW01VC1IFGXm7aTa30O4hTtEGUonKKKaS1GkI40xpAWb0qBuNe0BlraUdKEsJY82OOk8l8NbUwHf2s)ZsU2SkV(tXdeQ3XK)i7E49q4ui1pafknil5DY1UfY9O4K2uVL83P469Qp)2RYD(YvZVCzUZpp7YzxFXYRUEbOLhbQ6sqxIBUhScrummlbCMWaTS3P(5lUvT(sm4grAANBjz3(aDhXKF86HTQX3xdlbXf3TlG65Ydo6g6N7GEXtbqeIXJ7oSwnjrmdMnd21Q9qjyLJGmLbgTpsNR(EsiTfQySLI4sJD1F9SaqiCpXgiRTucYp4PzNrWqOuecR7Kj(Cwqk97lcHWffjGFaxFGk0zL2PnYsHgolTPekgKRGGbd4acagLdujla9hRg2GHd36woTjVoH7uWlkkWp6HWw9jCdjoHeFNQ4Z9pq289FbCbucMCNVh48hd92ehfs)tcyOKLWsPTIVRhjwFwscFBhIGwnbNJ5X7BKEdpoFbPaRFlq32RZIFSUSvNdLYJ2Qxs9SfFYlaq8b4zm2SGpGSza6gs8ivhxEALf1bTKKIzk31)X2CzT2fWhXEnng(bVGHA09hyphiBydcnt34T4)5tqQPMgjBLHsGCisqCLr(ZyVB1QMDs0skSquPmGAld0QqXxYEmkQxuSdbHdczaDHEpYJ5ZdTgJX)ssDdbBmp3K02Zo(4A2jNwQbA(SPnhCcld0FHAudpQBaiQVbkDkfCH1i7j5dzubOmfwbmfy2CMc9gkvuBquKpx3UiFxxWhyBM(GFhE2t1zVzjjG6oJdXNkcjkD84TH4DxIINEgHvarP0xAKnzNfY5MbkBUPPqPRv0Q8ITyWKCxwqG9nGxvfMAoeppooBxQGDQkhqc5cfEurteLWKwUNlGg(FyJvoZRF2MxAFfSBr7AxC0dQMZlszjiIPuIkXkYLYebRjAzWXG(u9C8IqFeXrPIIa7fRufcba)RFocJ10qAYgqHfHWBEoqqk7tae)4ZbeRPbbcsy8O9o6WhOHOXqmH3HModkuw5xXzKQH8F1WfJvTOtiERwmA44kU5bxQjItK7aFLHSA24(17YzPIjDHpOEez(CEK5uuTNiQMPfhtBH6uruNUHy)anWxTi84mkycZ6Ggly9NJ(cWwdTgcCWBjPU5o)2fxp)I3(Pzyfmx((CN3D1LVFoREDy31snmXdiGyAeqLZeYiMdcw0LChw4f5t8CNLI38EiiLVCvdq6Ce068lxpdlO6ILSF9lxCnRDw68xQYO9X9OQJwn(ZBT8(U9KO4JIDUvybP5uRUTY8p9Pzxx2DKkH6oqbHfkTBD1YQyW3XUqZTVkzgt)tQXuQj7YtMNLgI85EI50nm1gS2InXAgLIhFCTCNh2G2G8(EvvubsopqX4bxf9ozs5z1JSEt)MI51P8JZfEUHVif7zqAbv2dP4bn4OU9e1KYnfRvNKFwv(mCD7EqLnWyQC8TwCOb5Uh5rJYsSVbqrdtMlNV4xqJMVC98RUE(Y)fuBK17axAl(YmWT1L)mCao7ReVSumaoiSjmNFCicE8O46GBWn0B3qsaz3oWFgkPApBzRY6qvBKSPk2e5hP28UMch9n2P84qQz4kMdSNK7Cn8OADHHXFiZq9qF(Q128CBqV56qTKSPmbGj89iZ4VbIaDuBobyD4VE1e0D6Ab1o4NKTupmVJ1qQhB6ZH5H6VBaKkpSADDcbDpZqFi651mW87CuBouyYI2AG03M7)GTxKgA0dQw7He7CQwlKm5UPDRDngUfAq(zB719)Sp2Sh2SXrAQJSRii6QUOBZzjFSYw2pllxmUp3JRBuR3HJXg4DXv1VCXPVu62fB22YND)RlvV5nivfU9QDON0axyho1DVD99wl1heZup0n3P697atRssBnv(VVlaTV3uz7MHkQhM8jWuKZsX(h9yRjo0rda)1LZ)elHbwvoF(QFB2NND5Yv9STFc5LOLHGKAudEyshxm5E15NV9vQymwJFZwc95O7fv0PTrEBfpEOpfBaPhxxAs9IKrWQlF0PAZhTlG)ggC08m9zznrY6fRE02BdEGYuUsXYQIdb1Ye8Qlayq3UlkovuLZl4t5XlWSl(pzuwrijGNFE3326MIlaGdY1mzy(h)eneE0KFk35xdtY2Hac3ah5a0Q8v(cy35FudclBkwFXjdgRJccIEGzC5cwVG53deSnwzj4MPHyr3K6t2cEYKwSVWigbKfwB3((4MHA3DVXnH8tafJrH1ClXg4LYUI1xEHl)o2O8tTP5V4Vd(N7gqphdXC3pED8FrDfS317hgnRDk17yJOSQjJ7hw7lFY39j9C3Ajrr4I9J(SmIrjpgfOehAmWtkupmHpbzBPjjmLpbaeKctyHLMKgtdVdcHom3j3zEk)LyD4dCG5ty9ed9DtUNG3RwrDPSj9iiZhZ2HqbDY4cDW)9VMqqir2M87Vc7Oa1BJ8UDdFScRc1BYxXANOPbvWvwBVaP)twdveOzjheW53VlQ3QAPjsygesbsCKaKPfBLjnylfMTfYMMDKeaPfK)X5BlK4yFvLnqXdNv4fASjcsfEX2S1X07yHWqb)Qf)JCNU7W5h)hT2Kt44SOlAVcBb(zvZOXRU3niJCwYosqqrkqdlt(78Zow3RIjTkEXXQpViDlSBDI9msDpjBqHrsQDAQVypAswt5LcIqv597DsITZ2j2TUsIuP91kBxPv9kBxzaLQ4w25HPglRaeWxAxNbtvFhE462FTZMiOJ(1hBfmi1RvbA4)XPwJgCGHcdfpqQmsvYEN9w3VAdeCyXrOCY0NFM1tpDy9voEGPEUC6KJuHpKlNTO9icWR0hJtF9WjdQJGXcPuxTXxLvCdfXqQRls(kAspO4VGI4ECqJ(KDEddcosStOPzmClRkXip9xIq(h5EssgwErkV8SFq9AeEfD9zhy6cg0dIImYREv5m61(kSCUz7VmlDHcrr(5LmtpVs5s80fbvQ4jnKIsVRuaF2Rl93ccY41bldMQltgHs9lhUoPw)Qh5NWsGKHsLl3vga9tscWO(D42nnun6oDU1Y(y39wRYvQ79kU3OsnHMdqBLYvPedL9nMexu(inXMthnqXB85vJk63nAOLE4wmcSkqZQdOnvp00o5RiOBOEkpSPhpYaTvSFfIBshe3XczR2jsvpQQnyRa6qSZ132RjLvpWLhp1MYzUITYWUwdMfHt3NzqRIsk3ktIYImHebpAgeFzuZama(vJc90tkD35ObTD7JNoTiQspMKm90QeuRO3tpBQL5WVMNsab1018HPNsA00jKEm0hPbngDSbnts78Xwcc6V44FPNEvREgjx1KkeIZJnNmJGcBmCxTQzbKzP5E9uhF6Pg5gPfoLJTv)Hd)OTh3Ail07Z5IdRO1YWcOErTEy2ukBnqXMrRLwJKJoDI1GcRtRICP3NBcup1kH2MK6yZzzIzmEyJSunNu6tpvq8Vz0rfkr98o90t5GeuNW9WdueVqUZ6s3vDTM2J6mrvBs(rhPTQM63cMz6Vwh2pBSo(rLD6dvnaXx1LLC6zfX(66A1(wQrFyL2BdRvXcnD3uiEnChz)VrNM1P)I4Pg)ipWhQ8DEuH(Q1WyuLDPcrVMpae(HAZRoRMbUwqxwgBnid1kx(QhBv6IUZVAddiH1gdmpB1lIBqJVCIs0o1QdGP(bAC60bnwsJnyByS1yOT(Pn0gTQXMSPGOHbMrZs5piJAslEIqD(5s0lDm9FMecrSMhOrqxP6PJvoP0(qD01KBLIy61KTkz11a0lo9AVkH4D2OHJRP7k1rLwZD88PLj8AAo00H3QXXs1vWPvXtpUmEAVh0mD4InaviAoS2uAz252GUONUMzS9MJpOgLzoN5gusJbbRvbqR8f3tAlJzqfObhBn013hFN83)5BwFIw)BCOwZvSjgU5B9SInPWpF7YCqfv7FO)65OYdP26NSUug)S23Uxhy6oEkbZZxVPee77XLugM64R)FCWvITE76RjxBWoU3(10yWRFgmQqU4E7E5EwyTq0WkS(8rLiEILoi)S7wQem6Dxi1m4e6GNVOXPnMNHZNuufUy8jQu2hPdqs3uPE49MbnwtUOYjf5K0YhYrjEFPPoXmTGORxF(ZR7mvitn9bb2SkoX5FGgNpEpUfMoY2GnDiR(V]])

