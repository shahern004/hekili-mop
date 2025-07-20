-- RogueAssassination.lua July 2025
-- by Smufrik

-- MoP: Use UnitClass instead of UnitClassBase
local addon, ns = ...
local _, playerClass = UnitClass('player')
if playerClass ~= 'ROGUE' then return end

local Hekili = _G[addon]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format

-- Create the Assassination spec (259 is Assassination in retail, using appropriate ID)
local spec = Hekili:NewSpecialization(259, true)

spec.name = "Assassination"
spec.role = "DAMAGER"
spec.primaryStat = 2 -- Agility

-- Ensure state is properly initialized
if not state then 
    state = Hekili.State 
end

-- MoP-compatible power type registration
-- Use MoP power type numbers instead of Enum
-- Energy = 3, ComboPoints = 4 in MoP Classic
spec:RegisterResource( 3 ) -- Energy
spec:RegisterResource( 4 ) -- ComboPoints

-- Talents for MoP Assassination Rogue
spec:RegisterTalents({
    -- Tier 1 (Level 15)
    shadow_focus =        { 1, 1, 108209 }, -- Abilities cost 30% less Energy while Stealth or Shadow Clone is active
    improved_recuperate = { 1, 2, 108210 }, -- Recuperate restores 5% additional health and 30% more healing per stack of Recuperate
    lethality =           { 1, 3, 108211 }, -- Critical strike damage bonus increased by 10%
    
    -- Tier 2 (Level 30)
    deadly_throw =       { 2, 1, 26679 }, -- Throw a dagger that slows the target
    nerve_strike =       { 2, 2, 108215 }, -- Your successful melee attacks reduce the target's damage by 50% for 6 sec
    combat_readiness =   { 2, 3, 74001 }, -- Each melee or ranged attack against you increases your dodge by 2%
    
    -- Tier 3 (Level 45)
    cheat_death = { 3, 1, 31230 }, -- Fatal damage instead reduces you to 7% of maximum health
    leeching_poison = { 3, 2, 108211 }, -- Your poisons also heal you for 10% of damage dealt
    elusiveness = { 3, 3, 79008 }, -- Reduces cooldown of Cloak of Shadows, Combat Readiness, and Dismantle
    
    -- Tier 4 (Level 60) 
    cloak_and_dagger = { 4, 1, 138106 }, -- Ambush, Garrote, and Cheap Shot have 40 yard range and will cause you to teleport behind your target
    shadowstep = { 4, 2, 36554 }, -- Step through shadows to appear behind your target and increase movement speed
    burst_of_speed = { 4, 3, 108212 }, -- Increases movement speed by 70% for 4 sec. Each enemy strike removes 1 sec
    
    -- Tier 5 (Level 75)
    internal_bleeding = { 5, 1, 154953 }, -- Kidney Shot also causes the target to bleed
    dirty_deeds = { 5, 2, 108216 }, -- Cheap Shot and Kidney Shot have 20% increased critical strike chance
    paralytic_poison = { 5, 3, 108215 }, -- Coats weapons with poison that reduces target's movement speed
    
    -- Tier 6 (Level 90)
    vendetta = { 6, 1, 79140 }, -- Marks an enemy for death, increasing all damage you deal to the target
    shadow_clone = { 6, 2, 159621 }, -- Create a shadow clone that mirrors your attacks
    venom_rush = { 6, 3, 152152 }, -- Vendetta also increases your Energy regeneration
})

