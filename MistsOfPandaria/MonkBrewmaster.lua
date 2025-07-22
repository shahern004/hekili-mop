-- MonkBrewmaster.lua
-- Updated July 21, 2025 - Modern Structure
-- Mists of Pandaria module for Monk: Brewmaster spec

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass("player")
if playerClass ~= "MONK" then return end

local addon, ns = ...
local Hekili = _G[addon]
local class, state = Hekili.Class, Hekili.State

-- Initialize state.items to prevent 'attempt to index field "items" (a nil value)' error
state.items = state.items or {}

-- Initialize specialization
local spec = Hekili:NewSpecialization(268) -- Brewmaster spec ID
if not spec then
    print("Brewmaster: Failed to initialize specialization (ID 268).")
    return
end

-- Helper function for compatibility
local function getReferences()
    return class, state
end

-- MoP-specific aura detection
local function GetPlayerAuraBySpellID(spellID)
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

-- Target debuff detection
local function GetTargetDebuffByID(spellID, caster)
    caster = caster or "player"
    local name, icon, count, debuffType, duration, expirationTime, unitCaster = ns.FindUnitDebuffByID("target", spellID)
    if name and (unitCaster == caster or caster == "any") then
        return name, icon, count, debuffType, duration, expirationTime, unitCaster
    end
    return nil
end

-- Combat Log Event Frame for tracking
local brewmaster_combat_log_frame = CreateFrame("Frame")
brewmaster_combat_log_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
brewmaster_combat_log_frame:SetScript("OnEvent", function(self, event, ...)
    local timestamp, eventType, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID, spellName = ...
    
    if sourceGUID ~= UnitGUID("player") then return end

    -- Track Chi-generating abilities
    if eventType == "SPELL_CAST_SUCCESS" then
        if spellID == 100780 or spellID == 121253 then -- Tiger Palm, Keg Smash
            ns.last_chi_ability = GetTime()
        end
    end

    -- Track Elusive Brew stacks
    if eventType == "SPELL_AURA_APPLIED_DOSE" or eventType == "SPELL_AURA_REFRESH" then
        if spellID == 115308 then -- Elusive Brew
            local _, _, count = GetPlayerAuraBySpellID(115308)
            ns.elusive_brew_stacks = count or 0
        end
    end
end)

-- Resource Registration (Energy and Chi)
spec:RegisterResource(3, { -- Energy = 3 in MoP
    tiger_palm = {
        last = function()
            return state.abilities.tiger_palm.lastCast
        end,
        interval = function()
            return state.abilities.tiger_palm.cooldown
        end,
        stop = function()
            return state.abilities.tiger_palm.lastCast == 0
        end,
        value = function()
            return 50 -- Tiger Palm costs 50 energy
        end,
    },
    keg_smash = {
        last = function()
            return state.abilities.keg_smash.lastCast
        end,
        interval = function()
            return state.abilities.keg_smash.cooldown
        end,
        stop = function()
            return state.abilities.keg_smash.lastCast == 0
        end,
        value = function()
            return 40 -- Keg Smash costs 40 energy
        end,
    },
})

spec:RegisterResource(12, { -- Chi = 12 in MoP
    tiger_palm = {
        last = function()
            return state.abilities.tiger_palm.lastCast
        end,
        interval = function()
            return state.abilities.tiger_palm.cooldown
        end,
        stop = function()
            return state.abilities.tiger_palm.lastCast == 0
        end,
        value = 1,
    },
    keg_smash = {
        last = function()
            return state.abilities.keg_smash.lastCast
        end,
        interval = function()
            return state.abilities.keg_smash.cooldown
        end,
        stop = function()
            return state.abilities.keg_smash.lastCast == 0
        end,
        value = 2,
    },
    expel_harm = {
        last = function()
            return state.abilities.expel_harm.lastCast
        end,
        interval = function()
            return state.abilities.expel_harm.cooldown
        end,
        stop = function()
            return state.abilities.expel_harm.lastCast == 0
        end,
        value = 2,
    },
})

