-- WarriorArms.lua
-- Updated for MoP Classic based on WoWSimulation APL
-- Enhanced rotation logic with sophisticated cooldown management

local addon, ns = ...
local Hekili = _G[ addon ]

if not Hekili then return end

local class, state = Hekili.Class, Hekili.State
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

local spec = Hekili:NewSpecialization( 71 ) -- Arms

-- Enhanced State Expressions for WoWSimulation compatibility
spec:RegisterStateExpr( "rage_deficit", function()
    return rage.max - rage.current
end )

spec:RegisterStateExpr( "max_rage", function()
    return rage.max or 100
end )

spec:RegisterStateExpr( "current_rage", function()
    return rage.current or 0
end )

spec:RegisterStateExpr( "current_time", function()
    return combat_time or 0
end )

spec:RegisterStateExpr( "remaining_time", function()
    return target.time_to_die or 300
end )

spec:RegisterStateExpr( "number_targets", function()
    return active_enemies or 1
end )

spec:RegisterStateExpr( "auto_time_to_next", function()
    return swing.main_hand.remains or 0
end )

spec:RegisterStateExpr( "gcd_time_to_ready", function()
    return gcd.remains
end )

spec:RegisterStateExpr( "is_execute_phase", function()
    return target.health_pct <= 20
end )

spec:RegisterStateExpr( "active_enemies", function()
    return active_enemies or 1
end )

