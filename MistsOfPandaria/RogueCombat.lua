-- RogueCombat.lua
-- May 2023

-- Contributed to JoeMama.
if UnitClassBase( "player" ) ~= "ROGUE" then return end

local addon, ns = ...
local Hekili = _G[ addon ]

local class = Hekili.Class
local state = Hekili.State

local FindPlayerAuraByID = ns.FindPlayerAuraByID
local strformat, abs = string.format, math.abs

local spec = Hekili:NewSpecialization( 260 ) -- Combat was spec 2 in MoP

-- Set class for MoP compatibility
spec.class = "ROGUE"

spec:RegisterResource( Enum.PowerType.ComboPoints )
spec:RegisterResource( Enum.PowerType.Energy, {
    
    base_time_to_max = function( t )
        if buff.adrenaline_rush.up then
        if t.current > t.max - 50 then return 0 end
        return state:TimeToResource( t, t.max - 50 )
        end
    end,
    base_deficit = function( t )
        if buff.adrenaline_rush.up then
        return max( 0, ( t.max - 50 ) - t.current )
        end
    end,
    }
)

-- Talents - MoP had a different talent system with 6 tiers (15,30,45,60,75,90)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility
    nightstalker            = { 1, 14062, 1 }, -- While Stealth is active, movement speed is increased by 15% and your abilities deal 25% more damage.
    subterfuge              = { 1, 108208, 1 }, -- Your abilities requiring Stealth can still be used for 3 sec after Stealth breaks.
    shadow_focus            = { 1, 108209, 1 }, -- Abilities used while Stealth cost 75% less energy.
    
    -- Tier 2 (Level 30) - Crowd Control
    deadly_throw            = { 2, 26679, 1 }, -- Finishing move that deals damage and reduces the target's movement speed by 70% for 6 seconds.
    nerve_strike            = { 2, 108210, 1 }, -- Kidney Shot also reduces the damage enemies deal by 50% for 6 sec after Kidney Shot is removed.
    combat_readiness        = { 2, 74001, 1 }, -- Reduces all damage taken by 50% for 10 sec. Each time you are struck while Combat Readiness is active, the damage reduction decreases by 10%.
    
    -- Tier 3 (Level 45) - Self-Healing
    leeching_poison         = { 3, 108211, 1 }, -- Your Deadly Poison and Wound Poison also cause your attacks to heal you for 10% of the damage they deal.
    cheat_death             = { 3, 31230, 1 }, -- Fatal attacks instead reduce you to 10% of your maximum health. For 3 sec afterward, you take 85% reduced damage.
    elusiveness             = { 3, 79008, 1 }, -- Feint also reduces all damage you take by 30% for 5 sec.
    
    -- Tier 4 (Level 60) - Cooldowns
    preparation             = { 4, 14185, 1 }, -- When activated, the cooldown on your Vanish, Sprint, and Evasion abilities are reset.
    shadowstep              = { 4, 36554, 1 }, -- Step through the shadows to appear behind your target and gain 70% increased movement speed for 2 sec.
    burst_of_speed          = { 4, 108212, 1 }, -- Increases your movement speed by 70% for 4 sec. Usable while stealthed.
    
    -- Tier 5 (Level 75) - Utilities
    prey_on_the_weak        = { 5, 131511, 1 }, -- Enemies disabled by your Cheap Shot or Kidney Shot take 10% increased damage from all sources for 10 sec.
    paralytic_poison        = { 5, 108215, 1 }, -- Causes your Crippling Poison to also have a 20% chance to paralyze the target for 4 sec.
    dirty_tricks            = { 5, 108216, 1 }, -- Your Gouge, Blind, and Sap abilities no longer cost Energy.
    
    -- Tier 6 (Level 90) - DPS
    shuriken_toss           = { 6, 114014, 1 }, -- Throws a Shuriken at the target dealing 50% weapon damage. Generates 1 combo point.
    marked_for_death        = { 6, 137619, 1 }, -- Marks the target, instantly generating 5 combo points. When the target dies, the cooldown is reset.
    anticipation            = { 6, 114015, 1 }, -- You can store up to 5 extra combo points.
} )

