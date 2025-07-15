-- RogueCombat.lua
-- July 2025
-- by Smufrik

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'ROGUE' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format

local spec = Hekili:NewSpecialization( 260, true ) -- Combat spec ID for Hekili (260 = Combat in MoP Classic)

-- Ensure state is properly initialized
if not state then 
    state = Hekili.State 
end

-- Register resources using MoP power types from Constants.lua
spec:RegisterResource( ns.GetResourceID( "energy" ) ) -- Energy 
spec:RegisterResource( ns.GetResourceID( "combo_points" ) ) -- Combo Points

-- Talents
spec:RegisterTalents( {
    -- Tier 1 (Level 15)
    nightstalker = { 1, 1, 14062 }, -- Increases damage done while stealthed.
    subterfuge = { 1, 2, 108208 }, -- Allows abilities to be used for 3 seconds after leaving stealth.
    shadow_focus = { 1, 3, 108209 }, -- Reduces energy cost of abilities while stealthed.
    
    -- Tier 2 (Level 30) 
    deadly_throw = { 2, 1, 48673 }, -- Throws a blade that damages and slows target movement.
    nerve_strike = { 2, 2, 108210 }, -- Reduces damage done by targets affected by Kidney Shot or Cheap Shot.
    combat_readiness = { 2, 3, 74001 }, -- Defensive cooldown that reduces damage taken with consecutive hits.
    
    -- Tier 3 (Level 45)
    cheat_death = { 3, 1, 31230 }, -- Prevents fatal damage and reduces damage taken afterward.
    leeching_poison = { 3, 2, 108211 }, -- Attacks heal you for a portion of damage done.
    elusiveness = { 3, 3, 79008 }, -- Reduces damage taken when Feint is active.
    
    -- Tier 4 (Level 60)
    preparation = { 4, 1, 14185 }, -- Resets the cooldown of several rogue abilities.
    shadowstep = { 4, 2, 36554 }, -- Teleport behind target and increases damage of next ability.
    burst_of_speed = { 4, 3, 108212 }, -- Increases movement speed and removes movement impairing effects.
    
    -- Tier 5 (Level 75)
    prey_on_the_weak = { 5, 1, 131223 }, -- Increases damage against targets affected by stuns.
    paralytic_poison = { 5, 2, 108215 }, -- Attacks have a chance to stun the target.
    dirty_tricks = { 5, 3, 108216 }, -- Reduces cost of Blind and Sap.
    
    -- Tier 6 (Level 90)
    shuriken_toss = { 6, 1, 114014 }, -- Ranged attack that generates combo points.
    marked_for_death = { 6, 2, 137619 }, -- Marks target and generates 5 combo points; resets on kill.
    anticipation = { 6, 3, 114015 }, -- Can store extra combo points beyond the normal limit.
} )

-- Auras
spec:RegisterAuras( {
    -- Core Combat Rogue buffs
    slice_and_dice = {
        id = 5171,
        duration = function() return 12 + (talent.improved_slice_and_dice.enabled and 6 or 0) end,
        max_stack = 1
    },
    adrenaline_rush = {
        id = 13750,
        duration = 15,
        max_stack = 1
    },
    killing_spree = {
        id = 51690,
        duration = 3,
        max_stack = 1
    },
    blade_flurry = {
        id = 13877,
        duration = 15,
        max_stack = 1
    },
    shadow_blades = {
        id = 121471,
        duration = 12,
        max_stack = 1
    },
    sprint = {
        id = 2983,
        duration = 8,
        max_stack = 1
    },
    evasion = {
        id = 5277,
        duration = 10,
        max_stack = 1
    },
    feint = {
        id = 1966,
        duration = 5,
        max_stack = 1
    },
    stealth = {
        id = 1784,
        duration = 3600,
        max_stack = 1
    },
    
    -- Combat Rogue debuffs
    revealing_strike = {
        id = 84617,
        duration = 24,
        max_stack = 1
    },
    rupture = {
        id = 1943,
        duration = function() return 16 + (2 * combo_points.current) end,
        tick_time = 2,
        max_stack = 1
    },
    garrote = {
        id = 703,
        duration = 18,
        tick_time = 3,
        max_stack = 1
    },
    crimson_tempest = {
        id = 121411,
        duration = function() return 6 + (2 * combo_points.current) end,
        tick_time = 2,
        max_stack = 1
    },
    gouge = {
        id = 1776,
        duration = 4,
        max_stack = 1
    },
    blind = {
        id = 2094,
        duration = 60,
        max_stack = 1
    },
    kidney_shot = {
        id = 408,
        duration = function() return 2 + combo_points.current end,
        max_stack = 1
    },
    cheap_shot = {
        id = 1833,
        duration = 4,
        max_stack = 1
    },
    sap = {
        id = 6770,
        duration = 60,
        max_stack = 1
    },
    
    -- MoP Tier Set Bonuses
    tier14_2pc = {
        id = 123122,
        duration = 15,
        max_stack = 1
    },
    tier15_2pc = {
        id = 138151,
        duration = 10,
        max_stack = 1
    },
    tier16_2pc = {
        id = 145210,
        duration = 15,
        max_stack = 1
    },
    
    -- MoP talents and abilities
    anticipation = {
        id = 115189,
        duration = 3600,
        max_stack = 5
    },
    deep_insight = {
        id = 84747,
        duration = 15,
        max_stack = 1
    },
    moderate_insight = {
        id = 84746,
        duration = 15,
        max_stack = 1
    },
    shallow_insight = {
        id = 84745,
        duration = 15,
        max_stack = 1
    },
    find_weakness = {
        id = 91021,
        duration = 10,
        max_stack = 1
    },
    subterfuge = {
        id = 115192,
        duration = 3,
        max_stack = 1
    },
    shadow_dance = {
        id = 51713,
        duration = 8,
        max_stack = 1
    },
    shuriken_toss = {
        id = 114014,
        duration = 8,
        max_stack = 1
    },
    burst_of_speed = {
        id = 108212,
        duration = 4,
        max_stack = 1
    },
    marked_for_death = {
        id = 137619,
        duration = 60,
        max_stack = 1
    },
    cloak_of_shadows = {
        id = 31224,
        duration = 5,
        max_stack = 1
    },
    combat_readiness = {
        id = 74001,
        duration = 20,
        max_stack = 5
    },
    combat_insight = {
        id = 74002,
        duration = 10,
        max_stack = 1
    },
    nerve_strike = {
        id = 108210,
        duration = 4,
        max_stack = 1
    },
    cheat_death = {
        id = 45181,
        duration = 3,
        max_stack = 1
    },
    leeching_poison = {
        id = 108211,
        duration = 3600,
        max_stack = 1
    },
    deadly_poison = {
        id = 2818,
        duration = 12,
        tick_time = 3,
        max_stack = 5
    },
    wound_poison = {
        id = 8680,
        duration = 12,
        max_stack = 5
    },
    crippling_poison = {
        id = 3409,
        duration = 12,
        max_stack = 1
    },
    paralytic_poison = {
        id = 113952,
        duration = 20,
        max_stack = 5
    },
    vendetta = {
        id = 79140,
        duration = 20,
        max_stack = 1
    },
    master_of_subtlety = {
        id = 31665,
        duration = 6,
        max_stack = 1
    },
    bandit_guile = {
        id = 84654,
        duration = 15,
        max_stack = 3
    },
    prey_on_the_weak = {
        id = 131231,
        duration = 8,
        max_stack = 1
    },
    
    -- Rogue generic abilities
    recuperate = {
        id = 73651,
        duration = function() return 6 + (6 * combo_points.current) end,
        tick_time = 3,
        max_stack = 1
    },
    vanish = {
        id = 1856,
        duration = 3,
        max_stack = 1
    },
    shroud_of_concealment = {
        id = 114018,
        duration = 15,
        max_stack = 1
    },
    smoke_bomb = {
        id = 76577,
        duration = 5,
        max_stack = 1
    },
    tricks_of_the_trade = {
        id = 57934,
        duration = 6,
        max_stack = 1
    },
    redirect = {
        id = 73981,
        duration = 60,
        max_stack = 1
    },
    kick = {
        id = 1766,
        duration = 5,
        max_stack = 1
    },
    
    -- Passive effects
    bandits_guile = {
        id = 84654,
        duration = 3600,
        max_stack = 1
    },
    combat_potency = {
        id = 35553,
        duration = 3600,
        max_stack = 1
    },
    restless_blades = {
        id = 79096,
        duration = 3600,
        max_stack = 1
    },
    lightning_reflexes = {
        id = 13750,
        duration = 3600,
        max_stack = 1
    },
    vitality = {
        id = 61329,
        duration = 3600,
        max_stack = 1
    }
} )


