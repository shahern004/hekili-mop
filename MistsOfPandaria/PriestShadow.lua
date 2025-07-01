-- PriestShadow.lua
-- Updated May 28, 2025
-- Mists of Pandaria module for Priest: Shadow spec

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'PRIEST' then return end

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

-- Enhanced helper functions for Shadow Priest
local function UA_GetPlayerAuraBySpellID(spellID)
    return FindUnitBuffByID("player", spellID)
end

local function GetTargetDebuffByID(spellID)
    return FindUnitDebuffByID("target", spellID, "PLAYER")
end

local spec = Hekili:NewSpecialization( 258 ) -- Shadow spec ID for MoP

-- Shadow-specific combat log event tracking
local shadowCombatLogFrame = CreateFrame("Frame")
local shadowCombatLogEvents = {}

local function RegisterShadowCombatLogEvent(event, handler)
    if not shadowCombatLogEvents[event] then
        shadowCombatLogEvents[event] = {}
    end
    table.insert(shadowCombatLogEvents[event], handler)
end


shadowCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Shadow Orb generation tracking with advanced optimization
RegisterShadowCombatLogEvent("SPELL_CAST_SUCCESS", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 8092 then -- Mind Blast
        -- Track Mind Blast casts for Shadow Orb generation
        -- Base: 100% chance to generate Shadow Orb
        -- Enhanced: Track for Surge of Darkness cooldown reset potential
        ns.shadow_priest_mind_blast_count = (ns.shadow_priest_mind_blast_count or 0) + 1
        ns.shadow_priest_last_mind_blast = timestamp
        
        -- Enhanced tracking for tier set bonuses
        if ns.shadow_priest_tier14_4pc then
            -- T14 4-piece: Mind Blast has chance to reset SW:D cooldown
            ns.shadow_priest_tier14_proc_opportunity = timestamp
        end
        
    elseif spellID == 32379 then -- Shadow Word: Death
        -- Track SW:D usage for execute optimization and backlash management
        ns.shadow_priest_swd_count = (ns.shadow_priest_swd_count or 0) + 1
        ns.shadow_priest_last_swd = timestamp
        
        -- Track for potential backlash damage (when target doesn't die)
        ns.shadow_priest_swd_pending_backlash = timestamp + 0.1 -- Small delay for death check
        
    elseif spellID == 15407 then -- Mind Flay
        -- Track Mind Flay channel initiation for Shadowy Apparition tracking
        ns.shadow_priest_mind_flay_start = timestamp
        ns.shadow_priest_mind_flay_channels = (ns.shadow_priest_mind_flay_channels or 0) + 1
        
    elseif spellID == 2944 then -- Devouring Plague
        -- Track DP application for Shadow Orb consumption optimization
        ns.shadow_priest_devouring_plague_cast = timestamp
        
        -- Track for enhanced healing effect monitoring
        if ns.shadow_priest_glyph_dp_healing then
            ns.shadow_priest_dp_healing_window = timestamp + 24 -- DP duration
        end
        
    elseif spellID == 589 then -- Shadow Word: Pain
        -- Track SWP application for pandemic optimization
        ns.shadow_priest_swp_applications = (ns.shadow_priest_swp_applications or 0) + 1
        ns.shadow_priest_last_swp_cast = timestamp
        
    elseif spellID == 34914 then -- Vampiric Touch
        -- Track VT application for pandemic optimization
        ns.shadow_priest_vt_applications = (ns.shadow_priest_vt_applications or 0) + 1
        ns.shadow_priest_last_vt_cast = timestamp
    end
end)

-- Enhanced DoT damage tracking with pandemic mechanics
RegisterShadowCombatLogEvent("SPELL_PERIODIC_DAMAGE", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical)
    -- Shadow Word: Pain tick tracking
    if spellID == 589 then
        ns.shadow_priest_swp_ticks = (ns.shadow_priest_swp_ticks or 0) + 1
        ns.shadow_priest_last_swp_tick = timestamp
        
        -- Track for Shadowy Apparition proc potential
        if critical and ns.shadow_priest_mastery_shadowy_recall then
            ns.shadow_priest_apparition_proc_opportunity = timestamp
        end
        
    -- Vampiric Touch tick tracking
    elseif spellID == 34914 then
        ns.shadow_priest_vt_ticks = (ns.shadow_priest_vt_ticks or 0) + 1
        ns.shadow_priest_last_vt_tick = timestamp
        
        -- Track mana return from VT ticks
        ns.shadow_priest_vt_mana_return = timestamp
        
    -- Devouring Plague tick tracking
    elseif spellID == 2944 then
        ns.shadow_priest_dp_ticks = (ns.shadow_priest_dp_ticks or 0) + 1
        ns.shadow_priest_last_dp_tick = timestamp
        
        -- Track enhanced healing from DP ticks (if glyphed)
        if ns.shadow_priest_glyph_dp_healing then
            ns.shadow_priest_dp_healing_tick = timestamp
        end
        
    -- Mind Flay tick tracking
    elseif spellID == 15407 then
        ns.shadow_priest_mind_flay_ticks = (ns.shadow_priest_mind_flay_ticks or 0) + 1
        
        -- Track for Shadowy Apparition generation (each tick has proc chance)
        if ns.shadow_priest_mastery_shadowy_recall then
            local proc_chance = 0.04 * (ns.shadow_priest_mastery_rating or 8) -- 4% per mastery point
            if math.random() < proc_chance then
                ns.shadow_priest_apparition_spawned = timestamp
            end
        end
    end
end)

-- Advanced aura tracking for proc monitoring
RegisterShadowCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if destGUID == UnitGUID("player") then
        if spellID == 87160 then -- Surge of Darkness
            -- Track Surge of Darkness proc for instant Mind Spike
            ns.shadow_priest_surge_of_darkness_proc = timestamp
            ns.shadow_priest_surge_procs = (ns.shadow_priest_surge_procs or 0) + 1
            
        elseif spellID == 15473 then -- Shadowform
            -- Track Shadowform application for damage bonus
            ns.shadow_priest_shadowform_active = timestamp
            
        elseif spellID == 77487 then -- Shadow Orb
            -- Track Shadow Orb stacking for optimal consumption
            local current_orbs = UnitPower("player", 13) or 0 -- Shadow Orbs power type
            ns.shadow_priest_shadow_orbs = current_orbs
            ns.shadow_priest_orb_gain_time = timestamp
            
        elseif spellID == 47585 then -- Dispersion
            -- Track Dispersion for mana regeneration and damage reduction
            ns.shadow_priest_dispersion_start = timestamp
            
        elseif spellID == 15286 then -- Vampiric Embrace
            -- Track Vampiric Embrace for group healing
            ns.shadow_priest_vampiric_embrace_active = timestamp
        end
    end
end)

-- Enhanced buff/debuff removal tracking
RegisterShadowCombatLogEvent("SPELL_AURA_REMOVED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if destGUID == UnitGUID("player") then
        if spellID == 87160 then -- Surge of Darkness removed
            -- Track Surge consumption for efficiency analysis
            ns.shadow_priest_surge_consumed = timestamp
            local duration_held = timestamp - (ns.shadow_priest_surge_of_darkness_proc or timestamp)
            ns.shadow_priest_surge_efficiency = duration_held <= 10 -- Good efficiency if used within 10 seconds
            
        elseif spellID == 47585 then -- Dispersion removed
            -- Track Dispersion usage efficiency
            local dispersion_duration = timestamp - (ns.shadow_priest_dispersion_start or timestamp)
            ns.shadow_priest_dispersion_efficiency = dispersion_duration >= 4 -- Good if held for at least 4 seconds
        end
    elseif sourceGUID == UnitGUID("player") then
        -- Track DoT removals for refresh timing
        if spellID == 589 then -- Shadow Word: Pain removed
            ns.shadow_priest_swp_removed = timestamp
        elseif spellID == 34914 then -- Vampiric Touch removed  
            ns.shadow_priest_vt_removed = timestamp
        elseif spellID == 2944 then -- Devouring Plague removed
            ns.shadow_priest_dp_removed = timestamp
        end
    end
end)

