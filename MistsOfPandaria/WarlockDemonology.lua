-- WarlockDemonology.lua
-- Updated May 28, 2025 


-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'WARLOCK' then 
    return 
end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format
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

local spec = Hekili:NewSpecialization( 266, false ) -- Demonology spec ID for MoP

-- Local state tracking tables
local demonicFuryHistory = {}
local metamorphosisUptime = 0
local lastMetaToggle = 0
local wildImpCount = 0
local moltenCoreStacks = 0
local lastCombatLogUpdate = 0

-- Local functions for state management and tracking
local function ResetDemonicFuryHistory()
    demonicFuryHistory = {}
end

local function UpdateDemonicFuryHistory(amount, source)
    local timestamp = GetTime()
    table.insert(demonicFuryHistory, {
        time = timestamp,
        amount = amount,
        source = source,
        total = UnitPower("player", 11) -- Demonic Fury power type
    })
    
    -- Keep only last 10 seconds of history
    local cutoff = timestamp - 10
    for i = #demonicFuryHistory, 1, -1 do
        if demonicFuryHistory[i].time < cutoff then
            table.remove(demonicFuryHistory, i)
        end
    end
end

local function GetDemonicFuryIncomeRate()
    if #demonicFuryHistory < 2 then return 8.5 end -- Default regen rate
    
    local now = GetTime()
    local recent = {}
    
    -- Get fury gains from last 5 seconds
    for _, entry in ipairs(demonicFuryHistory) do
        if now - entry.time <= 5 and entry.amount > 0 then
            table.insert(recent, entry)
        end
    end
    
    if #recent < 2 then return 8.5 end
    
    local totalGain = 0
    local timeSpan = recent[#recent].time - recent[1].time
    
    for _, entry in ipairs(recent) do
        totalGain = totalGain + entry.amount
    end
    
    return timeSpan > 0 and (totalGain / timeSpan) or 8.5
end

local function UpdateMetamorphosisTracking(isActive)
    local now = GetTime()
    
    if isActive and lastMetaToggle > 0 then
        -- We're entering meta
        lastMetaToggle = now
    elseif not isActive and lastMetaToggle > 0 then
        -- We're leaving meta, update uptime
        metamorphosisUptime = metamorphosisUptime + (now - lastMetaToggle)
        lastMetaToggle = 0
    end
end

local function GetMetamorphosisUptimePercent()
    local combatTime = state.combat_time or 1
    if combatTime <= 0 then return 0 end
    
    local totalUptime = metamorphosisUptime
    if lastMetaToggle > 0 then
        -- Currently in meta, add current session
        totalUptime = totalUptime + (GetTime() - lastMetaToggle)
    end
    
    return (totalUptime / combatTime) * 100
end

local function UpdateWildImpTracking()
    -- Count active wild imps from combat log or pet tracking
    local count = 0
    
    -- This would need proper implementation based on MoP's wild imp mechanics
    -- For now, we'll track via buffs/state
    if state.buff and state.buff.wild_imps and state.buff.wild_imps.up then
        count = state.buff.wild_imps.stack or 0
    end
    
    wildImpCount = count
    return count
end

local function ShouldUseTrinket(slot)
    -- Advanced trinket usage logic
    local darkSoulUp = state.buff.dark_soul.up or state.buff.dark_soul_knowledge.up
    local metaReady = state.demonic_fury.current >= 750
    local heroUp = state.buff.bloodlust.up or state.buff.time_warp.up
    local executePhase = state.target.health.pct <= 25
    
    -- Perfect sync: Dark Soul + Meta ready
    if darkSoulUp and metaReady then return true end
    
    -- Hero timing
    if heroUp and state.demonic_fury.current >= 500 then return true end
    
    -- Execute phase
    if executePhase and state.demonic_fury.current >= 400 then return true end
    
    -- Don't waste on low fury
    if state.demonic_fury.current < 300 then return false end
    
    return false
end

local function CalculateHandOfGuldanValue(targets)
    targets = targets or state.active_enemies
    
    local furyGain = math.min(targets, 6) * 5 -- 5 fury per target, max 6 targets
    local impChance = targets >= 3 and 0.8 or 0.3 -- Higher imp chance with more targets
    local currentFury = state.demonic_fury.current
    
    -- Base value from damage
    local baseValue = targets * 15
    
    -- Fury value (higher when we need fury)
    local furyValue = 0
    if currentFury < 600 then
        furyValue = furyGain * 2 -- Double value when low on fury
    elseif currentFury < 800 then
        furyValue = furyGain
    end
    
    -- Imp generation value
    local impValue = impChance * 20
    
    return baseValue + furyValue + impValue
end

local function OptimalSoulFireTiming()
    local mcStacks = state.buff.molten_core.stack or 0
    local mcRemains = state.buff.molten_core.remains or 0
    local manaPercent = state.mana.pct or 0
    local inMeta = state.buff.metamorphosis.up
    
    -- Don't use in meta form
    if inMeta then return 0 end
    
    -- No stacks = no value
    if mcStacks == 0 then return 0 end
    
    -- High priority when about to expire
    if mcRemains <= 3 and mcStacks >= 1 then return 95 end
    
    -- Medium priority with multiple stacks
    if mcStacks >= 2 and manaPercent >= 30 then return 75 end
    
    -- Low priority with single stack and good mana
    if mcStacks >= 1 and manaPercent >= 50 then return 50 end
    
    -- Don't use with low mana unless critical
    if manaPercent < 25 and mcRemains > 5 then return 0 end
    
    return 25 -- Default low priority
end

local function ResetCombatTracking()
    -- Reset all tracking when combat ends
    ResetDemonicFuryHistory()
    metamorphosisUptime = 0
    lastMetaToggle = 0
    wildImpCount = 0
    moltenCoreStacks = 0
end

-- Combat state tracking
local function OnCombatStart()
    ResetCombatTracking()
end

local function OnCombatEnd()
    ResetCombatTracking()
end

-- Event registration for tracking
local trackingFrame = CreateFrame("Frame")
trackingFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Combat start
trackingFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Combat end
trackingFrame:RegisterEvent("UNIT_POWER_UPDATE")     -- Resource changes

trackingFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        OnCombatStart()
    elseif event == "PLAYER_REGEN_ENABLED" then
        OnCombatEnd()
    elseif event == "UNIT_POWER_UPDATE" then
        local unit, powerType = ...
        if unit == "player" and powerType == "DEMONIC_FURY" then
            -- Update fury tracking
            UpdateDemonicFuryHistory(0, "regen") -- This would need proper amount calculation
        end
    end
end)

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
spec:RegisterResource( 0 ) -- Mana = 0 in MoP

