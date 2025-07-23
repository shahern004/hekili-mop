-- MoP Brewmaster Monk (Data-Driven Rework V5.0)
-- Hekili Specialization File with SimulationCraft APL
-- Last Updated: July 22, 2025

-- Boilerplate and Class Check
local _, playerClass = UnitClass('player')
if playerClass ~= 'MONK' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

-- Initialize all required state tables
state.abilities = state.abilities or {}
state.buff = state.buff or {}
state.debuff = state.debuff or {}
state.talent = state.talent or {}
state.pvp = state.pvp or {}
state.set_bonus = state.set_bonus or {}
state.items = state.items or {}

local spec = Hekili:NewSpecialization( 268, true ) -- Brewmaster spec ID for MoP, force enable
if not spec then
    print("Brewmaster: Failed to initialize specialization (ID 268).")
    return
end

-- =================================================================
--                        Advanced State Tracking
-- =================================================================
function spec:GetStaggerLevel()
    if state.buff.heavy_stagger.up then return "heavy" end
    if state.buff.moderate_stagger.up then return "moderate" end
    if state.buff.light_stagger.up then return "light" end
    return "none"
end

-- Resource registration for Energy (3) and Chi (12).
spec:RegisterResource(3, { -- Energy
    base_regen = function() 
        local b = 10 
        if state.talent.ascension.enabled then b = b * 1.15 end 
        if state.buff.energizing_brew.up then b = b + 20 end 
        return b 
    end,
})

spec:RegisterResource(12, { -- Chi
    max = function() return state.talent.ascension.enabled and 5 or 4 end,
})

-- Comprehensive Gear, Talent, and Glyph Registration
spec:RegisterGear( "tier14", 85468, 85471, 85474, 85477, 85480 )
spec:RegisterGear( "tier15", 95094, 95097, 95100, 95103, 95106 )
spec:RegisterGear( "tier16", 99250, 99253, 99256, 99259, 99262 )
spec:RegisterGear( "legendary_cloak_tank", 102246 )
spec:RegisterGear( "steadfast_talisman", 102305 )
spec:RegisterGear( "thoks_tail_tip", 102300 )
spec:RegisterGear( "haromms_talisman", 102298 )

spec:RegisterTalents({
    celerity        = { 1, 1, 115173 },
    tigers_lust     = { 1, 2, 116841 },
    momentum        = { 1, 3, 115294 },
    chi_wave        = { 2, 1, 115098 },
    zen_sphere      = { 2, 2, 124081 },
    chi_burst       = { 2, 3, 123986 },
    power_strikes   = { 3, 1, 121817 },
    ascension       = { 3, 2, 115396 },
    chi_brew        = { 3, 3, 115399 },
    ring_of_peace   = { 4, 1, 116844 },
    charging_ox_wave= { 4, 2, 119392 },
    leg_sweep       = { 4, 3, 119381 },
    healing_elixirs = { 5, 1, 122280 },
    dampen_harm     = { 5, 2, 122278 },
    diffuse_magic   = { 5, 3, 122783 },
    rushing_jade_wind = { 6, 1, 116847 },
    invoke_xuen     = { 6, 2, 123904 },
    chi_torpedo     = { 6, 3, 115008 },
})

spec:RegisterGlyphs( {
    [146961] = "clash",
    [125672] = "expel_harm",
    [125687] = "fortifying_brew",
    [125677] = "guard",
    [146958] = "stoneskin",
    [125679] = "touch_of_death",
})

-- Brewmaster Auras and Debuffs
spec:RegisterAuras({
    shuffle = { id = 115307, duration = 6 },
    guard = { id = 115295, duration = 30 },
    elusive_brew_stack = { id = 128938, duration = 30, max_stack = 15 },
    elusive_brew = { id = 128939 },
    fortifying_brew = { id = 115203, duration = 20 },
    heavy_stagger = { id = 124273, duration = 10 },
    moderate_stagger = { id = 124274, duration = 10 },
    light_stagger = { id = 124275, duration = 10 },
    breath_of_fire_dot = { id = 123725, duration = 8, debuff = true },
    stance_of_the_sturdy_ox = { id = 115069 },
})