-- Shadow Word: Death backlash damage tracking
RegisterShadowCombatLogEvent("SPELL_DAMAGE", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical)
    -- Track SW:D backlash when target survives
    if destGUID == UnitGUID("player") and spellID == 32409 then -- SW:D backlash
        ns.shadow_priest_swd_backlash_count = (ns.shadow_priest_swd_backlash_count or 0) + 1
        ns.shadow_priest_swd_backlash_damage = amount
        
        -- Track efficiency - backlash indicates suboptimal usage
        ns.shadow_priest_swd_efficiency_warning = timestamp
    end
end)

-- Enhanced target death tracking for SW:D optimization
RegisterShadowCombatLogEvent("UNIT_DIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags)
    -- Track enemy deaths for execute timing optimization
    if destGUID and destName then
        ns.shadow_priest_target_death = timestamp
        
        -- Check if recent SW:D contributed to kill (no backlash)
        local recent_swd = ns.shadow_priest_last_swd or 0
        if timestamp - recent_swd <= 2 then
            ns.shadow_priest_swd_kill_contribution = timestamp
            ns.shadow_priest_swd_efficiency_bonus = true
        end
    end
end)

-- Mana efficiency tracking across all abilities
RegisterShadowCombatLogEvent("SPELL_ENERGIZE", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, amount, powerType)
    if destGUID == UnitGUID("player") and powerType == 0 then -- Mana
        if spellID == 34914 then -- Vampiric Touch mana return
            ns.shadow_priest_vt_mana_gained = (ns.shadow_priest_vt_mana_gained or 0) + amount
            
        elseif spellID == 47585 then -- Dispersion mana return
            ns.shadow_priest_dispersion_mana_gained = (ns.shadow_priest_dispersion_mana_gained or 0) + amount
            
        elseif spellID == 15286 then -- Vampiric Embrace potential mana return
            ns.shadow_priest_ve_mana_efficiency = timestamp
        end
    end
end)

shadowCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Shadow Orb generation tracking
RegisterShadowCombatLogEvent("SPELL_CAST_SUCCESS", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 8092 then -- Mind Blast
        -- Mind Blast generates Shadow Orbs
    elseif spellID == 15407 then -- Mind Flay
        -- Mind Flay can trigger Shadow Orb generation via Mastery
    elseif spellID == 73510 then -- Mind Spike
        -- Mind Spike generates Shadow Orbs and removes DoTs
    end
end)

-- DoT tick tracking for Evangelism and Shadow Orb generation
RegisterShadowCombatLogEvent("SPELL_PERIODIC_DAMAGE", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 589 then -- Shadow Word: Pain
        -- SW:P ticks can generate Shadow Orbs via Mastery
    elseif spellID == 34914 then -- Vampiric Touch
        -- VT ticks can generate Shadow Orbs via Mastery
    elseif spellID == 158831 then -- Devouring Plague
        -- DP ticks generate Shadow Orbs and consume them
    end
end)

-- Divine Insight proc tracking
RegisterShadowCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 124430 then -- Divine Insight (Shadow)
        -- Track Divine Insight proc for instant Mind Blast
    elseif spellID == 87118 then -- Dark Evangelism
        -- Track Evangelism stacks for Archangel
    end
end)

-- Mind Spike DoT removal tracking
RegisterShadowCombatLogEvent("SPELL_AURA_REMOVED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 589 or spellID == 34914 or spellID == 158831 then
        -- Track DoT removal by Mind Spike for optimization
    end
end)

-- ============================================================================
-- ADVANCED RESOURCE SYSTEMS - Enhanced MoP Shadow Priest Resource Management
-- ============================================================================
-- Comprehensive resource tracking featuring:
-- - Mana efficiency optimization across all Shadow abilities
-- - Shadow Orb generation timing and optimal consumption patterns  
-- - Dispersion usage optimization for maximum mana recovery
-- - Vampiric Touch mana return tracking with pandemic mechanics
-- - Shadowfiend/Mindbender coordination with mana deficit timing
-- - Spirit and intellect scaling for optimal gear prioritization
-- - Haste breakpoint awareness for DoT optimization
-- - Multi-target mana efficiency with AoE ability prioritization
-- ============================================================================

-- Enhanced Mana resource system with comprehensive tracking
spec:RegisterResource( 0, { -- Mana = 0 in MoP
    -- Dispersion: Primary mana recovery cooldown
    dispersion = {
        aura = "dispersion",
        last = function ()
            local app = state.buff.dispersion.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            local base_return = state.max_mana * 0.06 -- 6% max mana per second
            
            -- Enhanced return with Glyph of Dispersion
            if state.glyph.dispersion.enabled then
                base_return = base_return * 1.2 -- 20% increased effectiveness
            end
            
            -- Reduced return if not in Shadowform
            if not state.buff.shadowform.up then
                base_return = base_return * 0.5 -- 50% reduced without Shadowform
            end
            
            return base_return
        end,
    },
    
    -- Shadowfiend/Mindbender: Pet-based mana restoration
    shadowfiend = {
        aura = "shadowfiend",
        last = function ()
            local app = state.buff.shadowfiend.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1.5 ) * 1.5
        end,
        interval = 1.5,
        value = function()
            local base_return = state.max_mana * 0.03 -- 3% per melee hit
            
            -- Mindbender talent enhancement
            if state.talent.mindbender.enabled then
                base_return = base_return * 1.25 -- 25% more efficient
                -- Also returns slightly more per hit
                base_return = base_return + (state.max_mana * 0.005) -- Additional 0.5%
            end
            
            -- Enhanced return with multiple targets (Shadowfiend cleave)
            if state.active_enemies >= 2 then
                base_return = base_return * math.min(1.5, 1 + (state.active_enemies * 0.1))
            end
            
            -- Glyph of Shadowfiend enhancement
            if state.glyph.shadowfiend.enabled then
                base_return = base_return * 1.1 -- 10% increased mana return
            end
            
            return base_return
        end,
    },
    
    -- Vampiric Touch: DoT-based mana return with pandemic optimization
    vampiric_touch = {
        aura = "vampiric_touch",
        last = function ()
            local app = state.debuff.vampiric_touch.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 3 ) * 3
        end,
        interval = 3,
        value = function()
            local base_return = state.max_mana * 0.02 -- 2% mana per tick
            
            -- Enhanced return based on spell power
            local sp_bonus = (state.stat.spell_power or 0) * 0.00025 -- 0.025% per 100 SP
            base_return = base_return + (state.max_mana * sp_bonus)
            
            -- Multiple target efficiency (VT on multiple targets)
            local vt_targets = state.debuff.vampiric_touch.count or 1
            if vt_targets > 1 then
                base_return = base_return * vt_targets
            end
            
            -- Mastery: Shadowy Recall enhancement
            if state.mastery_value > 0 then
                local mastery_bonus = state.mastery_value * 0.0025 -- 0.25% per mastery point
                base_return = base_return * (1 + mastery_bonus)
            end
            
            -- Glyph of Vampiric Touch enhancement
            if state.glyph.vampiric_touch.enabled then
                base_return = base_return * 1.15 -- 15% increased mana return
            end
            
            return base_return
        end,
    },
    
    -- Archangel: Evangelism stacks conversion to mana
    archangel = {
        aura = "archangel",
        last = function ()
            local app = state.buff.archangel.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            if not state.buff.archangel.up then return 0 end
            
            local stacks_consumed = state.buff.archangel.stacks or 5 -- Usually 5 Evangelism stacks
            local base_return = state.max_mana * 0.01 * stacks_consumed -- 1% per stack per second
            
            -- Enhanced duration and effectiveness at higher stacks
            if stacks_consumed >= 5 then
                base_return = base_return * 1.25 -- 25% bonus at max stacks
            end
            
            return base_return
        end,
    },
    
    -- Shadow Word: Death mana return (when target dies)
    shadow_word_death = {
        channel = "shadow_word_death_kill",
        last = function()
            return state.shadow_word_death_kill_time or 0
        end,
        interval = 0.1,
        value = function()
            -- Instant mana return when SW:D kills target
            return state.max_mana * 0.25 -- 25% mana return on kill
        end,
    },
    
    -- Hymn of Hope: Raid utility mana restoration
    hymn_of_hope = {
        aura = "hymn_of_hope",
        last = function ()
            local app = state.buff.hymn_of_hope.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 2 ) * 2
        end,
        interval = 2,
        value = function()
            return state.max_mana * 0.04 -- 4% max mana every 2 seconds
        end,
    },
} )

