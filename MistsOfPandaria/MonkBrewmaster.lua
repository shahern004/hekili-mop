```lua
-- MoP Brewmaster Monk (Data-Driven Rework V6.0)
-- Hekili Specialization File
-- Author: Gemini & User Collaboration
-- Last Updated: July 22, 2025

-- Boilerplate and Class Check
if not Hekili or not Hekili.NewSpecialization then return end
if select(2, UnitClass('player')) ~= 'MONK' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

-- Helper functions
local strformat = string.format

-- Brewmaster specific combat log tracking
local bm_combat_log_events = {}

local function RegisterBMCombatLogEvent(event, callback)
    if not bm_combat_log_events[event] then
        bm_combat_log_events[event] = {}
    end
    table.insert(bm_combat_log_events[event], callback)
end

-- Hook into combat log for Brewmaster-specific tracking
local bmCombatLogFrame = CreateFrame("Frame")
bmCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
bmCombatLogFrame:SetScript("OnEvent", function(self, event)
    local timestamp, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID, _, _, amount, _, _, _, _, _, critical = CombatLogGetCurrentEventInfo()
    if sourceGUID ~= state.GUID and destGUID ~= state.GUID then return end

    if bm_combat_log_events[subevent] then
        for _, callback in ipairs(bm_combat_log_events[subevent]) do
            callback(timestamp, subevent, sourceGUID, destGUID, spellID, amount, critical)
        end
    end
end)


local function RegisterBrewmasterSpec()
    if not class or not state or not Hekili.NewSpecialization then return end

    local spec = Hekili:NewSpecialization( 268 ) -- Brewmaster spec ID for MoP
    if not spec then return end -- Not ready yet

    --[[
        Resource registration for Energy (3) and Chi (12).
    ]]
    spec:RegisterResource(3, { -- Energy
        base_regen = function()
            local base = 10
            if state.talent.ascension.enabled then base = base * 1.15 end
            if state.buff.energizing_brew.up then base = base + 20 end
            return base * state.haste
        end,
    })
    spec:RegisterResource(12, { -- Chi
        max = function() return state.talent.ascension.enabled and 5 or 4 end,
    })

    --[[
        Comprehensive Gear, Talent, and Glyph Registration
    ]]
    -- Tier Sets
    spec:RegisterGear( "tier14", 85468, 85471, 85474, 85477, 85480 )
    spec:RegisterGear( "tier15", 95094, 95097, 95100, 95103, 95106 )
    spec:RegisterGear( "tier16", 99250, 99253, 99256, 99259, 99262 )

    -- Tier Set Bonuses (as functions)
    spec:RegisterGear( "tier14_2pc", function() return state.set_bonus.tier14_2pc end)
    spec:RegisterGear( "tier14_4pc", function() return state.set_bonus.tier14_4pc end)
    spec:RegisterGear( "tier15_2pc", function() return state.set_bonus.tier15_2pc end)
    spec:RegisterGear( "tier15_4pc", function() return state.set_bonus.tier15_4pc end)
    spec:RegisterGear( "tier16_2pc", function() return state.set_bonus.tier16_2pc end)
    spec:RegisterGear( "tier16_4pc", function() return state.set_bonus.tier16_4pc end)

    -- Legendary and Notable Items
    spec:RegisterGear( "legendary_cloak_tank", 102246 )
    spec:RegisterGear( "steadfast_talisman", 102305 )
    spec:RegisterGear( "thoks_tail_tip", 102300 )
    spec:RegisterGear( "haromms_talisman", 102298 )

    -- Talents
    spec:RegisterTalents({
        celerity        = { 1, 1, 115173, "Grants an extra charge of Roll and reduces its cooldown." },
        tigers_lust     = { 1, 2, 116841, "Increases movement speed and removes roots and snares." },
        momentum        = { 1, 3, 115294, "Rolling increases your movement speed." },
        chi_wave        = { 2, 1, 115098, "A wave of Chi energy that bounces between friends and foes, dealing damage and healing." },
        zen_sphere      = { 2, 2, 124081, "Forms a sphere of Chi that heals an ally or damages an enemy." },
        chi_burst       = { 2, 3, 123986, "Hurls a torrent of Chi energy forward, dealing damage and healing." },
        power_strikes   = { 3, 1, 121817, "Your Jab, Expel Harm, and Spinning Crane Kick generate an extra Chi on a 20 sec internal cooldown." },
        ascension       = { 3, 2, 115396, "Increases your maximum Chi by 1, and your energy regeneration by 15%." },
        chi_brew        = { 3, 3, 115399, "Instantly generates 2 Chi and 2 stacks of Elusive Brew." },
        ring_of_peace   = { 4, 1, 116844, "Forms a sanctuary that incapacitates enemies." },
        charging_ox_wave= { 4, 2, 119392, "A forward-charging ox that stuns all enemies in its path." },
        leg_sweep       = { 4, 3, 119381, "Knocks down all enemies within 5 yards, stunning them." },
        healing_elixirs = { 5, 1, 122280, "You gain a charge of Healing Elixirs every 18s, which automatically heal you if you drop below 35% health." },
        dampen_harm     = { 5, 2, 122278, "Reduces damage from the next 3 attacks that deal 10% or more of your health." },
        diffuse_magic   = { 5, 3, 122783, "Reduces magic damage taken by 90% and clears magical effects." },
        rushing_jade_wind = { 6, 1, 116847, "A whirling tornado that deals damage to nearby enemies." },
        invoke_xuen     = { 6, 2, 123904, "Summons Xuen, the White Tiger, to fight by your side." },
        chi_torpedo     = { 6, 3, 115008, "Replaces Roll. You torpedo a long distance, healing yourself and dealing damage." },
    })

    -- Glyphs
    spec:RegisterGlyphs( {
        [146961] = "clash",
        [125672] = "expel_harm",
        [125687] = "fortifying_brew", -- Increases health bonus but removes damage reduction.
        [125677] = "guard", -- Guard also increases healing received.
        [146958] = "stoneskin", -- Increases the amount of damage absorbed by Guard.
        [125679] = "touch_of_death",
    })

    -- Brewmaster Auras and Debuffs
    spec:RegisterAuras({
        -- Core Brewmaster Buffs
        shuffle = { id = 115307, duration = 6, dr_type = "parry" },
        guard = { id = 115295, duration = 30, absorb = true },
        elusive_brew_stack = { id = 128938, duration = 30, max_stack = 15 },
        elusive_brew = { id = 128939, dr_type = "dodge" },
        stance_of_the_sturdy_ox = { id = 115069 },
        energizing_brew = { id = 115288, duration = 20 },

        -- Cooldowns & Defensives
        fortifying_brew = { id = 115203, duration = 20, dr = 0.2 },
        dampen_harm = { id = 122278, duration = 45, max_stack = 3 },
        diffuse_magic = { id = 122783, duration = 6, dr_type = "magic" },
        zen_meditation = { id = 115176, duration = 8, dr = 0.9 },

        -- Stagger Debuffs
        heavy_stagger = { id = 124273, duration = 10, debuff = true, aoe = true },
        moderate_stagger = { id = 124274, duration = 10, debuff = true, aoe = true },
        light_stagger = { id = 124275, duration = 10, debuff = true, aoe = true },

        -- Target Debuffs
        breath_of_fire_dot = { id = 123725, duration = 8, debuff = true, dot = true },
        weakened_blows = { id = 115798, duration = 30, debuff = true }, -- From Keg Smash

        -- Tier Set Bonuses
        tier14_4pc = { id = 124473, duration = 12 }, -- Your Purifying Brew also heals you.
        tier16_2pc = { id = 144634, duration = 10 }, -- Dodging an attack gives you 2 Chi.
    })


    --[[
        Brewmaster Ability List
    ]]
    spec:RegisterAbilities({
        -- Core Rotational Abilities
        keg_smash = { id = 121253, cooldown = 8, spend = 40, spendType = "energy",
            handler = function() state.gainResource(2, "chi"); state.applyDebuff("target", "weakened_blows", 30) end },
        blackout_kick = { id = 100784, spend = 2, spendType = "chi",
            handler = function() state.applyBuff("player", "shuffle", 6) end },
        jab = { id = 100780, spend = 40, spendType = "energy",
            handler = function() state.gainResource(1, "chi") end },
        tiger_palm = { id = 100787, spend = 25, spendType = "energy" },
        expel_harm = { id = 115072, cooldown = 15, spend = 40, spendType = "energy",
            handler = function() state.gainResource(1, "chi") end },
        breath_of_fire = { id = 115181, spend = 2, spendType = "chi",
            handler = function() state.applyDebuff("target", "breath_of_fire_dot", 8) end },

        -- AoE Abilities
        spinning_crane_kick = { id = 101546, spend = 40, spendType = "energy", aoe = true,
            usable = function() return state.enemies.in_melee >= 3 end },
        rushing_jade_wind = { id = 116847, cooldown = 6, spend = 1, spendType = "chi", talent = "rushing_jade_wind", aoe = true },

        -- Active Mitigation
        purifying_brew = { id = 119582, cooldown = 1, spend = 1, spendType = "chi", toggle = "defensives",
            usable = function() local level = spec:GetStaggerLevel(); return level == "heavy" or level == "moderate" end },
        guard = { id = 115295, cooldown = 30, spend = 2, spendType = "chi", toggle = "defensives",
            handler = function() state.applyBuff("player", "guard", 30) end },
        elusive_brew = { id = 115308, cooldown = 1, toggle = "defensives",
            usable = function() return state.buff.elusive_brew_stack.stack >= state.settings.elusive_brew_threshold end,
            handler = function()
                local s = state.buff.elusive_brew_stack.stack or 0
                state.removeBuff("player", "elusive_brew_stack")
                state.applyBuff("player", "elusive_brew", s)
            end },

        -- Cooldowns
        fortifying_brew = { id = 115203, cooldown = 180, toggle = "cooldowns",
            handler = function() state.applyBuff("player", "fortifying_brew", 20) end },
        energizing_brew = { id = 115288, cooldown = 60, toggle = "cooldowns",
            handler = function() state.applyBuff("player", "energizing_brew", 20); state.gainResource(state.chi.max, "chi") end },
        invoke_xuen = { id = 123904, cooldown = 180, toggle = "cooldowns", talent = "invoke_xuen" },
        summon_black_ox_statue = { id = 115315, cooldown = 30, toggle = "cooldowns" },

        -- Talent Abilities
        chi_brew = { id = 115399, cooldown = 45, charges = 2, talent = "chi_brew",
            handler = function() state.gainResource(2, "chi"); state.addBuffStack("player", "elusive_brew_stack", 2) end },
        chi_wave = { id = 115098, cooldown = 15, talent = "chi_wave" },

        -- Defensives / Utility
        zen_meditation = { id = 115176, cooldown = 180, toggle = "defensives" },
        dampen_harm = { id = 122278, cooldown = 90, toggle = "defensives", talent = "dampen_harm" },
        diffuse_magic = { id = 122783, cooldown = 90, toggle = "defensives", talent = "diffuse_magic" },
        provoke = { id = 115546, cooldown = 8, toggle = "threat" },
        spear_hand_strike = { id = 116705, cooldown = 15, interrupt = true },
        stance_of_the_sturdy_ox = { id = 115069, handler = function() state.applyBuff("player", "stance_of_the_sturdy_ox") end },
    })

    -- Advanced State Tracking
    ns.stagger_tick_amount = 0
    ns.last_stagger_tick_time = 0
    spec.GetStaggerLevel = function()
        if state.buff.heavy_stagger.up then return "heavy" end
        if state.buff.moderate_stagger.up then return "moderate" end
        if state.buff.light_stagger.up then return "light" end
        return "none"
    end

    -- State Expressions
    spec:RegisterStateExpr("stagger_dtps", function()
        if state.query_time - (ns.last_stagger_tick_time or 0) > 1.5 then return 0 end
        return ns.stagger_tick_amount or 0
    end)
    spec:RegisterStateExpr("stagger_level", function()
        local level = spec:GetStaggerLevel()
        if level == "heavy" then return 3 end
        if level == "moderate" then return 2 end
        if level == "light" then return 1 end
        return 0
    end)
    spec:RegisterStateExpr("shuffle_gap", function()
        if state.buff.shuffle.up then return 0 end
        local time_to_keg = state.cooldown.keg_smash.remains
        local energy_for_kick = 2 * (40 / state.energy.regen) -- Time to get energy for 2 Jabs
        return math.min(time_to_keg, energy_for_kick)
    end)
    spec:RegisterStateExpr("time_to_die", function()
        if state.stagger_dtps == 0 and state.unmitigated_dtps == 0 then return 999 end
        local total_dtps = state.stagger_dtps + (state.unmitigated_dtps or 0)
        return state.health.current / total_dtps
    end)

    -- Combat Log Event Processing
    RegisterBMCombatLogEvent("SPELL_PERIODIC_DAMAGE", function(timestamp, subevent, sourceGUID, destGUID, spellID, amount, critical)
        if destGUID == state.GUID and (spellID == 124273 or spellID == 124274 or spellID == 124275) then
            ns.stagger_tick_amount = amount
            ns.last_stagger_tick_time = GetTime()
        end
    end)

    RegisterBMCombatLogEvent("SPELL_DAMAGE", function(timestamp, subevent, sourceGUID, destGUID, spellID, amount, critical)
        if sourceGUID == state.GUID and critical and (spellID == 100780 or spellID == 115072 or spellID == 121253) then
            state.addBuffStack("player", 128938, 1) -- Elusive Brew Stack
        end
    end)

    -- Addon Options
    spec:RegisterOptions({
        enabled = true,
        aoe = 3,
        nameplates = false,
        nameplateRange = 8,
        damage = true,
        damageExpiration = 3,
        package = "Brewmaster",
    })

    -- User Settings
    spec:RegisterSetting("proactive_shuffle", true, { name = "Proactive Shuffle Management", type = "toggle" })
    spec:RegisterSetting("purify_level", 2, { name = "Purify at Stagger Level", desc="1=Light, 2=Moderate, 3=Heavy", type = "range", min = 1, max = 3, step = 1 })
    spec:RegisterSetting("elusive_brew_threshold", 8, { name = "Elusive Brew Stack Threshold", type = "range", min = 1, max = 15, step = 1 })
    spec:RegisterSetting("guard_health_threshold", 65, { name = "Reactive Guard Health %", type = "range", min = 30, max = 90, step = 5 })
    spec:RegisterSetting("fortify_health_pct", 35, {
        name = function() return string.format("Use %s Below Health %%", Hekili:GetSpellLinkWithTexture(spec.abilities.fortifying_brew.id)) end,
        desc = "The health percentage at which Fortifying Brew will be recommended as an emergency defensive cooldown.",
        type = "range", min = 0, max = 100, step = 5, width = "full"
    })

    -- Default APL Pack
    spec:RegisterPack("Brewmaster", 20250724, [[Hekili:T31AOTTnu4FldiHr5osojoRZt)8vA3eT5b42TCLQ2rS2gM57n6lE86iE8swksB9(l6VGQIQUnbJeHAVQDcOWrbU86CaE4GUwDBB4CvC5m98jdNZzDX6w)v)V(i)h(jDV7GFWEh)9T6rhFQVnSVzsmypSlD2OXqskYJCKfpPWXt87zPkZGZVRSLAXYUYORTmYLwaXlyc8LkGusGO7469JwjTfTH0PwPbJaeivvLsvrfoeQtcGbWlG0A)Ff9)8jPyqXgkz5Qkz5kLRyR12Uco1veB5MUOfIMXnV2Nw8UqEkeUOLXMFtKUOMcEvjzmqssgiE37NuLYlP5NnNgEE5(vJDjgvCeXmQVShsbh(AfIigS2JOmiUeXm(KJ0JkOtQu0Ky)iYcJvqQrthQ(5Fcu5ILidEZjQ0CoYXj)USIip9kem)i81l2cOFLlk9cKGk5nuuDXZes)SEHXiZdLP1gpb968CvpxbSVDaPzgwP6ahsQWnRs)uOKnc0)]])
end

-- Deferred loading mechanism
local function TryRegister()
    if Hekili and Hekili.Class and Hekili.Class.specs and Hekili.Class.specs[0] then
        RegisterBrewmasterSpec()
        bmCombatLogFrame:UnregisterEvent("ADDON_LOADED")
        return true
    end
    return false
end

if not TryRegister() then
    bmCombatLogFrame:RegisterEvent("ADDON_LOADED")
    bmCombatLogFrame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Hekili" or TryRegister() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

print("Brewmaster: Data-Driven Rework V6.0 loaded.")
```