-- Auras - Only include MoP auras
spec:RegisterAuras( {
    -- Energy regeneration increased by $w1%.  Maximum Energy increased by $w4.  Attack speed increased by $w2%.
    adrenaline_rush = {
    id = 13750,
    duration = 15,
    max_stack = 1
    },
    
    -- Damage taken reduced by $w1%.
    evasion = {
    id = 5277,
    duration = 10,
    max_stack = 1
    },
    
    -- Movement speed increased by $w1%.
    sprint = {
    id = 2983,
    duration = 8,
    max_stack = 1
    },
    
    -- Attack speed increased by $w1%.
    slice_and_dice = {
    id = 5171,
    duration = function() return 12 + (3 * combo_points.current) end,
    max_stack = 1
    },
    
    -- Energy cost of your finishing moves reduced by $s1%.
    restless_blades = {
    id = 79096,
    duration = 3600,
    max_stack = 1
    },
    
    -- Damage done increased by $s1%.
    killing_spree = {
    id = 51690,
    duration = 2,
    max_stack = 1
    },
    
    -- Dodge chance increased by $w1%.
    shadow_dance = {
    id = 51713,
    duration = 8,
    max_stack = 1
    },
} )

local restless_blades_list = {
    "adrenaline_rush",
    "killing_spree",
    "redirect",
    "sprint",
    "vanish"
}

spec:RegisterHook( "spend", function( amt, resource )
    if amt > 0 and resource == "combo_points" then
    -- In MoP, Restless Blades reduced cooldowns by 2s per combo point
    local cdr = amt * 2
    
    for _, action in ipairs( restless_blades_list ) do
        reduceCooldown( action, cdr )
    end
    end
end )

-- Abilities - Only include MoP abilities
spec:RegisterAbilities( {
    -- Increases your Energy regeneration rate by 100% and your attack speed by 20% for 15 sec.
    adrenaline_rush = {
    id = 13750,
    cast = 0,
    cooldown = 180,
    gcd = "off",
    
    startsCombat = false,
    texture = 136206,
    
    toggle = "cooldowns",
    
    handler = function ()
        applyBuff( "adrenaline_rush" )
        energy.regen = energy.regen * 2
        energy.max = energy.max + 50
        forecastResources( "energy" )
    end
    },
    
    -- Increases your dodge chance by 50% for 10 sec.
    evasion = {
    id = 5277,
    cast = 0,
    cooldown = 180,
    gcd = "off",
    
    startsCombat = false,
    texture = 136205,
    
    toggle = "defensives",
    
    handler = function ()
        applyBuff( "evasion" )
    end
    },
    
    -- Teleport to an enemy within 10 yards, attacking with both weapons for a total of 5 attacks over 2 sec.
    killing_spree = {
    id = 51690,
    cast = 0,
    cooldown = 120,
    gcd = "totem",
    
    startsCombat = true,
    texture = 236277,
    
    toggle = "cooldowns",
    
    handler = function ()
        applyBuff( "killing_spree" )
    end
    },
    
    -- Extends the duration of Slice and Dice by $s1 sec.
    redirect = {
    id = 73981,
    cast = 0,
    cooldown = 60,
    gcd = "off",
    
    startsCombat = false,
    texture = 132289,
    
    handler = function ()
        -- In MoP, redirect transferred combo points to a new target
        -- For simulation purposes, we just keep the combo points
    end
    },
    
    -- Finishing move that increases attack speed by 40%. Lasts longer per combo point.
    slice_and_dice = {
    id = 5171,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    
    spend = 25,
    spendType = "energy",
    
    startsCombat = false,
    texture = 132306,
    
    usable = function() return combo_points.current > 0, "requires combo points" end,
    
    handler = function ()
        applyBuff( "slice_and_dice", 12 + (3 * combo_points.current) )
        spend( combo_points.current, "combo_points" )
    end
    },
    
    -- Increases your movement speed by 70% for 8 sec.
    sprint = {
    id = 2983,
    cast = 0,
    cooldown = 60,
    gcd = "off",
    
    startsCombat = false,
    texture = 132307,
    
    handler = function ()
        applyBuff( "sprint" )
    end
    },
    
    -- Finishing move that deals damage with both weapons. Damage increases per combo point.
    eviscerate = {
    id = 2098,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    
    spend = 35,
    spendType = "energy",
    
    startsCombat = true,
    texture = 132292,
    
    usable = function() return combo_points.current > 0, "requires combo points" end,
    
    handler = function ()
        spend( combo_points.current, "combo_points" )
    end
    },
    
    -- Stuns the target for 4 sec. Awards 2 combo points.
    cheap_shot = {
    id = 1833,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    
    spend = 40,
    spendType = "energy",
    
    startsCombat = true,
    texture = 132092,
    
    usable = function() return stealthed.all, "requires stealth" end,
    
    handler = function ()
        applyDebuff( "target", "cheap_shot", 4 )
        gain( 2, "combo_points" )
    end
    },
    
    -- Attacks with both weapons, dealing an additional 40% damage. Awards 1 combo point.
    sinister_strike = {
    id = 1752,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    
    spend = 40,
    spendType = "energy",
    
    startsCombat = true,
    texture = 136189,
    
    handler = function ()
        gain( 1, "combo_points" )
    end
    },
    
    -- Throws a revealing agent, increasing stealth detection and preventing nearby enemies from stealthing for 15 sec.
    revealing_strike = {
    id = 84617,
    cast = 0,
    cooldown = 0,
    gcd = "totem",
    
    spend = 40,
    spendType = "energy",
    
    startsCombat = true,
    texture = 132297,
    
    handler = function ()
        applyDebuff( "target", "revealing_strike", 24 )
        gain( 1, "combo_points" )
    end
    },
    
    -- Finishes the enemy, causing 1371 to 2349 damage. Damage is increased by 20% against enemies below 35% health.
    kidney_shot = {
    id = 408,
    cast = 0,
    cooldown = 20,
    gcd = "totem",
    
    spend = 25,
    spendType = "energy",
    
    startsCombat = true,
    texture = 132298,
    
    usable = function() return combo_points.current > 0, "requires combo points" end,
    
    handler = function ()
        applyDebuff( "target", "kidney_shot", 1 + combo_points.current )
        spend( combo_points.current, "combo_points" )
    end
    }
} )