-- ============================================================================
-- SHADOW ORB POWER SYSTEM - Advanced Orb Management
-- ============================================================================

-- Enhanced Shadow Orb resource tracking
spec:RegisterResource( 10, { -- AlternatePower = 10 in MoP (Shadow Orbs)
    -- Mind Blast: Primary Shadow Orb generation
    mind_blast = {
        channel = "mind_blast_orb_gen",
        last = function()
            return state.mind_blast_orb_gen_time or 0
        end,
        interval = 0.1,
        value = function()
            -- Mind Blast generates 1 Shadow Orb on cast
            return 1
        end,
    },
    
    -- Critical DoT ticks: Chance to generate Shadow Orbs
    dot_critical = {
        channel = "dot_crit_orb_gen",
        last = function()
            return state.dot_crit_orb_gen_time or 0
        end,
        interval = 0.1,
        value = function()
            -- DoT crits have chance to generate Shadow Orbs
            local crit_chance = state.stat.spell_crit / 100
            local mastery_bonus = (state.mastery_value or 8) * 0.025 -- 2.5% per mastery point
            
            if math.random() < (crit_chance + mastery_bonus) then
                return 1
            end
            return 0
        end,
    },
} )

-- ============================================================================
-- ENHANCED BASE REGENERATION WITH TALENT INTERACTIONS
-- ============================================================================

-- Base mana regeneration with comprehensive bonus calculations
spec:RegisterResource( 0, {}, { -- Mana = 0 in MoP
    base_regen = function ()
        local base = state.max_mana * 0.02 -- 2% base regeneration per 5 seconds
        
        -- Spirit-based regeneration (primary stat for mana regen)
        local spirit_regen = (state.stat.spirit or 0) * 0.56 -- ~0.56 mana per spirit per 5 sec
        
        -- Meditation bonus (in-combat regeneration)
        local meditation_bonus = 0
        if state.talent.meditation.enabled then
            meditation_bonus = spirit_regen * 0.5 -- 50% of normal spirit regen in combat
        end
        
        -- Shadowform mana efficiency bonus
        local shadowform_efficiency = 1.0
        if state.buff.shadowform.up then
            shadowform_efficiency = 1.15 -- 15% improved mana efficiency
        end
        
        -- Inner Fire/Inner Will mana considerations
        local inner_bonus = 0
        if state.buff.inner_will.up then
            inner_bonus = spirit_regen * 0.1 -- 10% bonus spirit regen with Inner Will
        end
        
        -- Intellect-based mana bonus
        local int_bonus = (state.stat.intellect or 0) * 15 -- Mana pool scaling
        
        -- Discipline talent bonuses (if talented)
        local disc_bonus = 0
        if state.talent.archangel.enabled then
            disc_bonus = base * 0.05 -- 5% bonus if Archangel talented
        end
        
        -- Gear-based mana regeneration bonuses
        local gear_bonus = 0
        
        -- Tier set bonuses affecting mana efficiency
        if state.set_bonus.tier14_2pc == 1 then
            gear_bonus = gear_bonus + (base * 0.03) -- 3% mana efficiency
        end
        if state.set_bonus.tier15_4pc == 1 then
            gear_bonus = gear_bonus + (base * 0.05) -- 5% mana efficiency  
        end
        
        -- Meta gem bonuses
        if state.meta_gem and state.meta_gem.mana_bonus then
            gear_bonus = gear_bonus + (state.max_mana * 0.02) -- 2% max mana bonus
        end
          local total_regen = base + spirit_regen + meditation_bonus + inner_bonus + disc_bonus + gear_bonus
        return total_regen * shadowform_efficiency / 5 -- Convert to per-second
    end,
} )

-- Shadow Orbs resource system
spec:RegisterStateTable( "shadow_orb", setmetatable({}, {
    __index = function( t, k )
        if k == "count" then
            return FindUnitBuffByID("player", 77487) and FindUnitBuffByID("player", 77487).count or 0
        elseif k == "max" then
            return 3 -- Maximum Shadow Orbs
        elseif k == "deficit" then
            return t.max - t.count
        end
        return 0
    end,
}))
-- Tier 14: Vestments of the Lost Cataphract (Heart of Fear/Terrace of Endless Spring)
spec:RegisterGear( "tier14", 86919, 86920, 86921, 86922, 86923 ) -- Base tier references

-- Tier 14 Set Bonuses with Enhanced Tracking
spec:RegisterAura( "tier14_2pc_shadow", {
    id = 105843,
    duration = 30,
    max_stack = 1,
    generate = function( t )
        if state.set_bonus.tier14_2pc >= 1 then
            t.name = "Tier 14 2-Piece Bonus"
            t.count = 1
            t.expires = query_time + 3600
            t.applied = query_time
            t.caster = "player"
            
            -- Enhanced Shadow Word: Pain damage by 15%
            t.swp_damage_bonus = 0.15
            t.optimal_for_multidot = true
            
            return
        end
        
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
    end,
} )

spec:RegisterAura( "tier14_4pc_shadow", {
    id = 105844,
    duration = 8,
    max_stack = 1,
    generate = function( t )
        if state.set_bonus.tier14_4pc >= 1 then
            t.name = "Tier 14 4-Piece Bonus"
            t.count = 1
            t.expires = query_time + 3600
            t.applied = query_time
            t.caster = "player"
            
            -- Mind Blast has 25% chance to reset Shadow Word: Death cooldown
            t.swd_reset_chance = 0.25
            t.enhances_mind_blast = true
            t.execute_optimization = true
            
            return
        end
        
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
    end,
} )

-- Tier 15: Vestments of the All-Consuming Maw (Throne of Thunder)
spec:RegisterGear( "tier15", 95225, 95226, 95227, 95228, 95229 ) -- Base tier references
spec:RegisterGear( 14, 8, { -- Tier 15 Shadow Priest
    -- LFR Tier 15: Vestments of the All-Consuming Maw
    { 95299, head = 95298, shoulder = 95301, chest = 95299, hands = 95300, legs = 95302 },
    -- Normal Tier 15: Vestments of the All-Consuming Maw
    { 95706, head = 95705, shoulder = 95708, chest = 95706, hands = 95707, legs = 95709 },
    -- Heroic Tier 15: Vestments of the All-Consuming Maw
    { 96102, head = 96101, shoulder = 96104, chest = 96102, hands = 96103, legs = 96105 },
    -- Thunderforged Tier 15: Enhanced versions
    { 96102, head = 96516, shoulder = 96519, chest = 96517, hands = 96518, legs = 96520 },
} )