-- Mists of Pandaria
spec:RegisterGear( "tier14", 85299, 85300, 85301, 85302, 85303 ) -- Heroic Malevolent Gladiator's Leather Armor
spec:RegisterGear( "tier15", 95305, 95306, 95307, 95308, 95309 ) -- Battlegear of the Thousandfold Blades
spec:RegisterGear( "tier16", 99009, 99010, 99011, 99012, 99013 ) -- Battlegear of the Barbed Assassin

spec:RegisterAuras( {
    -- Tier 14 (2-piece) - Your Sinister Strike critical strikes have a 20% chance to generate an extra combo point.
    t14_2pc_combat = {
        id = 123122,
        duration = 15,
        max_stack = 1
    },
    
    -- Tier 15 (2-piece) - Adrenaline Rush also grants 40% increased critical strike chance.
    t15_2pc_crit_bonus = {
        id = 138150,
        duration = 15,
        max_stack = 1
    },
    
    -- Tier 16 (2-piece) - Increases the damage of your Sinister Strike, Revealing Strike, and Eviscerate by 10%.
    t16_2pc_damage_bonus = {
        id = 145183,
        duration = 3600,
        max_stack = 1
    },
    
    -- Tier 16 (4-piece) - When you activate Killing Spree, you gain 30% increased attack speed for 10 sec.
    t16_4pc_attack_speed = {
        id = 145210,
        duration = 10,
        max_stack = 1
    }
} )

spec:RegisterHook( "runHandler", function( action, pool )
    if buff.stealth.up and not (action == "stealth" or action == "garrote" or action == "ambush" or action == "cheap_shot") then 
        removeBuff("stealth") 
    end
    if buff.vanish.up and not (action == "vanish" or action == "garrote" or action == "ambush" or action == "cheap_shot") then 
        removeBuff("vanish") 
    end
end )

local function IsActiveSpell( id )
    local slot = FindSpellBookSlotBySpellID( id )
    if not slot then return false end

    local _, _, spellID = GetSpellBookItemName( slot, "spell" )
    return id == spellID
end

-- Set up the state reference correctly with multiple fallbacks
local function ensureState()
    if not state then 
        state = Hekili.State 
    end
    if not state and Hekili and Hekili.State then
        state = Hekili.State
    end
    if state and state.IsActiveSpell == nil then
        state.IsActiveSpell = IsActiveSpell
    end
end

-- Call it immediately and also register as a hook for safety
ensureState()