-- Auras for Assassination Rogue
spec:RegisterAuras({
    -- Poisons
    deadly_poison = {
        id = 2823,
        duration = 3600,
        max_stack = 1
    },
    instant_poison = {
        id = 8680,
        duration = 3600,
        max_stack = 1
    },
    wound_poison = {
        id = 8679,
        duration = 3600,
        max_stack = 1
    },
    leeching_poison = {
        id = 108211,
        duration = 3600,
        max_stack = 1
    },
    paralytic_poison = {
        id = 108215,
        duration = 3600,
        max_stack = 1
    },
    
    -- Debuffs on target
    deadly_poison_dot = {
        id = 2818,
        duration = 12,
        tick_time = 3,
        max_stack = 5
    },
    rupture = {
        id = 1943,
        duration = function() return 4 * combo_points.current + 6 end,
        tick_time = 2,
        max_stack = 1
    },
    garrote = {
        id = 703,
        duration = 18,
        tick_time = 3,
        max_stack = 1
    },
    
    -- Buffs
    slice_and_dice = {
        id = 5171,
        duration = function() return 6 + (3 * combo_points.current) end,
        max_stack = 1
    },
    stealth = {
        id = 1784,
        duration = 10,
        max_stack = 1
    },
    vanish = {
        id = 1856,
        duration = 3,
        max_stack = 1
    },
    cold_blood = {
        id = 14177,
        duration = 60,
        max_stack = 1
    },
    vendetta = {
        id = 79140,
        duration = 30,
        max_stack = 1
    },
    shadow_clone = {
        id = 159621,
        duration = 15,
        max_stack = 1
    },
    envenom = {
        id = 32645,
        duration = function() return combo_points.current end,
        max_stack = 1
    },
    
    -- Utility
    evasion = {
        id = 5277,
        duration = 15,
        max_stack = 1
    },
    cloak_of_shadows = {
        id = 31224,
        duration = 5,
        max_stack = 1
    },
    feint = {
        id = 1966,
        duration = 10,
        max_stack = 1
    },
    sprint = {
        id = 2983,
        duration = 15,
        max_stack = 1
    },
    shadowstep = {
        id = 36554,
        duration = 0,
        max_stack = 1
    },
    burst_of_speed = {
        id = 108212,
        duration = 4,
        max_stack = 1
    },
    
    -- Missing auras for MoP abilities
    shadow_blades = {
        id = 121471,
        duration = 12,
        max_stack = 1
    },
    
    shadow_dance = {
        id = 185313, -- Placeholder ID (this is more of a Subtlety ability)
        duration = 8,
        max_stack = 1
    },
    
    crimson_tempest = {
        id = 121411,
        duration = function() return 2 + (2 * combo_points.current) end,
        tick_time = 2,
        max_stack = 1
    },
    
    -- MoP Trinket auras
    vial_of_shadows = {
        id = 79734, -- Vial of Shadows proc aura
        duration = 15,
        max_stack = 1
    },
})