-- Tier 15 Set Bonuses with Enhanced Tracking
spec:RegisterAura( "tier15_2pc_shadow", {
    id = 138129,
    duration = 15,
    max_stack = 1,
    generate = function( t )
        if state.set_bonus.tier15_2pc >= 1 then
            t.name = "Tier 15 2-Piece Bonus"
            t.count = 1
            t.expires = query_time + 3600
            t.applied = query_time
            t.caster = "player"
            
            -- Shadow Word: Pain critical strikes reduce Mind Blast cooldown by 0.5 seconds
            t.cooldown_reduction = 0.5
            t.enhances_swp_crits = true
            t.mind_blast_synergy = true
            
            return
        end
        
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
    end,
} )

spec:RegisterAura( "tier15_4pc_shadow", {
    id = 138132,
    duration = 10,
    max_stack = 1,
    generate = function( t )
        if state.set_bonus.tier15_4pc >= 1 then
            t.name = "Tier 15 4-Piece Bonus"
            t.count = 1
            t.expires = query_time + 3600
            t.applied = query_time
            t.caster = "player"
            
            -- Devouring Plague heals you for 100% of damage dealt
            t.devouring_plague_heal = 1.0 -- 100% healing
            t.survival_enhancement = true
            t.dp_priority_bonus = true
            
            return
        end
        
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
    end,
} )

-- Tier 16: Vestments of the Ternion Glory (Siege of Orgrimmar)
spec:RegisterGear( "tier16", 99163, 99164, 99165, 99166, 99167 ) -- Base tier references
spec:RegisterGear( 15, 8, { -- Tier 16 Shadow Priest
    -- LFR Tier 16: Vestments of the Ternion Glory
    { 99164, head = 99163, shoulder = 99166, chest = 99164, hands = 99165, legs = 99167 },
    -- Normal Tier 16: Vestments of the Ternion Glory
    { 99691, head = 99690, shoulder = 99693, chest = 99691, hands = 99692, legs = 99694 },
    -- Heroic Tier 16: Vestments of the Ternion Glory
    { 100163, head = 100162, shoulder = 100165, chest = 100163, hands = 100164, legs = 100166 },
    -- Mythic Tier 16: Enhanced Heroic versions
    { 100163, head = 100580, shoulder = 100583, chest = 100581, hands = 100582, legs = 100584 },
} )

-- Tier 16 Set Bonuses with Enhanced Tracking
spec:RegisterAura( "tier16_2pc_shadow", {
    id = 144910,
    duration = 8,
    max_stack = 1,
    generate = function( t )
        if state.set_bonus.tier16_2pc >= 1 then
            t.name = "Tier 16 2-Piece Bonus"
            t.count = 1
            t.expires = query_time + 3600
            t.applied = query_time
            t.caster = "player"
            
            -- Mind Flay increases Shadow damage dealt by 2% per tick, stacking up to 10 times
            t.shadow_damage_stacks = 10
            t.damage_per_stack = 0.02 -- 2% per stack
            t.mind_flay_enhancement = true
            
            return
        end
        
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
    end,
} )

spec:RegisterAura( "tier16_4pc_shadow", {
    id = 144911,
    duration = 6,
    max_stack = 1,
    generate = function( t )
        if state.set_bonus.tier16_4pc >= 1 then
            t.name = "Tier 16 4-Piece Bonus"
            t.count = 1
            t.expires = query_time + 3600
            t.applied = query_time
            t.caster = "player"
            
            -- Devouring Plague has 40% chance to not consume Shadow Orbs
            t.orb_preservation_chance = 0.40 -- 40% chance
            t.resource_efficiency = true
            t.dp_optimization = true
            
            return
        end
        
        t.count = 0
        t.expires = 0
        t.applied = 0
        t.caster = "nobody"
    end,
} )

-- ============================================================================
-- LEGENDARY CLOAKS AND NOTABLE TRINKETS
-- ============================================================================

-- Legendary Cloaks (Mists of Pandaria questline rewards)
spec:RegisterGear( "legendary_cloak", 102246, { -- Jina-Kang, Kindness of Chi-Ji (Healer cloak)
    bonus = {
        { stat = "intellect", amount = 600 },
        { stat = "spirit", amount = 400 },
        { effect = "legendary_cloak_heal_proc", chance = 0.15 } -- 15% chance on heal
    }
} )

spec:RegisterGear( "legendary_cloak_dps", 102245, { -- Xing-Ho, Breath of Yu'lon (DPS cloak)
    bonus = {
        { stat = "intellect", amount = 600 },
        { stat = "critical_strike", amount = 400 },
        { effect = "legendary_cloak_damage_proc", chance = 0.15 } -- 15% chance on damage
    }
} )

-- Notable Trinkets for Shadow Priests
spec:RegisterGear( "kardris_toxic_totem", 104769, {
    bonus = {
        { stat = "intellect", amount = 600 },
        { effect = "toxic_totem_proc", cooldown = 105, damage_multiplier = 1.15 }
    }
} )

spec:RegisterGear( "purified_bindings_of_immerseus", 104770, {
    bonus = {
        { stat = "intellect", amount = 600 },
        { effect = "purified_bindings_mana", chance = 0.20, mana_return = 0.05 }
    }
} )

spec:RegisterGear( "black_blood_of_yshaarj", 104810, {
    bonus = {
        { stat = "intellect", amount = 600 },
        { effect = "black_blood_shadow_proc", cooldown = 115, shadow_damage_bonus = 0.25 }
    }
} )

spec:RegisterGear( "thoks_tail_tip", 105609, {
    bonus = {
        { stat = "intellect", amount = 650 },
        { effect = "thok_crit_proc", chance = 0.25, crit_bonus = 0.30, duration = 20 }
    }
} )

spec:RegisterGear( "haromms_talisman", 105458, {
    bonus = {
        { stat = "intellect", amount = 650 },
        { effect = "haromm_multistrike_proc", chance = 0.20, multistrike_bonus = 0.35 }
    }
} )

-- ============================================================================
-- PVP SETS AND GEAR
-- ============================================================================

-- Season 12: Malevolent Gladiator's Investiture
spec:RegisterGear( "pvp_s12", { 84406, 84407, 84408, 84409, 84410 }, {
    bonus = {
        { pieces = 2, effect = "pvp_s12_2pc", resilience_bonus = 400 },
        { pieces = 4, effect = "pvp_s12_4pc", shadow_damage_bonus = 0.10 }
    }
} )

-- Season 13: Tyrannical Gladiator's Investiture  
spec:RegisterGear( "pvp_s13", { 91370, 91371, 91372, 91373, 91374 }, {
    bonus = {
        { pieces = 2, effect = "pvp_s13_2pc", resilience_bonus = 450 },
        { pieces = 4, effect = "pvp_s13_4pc", mind_blast_damage_bonus = 0.15 }
    }
} )

-- Season 14: Grievous Gladiator's Investiture
spec:RegisterGear( "pvp_s14", { 100163, 100164, 100165, 100166, 100167 }, {
    bonus = {
        { pieces = 2, effect = "pvp_s14_2pc", resilience_bonus = 500 },
        { pieces = 4, effect = "pvp_s14_4pc", devouring_plague_bonus = 0.20 }
    }
} )

-- ============================================================================
-- CHALLENGE MODE AND SPECIAL SETS
-- ============================================================================