spec:RegisterResource( 11 ) -- DemonicFury = 11 in MoP

-- State Expressions for Demonology using local functions (High Priority - Load Early)
spec:RegisterStateExpr( "demonic_fury", function()
    return demonic_fury.current
end )

-- Meta auras for import compatibility
spec:RegisterStateExpr( "focus_deficit", function()
    return demonic_fury.max - demonic_fury.current
end )

spec:RegisterStateExpr( "current_focus", function()
    return demonic_fury.current
end )

spec:RegisterStateExpr( "focus_time_to_max", function()
    local deficit = demonic_fury.max - demonic_fury.current
    if deficit <= 0 then return 0 end
    -- Use tracked income rate instead of static value
    local incomeRate = GetDemonicFuryIncomeRate()
    return deficit / incomeRate
end )

spec:RegisterStateExpr( "mana_deficit", function()
    return mana.max - mana.current
end )

spec:RegisterStateExpr( "pet_alive", function()
    return pet.alive or false
end )

spec:RegisterStateExpr( "pet_exists", function()
    return pet.exists or false
end )

spec:RegisterStateExpr( "in_combat", function()
    return combat
end )

-- Advanced rotation logic state expressions using local functions
spec:RegisterStateExpr( "should_metamorphosis", function()
    -- Complex logic for when to enter Metamorphosis
    local min_fury = 400
    local optimal_fury = buff.dark_soul.up and 750 or 1000
    local target_time = target.time_to_die
    
    -- Don't enter if already in meta or not enough fury
    if buff.metamorphosis.up or demonic_fury.current < min_fury then
        return false
    end
    
    -- Priority 1: Dark Soul is up and we have enough fury
    if buff.dark_soul.up and demonic_fury.current >= 750 and target_time >= 30 then
        return true
    end
    
    -- Priority 2: No Dark Soul but high fury and long fight
    if not buff.dark_soul.up and demonic_fury.current >= optimal_fury and target_time >= 45 then
        return true
    end
    
    -- Priority 3: Burst phase (bloodlust/hero)
    if (buff.bloodlust.up or buff.time_warp.up) and demonic_fury.current >= 600 then
        return true
    end
    
    return false
end )