-- Enhanced Aura tracking
spec:RegisterAuras( {
    -- Key buffs
    battle_shout = {
        id = 6673,
        duration = 300,
        max_stack = 1,
    },
    
    commanding_shout = {
        id = 469,
        duration = 300,
        max_stack = 1,
    },
    
    recklessness = {
        id = 1719,
        duration = 12,
        max_stack = 1,
    },
    
    avatar = {
        id = 107574,
        duration = 24,
        max_stack = 1,
    },
    
    bloodbath = {
        id = 12292,
        duration = 12,
        max_stack = 1,
    },
    
    berserker_rage = {
        id = 18499,
        duration = 6,
        max_stack = 1,
    },
    
    enrage = {
        id = 12880,
        duration = 12,
        max_stack = 1,
    },
    
    sweeping_strikes = {
        id = 12328,
        duration = 10,
        max_stack = 1,
    },
    
    taste_for_blood = {
        id = 60503,
        duration = 9,
        max_stack = 5,
    },
    
    sudden_death = {
        id = 52437,
        duration = 10,
        max_stack = 1,
    },
    
    charge = {
        id = 100,
        duration = 1,
        max_stack = 1,
    },
    
    bladestorm = {
        id = 46924,
        duration = 6,
        max_stack = 1,
    },
    
    skull_banner = {
        id = 114207,
        duration = 15,
        max_stack = 1,
    },
    
    battle_stance = {
        id = 2457,
        duration = 3600,
        max_stack = 1,
    },
    
    berserker_stance = {
        id = 2458,
        duration = 3600,
        max_stack = 1,
    },
    
    defensive_stance = {
        id = 71,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Key debuffs
    colossus_smash = {
        id = 86346,
        duration = 6,
        max_stack = 1,
    },
    
    mortal_strike_debuff = {
        id = 12294,
        duration = 10,
        max_stack = 1,
    },
    
    deep_wounds = {
        id = 115767,
        duration = 12,
        tick_time = 3,
        max_stack = 1,
    },
    
    -- Defensive buffs
    die_by_the_sword = {
        id = 118038,
        duration = 8,
        max_stack = 1,
    },
    
    shield_wall = {
        id = 871,
        duration = 12,
        max_stack = 1,
    },
    
    rallying_cry = {
        id = 97462,
        duration = 10,
        max_stack = 1,
    },
    
    enraged_regeneration = {
        id = 55694,
        duration = 5,
        max_stack = 1,
    },
    
    victory_rush = {
        id = 34428,
        duration = 20,
        max_stack = 1,
    },
    
    -- Consumables
    potion = {
        id = 76095, -- Mogu Power Potion
        duration = 25,
        max_stack = 1,
    },
} )

-- Enhanced ability definitions with proper MoP mechanics
spec:RegisterAbilities( {
    mortal_strike = {
        id = 12294,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        spend = function() return -10 end, -- Generates rage in MoP
        spendType = "rage",
        startsCombat = true,
        texture = 132355,
        handler = function()
            applyDebuff( "target", "mortal_strike_debuff", 10 )
            if not buff.taste_for_blood.up then
                applyBuff( "taste_for_blood" )
                buff.taste_for_blood.stack = 2
            else
                addStack( "taste_for_blood", nil, 2 )
                if buff.taste_for_blood.stack > 5 then
                    buff.taste_for_blood.stack = 5
                end
            end
        end,
    },
    
    colossus_smash = {
        id = 86346,
        cast = 0,
        cooldown = 20,
        gcd = "spell", 
        spend = 20,
        spendType = "rage",
        startsCombat = true,
        texture = 464973,
        handler = function()
            applyDebuff( "target", "colossus_smash", 6 )
        end,
    },
    
    execute = {
        id = 5308,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = function()
            if buff.sudden_death.up then return 0 end
            return 30
        end,
        spendType = "rage",
        startsCombat = true,
        texture = 135358,
        usable = function()
            return target.health_pct < 20 or buff.sudden_death.up
        end,
        handler = function()
            if buff.sudden_death.up then
                removeBuff( "sudden_death" )
            end
        end,
    },
    
    slam = {
        id = 1464,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = 25,
        spendType = "rage",
        startsCombat = true,
        texture = 132340,
        handler = function()
            -- MoP instant Slam
        end,
    },
    
    overpower = {
        id = 7384,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = 10,
        spendType = "rage",
        startsCombat = true,
        texture = 132223,
        charges = function()
            return buff.taste_for_blood.stack or 0
        end,
        usable = function()
            return buff.taste_for_blood.up
        end,
        handler = function()
            removeStack( "taste_for_blood", 1 )
        end,
    },
    
    recklessness = {
        id = 1719,
        cast = 0,
        cooldown = function()
            if set_bonus.tier15_4pc == 1 then return 60 end
            return 180
        end,
        gcd = "spell",
        spend = 0,
        spendType = "rage",
        toggle = "cooldowns",
        startsCombat = false,
        texture = 458972,
        handler = function()
            applyBuff( "recklessness", 12 )
        end,
    },
    
    avatar = {
        id = 107574,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        spend = 0,
        spendType = "rage",
        talent = "avatar",
        toggle = "cooldowns",
        startsCombat = false,
        texture = 613534,
        handler = function()
            applyBuff( "avatar", 24 )
        end,
    },
    
    bloodbath = {
        id = 12292,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        spend = 0,
        spendType = "rage",
        talent = "bloodbath",
        toggle = "cooldowns",
        startsCombat = false,
        texture = 236304,
        handler = function()
            applyBuff( "bloodbath", 12 )
        end,
    },
    
    berserker_rage = {
        id = 18499,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        spend = 0,
        spendType = "rage",
        startsCombat = false,
        texture = 136009,
        handler = function()
            applyBuff( "berserker_rage", 6 )
            applyBuff( "enrage", 12 )
        end,
    },
    
    sweeping_strikes = {
        id = 12328,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        spend = 20,
        spendType = "rage",
        startsCombat = false,
        texture = 132306,
        handler = function()
            applyBuff( "sweeping_strikes", 10 )
        end,
    },
    
    bladestorm = {
        id = 46924,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        spend = 0,
        spendType = "rage",
        talent = "bladestorm",
        toggle = "cooldowns",
        startsCombat = true,
        texture = 236303,
        handler = function()
            applyBuff( "bladestorm", 6 )
        end,
    },
    
    dragon_roar = {
        id = 118000,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        spend = 0,
        spendType = "rage",
        talent = "dragon_roar",
        toggle = "cooldowns",
        startsCombat = true,
        texture = 642418,
        handler = function()
            -- AoE damage
        end,
    },
    
    heroic_strike = {
        id = 78,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        spend = 30,
        spendType = "rage",
        startsCombat = true,
        texture = 132282,
        usable = function()
            return rage.current >= 100 or (rage.current >= 85 and buff.charge.up)
        end,
        handler = function()
            -- Next melee swing enhanced
        end,
    },
    
    charge = {
        id = 100,
        cast = 0,
        cooldown = 20,
        charges = function()
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 2
            end
            return 1
        end,
        recharge = 20,
        gcd = "off",
        range = 25,
        spend = function()
            if talent.juggernaut.enabled then return -15 end
            return 0
        end,
        spendType = "rage",
        startsCombat = true,
        texture = 132337,
        handler = function()
            applyBuff( "charge", 1 )
            if talent.warbringer.enabled then
                applyDebuff( "target", "charge_root", 4 )
            end
        end,
    },
    
    battle_shout = {
        id = 6673,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = function() return -10 end,
        spendType = "rage",
        startsCombat = false,
        texture = 132333,
        handler = function()
            applyBuff( "battle_shout", 300 )
        end,
    },
    
    skull_banner = {
        id = 114207,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        spend = 0,
        spendType = "rage",
        talent = "skull_banner",
        toggle = "cooldowns", 
        startsCombat = false,
        texture = 132333,
        handler = function()
            applyBuff( "skull_banner", 15 )
        end,
    },
    
    thunder_clap = {
        id = 6343,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        spend = 20,
        spendType = "rage",
        startsCombat = true,
        texture = 136105,
        handler = function()
            if talent.blood_and_thunder.enabled then
                applyDebuff( "target", "deep_wounds" )
            end
        end,
    },
    
    cleave = {
        id = 845,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        spend = 30,
        spendType = "rage",
        startsCombat = true,
        texture = 132338,
        usable = function()
            return active_enemies >= 2
        end,
        handler = function()
            -- Next melee hits multiple targets
        end,
    },
    
    whirlwind = {
        id = 1680,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = 30,
        spendType = "rage",
        startsCombat = true,
        texture = 132369,
        usable = function()
            return active_enemies >= 3
        end,
        handler = function()
            -- AoE damage
        end,
    },
    
    heroic_leap = {
        id = 6544,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        spend = 0,
        spendType = "rage",
        startsCombat = true,
        texture = 236171,
        handler = function()
            -- Leap to target
        end,
    },
    
    pummel = {
        id = 6552,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        spend = 0,
        spendType = "rage",
        toggle = "interrupts",
        startsCombat = true,
        texture = 132938,
        handler = function()
            interrupt()
        end,
    },
    
    disrupting_shout = {
        id = 102060,
        cast = 0,
        cooldown = 40,
        gcd = "spell",
        spend = 0,
        spendType = "rage",
        talent = "disrupting_shout",
        toggle = "interrupts",
        startsCombat = true,
        texture = 613534,
        handler = function()
            -- AoE interrupt
        end,
    },
    
    -- Defensive abilities
    die_by_the_sword = {
        id = 118038,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        spend = 0,
        spendType = "rage",
        toggle = "defensives",
        startsCombat = false,
        texture = 132336,
        handler = function()
            applyBuff( "die_by_the_sword", 8 )
        end,
    },
    
    shield_wall = {
        id = 871,
        cast = 0,
        cooldown = 240,
        gcd = "off",
        spend = 0,
        spendType = "rage",
        toggle = "defensives",
        startsCombat = false,
        texture = 132362,
        handler = function()
            applyBuff( "shield_wall", 12 )
        end,
    },
    
    rallying_cry = {
        id = 97462,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        spend = 0,
        spendType = "rage",
        toggle = "defensives",
        startsCombat = false,
        texture = 132351,
        handler = function()
            applyBuff( "rallying_cry", 10 )
        end,
    },
    
    enraged_regeneration = {
        id = 55694,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        spend = 0,
        spendType = "rage",
        talent = "enraged_regeneration",
        toggle = "defensives",
        startsCombat = false,
        texture = 132345,
        handler = function()
            applyBuff( "enraged_regeneration", 5 )
        end,
    },
    
    victory_rush = {
        id = 34428,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = 0,
        spendType = "rage",
        startsCombat = true,
        texture = 132342,
        usable = function()
            return buff.victory_rush.up
        end,
        handler = function()
            removeBuff( "victory_rush" )
            gain( health.max * 0.2, "health" )
        end,
    },
    
    intervene = {
        id = 3411,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        spend = 0,
        spendType = "rage",
        startsCombat = false,
        texture = 132365,
        handler = function()
            -- Charge to ally
        end,
    },
    
    heroic_throw = {
        id = 57755,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = 0,
        spendType = "rage",
        range = 30,
        startsCombat = true,
        texture = 132453,
        handler = function()
            -- Ranged attack
        end,
    },
    
    -- Stance abilities
    battle_stance = {
        id = 2457,
        cast = 0,
        cooldown = 1.5,
        gcd = "spell",
        spend = 0,
        spendType = "rage",
        startsCombat = false,
        texture = 132349,
        usable = function() return not buff.battle_stance.up end,
        handler = function()
            removeBuff( "defensive_stance" )
            removeBuff( "berserker_stance" )
            applyBuff( "battle_stance" )
        end,
    },
    
    berserker_stance = {
        id = 2458,
        cast = 0,
        cooldown = 1.5,
        gcd = "spell",
        spend = 0,
        spendType = "rage",
        startsCombat = false,
        texture = 132275,
        usable = function() return not buff.berserker_stance.up end,
        handler = function()
            removeBuff( "battle_stance" )
            removeBuff( "defensive_stance" )
            applyBuff( "berserker_stance" )
        end,
    },
    
    defensive_stance = {
        id = 71,
        cast = 0,
        cooldown = 1.5,
        gcd = "spell",
        spend = 0,
        spendType = "rage",
        startsCombat = false,
        texture = 132341,
        usable = function() return not buff.defensive_stance.up end,
        handler = function()
            removeBuff( "battle_stance" )
            removeBuff( "berserker_stance" )
            applyBuff( "defensive_stance" )
        end,
    },
    
    -- Auto attack
    auto_attack = {
        id = 6603,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        startsCombat = true,
        texture = 135348,
        handler = function()
            -- Auto attack handled by game
        end,
    },
} )

-- Priority Lists using Hekili's proper system
spec:RegisterPack( "Arms Warrior MoP", 20250131, [[Hekili:T3ZAZTnss(BjvItHT5TfLSSjyLTKzKPb1e)CzWLfvCK7xnH4nK9pUwHf7qGcWvk(wB(0PJF7bXH7w6(b(9aAFWdUo(0N2F8K)1sEJJNo3X29(GGFWt5d)B4(DF7Y(NF4vE)IVZ6JJuJ)lF)YpbGF4c(NV5ZnE4YFJSqE5Np(VPF(5VoN2p)O1((NhV(n(E9KFRE4P9VF4z(nE9V5Nt(8dF7p(WHD6KVZ2)8BfG(2pF93HgU(5)aYdnC0LPDM9vq6dWF5J3xEOgA4MZS3I2V(iDyXhKoEV2H0Hfpq6WL7d)e28A4Lc(YRdP4b6ydJdJHnhE47ImpY)MfYdJO8d6dYDUadVk5gfO0Hgo7Z(5HJlEOWJDTJgE4Lc84dYl3tFepb0Hfh)VOSHN4JWHSHhk8yH1XEn1vPCHjqCDuVIfn8SbJdBhVCSd3)HJN6dJLYb2dzHtOWD9TKJg(gXdxuW9DTHT48WuFiSzOgog1i2Hfgn5u8OYIXWdBQeVP1Hl(rn2g(Z6qCJNSHt7cjd3xCkUVmvCqxBJZdJpOZf7x2c8rr0x3FdA2V9xmJdJLDQGKJfz7f5sJEWyquJ2ogxzOgdWdZHNdJFNpF5HS14I1vdUmhSRJrPdrC43)IZm1P3eo1Ln2Hl3W)YJvPJJfho0zOA0hnULTxHLHJgog9rJtpK4JWHSwchdcF)q79H)WjREpWL5Y)cC))KONp(YH7AKn(npSh8JK8dJ)8BI8z3fDmh6vt7Xy1bFE4dqeJhnJJJQ6WKSDqxGWvVdA)(k(2FIVjAHWo1PpOm1bwQqrDdNYO7lQiOO6dJPp0LWCy2AE4gTBJNEDVN(AXe3FjJbHGfpSZXjJBxD9x0WQiV)ZXp(47ZIjFFLR1VHH))S1HN8p8VG2VF(TVJ4)rSSJD5b)E(YF5tf(gzjhJp0hZ(w7RP9BUe45R(kKK9PwQY9eZz0cP5Xt2HIo94dwvpCJMB5L4WmcgKNWRKg0(rWv3x8O4pjnU2VpFkXjYhdUn3D9xGJJ)UjF2VZZ5u31(p8HIFewrjFlv9JJnU9p]]))

-- Ranges
spec:RegisterRanges( "mortal_strike", "charge", "heroic_throw" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    aoe = 3,
    gcd = 1500,
    nameplates = true,
    nameplateRange = 8,
    damage = true,
    damageExpiration = 8,
    potion = "mogu_power",
    package = "Arms Warrior MoP",
} )