-- Challenge Mode Sets (Unique appearances with scaling bonuses)
spec:RegisterGear( "challenge_mode", { 90497, 90498, 90499, 90500, 90501 }, {
    bonus = {
        { effect = "challenge_mode_scaling", stat_scaling = 1.0 },
        { effect = "challenge_mode_appearance", unique_appearance = true }
    }
} )

-- Meta Gems optimized for Shadow Priests
spec:RegisterGear( "meta_gems", {
    [68780] = { name = "Burning Primal Diamond", effect = "spell_damage_and_crit" },
    [68778] = { name = "Destructive Primal Diamond", effect = "spell_crit_and_spell_reflect" },    [68779] = { name = "Effulgent Primal Diamond", effect = "spell_damage_and_mana_cost" },
    [76884] = { name = "Sinister Primal Diamond", effect = "shadow_damage_and_crit" },
} )

spec:RegisterGear( 15, 8, { -- Tier 16 (Siege of Orgrimmar)
    { 99593, head = 99593, shoulder = 99596, chest = 99594, hands = 99595, legs = 99597 }, -- LFR
    { 98278, head = 98278, shoulder = 98281, chest = 98279, hands = 98280, legs = 98282 }, -- Normal
    { 99138, head = 99138, shoulder = 99141, chest = 99139, hands = 99140, legs = 99142 }, -- Heroic
    { 99828, head = 99828, shoulder = 99831, chest = 99829, hands = 99830, legs = 99832 }, -- Mythic
} )

spec:RegisterAura( "tier16_2pc_shadow", {
    id = 144912,
    duration = 20,
    max_stack = 1,
} )

spec:RegisterAura( "tier16_4pc_shadow", {
    id = 144915,
    duration = 8,
    max_stack = 3,
} )

-- Legendary and Notable Items
spec:RegisterGear( "legendary_cloak", 102246, { -- Jina-Kang, Kindness of Chi-Ji
    back = 102246,
} )

spec:RegisterAura( "legendary_cloak_proc", {
    id = 148009,
    duration = 4,
    max_stack = 1,
} )

spec:RegisterGear( "kardris_toxic_totem", 104769, {
    trinket1 = 104769,
    trinket2 = 104769,
} )

spec:RegisterGear( "purified_bindings_of_immerseus", 104770, {
    trinket1 = 104770,
    trinket2 = 104770,
} )

spec:RegisterGear( "black_blood_of_yshaarj", 104810, {
    trinket1 = 104810,
    trinket2 = 104810,
} )

-- Comprehensive Talent System (MoP Talent Trees + Mastery Talents)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Crowd Control
    void_tendrils             = { 2295, 1, 108920 }, -- Shadowy tendrils immobilize all enemies within 8 yards for 8 sec, but can be broken by damage.
    psyfiend                  = { 2296, 1, 108921 }, -- Summons a Psyfiend with 20% of your health that attacks your target for 12 sec. Each time it attacks, it inflicts Fear for 4 sec.
    dominate_mind             = { 2297, 1, 108968 }, -- Controls an enemy mind up to level 90 for 8 sec while channeling. Generates no threat.

    -- Tier 2 (Level 30) - Movement Enhancement
    body_and_soul             = { 2298, 1, 64129  }, -- When you cast Power Word: Shield or Leap of Faith, you increase the target's movement speed by 60% for 4 sec.
    angelic_feather           = { 2299, 1, 121536 }, -- Places a feather at the target location that grants the first ally to walk through it 80% movement speed for 6 sec. Maximum of 3 charges.
    phantasm                  = { 2300, 1, 108942 }, -- When you receive a fear effect, you activate Fade and remove all harmful magic effects. This effect can only occur once every 30 sec.

    -- Tier 3 (Level 45) - Mana and Healing
    from_darkness_comes_light = { 2301, 1, 109186 }, -- When you deal damage with Mind Flay, Mind Blast, or Shadow Word: Death, there is a 15% chance your next Flash Heal will not trigger a global cooldown and will cast 50% faster.
    mindbender                = { 2302, 1, 123040 }, -- Replaces your Shadowfiend. The Mindbender's attacks restore 0.75% mana and have a 100% chance to trigger Replenishment.
    archangel                 = { 2303, 1, 81700  }, -- Consumes your Dark Evangelism effects to instantly restore 1% mana per stack consumed and increase your healing done by 5% per stack for 18 sec.

    -- Tier 4 (Level 60) - Survivability
    desperate_prayer          = { 2304, 1, 19236  }, -- Instantly heals the caster for 30% of their maximum health. 90 sec cooldown.
    spectral_guise            = { 2305, 1, 112833 }, -- You become translucent for 6 sec, threat is ignored for 2 sec, and each time you take damage the duration is reduced by 1 sec.
    angelic_bulwark           = { 2306, 1, 108945 }, -- When an attack brings you below 30% health, you gain an absorption shield equal to 20% of your maximum health for 20 sec.

    -- Tier 5 (Level 75) - DPS Enhancement
    twist_of_fate             = { 2307, 1, 109142 }, -- Your damage and healing is increased by 20% on targets below 35% health.
    power_infusion            = { 2308, 1, 10060  }, -- Infuses the target with power for 15 sec, increasing spell casting speed by 40% and reducing the mana cost of all spells by 25%.
    divine_insight            = { 2309, 1, 109175 }, -- Your Shadow Word: Pain periodic damage has a 40% chance to reset the cooldown on Mind Blast and cause your next Mind Blast within 8 sec to not trigger a global cooldown.

    -- Tier 6 (Level 90) - Ultimate Abilities
    cascade                   = { 2310, 1, 121135 }, -- Fire a shadowy bolt that jumps to the nearest enemy within 15 yards, preferring targets with no DoTs. Jumps up to 4 times and deals increasing damage.
    divine_star               = { 2311, 1, 110744 }, -- A star travels 24 yards forward, then returns to you, dealing Shadow damage to enemies and healing allies in its path.
    halo                      = { 2312, 1, 120517 }  -- Creates a ring of Shadow energy around you that grows outward to 30 yards, dealing damage to enemies and healing allies. Damage and healing increases with distance from the caster.
} )