-- Fully Comprehensive Brewmaster Ability List
spec:RegisterAbilities({
    keg_smash = { 
        id = 121253, 
        cooldown = 8, 
        spend = 40, 
        spendType = "energy", 
        handler = function() gain(2, "chi") end 
    },
    blackout_kick = { 
        id = 100784, 
        spend = 2, 
        spendType = "chi", 
        handler = function() applyBuff("player", "shuffle") end 
    },
    jab = { 
        id = 100780, 
        spend = 40, 
        spendType = "energy", 
        handler = function() gain(1, "chi") end 
    },
    expel_harm = { 
        id = 115072, 
        cooldown = 15, 
        spend = 40, 
        spendType = "energy", 
        handler = function() gain(1, "chi") end 
    },
    tiger_palm = { 
        id = 100787, 
        spend = 25, 
        spendType = "energy" 
    },
    breath_of_fire = { 
        id = 115181, 
        spend = 2, 
        spendType = "chi", 
        handler = function() applyDebuff("target", "breath_of_fire_dot") end 
    },
    spinning_crane_kick = { 
        id = 101546, 
        spend = 40, 
        spendType = "energy" 
    },
    rushing_jade_wind = { 
        id = 116847, 
        cooldown = 6, 
        spend = 40, 
        spendType = "energy", 
        talent = "rushing_jade_wind" 
    },
    purifying_brew = { 
        id = 119582, 
        cooldown = 1, 
        spend = 1, 
        spendType = "chi", 
        toggle = "defensives" 
    },
    guard = { 
        id = 115295, 
        cooldown = 30, 
        spend = 2, 
        spendType = "chi", 
        toggle = "defensives" 
    },
    elusive_brew = { 
        id = 115308, 
        cooldown = 1, 
        toggle = "defensives", 
        handler = function() 
            local s = state.buff.elusive_brew_stack.stack or 0
            removeBuff("player", "elusive_brew_stack")
            applyBuff("player", "elusive_brew", s) 
        end 
    },
    fortifying_brew = { 
        id = 115203, 
        cooldown = 180, 
        toggle = "cooldowns" 
    },
    zen_meditation = { 
        id = 115176, 
        cooldown = 180, 
        toggle = "defensives" 
    },
    dampen_harm = { 
        id = 122278, 
        cooldown = 90, 
        toggle = "defensives", 
        talent = "dampen_harm" 
    },
    diffuse_magic = { 
        id = 122783, 
        cooldown = 90, 
        toggle = "defensives", 
        talent = "diffuse_magic" 
    },
    provoke = { 
        id = 115546, 
        cooldown = 8, 
        toggle = "threat" 
    },
    summon_black_ox_statue = { 
        id = 115315, 
        cooldown = 30, 
        toggle = "cooldowns" 
    },
    stance_of_the_sturdy_ox = { 
        id = 115069, 
        handler = function() applyBuff("player", "stance_of_the_sturdy_ox") end 
    },
    energizing_brew = { 
        id = 115288, 
        cooldown = 60, 
        toggle = "cooldowns" 
    },
    chi_brew = { 
        id = 115399, 
        cooldown = 45, 
        charges = 2, 
        talent = "chi_brew", 
        handler = function() gain(2, "chi") end 
    },
    chi_wave = { 
        id = 115098, 
        cooldown = 15, 
        talent = "chi_wave" 
    },
    invoke_xuen = { 
        id = 123904, 
        cooldown = 180, 
        toggle = "cooldowns", 
        talent = "invoke_xuen" 
    },
    spear_hand_strike = { 
        id = 116705, 
        cooldown = 15, 
        interrupt = true 
    },
})

-- Deep Intuitive State Expressions
spec:RegisterStateExpr("stagger_dtps", function() 
    return 0 -- Placeholder for stagger damage tracking
end)

spec:RegisterStateExpr("stagger_threat_level", function() 
    return 0 -- Placeholder for stagger threat calculation
end)