-- Also ensure state is available in a hook for delayed initialization
-- Combined reset_precast hook to avoid conflicts
spec:RegisterHook( "reset_precast", function()
    -- Ensure state is properly initialized first
    ensureState()
    
    -- Forced distance reset on Shadowstep
    if now - action.shadowstep.lastCast < 1.5 then
        setDistance(5)
    end

    -- Force sync Revealing Strike if there's a mismatch between game and Hekili state
    if UnitExists("target") then
        for i = 1, 40 do
            local name, _, _, _, _, expires, caster, _, _, spellID = UnitDebuff("target", i)
            if not name then break end
            if spellID == 84617 and caster == "player" then -- Revealing Strike
                local gameRemains = expires > 0 and (expires - GetTime()) or 0
                if gameRemains > 0 and (not debuff.revealing_strike.up or debuff.revealing_strike.remains <= 0) then
                    applyDebuff("target", "revealing_strike", gameRemains)
                end
                break
            end
        end
    end

    -- Force sync Rupture if there's a mismatch
    if UnitExists("target") then
        for i = 1, 40 do
            local name, _, _, _, _, expires, caster, _, _, spellID = UnitDebuff("target", i)
            if not name then break end
            if spellID == 1943 and caster == "player" then -- Rupture
                local gameRemains = expires > 0 and (expires - GetTime()) or 0
                if gameRemains > 0 and (not debuff.rupture.up or debuff.rupture.remains <= 0) then
                    applyDebuff("target", "rupture", gameRemains)
                end
                break
            end
        end
    end

    -- Auto-sync missing player buffs
    for i = 1, 40 do
        local name, _, _, _, _, expires, _, _, _, spellID = UnitBuff("player", i)
        if not name then break end
        
        -- Sync missing buffs based on spell IDs
        local gameRemains = expires > 0 and (expires - GetTime()) or 0
        if gameRemains > 0 then
            if spellID == 5171 and not buff.slice_and_dice.up then -- Slice and Dice
                applyBuff("slice_and_dice", gameRemains)
            elseif spellID == 13750 and not buff.adrenaline_rush.up then -- Adrenaline Rush
                applyBuff("adrenaline_rush", gameRemains)
            elseif spellID == 51690 and not buff.killing_spree.up then -- Killing Spree
                applyBuff("killing_spree", gameRemains)
            elseif spellID == 13877 and not buff.blade_flurry.up then -- Blade Flurry
                applyBuff("blade_flurry", gameRemains)
            elseif spellID == 121471 and not buff.shadow_blades.up then -- Shadow Blades
                applyBuff("shadow_blades", gameRemains)
            end
        end
    end

    -- MoP tier bonus handling
    if set_bonus.tier14_2pc > 0 then
        -- T14 2pc - Sinister Strike crits have 20% chance to generate an extra combo point
        if action.sinister_strike.lastCast > now - 5 and GetTime() % 1 < 0.2 then
            gain(1, "combo_points")
        end
    end
    
    if set_bonus.tier15_2pc > 0 and buff.adrenaline_rush.up then
        -- T15 2pc - Adrenaline Rush grants 40% increased critical strike chance
        applyBuff("t15_2pc_crit_bonus")
    end

    if set_bonus.tier16_2pc > 0 then
        -- T16 2pc - Increases the damage of your Sinister Strike, Revealing Strike, and Eviscerate by 10%
        applyBuff("t16_2pc_damage_bonus")
    end
    
    if set_bonus.tier16_4pc > 0 and action.killing_spree.lastCast > now - 1 then
        -- T16 4pc - When you activate Killing Spree, you gain 30% increased attack speed for 10 sec
        applyBuff("t16_4pc_attack_speed", 10)
    end
end )

-- MoP Talent Detection Hook
spec:RegisterHook( "PLAYER_TALENT_UPDATE", function()
    if not GetTalentInfo then return end
    
    local specGroup = GetActiveSpecGroup and GetActiveSpecGroup() or 1
    
    -- Debug output for talent detection
    -- if Hekili.ActiveDebug then
    --     print("=== MOP TALENT DETECTION DEBUG ===")
    --     for tier = 1, 6 do
    --         for column = 1, 3 do
    --             local id, name, icon, selected = GetTalentInfo(tier, column, specGroup)
    --             if selected then
    --                 print("SELECTED TALENT: Tier " .. tier .. ", Column " .. column .. " - " .. (name or "Unknown") .. " (ID: " .. (id or "nil") .. ")")
    --             end
    --         end
    --     end
    --     print("=== END TALENT DEBUG ===")
    -- end
end )

-- State Expressions for MoP Combat Rogue
spec:RegisterStateExpr("combo_points", function()
    if not UnitExists("player") then return 0 end
    return GetComboPoints("player", "target")
end)

spec:RegisterStateExpr("bandit_guile_stack", function()
    if buff.deep_insight.up then
        return 3
    elseif buff.moderate_insight.up then
        return 2
    elseif buff.shallow_insight.up then
        return 1
    else
        return 0
    end
end)

spec:RegisterStateExpr("in_combat", function()
    return UnitAffectingCombat and UnitAffectingCombat("player") or InCombatLockdown()
end)

spec:RegisterStateExpr("effective_combo_points", function()
    local cp = GetComboPoints("player", "target")
    -- Account for Anticipation talent
    if talent.anticipation.enabled and buff.anticipation.up then
        return cp + buff.anticipation.stack
    end
    return cp
end)

spec:RegisterStateExpr("energy_regen_combined", function()
    local regen = GetPowerRegen()
    -- Add energy regen from Adrenaline Rush
    if buff.adrenaline_rush.up then
        regen = regen * 2
    end
    return regen
end)

spec:RegisterStateExpr("energy_time_to_max", function()
    if energy_regen_combined == 0 then return 999 end
    return (UnitPowerMax("player", 3) - UnitPower("player", 3)) / energy_regen_combined
end)

-- Calculate cooldown reduction from Restless Blades for Combat Rogues
spec:RegisterStateFunction("restless_blades_cdr", function(cp_spent)
    if not talent.restless_blades.enabled then return 0 end
    return cp_spent * 2 -- 2 seconds per combo point in MoP
end)