-- Enhanced Glyphs System for Shadow Priest
spec:RegisterGlyphs( {
    -- Major Glyphs (affecting DPS and mechanics)
    [55687] = "Glyph of Dispersion",          -- Reduces the cooldown on Dispersion by 60 sec, but reduces the healing you receive while in Dispersion by 50%.
    [55680] = "Glyph of Dispel Magic",        -- Your Dispel Magic can be cast on hostile targets and will now always hit, but costs 8% more mana.
    [42408] = "Glyph of Fade",                -- Reduces the cooldown of your Fade spell by 9 sec.
    [55684] = "Glyph of Fortitude",           -- Your Power Word: Fortitude spell is now also cast on you when cast on a party or raid member.
    [55675] = "Glyph of Holy Nova",           -- Increases the radius of your Holy Nova spell by 5 yards, but increases its cooldown by 2 sec.
    [55678] = "Glyph of Inner Fire",          -- Increases the spell power gained from your Inner Fire spell by an additional 264.
    [42414] = "Glyph of Levitate",            -- Your Levitate spell no longer requires a reagent.
    [55682] = "Glyph of Mass Dispel",         -- Reduces the cast time of Mass Dispel by 1 sec.
    [42415] = "Glyph of Mind Control",        -- Increases the duration of your Mind Control spell by 8 sec.
    [55688] = "Glyph of Mind Flay",           -- Increases the damage done by your Mind Flay spell by 20% when your target is afflicted with Shadow Word: Pain.
    [55679] = "Glyph of Mind Spike",          -- Your Mind Spike also increases spell power by 30% for your next Mind Blast.
    [55689] = "Glyph of Psychic Horror",      -- Your Psychic Horror spell no longer causes enemies to flee, but now reduces their movement speed by 70%.
    [55681] = "Glyph of Psychic Scream",      -- Targets of your Psychic Scream spell now flee 8 yards further.
    [42413] = "Glyph of Shadow Word: Death",  -- Shadow Word: Death can now be used on targets at or below 25% health.
    [55676] = "Glyph of Shadow Word: Pain",   -- Your Shadow Word: Pain spell is instantly applied to all targets within 10 yards of your target.
    [42416] = "Glyph of Spirit of Redemption", -- When you enter Spirit of Redemption, you gain 100% spell haste for the duration.
    [55690] = "Glyph of Vampiric Embrace",    -- Your Vampiric Embrace also affects 2 additional nearby party members.
    [55691] = "Glyph of Prayer of Mending",   -- Your Prayer of Mending spell bounces 2 additional times.
    [55692] = "Glyph of Renew",               -- Your Renew spell heals for 25% more when cast on yourself.
    [55693] = "Glyph of Smite",               -- Your Smite spell reduces the target's movement speed by 50% for 5 sec.
    [55694] = "Glyph of Inner Sanctum",       -- Increases the movement speed bonus of your Inner Will by an additional 10%.
    [55695] = "Glyph of Lightwell",           -- Your Lightwell gains 5 additional charges.
    [55696] = "Glyph of Circle of Healing",   -- Your Circle of Healing spell heals 1 additional target.
    [55697] = "Glyph of Guardian Spirit",     -- When Guardian Spirit expires or is cancelled, 50% of the health lost while Guardian Spirit was active is restored.
    [55698] = "Glyph of Prayer of Healing",   -- Your Prayer of Healing spell also heals an additional 20% over 6 sec.
    [55699] = "Glyph of Scourge Imprisonment", -- Your Shackle Undead spell has 100% chance to break early when the target takes damage.
    [55700] = "Glyph of Shadow",              -- While in Shadowform, your non-damaging spells cost 10% less mana.
    [55701] = "Glyph of Mind Blast",          -- Your Mind Blast spell also slows the target's movement speed by 50% for 4 sec.
    [55702] = "Glyph of Devouring Plague",    -- Your Devouring Plague instantly deals damage equal to 1 tick when applied.
    [55703] = "Glyph of Vampiric Touch",      -- Your Vampiric Touch spell also silences the target for 3 sec when applied.
    
    -- Minor Glyphs (convenience and visual)
    [57985] = "Glyph of Shadowfiend",         -- Your Shadowfiend appears as a Shadow Orb.
    [57986] = "Glyph of Shackle Undead",      -- Your Shackle Undead spell glows with a different color.
    [57987] = "Glyph of Fading",              -- Your character becomes more transparent when using Fade.
    [57988] = "Glyph of Fortitude",           -- Your Power Word: Fortitude creates a visual shield effect.
    [57989] = "Glyph of Shadow Protection",   -- Your Shadow Protection creates a dark aura around the target.
    [57990] = "Glyph of Shadowform",          -- Your Shadowform appearance is even more dramatic.
    [57991] = "Glyph of the Heavens",         -- Your appearance when casting spells creates sparkles.
    [57992] = "Glyph of Angels",              -- Your Guardian Spirit appears as a different type of angel.
    [57993] = "Glyph of the Val'kyr",         -- Your Spirit of Redemption takes on a Val'kyr appearance.
} )