-- Abilities for Assassination Rogue
spec:RegisterAbilities({
    -- Basic attacks
    mutilate = {
        id = 1329,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 55,
        spendType = "energy",
        
        startsCombat = true,
        
        handler = function()
            gain(2, "combo_points")
            if buff.deadly_poison.up then
                applyDebuff("target", "deadly_poison_dot", 12, min(5, debuff.deadly_poison_dot.stack + 1))
            end
        end,
    },
    
    sinister_strike = {
        id = 1752,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 45,
        spendType = "energy",
        
        startsCombat = true,
        
        handler = function()
            gain(1, "combo_points")
        end,
    },
    
    backstab = {
        id = 53,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 60,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return behind_target end,
        
        handler = function()
            gain(1, "combo_points")
        end,
    },
    
    -- Finishers
    envenom = {
        id = 32645,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 35,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return combo_points.current > 0 end,
        
        handler = function()
            local cp = combo_points.current
            applyBuff("envenom", cp)
            spend(cp, "combo_points")
        end,
    },
    
    rupture = {
        id = 1943,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 25,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return combo_points.current > 0 end,
        
        handler = function()
            local cp = combo_points.current
            applyDebuff("target", "rupture", 4 * cp + 6)
            spend(cp, "combo_points")
        end,
    },
    
    slice_and_dice = {
        id = 5171,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 25,
        spendType = "energy",
        
        startsCombat = false,
        
        usable = function() return combo_points.current > 0 end,
        
        handler = function()
            local cp = combo_points.current
            applyBuff("slice_and_dice", 6 + (3 * cp))
            spend(cp, "combo_points")
        end,
    },
    
    -- Stealth abilities
    stealth = {
        id = 1784,
        cast = 0,
        cooldown = 10,
        gcd = "off",
        
        startsCombat = false,
        
        usable = function() return not combat end,
        
        handler = function()
            applyBuff("stealth")
        end,
    },
    
    vanish = {
        id = 1856,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function()
            applyBuff("vanish")
        end,
    },
    
    -- Opening abilities
    garrote = {
        id = 703,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 45,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return stealthed.all and behind_target end,
        
        handler = function()
            applyDebuff("target", "garrote")
            removeBuff("stealth")
            removeBuff("vanish")
        end,
    },
    
    ambush = {
        id = 8676,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 60,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return stealthed.all end,
        
        handler = function()
            gain(2, "combo_points")
            removeBuff("stealth")
            removeBuff("vanish")
        end,
    },
    
    -- Utility
    kick = {
        id = 1766,
        cast = 0,
        cooldown = 24,
        gcd = "off",
        
        startsCombat = true,
        interrupt = true,
        
        handler = function()
            interrupt()
        end,
    },
    
    evasion = {
        id = 5277,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        
        startsCombat = false,
        toggle = "defensives",
        
        handler = function()
            applyBuff("evasion")
        end,
    },
    
    feint = {
        id = 1966,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        
        spend = 20,
        spendType = "energy",
        
        startsCombat = false,
        
        handler = function()
            applyBuff("feint")
        end,
    },
    
    sprint = {
        id = 2983,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function()
            applyBuff("sprint")
        end,
    },
    
    -- Talents
    vendetta = {
        id = 79140,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        
        talent = "vendetta",
        toggle = "cooldowns",
        
        startsCombat = true,
        
        handler = function()
            applyDebuff("target", "vendetta")
        end,
    },
    
    shadowstep = {
        id = 36554,
        cast = 0,
        cooldown = 24,
        gcd = "off",
        
        talent = "shadowstep",
        
        startsCombat = false,
        
        handler = function()
            setDistance(5)
        end,
    },
    
    -- Poisons
    deadly_poison = {
        id = 2823,
        cast = 3,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        usable = function() return not buff.deadly_poison.up end,
        
        handler = function()
            applyBuff("deadly_poison")
        end,
    },
    
    instant_poison = {
        id = 8680,
        cast = 3,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        usable = function() return not buff.instant_poison.up end,
        
        handler = function()
            applyBuff("instant_poison")
        end,
    },
    
    -- Utility abilities
    shiv = {
        id = 5938,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 20,
        spendType = "energy",
        
        startsCombat = true,
        
        handler = function()
            gain(1, "combo_points")
            -- Apply poison effects
        end,
    },
    
    tricks_of_the_trade = {
        id = 57934,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 15,
        spendType = "energy",
        
        startsCombat = false,
        
        handler = function()
            -- Redirect threat
        end,
    },
    
    apply_poison = {
        id = 2823, -- Use deadly poison as default
        cast = 3,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function()
            applyBuff("deadly_poison")
        end,
    },
    
    -- AoE abilities
    crimson_tempest = {
        id = 121411,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 35,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return combo_points.current > 0 end,
        
        handler = function()
            local cp = combo_points.current
            applyDebuff("target", "crimson_tempest", 2 + (2 * cp))
            spend(cp, "combo_points")
        end,
    },
    
    fan_of_knives = {
        id = 51723,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 50,
        spendType = "energy",
        
        startsCombat = true,
        
        handler = function()
            gain(1, "combo_points")
        end,
    },
    
    -- Cooldowns
    shadow_blades = {
        id = 121471,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        startsCombat = false,
        toggle = "cooldowns",
        
        handler = function()
            applyBuff("shadow_blades")
        end,
    },
    
    -- Defensive abilities
    cloak_of_shadows = {
        id = 31224,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        startsCombat = false,
        toggle = "defensives",
        
        handler = function()
            applyBuff("cloak_of_shadows")
        end,
    },
    
    leeching_poison = {
        id = 108211,
        cast = 3,
        cooldown = 0,
        gcd = "spell",
        
        talent = "leeching_poison",
        startsCombat = false,
        
        handler = function()
            applyBuff("leeching_poison")
        end,
    },
    
    -- Finishers
    dispatch = {
        id = 111240,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 30,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return combo_points.current > 0 and target.health.pct < 35 end,
        
        handler = function()
            local cp = combo_points.current
            spend(cp, "combo_points")
        end,
    },
    
    -- Utility
    preparation = {
        id = 14185,
        cast = 0,
        cooldown = 480,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function()
            setCooldown("evasion", 0)
            setCooldown("vanish", 0)
            setCooldown("sprint", 0)
        end,
    },
    
    -- Consumable (placeholder)
    jade_serpent_potion = {
        id = 76093,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function()
            -- Agility buff
        end,
    },

    -- MoP Trinkets and Items
    vial_of_shadows = {
        id = 79713, -- Vial of Shadows trinket ID
        cast = 0,
        cooldown = 120,
        gcd = "off",
        
        item = 79713,
        toggle = "cooldowns",
        
        startsCombat = false,
        
        handler = function()
            -- Vial of Shadows effect - increases damage
        end,
    },
    
    -- Generic use_items support
    use_items = {
        id = 0, -- Generic use items
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function()
            -- Generic item usage
        end,
    },
})

-- State expressions
spec:RegisterStateExpr("behind_target", function()
    return true -- Assume we can get behind target
end)