-- Function to calculate duration of Slice and Dice based on combo points
spec:RegisterStateFunction("slice_and_dice_duration", function(cp)
    if not cp or cp == 0 then return 0 end
    -- Base duration: 12 seconds + 6 seconds per combo point
    local duration = 12 + (cp * 6)
    -- Add 6 seconds if the improved slice and dice talent is enabled
    if talent.improved_slice_and_dice and talent.improved_slice_and_dice.enabled then
        duration = duration + 6
    end
    return duration
end)

-- Helper function to calculate rupture duration based on combo points
spec:RegisterStateFunction("rupture_duration", function(cp)
    if not cp or cp == 0 then return 0 end
    -- Base duration is 8 seconds + 4 seconds per combo point
    return 8 + (cp * 4)
end)

-- Helper function to detect if we're stealthed or have stealth-like buffs
spec:RegisterStateExpr("is_stealthed", function()
    return buff.stealth.up or buff.vanish.up or buff.shadow_dance.up or buff.subterfuge.up
end)

-- Combat Rogue specific cooldown reduction tracking (for Killing Spree, Adrenaline Rush)
spec:RegisterStateFunction("update_rogue_cooldowns", function()
    -- Implementation depends on Hekili's internal handling of cooldown reduction
    -- This is a placeholder for now
end)