-- Gear and Tier Sets
spec:RegisterGear("tier14", 85324, 85325, 85326, 85327, 85328) -- T14 White Tiger Battlegear
spec:RegisterGear("tier14_lfr", 86664, 86665, 86666, 86667, 86668) -- LFR versions
spec:RegisterGear("tier14_heroic", 87084, 87085, 87086, 87087, 87088) -- Heroic versions

spec:RegisterGear("tier15", 95265, 95266, 95267, 95268, 95269) -- T15 Battlegear of the Lightning Emperor
spec:RegisterGear("tier15_lfr", 95895, 95896, 95897, 95898, 95899) -- LFR versions
spec:RegisterGear("tier15_heroic", 96639, 96640, 96641, 96642, 96643) -- Heroic versions

spec:RegisterGear("tier16", 99117, 99118, 99119, 99120, 99121) -- T16 Battlegear of Winged Triumph
spec:RegisterGear("tier16_lfr", 98970, 98971, 98972, 98973, 98974) -- LFR versions
spec:RegisterGear("tier16_heroic", 99357, 99358, 99359, 99360, 99361) -- Heroic versions

-- Notable Items
spec:RegisterGear("legendary_cloak", 102249) -- Qian-Ying, Fortitude of Niuzao
spec:RegisterGear("prideful_gladiator", 103808, 103809, 103810, 103811, 103812) -- PvP gear

-- Tier Set Bonuses as Auras
spec:RegisterAura("brewmaster_tier14_2pc", {
    id = 123113,
    duration = 3600,
    max_stack = 1,
})

spec:RegisterAura("brewmaster_tier14_4pc", {
    id = 123114,
    duration = 3600,
    max_stack = 1,
})

spec:RegisterAura("brewmaster_tier15_2pc", {
    id = 138169,
    duration = 3600,
    max_stack = 1,
})

spec:RegisterAura("brewmaster_tier15_4pc", {
    id = 138170,
    duration = 3600,
    max_stack = 1,
})

spec:RegisterAura("brewmaster_tier16_2pc", {
    id = 144609,
    duration = 3600,
    max_stack = 1,
})

spec:RegisterAura("brewmaster_tier16_4pc", {
    id = 144610,
    duration = 3600,
    max_stack = 1,
})

-- Talents (MoP 6-tier talent system)
spec:RegisterTalents({
    -- Tier 1 (Level 15) - Mobility
    celerity = { 1, 1, 115173 }, -- Roll gains 1 additional charge
    tigers_lust = { 1, 2, 116841 }, -- Increases movement speed by 70% for 6 sec
    momentum = { 1, 3, 115399 }, -- Roll and Chi Torpedo increase movement speed by 25% for 10 sec

    -- Tier 2 (Level 30) - Healing
    chi_wave = { 2, 1, 115098 }, -- Bounces between allies and enemies, healing or damaging
    zen_sphere = { 2, 2, 124081 }, -- Places a sphere that periodically heals or damages
    chi_burst = { 2, 3, 123986 }, -- Heals allies or damages enemies in a line

    -- Tier 3 (Level 45) - Utility
    power_strikes = { 3, 1, 121817 }, -- Every 15 sec, gain 1 Chi or reset Jab cooldown
    ascension = { 3, 2, 115396 }, -- Increases max Chi by 1 and energy regen by 15%
    chi_brew = { 3, 3, 115399 }, -- Generates 2 Chi, 60 sec cooldown

    -- Tier 4 (Level 60) - Survivability
    healing_elixirs = { 4, 1, 122280 }, -- Heals for 15% when below 35% health
    dampen_harm = { 4, 2, 122278 }, -- Reduces damage taken by 50% for 10 sec
    diffuse_magic = { 4, 3, 122783 }, -- Reduces magic damage taken by 90% for 6 sec

    -- Tier 5 (Level 75) - Control
    ring_of_peace = { 5, 1, 116844 }, -- Silences or disarms enemies in an area
    charging_ox_wave = { 5, 2, 119392 }, -- Stuns enemies in a line
    leg_sweep = { 5, 3, 119381 }, -- Stuns enemies within 5 yards

    -- Tier 6 (Level 90) - DPS/Utility
    rushing_jade_wind = { 6, 1, 116847 }, -- Deals AoE damage and increases Shuffle duration
    invoke_xuen = { 6, 2, 123904 }, -- Summons Xuen to fight for 45 sec
    chi_torpedo = { 6, 3, 115008 }, -- Replaces Roll, deals damage and heals
})