spec:RegisterStateExpr("time_to_next_shuffle", function() 
    local n = 2 - state.chi.current
    if n <= 0 then return 0 end
    local e = n * 40 - state.energy.current
    if e <= 0 then return n * state.gcd.max end
    return (e / state.energy.regen) + (n * state.gcd.max)
end)

-- User Settings
spec:RegisterSetting( "proactive_shuffle", true, { 
    name = "Proactive Shuffle Management", 
    type = "toggle" 
})

spec:RegisterSetting( "stagger_threat_threshold", 70, { 
    name = "Stagger Threat Threshold", 
    type = "range", 
    min = 20, 
    max = 120, 
    step = 5 
})

spec:RegisterSetting( "elusive_brew_threshold", 8, { 
    name = "Elusive Brew Stack Threshold", 
    type = "range", 
    min = 1, 
    max = 15, 
    step = 1 
})

spec:RegisterSetting( "guard_health_threshold", 65, { 
    name = "Reactive Guard Health %", 
    type = "range", 
    min = 30, 
    max = 90, 
    step = 5 
})

spec:RegisterSetting( "fortify_health_pct", 35, {
    name = function() return string.format( "Use %s Below Health %%", Hekili:GetSpellLinkWithTexture( spec.abilities.fortifying_brew.id ) ) end,
    desc = "The health percentage at which Fortifying Brew will be recommended as an emergency defensive cooldown.",
    type = "range", 
    min = 0, 
    max = 100, 
    step = 5, 
    width = "full"
})

spec:RegisterPack("Brewmaster V5.0 (Data-Driven)", 20250722, [[Hekili:Tw1wVTjmu4FlttkpSlSCrPRBkjpSN2Q06lPpdXyFa7IXgzBAkrr8BFhdekKe12hMIccoh)9DU4ZLWzHpeULrCq49ZNoF50VpFEWSBx(JWTUQciCBbHMrsXxuKC85VmWEVWkPMW8qT6sdfveUnUuiD)rfgJclakY3n3gULlymOridS0WTpWf26D()K6DDKxVtNGFtDcTQENuyDO6eTPE3VHmHueGw0Otes0oF8J17(RwL9Z6DEFjNyDGP(ou8DTeydkmavNhtCFE93SoIIcr6KihhISUsdRks)81pmLlIIlnw3xejRDejOCb9YcafjwcSRdvcPeA1j7SNlCqKtK6DTEaE3PaiMiorXqFXiYGwlzsbxadIltscOyejuPbgaHneBPfIqAZTdfgl1AwusPPAKuWybtgsZqPedLOq3sBmyKnuJsKJHwumMq9ouNNKG(AqzXXJDFxOLv5AtbFOqoYM2FSH8Xi5fGcJttUNpHcZtOZeHYXR7OzlNon3UHdePJhKtE(ttdwmP1MAJtKu5pS3Bcy69Qrmlss8jcKhb9)a3tAiQd86zdn1zh3BSowlOUvlwE847X2lhxauuAoJtScnfRtcqupv9(oAUMbgSLTnSSC8PeWcMCIqz3S(Mjyr7MXbtgKgzXMfUNhu9Qfd1cpxaY(RluT35)Alltge0RVD5qyPLedRdXM1ZhQQPTPZTh2j5Z7DnsEVC1yV8aw0yl4GbgG7fH9i)GtqpV62t)EYtWzw0l6IwxFillTINEPMVjvouyaMTPzycy64BWyjkwx6IYqFOh5PlHZRxV40TPQREZTA9nJMv0Q9nbnBS)zkTCFrZJegoisOydsixORpJ6XJboOGCbG1qlU4Y8TMl(6uGzuIJ7NpMiAVDzAxWyPdcPxNmBHqP8Xb14hODk1EbMjNQlhpb5WHMUko5aCDyNgilA3ECznqZK9OcImVVaOtKEp2F2u5mUd7nq0h5Ja9ij(Y(XRZA429eJpNy9RIjLoCUmUSLq1XnBSBwQ2SQhsiLsh(69nR(7U98lOB5TbToYY1Uq)VT9R5E)yA)f(V]])

print("Brewmaster: Data-Driven Rework V5.0 with SimulationCraft APL loaded.")