spec:RegisterRanges( "pick_pocket", "kick", "blind", "shadowstep" )

spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    cycle = false,
    
    nameplates = true,
    nameplateRange = 10,
    rangeFilter = false,
    
    damage = true,
    damageExpiration = 6,
    
    potion = "virmens_bite",
    
    package = "Combat",
} )

spec:RegisterPack( "Combat", 20250425, [[Hekili:nRvBVnoUr4FlghG3KRBDD8lzVTi2a9URh6f0EOO(6xTmJeDSQLLCLOsUfWW)27mKuwKuKumVGU3h2fjuKdhoZZ8Wz4K13S(xxVkHWOR)LjJNmF8NgpD0KXtNpE26vSVCKUE1rs8EYJWpKtoa))puC4bcJrRy4N(swbjbfrvrDzm851REOonJ9Z5RFOJCV5ZtVD2nWCpsJHHVD86v7stsOI5sRIxV6x3LwDEd(pY5nYD(8MITWVhZslYpVjlTIbFEBr55n)n6(0S0rRxXhevdCZr95x4NlAo5HmAY6VF9Q4YugTmLGtz72rvzPX0isEsuc8dJskEge9WZBIHtxr0XI0CCtwCEdOJIDgu70CyBOLrvSY09uHkxMEu81Vh35ZBklye(am4e(EOdl11bT1GBYuNBIUCUdomt5YpHY3(s6tuswA(JYZtRcyt7kPhiP5c9zER(ykeuJMfQgPjjtRliO5of0v9OKGONyZwUGp(1ESNm0TULuNX8JIKgXKuamNLHtiIMxcO1r1hve)U0NmWj)dqddfMWiLpszJK7vmPIbwATnyFA8E)Oaw6bk3RnvbgbM449vrfBJy7OrSssspEo(PmsOpvJEidwq02S6YYVOyS5AP630u1ysEmnlcNKiaisqOOUaBE921dAG4xIW4DruVuiXjv4AVnqO3cDqCDUtbVfHL7qz)PanoBj5OHDFE6t0gmxy7fPG7f(UxJbqq8bR(ZVMvdqEAEfQWIqGJL0yopVTGan48)Q4XA6F(8gX1cN38pBwzdJDvVOoo(Vzo)hemurlpsZzG7smy7M7fQp48gGbHKbspzeCCvIdfd7hJ7Iu2pBb608YumOVadTaaDR7FP4V(c5kWW9iwbOGubdlpYe3QNqgk6HuQGexftstsb3gZV1T3Rn8XU)YUNOpU95U429DrP7Bt6kOz8nWMjfSC3mr9RnML6JS6sfRHPjhV)DMkpaF((jT6LyzwVgETf5NgRlfPDSJo5jS(dvaNcJE4iMuOfcSWyHPpLwftlXugTqJ9AtIGjUBWseQcRu(EkdZlnRGP(7gaYek9yeabtFChdcGpV50jzOnjPeemaVPrL1v74r3AXX)qrrgImQSfdBOitEJBS2PyI)yAWPw(O4k8PcVDdBfKyTiCfUkGY3upzok)CtwzU13hYkksYQRedRKhMXbXp9qxT2gHHuPg40u1VolpVqoajrptj7ZPvvMAUMHYppZRWz2Ehby4I2wlsrYnJXBzlOLW9U7HZIFAIgEpiqdZOtqiCZyjNygCV9OQDeaTdbIhh1icLuIB(MFQc7BZC1T5H6sidgGDd4jHB87Sv6F3pRIVTBGNdMXe6tLaucWBTUPoJMKU8MaXoEUlJogZe3ImzSgWogkbFpFlfkNEs3gF0Gx6hvZ7ZtYfMQGbzb9jsfipTDwoMF(N0CGnhJEsihGANIMlYnrUDhi)25nFlu)7iLl23sfgqp8dAA7fSz3B5NQDiGmGQpYV)r7C0oS)G7qpkAiyrQYrLusskNCPdGXCgcOJSQKx87C82sIsh78tCDi00tDKCbg5affa2TlSXfvvcglZepWasG6vZPzKuDaPTzJH0AAzH(WkIZcQWosb)whg6zIv5WYC5jo2bvYu8SgFUIb4qrchCQ99R9kz)waT0W4GTNjL5GdQcFDo4eLE4yrjt(cCFqGe)aadO)3AOkcGqSQaFXbsnR4aifyG4DK8hPvJoF)FhWWGNaQx8FNxvFefeobXEdsthW9HlRyIZviDyTtDQZP2EYWzZplBlqBlh9rQljGv6zAjmEDfUs8HAy40AebwXmA)ynZlVGBiQZ1MDsco5ecJ8aPcko((ZB(JWYuF0eXqQob5qM(t5WgOGMr1mxWG3BXdjFoR3nx0U0NcXXGVmviEflpkWVhCp2SKxEvK3lBPJZEFMwlVrsiwA5JG0o1zVG4W)V7pccBtkOVx(cv)FioHMhnjelVzbtVoxGyfZdNk8wNtv7vbAxWNCUaJQ8BxY3fiDRy2F29XvVY9Vkqolm0MEUMHfM6xcunoP6LbvDdNmQIle0KwvQH4WBR0jeFTEzpb5V5fc9vXnB5wxTk8LJPzY8dhcca0wU3ldh4MYYS4UqOTKLLfcRfVsRqaxTLifcnLzfnFvWaMMo5WsRZfVDZ5YHlL30L3lVPfgW(CMUUJ4D(MixkMBF8VdYFi4q1F(qJ6)j9TgDAyRWk2MMbf)(nN3y0SR7)gB97689YFy0L8f)dl(tws1Z(eTKCN9jktN7JPBxmqRTxoMU2bhxLR(DHgf4KP3O6lcfffucakaF9axD(yPa48D1oB15AXoXxkut9YPJvNPs)K)i2fZfQxFJRXDpRVBYqRVEGM01BxQylGlXvNKrZCfZrurmQaQ1FVyEVlesMTRARLP2Yft6xh5Ks9pT2RJK(BTEn2IHaTcKHPTDGx7NCrnPiR47vEBK7MpeNE7l8SCsxbOhdRa6S2gYHQw87MBkUWcbKVrgOEQst103ODIKan90lxmBy3t7YBMm0DhdnSe3TyM5MPHd6fMmRhlHr68DbRMUMfDerB69EG6ngE9BqmxaQFCiOXFdvTIHJPTlixSyAwGfJTiRGqdDe1slIYgov7aUy6qV4wp4WLZdYm4YF7(0ELpW)etW)1sxK5R(2UtcEVGnSbeMDrIoI0ay6a5Rhp8k8DJpDsh2U4MRhALPYraQ1UN1vD8b9pDYct3TgNXzNozCoUYXB9kvFlVY71DKHDTN71U0)52tdCvgCuGmVIsbwGpIDnErtRVV4ZmK2Pto6IyqIDYBwSgZaLNOxW3nDU0sz23ANXDWNUYJYO2P6Rn1dTnrxlSb1V4g7EcDPdo68ChnPTVWVzJBB)FFZIQ9Xdut7t2A1LlUz8q39t1uR0Ezb7IB(qVDFTJ2XF6bxIAGtv7YNCTn8qTFujVQM9Tnxl8UxJsprfPTJL3TyYyjAXsJDDiszzRMs6sqrB)zDiaEP(4Y72fZLTDW8BhpAIdb0wQSHsa(ADUVPsDsRDRUmvgpvqiA4fWG5Iv6TAnBxr56v)uXJj08CExUw))(]] ) -- Simplified placeholder