-- Abilities
spec:RegisterAbilities( {
    -- Basic Attacks
    
    -- A strike that deals Physical damage and awards 1 combo point.
    sinister_strike = {
        id = 1752,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 40,
        spendType = "energy",
        
        startsCombat = true,

        handler = function ()
            -- Generate combo points
            gain(1, "combo_points")
            
            -- MoP mechanics - chance for extra combo point
            if GetTime() % 1 < 0.2 then -- 20% chance
                gain(1, "combo_points")
            end
            
            -- Combat Potency for off-hand attacks (simulated)
            if GetTime() % 1 < 0.3 then -- 30% chance to simulate off-hand
                if GetTime() % 1 < 0.2 then -- 20% chance for Combat Potency
                    gain(15, "energy")
                end
            end
            
            -- Bandit's Guile tracking
            if buff.bandits_guile.stack < 12 then
                addStack("bandits_guile", nil, 1)
            else
                -- Cycle through Insight buffs
                if not buff.shallow_insight.up and not buff.moderate_insight.up and not buff.deep_insight.up then
                    applyBuff("shallow_insight")
                elseif buff.shallow_insight.up and buff.bandits_guile.stack >= 4 then
                    removeBuff("shallow_insight")
                    applyBuff("moderate_insight")
                elseif buff.moderate_insight.up and buff.bandits_guile.stack >= 8 then
                    removeBuff("moderate_insight")
                    applyBuff("deep_insight")
                end
            end
            
            -- Tier bonuses
            if set_bonus.tier14_2pc > 0 and GetTime() % 1 < 0.2 then
                applyBuff("t14_2pc_combat")
            end
        end,
    },
    
    -- A strike that deals Physical damage and increases the damage of your finishing moves against the target by 35% for 24 sec.
    revealing_strike = {
        id = 84617,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 40,
        spendType = "energy",
        
        startsCombat = true,

        handler = function ()
            applyDebuff("target", "revealing_strike")
            gain(1, "combo_points")
        end,
    },
    
    -- Finishing move that causes damage per combo point and consumes up to 5 combo points.
    eviscerate = {
        id = 2098,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 35,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function ()
            local cp = combo_points.current
            
            -- Apply Restless Blades cooldown reduction
            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("redirect", cdr)
            end
            
            -- Consume combo points
            spend(cp, "combo_points")
            
            -- Handle Anticipation talent
            if talent.anticipation.enabled and buff.anticipation.stack > 0 then
                gain(1, "combo_points")
                removeStack("anticipation")
            end
        end,
    },
    
    -- Finishing move that causes damage over time. Lasts longer per combo point.
    rupture = {
        id = 1943,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 25,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function ()
            local cp = combo_points.current
            
            -- Duration based on combo points (4 sec base + 4 sec per combo point)
            applyDebuff("target", "rupture", 4 + 4 * cp)
            
            -- Apply Restless Blades cooldown reduction
            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("redirect", cdr)
            end
            
            -- Consume combo points
            spend(cp, "combo_points")
            
            -- Handle Anticipation talent
            if talent.anticipation.enabled and buff.anticipation.stack > 0 then
                gain(1, "combo_points")
                removeStack("anticipation")
            end
        end,
    },
    
    -- Finishing move that increases attack speed by 40%. Lasts longer per combo point.
    slice_and_dice = {
        id = 5171,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 25,
        spendType = "energy",
        
        startsCombat = false,
        
        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function ()
            local cp = combo_points.current
            
            -- Duration: 12 sec + 6 sec per combo point
            applyBuff("slice_and_dice", 12 + 6 * cp)
            
            -- Apply Restless Blades cooldown reduction
            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("redirect", cdr)
            end
            
            -- Consume combo points
            spend(cp, "combo_points")
            
            -- Handle Anticipation talent
            if talent.anticipation.enabled and buff.anticipation.stack > 0 then
                gain(1, "combo_points")
                removeStack("anticipation")
            end
        end,
    },
    
    -- Major Cooldowns
    
    -- Increases energy regeneration rate by 100% for 15 sec.
    adrenaline_rush = {
        id = 13750,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",
        
        toggle = "cooldowns",
        startsCombat = false,

        handler = function ()
            applyBuff("adrenaline_rush")
            
            -- Tier 15 2pc - Adrenaline Rush also grants 40% increased critical strike chance
            if set_bonus.tier15_2pc > 0 then
                applyBuff("t15_2pc_crit_bonus")
            end
        end,
    },
    
    -- Increases your attack speed by 20% for 15 sec. While active, your successful attacks strike an additional nearby opponent.
    blade_flurry = {
        id = 13877,
        cast = 0,
        cooldown = 10,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,

        handler = function ()
            if buff.blade_flurry.up then
                removeBuff("blade_flurry")
            else
                applyBuff("blade_flurry")
            end
        end,
    },
    
    -- You attack with both weapons for a total of 7 attacks over 3 sec, while jumping from target to target. Can hit up to 5 enemies within 10 yards. The damage of each attack is based on the weapons you have equipped. Cannot be used with ranged weapons.
    killing_spree = {
        id = 51690,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        school = "physical",
        
        toggle = "cooldowns",
        startsCombat = true,

        handler = function ()
            applyBuff("killing_spree")
            
            -- Tier 16 4pc - When you activate Killing Spree, you gain 30% increased attack speed for 10 sec
            if set_bonus.tier16_4pc > 0 then
                applyBuff("t16_4pc_attack_speed", 10)
            end
        end,
    },
    
    -- For the next 12 sec, your successful melee attacks have a 100% chance to grant you an extra combo point.
    shadow_blades = {
        id = 121471,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "shadow",
        
        toggle = "cooldowns",
        startsCombat = false,

        handler = function ()
            applyBuff("shadow_blades")
        end,
    },
    
    -- Utility Abilities
    
    -- Redirect your combo points from your last target to your current target.
    redirect = {
        id = 73981,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,
        
        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function ()
            -- This is a placeholder since Hekili doesn't track combo points per target
        end,
    },
    
    -- Reduces all damage taken by 30% for 5 sec.
    feint = {
        id = 1966,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        school = "physical",

        spend = 20,
        spendType = "energy",
        
        startsCombat = false,

        handler = function ()
            applyBuff("feint")
            
            -- Elusiveness talent increases damage reduction
            if talent.elusiveness.enabled then
                applyBuff("elusiveness")
            end
        end,
    },
    
    -- Increases your movement speed by 70% for 8 sec. Usable while stealthed.
    sprint = {
        id = 2983,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,

        handler = function ()
            applyBuff("sprint")
        end,
    },
    
    -- Strikes the target, dealing Physical damage and interrupting spellcasting, preventing any spell in that school from being cast for 5 sec.
    kick = {
        id = 1766,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        school = "physical",
        
        toggle = "interrupts",
        startsCombat = true,

        handler = function ()
            interrupt()
        end,
    },
    
    -- Increases your dodge chance by 50% for 10 sec.
    evasion = {
        id = 5277,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",
        
        toggle = "defensives",
        startsCombat = false,

        handler = function ()
            applyBuff("evasion")
        end,
    },
    
    -- Allows the rogue to enter stealth mode. Lasts until cancelled.
    stealth = {
        id = 1784,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        usable = function() 
            return not buff.stealth.up and not buff.vanish.up and not buff.shadow_dance.up 
                and not buff.shadowmeld.up and not in_combat
        end,

        handler = function ()
            applyBuff("stealth")
            
            -- Apply Stealth-related buffs
            if talent.subterfuge.enabled then
                applyBuff("subterfuge")
            end
            
            if talent.shadow_focus.enabled then
                applyBuff("shadow_focus")
            end
        end,
    },
    
    -- Instantly enter stealth, but breaks when damaged. For 3 sec after you vanish, damage and harmful effects received will not break stealth.
    vanish = {
        id = 1856,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "physical",
        
        toggle = "cooldowns",
        startsCombat = false,

        handler = function ()
            applyBuff("vanish")
            applyBuff("stealth")
            
            -- Apply Stealth-related buffs
            if talent.subterfuge.enabled then
                applyBuff("subterfuge")
            end
            
            if talent.shadow_focus.enabled then
                applyBuff("shadow_focus")
            end
            
            -- Reset threat
            setCooldown("vanish", 120)
        end,
    },
    
    -- Strikes an enemy, dealing Physical damage and incapacitating the target for 4 sec. Must be facing the target. Any damage caused will revive the target. Awards 1 combo point.
    gouge = {
        id = 1776,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        school = "physical",

        spend = 45,
        spendType = "energy",
        
        startsCombat = true,

        handler = function ()
            applyDebuff("target", "gouge")
            gain(1, "combo_points")
        end,
    },
    
    -- Blinds the target, causing it to wander disoriented for 1 min. Any damage caused will remove the effect.
    blind = {
        id = 2094,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        school = "physical",

        spend = function() return talent.dirty_tricks.enabled and 0 or 15 end,
        spendType = "energy",
        
        toggle = "cooldowns",
        startsCombat = true,

        handler = function ()
            applyDebuff("target", "blind")
        end,
    },
    
    -- Finishing move that stuns the target. Lasts longer per combo point.
    kidney_shot = {
        id = 408,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        school = "physical",

        spend = 25,
        spendType = "energy",
        
        toggle = "cooldowns",
        startsCombat = true,
        
        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function ()
            local cp = combo_points.current
            applyDebuff("target", "kidney_shot", 2 + cp)
            
            -- Nerve Strike talent
            if talent.nerve_strike.enabled then
                applyDebuff("target", "nerve_strike")
            end
            
            -- Prey on the Weak talent
            if talent.prey_on_the_weak.enabled then
                applyDebuff("target", "prey_on_the_weak")
            end
            
            -- Apply Restless Blades cooldown reduction
            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("redirect", cdr)
            end
            
            -- Consume combo points
            spend(cp, "combo_points")
        end,
    },
    
    -- Creates a cloud of dense smoke in a 10-yard radius around the Rogue for 5 sec. Enemies are unable to target into or out of the smoke cloud.
    smoke_bomb = {
        id = 76577,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        school = "physical",
        
        toggle = "cooldowns",
        startsCombat = false,

        handler = function ()
            applyBuff("smoke_bomb")
        end,
    },
    
    -- Provides a moment of magic immunity, instantly removing all harmful spell effects. The cloak lingers, causing you to resist harmful spells for 5 sec.
    cloak_of_shadows = {
        id = 31224,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        school = "physical",
        
        toggle = "defensives",
        startsCombat = false,

        handler = function ()
            applyBuff("cloak_of_shadows")
            removeDebuff("target", "all")
        end,
    },
    
    -- Disarm the enemy's weapon for 10 sec.
    dismantle = {
        id = 51722,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "physical",
        
        toggle = "cooldowns",
        startsCombat = true,

        handler = function ()
            applyDebuff("target", "dismantle")
        end,
    },
    
    -- MoP-specific abilities
    
    -- Finishing move that deals damage over time to up to 8 nearby enemies. Deals more damage per combo point.
    crimson_tempest = {
        id = 121411,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 35,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function ()
            local cp = combo_points.current
            applyDebuff("target", "crimson_tempest", 6 + 2 * cp)
            
            -- Apply Restless Blades cooldown reduction
            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("redirect", cdr)
            end
            
            -- Consume combo points
            spend(cp, "combo_points")
            
            -- Handle Anticipation talent
            if talent.anticipation.enabled and buff.anticipation.stack > 0 then
                gain(1, "combo_points")
                removeStack("anticipation")
            end
        end,
    },
    
    -- Talent: Throw a deadly blade at the target, dealing Physical damage and generating 1 combo point. Can be used at range.
    shuriken_toss = {
        id = 114014,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        school = "physical",

        spend = 40,
        spendType = "energy",
        
        talent = "shuriken_toss",
        startsCombat = true,

        handler = function ()
            gain(1, "combo_points")
        end,
    },
    
    -- Talent: Marks the target, instantly generating 5 combo points. When the target dies, the cooldown is reset.
    marked_for_death = {
        id = 137619,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        school = "physical",
        
        talent = "marked_for_death",
        startsCombat = false,

        handler = function ()
            gain(5, "combo_points")
            applyDebuff("target", "marked_for_death", 60)
        end,
    },
    
    -- Talent: You gain 5 stacks of Anticipation, allowing combo points from your abilities to be stored beyond the normal maximum.
    anticipation = {
        id = 115189,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        school = "physical",
        
        talent = "anticipation",
        startsCombat = false,

        handler = function ()
            applyBuff("anticipation", nil, 5)
        end,
    },
    
    -- Ambushes the target, causing Physical damage. Must be stealthed. Awards 2 combo points.
    ambush = {
        id = 8676,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 60,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return is_stealthed, "requires stealth" end,

        handler = function ()
            gain(2, "combo_points")
            
            -- Subterfuge talent extends stealth after abilities
            if not talent.subterfuge.enabled then
                removeBuff("stealth")
                removeBuff("vanish")
            end
        end,
    },
    
    -- Garrote the enemy, causing Bleed damage over 18 sec. Awards 1 combo point.
    garrote = {
        id = 703,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 45,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return is_stealthed, "requires stealth" end,

        handler = function ()
            applyDebuff("target", "garrote")
            gain(1, "combo_points")
            
            -- Subterfuge talent extends stealth after abilities
            if not talent.subterfuge.enabled then
                removeBuff("stealth")
                removeBuff("vanish")
            end
        end,
    },
    
    -- Stuns the target for 4 sec. Must be stealthed. Awards 2 combo points.
    cheap_shot = {
        id = 1833,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 40,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return is_stealthed, "requires stealth" end,

        handler = function ()
            applyDebuff("target", "cheap_shot")
            gain(2, "combo_points")
            
            -- Nerve Strike talent
            if talent.nerve_strike.enabled then
                applyDebuff("target", "nerve_strike")
            end
            
            -- Prey on the Weak talent
            if talent.prey_on_the_weak.enabled then
                applyDebuff("target", "prey_on_the_weak")
            end
            
            -- Subterfuge talent extends stealth after abilities
            if not talent.subterfuge.enabled then
                removeBuff("stealth")
                removeBuff("vanish")
            end
        end,
    },
    
    -- Talent: Step through the shadows to appear behind your target and gain 70% increased movement speed for 2 sec.
    shadowstep = {
        id = 36554,
        cast = 0,
        cooldown = 20,
        gcd = "off",
        school = "physical",
        
        talent = "shadowstep",
        startsCombat = false,

        handler = function ()
            applyBuff("shadowstep")
            setDistance(5)
        end,
    },
    
    -- Talent: Removes all movement impairing effects and increases your movement speed by 70% for 4 sec.
    burst_of_speed = {
        id = 108212,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 50,
        spendType = "energy",
        
        talent = "burst_of_speed",
        startsCombat = false,

        handler = function ()
            applyBuff("burst_of_speed")
            removeDebuff("player", "movement")
        end,
    },
    
    -- Talent: You become shrouded in a veil of shadows for 3 min, reducing your threat in combat. Increases your movement speed by 70% and allows the use of stealth abilities for 3 sec.
    preparation = {
        id = 14185,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        school = "physical",
        
        talent = "preparation",
        toggle = "cooldowns",
        startsCombat = false,

        handler = function ()
            setCooldown("vanish", 0)
            setCooldown("sprint", 0)
            setCooldown("evasion", 0)
        end,
    },
    
    -- A useful ability for rogues to recharge health.
    recuperate = {
        id = 73651,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 30,
        spendType = "energy",
        
        startsCombat = false,
        
        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function ()
            local cp = combo_points.current
            applyBuff("recuperate", 6 + 6 * cp)
            
            -- Apply Restless Blades cooldown reduction
            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("redirect", cdr)
            end
            
            -- Consume combo points
            spend(cp, "combo_points")
        end,
    },
    
    -- Talent: When activated, will begin reducing damage taken by 10%. Each attack against you increases the damage reduction by an additional 10%. Lasts 20 sec or 5 attacks.
    combat_readiness = {
        id = 74001,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "physical",
        
        talent = "combat_readiness",
        toggle = "defensives",
        startsCombat = false,

        handler = function ()
            applyBuff("combat_readiness")
        end,
    },
    
    -- Stuns and blinds nearby targets for 8 sec. Also interrupts spellcasting and prevents any spell in that school from being cast for 3 sec.
    shroud_of_concealment = {
        id = 114018,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        school = "physical",
        
        toggle = "cooldowns",
        startsCombat = false,

        handler = function ()
            applyBuff("shroud_of_concealment")
        end,
    },
    
    -- Finishing move that heals you for a moderate amount every 3 sec. Lasts longer per combo point.
    deadly_throw = {
        id = 26679,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 35,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function ()
            local cp = combo_points.current
            applyDebuff("target", "deadly_throw")
            
            -- Apply Restless Blades cooldown reduction
            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("redirect", cdr)
            end
            
            -- Consume combo points
            spend(cp, "combo_points")
        end,
    },
    
    -- Talent: Transfers all threat to the targeted party or raid member, causing your threat to be equal to the target's threat. Lasts 6 sec.
    tricks_of_the_trade = {
        id = 57934,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,

        handler = function ()
            applyBuff("tricks_of_the_trade")
        end,
    },
    
    -- Immobilizes the target in place for 1 min and deals damage over time. Only affects Humanoids and Beasts. Only usable while stealthed.
    sap = {
        id = 6770,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = function() return talent.dirty_tricks.enabled and 0 or 35 end,
        spendType = "energy",
        
        startsCombat = false,
        
        usable = function() return is_stealthed, "requires stealth" end,

        handler = function ()
            applyDebuff("target", "sap")
        end,
    },
    
    -- Auto Attack - basic melee auto attacks
    auto_attack = {
        id = 6603,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        school = "physical",

        startsCombat = true,

        handler = function ()
            -- Enable auto attacks if not already active
        end,
    },
} )