-- Advanced Aura System for Shadow Priest
spec:RegisterAuras( {
    -- Primary Shadow Orb System with Advanced Tracking
    shadow_orb = {
        id = 77487,
        duration = 3600,
        max_stack = 3,
        generate = function( aura )
            local applied = action.mind_blast.lastCast or 0
            local count = 0
            
            -- Advanced Shadow Orb generation tracking
            if query_time - applied < 3600 then
                -- Calculate orbs based on Mind Blast, Mind Flay, and SW:D usage
                count = min( 3, floor( ( query_time - applied ) / 8 ) ) -- Base from Mind Blast cooldown
                
                -- Add orbs from Mind Flay channels
                if buff.mind_flay.up then
                    count = min( 3, count + floor( buff.mind_flay.remains / 1 ) )
                end
                
                -- Factor in Shadow Word: Death usage
                if action.shadow_word_death.lastCast and query_time - action.shadow_word_death.lastCast < 8 then
                    count = min( 3, count + 1 )
                end
            end
            
            aura.count = count
            aura.applied = applied
            aura.expires = applied + 3600
            aura.caster = "player"
        end,
    },
    
    -- Enhanced Shadowform with Combat State Tracking
    shadowform = {
        id = 15473,
        duration = 3600,
        max_stack = 1,
        generate = function( aura )
            local applied = action.shadowform.lastCast or 0
            
            if query_time - applied < 3600 then
                aura.count = 1
                aura.applied = applied
                aura.expires = applied + 3600
                aura.caster = "player"
            else
                aura.count = 0
                aura.applied = 0
                aura.expires = 0
                aura.caster = "nobody"
            end
        end,
    },
    
    -- Shadow Word: Pain with Pandemic and DoT Optimization
    shadow_word_pain = {
        id = 589,
        duration = function() return 18 + ( glyph.shadow_word_pain.enabled and 6 or 0 ) end,
        tick_time = 3,
        max_stack = 1,
        generate = function( aura )
            local applied = action.shadow_word_pain.lastCast or 0
            local duration = 18 + ( glyph.shadow_word_pain.enabled and 6 or 0 )
            
            if query_time - applied < duration then
                aura.count = 1
                aura.applied = applied
                aura.expires = applied + duration
                aura.caster = "player"
                
                -- Advanced pandemic timing
                aura.pandemic_threshold = aura.expires - ( duration * 0.3 )
                aura.optimal_refresh = aura.expires - 5.4 -- 30% of base duration
            else
                aura.count = 0
                aura.applied = 0
                aura.expires = 0
                aura.caster = "nobody"
            end
        end,
    },
    
    -- Vampiric Touch with Enhanced Mana Tracking
    vampiric_touch = {
        id = 34914,
        duration = function() return 15 + ( glyph.vampiric_touch.enabled and 3 or 0 ) end,
        tick_time = 3,
        max_stack = 1,
        generate = function( aura )
            local applied = action.vampiric_touch.lastCast or 0
            local duration = 15 + ( glyph.vampiric_touch.enabled and 3 or 0 )
            
            if query_time - applied < duration then
                aura.count = 1
                aura.applied = applied
                aura.expires = applied + duration
                aura.caster = "player"
                
                -- Mana regeneration tracking
                aura.mana_per_tick = mana.max * 0.02 -- 2% base mana per tick
                aura.total_mana_return = ( aura.expires - query_time ) / 3 * aura.mana_per_tick
            else
                aura.count = 0
                aura.applied = 0
                aura.expires = 0
                aura.caster = "nobody"
            end
        end,
    },
    
    -- Devouring Plague with Orb Consumption Optimization
    devouring_plague = {
        id = 2944,
        duration = function() return 24 + ( glyph.devouring_plague.enabled and 6 or 0 ) end,
        tick_time = 3,
        max_stack = 1,
        generate = function( aura )
            local applied = action.devouring_plague.lastCast or 0
            local duration = 24 + ( glyph.devouring_plague.enabled and 6 or 0 )
            
            if query_time - applied < duration then
                aura.count = 1
                aura.applied = applied
                aura.expires = applied + duration
                aura.caster = "player"
                
                -- Advanced damage per orb tracking
                aura.orbs_consumed = 3 -- Always consumes 3 orbs
                aura.damage_per_tick = spell_power * 0.4 * aura.orbs_consumed
                aura.total_damage = aura.damage_per_tick * ( duration / 3 )
            else
                aura.count = 0
                aura.applied = 0
                aura.expires = 0
                aura.caster = "nobody"
            end
        end,
    },
    
    -- Mind Flay with Enhanced Channel Optimization
    mind_flay = {
        id = 15407,
        duration = 3,
        tick_time = 1,
        max_stack = 1,
        generate = function( aura )
            local applied = action.mind_flay.lastCast or 0
            
            if query_time - applied < 3 and not action.mind_flay.interrupt then
                aura.count = 1
                aura.applied = applied
                aura.expires = applied + 3
                aura.caster = "player"
                
                -- Advanced channel tracking
                aura.ticks_remaining = max( 0, ceil( ( aura.expires - query_time ) / 1 ) )
                aura.orbs_generated = min( 3 - buff.shadow_orb.count, aura.ticks_remaining )
                
                -- Glyph enhancement
                if glyph.mind_flay.enabled and debuff.shadow_word_pain.up then
                    aura.damage_bonus = 1.2
                end
            else
                aura.count = 0
                aura.applied = 0
                aura.expires = 0
                aura.caster = "nobody"
            end
        end,
    },
    
    -- Dispersion with Advanced Mana Management
    dispersion = {
        id = 47585,
        duration = function() return 6 - ( glyph.dispersion.enabled and 0 or 0 ) end,
        max_stack = 1,
        generate = function( aura )
            local applied = action.dispersion.lastCast or 0
            local duration = 6
            
            if query_time - applied < duration then
                aura.count = 1
                aura.applied = applied
                aura.expires = applied + duration
                aura.caster = "player"
                
                -- Enhanced mana regeneration tracking
                aura.mana_per_second = mana.max * 0.15 -- 15% mana per second
                aura.total_mana_return = aura.mana_per_second * ( aura.expires - query_time )
                aura.damage_reduction = 0.6 -- 60% damage reduction
            else
                aura.count = 0
                aura.applied = 0
                aura.expires = 0
                aura.caster = "nobody"
            end
        end,
    },
    
    -- Vampiric Embrace with Group Healing Tracking
    vampiric_embrace = {
        id = 15286,
        duration = function() return 15 + ( glyph.vampiric_embrace.enabled and 5 or 0 ) end,
        max_stack = 1,
        generate = function( aura )
            local applied = action.vampiric_embrace.lastCast or 0
            local duration = 15 + ( glyph.vampiric_embrace.enabled and 5 or 0 )
            
            if query_time - applied < duration then
                aura.count = 1
                aura.applied = applied
                aura.expires = applied + duration
                aura.caster = "player"
                
                -- Group healing enhancement
                aura.healing_multiplier = glyph.vampiric_embrace.enabled and 1.5 or 1.0
                aura.affected_members = glyph.vampiric_embrace.enabled and 5 or 3
            else
                aura.count = 0
                aura.applied = 0
                aura.expires = 0
                aura.caster = "nobody"
            end
        end,
    },
    
    -- Inner Fire with Spell Power Optimization
    inner_fire = {
        id = 588,
        duration = 1800,
        max_stack = 1,
        generate = function( aura )
            local applied = action.inner_fire.lastCast or 0
            
            if query_time - applied < 1800 then
                aura.count = 1
                aura.applied = applied
                aura.expires = applied + 1800
                aura.caster = "player"
                
                -- Enhanced spell power tracking
                aura.spell_power_bonus = 531 + ( glyph.inner_fire.enabled and 264 or 0 )
                aura.armor_bonus = 100 -- Base armor increase
            else
                aura.count = 0
                aura.applied = 0
                aura.expires = 0
                aura.caster = "nobody"
            end
        end,
    },
    
    -- Power Word: Shield with Advanced Absorption
    power_word_shield = {
        id = 17,
        duration = 15,
        max_stack = 1,
        generate = function( aura )
            local applied = action.power_word_shield.lastCast or 0
            
            if query_time - applied < 15 then
                aura.count = 1
                aura.applied = applied
                aura.expires = applied + 15
                aura.caster = "player"
                
                -- Advanced absorption calculation
                aura.absorption_amount = spell_power * 1.2 + 2230 -- Base + SP scaling
                aura.movement_bonus = talent.body_and_soul.enabled and 0.6 or 0
            else
                aura.count = 0
                aura.applied = 0
                aura.expires = 0
                aura.caster = "nobody"
            end
        end,
    },
    
    -- Weakened Soul with Shield Management
    weakened_soul = {
        id = 6788,
        duration = 15,
        max_stack = 1,
        generate = function( aura )
            local applied = action.power_word_shield.lastCast or 0
            
            if query_time - applied < 15 then
                aura.count = 1
                aura.applied = applied
                aura.expires = applied + 15
                aura.caster = "player"
            else
                aura.count = 0
                aura.applied = 0
                aura.expires = 0
                aura.caster = "nobody"
            end
        end,
    },
    
    -- Surge of Darkness with Instant Cast Optimization
    surge_of_darkness = {
        id = 87160,
        duration = 10,
        max_stack = 3,
        generate = function( aura )
            local applied = action.mind_spike.lastCast or 0
            local stacks = 0
            
            -- Advanced proc tracking based on DoT damage
            if debuff.shadow_word_pain.up then
                local pain_ticks = floor( ( query_time - debuff.shadow_word_pain.applied ) / 3 )
                stacks = min( 3, pain_ticks * 0.15 ) -- 15% chance per tick
            end
            
            if debuff.vampiric_touch.up then
                local vt_ticks = floor( ( query_time - debuff.vampiric_touch.applied ) / 3 )
                stacks = min( 3, stacks + vt_ticks * 0.15 )
            end
            
            if stacks > 0 and query_time - applied < 10 then
                aura.count = stacks
                aura.applied = applied
                aura.expires = applied + 10
                aura.caster = "player"
            else
                aura.count = 0
                aura.applied = 0
                aura.expires = 0
                aura.caster = "nobody"
            end
        end,
    },
    
    -- Mind Melt with DoT Removal Tracking
    mind_melt = {
        id = 81292,
        duration = 10,
        max_stack = 3,
        generate = function( aura )
            local applied = action.mind_spike.lastCast or 0
            local stacks = 1
            
            if query_time - applied < 10 then
                -- Calculate stacks based on consecutive Mind Spike usage
                local consecutive_spikes = 1
                if action.mind_spike.lastCast and query_time - action.mind_spike.lastCast < 2.5 then
                    consecutive_spikes = min( 3, consecutive_spikes + 1 )
                end
                
                aura.count = consecutive_spikes
                aura.applied = applied
                aura.expires = applied + 10
                aura.caster = "player"
                
                -- Damage bonus tracking
                aura.damage_bonus = 1 + ( aura.count * 0.25 ) -- 25% per stack
            else
                aura.count = 0
                aura.applied = 0
                aura.expires = 0
                aura.caster = "nobody"
            end
        end,
    },
    
    -- Advanced Shadowfiend/Mindbender Tracking
    shadowfiend = {
        id = 34433,
        duration = function() return talent.mindbender.enabled and 15 or 12 end,
        max_stack = 1,
        generate = function( aura )
            local applied = action.shadowfiend.lastCast or 0
            local duration = talent.mindbender.enabled and 15 or 12
            
            if query_time - applied < duration then
                aura.count = 1
                aura.applied = applied
                aura.expires = applied + duration
                aura.caster = "player"
                
                -- Enhanced mana return tracking
                aura.attacks_per_second = 1.5
                aura.mana_per_attack = talent.mindbender.enabled and ( mana.max * 0.0075 ) or ( mana.max * 0.03 )
                aura.total_mana_return = aura.mana_per_attack * aura.attacks_per_second * ( aura.expires - query_time )
            else
                aura.count = 0
                aura.applied = 0
                aura.expires = 0
                aura.caster = "nobody"
            end
        end,
    },
    
    -- Dark Evangelism for Archangel Talent
    dark_evangelism = {
        id = 87118,
        duration = 20,
        max_stack = 5,
        generate = function( aura )
            local applied = action.mind_flay.lastCast or action.mind_blast.lastCast or action.shadow_word_pain.lastCast or 0
            local stacks = 0
            
            if talent.archangel.enabled and query_time - applied < 20 then
                -- Calculate stacks from damage spell usage
                stacks = min( 5, floor( ( query_time - applied ) / 4 ) )
                
                if stacks > 0 then
                    aura.count = stacks
                    aura.applied = applied
                    aura.expires = applied + 20
                    aura.caster = "player"
                    
                    -- Archangel benefit tracking
                    aura.mana_return = stacks * 0.01 -- 1% per stack
                    aura.healing_bonus = stacks * 0.05 -- 5% per stack
                else
                    aura.count = 0
                    aura.applied = 0
                    aura.expires = 0
                    aura.caster = "nobody"
                end
            end
        end,
    },
    
    -- Tier Set and Proc Auras
    tier14_2pc_shadow = {
        id = 123254,
        duration = 8,
        max_stack = 1,
    },
    
    tier14_4pc_shadow = {
        id = 123259,
        duration = 15,
        max_stack = 1,
    },
    
    tier15_2pc_shadow = {
        id = 138322,
        duration = 12,
        max_stack = 1,
    },
    
    tier15_4pc_shadow = {
        id = 138323,
        duration = 6,
        max_stack = 1,
    },
    
    tier16_2pc_shadow = {
        id = 144912,
        duration = 20,
        max_stack = 1,
    },
    
    tier16_4pc_shadow = {
        id = 144915,
        duration = 8,
        max_stack = 3,
    },
    
    -- Legendary and Special Proc Tracking
    legendary_cloak_proc = {
        id = 148009,
        duration = 4,
        max_stack = 1,
    },
    
    -- Enhanced Combat State Tracking
    twist_of_fate = {
        id = 123254,
        duration = 3600,
        max_stack = 1,
        generate = function( aura )
            if talent.twist_of_fate.enabled and target.health.pct < 35 then
                aura.count = 1
                aura.applied = query_time
                aura.expires = query_time + 3600
                aura.caster = "player"
                aura.damage_bonus = 1.2 -- 20% damage increase
            else
                aura.count = 0
                aura.applied = 0
                aura.expires = 0
                aura.caster = "nobody"
            end
        end,
    },
} )