spec:RegisterStateExpr( "should_cancel_metamorphosis", function()
    -- Logic for when to cancel Metamorphosis early
    if not buff.metamorphosis.up then return false end
    
    -- Cancel if very low on fury and no Dark Soul
    if demonic_fury.current <= 200 and not buff.dark_soul.up then
        return true
    end
    
    -- Cancel if Dark Soul ended and we're below threshold
    if not buff.dark_soul.up and demonic_fury.current <= 400 and target.time_to_die <= 20 then
        return true
    end
    
    return false
end )

spec:RegisterStateExpr( "hand_of_guldan_targets", function()
    -- Calculate optimal number of targets for Hand of Gul'dan
    local base_targets = active_enemies >= 3 and 3 or 1
    local fury_consideration = demonic_fury.current < 200 and 2 or base_targets
    return math.min(fury_consideration, active_enemies)
end )

spec:RegisterStateExpr( "optimal_dark_soul_timing", function()
    -- Advanced timing for Dark Soul usage
    local cd_ready = cooldown.dark_soul.ready
    local has_meta_fury = demonic_fury.current >= 750
    local long_fight = target.time_to_die >= 60
    local hero_soon = cooldown.bloodlust.remains <= 15 or cooldown.time_warp.remains <= 15
    
    if not cd_ready then return false end
    
    -- Use immediately if we have meta fury and long fight
    if has_meta_fury and long_fight then return true end
    
    -- Use if hero is coming soon
    if hero_soon and demonic_fury.current >= 400 then return true end
    
    -- Use in execute phase
    if target.health.pct <= 25 and demonic_fury.current >= 500 then return true end
    
    return false
end )

spec:RegisterStateExpr( "molten_core_priority", function()
    -- Use local function for optimal timing
    return OptimalSoulFireTiming()
end )

spec:RegisterStateExpr( "demonic_fury_income_rate", function()
    -- Use tracked income rate
    return GetDemonicFuryIncomeRate()
end )

spec:RegisterStateExpr( "fury_time_to_threshold", function()
    -- Time to reach specific Demonic Fury thresholds
    local target_fury = 750 -- Metamorphosis threshold
    local current = demonic_fury.current
    local income = GetDemonicFuryIncomeRate()
    
    if current >= target_fury then return 0 end
    
    local deficit = target_fury - current
    return deficit / income
end )

spec:RegisterStateExpr( "aoe_hand_value", function()
    -- Use local function for calculation
    return CalculateHandOfGuldanValue(active_enemies)
end )

spec:RegisterStateExpr( "trinket_sync_window", function()
    -- Use local function for trinket logic
    if ShouldUseTrinket(1) then return 100 end
    
    local dark_soul_soon = cooldown.dark_soul.remains <= 5
    local meta_ready = demonic_fury.current >= 750
    local hero_up = buff.bloodlust.up or buff.time_warp.up
    
    if dark_soul_soon and meta_ready then return 80 end
    if hero_up and demonic_fury.current >= 500 then return 60 end
    
    return 0
end )

spec:RegisterStateExpr( "execute_phase_active", function()
    -- Determine if we're in execute phase
    local low_health = target.health.pct <= 25
    local burn_phase = target.time_to_die <= 45
    local hero_up = buff.bloodlust.up or buff.time_warp.up
    
    return low_health or burn_phase or hero_up
end )

spec:RegisterStateExpr( "metamorphosis_uptime_percent", function()
    -- Track metamorphosis uptime using local function
    return GetMetamorphosisUptimePercent()
end )