spec:RegisterStateExpr("poisoned", function()
    return debuff.deadly_poison_dot.up or debuff.wound_poison.up
end)

-- Proper stealthed state table for MoP compatibility
spec:RegisterStateTable("stealthed", {
    rogue = function() return buff.stealth.up end,
    mantle = function() return false end, -- Not available in MoP
    all = function() return buff.stealth.up or buff.vanish.up or buff.shadow_dance.up end,
})

-- Add anticipation_charges for compatibility (not used in MoP but referenced in imported rotations)
spec:RegisterStateExpr("anticipation_charges", function()
    return 0 -- Always 0 in MoP since Anticipation works differently
end)

-- Hooks
spec:RegisterHook("reset_precast", function()
    -- Reset any necessary state
end)

-- Options
spec:RegisterOptions({
    enabled = true,
    aoe = 2,
    cycle = false,
    nameplates = true,
    nameplateRange = 8,
    damage = true,
    damageExpiration = 8,
    potion = "virmen_bite_potion",
    package = "Assassination"
})
spec:RegisterSetting( "use_vendetta", true, {
    name = strformat( "Use %s", Hekili:GetSpellLinkWithTexture( 79140 ) ), -- Vendetta
    desc = "If checked, Vendetta will be recommended based on the Assassination Rogue priority. If unchecked, it will not be recommended.",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "envenom_stack_threshold", 4, {
    name = strformat( "Envenom Stack Threshold" ),
    desc = "Minimum deadly poison stacks on target before recommending Envenom over Rupture (1-5)",
    type = "range",
    min = 1,
    max = 5,
    step = 1,
    width = 1.5
} )

spec:RegisterSetting( "shadow_clone_toggle", "cooldowns", {
    name = strformat( "%s Toggle", Hekili:GetSpellLinkWithTexture( 159621 ) ), -- Shadow Clone
    desc = "Select when Shadow Clone should be recommended:",
    type = "select",
    values = {
        cooldowns = "With Cooldowns",
        always = "Always",
        never = "Never"
    },
    width = 1.5
} )

spec:RegisterSetting( "mutilate_poison_management", true, {
    name = strformat( "Optimize %s Poison Application", Hekili:GetSpellLinkWithTexture( 1329 ) ), -- Mutilate
    desc = "If checked, the addon will optimize Mutilate usage to maintain deadly poison stacks efficiently.",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "allow_shadowstep", true, {
    name = strformat( "Allow %s", Hekili:GetSpellLinkWithTexture( 36554 ) ), -- Shadowstep
    desc = "If checked, Shadowstep may be recommended for mobility and positioning. If unchecked, it will only be recommended for damage bonuses.",
    type = "toggle",
    width = "full"
} )
-- Pack (rotation logic would go here)
spec:RegisterPack("Assassination", 20250710, [[Hekili:nJX(pUnn4)wonPQBJJqV0R3yJ2kbmqStIjeD8tiAIBIBJP5LID6Osv5VD((SZl78O9gieAANsT)8373BUFZh3S2NiOB(G9u75tF99tTSV)HP2Z2SwCkLUzDkX7azp8rmjc(lHZbO5c8ItHjeFeb8K8mp4YnR3MZcfVpEZ2EX605aSPup445VzZ6aMVpvblL7Tz9hdy8cx8)Kc3s6w4MSd(TNGLex4gY4c46DjzfU)e9alKzTzT8qKnqIJ8ZhKsfnMSnK6V57aMw(CGmmEkr4fOiyglvD83HVRWnlrquhaxjOzmcaxIWYNstDyXC2(aHvgnIaFx4UQWDAH7KcxeKm6rkjKfV3HlYyhO6GTracSbl1qcVKOTjoPjSyu0wu4(qH75ZfU3w4kiH0yHfjwW8yPsMZQehss35PZLh3gEhVas2EQ66zfUVSrBeLlyHOrcyVz))J9Qnwa79WGS3nfUBZ3TZ6ijMXdSYtlPCsOFYNIRoUT54XPn0inJMsYuwDb8pWVyhjpumMtejABo30f6Nb03VhexaEgIaQVfjmCCpbFQuuqbNggIa4qJZGGaqSAOppGDCCtMavPOFReDEeUa8m1WXbM3HX1RcwevQUM1sDb(2Eh4oj7CabYrKr8LopZhqt5bsSJ6hoyqQku1rLiXZNJV9XR0XBP075ZYXB1sPt7GEE496UEz5XdY37yOhfY6VEqwxA)CuMbU1osmQYoeZowro7RJwKeP(9R)C0VQKHWRFZNZRH4akKXdyyvCbeOGkvsVrgArc)AY(C6BlC)wOqbNZIjQm3)sfcQsMZb6rfbKq89e)WtTIWstdpHMpo(R4K4karQKIPzRJJgZZSflwfUub(Fc37WPzPGBeqi1HAGpAgh9y6Mit1X9fs08CzmjpK5rDiX(o(WhwyQQwOr7sL(h9egjNeG(iqz5iOrPYIZAMKVn5h6p30qXjx0)DMeSBuf)miUfeJDOTn6Qvd1zPRlv0LbThrp9CQInVbpAY342()HkS(0wTfA7HTOsVamN5iEbhPX(uHGyy()(YIH8EZVF)0kBPYKO8HXQfJA)U871poGaSGJpj2JwDhnMMT)uzn5(ByywlHJuL3DyRSKuBdts8dZLQw4XQIgLLerU2rKaomuvVmtvx3Mh3gcjh4YysjtDBvhgLAxj7JpQPjJQBA3MXSPALu0qEFoz1YjJeIEpQhW7iEDyJbenSUTkxUjgVC6Pw0OHXK6vND5zNgVU9iyGMb5CRYnmC5ZkhJf6nRrY8iXOmMLbPT7RWy3wGGkAOlNkiS0vTS7Hs1HGMw17GP1cVRUTWQYHJLfgMh6GMTtlo8DniPfNgOIxsrp1fyco94jtCEXatt8nBUg(OhjCGB0SlLNnESflgIoXjC8jrqlPoZvU5LKlI8xfUVcM1XQvoSDuMYonCcvnUvf00yHcPuVaKKQwb6AMmaqzRkBqBe7KrHdDR0pkFE)1lVurl7blAnQjdSnL1mlL(Ub0yoY29mMkYZUqjVUm2ZcXp)IGJQDq60mUSImA3EFl)Xyi9rs04jQgLlkXGMXzQ18ULD6LOx7mjst7LfD9c7n0r6T(jswmy45vB)inlzhlKQwdsed7Gg8k45PPjzIYnFShfbMhyqZyXhWookClCFVq9izJ2ry(xyyiOVz4y6rA2je3SequGVGG5WCFS5ekd6Jn7Tfpv4(LfU)(VXPiMOr8)4Uc3pfW8cAdnj(udvlCJtqK)xql5EmrydE9XVqItBi63u4c8Ejz(OcfGv)pqK63(i7wu(tSWWwsujkfvGk1gYJIZJGQliH5HGdwXtVpcvy4bV2y9rWL48ms18M1VOWT)jwE6f9n0sXtLFyvpr0xS8RApWYDQHvwQgQ5U6Pxw6vn8s)4ONjy6hWEMDPFalBf7o2UL3OnXYaGR5(IVAOrvaRiQD035rnsr9HCfjik6NUi1cyhragBNhTHh3ybc)q72OnS9OkLpfY7TcQW0csZzGVd7yAj0MDBGmMqxbJQkdI225ewo)85Bhz7etAd8QLpmPVnsSA5SxEr6ddek1Vdp4XQL2xwuLBj4YG10)tPTxBKYg)jGRqCOp7IPscL7r57ztUzK5knP2153wMnEXCdtGTj604ftwFX8)9L1rgkCHDP62yd1nmH0(bSr1YsLHudSZ6vtNm2UQxnTlARwrCh9Wdpd)CqN3NB(IwE59kh)NqWwBawMOuFzYtgyrYRGbwvwgZ2fBOGkdXZ2b1Eyh0Amw2)KKHlJkM0T5Uvpo(tBO4v(2Ywx6ZhFejA1Jt6PNVv3)zqaJ26waT0nr1oN0GC94ZEmgUoQREXjnOgkna4TA626Qk3pDYnMR)W8nKQcgd9IQd0xvsJaQ7JpZKaAByO2lZyBiNp31wV4HPNppWgqMCR548Npp4EpGIRV0KRY5uhO75ivDeJvruZLA4VhoSvv7s82SnI(qshOR38W1aT(IgWxOSblESdB0SOG2nNuU1HvlbR8GBBO0j7DTkTwH7MYTyfgJnaGeQzS5flTR8K6zvbdGYYb(nX0S5LyQzjbdGa5K94Z7UvGvnBe4vtTShabgtUBWjZQvBdVcGCrqsgmUEYEFASA0)n)9]])