-- Abilities
spec:RegisterAbilities( {
    -- Shadowform
    shadowform = {
        id = 15473,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        handler = function ()
            if buff.shadowform.up then
                removeBuff( "shadowform" )
            else
                applyBuff( "shadowform" )
            end
        end,
    },
    
    -- Shadow Word: Pain
    shadow_word_pain = {
        id = 589,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.22,
        spendType = "mana",
        
        handler = function ()
            applyDebuff( "target", "shadow_word_pain" )
        end,
    },
    
    -- Vampiric Touch
    vampiric_touch = {
        id = 34914,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.20,
        spendType = "mana",
        
        handler = function ()
            applyDebuff( "target", "vampiric_touch" )
        end,
    },
    
    -- Devouring Plague
    devouring_plague = {
        id = 2944,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 3,
        spendType = "shadow_orb",
        
        usable = function () return shadow_orb.count >= 3 end,
        
        handler = function ()
            applyDebuff( "target", "devouring_plague" )
            shadow_orb.count = 0
        end,
    },
    
    -- Mind Blast
    mind_blast = {
        id = 8092,
        cast = 1.5,
        cooldown = 8,
        gcd = "spell",
        
        spend = 0.17,
        spendType = "mana",
        
        handler = function ()
            if shadow_orb.count < 3 then
                shadow_orb.count = shadow_orb.count + 1
            end
        end,
    },
    
    -- Mind Flay
    mind_flay = {
        id = 15407,
        cast = 3,
        channeled = true,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.09,
        spendType = "mana",
        
        start = function ()
            applyDebuff( "target", "mind_flay" )
        end,
        
        tick = function ()
            if shadow_orb.count < 3 then
                shadow_orb.count = shadow_orb.count + 1
            end
        end,
    },
    
    -- Mind Spike
    mind_spike = {
        id = 73510,
        cast = function () return buff.surge_of_darkness.up and 0 or 1.5 end,
        cooldown = 0,
        gcd = "spell",
        
        spend = function () return buff.surge_of_darkness.up and 0 or 0.18 end,
        spendType = "mana",
        
        handler = function ()
            if buff.surge_of_darkness.up then
                removeBuff( "surge_of_darkness" )
            end
            
            if buff.mind_melt.up then
                applyBuff( "mind_melt", nil, min( 3, buff.mind_melt.stack + 1 ) )
            else
                applyBuff( "mind_melt" )
            end
            
            -- Remove DoTs
            removeDebuff( "target", "shadow_word_pain" )
            removeDebuff( "target", "vampiric_touch" )
        end,
    },
    
    -- Shadow Word: Death
    shadow_word_death = {
        id = 32379,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        spend = 0.12,
        spendType = "mana",
        
        handler = function ()
            if shadow_orb.count < 3 then
                shadow_orb.count = shadow_orb.count + 1
            end
        end,
    },
    
    -- Psychic Horror
    psychic_horror = {
        id = 64044,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        
        spend = 0.08,
        spendType = "mana",
    },
    
    -- Psychic Scream
    psychic_scream = {
        id = 8122,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0.15,
        spendType = "mana",
    },
    
    -- Dispersion
    dispersion = {
        id = 47585,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        handler = function ()
            applyBuff( "dispersion" )
        end,
    },
    
    -- Vampiric Embrace
    vampiric_embrace = {
        id = 15286,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        handler = function ()
            applyBuff( "vampiric_embrace" )
        end,
    },
    
    -- Power Word: Shield
    power_word_shield = {
        id = 17,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.23,
        spendType = "mana",
        
        handler = function ()
            applyBuff( "power_word_shield" )
            applyDebuff( "target", "weakened_soul" )
        end,
    },
    
    -- Inner Fire
    inner_fire = {
        id = 588,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.13,
        spendType = "mana",
        
        handler = function ()
            applyBuff( "inner_fire" )
        end,
    },
    
    -- Shadowfiend
    shadowfiend = {
        id = 34433,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
    },
    
    -- Fade
    fade = {
        id = 586,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
    },
} )

-- Register default pack for MoP Shadow Priest
spec:RegisterPack( "Shadow", 20250528, [[Hekili:T1PBVTTn04FlXjHj0Ofnr0i4Lvv9n0KxkzPORkyzyV1ikA2mzZ(fQ1Hm8kkjjjjlvQKKQKYfan1Y0YPpNvFupNLJLhum9DbDps9yVDJnLHrdlRJsrkzpNISnPnkTkUk(qNGYXnENRNpnS2)YBFm(nEF5(wB5OxZ)m45MyiytnisgMPzJfW2vZYwbpzw0aD6w)aW]] )

-- Register pack selector for Shadow
spec:RegisterPackSelector( "shadow", "Shadow", "|T136207:0|t Shadow",
    "Handles all aspects of Shadow Priest DPS with focus on DoT management and Shadow Orb generation.",
    nil )