spec:RegisterRanges( "shuriken_toss", "throw", "deadly_throw" )

spec:RegisterOptions( {
    enabled = true,

    aoe = 2,
    cycle = false,

    nameplates = true,
    nameplateRange = 8,
    rangeFilter = false,

    damage = true,
    damageExpiration = 8,

    potion = "virmen_bite_potion", -- MoP-era agility potion

    package = "Combat"
} )

spec:RegisterSetting( "use_killing_spree", true, {
    name = strformat( "Use %s", Hekili:GetSpellLinkWithTexture( 51690 ) ), -- Killing Spree
    desc = "If checked, Killing Spree will be recommended based on the Combat Rogue priority. If unchecked, it will not be recommended.",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "bandits_guile_threshold", 3, {
    name = strformat( "Bandit's Guile Threshold for Eviscerate" ),
    desc = "Minimum Bandit's Guile stack level before recommending Eviscerate (0 = None, 1 = Shallow, 2 = Moderate, 3 = Deep)",
    type = "range",
    min = 0,
    max = 3,
    step = 1,
    width = 1.5
} )

spec:RegisterSetting( "blade_flurry_toggle", "aoe", {
    name = strformat( "%s Toggle", Hekili:GetSpellLinkWithTexture( 13877 ) ), -- Blade Flurry
    desc = "Select when Blade Flurry should be recommended:",
    type = "select",
    values = {
        aoe = "Only in AoE",
        always = "Always",
        never = "Never"
    },
    width = 1.5
} )

spec:RegisterSetting( "anticipation_management", true, {
    name = strformat( "Manage %s", Hekili:GetSpellLinkWithTexture( 114015 ) ), -- Anticipation
    desc = "If checked, the addon will optimize combo point usage to avoid wasting combo points when using the Anticipation talent.",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "allow_shadowstep", true, {
    name = strformat( "Allow %s", Hekili:GetSpellLinkWithTexture( 36554 ) ), -- Shadowstep
    desc = "If checked, Shadowstep may be recommended for mobility and positioning. If unchecked, it will only be recommended for damage bonuses.",
    type = "toggle",
    width = "full"
} )

spec:RegisterPack( "Combat", 20250710, [[Hekili:nR1EVnoUr8plbhG3KRBDTLTZEPWYa9URh6f0EOO(6)kjAjABvll5ksLClGH(S3Hp0dsrkjVjO79h7IekodNh)48Gt8M79REBJquS3V4mZz1SpnF205p68KZtEBPF(c2B7fu4j0b4hsrNH))hYoVdrPycL9PpNKHIySGKvKhcF2B7UI4e6pN6TtLVZwmD(tlEC5CyVxWHWYpoZB7X4OiSyVysO32F9ymPmG9puzG8KldY2d)EinolTmijMqHpVplVm4VHpfNep1BlFrMySponMCe(PFHRy4u0UeCK33l4FE8fgt82(t8TvgKNrrIvGVrX5XiM8VF)ussCi2hLg5hb)W0C8zuCkCSRldwvgmPmiemdz(xYItzsZg3YahVTczeuqfQ9OGYQjnnhNkJCR4)DLb04WtXPh4)69Lb7YiWgUEvykEb7JtXNJXcIMxg8qfDCfyxckc7VpPip)ZtlUW)gfLFatNsJpJ9PzGSbM2naTo8VYjlcJV4dAA8HJuGSgvkV4cTiNRllUjDHjWMoyWs(Ofl5sbvwSm3lfvYruss2RTKwfdW5SiCoG)u((d9Y5(Ta4xIjHCwcgbkdqThvKqheR9paKJzKwewCIXWfIKeg1Gpnhq8kNl5y8l9dHKMxj7crekaBu4Xjak1VRJ5B4OHfZAiJMd0r8Z27tpcEUCasX4YsgxyNLViKqBSMc7R4tikneN4ZiP9zYvBFH0tuqSC4rlyPgAMjeR0uLMZc4P4x8zHfebhKsAyeHr7JwOnVivL0(G2kmwg3b49NUDERAh2Jszw8tPWD8MqlTolug3l8DFjgawW5ig1p9Lqna5XWndqUexbUKJd5Pdg8sW)k7qb(pxgiYEug8pROSkWozquhh)xTN)ddpqW5xWPuWRiVHwF49c1HieekgLaCpAkOUTUQjwUgJBKCt5hIYEnTNW)uHtBiJ0Fj7VAoqHLG6nNOYnWXeRqpuSiaOEILnkz1YXrXGBJ2V1vgfkh)cylH4q(eWFEsyImeVFn)MuZrOs1T7jEZzQ1JRyleGmr1GPvvdoltJ2yn0n5RzS1yAx9Gw3q8JLdA4viYuySblyPd2Xv5aa6ptGyku85lSAhneaR)GTgtd3jmMnEOQTew0AyFnOmQi3GHBOTIkLEctzLVMKrB)7k3H)HSSeMZL0bOQvyHOse(xqr5WbcWESFEb5OmbN97W3o701chnTWP)70Gtn)GiP8Ivkvzb1FlUUcPcWvLGzleG8Z3BUsRwAWUKSSOKcISOTgXxt16p8qxP2uadTYg7A8gwML6ludqK)Ry0PumHOl5kgQ(JZ8gCVCdN)(crwa7rmElhbohY7YAmP)WevX9GlASQ)ebeMptgtmbYBZQGhUQaxeVmTIfTQ6T6B9hQW8XSQ9XSRihQGbIUbXjHm(Dok1V3FuL(oU76rX02WqIeGsG4wEv9zuv01qfq8JnBTLmFKxuZ0lHur6fNzki(qOf(tCzri1kEB9p2FGj9tslyb(feb4Qwxv816p(tCkenND7jcDgApYFLO2e5XDg9BLbFBzWSPTsSVhlmG9eFqrARXMDZYVqrjGkGkUWZ)O2FC9Y9F5ESQIccwuQSFogffZdU0bWOVdb0ruT)qOMVNTRX)wiwkKdmuZ6ld7q5Zg3PSr9u6u92yFBI11(1bRxT3Qm38gkF92QqPhm19diK19sBOuyLKugACbqrVIYtbDIWEDoiIx85lz5u5lW9brJVFaGp4)Bb0EaaKizSNsavqZodxhGfcpIspGjtlF(VdGt4Mg0i4)oLuCHXi2geNpWnvb4d1u4yLczbYnBDH1T2u5iB3CDzFg7jK4pYgQihbgLxX5W6fegLS3THY2wflyTcZS10Q9LMXnefPk7okIT5iefTdrGUEFUm4pcK1(9nel1odSCj9NTsUS2JDvTQI5cw8zdEi57u9U5Iog)YyCmSNCAmEfdD7)7b3Jjlz9ZD8EzlTO7dzAn84hJXslFDJMTU8gUh()D)XOW2Om87LVOT)FmoHQxdzmwE98cFzUabfRgFOWhTUvL29Bi4twjqR99gs(UrgUvS7NSRUQj8(Qa5meHw3ZvTSWuFlq1WiYTbvTdN0ApBmOjL2phJdVPfMX4Rv7Nzu(BEhoFvCZgY6Q06UCnftw)WHrbaA6J72Wb2dzP3C2ycBj73AmrT4TqngWvtVpJjmLERkFvWa6Mo5YsRtT3UsVS4s59x9E5nnebCiNPTCeVZzISjy29X)oO(HrFv9Npxj(Fs9Ozon2mUY2hNG92(nLbAtX65VX0GSkFw(dtRRx8p4(NmuQN5nAO4oZBuwo3hJ37ENY8SSSDffNrL12UFMRzQZTUMPmwbTaWyqFZVU9(zTcW2VT5u3EVgStCsJpJ3Syw7D2AOYFKnEs32PVz0yF8YRDMyAEAQCxDoOIJasI3EtAZ0vShrhXmbOD72URgKqOy2UITsLABCDgwg5bLgEBnPJK(BLPp2GHaPc4HUT9UETFsIQkrULVV1qYwVAcB7nZmAJtxgOEhUfOZ471mPTfF9kD2nURaYNnbeV2CRTPVs6efbQ7P34UCsxTDZCNj2hfOMLyT7s9dtbhmimz5awcTY57cw1DnUDyrt599a1Rm8Qzq0jGjFCiO2lr2WgoM2mJSfftXc4oZaVgfAOdR2yGvMWPkkO7Ij9IB7bhUz1Omd28321277d87Od(Fq6I0)lNR5KeX9gTHDexZQ5OLBAam9o5FKCtUN9Nh31RQWw35pmXyKklxqnowSUItFq)RxneP7rnDC51RA6H0z05pPnP4B4pMTh6WdZsp3Rvpv6gTbsLbQcu5LFmef4JSXb7wnt7AFMg3UE1Y4bhfBDEZSvBhm(jgY76fRKwk9bsB9Eh8P77ryApc6h0LdLdrvkmb1RDJD1qBYGLrk3rsAg47B242my33mRAE8G2L9jNz6g35ZMyFqP6sLYllyMDRM07yv7iD8NEWgRUZQOv)jBhd)Q2p2QUQQZTPwlwUxTwpzcsZOix76mtIwmmywlSu22QoNQVu0m4vlmG3QpJ8UJNCtZOj)2ztDSWGMwL1ecWxRg7BHuMuMJQntL2tfmgjSgmOtCRHMwqpML7T9NYoeHtt5t5Y7)n]] )