spec:RegisterStateExpr( "wild_imp_count", function()
    -- Get current wild imp count
    return UpdateWildImpTracking()
end )

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
        max_stack = 10,    },
      -- Metamorphosis and related
    dark_apotheosis = {
        id = 114168,        duration = 3600,
        max_stack = 1,
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
        duration = 6,        max_stack = 1,
    },
    
    -- Pet-related
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
    
    -- Missing auras for import compatibility
    bloodlust = {
        id = 2825, -- Bloodlust/Heroism
        duration = 40,
        max_stack = 1,
        copy = { 2825, 32182, 80353, 90355, 178207 }, -- Various bloodlust effects
    },
    
    time_warp = {
        id = 80353, -- Time Warp
        duration = 40,
        max_stack = 1,
        copy = { 80353 },
    },
    
    -- Focus-related meta auras for import compatibility (maps to demonic fury)
    focus = {
        duration = 3600,
        max_stack = 1,
        meta = {
            actual = function() return demonic_fury.current end,
            max = function() return demonic_fury.max end,
            deficit = function() return demonic_fury.max - demonic_fury.current end,
            pct = function() return demonic_fury.current / demonic_fury.max * 100 end,
            time_to_max = function() 
                local deficit = demonic_fury.max - demonic_fury.current
                if deficit <= 0 then return 0 end
                return deficit / 8.5 -- Demonic Fury regen rate
            end,
        }
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
    
    -- Missing abilities that were causing import errors
    dark_intent = {
        id = 109773,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = false,
        texture = 538993,
        
        handler = function()
            -- Apply Dark Intent buff to party member
        end,
    },
    
    summon_pet = {
        id = 30146, -- Felguard ID as default
        cast = 6,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136216,
        
        handler = function()
            -- Summon active pet
        end,
    },
    
    felstorm = {
        id = 89751,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        startsCombat = true,
        texture = 236305,
        
        usable = function()
            return pet.active and pet.felguard.alive, "requires active felguard"
        end,
        
        handler = function()
            -- Felguard's Felstorm ability
        end,
    },
    
    hand_of_gul_dan = {
        -- Alternative spelling for hand_of_guldan
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
            gain( 15, "demonic_fury" )
            if not buff.wild_imps.up then
                applyBuff( "wild_imps" )
                buff.wild_imps.stack = 1
            else
                addStack( "wild_imps", nil, 1 )
            end
        end,
    },

    -- Missing abilities for import compatibility
    imp_swarm = {
        id = 119915,  -- Imp Swarm spell ID
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = true,
        texture = 134413,
        
        usable = function()
            return buff.demonic_calling.up, "requires demonic calling"
        end,
        
        handler = function()
            removeBuff( "demonic_calling" )
            -- Summon multiple imps
            gain( 5, "wild_imps" )
        end,
    },

    life_tap = {
        id = 1454,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.15,
        spendType = "health",
        
        startsCombat = false,
        texture = 136126,
        
        handler = function()
            gain( 0.15, "mana" )
        end,
    },

    hellfire = {
        id = 1949,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        channeled = true,
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135818,
        
        handler = function()
            -- AoE damage channel
        end,
    },

    immolation_aura = {
        id = 104025,  -- Metamorphosis: Immolation Aura
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 60,
        spendType = "demonic_fury",
        
        startsCombat = true,
        texture = 135826,
        
        usable = function()
            return buff.metamorphosis.up, "requires metamorphosis"
        end,
        
        handler = function()
            -- AoE damage aura in meta form
        end,
    },

    felstorm = {
        id = 89751,  -- Felguard's Felstorm
        cast = 0,
        cooldown = 45,
        gcd = "off",
        
        startsCombat = true,
        texture = 136221,
        
        usable = function()
            return UnitExists("pet") and UnitCreatureFamily("pet") == "Felguard", "requires felguard pet"
        end,
        
        handler = function()
            -- Pet AoE whirlwind attack
        end,
    },

    command_demon = {
        id = 119898,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 136194,
        
        usable = function()
            return UnitExists("pet"), "requires active pet"
        end,
        
        handler = function()
            -- Commands current demon to use their special ability
        end,
    },
} )

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

-- Settings for Demonology Warlock
spec:RegisterSetting( "dark_soul_usage", "cooldowns", {
    name = strformat( "%s Usage Toggle", Hekili:GetSpellLinkWithTexture( 113858 ) ), -- Dark Soul
    desc = strformat( "Dark Soul will only be recommended when the selected toggle is active." ),
    type = "select",
    width = 2,
    values = function ()
        local toggles = {
            none       = "Do Not Override",
            default    = "Default",
            cooldowns  = "Cooldowns",
            essences   = "Minor CDs",
            defensives = "Defensives",
            interrupts = "Interrupts",
            potions    = "Potions",
            custom1    = spec.custom1Name or "Custom 1",
            custom2    = spec.custom2Name or "Custom 2",
        }
        return toggles
    end
} )