-- Glyphs
spec:RegisterGlyphs({
    -- Major Glyphs
    [115930] = "blackout_kick", -- Blackout Kick refunds 1 Chi if it doesn't kill
    [115933] = "breath_of_fire", -- Breath of Fire disorients targets
    [115934] = "clash", -- Increases Clash range by 10 yards
    [115935] = "fortuitous_spheres", -- Chi Sphere has 20% chance to heal
    [115936] = "guard", -- Guard absorbs 10% more damage
    [115937] = "keg_smash", -- Keg Smash deals 10% more damage
    [115938] = "zen_meditation", -- Zen Meditation can be cast while moving
    [123401] = "fortifying_brew", -- Fortifying Brew increases health by 20% instead
    [124081] = "zen_meditation", -- Reduces Zen Meditation cooldown by 50%
    [125069] = "spirit_roll", -- Roll can be used while stunned
})

-- Auras
spec:RegisterAuras({
    shuffle = {
        id = 115307,
        duration = function()
            return 6 + (state.talent.rushing_jade_wind.enabled and 6 or 0)
        end,
        max_stack = 1,
        generate = function(t)
            local name, _, count, _, duration, expirationTime, caster = GetPlayerAuraBySpellID(115307)
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    elusive_brew = {
        id = 115308,
        duration = 30,
        max_stack = 15,
        generate = function(t)
            local name, _, count, _, duration, expirationTime, caster = GetPlayerAuraBySpellID(115308)
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    fortifying_brew = {
        id = 115203,
        duration = function()
            return state.glyph.fortifying_brew.enabled and 20 or 15
        end,
        max_stack = 1,
        generate = function(t)
            local name, _, count, _, duration, expirationTime, caster = GetPlayerAuraBySpellID(115203)
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    dampen_harm = {
        id = 122278,
        duration = 10,
        max_stack = 1,
        generate = function(t)
            local name, _, count, _, duration, expirationTime, caster = GetPlayerAuraBySpellID(122278)
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    diffuse_magic = {
        id = 122783,
        duration = 6,
        max_stack = 1,
        generate = function(t)
            local name, _, count, _, duration, expirationTime, caster = GetPlayerAuraBySpellID(122783)
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    keg_smash_debuff = {
        id = 121253,
        duration = 15,
        max_stack = 1,
        generate = function(t)
            local name, _, count, _, duration, expirationTime, caster = GetTargetDebuffByID(121253, "player")
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
    breath_of_fire_debuff = {
        id = 123725,
        duration = 8,
        max_stack = 1,
        generate = function(t)
            local name, _, count, _, duration, expirationTime, caster = GetTargetDebuffByID(123725, "player")
            if name then
                t.name = name
                t.count = count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },
})

-- Abilities
spec:RegisterAbilities({
    blackout_kick = {
        id = 100784,
        cast = 0,
        cooldown = 3,
        gcd = "spell",
        spend = 2,
        spendType = "chi",
        startsCombat = true,
        texture = 574791,
        handler = function()
            applyBuff("shuffle", 6)
        end,
    },
    keg_smash = {
        id = 121253,
        cast = 0,
        charges = 2,
        cooldown = 8,
        gcd = "spell",
        spend = 40,
        spendType = "energy",
        startsCombat = true,
        texture = 604965,
        handler = function()
            applyDebuff("target", "keg_smash_debuff")
            gain(2, "chi")
        end,
    },
    rushing_jade_wind = {
        id = 116847,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        spend = 25,
        spendType = "energy",
        startsCombat = true,
        texture = 606553,
        handler = function()
            if state.buff.shuffle.up then
                applyBuff("shuffle", state.buff.shuffle.remains + 6)
            end
        end,
    },
    tiger_palm = {
        id = 100780,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = 50,
        spendType = "energy",
        startsCombat = true,
        texture = 606551,
        handler = function()
            gain(1, "chi")
        end,
    },
    spinning_crane_kick = {
        id = 101546,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        spend = 25,
        spendType = "energy",
        startsCombat = true,
        texture = 606543,
        handler = function()
            -- AoE damage, no Chi generation
        end,
    },
    breath_of_fire = {
        id = 115181,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        spend = 2,
        spendType = "chi",
        startsCombat = true,
        texture = 615339,
        handler = function()
            applyDebuff("target", "breath_of_fire_debuff")
        end,
    },
    purifying_brew = {
        id = 119582,
        cast = 0,
        charges = 2,
        cooldown = 12,
        gcd = "off",
        spend = 1,
        spendType = "chi",
        startsCombat = false,
        texture = 133701,
        handler = function()
            -- Clears Stagger damage
        end,
    },
    fortifying_brew = {
        id = 115203,
        cast = 0,
        cooldown = 360,
        gcd = "off",
        startsCombat = false,
        texture = 629482,
        toggle = "defensives",
        handler = function()
            applyBuff("fortifying_brew")
        end,
    },
    expel_harm = {
        id = 115072,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        spend = 15,
        spendType = "energy",
        startsCombat = true,
        texture = 606550,
        handler = function()
            gain(2, "chi")
        end,
    },
    chi_torpedo = {
        id = 115008,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        startsCombat = true,
        texture = 607849,
        talent = "chi_torpedo",
        handler = function()
            -- Replaces Roll, deals damage and heals
        end,
    },
    provoke = {
        id = 115546,
        cast = 0,
        cooldown = 8,
        gcd = "off",
        startsCombat = true,
        texture = 620830,
        handler = function()
            -- Taunts target
        end,
    },
    roll = {
        id = 109132,
        cast = 0,
        charges = function()
            return state.talent.celerity.enabled and 3 or 2
        end,
        cooldown = 20,
        gcd = "off",
        startsCombat = false,
        texture = 574574,
        handler = function()
            -- Movement ability
        end,
    },
    spear_hand_strike = {
        id = 116705,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        startsCombat = true,
        texture = 642416,
        handler = function()
            -- Interrupts target
        end,
    },
    detox = {
        id = 115450,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        spend = 20,
        spendType = "energy",
        startsCombat = false,
        texture = 460856,
        handler = function()
            -- Removes Poison and Disease effects
        end,
    },
    transcendence = {
        id = 101643,
        cast = 0,
        cooldown = 10,
        gcd = "off",
        startsCombat = false,
        texture = 627608,
        handler = function()
            -- Places spirit for Transcendence: Transfer
        end,
    },
    transcendence_transfer = {
        id = 119996,
        cast = 0,
        cooldown = 45,
        gcd = "off",
        startsCombat = false,
        texture = 627608,
        handler = function()
            -- Teleports to spirit
        end,
    },
    black_ox_brew = {
        id = 115399,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        talent = "chi_brew",
        startsCombat = false,
        texture = 629482,
        handler = function()
            gain(2, "chi")
        end,
    },
    invoke_niuzao = {
        id = 132578,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        toggle = "cooldowns",
        startsCombat = true,
        texture = 627606,
        handler = function()
            -- Summons Niuzao to attack
        end,
    },
    chi_wave = {
        id = 115098,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        talent = "chi_wave",
        startsCombat = true,
        texture = 606548,
        handler = function()
            -- Heals or damages based on target
        end,
    },
    zen_sphere = {
        id = 124081,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        talent = "zen_sphere",
        startsCombat = true,
        texture = 606547,
        handler = function()
            -- Applies HoT or DoT based on target
        end,
    },
    chi_burst = {
        id = 123986,
        cast = 1,
        cooldown = 30,
        gcd = "spell",
        talent = "chi_burst",
        startsCombat = true,
        texture = 606542,
        handler = function()
            -- Heals or damages in a line
        end,
    },
    dampen_harm = {
        id = 122278,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        talent = "dampen_harm",
        toggle = "defensives",
        startsCombat = false,
        texture = 642418,
        handler = function()
            applyBuff("dampen_harm")
        end,
    },
    diffuse_magic = {
        id = 122783,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        talent = "diffuse_magic",
        toggle = "defensives",
        startsCombat = false,
        texture = 642418,
        handler = function()
            applyBuff("diffuse_magic")
        end,
    },
    ring_of_peace = {
        id = 116844,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        talent = "ring_of_peace",
        startsCombat = true,
        texture = 620831,
        handler = function()
            -- Silences or disarms enemies in area
        end,
    },
    charging_ox_wave = {
        id = 119392,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        talent = "charging_ox_wave",
        startsCombat = true,
        texture = 642417,
        handler = function()
            -- Stuns enemies in a line
        end,
    },
    leg_sweep = {
        id = 119381,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        talent = "leg_sweep",
        startsCombat = true,
        texture = 642414,
        handler = function()
            -- Stuns enemies within 5 yards
        end,
    },
    invoke_xuen = {
        id = 123904,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        talent = "invoke_xuen",
        toggle = "cooldowns",
        startsCombat = true,
        texture = 620832,
        handler = function()
            -- Summons Xuen to attack
        end,
    },
})

-- Options
spec:RegisterOptions({
    enabled = true,
    aoe = 3,
    nameplates = true,
    nameplateRange = 8,
    damage = true,
    damageExpiration = 8,
    potion = "jade_serpent_potion",
    package = "Brewmaster",
})

-- Event Handler for Initialization
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        local _, playerClass = UnitClass("player")
        if playerClass ~= "MONK" then return end
        local specID = GetSpecializationInfo(GetSpecialization())
        if specID == 268 then
            state.items = state.items or {}
            if not class.abilities then
                print("Brewmaster: Hekili.Class.abilities is nil. Aborting.")
                return
            end
            if not spec then
                print("Brewmaster: Failed to initialize specialization (ID 268).")
                return
            end
        end
    end
    -- Update equipped items on gear change
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        state.items = state.items or {}
        for i = 0, 19 do
            local itemID = GetInventoryItemID("player", i)
            if itemID then
                state.items[itemID] = { equipped = true }
            end
        end
    end
end)

-- Register default pack for MoP Brewmaster Monk
spec:RegisterPack( "Brewmaster", 20250517, [[Hekili:T3vBVTTnu4FldiHr5osojoRZh7KvA3KRJvA2jDLA2jz1yvfbpquu6iqjvswkspfePtl6VGQIQUnbJeHAVQDcOWrbE86CaE4GUwDBB4CvC5m98jdNZzDX6w)v)V(i)h(jDV7GFWEh)9T6rhFQVnSVzsmypSlD2OXqskYJCKfpPWXt87zPkZGZVRSLAXYUYORTmYLwaXlyc8LkGusGO7469JwjTfTH0PwPbJaeivvLsvrfoeQtcGbWlG0A)Ff9)8jPyqXgkz5Qkz5kLRyR12Uco1veB5MUOfIMXnV2Nw8UqEkeUOLXMFtKUOMcEvjzmqssgiE37NuLYlP5NnNgEE5(vJDjgvCeXmQVShsbh(AfIigS2JOmiUeXm(KJ0JkOtQu0Ky)iYcJvqQrthQ(5Fcu5ILidEZjQ0CoYXj)USIip9kem)i81l2cOFLlk9cKGk5nuuDXZes)SEHXiZdLP1gpb968CvpxbSVDaPzgwP6ahsQWnRs)uOKnc0)]] )

print("Brewmaster: Script loaded successfully.")