spec:RegisterSetting( "auto_metamorphosis", true, {
    name = strformat( "Auto %s Management", Hekili:GetSpellLinkWithTexture( 103958 ) ), -- Metamorphosis
    desc = strformat( "If checked, %s will be automatically recommended when conditions are optimal.", Hekili:GetSpellLinkWithTexture( 103958 ) ),
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "grimoire_type", "none", {
    name = strformat( "Grimoire Preference" ),
    desc = strformat( "Select your preferred Grimoire talent for rotation optimization." ),
    type = "select",
    width = 2,
    values = function ()
        local grimoires = {
            none = "No Override",
            supremacy = "Grimoire of Supremacy",
            service = "Grimoire of Service",
            sacrifice = "Grimoire of Sacrifice",
        }
        return grimoires
    end
} )

spec:RegisterPack( "Demonology", 20250712, [[ Hekili:fNv4oUnUr4NLfhG3E42Z12zT3K0vlqBVw0S4AqrDo0FuCsIwI2MyLeDLO2ngiqp7DgsjrkzsjTibibijwud)4Wz(MHdh5V0)t(BJjcQ)hxTy16f3TC18vWFw)g)TIZNO(BprIEICa(rgjf(3FHMYZ4j8dNf0cb(6ZjCsmctbVmpceXF7UswI4dz(7SG9YBxSeK9encgEZg)ThzXXuLS0Ii)TF6iROke)lPkSE1Rc57HNJemEwvycRqaVEppVk8FqFILWM7VvoOunebPubb(5hL7oAgzxcn2)V4VnkNjO5mI)2CAkHLbGCFvOGf9uGGH7o1kaAcNN6lafebOzqbVm6yaFFq0rcVWeyqY34CPI5I5iEZX1HLDOkCwv4UY97NhtYFkaSAjW7FjtoEmAEzrb7lZpdkNxv4DRxiFZjQy(lSK4aw6P5Ok9myvG3REBeNNGGmVRsoVDFIsQ3krKSiAI0oLYZpDKxWkWDXTU3fxOy3UWaW(ijWzSNuMiS5hATO5SSNOILMlu7orBDmDwRBiITZTXnzvT7zNlpPx8tC5)pOVBGPVJMxqZrh6WgUHGiHZJLwueI1oH4kGJssOzI5K8OJmWrarkbptZoqr)486jvf(LVuZS64oG1SlhXokTw5hQcxU2iwOr3rLCJtLurjdOz0ugfrbOiB0OKxMfO(DagPQIxduUscNIyF3W2W(7PPHDt2aa)3oKb(RAjq0FhIEk)zKqae(6fkOEeds)EiWBFICMMzqWCP50iE6oI1ygm5yo7KcJ)djpHh907Rc15J75XyzcGX0gDaPpcuj0H1)qjjpwlFrzkasaiYWj1gKNxZqpKdmlwoftbvqGxVNPzO6L0QyTrb9cr7QcBmLqto7BmrsvJz0W0l36Vh(rHGNN2dA35r6M(d52MJmpL85QWFgZjQxSJKSyC7DOm56yYijAsjzK5NIeYCCMOKW2tdeKt2m(TzZ555L1mdths(b4mJYmgG6vE45LrLfYmbwp9t(M(rXQmUrNJsqTabSaTPdMUYDgiDImy)MXZ5IJfkd4feKJ0KK9abz4KoUxQPUomG6NqKb2KYCYW5Hgv)TCgoYvGIFSVZCNs6Rq)F3uzXJCg(hxUWm4P4ibo9iyhprCrWwH1uw2mCtm)qDkjSUjvYQ(fJnwOS7qT2JbBMz3t(mRsINMIbXsZ2Wz)gPEsJi0bdDGtaEgSmqsJO4U8ADvJDP74oXUpA8ahZQsSXCRcF7G8d3bkJwokGn9Z0OsbvN7PxjMosXUz4uSUJOMukw3XokBpyyPzbG7K2yZUy8EvR26Aa7CqtCVkYAkXOEiLC4Ou3HDw0nagx60QjgTdd8cjpdkRPaVTg48GRKWZf13i766sUUgpN5)vcOdPfl4OtMuk4PWfcHba(au4zX8Qh)vwg8QLqTm)wwr5jejuaLIaWH5aUUvUvoLRlvtpJ34Cg2UfKEE36CExmbPryppjH)I8cEyMyGa8cnhgVSaNmdMOafRbfSasK9iAKlJlTGLzDKoogfgUfnzhPG((QhLbbTrUWZpAXfuF3RxNlyTBxqZYPToVZPWT13(D3YGp3njQDRvBD3Vo71auwDb4tH5QR)EkSpRNGQN4MP5fTAiGAM)wzcU485Pyi6LpFkXWnjVNILtFk81tG03uN2umT9QctpL7EfW)2xp8UJcDKuB5c3SqDg)VlrUtjsT4BwiA)cmNc9Cao9ahYywez3j8x5zptvIFn2EVg8N7Sevy3l4sqDlWFy5N)XV5bd9ihJfp4G9nq0GRiF3bfxg57oAOTqNjfj4k2za2Kf8hiF)35iTXoJuoMUQrvSiEfKt589SeQQ78PSIcP(wVfRJrpqZGIpJanq1GwiymSk8dc1KKN0MsZIXDL4ibgMcXaNrSzCOW1ZO6hLugJDFGYGTrEJA)F)TckIenT43Vb23hzrhnLMKDwVQ1we6NpLWIyIenUMgOMf9pvfc6E9Y8jfeGl83rqJnhALXk)cljXyhvdPOruP1qouwz6oQkHvcxaE8pK2Wjw31LIzUGAWlfh55(B)vE0tW6tXoHPS8(B)HQqBn)R6XFaEZ)QPqMQhvOwmVT2MFY7pAuwIDb0fICtt)c9Ask5ygzKtfh5IGcbbm6wLXAbl3W27nLwcyhsvJbhyx2uBmAv(fvXWTsdYarvbWLKsVb7GRxZNsa1j3F(H7xBIGsdWzC5vPnet)vcgx02VgWOI2ook5vt5Bd8LVyTvzZM23e4HLD279AgUYic1oIAdoUUbIp4Tz0jwFDX2n9fTZBCaKMHrNC7ftUr1uEVLnmKTWtyATpj7Wzv4hHtujqS9Fh(FnjRWiePTUbtpWejYsCUOwIEVVtzd4ImTceEy5IlaQ5CEeLgUSURV92E6JMKlQZ(rnZrVO6HxhbSYRNz2WJhE7I(6FVkd6eJAV7spy2zPoWFF)ok9ZB6VCnvvGRtthJU)2(s1EEVM12PZqZC1viJKiomqDmhEyVFEvRTSdpUDQUy8)tqnUKVldmX8naBFu2tJWDDk2KWwFxKB9EFP8zw(k5D9NE3TEXmlFzCVfZgHK4TWMMnO34EVBrNHYa(N5)TQW)nxiVvgu09MFcBXT8dK8JAKHKIdhRReWchVln4cERjJuHXOexLygPd68vD8wQorgF4kp5NkA2fU7zDZUBsMR3i1xQ1zY8zxnYhqPhG9U5RBCFDWAQNJOrDZp5TA9fMul64RtBgohWTlUyf72MFHV))p ]] )

-- Register ability aliases for import compatibility
do
    local aliases = {
        ["hand_of_gul'dan"] = "hand_of_guldan",
        ["hand_of_gul_dan"] = "hand_of_guldan", 
        ["felguard:felstorm"] = "felstorm",
        ["dark_soul"] = "dark_soul_knowledge",
        ["cancel_metamorphosis"] = "metamorphosis", -- Same spell, different usage
    }
    
    for alias, real in pairs(aliases) do
        if spec.abilities[real] then
            spec.abilities[alias] = spec.abilities[real]
        end
    end
end

-- Register aura aliases for import compatibility  
do
    local aura_aliases = {
        ["dark_soul"] = "dark_soul_knowledge",
        ["metamorphosis"] = "metamorphosis",
        ["molten_core"] = "molten_core", 
        ["demonic_calling"] = "demonic_calling",
        ["bloodlust"] = "bloodlust",
        ["time_warp"] = "time_warp",
    }
    
    for alias, real in pairs(aura_aliases) do
        if spec.auras[real] then
            spec.auras[alias] = spec.auras[real]
        end
    end
end
